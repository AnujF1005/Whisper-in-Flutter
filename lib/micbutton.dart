import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:assistant/services/whisper_service.dart';
import 'package:http/http.dart' as http;

double calculateAudioDuration(
    int byteLength, int sampleRate, int numChannels, int bitDepth) {
  int bytesPerSample = bitDepth ~/ 8; // Convert bits to bytes
  int bytesPerSecond = sampleRate * numChannels * bytesPerSample;
  return byteLength / bytesPerSecond;
}

class MicButton extends StatefulWidget {
  @override
  _MicButtonState createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> {
  bool isPressed = false;
  bool isLoading = false;
  String recognizedText = "Press the button and speak";
  final WhisperService _whisperService = WhisperService();
  FlutterSoundRecorder? _recorder;
  StreamController<Uint8List> _recordingDataController = StreamController();
  StreamSubscription? _recorderSubscription;
  String? _filePath;
  List<int> _audioBytes = [];
  int _transcribedIndex = 0;
  Timer? timer;
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    await _recorder!.openRecorder();
    await Permission.microphone.request();
    final directory = await getApplicationDocumentsDirectory();
    _filePath = '${directory.path}/recording.wav';

    _recorderSubscription = _recordingDataController.stream.listen((buffer) {
      _audioBytes.addAll(buffer);
    });
  }

  Future<IOSink> createFile() async {
    var outputFile = File(_filePath!);
    if (outputFile.existsSync()) {
      await outputFile.delete();
    }
    return outputFile.openWrite();
  }

  void _startRecording() async {
    if (_recorderSubscription?.isPaused ?? true) {
      _recorderSubscription?.resume();
    }

    await _recorder!.startRecorder(
      toStream: _recordingDataController.sink,
      codec: Codec.pcm16,
      numChannels: 1,
    );

    _startPeriodicTranscription();
  }

  void _stopRecording() async {
    _stopPeriodicTranscription();
    await _recorder!.stopRecorder();
    _recorderSubscription?.pause();
    _transcribeAudio();
  }

  void _startPeriodicTranscription() {
    timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _transcribeAudio();
    });
  }

  void _stopPeriodicTranscription() {
    timer?.cancel();
  }

  Future<void> _transcribeAudio() async {
    setState(() {
      isLoading = true;
    });
    try {
      // Check size of _audioBytes to ensure that it is not empty or too small
      if (_audioBytes.isEmpty ||
          calculateAudioDuration(_audioBytes.length, 16000, 1, 16) < 5) {
        print('No audio data recorded');
        return;
      }
      // Convert collected audio bytes to Uint8List and write them to an MP3 file.
      final int lastIndex = _audioBytes.length - 1;
      Uint8List audioData =
          Uint8List.fromList(_audioBytes.sublist(_transcribedIndex, lastIndex));
      _audioBytes = _audioBytes.sublist(lastIndex + 1);
      _transcribedIndex = 0;
      final file = File(_filePath!);
      List<int> wavData = _addWavHeader(audioData);
      file.writeAsBytesSync(wavData);

      final text = await _whisperService.transcribeAudio(_filePath!);
      setState(() {
        recognizedText += ' $text';
      });
    } catch (e) {
      setState(() {
        recognizedText += '\n\nError: ${e.toString()}';
      });
    } finally {
      // Scroll to the bottom of the SingleChildScrollView
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  void _toggleButton() async {
    if (isPressed) {
      _stopRecording();
    } else {
      _startRecording();
    }

    setState(() {
      isPressed = !isPressed;
    });
  }

  /// Generate WAV Header for PCM Data
  List<int> _addWavHeader(Uint8List audioData) {
    const int sampleRate = 16000;
    const int numChannels = 1;
    const int bitsPerSample = 16;
    const int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    const int blockAlign = numChannels * (bitsPerSample ~/ 8);

    int dataLength = audioData.length;
    int totalFileSize = dataLength + 44; // Header size = 44 bytes

    // WAV Header Structure (Little Endian)
    var header = <int>[
      // RIFF Header
      ...'RIFF'.codeUnits, // Chunk ID
      totalFileSize & 0xFF,
      (totalFileSize >> 8) & 0xFF,
      (totalFileSize >> 16) & 0xFF,
      (totalFileSize >> 24) & 0xFF, // Chunk Size
      ...'WAVE'.codeUnits, // Format
      // fmt Subchunk
      ...'fmt '.codeUnits, // Subchunk1 ID
      16, 0, 0, 0, // Subchunk1 Size (16 for PCM)
      1, 0, // Audio Format (PCM)
      numChannels, 0, // NumChannels
      sampleRate & 0xFF,
      (sampleRate >> 8) & 0xFF,
      (sampleRate >> 16) & 0xFF,
      (sampleRate >> 24) & 0xFF, // SampleRate
      byteRate & 0xFF,
      (byteRate >> 8) & 0xFF,
      (byteRate >> 16) & 0xFF,
      (byteRate >> 24) & 0xFF, // ByteRate
      blockAlign, 0, // BlockAlign
      bitsPerSample, 0, // BitsPerSample
      // Data Subchunk
      ...'data'.codeUnits, // Subchunk2 ID
      dataLength & 0xFF,
      (dataLength >> 8) & 0xFF,
      (dataLength >> 16) & 0xFF,
      (dataLength >> 24) & 0xFF, // Subchunk2 Size
    ];

    // Return header + PCM data combined
    return [...header, ...audioData];
  }

  @override
  void dispose() {
    _recorder!.closeRecorder();
    _stopPeriodicTranscription();
    _recorder = null;
    _recorderSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _toggleButton,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isPressed ? Colors.red : Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPressed ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 60,
            ),
          ),
        ),
        const SizedBox(height: 30),
        Container(
          width: screenWidth * 0.8, // 80% of screen width
          height: screenHeight * 0.5, // 50% of screen height
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueAccent, width: 2),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                child: Text(
                  recognizedText,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.left, // left-aligned text
                ),
              ),
              if (isLoading)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
