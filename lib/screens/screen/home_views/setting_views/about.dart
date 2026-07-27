import 'package:flutter/material.dart';
import 'package:voidmusic/l10n/app_localizations.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'dart:math';

// Gradients adapted dynamically to theme mode
Gradient getTitleGradient(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFB0B0B5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : const LinearGradient(
          colors: [Color(0xFF1C1C1E), Color(0xFF505055)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
}

Gradient getButtonGradient(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFD1D1D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : const LinearGradient(
          colors: [Color(0xFF1C1C1E), Color(0xFF3A3A3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
}

Gradient getWaveformGradient(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? const LinearGradient(
          colors: [Color(0xFFE5E5EA), Color(0xFF8E8E93)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        )
      : const LinearGradient(
          colors: [Color(0xFF1C1C1E), Color(0xFF636366)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
}

class About extends StatelessWidget {
  const About({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final cardBgColor = isDark
        ? const Color.fromRGBO(30, 30, 35, 0.45)
        : const Color.fromRGBO(240, 240, 245, 0.65);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: primaryTextColor.withValues(alpha: 0.7)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          const ParticleBackground(),
          const Positioned.fill(child: AnimatedWaveform()),
          Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 480), // Responsive constraint
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    _buildInfoCard(context, l10n, primaryTextColor, cardBgColor),
                    const SizedBox(height: 50),
                    _buildSupportSection(context, l10n, primaryTextColor),
                    const Spacer(),
                    // Footer moved to bottom of screen
                    const SizedBox(height: 12),
                    _buildFooter(context, l10n),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, AppLocalizations l10n,
      Color primaryTextColor, Color cardBgColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF66666E);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE5E5EA);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(28.0),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => getTitleGradient(context).createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                    child: const Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          'Void Music',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Gilroy',
                          ),
                        ),
                        GentleRotatingFlower(size: 24),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                l10n.aboutCraftingSubtitle,
                style: TextStyle(
                    fontSize: 16,
                    color: secondaryTextColor,
                    fontFamily: 'Gilroy'),
              ),
              const SizedBox(height: 35),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.35)
                      : const Color(0xFFE5E5EA).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: getButtonGradient(context),
                        boxShadow: [
                          BoxShadow(
                            color: primaryTextColor.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                          backgroundColor: Colors.transparent, radius: 10),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        '@siamislamtalha',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          fontFamily: 'Gilroy',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 35),
              Wrap(
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 12.0,
                spacing: 12.0,
                children: [
                  _InfoPill(
                      icon: Icons.shield_outlined,
                      text: 'Maintainer',
                      tooltip: l10n.aboutFollowGitHub,
                      onTap: () {
                        launchUrl(Uri.parse('https://github.com/siamislamtalha'),
                            mode: LaunchMode.externalApplication);
                      }),
                  _InfoPill(
                      icon: FontAwesome.x_twitter_brand,
                      text: 'Contact',
                      tooltip: l10n.aboutSendInquiry,
                      onTap: () {
                        launchUrl(
                          Uri.parse('https://x.com/siamislamtalha'),
                          mode: LaunchMode.externalApplication,
                        );
                      }),
                  _InfoPill(
                      icon: FontAwesome.linkedin_brand,
                      text: 'Linkedin',
                      tooltip: l10n.aboutCreativeHighlights,
                      onTap: () {
                        launchUrl(
                            Uri.parse('https://linkedin.com/in/siamislamtalha'),
                            mode: LaunchMode.externalApplication);
                      }),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context, AppLocalizations l10n, Color primaryTextColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF66666E);
    final buttonTextColor = isDark ? Colors.black : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            l10n.aboutTipQuote,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: secondaryTextColor, fontSize: 14, fontFamily: 'Gilroy'),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: getButtonGradient(context),
            borderRadius: BorderRadius.circular(34.0),
            boxShadow: [
              BoxShadow(
                color: primaryTextColor.withValues(alpha: 0.15),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(32.0),
              onTap: () {
                launchUrl(
                  Uri.parse("https://siamislamtalha.github.io/Void-Music/"),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 44, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32.0),
                  border:
                      Border.all(color: primaryTextColor.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite,
                        color: buttonTextColor, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      l10n.aboutTipButton,
                      style: TextStyle(
                        color: buttonTextColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Gilroy',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.aboutTipDesc,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: secondaryTextColor, fontSize: 14, fontFamily: 'Gilroy'),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF66666E);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                launchUrl(
                    Uri.parse("https://siamislamtalha.github.io/Void-Music/"),
                    mode: LaunchMode.externalApplication);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(MingCute.github_fill,
                      color: secondaryTextColor, size: 16),
                  const SizedBox(width: 8),
                  Text(l10n.aboutGitHub,
                      style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                          fontFamily: 'Gilroy')),
                ],
              ),
            ),
            const SizedBox(width: 18),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final ver = snapshot.hasData
                    ? 'v${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                    : 'Not able to retrieve version';
                return Text(ver,
                    style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                        fontFamily: 'Gilroy'));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? tooltip;
  final VoidCallback? onTap;
  const _InfoPill(
      {required this.icon, required this.text, this.onTap, this.tooltip});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF66666E);

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: secondaryTextColor, size: 18),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
                color: secondaryTextColor,
                fontSize: 13,
                fontFamily: 'Gilroy')),
      ],
    );

    Widget result = InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
        child: child,
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      result = Tooltip(message: tooltip!, child: result);
    }

    if (onTap == null) return child;

    return result;
  }
}

