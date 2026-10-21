import 'package:flutter/material.dart';

/// Paleta dark neon do Co Pilot.
class Neon {
  static const bg = Color(0xFF07070D);
  static const surface = Color(0xFF10101C);
  static const surfaceHi = Color(0xFF181829);
  static const cyan = Color(0xFF00F0FF);
  static const magenta = Color(0xFFFF2BD6);
  static const lime = Color(0xFFB6FF3B);
  static const amber = Color(0xFFFFC53D);
  static const red = Color(0xFFFF3B5C);
  static const text = Color(0xFFEAEAF5);
  static const textDim = Color(0xFF8A8AA3);

  static Color forVerdict(String verdict) {
    switch (verdict) {
      case 'ACCEPT':
        return lime;
      case 'MAYBE':
        return amber;
      default:
        return red;
    }
  }

  static String labelForVerdict(String verdict) {
    switch (verdict) {
      case 'ACCEPT':
        return 'ACEITAR';
      case 'MAYBE':
        return 'AVALIAR';
      default:
        return 'RECUSAR';
    }
  }

  static Color forSemaforo(String status) {
    switch (status.toUpperCase()) {
      case 'GOOD':
        return const Color(0xFF22C55E); // Verde
      case 'REGULAR':
        return const Color(0xFFF59E0B); // Amarelo
      case 'BAD':
      default:
        return const Color(0xFFEF4444); // Vermelho
    }
  }

  static Color tarjaBg(String status) {
    switch (status.toUpperCase()) {
      case 'GOOD':
        return const Color(0xFF15803D);
      case 'REGULAR':
        return const Color(0xFFB45309);
      case 'BAD':
      default:
        return const Color(0xFF991B1B);
    }
  }

  static String labelForSemaforo(String status) {
    switch (status.toUpperCase()) {
      case 'GOOD':
        return 'BOM';
      case 'REGULAR':
        return 'ATENÇÃO';
      case 'BAD':
      default:
        return 'RUIM';
    }
  }

  static List<BoxShadow> glow(Color c, {double blur = 18, double alpha = 0.35}) => [
        BoxShadow(color: c.withValues(alpha: alpha), blurRadius: blur, spreadRadius: 0),
      ];
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Neon.bg,
    colorScheme: const ColorScheme.dark(
      primary: Neon.cyan,
      secondary: Neon.magenta,
      surface: Neon.surface,
      error: Neon.red,
      onSurface: Neon.text,
    ),
    textTheme: base.textTheme.apply(bodyColor: Neon.text, displayColor: Neon.text),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Neon.surface,
      indicatorColor: Neon.cyan.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? Neon.cyan : Neon.textDim,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Neon.cyan : Neon.textDim),
      ),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: Neon.cyan,
      inactiveTrackColor: Neon.surfaceHi,
      thumbColor: Neon.cyan,
      overlayColor: Neon.cyan.withValues(alpha: 0.15),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Neon.cyan : Neon.textDim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Neon.cyan.withValues(alpha: 0.3) : Neon.surfaceHi,
      ),
    ),
  );
}

/// Cartão com borda neon e brilho suave.
class NeonCard extends StatelessWidget {
  const NeonCard({
    super.key,
    required this.child,
    this.color = Neon.cyan,
    this.padding = const EdgeInsets.all(16),
    this.glowing = false,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final bool glowing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Neon.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: glowing ? 0.9 : 0.35), width: 1.2),
        boxShadow: glowing ? Neon.glow(color) : null,
      ),
      child: child,
    );
  }
}
