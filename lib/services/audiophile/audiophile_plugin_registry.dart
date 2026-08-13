import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AudiophilePluginManifest {
  final String id;
  final String displayName;
  final String version;
  final String description;
  final List<String> qualityOptions;
  final List<String> permissions;
  final String pluginDir;

  const AudiophilePluginManifest({
    required this.id,
    required this.displayName,
    required this.version,
    required this.description,
    required this.qualityOptions,
    required this.permissions,
    required this.pluginDir,
  });

  factory AudiophilePluginManifest.fromJson(
      Map<String, dynamic> json, String pluginDir) {
    final rawQuality = json['qualityOptions'] as List? ?? [];
    final qualityOptions = rawQuality
        .map((q) => q is Map ? (q['id'] ?? '').toString() : q.toString())
        .where((q) => q.isNotEmpty)
        .toList();

    final rawPerms = json['permissions']?['network'] as List? ?? [];
    final permissions = rawPerms.map((p) => p.toString()).toList();

    final id = (json['id'] ?? json['name'] ?? p.basename(pluginDir)).toString();
    final displayName =
        (json['displayName'] ?? json['name'] ?? id).toString();

    return AudiophilePluginManifest(
      id: id,
      displayName: displayName,
      version: (json['version'] ?? '1.0.0').toString(),
      description: (json['description'] ?? '').toString(),
      qualityOptions: qualityOptions,
      permissions: permissions,
      pluginDir: pluginDir,
    );
  }
}

class AudiophilePluginRegistry {
  static final AudiophilePluginRegistry _instance =
      AudiophilePluginRegistry._internal();
  factory AudiophilePluginRegistry() => _instance;
  AudiophilePluginRegistry._internal();

  final Map<String, AudiophilePluginManifest> _discoveredPlugins = {};

  List<AudiophilePluginManifest> get allPlugins =>
      _discoveredPlugins.values.toList();
  List<String> get pluginIds => _discoveredPlugins.keys.toList();

  /// Discover all installed plugins in desktop_plugins/ and extracted extensions
  Future<List<AudiophilePluginManifest>> discoverPlugins() async {
    final searchDirs = <Directory>[
      Directory('desktop_plugins'),
      Directory('desktop_plugins/SpotiFLAC-Extension-main/extracted'),
    ];

    try {
      final appDocs = await getApplicationDocumentsDirectory();
      searchDirs.add(Directory(p.join(appDocs.path, 'plugins')));
      searchDirs.add(Directory(p.join(appDocs.path, 'VoidMusic', 'plugins')));
      final appSupp = await getApplicationSupportDirectory();
      searchDirs.add(Directory(p.join(appSupp.path, 'plugins')));
    } catch (_) {}

    for (final dir in searchDirs) {
      if (await dir.exists()) {
        await _scanDirectory(dir);
      }
    }

    // Register built-in fallback manifests if none found on disk
    _ensureFallbackManifests();

    log('Discovered ${_discoveredPlugins.length} Audiophile plugins',
        name: 'AudiophilePluginRegistry');
    return allPlugins;
  }

  void _ensureFallbackManifests() {
    const builtins = [
      {'id': 'audiophile.deezer', 'displayName': 'Deezer Hi-Fi FLAC', 'version': '1.2.0'},
      {'id': 'audiophile.qobuz-web', 'displayName': 'Qobuz Studio Master', 'version': '1.1.0'},
      {'id': 'audiophile.tidal-web', 'displayName': 'Tidal HiRes FLAC', 'version': '1.1.2'},
      {'id': 'audiophile.ytmusic-spotiflac', 'displayName': 'YouTube Music Audiophile', 'version': '2.3.9'},
      {'id': 'audiophile.apple-music', 'displayName': 'Apple Music Lossless', 'version': '1.3.8'},
      {'id': 'audiophile.amazon', 'displayName': 'Amazon Music HD', 'version': '2.2.1'},
      {'id': 'audiophile.pandora', 'displayName': 'Pandora High Quality', 'version': '1.0.8'},
      {'id': 'audiophile.soundcloud', 'displayName': 'SoundCloud HQ', 'version': '1.0.5'},
    ];

    for (final b in builtins) {
      final id = b['id']!;
      if (!_discoveredPlugins.containsKey(id)) {
        _discoveredPlugins[id] = AudiophilePluginManifest(
          id: id,
          displayName: b['displayName']!,
          version: b['version']!,
          description: '${b['displayName']} Lossless Audio Provider',
          qualityOptions: ['flac', 'hi_res', 'ultra_flac'],
          permissions: ['api.zarz.moe', 'dl.musicdl.me'],
          pluginDir: 'builtin',
        );
      }
    }
  }

  Future<void> _scanDirectory(Directory root) async {
    try {
      final entities = await root.list(recursive: false).toList();
      for (final entity in entities) {
        if (entity is Directory) {
          final manifestFile = File(p.join(entity.path, 'manifest.json'));
          if (await manifestFile.exists()) {
            try {
              final content = await manifestFile.readAsString();
              final json = jsonDecode(content) as Map<String, dynamic>;
              final manifest =
                  AudiophilePluginManifest.fromJson(json, entity.path);
              _discoveredPlugins[manifest.id] = manifest;
              
              final base = p.basename(entity.path);
              if (!_discoveredPlugins.containsKey(base)) {
                _discoveredPlugins[base] = manifest;
              }
              if (!base.startsWith('audiophile.') && !_discoveredPlugins.containsKey('audiophile.$base')) {
                _discoveredPlugins['audiophile.$base'] = manifest;
              }
            } catch (e) {
              log('Failed to parse manifest in ${entity.path}: $e',
                  name: 'AudiophilePluginRegistry');
            }
          } else {
            final subEntities = await entity.list().toList();
            for (final sub in subEntities) {
              if (sub is Directory) {
                final subManifest = File(p.join(sub.path, 'manifest.json'));
                if (await subManifest.exists()) {
                  try {
                    final content = await subManifest.readAsString();
                    final json = jsonDecode(content) as Map<String, dynamic>;
                    final manifest =
                        AudiophilePluginManifest.fromJson(json, sub.path);
                    _discoveredPlugins[manifest.id] = manifest;

                    final base = p.basename(sub.path);
                    if (!_discoveredPlugins.containsKey(base)) {
                      _discoveredPlugins[base] = manifest;
                    }
                    if (!base.startsWith('audiophile.') && !_discoveredPlugins.containsKey('audiophile.$base')) {
                      _discoveredPlugins['audiophile.$base'] = manifest;
                    }
                  } catch (_) {}
                }
              }
            }
          }
        }
      }
    } catch (e) {
      log('Failed scanning directory ${root.path}: $e',
          name: 'AudiophilePluginRegistry');
    }
  }

  AudiophilePluginManifest? getPlugin(String id) => _discoveredPlugins[id];
}
