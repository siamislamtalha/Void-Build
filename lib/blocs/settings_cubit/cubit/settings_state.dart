// ignore_for_file: public_member_api_docs, sort_constructors_first
part of 'settings_cubit.dart';

class SettingsState extends Equatable {
  final bool settingsReady; // true only after all settings loaded from DB
  final bool autoUpdateNotify;
  final bool autoSlideCharts;
  final String downPath;
  final String downQuality;
  final String strmQuality;
  final String backupPath;
  final bool autoBackup;
  final String historyClearTime;
  final bool autoGetCountry;
  final bool lFMPicks;
  final bool lastFMScrobble;
  final bool autoSaveLyrics;
  final bool autoPlay;
  final bool autoResolveUnavailableTracks;
  final String languageCode;
  final String countryCode;
  final Map chartMap;
  final int crossfadeDuration; // seconds, 0 = disabled
  final bool eqEnabled;
  final List<double> eqBandGains; // 10 gains, -15..+15 dB
  final String eqPreset;

  /// EQ routing source: 'builtin' or 'device'.
  /// See [EqSourceValues] for valid values.
  final String eqSource;

  final List<String> homePluginIds; // content resolver plugins for home sections (priority order)
  final List<String> searchPluginIds; // search plugins (priority order)
  final List<String> resolverPriority; // content resolver priority order
  final List<String> lyricsPriority; // lyrics provider plugin priority order
  final List<String> suggestionPluginIds; // search suggestion provider plugins (priority order)
  final List<String> downloadPluginIds; // content resolver plugins for downloads (priority order)

  const SettingsState({
    required this.settingsReady,
    required this.autoUpdateNotify,
    required this.autoSlideCharts,
    required this.downPath,
    required this.downQuality,
    required this.strmQuality,
    required this.backupPath,
    required this.autoBackup,
    required this.historyClearTime,
    required this.autoGetCountry,
    required this.languageCode,
    required this.countryCode,
    required this.autoSaveLyrics,
    required this.lFMPicks,
    required this.lastFMScrobble,
    required this.chartMap,
    required this.autoPlay,
    required this.autoResolveUnavailableTracks,
    required this.crossfadeDuration,
    required this.eqEnabled,
    required this.eqBandGains,
    required this.eqPreset,
    required this.eqSource,
    required this.homePluginIds,
    required this.searchPluginIds,
    required this.resolverPriority,
    required this.lyricsPriority,
    required this.suggestionPluginIds,
    required this.downloadPluginIds,
  });

  SettingsState copyWith({
    bool? settingsReady,
    bool? autoUpdateNotify,
    bool? autoSlideCharts,
    String? downPath,
    String? downQuality,
    String? strmQuality,
    String? backupPath,
    bool? autoBackup,
    String? historyClearTime,
    bool? autoGetCountry,
    String? languageCode,
    String? countryCode,
    bool? lFMPicks,
    bool? lastFMScrobble,
    Map? chartMap,
    bool? autoSaveLyrics,
    bool? autoPlay,
    bool? autoResolveUnavailableTracks,
    int? crossfadeDuration,
    bool? eqEnabled,
    List<double>? eqBandGains,
    String? eqPreset,
    String? eqSource,
    List<String>? homePluginIds,
    List<String>? searchPluginIds,
    List<String>? resolverPriority,
    List<String>? lyricsPriority,
    List<String>? suggestionPluginIds,
    List<String>? downloadPluginIds,
  }) {
    return SettingsState(
      settingsReady: settingsReady ?? this.settingsReady,
      autoUpdateNotify: autoUpdateNotify ?? this.autoUpdateNotify,
      autoSlideCharts: autoSlideCharts ?? this.autoSlideCharts,
      downPath: downPath ?? this.downPath,
      downQuality: downQuality ?? this.downQuality,
      strmQuality: strmQuality ?? this.strmQuality,
      backupPath: backupPath ?? this.backupPath,
      autoBackup: autoBackup ?? this.autoBackup,
      historyClearTime: historyClearTime ?? this.historyClearTime,
      autoGetCountry: autoGetCountry ?? this.autoGetCountry,
      languageCode: languageCode ?? this.languageCode,
      countryCode: countryCode ?? this.countryCode,
      lFMPicks: lFMPicks ?? this.lFMPicks,
      lastFMScrobble: lastFMScrobble ?? this.lastFMScrobble,
      chartMap: Map.from(chartMap ?? this.chartMap),
      autoSaveLyrics: autoSaveLyrics ?? this.autoSaveLyrics,
      autoPlay: autoPlay ?? this.autoPlay,
      autoResolveUnavailableTracks:
          autoResolveUnavailableTracks ?? this.autoResolveUnavailableTracks,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      eqEnabled: eqEnabled ?? this.eqEnabled,
      eqBandGains: eqBandGains != null
          ? List<double>.from(eqBandGains)
          : List<double>.from(this.eqBandGains),
      eqPreset: eqPreset ?? this.eqPreset,
      eqSource: eqSource ?? this.eqSource,
      homePluginIds: homePluginIds != null
          ? List<String>.from(homePluginIds)
          : List<String>.from(this.homePluginIds),
      searchPluginIds: searchPluginIds != null
          ? List<String>.from(searchPluginIds)
          : List<String>.from(this.searchPluginIds),
      resolverPriority: resolverPriority != null
          ? List<String>.from(resolverPriority)
          : List<String>.from(this.resolverPriority),
      lyricsPriority: lyricsPriority != null
          ? List<String>.from(lyricsPriority)
          : List<String>.from(this.lyricsPriority),
      suggestionPluginIds: suggestionPluginIds != null
          ? List<String>.from(suggestionPluginIds)
          : List<String>.from(this.suggestionPluginIds),
      downloadPluginIds: downloadPluginIds != null
          ? List<String>.from(downloadPluginIds)
          : List<String>.from(this.downloadPluginIds),
    );
  }

  @override
  List<Object?> get props => [
        settingsReady,
        autoUpdateNotify,
        autoSlideCharts,
        downPath,
        downQuality,
        strmQuality,
        backupPath,
        autoBackup,
        historyClearTime,
        autoGetCountry,
        languageCode,
        countryCode,
        chartMap,
        lFMPicks,
        lastFMScrobble,
        autoSaveLyrics,
        autoPlay,
        autoResolveUnavailableTracks,
        crossfadeDuration,
        eqEnabled,
        eqBandGains,
        eqPreset,
        eqSource,
        homePluginIds,
        searchPluginIds,
        resolverPriority,
        lyricsPriority,
        suggestionPluginIds,
        downloadPluginIds,
      ];
}

class SettingsInitial extends SettingsState {
  SettingsInitial()
      : super(
          settingsReady: false,
          autoUpdateNotify: false,
          autoSlideCharts: true,
          downPath: "",
          downQuality: "Medium",
          strmQuality: "High",
          backupPath: "",
          autoBackup: true,
          historyClearTime: "30",
          autoGetCountry: true,
          languageCode: '',
          countryCode: "US",
          chartMap: {},
          lFMPicks: false,
          lastFMScrobble: true,
          autoSaveLyrics: false,
          autoPlay: true,
          autoResolveUnavailableTracks: true,
          crossfadeDuration: 2,
          eqEnabled: false,
          eqBandGains: List<double>.filled(10, 0.0),
          eqPreset: 'Flat',
          eqSource: EqSourceValues.builtin,
          homePluginIds: const [],
          searchPluginIds: const [],
          resolverPriority: const [],
          lyricsPriority: const [],
          suggestionPluginIds: const [],
          downloadPluginIds: const [],
        );
}
