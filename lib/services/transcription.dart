import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:assistant/services/whisper_service.dart';
import 'package:assistant/utils/audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';

class TranscriptionService {
  final List<int> _audioBytesBuffer = [];
  final double _audioChunkDurationInSec = 30;
  final AudioProperties audioProperties;
  late Directory _appDir;
  late String _filePath;
  final WhisperService _whisperService = WhisperService();
  final StreamController<String> _recognizedTextController =
      StreamController<String>();

  TranscriptionService(this.audioProperties) {
    _initialize();
  }

  Stream<String> get recognizedTextStream => _recognizedTextController.stream;

  void _initialize() async {
    _appDir = await getApplicationDocumentsDirectory();
    _filePath = '${_appDir.path}/recording.wav';
  }

  void transcribeRemaining() {
    double bufferDuration = calculateAudioDuration(
        _audioBytesBuffer.length,
        audioProperties.sampleRate,
        audioProperties.numChannels,
        audioProperties.bitsPerSample);
    if (_audioBytesBuffer.isNotEmpty && bufferDuration > 0.01) {
      _transcribeAudio(Uint8List.fromList(_audioBytesBuffer));
    }
    _audioBytesBuffer.clear();
  }

  void processAudioData(Uint8List audioData) {
    _audioBytesBuffer.addAll(audioData);
    double bufferDuration = calculateAudioDuration(
        _audioBytesBuffer.length,
        audioProperties.sampleRate,
        audioProperties.numChannels,
        audioProperties.bitsPerSample);
    if (bufferDuration >= _audioChunkDurationInSec) {
      int lastIndex = _audioBytesBuffer.length - 1;
      final chunk = _audioBytesBuffer.sublist(0, lastIndex);
      _audioBytesBuffer.clear();
      _transcribeAudio(Uint8List.fromList(chunk));
    }
  }

  void _transcribeAudio(Uint8List audioData) async {
    try {
      final file = File(_filePath);
      List<int> wavData = addWavHeader(audioData, audioProperties.sampleRate,
          audioProperties.numChannels, audioProperties.bitsPerSample);
      file.writeAsBytesSync(wavData);

      // Use ffmpeg to remove silence
      // get folder path for the file _filePath and append _nosilence.wav to it

      final outputFilePath = '${_appDir.path}/recording_nosilence.wav';
      await FFmpegKit.execute(
          '-fflags +discardcorrupt -y -i $_filePath -ar ${audioProperties.sampleRate} -af silenceremove=start_periods=1:stop_periods=-1:start_threshold=-30dB:stop_threshold=-30dB:start_silence=2:stop_silence=2 $outputFilePath');

      // Get duration of audio in seconds. (Note: WAV file has 44 bytes header + 0.1 seconds of audio data)
      if (File(outputFilePath).lengthSync() <
          (44 +
              0.1 *
                  audioProperties.sampleRate *
                  audioProperties.numChannels *
                  audioProperties.bitsPerSample ~/
                  8)) {
        print("=========== In TranscriptionService::transcribeAudio ===========");
        print("File length is less than the expected length");
        print("=========== In TranscriptionService::transcribeAudio ===========");
        return;
      }

      final text = await _whisperService.transcribeAudio(outputFilePath);
      _recognizedTextController.add(text);
    } catch (e) {
      _recognizedTextController.add('\n\nError: ${e.toString()}');
    }
  }

  void dispose() {
    _recognizedTextController.close();
  }
}
