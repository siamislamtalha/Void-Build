import 'dart:convert';
import 'dart:async';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:voidmusic/services/db/dao/settings_dao.dart';
import 'package:voidmusic/plugins/models/plugin_repository.dart';

class PluginRepositoryService {
  final SettingsDAO _settingsDao;
  static const String _reposKey = 'user_plugin_repositories';
  static Future<void> _mutationChain = Future<void>.value();

  PluginRepositoryService({required SettingsDAO settingsDao})
      : _settingsDao = settingsDao;

  Future<T> _enqueueMutation<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _mutationChain = _mutationChain.catchError((_) {}).then((_) async {
      try {
        completer.complete(await action());
      } catch (e, stack) {
        completer.completeError(e, stack);
      }
    });
    return completer.future;
  }

  /// Fetch and parse a repository from [url].
  ///
  /// Retries up to [_fetchRetries] times on transient network errors
  /// (e.g. GitHub releases CDN dropping the connection mid-redirect).
  /// Network errors and JSON parse errors are surfaced with distinct
  /// prefixes so callers can classify them correctly.
  static const int _fetchRetries = 3;

  Future<PluginRepositoryModel> fetchRepository(String url) async {
    Object? lastError;
    for (int attempt = 1; attempt <= _fetchRetries; attempt++) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }
        try {
          final jsonMap = jsonDecode(response.body);
          return PluginRepositoryModel.fromJson(url, jsonMap);
        } on FormatException catch (e) {
          // Real JSON parse failure — do not retry.
          throw Exception('JSON parse error at $url: $e');
        }
      } catch (e) {
        lastError = e;
        final msg = e.toString();
        // Only retry on transient network-level errors.
        final isTransient = msg.contains('ClientException') ||
            msg.contains('Connection closed') ||
            msg.contains('SocketException') ||
            msg.contains('TimeoutException') ||
            msg.contains('Connection reset');
        if (!isTransient || attempt == _fetchRetries) {
          break;
        }
        log('Fetch attempt $attempt failed for $url ($e), retrying...',
            name: 'PluginRepositoryService');
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
    // Distinguish network errors from parse errors for upstream classifiers.
    final errStr = lastError.toString();
    if (errStr.contains('JSON parse error')) {
      throw Exception('Failed to parse repository at $url: $lastError');
    }
    throw Exception('Failed to fetch repository at $url: $lastError');
  }

  /// Get the list of saved repository URLs
  Future<List<String>> getSavedRepositoryUrls() async {
    final urlsJson = await _settingsDao.getSettingStr(_reposKey);
    if (urlsJson != null && urlsJson.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(urlsJson);
        return list.map((e) => e.toString()).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  /// Add a new repository URL
  Future<void> addRepositoryUrl(String url) async {
    await ensureRepositoryUrls(<String>[url]);
  }

  /// Remove a repository URL
  Future<void> removeRepositoryUrl(String url) async {
    await _enqueueMutation(() async {
      final urls = await getSavedRepositoryUrls();
      if (urls.contains(url)) {
        urls.remove(url);
        await _settingsDao.putSettingStr(_reposKey, jsonEncode(urls));
      }
    });
  }

  Future<int> ensureRepositoryUrls(Iterable<String> urls) {
    return _enqueueMutation(() async {
      final existing = (await getSavedRepositoryUrls()).toSet();
      final validToAdd = urls
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .where((e) => Uri.tryParse(e)?.isAbsolute ?? false)
          .where((e) => !existing.contains(e))
          .toList(growable: false);

      if (validToAdd.isEmpty) return 0;

      existing.addAll(validToAdd);
      final updated = existing.toList()..sort();
      await _settingsDao.putSettingStr(_reposKey, jsonEncode(updated));
      return validToAdd.length;
    });
  }
}
