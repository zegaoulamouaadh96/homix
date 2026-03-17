import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_home_security/core/theme/app_colors.dart';
import 'package:smart_home_security/core/router/app_router.dart';
import 'package:smart_home_security/core/services/api_service.dart';
import 'package:smart_home_security/core/services/biometric_service.dart';
import 'package:smart_home_security/features/auth/widgets/animated_button.dart';

/// شاشة تسجيل الدخول
/// ✅ تسجيل الدخول بكلمة المرور + مصادقة جهاز إلزامية (بصمة/وجه/PIN)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _formController;
  late Animation<double> _formOpacity;
  late Animation<Offset> _formSlide;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  final _api = ApiService();
  final _biometric = BiometricService();
  static const _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _formOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOut),
    );

    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic),
    );

    _formController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _formController.dispose();
    super.dispose();
  }

  /// ✅ مصادقة جهاز إلزامية بعد كلمة المرور (بصمة/وجه/رمز الهاتف)
  /// إذا فشلت: نحذف التوكن ونلغي تسجيل الدخول
  Future<bool> _requireDeviceAuthOrRollback() async {
    final ok = await _biometric.authenticate(
      reason: 'تأكيد إضافي للدخول إلى HomiX',
      // هذه الدالة عندك في BiometricService تسمح PIN/Pattern لأن biometricOnly:false
    );

    if (!ok) {
      await _api.logout();
      _showError(
          'فشل التحقق (البصمة/الوجه/رمز الهاتف). تم إلغاء تسجيل الدخول.');
      return false;
    }
    return true;
  }

  /// تسجيل الدخول العادي (Email/Phone + Password) + تحقق إلزامي
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final input = _emailController.text.trim();
    final password = _passwordController.text;

    // تحديد ما إذا كان المدخل بريد أو رقم هاتف
    final isEmail = input.contains('@');

    final result = await _api.login(
      email: isEmail ? input : null,
      phone: isEmail ? null : input,
      password: password,
    );

    if (!mounted) return;

    if (result.ok) {
      // ✅ خطوة إلزامية: مصادقة الجهاز
      final verified = await _requireDeviceAuthOrRollback();
      if (!verified || !mounted) {
        setState(() => _isLoading = false);
        return;
      }

      // بعد نجاح التحقق: ربط المنزل إن وجد كود معلق
      final paired = await _pairPendingHome();
      if (!paired) {
        setState(() => _isLoading = false);
        return;
      }

      HapticFeedback.heavyImpact();
      if (mounted) context.go(AppRoutes.main);
    } else {
      setState(() => _isLoading = false);
      _showError(result.errorMessage);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
      ),
    );
  }

  /// ربط المنزل بعد تسجيل الدخول إذا كان هناك كود معلق
  Future<bool> _pairPendingHome() async {
    final pendingCode = await _storage.read(key: 'pending_home_code');
    if (pendingCode == null || pendingCode.isEmpty) {
      return true;
    }

    final pair = await _api.pairHome(pendingCode);
    if (pair.ok) {
      await _storage.delete(key: 'pending_home_code');
      return true;
    }

    _showError(pair.errorMessage);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: AnimatedBuilder(
                  animation: _formController,
                  builder: (context, child) {
                    return SlideTransition(
                      position: _formSlide,
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

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryBlack,
            AppColors.charcoal.withValues(alpha: 0.5),
            AppColors.primaryBlack,
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 40.h),
        _buildBackButton(),
        SizedBox(height: 40.h),
        _buildHeader(),
        SizedBox(height: 48.h),
        _buildLoginForm(),
        SizedBox(height: 24.h),
        _buildOptions(),
        SizedBox(height: 32.h),
        AnimatedButton(
          text: 'تسجيل الدخول',
          isLoading: _isLoading,
          onPressed: _login,
          icon: Icons.login,
        ),
        SizedBox(height: 32.h),
        _buildRegisterLink(),
        SizedBox(height: 40.h),
      ],
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.pop();
      },
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.darkGrey),
        ),
        child: Icon(
          Icons.arrow_back_ios_new,
          color: AppColors.white,
          size: 20.sp,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.neonBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.lock,
                color: AppColors.neonBlue,
                size: 28.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تسجيل الدخول',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'الدخول إلى منزلك الذكي',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.silver,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 14.h),
        Text(
          'بعد إدخال كلمة المرور سيتم طلب بصمة/وجه أو رمز الهاتف كإجراء أمان إضافي.',
          style: TextStyle(
            fontSize: 12.sp,
            color: AppColors.silver.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _emailController,
            label: 'البريد الإلكتروني أو رقم الهاتف',
            hint: 'example@email.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'الرجاء إدخال البريد الإلكتروني أو رقم الهاتف';
              }
              return null;
            },
          ),
          SizedBox(height: 20.h),
          _buildTextField(
            controller: _passwordController,
            label: 'كلمة المرور',
            hint: '••••••••',
            icon: Icons.lock_outline,
            isPassword: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'الرجاء إدخال كلمة المرور';
              }
              if (value.length < 6) {
                return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.silver,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword && _obscurePassword,
          validator: validator,
          style: TextStyle(
            fontSize: 16.sp,
            color: AppColors.white,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 22.sp),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 22.sp,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                      HapticFeedback.lightImpact();
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildOptions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () {
            setState(() => _rememberMe = !_rememberMe);
            HapticFeedback.lightImpact();
          },
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22.w,
                height: 22.w,
                decoration: BoxDecoration(
                  color: _rememberMe ? AppColors.neonBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(
                    color: _rememberMe ? AppColors.neonBlue : AppColors.silver,
                    width: 2,
                  ),
                ),
                child: _rememberMe
                    ? Icon(
                        Icons.check,
                        size: 14.sp,
                        color: AppColors.white,
                      )
                    : null,
              ),
              SizedBox(width: 8.w),
              Text(
                'تذكرني',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.silver,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () async {
            HapticFeedback.lightImpact();
            await _storage.delete(key: 'pending_home_code');
            if (mounted) context.go(AppRoutes.homeCode);
          },
          child: Text(
            'تغيير المنزل',
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.neonBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterLink() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ليس لديك حساب؟',
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.silver,
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push(AppRoutes.register);
            },
            child: Text(
              'إنشاء حساب',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.neonBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
