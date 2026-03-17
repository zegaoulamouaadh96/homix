import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_home_security/core/theme/app_colors.dart';
import 'package:smart_home_security/core/router/app_router.dart';
import 'package:smart_home_security/core/services/api_service.dart';
import 'package:smart_home_security/features/auth/widgets/code_input_field.dart';
import 'package:smart_home_security/features/auth/widgets/animated_button.dart';
import 'package:smart_home_security/features/auth/widgets/security_animation.dart';

/// شاشة إدخال كود المنزل
class HomeCodeScreen extends StatefulWidget {
  const HomeCodeScreen({super.key});

  @override
  State<HomeCodeScreen> createState() => _HomeCodeScreenState();
}

class _HomeCodeScreenState extends State<HomeCodeScreen>
    with TickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late AnimationController _bgController;
  late AnimationController _formController;
  late AnimationController _shakeController;

  late Animation<double> _formSlide;
  late Animation<double> _formOpacity;

  bool _isLoading = false;
  bool _isCodeValid = false;
  String? _errorMessage;

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
  }

  void _initAnimations() {
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _formSlide = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic),
    );

    _formOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOut),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _formController.forward();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _bgController.dispose();
    _formController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    setState(() {
      _errorMessage = null;
      // تحقق من صيغة الكود (مثل: DZ-8F3A-91K2)
      final regex = RegExp(r'^[A-Z]{2}-[A-Z0-9]{4}-[A-Z0-9]{4}$');
      _isCodeValid = regex.hasMatch(value.toUpperCase());
    });
  }

  Future<void> _verifyHomeCode() async {
    if (!_formKey.currentState!.validate()) {
      _shakeController.forward().then((_) => _shakeController.reset());
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.mediumImpact();

    final code = _codeController.text.toUpperCase().trim();
    final verify = await _api.verifyHomeCode(code);

    if (!mounted) return;

    if (!verify.ok) {
      setState(() {
        _isLoading = false;
        _errorMessage = verify.errorMessage;
      });
      _shakeController.forward().then((_) => _shakeController.reset());
      HapticFeedback.heavyImpact();
      return;
    }

    final home = verify.data?['home'] as Map<String, dynamic>?;
    final isActivated = home?['activated'] == true;
    if (!isActivated) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'المنزل موجود لكن لم يتم تفعيله بعد من لوحة الإدارة';
      });
      _shakeController.forward().then((_) => _shakeController.reset());
      HapticFeedback.heavyImpact();
      return;
    }

    // حفظ الكود فقط بدون تسجيل خروج المستخدم
    const storage = FlutterSecureStorage();
    await storage.write(key: 'pending_home_code', value: code);

    setState(() => _isLoading = false);
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      body: Stack(
        children: [
          // Animated background
          _buildAnimatedBackground(),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: AnimatedBuilder(
                  animation: _formController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _formSlide.value),
                      child: Opacity(
                        opacity: _formOpacity.value,
                        child: _buildContent(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return CustomPaint(
          painter: SecurityGridPainter(
            progress: _bgController.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 60.h),

        // Security Animation
        const SecurityAnimation(),

        SizedBox(height: 40.h),

        // Title
        Text(
          'مرحباً بك',
          style: TextStyle(
            fontSize: 32.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),

        SizedBox(height: 8.h),

        Text(
          'أدخل كود المنزل للمتابعة',
          style: TextStyle(
            fontSize: 16.sp,
            color: AppColors.silver,
          ),
        ),

        SizedBox(height: 48.h),

        // Code Input Form
        _buildCodeForm(),

        SizedBox(height: 24.h),

        // Error Message
        if (_errorMessage != null) _buildErrorMessage(),

        SizedBox(height: 32.h),

        // Submit Button
        AnimatedShakeWidget(
          controller: _shakeController,
          child: AnimatedButton(
            text: 'تحقق من الكود',
            isLoading: _isLoading,
            isEnabled: _codeController.text.isNotEmpty,
            onPressed: _verifyHomeCode,
          ),
        ),

        SizedBox(height: 24.h),

        // Help Text
        _buildHelpSection(),

        SizedBox(height: 40.h),
      ],
    );
  }

  Widget _buildCodeForm() {
    return Form(
      key: _formKey,
      child: CodeInputField(
        controller: _codeController,
        onChanged: _onCodeChanged,
        isValid: _isCodeValid,
        hintText: 'DZ-XXXX-XXXX',
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'الرجاء إدخال كود المنزل';
          }
          final regex = RegExp(r'^[A-Z]{2}-[A-Z0-9]{4}-[A-Z0-9]{4}$');
          if (!regex.hasMatch(value.toUpperCase())) {
            return 'صيغة الكود غير صحيحة';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: 20.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.charcoal.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.darkGrey,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.neonBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.help_outline,
                  color: AppColors.neonBlue,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'كيف أحصل على كود المنزل؟',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildHelpItem(
            icon: Icons.router,
            text: 'كود المنزل موجود على جهاز التحكم المركزي',
          ),
          SizedBox(height: 12.h),
          _buildHelpItem(
            icon: Icons.email_outlined,
            text: 'أو تم إرساله إليك عبر البريد الإلكتروني',
          ),
          SizedBox(height: 12.h),
          _buildHelpItem(
            icon: Icons.person_outline,
            text: 'تواصل مع مالك المنزل إذا كنت ضيفاً',
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.silver,
          size: 18.sp,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.silver,
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated shake widget for errors
class AnimatedShakeWidget extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const AnimatedShakeWidget({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final shake = math.sin(controller.value * math.pi * 4) * 10;
        return Transform.translate(
          offset: Offset(shake, 0),
          child: child,
        );
      },
    );
  }
}

/// Security grid background painter
class SecurityGridPainter extends CustomPainter {
  final double progress;

  SecurityGridPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.neonBlue.withValues(alpha: 0.03)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Draw moving grid
    const gridSize = 50.0;
    final offset = progress * gridSize;

    for (double x = -gridSize + offset;
        x < size.width + gridSize;
        x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = -gridSize + offset;
        y < size.height + gridSize;
        y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Draw gradient overlay
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.5,
        colors: [
          AppColors.neonBlue.withValues(alpha: 0.02),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      gradientPaint,
    );
  }

  @override
  bool shouldRepaint(SecurityGridPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
