# BOSS RC-505mkII Loop Station Clone (Flutter)

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

A high-performance, 1:1 feature-complete software replica of the **BOSS RC-505mkII Loop Station**. Built in Flutter and Dart with zero external plugin dependencies, this project features a zero-allocation real-time DSP engine, all 53 hardware effects, per-track isolated FX routing, and native low-latency PCM audio drivers across **Linux**, **Windows**, and **Android**.

---

## Key Features

* **1:1 Hardware Faceplate & Workflow:** Accurate recreation of the RC-505mkII top panel and 5 track strips, including dual **INPUT FX** and **TRACK FX** sections with 4 banks (`A`–`D`), large silver-rimmed encoders, central graphic LCD screen, and 4 push-to-enter function knobs (`1`–`4`).
* **All 53 Authentic MKII Effects:** Real-time DSP implementations of Guitar-to-Bass (`G2B`), Harmonist, Vocoder, Osc Bot, Robot, Electric, Defretter, Sustainer, Auto Riff, Slow Gear, Transpose, Pitch Bend, Slicer, Beat Scatter, Beat Repeat, Beat Shift, Vinyl Flick, Tape Echo, Space Echo, Granular Delay, Warp, Twist, Freeze, Roll 1/2, and 3-Band Isolator EQ.
* **Per-Track FX Targeting & Insert Printing:**
  * Route Track FX globally (`ALL`) or lock individual FX slots (`A`–`D`) to a single recorded track (`TRK 1`–`TRK 5`).
  * Enable dedicated per-track Output Insert Effects (`OUT FX` on Track Edit Page 3) and permanently **Print/Bake FX** (`PRINT FX`) into your recorded loop audio with full Undo support.
* **True RC-505mkII Looping Architecture:**
  * Independent track lengths and polymetric looping.
  * Per-track and global `MEASURE` settings (`DEFAULT`, `AUTO`, `FREE`, `1BEAT`, `1BAR`–`32BAR`).
  * `OVERDUB` vs. `REPLACE` punch-in modes, `REVERSE`, `1-SHOT`, `FADE IN/OUT`, `LOOP END` stop, Half/Double speed, Track Bounce (`BNC`), and `MARK BACK` snapshots.
* **Zero-Dependency Native Audio Engines (44.1 kHz, 16-bit Mono PCM):**
  * **Linux:** Native **PipeWire** (`pw-cat`) with automatic fallback to **ALSA** (`arecord`/`aplay`).
  * **Windows:** Native C++ **WinMM** (`waveInOpen`/`waveOutOpen`) compiled directly into the runner—no external DLLs or FFmpeg required.
  * **Android:** Low-latency Java/Kotlin **AudioRecord & AudioTrack** (`PERFORMANCE_MODE_LOW_LATENCY` + `THREAD_PRIORITY_URGENT_AUDIO`).

---

## Download & Install (Pre-Built Releases)

Pre-compiled binaries for all platforms are available on the [**Releases**](../../releases) page:

| Platform | Release File | How to Run |
| :--- | :--- | :--- |
| **Linux (x64)** | `RC505mkII-Linux-x64.tar.gz` | Extract (`tar -xzvf ...`) and run `./bundle/bossrcmk2` (requires `pipewire` or `alsa-utils`). |
| **Windows (x64)** | `RC505mkII-Windows-x64.zip` | Extract the `.zip` folder and double-click `bossrcmk2.exe`. |
| **Android (ARM64)** | `RC505mkII-Android.apk` | Install the `.apk` on your device and grant Microphone permission on launch. |

> **Headphone Recommendation:** When using a live microphone, plug in headphones so your mic does not pick up speaker output during overdubbing.

---

## Keyboard Shortcuts (Desktop & USB Keyboards)

Press **`H`** or **`/`** inside the app at any time to toggle the interactive **Keyboard & Track FX Routing Guide**.

