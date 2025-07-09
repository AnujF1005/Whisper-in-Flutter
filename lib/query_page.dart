import 'package:flutter/material.dart';
import 'services/query_service.dart';

class QueryPage extends StatefulWidget {
  const QueryPage({Key? key}) : super(key: key);

  @override
  State<QueryPage> createState() => _QueryPageState();
}

class _QueryPageState extends State<QueryPage> {
  final TextEditingController _controller = TextEditingController();
  final QueryService _queryService = QueryService();
  String _result = '';
  bool _loading = false;

  void _submitQuery() async {
    setState(() {
      _loading = true;
      _result = '';
    });
    try {
      final res = await _queryService.queryMemory(_controller.text);
      setState(() {
        _result = res;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: ' + e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Query Memory')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Enter your query',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submitQuery(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _submitQuery,
              child: _loading ? const CircularProgressIndicator() : const Text('Query'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_result, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 