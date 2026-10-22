#include "flutter_window.h"
#include <optional>
#include <vector>
#include <mutex>
#include <algorithm>
#include <windows.h>
#include <mmsystem.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include "flutter/generated_plugin_registrant.h"

#define WM_MIC_DATA (WM_USER + 101)
static constexpr int kSampleRate = 44100;
static constexpr int kBlockBytes = 1024;
static constexpr int kNumBufs = 8;

class WinAudioBridge {
public:
  HWAVEIN hIn = nullptr;
  HWAVEOUT hOut = nullptr;
  WAVEHDR inHdrs[kNumBufs]{};
  char inBufs[kNumBufs][kBlockBytes]{};
  WAVEHDR outHdrs[kNumBufs * 2]{};
  char outBufs[kNumBufs * 2][kBlockBytes * 4]{};
  int outIdx = 0;
  bool running = false;
  HWND hwnd = nullptr;
  std::mutex mtx;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink;

  static void CALLBACK WaveInProc(HWAVEIN hwi, UINT uMsg, DWORD_PTR dwInstance, DWORD_PTR dwParam1, DWORD_PTR) {
    if (uMsg == WIM_DATA) {
      auto* self = reinterpret_cast<WinAudioBridge*>(dwInstance);
      if (self && self->running && self->hwnd) {
        PostMessage(self->hwnd, WM_MIC_DATA, 0, dwParam1);
      }
    }
  }

  bool Start(HWND window) {
    if (running) return true;
    hwnd = window;
    WAVEFORMATEX fmt{};
    fmt.wFormatTag = WAVE_FORMAT_PCM;
    fmt.nChannels = 1;
    fmt.nSamplesPerSec = kSampleRate;
    fmt.wBitsPerSample = 16;
    fmt.nBlockAlign = 2;
    fmt.nAvgBytesPerSec = kSampleRate * 2;

    if (waveOutOpen(&hOut, WAVE_MAPPER, &fmt, 0, 0, CALLBACK_NULL) != MMSYSERR_NOERROR) return false;
    if (waveInOpen(&hIn, WAVE_MAPPER, &fmt, (DWORD_PTR)&WinAudioBridge::WaveInProc, (DWORD_PTR)this, CALLBACK_FUNCTION) != MMSYSERR_NOERROR) {
      waveOutClose(hOut);
      hOut = nullptr;
      return false;
    }

    running = true;
    for (int i = 0; i < kNumBufs; ++i) {
      ZeroMemory(&inHdrs[i], sizeof(WAVEHDR));
      inHdrs[i].lpData = inBufs[i];
      inHdrs[i].dwBufferLength = kBlockBytes;
      waveInPrepareHeader(hIn, &inHdrs[i], sizeof(WAVEHDR));
      waveInAddBuffer(hIn, &inHdrs[i], sizeof(WAVEHDR));
    }
    waveInStart(hIn);
    return true;
  }

  void OnMicChunk(WAVEHDR* hdr) {
    if (!running) return;
    if (hdr->dwBytesRecorded > 0) {
      auto* ptr = reinterpret_cast<const uint8_t*>(hdr->lpData);
      std::vector<uint8_t> bytes(ptr, ptr + hdr->dwBytesRecorded);
      std::lock_guard<std::mutex> lock(mtx);
      if (sink) sink->Success(flutter::EncodableValue(bytes));
    }
    if (running && hIn) {
      waveInAddBuffer(hIn, hdr, sizeof(WAVEHDR));
    }
  }

  void Play(const std::vector<uint8_t>& pcm) {
    if (!running || !hOut || pcm.empty()) return;
    WAVEHDR& hdr = outHdrs[outIdx];
    if (hdr.dwFlags & WHDR_PREPARED) {
      waveOutUnprepareHeader(hOut, &hdr, sizeof(WAVEHDR));
    }
    size_t sz = std::min(pcm.size(), sizeof(outBufs[outIdx]));
    memcpy(outBufs[outIdx], pcm.data(), sz);
    ZeroMemory(&hdr, sizeof(WAVEHDR));
    hdr.lpData = outBufs[outIdx];
    hdr.dwBufferLength = static_cast<DWORD>(sz);
    waveOutPrepareHeader(hOut, &hdr, sizeof(WAVEHDR));
    waveOutWrite(hOut, &hdr, sizeof(WAVEHDR));
    outIdx = (outIdx + 1) % (kNumBufs * 2);
  }

  void Stop() {
    if (!running) return;
    running = false;
    if (hIn) { waveInStop(hIn); waveInReset(hIn); waveInClose(hIn); hIn = nullptr; }
    if (hOut) { waveOutReset(hOut); waveOutClose(hOut); hOut = nullptr; }
  }
};

static WinAudioBridge g_audio;

FlutterWindow::FlutterWindow(const flutter::DartProject& project) : project_(project) {}
FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) return false;
  RECT frame = GetClientArea();
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) return false;
  RegisterPlugins(flutter_controller_->engine());

  auto messenger = flutter_controller_->engine()->messenger();

  auto audio_ch = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "rc505/audio", &flutter::StandardMethodCodec::GetInstance());
  audio_ch->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "start") {
      result->Success(flutter::EncodableValue(g_audio.Start(GetHandle())));
    } else if (call.method_name() == "play") {
      if (const auto* bytes = std::get_if<std::vector<uint8_t>>(call.arguments())) {
        g_audio.Play(*bytes);
      }
      result->Success();
    } else {
      result->NotImplemented();
    }
  });

  auto mic_ch = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      messenger, "rc505/mic", &flutter::StandardMethodCodec::GetInstance());
  auto handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [](const flutter::EncodableValue*, std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
        std::lock_guard<std::mutex> lock(g_audio.mtx);
        g_audio.sink = std::move(events);
        return nullptr;
      },
      [](const flutter::EncodableValue*) {
        std::lock_guard<std::mutex> lock(g_audio.mtx);
        g_audio.sink = nullptr;
        return nullptr;
      });
  mic_ch->SetStreamHandler(std::move(handler));

  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  flutter_controller_->engine()->SetNextFrameCallback([&]() { this->Show(); });
  flutter_controller_->ForceRedraw();
  return true;
}

void FlutterWindow::OnDestroy() {
  g_audio.Stop();
  if (flutter_controller_) flutter_controller_ = nullptr;
  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message, WPARAM const wparam, LPARAM const lparam) noexcept {
  if (message == WM_MIC_DATA) {
    g_audio.OnMicChunk(reinterpret_cast<WAVEHDR*>(lparam));
    return 0;
  }
  if (flutter_controller_) {
    std::optional<LRESULT> result = flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    if (result) return *result;
  }
  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }
  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
