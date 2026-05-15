import 'offline_cache_service.dart';

Future<dynamic> fetchJson(String url) async {
  return OfflineCacheService.instance.fetchJson(url);
}
