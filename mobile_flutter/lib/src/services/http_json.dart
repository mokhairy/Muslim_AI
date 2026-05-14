import 'dart:convert';

import 'package:http/http.dart' as http;

const _defaultHeaders = {
  'Accept': 'application/json, text/plain, */*',
  'User-Agent': 'MuslimAI-Flutter/0.1',
};

Future<dynamic> fetchJson(String url) async {
  final response = await http
      .get(Uri.parse(url), headers: _defaultHeaders)
      .timeout(const Duration(seconds: 20));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'Request failed with status ${response.statusCode} for $url',
    );
  }

  final body = utf8
      .decode(response.bodyBytes)
      .replaceFirst('\uFEFF', '')
      .trim();
  if (body.isEmpty) {
    throw Exception('Empty JSON response from $url');
  }

  return jsonDecode(body);
}
