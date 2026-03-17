import 'package:flutter/material.dart';

/// ألوان التطبيق - تصميم أسود احترافي للأمان
class AppColors {
  AppColors._();

  // الألوان الأساسية - أسود بالكامل
  static const Color primaryBlack = Color(0xFF000000);
  static const Color deepBlack = Color(0xFF0A0A0A);
  static const Color softBlack = Color(0xFF121212);
  static const Color charcoal = Color(0xFF1A1A1A);
  static const Color darkGrey = Color(0xFF252525);
  static const Color mediumGrey = Color(0xFF2D2D2D);
  
  // الألوان الثانوية - لمسات معدنية
  static const Color silver = Color(0xFFB8B8B8);
  static const Color platinum = Color(0xFFE5E5E5);
  static const Color white = Color(0xFFFFFFFF);
  
  // ألوان التوهج والإضاءة
  static const Color neonBlue = Color(0xFF00D4FF);
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonPurple = Color(0xFF8B5CF6);
  static const Color electricBlue = Color(0xFF3B82F6);
  
  // ألوان الحالة
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF06B6D4);
  
  // ألوان الأمان
  static const Color secure = Color(0xFF22C55E);     // أخضر - آمن
  static const Color alert = Color(0xFFFFD93D);      // أصفر - تنبيه
  static const Color danger = Color(0xFFFF6B6B);     // أحمر - خطر
  static const Color locked = Color(0xFF00D4FF);     // أزرق - مقفل
  
  // تدرجات لونية
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [deepBlack, charcoal],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient glowGradient = LinearGradient(
    colors: [neonBlue, neonPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient securityGradient = LinearGradient(
    colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const RadialGradient lockGlow = RadialGradient(
    colors: [
      Color(0x3300D4FF),
      Color(0x1100D4FF),
      Colors.transparent,
    ],
    stops: [0.0, 0.5, 1.0],
  );
  
  // ظلال
  static List<BoxShadow> neonShadow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.4),
      blurRadius: 20,
      spreadRadius: 2,
    ),
    BoxShadow(
      color: color.withValues(alpha: 0.2),
      blurRadius: 40,
      spreadRadius: 5,
    ),
  ];
  
  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}
