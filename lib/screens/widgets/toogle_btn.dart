import 'package:flutter/material.dart';

class ToggleButton extends StatefulWidget {
  final String label;
  final ValueChanged<bool>
      onChanged; // Callback with current state (true/false)
  final bool initialState; // Parameter to set initial state

  const ToggleButton({
    Key? key,
    required this.label,
    required this.onChanged,
    this.initialState = false, // Default to false (inactive)
  }) : super(key: key);

  @override
  ToggleButtonState createState() => ToggleButtonState();
}

class ToggleButtonState extends State<ToggleButton>
    with SingleTickerProviderStateMixin {
  late bool _isActive;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _isActive = widget.initialState; // Set initial state from parameter
    _animationController = AnimationController(
      duration:
          const Duration(milliseconds: 200), // Lightweight, fast animation
      vsync: this,
    );
    if (_isActive) _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void updateState(bool newState) {
    setState(() {
      _isActive = newState;
    });
    if (_isActive) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    widget.onChanged(_isActive); // Notify parent of state change
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final activeText = isDark ? Colors.black : Colors.white;
    final inactiveBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF0F0F3);
    final inactiveText = isDark ? Colors.white70 : const Color(0xFF66666E);
    final inactiveBorder = isDark ? Colors.white24 : const Color(0xFFE5E5EA);

    return GestureDetector(
      onTap: () {
        updateState(!_isActive);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: _isActive ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isActive ? activeBg : inactiveBorder,
            width: 1.5,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.label,
            style: TextStyle(
              color: _isActive ? activeText : inactiveText,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Gilroy',
            ),
          ),
        ),
      ),
    );
  }
}
