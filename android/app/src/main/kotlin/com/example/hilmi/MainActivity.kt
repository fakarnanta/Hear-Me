package com.example.hilmi

// Import yang dibutuhkan untuk Flutter dan Azure SDK
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.microsoft.cognitiveservices.speech.SpeechConfig
import com.microsoft.cognitiveservices.speech.SpeechRecognizer
import com.microsoft.cognitiveservices.speech.ResultReason
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {

    // Definisikan nama untuk channel kita
    private val METHOD_CHANNEL = "com.example.hilmi/azure/method"
    private val EVENT_CHANNEL = "com.example.hilmi/azure/event"

    // TAG untuk mempermudah filtering di Logcat
    private val TAG = "MainActivity"

    // Variabel untuk menampung komponen Azure SDK
    private var speechRecognizer: SpeechRecognizer? = null
    private var speechConfig: SpeechConfig? = null
    
    // Variabel untuk mengirim data event ke Flutter
    private var eventSink: EventChannel.EventSink? = null

    // Deklarasi fungsi-fungsi dari C++
    external fun getAzureKey(): String
    external fun getAzureRegion(): String

    companion object {
        init {
            // LOG: Konfirmasi library native C++ dimuat saat kelas pertama kali diinisialisasi
            Log.i("MainActivity_Companion", "Loading native library 'native-lib'")
            System.loadLibrary("native-lib")
        }
    }
    
    // Fungsi untuk memulai proses mendengarkan
    private fun startListening() {
        // LOG: Konfirmasi fungsi startListening dipanggil
        Log.i(TAG, "startListening() called.")
        
        Executors.newSingleThreadExecutor().execute {
            try {
                // LOG: Memulai proses di thread terpisah
                Log.d(TAG, "Executing transcription logic on a background thread.")
                
                val azureKey = getAzureKey()
                val azureRegion = getAzureRegion()
                // LOG: Kredensial berhasil diambil dari C++
                Log.i(TAG, "Credentials retrieved successfully. Region: $azureRegion")

                speechConfig = SpeechConfig.fromSubscription(azureKey, azureRegion)
                speechConfig?.speechRecognitionLanguage = "id-ID"
                // LOG: Konfigurasi SpeechConfig berhasil dibuat
                Log.i(TAG, "SpeechConfig created for language 'id-ID'.")

                speechRecognizer = SpeechRecognizer(speechConfig)
                // LOG: SpeechRecognizer berhasil diinisialisasi
                Log.i(TAG, "SpeechRecognizer initialized.")

                // Tambahkan event listener untuk hasil
                speechRecognizer?.recognizing?.addEventListener { _, e ->
                    // LOG: Hasil parsial diterima
                    Log.d(TAG, "Recognizing: ${e.result.text}")
                    eventSink?.success(e.result.text)
                }
                
                speechRecognizer?.recognized?.addEventListener { _, e ->
                    if (e.result.reason == ResultReason.RecognizedSpeech) {
                        // LOG: Hasil final diterima
                        Log.i(TAG, "Recognized: ${e.result.text}")
                        eventSink?.success(e.result.text)
                    }
                }

                speechRecognizer?.canceled?.addEventListener { _, e ->
                    // LOG: Proses dibatalkan atau error
                    Log.e(TAG, "CANCELED: Reason=${e.reason}, Details=${e.errorDetails}")
                    eventSink?.error("CANCELED", "Speech recognition canceled: ${e.reason}", e.errorDetails)
                }
                
                speechRecognizer?.startContinuousRecognitionAsync()?.get()
                // LOG: Proses pengenalan suara berhasil dimulai
                Log.i(TAG, "✅ Continuous recognition started successfully.")

            } catch (e: Exception) {
                // LOG: Terjadi exception saat inisialisasi
                Log.e(TAG, "ERROR during startListening setup: ${e.message}", e)
                eventSink?.error("ERROR", "Initialization failed: ${e.message}", null)
            }
        }
    }
    
    // Fungsi untuk berhenti mendengarkan
    private fun stopListening() {
        // LOG: Konfirmasi fungsi stopListening dipanggil
        Log.i(TAG, "stopListening() called.")
        speechRecognizer?.stopContinuousRecognitionAsync()?.get()
        speechRecognizer?.close()
        speechRecognizer = null
        speechConfig?.close()
        speechConfig = null
        // LOG: Semua resource Azure telah dihentikan dan dibersihkan
        Log.i(TAG, "Azure resources stopped and cleaned up.")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // LOG: Konfirmasi bahwa mesin Flutter siap dikonfigurasi
        Log.i(TAG, "configureFlutterEngine() called. Setting up channels.")

        // Siapkan MethodChannel untuk menerima perintah dari Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            // LOG: Menerima panggilan dari Flutter melalui MethodChannel
            Log.d(TAG, "MethodChannel received call: ${call.method}")
            when (call.method) {
                "startListening" -> {
                    startListening()
                    result.success("Listening started")
                }
                "stopListening" -> {
                    stopListening()
                    result.success("Listening stopped")
                }
                else -> result.notImplemented()
            }
        }

        // Siapkan EventChannel untuk mengirim hasil ke Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    // LOG: Flutter mulai mendengarkan EventChannel
                    Log.i(TAG, "EventChannel: onListen - Flutter is now listening for events.")
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    // LOG: Flutter berhenti mendengarkan EventChannel
                    Log.i(TAG, "EventChannel: onCancel - Flutter has stopped listening.")
                    eventSink = null
                }
            }
        )
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // LOG: Activity dihancurkan, memastikan semua proses dihentikan
        Log.w(TAG, "onDestroy() called. Forcing stopListening.")
        stopListening()
    }
}