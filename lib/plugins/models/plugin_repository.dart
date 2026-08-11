import 'package:voidmusic/utils/country_info.dart';

class RemotePluginModel {
  final String assetName;
  final String description;
  final String id;
  final String name;
  final String manifestVersion;
  final String type;
  final String version;
  final String downloadUrl;
  final String? thumbnailUrl;
  final String? publisherName;
  final List<String> countryAllowlist;
  final DateTime? lastUpdated;

  RemotePluginModel({
    required this.assetName,
    required this.description,
    required this.id,
    required this.name,
    required this.manifestVersion,
    required this.type,
    required this.version,
    required this.downloadUrl,
    this.thumbnailUrl,
    this.publisherName,
    this.countryAllowlist = const [],
    this.lastUpdated,
  });

  factory RemotePluginModel.fromJson(Map<String, dynamic> json) {
    return RemotePluginModel(
      assetName: json['asset_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      manifestVersion: json['manifest_version']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      downloadUrl: json['download_url']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString(),
      publisherName: json['publisher'] != null
          ? json['publisher']['name']?.toString()
          : null,
      countryAllowlist:
          (json['country_allowlist'] as List<dynamic>? ?? const [])
              .map((value) =>
                  CountryInfoService.normalizeCountryCode(value?.toString()))
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort(),
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'].toString())
          : null,
    );
  }

  bool isAllowedInCountry(String countryCode) {
    // Country restrictions removed - all plugins available to all countries regardless of location
    return true;
  }
}

class PluginRepositoryModel {
  final String url;
  final String schemaVersion;
  final String name;
  final String description;
  final String? thumbnailUrl;
  final List<RemotePluginModel> plugins;
  final DateTime? generatedAt;

  PluginRepositoryModel({
    required this.url,
    required this.schemaVersion,
    required this.name,
    required this.description,
    this.thumbnailUrl,
    required this.plugins,
    this.generatedAt,
  });

  factory PluginRepositoryModel.fromJson(
      String url, Map<String, dynamic> json) {
    // Parse top-level plugins list
    final topLevelPlugins = (json['plugins'] as List? ?? [])
        .map((p) => RemotePluginModel.fromJson(Map<String, dynamic>.from(p)))
        .toList();

    // Also parse audiophile plugins from categories.Audiophile.plugins
    // (used by bex-factory.json to separate hi-res plugins from standard ones)
    final List<RemotePluginModel> audiophilePlugins = [];
    final categories = json['categories'];
    if (categories is Map) {
      final audiophileCategory = categories['Audiophile'];
      if (audiophileCategory is Map) {
        final catPlugins = audiophileCategory['plugins'] as List?;
        if (catPlugins != null) {
          for (final p in catPlugins) {
            if (p is Map) {
              audiophilePlugins.add(
                RemotePluginModel.fromJson(Map<String, dynamic>.from(p)),
              );
            }
          }
        }
      }
    }

    // Merge both lists (avoid duplicates by ID)
    final seenIds = <String>{};
    final allPlugins = <RemotePluginModel>[];
    for (final plugin in [...topLevelPlugins, ...audiophilePlugins]) {
      if (seenIds.add(plugin.id)) {
        allPlugins.add(plugin);
      }
    }

    // Handle both standard repository format and bex-factory format
    // bex-factory format has generated_at and plugins, but may not have plugin_count
    final isBexFactoryFormat = json.containsKey('generated_at') &&
        json.containsKey('plugins') &&
        !json.containsKey('schema_version');

    if (isBexFactoryFormat) {
      // bex-factory format: has generated_at, plugins, and optional categories
      return PluginRepositoryModel(
        url: url,
        schemaVersion: '1.0', // Default for bex-factory
        name: json['name']?.toString() ?? 'Void Factory',
        description:
            json['description']?.toString() ?? 'Void Music Plugin Factory',
        thumbnailUrl: json['thumbnail_url']?.toString(),
        plugins: allPlugins,
        generatedAt: json['generated_at'] != null
            ? DateTime.tryParse(json['generated_at'].toString())
            : null,
      );
    } else {
      // Standard repository format: has schema_version, name, description
      return PluginRepositoryModel(
        url: url,
        schemaVersion: json['schema_version']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Unknown Repository',
        description: json['description']?.toString() ?? '',
        thumbnailUrl: json['thumbnail_url']?.toString(),
        plugins: allPlugins,
        generatedAt: json['generated_at'] != null
            ? DateTime.tryParse(json['generated_at'].toString())
            : null,
      );
    }
  }
}
