import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:assistant/utils/audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Add backend URL at the top
const String backendUrl = 'http://10.0.2.2:8000/transcribe'; // TODO: Replace with your backend URL // For Android emulator, use 10.0.2.2 instead of 127.0.0.1 to access your host machine.

class TranscriptionService {
  final List<int> _audioBytesBuffer = [];
  final AudioProperties audioProperties;
  late Directory _appDir;
  late String _filePath;
  final StreamController<String> _recognizedTextController = StreamController<String>.broadcast();

  TranscriptionService(this.audioProperties) {
    _initialize();
  }

  Stream<String> get recognizedTextStream => _recognizedTextController.stream;

  void _initialize() async {
    _appDir = await getApplicationDocumentsDirectory();
    _filePath = '${_appDir.path}/recording.wav';
  }

  void transcribeRemaining() async {
    double bufferDuration = calculateAudioDuration(
        _audioBytesBuffer.length,
        audioProperties.sampleRate,
        audioProperties.numChannels,
        audioProperties.bitsPerSample);
    if (_audioBytesBuffer.isNotEmpty && bufferDuration > 0.01) {
      await _uploadAudioToBackend(Uint8List.fromList(_audioBytesBuffer));
    }
    _audioBytesBuffer.clear();
  }

  void processAudioData(Uint8List audioData) {
    _audioBytesBuffer.addAll(audioData);
  }

  Future<void> _uploadAudioToBackend(Uint8List audioData) async {
    try {
      final file = File(_filePath);
      List<int> wavData = addWavHeader(audioData, audioProperties.sampleRate,
          audioProperties.numChannels, audioProperties.bitsPerSample);
      file.writeAsBytesSync(wavData);

      final now = DateTime.now().toIso8601String();
      var request = http.MultipartRequest('POST', Uri.parse(backendUrl))
        ..fields['start_timestamp'] = now
        ..files.add(await http.MultipartFile.fromPath('audio', file.path));
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        _recognizedTextController.add('Processing started.');
      } else {
        _recognizedTextController.add('Failed to upload: $responseBody');
      }
    } catch (e) {
      _recognizedTextController.add('\n\nError:  [31m${e.toString()}\u001b[0m');
      print(e);
    }
  }

  void dispose() {
    _recognizedTextController.close();
  }
}
