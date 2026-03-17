import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smart_home_security/core/theme/app_colors.dart';
import 'package:smart_home_security/core/services/api_service.dart';
import 'package:smart_home_security/core/services/biometric_service.dart';

/// شاشة إنشاء كود دخول مؤقت للضيوف
class GuestAccessScreen extends StatefulWidget {
  const GuestAccessScreen({super.key});

  @override
  State<GuestAccessScreen> createState() => _GuestAccessScreenState();
}

class _GuestAccessScreenState extends State<GuestAccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String? _generatedCode;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  int _selectedDuration = 5; // دقائق
  String _selectedDoor = 'الباب الرئيسي';
  String _guestName = '';
  bool _isCreating = false;

  // لحفظ آخر كود في القائمة وتحديث حالته (used/expired/revoked)
  int? _activeRecentIndex;

  final _api = ApiService();
  final _biometric = BiometricService();

  final List<int> _durationOptions = [5, 15, 30, 60];
  final List<String> _doorOptions = [
    'الباب الرئيسي',
    'الباب الخلفي',
    'باب المرآب',
    'جميع الأبواب',
  ];

  // ✅ الأكواد السابقة (الآن تُملأ ديناميكياً)
  final List<Map<String, dynamic>> _recentCodes = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ✅ توليد كود 4 أرقام
  String _generate4DigitCode() {
    final random = math.Random();
    return List.generate(4, (_) => random.nextInt(10)).join();
  }

  Future<void> _generateCode() async {
    HapticFeedback.heavyImpact();

    // تأكيد بالبصمة/الوجه قبل إنشاء كود الضيف (عملية حساسة)
    final hasBio = await _biometric.isDeviceSupported() &&
        await _biometric.hasBiometrics();
    if (hasBio) {
      final authenticated = await _biometric.authenticate(
        reason: 'تأكيد إنشاء كود ضيف',
      );
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل التحقق من الهوية'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    setState(() => _isCreating = true);

    final code = _generate4DigitCode();

    // إرسال الكود للسيرفر
    final homeId = await _api.getHomeId();
    if (homeId != null) {
      // تحديد device_id حسب الباب المختار
      String? scopeDeviceId;
      if (_selectedDoor != 'جميع الأبواب') {
        final doorIndex = _doorOptions.indexOf(_selectedDoor);
        if (doorIndex >= 0 && doorIndex < 3) {
          scopeDeviceId = 'door_${doorIndex + 1}';
        }
      }

      final result = await _api.createGuestCode(
        homeId: homeId,
        code: code,
        minutes: _selectedDuration,
        scopeDeviceId: scopeDeviceId,
      );

      if (!mounted) return;

      if (!result.ok) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    if (!mounted) return;

    // ✅ إضافة الكود إلى الأكواد السابقة (نشط)
    final recentItem = {
      'code': code,
      'guest': _guestName.trim().isEmpty ? 'ضيف' : _guestName.trim(),
      'door': _selectedDoor,
      'createdAt': DateTime.now(),
      'status': 'active', // active / used / expired / revoked
    };

    setState(() {
      _isCreating = false;
      _generatedCode = code;
      _remainingSeconds = _selectedDuration * 60;

      // ضع العنصر في البداية
      _recentCodes.insert(0, recentItem);
      _activeRecentIndex = 0;
    });

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          // ✅ انتهاء الكود: حدّث الحالة في الأكواد السابقة
          _markActiveAs('expired');

          _generatedCode = null;
          _activeRecentIndex = null;
          timer.cancel();
        }
      });
    });
  }

  void _markActiveAs(String status) {
    if (_activeRecentIndex == null) return;
    if (_activeRecentIndex! < 0 || _activeRecentIndex! >= _recentCodes.length) {
      return;
    }
    _recentCodes[_activeRecentIndex!]['status'] = status;
  }

  void _copyCode() {
    if (_generatedCode != null) {
      Clipboard.setData(ClipboardData(text: _generatedCode!));
      HapticFeedback.mediumImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم نسخ الكود: $_generatedCode'),
          backgroundColor: AppColors.secure,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _revokeCode() {
    HapticFeedback.heavyImpact();

    setState(() {
      // ✅ حدّث الأكواد السابقة إلى revoked
      _markActiveAs('revoked');

      _generatedCode = null;
      _activeRecentIndex = null;
      _countdownTimer?.cancel();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إلغاء الكود'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  // ✅ (اختياري): لو عندك إشعار من السيرفر بأن الكود استُخدم
  // استدعِ هذه الدالة في المكان المناسب لتحديث الحالة إلى used
  void markCodeUsed() {
    setState(() {
      _markActiveAs('used');
      _generatedCode = null;
      _activeRecentIndex = null;
      _countdownTimer?.cancel();
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                _buildHeader(),
                SizedBox(height: 32.h),
                _generatedCode != null
                    ? _buildActiveCode()
                    : _buildCodeGenerator(),
                SizedBox(height: 32.h),
                _buildRecentCodes(),
                SizedBox(height: 120.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'دخول الضيوف',
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'أنشئ كود لمرة واحدة للسماح بدخول شخص',
          style: TextStyle(
            fontSize: 14.sp,
            color: AppColors.silver,
          ),
        ),
      ],
    );
  }

  Widget _buildCodeGenerator() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.darkGrey),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.qr_code_2,
              size: 48.sp,
              color: AppColors.neonBlue,
            ),
          ),
          SizedBox(height: 24.h),
          _buildGuestNameInput(),
          SizedBox(height: 20.h),
          _buildDurationSelector(),
          SizedBox(height: 20.h),
          _buildDoorSelector(),
          SizedBox(height: 24.h),
          _buildGenerateButton(),
        ],
      ),
    );
  }

  Widget _buildGuestNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اسم الضيف (اختياري)',
          style: TextStyle(fontSize: 14.sp, color: AppColors.silver),
        ),
        SizedBox(height: 8.h),
        TextField(
          onChanged: (value) => _guestName = value,
          style: const TextStyle(color: AppColors.white),
          decoration: InputDecoration(
            hintText: 'مثال: عامل التوصيل',
            prefixIcon: Icon(Icons.person_outline, size: 20.sp),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('مدة الصلاحية',
            style: TextStyle(fontSize: 14.sp, color: AppColors.silver)),
        SizedBox(height: 12.h),
        Row(
          children: _durationOptions.map((duration) {
            final isSelected = duration == _selectedDuration;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedDuration = duration);
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.neonBlue.withValues(alpha: 0.1)
                        : AppColors.darkGrey,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color:
                          isSelected ? AppColors.neonBlue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$duration',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.neonBlue
                              : AppColors.silver,
                        ),
                      ),
                      Text('دقيقة',
                          style: TextStyle(
                              fontSize: 10.sp, color: AppColors.silver)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDoorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الباب المسموح',
            style: TextStyle(fontSize: 14.sp, color: AppColors.silver)),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppColors.darkGrey,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDoor,
              isExpanded: true,
              dropdownColor: AppColors.charcoal,
              style: TextStyle(color: AppColors.white, fontSize: 14.sp),
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.silver),
              items: _doorOptions.map((door) {
                return DropdownMenuItem(
                  value: door,
                  child: Row(
                    children: [
                      Icon(Icons.door_front_door_outlined,
                          color: AppColors.silver, size: 20.sp),
                      SizedBox(width: 12.w),
                      Text(door),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedDoor = value);
                  HapticFeedback.selectionClick();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return GestureDetector(
      onTap: _isCreating ? null : _generateCode,
      child: Opacity(
        opacity: _isCreating ? 0.6 : 1,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.neonBlue, AppColors.neonPurple]),
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonBlue.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isCreating) ...[
                SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10.w),
                Text(
                  'جاري الإنشاء...',
                  style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white),
                ),
              ] else ...[
                Icon(Icons.add_circle_outline,
                    color: AppColors.white, size: 22.sp),
                SizedBox(width: 8.w),
                Text(
                  'إنشاء كود جديد',
                  style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCode() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: AppColors.charcoal,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: AppColors.neonBlue.withValues(alpha: _pulseAnimation.value),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    AppColors.neonBlue.withValues(alpha: 0.2 * _pulseAnimation.value),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.secure.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: AppColors.secure),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: const BoxDecoration(
                          color: AppColors.secure, shape: BoxShape.circle),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'كود نشط',
                      style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secure),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // ✅ عرض 4 أرقام
              GestureDetector(
                onTap: _copyCode,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 28.w, vertical: 20.h),
                  decoration: BoxDecoration(
                    color: AppColors.darkGrey,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _generatedCode!.split('').join(' '),
                        style: TextStyle(
                          fontSize: 36.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                          letterSpacing: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Icon(Icons.copy, color: AppColors.neonBlue, size: 22.sp),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: _remainingSeconds < 60
                        ? AppColors.warning
                        : AppColors.silver,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'ينتهي خلال ${_formatDuration(_remainingSeconds)}',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: _remainingSeconds < 60
                          ? AppColors.warning
                          : AppColors.silver,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                    color: AppColors.darkGrey,
                    borderRadius: BorderRadius.circular(12.r)),
                child: Row(
                  children: [
                    Icon(Icons.door_front_door_outlined,
                        color: AppColors.silver, size: 18.sp),
                    SizedBox(width: 8.w),
                    Text(_selectedDoor,
                        style: TextStyle(
                            fontSize: 14.sp, color: AppColors.silver)),
                    const Spacer(),
                    if (_guestName.trim().isNotEmpty) ...[
                      Icon(Icons.person_outline,
                          color: AppColors.silver, size: 18.sp),
                      SizedBox(width: 8.w),
                      Text(_guestName.trim(),
                          style: TextStyle(
                              fontSize: 14.sp, color: AppColors.silver)),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // ✅ فقط زر الإلغاء (بدون مشاركة)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _revokeCode,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cancel_outlined,
                                color: AppColors.error, size: 20.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'إلغاء الكود',
                              style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentCodes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الأكواد السابقة',
          style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.white),
        ),
        SizedBox(height: 16.h),
        if (_recentCodes.isEmpty)
          Text(
            'لا توجد أكواد بعد.',
            style: TextStyle(fontSize: 13.sp, color: AppColors.silver),
          )
        else
          ..._recentCodes.map((code) => _buildRecentCodeCard(code)),
      ],
    );
  }

  Widget _buildRecentCodeCard(Map<String, dynamic> code) {
    final status = code['status'] as String;
    final isUsed = status == 'used';
    final isExpired = status == 'expired';
    final isRevoked = status == 'revoked';
    final isActive = status == 'active';

    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    if (isUsed) {
      badgeColor = AppColors.secure;
      badgeIcon = Icons.check_circle;
      badgeText = 'مستخدم';
    } else if (isExpired) {
      badgeColor = AppColors.silver;
      badgeIcon = Icons.cancel;
      badgeText = 'منتهي';
    } else if (isRevoked) {
      badgeColor = AppColors.warning;
      badgeIcon = Icons.block;
      badgeText = 'ملغي';
    } else {
      badgeColor = AppColors.neonBlue;
      badgeIcon = Icons.access_time;
      badgeText = 'نشط';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.darkGrey),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(badgeIcon, color: badgeColor, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${code['guest']} • ${code['code']}',
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${code['door']} • ${_formatTime(code['createdAt'] as DateTime)}',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.silver),
                ),
                if (isActive && _generatedCode == code['code']) ...[
                  SizedBox(height: 4.h),
                  Text(
                    'هذا هو الكود الحالي النشط',
                    style:
                        TextStyle(fontSize: 11.sp, color: AppColors.neonBlue),
                  ),
                ]
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: badgeColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} ساعة';
    } else {
      return 'منذ ${diff.inDays} يوم';
    }
  }
}
