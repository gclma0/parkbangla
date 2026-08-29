import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Pb {
  static const yellow = Color(0xFFFFC629);
  static const yellowDeep = Color(0xFFF5B800);
  static const cream = Color(0xFFFFF8EE);
  static const ink = Color(0xFF1A1A1A);
  static const muted = Color(0xFF6B6560);
  static const card = Colors.white;
  static const stampGreen = Color(0xFF2E7D32);
  static const stampSkip = Color(0xFFC62828);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: yellow,
        onPrimary: ink,
        secondary: ink,
        surface: cream,
        onSurface: ink,
      ),
      scaffoldBackgroundColor: cream,
    );
    final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: ink,
      displayColor: ink,
    );
    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: cream,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: yellow,
          foregroundColor: ink,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: ink, width: 1.6),
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class ScaleTap extends StatefulWidget {
  const ScaleTap({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 280),
    lowerBound: 0.96,
    upperBound: 1,
    value: 1,
  );

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => c.reverse(),
      onTapUp: (_) {
        c.forward();
        widget.onTap?.call();
      },
      onTapCancel: () => c.forward(),
      child: ScaleTransition(scale: c, child: widget.child),
    );
  }
}