class AnimatedWaveform extends StatefulWidget {
  const AnimatedWaveform({super.key});
  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: WaveformPainter(_controller.value, context),
          );
        });
  }
}

class WaveformPainter extends CustomPainter {
  final double time;
  final BuildContext context;
  WaveformPainter(this.time, this.context);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final waveGradient = getWaveformGradient(context);
    final animatedGradient = LinearGradient(
        colors: waveGradient.colors,
        transform: GradientRotation(2 * pi * time));
    paint.shader = animatedGradient
        .createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    for (double x = -5; x <= size.width + 5; x++) {
      final amp = size.height * 0.1;
      final y = size.height / 2 +
          (amp) * sin(x * 0.015 + time * 2 * pi) +
          (amp * 0.5) * sin(x * 0.025 + time * 4 * pi);
      if (x == -5) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) =>
      time != oldDelegate.time;
}

class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key});
  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> _particles;
  final int _numberOfParticles = 40;
  final Random _random = Random();
  late double _lastTickSeconds;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
    _lastTickSeconds = DateTime.now().millisecondsSinceEpoch / 1000.0;
    _particles =
        List.generate(_numberOfParticles, (index) => _createParticle());
  }

  Particle _createParticle() {
    return Particle(
      position: Offset(_random.nextDouble(), _random.nextDouble()),
      radius: _random.nextDouble() * 1.5 + 0.5,
      velocity: Offset((_random.nextDouble() - 0.5) * 0.01,
          -(_random.nextDouble() * 0.02 + 0.002)),
      lifespan: _random.nextDouble() * 8 + 4,
      isSharp: _random.nextDouble() > 0.4,
      maxLifespan: 0.0,
    )..maxLifespan = _random.nextDouble() * 8 + 4;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
          final dt = (now - _lastTickSeconds).clamp(0.0, 0.05);
          _lastTickSeconds = now;

          for (var p in _particles) {
            p.lifespan -= dt;
            p.position = Offset(p.position.dx + p.velocity.dx * dt,
                p.position.dy + p.velocity.dy * dt);

            if (p.lifespan <= 0) {
              p.position = Offset(
                  _random.nextDouble(), 1.02 + _random.nextDouble() * 0.06);
              p.lifespan = _random.nextDouble() * 8 + 4;
              p.maxLifespan = p.lifespan;
              p.velocity = Offset((_random.nextDouble() - 0.5) * 0.01,
                  -(_random.nextDouble() * 0.02 + 0.002));
            }

            if (p.position.dx < -0.1) p.position = Offset(1.1, p.position.dy);
            if (p.position.dx > 1.1) p.position = Offset(-0.1, p.position.dy);
            if (p.position.dy < -0.2) {
              p.position =
                  Offset(p.position.dx, 1.02 + _random.nextDouble() * 0.06);
            }
          }
          return CustomPaint(
              size: Size.infinite, painter: ParticlePainter(_particles, context));
        });
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final BuildContext context;
  ParticlePainter(this.particles, this.context);
  @override
  void paint(Canvas canvas, Size size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rect = Rect.fromCircle(
        center: size.center(Offset.zero), radius: size.width * 0.9);
    final bgPaint = Paint()
      ..shader = RadialGradient(colors: [
        isDark ? const Color(0x33FFFFFF) : const Color(0x1A000000),
        Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0)
      ]).createShader(rect);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final paint = Paint();
    final particleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    for (var p in particles) {
      final progress = 1.0 - (p.lifespan / p.maxLifespan);
      final opacity = max(0.0, -4 * (progress - 0.5) * (progress - 0.5) + 1);

      paint.color = particleColor.withValues(alpha: opacity * 0.25);
      paint.maskFilter =
          p.isSharp ? null : MaskFilter.blur(BlurStyle.normal, p.radius * 2);

      canvas.drawCircle(
          Offset(p.position.dx * size.width, p.position.dy * size.height),
          p.radius,
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Particle {
  Offset position;
  final double radius;
  Offset velocity;
  double lifespan;
  double maxLifespan;
  final bool isSharp;

  Particle(
      {required this.position,
      required this.radius,
      required this.velocity,
      required this.lifespan,
      required this.maxLifespan,
      required this.isSharp});
}

class GentleRotatingFlower extends StatefulWidget {
  final double size;
  const GentleRotatingFlower({this.size = 28, super.key});

  @override
  State<GentleRotatingFlower> createState() => _GentleRotatingFlowerState();
}

class _GentleRotatingFlowerState extends State<GentleRotatingFlower>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1C1C1E);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final angle = sin(t * 2 * pi) * (pi / 20);
        final scale = 1 + 0.03 * sin(t * 2 * pi);
        final dx = 2.0 * sin(t * 2 * pi);

        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: scale,
              child: Icon(
                MingCute.sparkles_2_fill,
                size: widget.size,
                color: iconColor,
              ),
            ),
          ),
        );
      },
    );
  }
}