### Track 1–5 Controls
| Key Combination | RC-505mkII Function |
| :--- | :--- |
| **`1` `2` `3` `4` `5`** | **REC / OVERDUB / PLAY** Pad for Track 1–5 |
| **`Shift + 1..5`** | Toggle **Reverse** playback on Track 1–5 |
| **`Ctrl + 1..5`** | Lock active **Track FX Slot Target** to Track 1–5 |
| **`Q` `W` `E` `R` `T`** | **STOP** Track 1–5 |
| **`Shift + Q..T`** | **CLEAR** Track 1–5 |
| **`A` `S` `D` `F` `G`** | Toggle **FX** Bus Switch on Track 1–5 |
| **`Shift + A..G`** | Lock active **Track FX Slot Target** to Track 1–5 & open FX Editor |
| **`Z` `X` `C` `V` `B`** | Open **TRACK** Edit Menu (Pages 1–4) for Track 1–5 |
| **`Shift + Z..B`** | Toggle **1-Shot** mode on Track 1–5 |

### Input FX, Track FX & Transport
| Key Combination | RC-505mkII Function |
| :--- | :--- |
| **`6` `7` `8` `9`** | Toggle **INPUT FX** Slots `A`, `B`, `C`, `D` (`Shift + 6..9` switches Bank `A`–`D`) |
| **`0`** | Open **INPUT FX EDIT** screen |
| **`Y` `U` `I` `O`** | Toggle **TRACK FX** Slots `A`, `B`, `C`, `D` (`Shift + Y..O` switches Bank `A`–`D`) |
| **`P`** | Open **TRACK FX EDIT** screen |
| **`Space`** | **ALL START / STOP** (`Shift + Space` toggles Rhythm Start/Stop) |
| **`N`** / **`Ctrl + N`** | **RHYTHM START / STOP** / Open Rhythm Edit Menu |
| **`Backspace`** | **UNDO / REDO** (`Shift + Backspace` = **MARK BACK**, `Ctrl + Backspace` = Restore Base) |
| **`Left` / `Right` Arrows** | **Page `◄` / `►`** (Navigate LCD Home Views, FX Pages, or Track Edit Pages 1–4) |
| **`Up` / `Down` Arrows** | Increment / Decrement active Menu Value or Knob 1 |
| **`[ ` / ` ]`** | Previous / Next **Memory** Slot (`01`–`99`) |
| **`L`** / **`Shift + L`** | Open **LOOP** Setup / Quick-toggle Global Measure between **`FREE`** and **`AUTO`** |
| **`M` / `K` / `Enter` / `Esc`** | **MENU** / **TAP TEMPO** / **ENTER** (`Shift + Enter` = Save Memory) / **EXIT** |

---

## How to Apply Effects to a Specific Recorded Track

1. **Method 1 — Per-Slot Track FX Target (`TRK 1`–`TRK 5`):**
   * Hold the **`FX`** button on any track strip (or press **`Shift + A / S / D / F / G`**).
   * Or press **`EDIT`** under `TRACK FX`, press **`►`** to open **Page 2 (`SETUP`)**, and turn **Knob 2 (`TARGET`)** to choose `ALL`, `TRK 1`, `TRK 2`, `TRK 3`, `TRK 4`, or `TRK 5`.
2. **Method 2 — Dedicated Per-Track Output Insert FX & Print-to-Track:**
   * Press **`TRACK`** on any channel strip (`Z` `X` `C` `V` `B`) and press **`►`** twice to open **Page 3 (`OUT FX`)**.
   * Turn **Knob 1 (`INS ON`)** to `ON`, **Knob 2 (`FX TYPE`)** to pick any of the 53 effects, and **Knob 3 (`MIX`)** to adjust wet level.
   * **Push/Click Knob 4 (`PRINT FX`)** to permanently bake the effect into that track's recorded audio buffer (press `Backspace` to Undo at any time).

---

## Building from Source

### 1. Linux Desktop
Requires `pipewire` (`pw-cat`) or `alsa-utils` (`arecord`/`aplay`), plus standard GTK3 CMake headers.
```bash
flutter config --enable-linux-desktop
flutter build linux --release