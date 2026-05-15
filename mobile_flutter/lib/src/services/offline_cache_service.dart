import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const _defaultHeaders = {
  'Accept': 'application/json, text/plain, */*',
  'User-Agent': 'MuslimAI-Flutter/0.1',
};

class DownloadBatchResult {
  const DownloadBatchResult({
    required this.downloadedCount,
    required this.totalCount,
  });

  final int downloadedCount;
  final int totalCount;
}

class OfflineCacheService {
  OfflineCacheService._();

  static final OfflineCacheService instance = OfflineCacheService._();

  Future<dynamic> fetchJson(String url) async {
    final cacheFile = await _jsonCacheFile(url);

    try {
      final response = await http
          .get(Uri.parse(url), headers: _defaultHeaders)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = _decodeJsonPayload(response.bodyBytes, url);
        await _writeTextAtomically(cacheFile, body);
        return jsonDecode(body);
      }
      throw HttpException(
        'Request failed with status ${response.statusCode} for $url',
      );
    } catch (error) {
      if (await cacheFile.exists()) {
        final body = await cacheFile.readAsString();
        return jsonDecode(body);
      }
      rethrow;
    }
  }

  Future<Uri> resolvePlayableAudioUri(String url) async {
    final localPath = await resolveDownloadedAudioPath(url);
    if (localPath == null) {
      return Uri.parse(url);
    }
    return Uri.file(localPath);
  }

  Future<String?> resolveDownloadedAudioPath(String url) async {
    if (url.isEmpty) {
      return null;
    }

    final file = await _audioCacheFile(url);
    if (!await file.exists()) {
      return null;
    }
    return file.path;
  }

  Future<int> countDownloadedAudioUrls(List<String> urls) async {
    var count = 0;
    for (final url in urls.toSet()) {
      if (url.isEmpty) {
        continue;
      }
      if (await isAudioDownloaded(url)) {
        count += 1;
      }
    }
    return count;
  }

  Future<bool> isAudioDownloaded(String url) async {
    if (url.isEmpty) {
      return false;
    }
    final file = await _audioCacheFile(url);
    return file.exists();
  }

  Future<DownloadBatchResult> downloadAudioUrls(List<String> urls) async {
    final uniqueUrls = urls.where((item) => item.isNotEmpty).toSet().toList();
    var downloadedCount = 0;

    for (final url in uniqueUrls) {
      await _downloadAudioUrl(url);
      downloadedCount += 1;
    }

    return DownloadBatchResult(
      downloadedCount: downloadedCount,
      totalCount: uniqueUrls.length,
    );
  }

  Future<void> removeAudioUrls(List<String> urls) async {
    for (final url in urls.toSet()) {
      if (url.isEmpty) {
        continue;
      }
      final file = await _audioCacheFile(url);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _downloadAudioUrl(String url) async {
    final cacheFile = await _audioCacheFile(url);
    if (await cacheFile.exists()) {
      return;
    }

    final response = await http
        .get(Uri.parse(url), headers: _defaultHeaders)
        .timeout(const Duration(minutes: 2));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Audio download failed with status ${response.statusCode} for $url',
      );
    }

    await _writeBytesAtomically(cacheFile, response.bodyBytes);
  }

  Future<File> _jsonCacheFile(String url) async {
    final directory = await _jsonCacheDirectory();
    return File('${directory.path}/${_hash(url)}.json');
  }

  Future<File> _audioCacheFile(String url) async {
    final directory = await _audioCacheDirectory();
    final extension = _audioExtension(url);
    return File('${directory.path}/${_hash(url)}$extension');
  }

  Future<Directory> _jsonCacheDirectory() async {
    final root = await _cacheRoot();
    final directory = Directory('${root.path}/json');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> _audioCacheDirectory() async {
    final root = await _cacheRoot();
    final directory = Directory('${root.path}/audio');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> _cacheRoot() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/offline_cache');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _hash(String value) {
    return sha1.convert(utf8.encode(value)).toString();
  }

  String _audioExtension(String url) {
    final path = Uri.parse(url).path.toLowerCase();
    if (path.endsWith('.m4a')) {
      return '.m4a';
    }
    if (path.endsWith('.aac')) {
      return '.aac';
    }
    if (path.endsWith('.wav')) {
      return '.wav';
    }
    return '.mp3';
  }

  String _decodeJsonPayload(List<int> bodyBytes, String url) {
    final body = utf8.decode(bodyBytes).replaceFirst('\uFEFF', '').trim();
    if (body.isEmpty) {
      throw Exception('Empty JSON response from $url');
    }
    return body;
  }

  Future<void> _writeTextAtomically(File target, String body) async {
    final tempFile = File('${target.path}.tmp');
    await tempFile.writeAsString(body, flush: true);
    await tempFile.rename(target.path);
  }

  Future<void> _writeBytesAtomically(File target, List<int> bodyBytes) async {
    final tempFile = File('${target.path}.tmp');
    await tempFile.writeAsBytes(bodyBytes, flush: true);
    await tempFile.rename(target.path);
  }
}
