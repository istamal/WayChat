import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBackdrop extends StatelessWidget {
  final Widget child;

  const AppBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [AppTheme.bgTopDark, AppTheme.bgBottomDark]
        : const [AppTheme.bgTop, AppTheme.bgBottom];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -40,
            child: _blob(
              isDark ? const Color(0x334F46E5) : const Color(0x55FF9800),
              240,
            ),
          ),
          Positioned(
            top: 80,
            right: -70,
            child: _blob(
              isDark ? const Color(0x3314B8A6) : const Color(0x5500BCD4),
              220,
            ),
          ),
          Positioned(
            bottom: -80,
            left: 40,
            child: _blob(
              isDark ? const Color(0x334338CA) : const Color(0x553F51B5),
              190,
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const GlassCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? const Color(0xFF111827).withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.78);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.55);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
