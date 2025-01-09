import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv package

class WhisperService {
  final String apiUrl = 'https://api.openai.com/v1/audio/transcriptions';
  late String apiKey;

  WhisperService() {
    _initialize();
  }

  void _initialize() async {
    await dotenv.load(fileName: "assets/.env");
    apiKey = dotenv.env['OPENAI_API_KEY'] ?? "no-api-key";
  }

  Future<String> transcribeAudio(String audioFilePath) async {
    final request = http.MultipartRequest('POST', Uri.parse(apiUrl))
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..headers['Content-Type'] = 'multipart/form-data'
      ..fields['model'] = 'whisper-1'
      ..files.add(await http.MultipartFile.fromPath('file', audioFilePath));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    print("=========== In WhisperService::transcribeAudio ===========");
    print(response.statusCode);
    print(responseBody);
    print("=========== In WhisperService::transcribeAudio ===========");

    if (response.statusCode == 200) {
      final data = json.decode(responseBody);
      return data['text'];
    } else {
      throw Exception('Failed to transcribe audio');
    }
  }

  Future<String> transcribeAudioBytes(Uint8List audioBytes) async {
    final request = http.MultipartRequest('POST', Uri.parse(apiUrl))
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..headers['Content-Type'] = 'multipart/form-data'
      ..fields['model'] = 'whisper-1'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: 'audio.wav',
        contentType: MediaType('audio', 'wav'),
      ));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    print("=========== WhisperService::transcribeAudioBytes ===========");
    print(response.statusCode);
    print(responseBody);
    print("=========== END ===========");

    if (response.statusCode == 200) {
      final data = json.decode(responseBody);
      return data['text'];
    } else {
      throw Exception('Failed to transcribe audio');
    }
  }
}
