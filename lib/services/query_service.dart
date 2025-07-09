import 'dart:convert';
import 'package:http/http.dart' as http;

class QueryService {
  final String baseUrl;
  QueryService({this.baseUrl = 'http://10.0.2.2:8000'});

  Future<String> queryMemory(String query) async {
    final url = Uri.parse('$baseUrl/query');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'query': query}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['results']['answer'].toString();
    } else {
      throw Exception('Failed to query memory: ${response.body}');
    }
  }
} 