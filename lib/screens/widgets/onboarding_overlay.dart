import 'package:voidmusic/core/constants/setting_keys.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/l10n/app_localizations.dart';
import 'package:voidmusic/l10n/language_options.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/country_setting.dart';
import 'package:voidmusic/services/audiophile_mode_service.dart';
import 'package:voidmusic/services/db/dao/settings_dao.dart';

import 'package:voidmusic/services/db/db_provider.dart';
import 'package:voidmusic/services/onboarding_service.dart';
import 'package:voidmusic/utils/country_info.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingOverlay({super.key, required this.onComplete});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  static const _cardColor = Color(0xFF14101A);
  static const _fieldColor = Color(0xFF1C1624);

  final SettingsDAO _settingsDao = SettingsDAO(DBProvider.db);

  String _selectedLang = '';
  String _selectedCountry = CountryInfoService.defaultCountryCode;
  bool _autoDetectCountry = true;
  bool _isResolvingCountry = false;
  bool _countryTouchedByUser = false;
  Locale? _currentLocale;

  int _onboardingStep = 0;
  String _selectedQualityMode = QualityModeValues.normal;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final lang =
        await _settingsDao.getSettingStr(SettingKeys.languageCode) ?? '';
    final auto =
        await _settingsDao.getSettingBool(SettingKeys.autoGetCountry) ?? true;

    final storedCountryRaw =
        await _settingsDao.getSettingStr(SettingKeys.countryCode);
    final storedCountry =
        CountryInfoService.normalizeCountryCode(storedCountryRaw);

    final country = storedCountry.isEmpty
        ? CountryInfoService.defaultCountryCode
        : storedCountry;

    final supportedCodes = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();
    final normalizedLang =
        lang.isEmpty || supportedCodes.contains(lang) ? lang : '';

    if (!mounted) return;
    setState(() {
      _selectedLang = normalizedLang;
      _selectedCountry = country;
      _autoDetectCountry = auto;
      _currentLocale = normalizedLang.isEmpty ? null : Locale(normalizedLang);
    });

    if (auto) {
      _updateAutoDetect(true);
    } else {
      _updateCountryFromDeviceLocaleIfNeeded(
        shouldGuess: storedCountry.isEmpty,
      );
    }
  }

  Future<void> _updateCountryFromDeviceLocaleIfNeeded({
    required bool shouldGuess,
  }) async {
    if (!shouldGuess) {
      return;
    }

    final guessed =
        await CountryInfoService.resolveCountryCodeFromDeviceLocale();
    if (!mounted || guessed == null || _countryTouchedByUser) {
      return;
    }

    setState(() {
      _selectedCountry = guessed;
    });
    await _settingsDao.putSettingStr(SettingKeys.countryCode, guessed);
  }

  void _updateLang(String? val) {
    if (val == null) return;
    setState(() {
      _selectedLang = val;
      _currentLocale = val.isEmpty ? null : Locale(val);
    });
    _settingsDao.putSettingStr(SettingKeys.languageCode, val);
  }

  void _updateCountry(String? val) {
    if (val == null) return;
    setState(() {
      _countryTouchedByUser = true;
      _selectedCountry = val;
      if (_autoDetectCountry) {
        _autoDetectCountry = false;
        _settingsDao.putSettingBool(SettingKeys.autoGetCountry, false);
      }
    });
    _settingsDao.putSettingStr(SettingKeys.countryCode, val);
  }

  Future<void> _updateAutoDetect(bool val) async {
    setState(() {
      _autoDetectCountry = val;
    });
    await _settingsDao.putSettingBool(SettingKeys.autoGetCountry, val);

    if (val) {
      setState(() => _isResolvingCountry = true);
      final code = await CountryInfoService.resolveAndCacheCountryCode(
        settingsDao: _settingsDao,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        _selectedCountry = code;
        _isResolvingCountry = false;
      });
    }
  }

  Future<void> _goToQualityStep() async {
    await _settingsDao.putSettingBool(
      SettingKeys.autoGetCountry,
      _autoDetectCountry,
    );
    await _settingsDao.putSettingStr(SettingKeys.countryCode, _selectedCountry);
    await _settingsDao.putSettingStr(SettingKeys.languageCode, _selectedLang);
    setState(() {
      _onboardingStep = 1;
    });
  }

  Future<void> _finish() async {
    await _settingsDao.putSettingBool(
      SettingKeys.autoGetCountry,
      _autoDetectCountry,
    );
    await _settingsDao.putSettingStr(SettingKeys.countryCode, _selectedCountry);
    await _settingsDao.putSettingStr(SettingKeys.languageCode, _selectedLang);
    await AudiophileModeService.setMode(_settingsDao, _selectedQualityMode);
    await OnboardingService.markDone(_settingsDao);
    widget.onComplete();
  }

  List<DropdownMenuItem<String>> _buildLanguageItems(AppLocalizations l10n) {
    final options = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: '',
        child: Text(l10n.countrySettingSystemDefault),
      ),
    ];

    for (final option in buildLanguageOptions()) {
      options.add(
        DropdownMenuItem(
          value: option.code,
          child: Text(option.label),
        ),
      );
    }

    return options;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Default_Theme().defaultThemeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: _currentLocale,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          if (l10n == null) {
            return const Scaffold(backgroundColor: Default_Theme.themeColor);
          }

          final languageItems = _buildLanguageItems(l10n);
          final countryItems = countries.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));

          final selectedCountry = countries.containsValue(_selectedCountry)
              ? _selectedCountry
              : CountryInfoService.defaultCountryCode;

          final textTheme = Theme.of(context).textTheme;

          return Scaffold(
            backgroundColor: Default_Theme.themeColor,
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Default_Theme.themeColor,
                    Default_Theme.themeColor.withValues(alpha: 0.95),
                    const Color(0xFF07040B),
                  ],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.accentColor(context)
                              .withValues(alpha: 0.25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: _onboardingStep == 0
                          ? _buildCountryStep(
                              context,
                              l10n,
                              textTheme,
                              languageItems,
                              countryItems,
                              selectedCountry,
                            )
                          : _buildQualityStep(context, l10n, textTheme),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCountryStep(
    BuildContext context,
    AppLocalizations l10n,
    TextTheme textTheme,
    List<DropdownMenuItem<String>> languageItems,
    List<MapEntry<String, String>> countryItems,
    String selectedCountry,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          MingCute.music_2_fill,
          size: 70,
          color: AppTheme.accentColor(context),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.onboardingTitle,
          style: textTheme.headlineMedium?.copyWith(
            color: Default_Theme.primaryColor1,
            fontWeight: FontWeight.w800,
            fontFamily: Default_Theme.secondoryTextStyle.fontFamily,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.onboardingSubtitle,
          style: textTheme.bodyLarge?.copyWith(
            color: Default_Theme.primaryColor1.withValues(alpha: 0.75),
            fontFamily: Default_Theme.secondoryTextStyle.fontFamily,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        _FieldLabel(label: l10n.countrySettingLanguageLabel),
        const SizedBox(height: 10),
        _DropdownField(
          value: _selectedLang,
          items: languageItems,
          onChanged: _updateLang,
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _FieldLabel(
                label: l10n.countrySettingAutoDetect,
              ),
            ),
            if (_isResolvingCountry)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accentColor(context),
                ),
              ),
            if (_isResolvingCountry) const SizedBox(width: 10),
            _AestheticSwitch(
              value: _autoDetectCountry,
              onChanged: _updateAutoDetect,
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedOpacity(
          opacity: _autoDetectCountry ? 0.6 : 1,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: _autoDetectCountry,
            child: _DropdownField(
              value: selectedCountry,
              items: countryItems
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.value,
                      child: Text('${e.key} (${e.value})'),
                    ),
                  )
                  .toList(),
              onChanged: _updateCountry,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _goToQualityStep,
            borderRadius: BorderRadius.circular(14),
            splashColor: Colors.white.withValues(alpha: 0.15),
            child: Ink(
              decoration: BoxDecoration(
                color: AppTheme.accentColor(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.continueButton,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black
                            : Colors.white,
                        fontFamily: 'Gilroy',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      MingCute.right_line,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQualityStep(
    BuildContext context,
    AppLocalizations l10n,
    TextTheme textTheme,
  ) {
    final accentColor = AppTheme.accentColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  _onboardingStep = 0;
                });
              },
              icon: const Icon(
                MingCute.left_line,
                color: Default_Theme.primaryColor1,
              ),
              tooltip: 'Back',
            ),
            const Spacer(),
            Icon(
              MingCute.disc_fill,
              size: 40,
              color: accentColor,
            ),
            const Spacer(),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Select Audio Quality',
          style: textTheme.headlineMedium?.copyWith(
            color: Default_Theme.primaryColor1,
            fontWeight: FontWeight.w800,
            fontFamily: Default_Theme.secondoryTextStyle.fontFamily,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your preferred playback and source ecosystem mode',
          style: textTheme.bodyLarge?.copyWith(
            color: Default_Theme.primaryColor1.withValues(alpha: 0.75),
            fontFamily: Default_Theme.secondoryTextStyle.fontFamily,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _QualityOptionCard(
          title: 'Normal Mode',
          subtitle: 'Downloads 14 standard .bex plugins for general music streaming and fast playback.',
          badgeText: '14 Plugins (.bex)',
          icon: MingCute.music_2_line,
          isSelected: _selectedQualityMode == QualityModeValues.normal,
          onTap: () {
            setState(() {
              _selectedQualityMode = QualityModeValues.normal;
            });
          },
        ),
        const SizedBox(height: 16),
        _QualityOptionCard(
          title: 'Audiophile Mode',
          subtitle: 'Downloads all 11 SpotiFLAC extensions (.sflx & .spotiflac-ext) for Lossless FLAC, HD FLAC & DSD streaming & downloads. Excludes standard .bex plugins.',
          badgeText: '11 Plugins (FLAC / DSD) 🎧',
          badgeColor: const Color(0xFFFFB703),
          icon: MingCute.headphone_line,
          isSelected: _selectedQualityMode == QualityModeValues.audiophile,
          onTap: () {
            setState(() {
              _selectedQualityMode = QualityModeValues.audiophile;
            });
          },
        ),
        const SizedBox(height: 28),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _finish,
            borderRadius: BorderRadius.circular(14),
            splashColor: Colors.white.withValues(alpha: 0.15),
            child: Ink(
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                child: Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black
                        : Colors.white,
                    fontFamily: 'Gilroy',
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Default_Theme.primaryColor1,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ).merge(Default_Theme.secondoryTextStyle),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _OnboardingOverlayState._fieldColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Default_Theme.primaryColor1.withValues(alpha: 0.12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: _OnboardingOverlayState._fieldColor,
          icon: Icon(
            MingCute.down_line,
            color: Default_Theme.primaryColor1.withValues(alpha: 0.8),
          ),
          style: const TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ).merge(Default_Theme.secondoryTextStyle),
          selectedItemBuilder: (context) {
            return items
                .map(
                  (item) => Align(
                    alignment: Alignment.centerLeft,
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        color: Default_Theme.primaryColor1,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ).merge(Default_Theme.secondoryTextStyle),
                      child: item.child,
                    ),
                  ),
                )
                .toList();
          },
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _AestheticSwitch extends StatelessWidget {
  const _AestheticSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 54,
        height: 30,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: value
              ? AppTheme.accentColor(context).withValues(alpha: 0.2)
              : Default_Theme.primaryColor1.withValues(alpha: 0.06),
          border: Border.all(
            color: value
                ? AppTheme.accentColor(context).withValues(alpha: 0.65)
                : Default_Theme.primaryColor1.withValues(alpha: 0.18),
            width: 1.4,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value
                  ? AppTheme.accentColor(context)
                  : Default_Theme.primaryColor1.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _QualityOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final Color? badgeColor;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _QualityOptionCard({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    this.badgeColor,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor(context);
    final effectiveBadgeColor = badgeColor ?? accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.12)
                : const Color(0xFF1C1624),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? accent
                  : Default_Theme.primaryColor1.withValues(alpha: 0.12),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent
                      : Default_Theme.primaryColor1.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.black : accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: Default_Theme.primaryColor1,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              fontFamily: Default_Theme
                                  .secondoryTextStyle.fontFamily,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: effectiveBadgeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: effectiveBadgeColor.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: effectiveBadgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Default_Theme.primaryColor1
                            .withValues(alpha: 0.7),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

