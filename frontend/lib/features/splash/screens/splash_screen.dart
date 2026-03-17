import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_home_security/core/theme/app_colors.dart';
import 'package:smart_home_security/core/router/app_router.dart';
import 'package:smart_home_security/core/services/api_service.dart';

/// شاشة البداية ثلاثية الأبعاد - HomiX
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ─── Animation Controllers ───
  late AnimationController _bgController;       // خلفية الجزيئات المتحركة
  late AnimationController _iconEntryCtrl;      // ظهور الأيقونة 3D
  late AnimationController _rotateCtrl;         // دوران ثلاثي الأبعاد
  late AnimationController _glowPulseCtrl;      // نبض التوهج
  late AnimationController _ringExpandCtrl;     // حلقات تتوسع
  late AnimationController _textCtrl;           // ظهور النص
  late AnimationController _wifiCtrl;           // أنميشن إشارة الواي فاي

  // ─── Animations ───
  late Animation<double> _iconScale;
  late Animation<double> _iconOpacity;
  late Animation<double> _rotateY;
  late Animation<double> _glowPulse;
  late Animation<double> _ringExpand;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _wifiOpacity;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startSequence();
  }

  void _initAnimations() {
    // ── 1) Background particles ──
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // ── 2) Icon 3D entrance (scale + fade) ──
    _iconEntryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconEntryCtrl,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );
    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconEntryCtrl,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    // ── 3) 3D Y-axis rotation ──
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _rotateY = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateCtrl, curve: Curves.easeInOut),
    );

    // ── 4) Glow pulse ──
    _glowPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _glowPulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowPulseCtrl, curve: Curves.easeInOut),
    );

    // ── 5) Ring expansion ──
    _ringExpandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _ringExpand = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ringExpandCtrl, curve: Curves.easeOut),
    );

    // ── 6) Text entrance ──
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic),
    );

    // ── 7) WiFi signal animation ──
    _wifiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _wifiOpacity = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _wifiCtrl, curve: Curves.easeInOut),
    );
  }

  void _startSequence() async {
    HapticFeedback.mediumImpact();

    // Phase 1: Icon 3D entrance
    await Future.delayed(const Duration(milliseconds: 200));
    _iconEntryCtrl.forward();

    // Phase 2: 3D rotation (one full spin)
    await Future.delayed(const Duration(milliseconds: 600));
    _rotateCtrl.forward();

    // Phase 3: Glow pulse starts
    await Future.delayed(const Duration(milliseconds: 400));
    _glowPulseCtrl.repeat(reverse: true);

    // Phase 4: WiFi signal animation
    await Future.delayed(const Duration(milliseconds: 300));
    _wifiCtrl.repeat(reverse: true);

    // Phase 5: Rings expand
    await Future.delayed(const Duration(milliseconds: 200));
    _ringExpandCtrl.repeat();

    // Phase 6: Text slides up
    await Future.delayed(const Duration(milliseconds: 600));
    _textCtrl.forward();

    // Phase 7: Navigate
    await Future.delayed(const Duration(milliseconds: 2200));
    HapticFeedback.heavyImpact();

    if (mounted) {
      final api = ApiService();
      final isLoggedIn = await api.isLoggedIn();
      final homeId = await api.getHomeId();
      if (isLoggedIn && homeId != null) {
        if (mounted) context.go(AppRoutes.main);
      } else {
        if (mounted) context.go(AppRoutes.homeCode);
      }
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _iconEntryCtrl.dispose();
    _rotateCtrl.dispose();
    _glowPulseCtrl.dispose();
    _ringExpandCtrl.dispose();
    _textCtrl.dispose();
    _wifiCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050518),
      body: Stack(
        children: [
          // ── Animated particle background ──
          _buildParticlesBg(),
          // ── Radial gradient overlay ──
          _buildGradientOverlay(),
          // ── Expanding rings ──
          _buildExpandingRings(),
          // ── Main content (3D icon + text) ──
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _build3DIcon(),
                  SizedBox(height: 40.h),
                  _buildAnimatedText(),
                ],
              ),
            ),
          ),
          // ── Bottom loader ──
          _buildBottomLoader(),
        ],
      ),
    );
  }

  // ─── PARTICLES BACKGROUND ───
  Widget _buildParticlesBg() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, _) {
        return CustomPaint(
          painter: _StarFieldPainter(progress: _bgController.value),
          size: Size.infinite,
        );
      },
    );
  }

  // ─── GRADIENT OVERLAY ───
  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.2,
          colors: [
            const Color(0xFF0D47A1).withValues(alpha: 0.08),
            const Color(0xFF6200EA).withValues(alpha: 0.04),
            Colors.transparent,
            const Color(0xFF050518),
          ],
          stops: const [0.0, 0.25, 0.5, 1.0],
        ),
      ),
    );
  }

  // ─── EXPANDING RINGS ───
  Widget _buildExpandingRings() {
    return AnimatedBuilder(
      animation: _ringExpandCtrl,
      builder: (context, _) {
        final v = _ringExpand.value;
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: List.generate(3, (i) {
              final delay = i * 0.25;
              final t = ((v + delay) % 1.0);
              final size = 160.w + t * 200.w;
              final opacity = (1.0 - t).clamp(0.0, 0.4);
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.neonBlue.withValues(alpha: opacity),
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ─── 3D ANIMATED ICON ───
  Widget _build3DIcon() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _iconEntryCtrl,
        _rotateCtrl,
        _glowPulseCtrl,
        _wifiCtrl,
      ]),
      builder: (context, _) {
        // 3D perspective rotation around Y axis
        final angle = _rotateY.value;
        final perspective = Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateY(angle);

        return Transform.scale(
          scale: _iconScale.value,
          child: Opacity(
            opacity: _iconOpacity.value,
            child: Transform(
              alignment: Alignment.center,
              transform: perspective,
              child: _buildIconContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconContent() {
    final glow = _glowPulse.value;
    return Stack(
      alignment: Alignment.center,
      children: [
        // ─── Outer glow blur ───
        Container(
          width: 200.w,
          height: 200.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.neonBlue.withValues(alpha: 0.25 * glow),
                blurRadius: 80,
                spreadRadius: 20,
              ),
              BoxShadow(
                color: const Color(0xFF6200EA).withValues(alpha: 0.15 * glow),
                blurRadius: 60,
                spreadRadius: 10,
              ),
            ],
          ),
        ),

        // ─── Glass card (rounded square like the icon image) ───
        Container(
          width: 160.w,
          height: 160.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A1A4E).withValues(alpha: 0.9),
                const Color(0xFF0D0D2B).withValues(alpha: 0.95),
              ],
            ),
            border: Border.all(
              width: 2.5,
              color: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.neonBlue.withValues(alpha: 0.7 * glow),
                  const Color(0xFF6200EA).withValues(alpha: 0.5 * glow),
                  AppColors.neonBlue.withValues(alpha: 0.3 * glow),
                ],
              ).colors.first, // simplified gradient border
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonBlue.withValues(alpha: 0.3 * glow),
                blurRadius: 30,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: const Color(0xFF6200EA).withValues(alpha: 0.2 * glow),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: _buildSmartHomeIcon(),
            ),
          ),
        ),

        // ─── Corner shine effect ───
        Positioned(
          top: 8.h,
          right: 8.w,
          child: Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.15 * glow),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// رسم أيقونة المنزل الذكي مع إشارة WiFi
  Widget _buildSmartHomeIcon() {
    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ─── House outline (custom paint) ───
          CustomPaint(
            size: Size(120.w, 120.w),
            painter: _SmartHomePainter(
              glowIntensity: _glowPulse.value,
              wifiOpacity: _wifiOpacity.value,
            ),
          ),
        ],
      ),
    );
  }

  // ─── ANIMATED TEXT ───
  Widget _buildAnimatedText() {
    return AnimatedBuilder(
      animation: _textCtrl,
      builder: (context, _) {
        return SlideTransition(
          position: _textSlide,
          child: Opacity(
            opacity: _textOpacity.value,
            child: Column(
              children: [
                // ── HomiX logo text ──
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFF00D4FF),
                      Color(0xFF7C4DFF),
                      Color(0xFF00D4FF),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'HomiX',
                    style: TextStyle(
                      fontSize: 42.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 6,
                      height: 1,
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  'SMART HOME SECURITY',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w300,
                    color: AppColors.silver.withValues(alpha: 0.8),
                    letterSpacing: 6,
                  ),
                ),
                SizedBox(height: 20.h),
                // ─── Tagline pill ───
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(
                      color: AppColors.neonBlue.withValues(alpha: 0.35),
                      width: 1,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.neonBlue.withValues(alpha: 0.08),
                        const Color(0xFF6200EA).withValues(alpha: 0.06),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 14.sp, color: AppColors.neonBlue),
                      SizedBox(width: 6.w),
                      Text(
                        'حماية منزلك الذكي',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppColors.neonBlue.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── BOTTOM LOADER ───
  Widget _buildBottomLoader() {
    return Positioned(
      bottom: 70.h,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _textCtrl,
        builder: (context, _) {
          return Opacity(
            opacity: _textOpacity.value,
            child: Column(
              children: [
                SizedBox(
                  width: 28.w,
                  height: 28.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.neonBlue.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  'جاري تأمين الاتصال...',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.silver.withValues(alpha: 0.5),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════

/// رسم أيقونة المنزل الذكي + إشارة WiFi
class _SmartHomePainter extends CustomPainter {
  final double glowIntensity;
  final double wifiOpacity;

  _SmartHomePainter({
    required this.glowIntensity,
    required this.wifiOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // ─── Neon gradient paint ───
    final neonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF00D4FF), Color(0xFF4FC3F7), Color(0xFF00B0FF)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    // ─── House roof (triangle) ───
    final roofPath = Path()
      ..moveTo(cx, h * 0.12)
      ..lineTo(w * 0.12, h * 0.45)
      ..lineTo(w * 0.88, h * 0.45)
      ..close();
    canvas.drawPath(roofPath, neonPaint);

    // Roof glow
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8)
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00D4FF).withValues(alpha: 0.3 * glowIntensity),
          const Color(0xFF00B0FF).withValues(alpha: 0.1 * glowIntensity),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(roofPath, glowPaint);

    // ─── House body ───
    final bodyPath = Path()
      ..moveTo(w * 0.20, h * 0.45)
      ..lineTo(w * 0.20, h * 0.82)
      ..lineTo(w * 0.80, h * 0.82)
      ..lineTo(w * 0.80, h * 0.45);
    canvas.drawPath(bodyPath, neonPaint);

    // ─── Door (arch) ───
    final doorRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(cx - w * 0.1, h * 0.55, w * 0.2, h * 0.27),
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
    );
    canvas.drawRRect(doorRect, neonPaint);

    // ─── Person silhouette (small circle + body) ───
    final personPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF00D4FF).withValues(alpha: 0.8 * glowIntensity),
          const Color(0xFF4FC3F7).withValues(alpha: 0.6 * glowIntensity),
        ],
      ).createShader(Rect.fromLTWH(cx - 8, h * 0.60, 16, 24));

    // Head
    canvas.drawCircle(Offset(cx, h * 0.62), 5, personPaint);
    // Body
    final bodyPersonPath = Path()
      ..moveTo(cx, h * 0.67)
      ..lineTo(cx - 6, h * 0.78)
      ..quadraticBezierTo(cx, h * 0.80, cx + 6, h * 0.78)
      ..close();
    canvas.drawPath(bodyPersonPath, personPaint);

    // ─── WiFi signal arcs ───
    final wifiPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final arcOpacity = (wifiOpacity * (0.4 + 0.3 * (2 - i))).clamp(0.0, 1.0);
      wifiPaint.color = const Color(0xFF00D4FF).withValues(alpha: arcOpacity);

      final radius = 10.0 + i * 9.0;
      final arcRect = Rect.fromCircle(
        center: Offset(cx, h * 0.30),
        radius: radius,
      );
      canvas.drawArc(arcRect, -math.pi * 0.7, math.pi * 0.4, false, wifiPaint);
    }

    // WiFi dot
    canvas.drawCircle(
      Offset(cx, h * 0.30),
      3,
      Paint()..color = const Color(0xFF00D4FF).withValues(alpha: wifiOpacity),
    );
  }

  @override
  bool shouldRepaint(_SmartHomePainter old) =>
      old.glowIntensity != glowIntensity || old.wifiOpacity != wifiOpacity;
}

/// خلفية النجوم والجزيئات المتحركة
class _StarFieldPainter extends CustomPainter {
  final double progress;
  _StarFieldPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rand = math.Random(77);

    // ── Stars ──
    for (int i = 0; i < 80; i++) {
      final x = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * size.height;
      final y = (baseY + progress * size.height * 0.3) % size.height;
      final flicker = (math.sin(progress * math.pi * 2 + i * 0.8) + 1) / 2;
      final r = rand.nextDouble() * 1.5 + 0.3;
      final isBlue = rand.nextDouble() > 0.6;

      paint.color = isBlue
          ? const Color(0xFF00D4FF).withValues(alpha: flicker * 0.25)
          : const Color(0xFF7C4DFF).withValues(alpha: flicker * 0.15);

      canvas.drawCircle(Offset(x, y), r, paint);
    }

    // ── Floating particles connecting lines ──
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.06);

    final points = <Offset>[];
    final rand2 = math.Random(42);
    for (int i = 0; i < 20; i++) {
      final x = rand2.nextDouble() * size.width;
      final baseY = rand2.nextDouble() * size.height;
      final y = (baseY + progress * size.height * 0.2) % size.height;
      points.add(Offset(x, y));
    }

    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final dist = (points[i] - points[j]).distance;
        if (dist < 120) {
          canvas.drawLine(points[i], points[j], linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_StarFieldPainter old) => old.progress != progress;
}
