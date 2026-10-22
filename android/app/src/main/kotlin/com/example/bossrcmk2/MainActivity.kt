python3 - << 'EOF'
import glob, os, re

# 1. Find MainActivity.kt and detect package name
kt_files = glob.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True)
if not kt_files:
    print("Error: Could not find MainActivity.kt. Run this from your Flutter project root.")
    exit(1)

kt_path = kt_files[0]
with open(kt_path, "r") as f:
    m = re.search(r"^package\s+([\w\.]+)", f.read(), re.M)
    pkg = m.group(1) if m else "com.example.app"

# 2. Write the low-latency RC-505mkII Android Audio Engine into MainActivity.kt
kt_code = f"""package {pkg}

import android.Manifest
import android.content.pm.PackageManager
import android.media.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {{
    private val AUDIO_CH = "rc505/audio"
    private val MIC_CH = "rc505/mic"
    private val SR = 44100
    private val BLOCK_BYTES = 1024

    private var running = AtomicBoolean(false)
    private var rec: AudioRecord? = null
    private var trk: AudioTrack? = null
    private var sink: EventChannel.EventSink? = null
    private var pendingResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, MIC_CH).setStreamHandler(
            object : EventChannel.StreamHandler {{
                override fun onListen(args: Any?, events: EventChannel.EventSink?) {{ sink = events }}
                override fun onCancel(args: Any?) {{ sink = null }}
            }}
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CH).setMethodCallHandler {{ call, res ->
            when (call.method) {{
                "start" -> {{
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {{
                        res.success(startAudio())
                    }} else {{
                        pendingResult = res
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 101)
                    }}
                }}
                "play" -> {{
                    val pcm = call.arguments as? ByteArray
                    if (pcm != null && running.get()) {{
                        trk?.write(pcm, 0, pcm.size, AudioTrack.WRITE_NON_BLOCKING)
                    }}
                    res.success(null)
                }}
                else -> res.notImplemented()
            }}
        }}
    }}

    override fun onRequestPermissionsResult(reqCode: Int, perms: Array<out String>, grantResults: IntArray) {{
        super.onRequestPermissionsResult(reqCode, perms, grantResults)
        if (reqCode == 101) {{
            val ok = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingResult?.success(if (ok) startAudio() else false)
            pendingResult = null
        }}
    }}

    @SuppressWarnings("MissingPermission")
    private fun startAudio(): Boolean {{
        if (running.get()) return true
        val minIn = AudioRecord.getMinBufferSize(SR, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        val minOut = AudioTrack.getMinBufferSize(SR, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (minIn <= 0 || minOut <= 0) return false

        rec = AudioRecord(
            MediaRecorder.AudioSource.VOICE_UNPROCESSED,
            SR,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            maxOf(minIn, BLOCK_BYTES * 4)
        )

        val trkBuilder = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(SR)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setBufferSizeInBytes(maxOf(minOut, BLOCK_BYTES * 4))

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {{
            trkBuilder.setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
        }}

        trk = trkBuilder.build()
        if (rec?.state != AudioRecord.STATE_INITIALIZED || trk?.state != AudioTrack.STATE_INITIALIZED) return false

        running.set(true)
        rec?.startRecording()
        trk?.play()

        Thread {{
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            val buf = ByteArray(BLOCK_BYTES)
            while (running.get()) {{
                val n = rec?.read(buf, 0, buf.size) ?: -1
                if (n > 0) {{
                    val copy = buf.copyOf(n)
                    mainHandler.post {{ sink?.success(copy) }}
                }}
            }}
        }}.start()

        return true
    }}

    override fun onDestroy() {{
        running.set(false)
        rec?.stop(); rec?.release()
        trk?.stop(); trk?.release()
        super.onDestroy()
    }}
}}
"""

with open(kt_path, "w") as f:
    f.write(kt_code)
print(f"Updated {kt_path} (package {pkg})")

# 3. Ensure RECORD_AUDIO permission is in AndroidManifest.xml
manifest_path = "android/app/src/main/AndroidManifest.xml"
if os.path.exists(manifest_path):
    with open(manifest_path, "r") as f:
        xml = f.read()
    if "android.permission.RECORD_AUDIO" not in xml:
        xml = xml.replace("<application", '<uses-permission android:name="android.permission.RECORD_AUDIO"/>\n    <application', 1)
        with open(manifest_path, "w") as f:
            f.write(xml)
        print(f"Added RECORD_AUDIO permission to {manifest_path}")
    else:
        print("RECORD_AUDIO permission already present in AndroidManifest.xml")
EOF