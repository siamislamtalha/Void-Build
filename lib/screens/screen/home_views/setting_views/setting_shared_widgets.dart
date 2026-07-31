import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/custom_switch.dart';
import 'package:flutter/material.dart';

class SettingSectionHeader extends StatelessWidget {
  final String label;
  const SettingSectionHeader({required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark ? Default_Theme.primaryColor2 : const Color(0xFF66666E);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Text(
        label.toUpperCase(),
        style: Default_Theme.secondoryTextStyleMedium.copyWith(
          color: subtitleColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class SettingCard extends StatelessWidget {
  final List<Widget> children;
  const SettingCard({required this.children, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Default_Theme.cardSurfaceColor : Colors.white;
    final borderColor = isDark ? Default_Theme.cardBorderColor : const Color(0xFFE5E5EA);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Performance Fix
        children: children,
      ),
    );
  }
}

class SettingDivider extends StatelessWidget {
  const SettingDivider({super.key});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Default_Theme.cardBorderColor : const Color(0xFFE5E5EA);

    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: borderColor,
    );
  }
}

class SettingIconBox extends StatelessWidget {
  final IconData icon;
  final Color? color;
  const SettingIconBox({required this.icon, this.color, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Default_Theme.cardSurfaceColor : const Color(0xFFF0F0F3);
    final borderColor = isDark ? Default_Theme.cardBorderColor : const Color(0xFFE5E5EA);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 20,
          color: color ?? Default_Theme.primaryColor2.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

// CONVERTED TO STATEFUL WIDGET FOR INSTANT SWITCH ANIMATION
class SettingToggleTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  @override
  State<SettingToggleTile> createState() => _SettingToggleTileState();
}

class _SettingToggleTileState extends State<SettingToggleTile> {
  late bool _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(SettingToggleTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          SettingIconBox(icon: widget.icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min, // Layout Performance Fix
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: Default_Theme.secondoryTextStyleMedium.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: Default_Theme.secondoryTextStyle.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          VoidMusicSwitch(
            value: _currentValue,
            onChanged: () {
              final newValue = !_currentValue;
              _currentValue = newValue;
              widget.onChanged(newValue);
            },
          ),
        ],
      ),
    );
  }
}

class SettingNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;
  final bool roundBottom;

  const SettingNavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.roundBottom = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: roundBottom
            ? const BorderRadius.vertical(bottom: Radius.circular(20))
            : BorderRadius.circular(20),
        highlightColor: colorScheme.onSurface.withValues(alpha: 0.05),
        splashColor: colorScheme.onSurface.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              SettingIconBox(icon: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Layout Performance Fix
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Default_Theme.secondoryTextStyleMedium.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Default_Theme.secondoryTextStyle.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.accentColor(context).withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    badge!,
                    style: Default_Theme.secondoryTextStyle.copyWith(
                      color: AppTheme.accentColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Icon(Icons.chevron_right_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingRadioTile<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final T value;
  final T groupValue;
  final ValueChanged<T?> onChanged;

  const SettingRadioTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(20),
        highlightColor: colorScheme.onSurface.withValues(alpha: 0.05),
        splashColor: colorScheme.onSurface.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Layout Performance Fix
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Default_Theme.secondoryTextStyleMedium.copyWith(
                        color: isSelected
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Default_Theme.secondoryTextStyle.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
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

class SettingQualityChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SettingQualityChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: colorScheme.primary.withValues(alpha: 0.1),
        highlightColor: colorScheme.primary.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.onSurface.withValues(alpha: 0.10)
                : colorScheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.onSurface.withValues(alpha: 0.35)
                  : colorScheme.onSurface.withValues(alpha: 0.07),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: Default_Theme.secondoryTextStyleMedium.copyWith(
              color: isSelected
                  ? colorScheme.onSurface
                  : colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class SettingQualityChipRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const SettingQualityChipRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Layout Performance Fix
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SettingIconBox(icon: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Default_Theme.secondoryTextStyleMedium.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Default_Theme.secondoryTextStyle.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options
                .map((opt) => SettingQualityChip(
                      label: opt,
                      isSelected: opt == selected,
                      onTap: () => onSelected(opt),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class SettingDestructiveTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SettingDestructiveTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        highlightColor: Colors.red.withValues(alpha: 0.05),
        splashColor: Colors.red.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.15),
                  ),
                ),
                child: Center(
                  child: Icon(icon,
                      size: 20, color: Colors.red.withValues(alpha: 0.7)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Layout Performance Fix
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Default_Theme.secondoryTextStyleMedium.copyWith(
                        color: Colors.red.withValues(alpha: 0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Default_Theme.secondoryTextStyle.copyWith(
                        color: Colors.red.withValues(alpha: 0.45),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.red.withValues(alpha: 0.3), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingInfoText extends StatelessWidget {
  final String text;
  final Color? color;
  const SettingInfoText({required this.text, this.color, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        text,
        style: Default_Theme.secondoryTextStyle.copyWith(
          color: color ?? colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}

class SettingSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Default_Theme.primaryColor1 : Default_Theme.primaryColor2;
    final subtitleColor = isDark ? Default_Theme.primaryColor2 : const Color(0xFF66666E);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          SettingIconBox(icon: icon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class SettingDropdownTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final List<String> options;
  final List<String> labels;
  final ValueChanged<String> onChanged;

  const SettingDropdownTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.labels,
    required this.onChanged,
    super.key,
  });

  String _selectedLabel() {
    final index = options.indexOf(value);
    if (index >= 0 && index < labels.length) {
      return labels[index];
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Default_Theme.primaryColor1 : Default_Theme.primaryColor2;
    final titleColor = isDark ? Default_Theme.primaryColor1 : Default_Theme.primaryColor2;
    final subtitleColor = isDark ? Default_Theme.primaryColor2 : const Color(0xFF66666E);
    final accentColor = AppTheme.accentColor(context);

    return InkWell(
      onTap: () => _openSelector(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            SettingIconBox(icon: icon),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Text(
                  _selectedLabel(),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: iconColor.withValues(alpha: 0.4),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SimpleDropdownBottomSheet(
        title: title,
        options: options,
        labels: labels,
        currentValue: value,
        onSelected: (selected) {
          onChanged(selected);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _SimpleDropdownBottomSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final List<String> labels;
  final String currentValue;
  final ValueChanged<String> onSelected;

  const _SimpleDropdownBottomSheet({
    required this.title,
    required this.options,
    required this.labels,
    required this.currentValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Default_Theme.primaryColor1 : Default_Theme.primaryColor2;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Default_Theme.cardBorderColor : const Color(0xFFE5E5EA);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: borderColor,
                ),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: iconColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final label = labels.length > index ? labels[index] : option;
            final isSelected = option == currentValue;

            return InkWell(
              onTap: () => onSelected(option),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: borderColor,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check,
                        color: AppTheme.accentColor(context),
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class SettingTextFieldTile extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  const SettingTextFieldTile({
    required this.label,
    required this.controller,
    this.keyboardType,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 13,
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
                color: colorScheme.onSurface.withValues(alpha: 0.2)),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

class SettingDropdownItem<T> {
  final T value;
  final String label;
  final String? description;
  final IconData? icon;

  const SettingDropdownItem({
    required this.value,
    required this.label,
    this.description,
    this.icon,
  });
}
