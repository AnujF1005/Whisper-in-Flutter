import 'dart:async';
import 'dart:typed_data';
import 'package:assistant/services/transcription.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:assistant/utils/audio.dart';

class MicButton extends StatefulWidget {
  @override
  _MicButtonState createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> {
  bool isPressed = false;
  bool isLoading = false;
  String _recognizedText = "";
  FlutterSoundRecorder? _recorder;
  StreamController<Uint8List> _recordingDataController = StreamController();
  StreamSubscription? _recorderSubscription;
  ScrollController _scrollController = ScrollController();
  final AudioProperties _audioProperties = AudioProperties(
    sampleRate: 16000,
    numChannels: 1,
    bitsPerSample: 16,
  );
  TranscriptionService? _transcriptionService;
  StreamSubscription<String>? _transcriptionSubscription;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    await _recorder!.openRecorder();
    await Permission.microphone.request();

    _transcriptionService = TranscriptionService(_audioProperties);

    _recorderSubscription = _recordingDataController.stream.listen((buffer) {
      _transcriptionService!.processAudioData(buffer);
    });
    _transcriptionSubscription =
        _transcriptionService!.recognizedTextStream.listen((recognizedText) {
      setState(() {
        _recognizedText += ' $recognizedText';
      });

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _startRecording() async {
    if (_recorderSubscription?.isPaused ?? true) {
      _recorderSubscription?.resume();
    }

    await _recorder!.startRecorder(
      toStream: _recordingDataController.sink,
      codec: Codec.pcm16,
      numChannels: _audioProperties.numChannels,
      sampleRate: _audioProperties.sampleRate,
      bitRate: _audioProperties.bitsPerSample *
          _audioProperties.sampleRate *
          _audioProperties.numChannels,
    );
  }

  void _stopRecording() async {
    await _recorder!.stopRecorder();
    _recorderSubscription?.pause();
    _transcriptionService!.transcribeRemaining();
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

  @override
  void dispose() {
    _recorder!.closeRecorder();
    _recorder = null;
    _recorderSubscription?.cancel();
    _scrollController.dispose();
    _transcriptionSubscription?.cancel();
    _transcriptionService?.dispose();
    _recordingDataController.close();
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
        Text(
          isPressed ? "Recording..." : "Press the mic to start recording",
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
          textAlign: TextAlign.left, // left-aligned text
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
                  _recognizedText,
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
