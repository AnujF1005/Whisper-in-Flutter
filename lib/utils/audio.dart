// Data class to store audio properties

import 'dart:typed_data';

class AudioProperties {
  final int sampleRate;
  final int numChannels;
  final int bitsPerSample;

  AudioProperties({
    required this.sampleRate,
    required this.numChannels,
    required this.bitsPerSample,
  });
}

double calculateAudioDuration(
    int byteLength, int sampleRate, int numChannels, int bitsPerSample) {
  int bytesPerSample = bitsPerSample ~/ 8; // Convert bits to bytes
  int bytesPerSecond = sampleRate * numChannels * bytesPerSample;
  return byteLength / bytesPerSecond;
}

/// Generate WAV Header for PCM Data
List<int> addWavHeader(
    Uint8List audioData, int sampleRate, int numChannels, int bitsPerSample) {
  int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
  int blockAlign = numChannels * (bitsPerSample ~/ 8);

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
