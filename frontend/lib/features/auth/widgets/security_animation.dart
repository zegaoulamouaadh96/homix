import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smart_home_security/core/theme/app_colors.dart';

/// حركة الأمان المتقدمة - درع متحرك
class SecurityAnimation extends StatefulWidget {
  final double size;
  
  const SecurityAnimation({
    super.key,
    this.size = 120,
  });

  @override
  State<SecurityAnimation> createState() => _SecurityAnimationState();
}

class _SecurityAnimationState extends State<SecurityAnimation>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _scanController;
  
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    
    // دوران الحلقة الخارجية
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    // نبض التوهج
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // خط المسح
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    _scanAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size.w,
      height: widget.size.w,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _rotationController,
          _pulseController,
          _scanController,
        ]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // الحلقات الخارجية الدوارة
              _buildRotatingRings(),
              
              // التوهج الخلفي
              _buildGlowEffect(),
              
              // الدرع الداخلي
              _buildShieldIcon(),
              
              // خط المسح
              _buildScanLine(),
              
              // مؤشر الحالة
              _buildStatusIndicator(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRotatingRings() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // الحلقة الخارجية
        Transform.rotate(
          angle: _rotationAnimation.value,
          child: CustomPaint(
            size: Size(widget.size.w, widget.size.w),
            painter: DashedCirclePainter(
              color: AppColors.neonBlue.withValues(alpha: 0.3),
              strokeWidth: 2,
              dashLength: 8,
              gapLength: 4,
            ),
          ),
        ),
        
        // الحلقة الداخلية (عكس الاتجاه)
        Transform.rotate(
          angle: -_rotationAnimation.value * 0.7,
          child: CustomPaint(
            size: Size(widget.size.w * 0.75, widget.size.w * 0.75),
            painter: DashedCirclePainter(
              color: AppColors.neonPurple.withValues(alpha: 0.2),
              strokeWidth: 1.5,
              dashLength: 12,
              gapLength: 6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlowEffect() {
    return Container(
      width: widget.size.w * 0.6,
      height: widget.size.w * 0.6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.neonBlue.withValues(alpha: _pulseAnimation.value * 0.4),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildShieldIcon() {
    return Container(
      width: widget.size.w * 0.5,
      height: widget.size.w * 0.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.charcoal,
        border: Border.all(
          color: AppColors.neonBlue.withValues(alpha: _pulseAnimation.value),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonBlue.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        Icons.shield,
        size: widget.size.w * 0.25,
        color: AppColors.neonBlue.withValues(alpha: 0.8 + _pulseAnimation.value * 0.2),
      ),
    );
  }

  Widget _buildScanLine() {
    return ClipOval(
      child: SizedBox(
        width: widget.size.w * 0.5,
        height: widget.size.w * 0.5,
        child: Transform.translate(
          offset: Offset(0, _scanAnimation.value * widget.size.w * 0.25),
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.neonBlue.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Positioned(
      bottom: 0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppColors.secure.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppColors.secure.withValues(alpha: _pulseAnimation.value * 0.8),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6.w,
              height: 6.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secure,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secure.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            SizedBox(width: 6.w),
            Text(
              'آمن',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.secure,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// رسام الدوائر المتقطعة
class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    final dashAngle = (dashLength / circumference) * 2 * math.pi;
    final gapAngle = (gapLength / circumference) * 2 * math.pi;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * (dashAngle + gapAngle);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// حركة القفل المتقدمة
class LockAnimation extends StatefulWidget {
  final bool isLocked;
  final double size;
  final VoidCallback? onTap;

  const LockAnimation({
    super.key,
    this.isLocked = true,
    this.size = 80,
    this.onTap,
  });

  @override
  State<LockAnimation> createState() => _LockAnimationState();
}

class _LockAnimationState extends State<LockAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shackleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shackleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (!widget.isLocked) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(LockAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLocked != widget.isLocked) {
      if (widget.isLocked) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final isUnlocking = _shackleAnimation.value > 0.5;
          final color = isUnlocking ? AppColors.warning : AppColors.secure;

          return Container(
            width: widget.size.w,
            height: widget.size.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.charcoal,
              border: Border.all(
                color: color.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3 * _glowAnimation.value),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Lock body
                Icon(
                  isUnlocking ? Icons.lock_open : Icons.lock,
                  size: widget.size.w * 0.4,
                  color: color,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
