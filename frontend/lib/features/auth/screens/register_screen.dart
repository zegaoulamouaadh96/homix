import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:smart_home_security/core/theme/app_colors.dart';
import 'package:smart_home_security/core/router/app_router.dart';
import 'package:smart_home_security/core/services/api_service.dart';
import 'package:smart_home_security/features/auth/widgets/animated_button.dart';

/// شاشة إنشاء حساب جديد (مرحلتين)
/// Step 1: بيانات الحساب + دور في العائلة
/// Step 2: 3 صور وجه + صورة بروفايل ثم دخول
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Step 1 controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 1: role
  String? _familyRole;

  // Step 2 images
  final ImagePicker _picker = ImagePicker();
  List<String> _faceFrames = []; // preview/test frames only
  File? _profileImage;

  late AnimationController _formController;
  late Animation<double> _formOpacity;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  int _currentStep = 0; // 0 = Step1, 1 = Step2

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _formOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOut),
    );

    _formController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _formController.dispose();
    super.dispose();
  }

  // ===================== Step Navigation =====================

  Future<void> _nextStep() async {
    // Validate Step 1
    if (!_formKey.currentState!.validate()) return;

    if (_familyRole == null) {
      _showError('الرجاء اختيار دورك داخل العائلة');
      return;
    }

    if (!_agreeToTerms) {
      _showError('يجب الموافقة على الشروط والأحكام');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('كلمتا المرور غير متطابقتين');
      return;
    }

    setState(() => _currentStep = 1);
    HapticFeedback.lightImpact();
  }

  void _backStep() {
    setState(() => _currentStep = 0);
    HapticFeedback.lightImpact();
  }

  // ===================== Image Picking =====================

  Future<File?> _captureImageWithPreview({String title = 'التقاط صورة'}) async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        _showError('لا توجد كاميرا متاحة');
        return null;
      }

      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );

      final path = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CameraCaptureDialog(camera: front, title: title),
      );

      if (path == null || path.isEmpty) return null;
      return File(path);
    } catch (_) {
      _showError('تعذر تشغيل معاينة الكاميرا');
      return null;
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (xfile == null) return;

      setState(() {
        _profileImage = File(xfile.path);
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      // إذا فشل المعرض، جرب الكاميرا
      try {
        final file = await _captureImageWithPreview(
          title: 'التقاط صورة الملف الشخصي',
        );
        if (file == null) return;
        setState(() {
          _profileImage = file;
        });
        HapticFeedback.lightImpact();
      } catch (_) {
        _showError('تعذر اختيار صورة البروفايل');
      }
    }
  }

  bool get _step2Complete {
    final profileOk = _profileImage != null;
    return profileOk;
  }

  Future<void> _captureFaceFramesFlow() async {
    final frames = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _FaceFramesCaptureDialog(
        title: 'اختبار الكاميرا',
        instruction: 'حرّك وجهك قليلًا للتأكد من وضوح الكاميرا.',
      ),
    );

    if (!mounted || frames == null || frames.length < 10) return;
    setState(() => _faceFrames = frames);
    HapticFeedback.mediumImpact();
  }

  // ===================== Registration Flow =====================

  Future<void> _finishRegister() async {
    if (!_step2Complete) {
      _showError('يجب إضافة صورة بروفايل للمتابعة');
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    // 1) Register account (يحفظ token في ApiService)
    final reg = await _api.register(
      email: email.isNotEmpty ? email : null,
      phone: phone.isNotEmpty ? phone : null,
      password: password,
    );

    if (!mounted) return;

    if (!reg.ok) {
      setState(() => _isLoading = false);
      _showError(reg.errorMessage);
      return;
    }

    // 2) Upload profile image -> get url
    String? profileUrl;
    final prof = await _api.uploadSingleImage(filePath: _profileImage!.path);
    if (prof.ok) {
      profileUrl = prof.data?['url'] as String?;
    } else {
      // إذا فشل رفع البروفايل نوقف (حسب طلبك: إلزامي)
      await _api.logout();
      setState(() => _isLoading = false);
      _showError('فشل رفع صورة البروفايل');
      return;
    }

    // 3) Get challenge and capture face frames with explicit instruction
    final challenge = await _api.getFaceChallenge();
    if (!challenge.ok) {
      await _api.logout();
      setState(() => _isLoading = false);
      _showError(challenge.errorMessage);
      return;
    }

    final challengeToken =
        (challenge.data?['challenge_token'] ?? '').toString();
    final instruction = (challenge.data?['instruction_ar'] ?? 'اتبع الحركة المطلوبة').toString();
    final challengeType = (challenge.data?['challenge'] ?? '').toString();
    if (challengeToken.isEmpty) {
      await _api.logout();
      setState(() => _isLoading = false);
      _showError('فشل بدء تسجيل الوجه');
      return;
    }

    final challengeFrames = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FaceFramesCaptureDialog(
        title: 'تسجيل الوجه (تحقق حي)',
        instruction: instruction,
      ),
    );

    if (!mounted) return;
    if (challengeFrames == null || challengeFrames.length < 10) {
      await _api.logout();
      setState(() => _isLoading = false);
      _showError('لم يتم جمع فيديو كافٍ للتحقق من الحركة');
      return;
    }

    setState(() => _faceFrames = challengeFrames);

    final faceReg = await _api.registerFaceFrames(
      frames: challengeFrames,
      challengeToken: challengeToken,
    );
    if (!faceReg.ok) {
      await _api.logout();
      setState(() => _isLoading = false);
      _showError('${faceReg.errorMessage} (${challengeType.isEmpty ? 'challenge' : challengeType})');
      return;
    }

    // 4) Update profile (name + family role + profile image url)
    final upd = await _api.updateProfile(
      fullName: fullName,
      familyRole: _familyRole!,
      profileImageUrl: profileUrl,
    );
    if (!upd.ok) {
      await _api.logout();
      setState(() => _isLoading = false);
      _showError('فشل حفظ بيانات الملف الشخصي');
      return;
    }

    // 5) Pair home إذا كان هناك كود معلق
    const storage = FlutterSecureStorage();
    final pendingCode = await storage.read(key: 'pending_home_code');
    if (pendingCode != null && pendingCode.isNotEmpty) {
      final pair = await _api.pairHome(pendingCode);
      if (!pair.ok) {
        await _api.logout();
        setState(() => _isLoading = false);
        _showError(pair.errorMessage);
        return;
      }
      await storage.delete(key: 'pending_home_code');
    }

    HapticFeedback.heavyImpact();
    if (mounted) context.go(AppRoutes.main);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryBlack,
                  AppColors.charcoal.withValues(alpha: 0.3),
                  AppColors.primaryBlack,
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: AnimatedBuilder(
                  animation: _formController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _formOpacity.value,
                      child: _buildContent(),
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

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20.h),
        _buildBackButton(),
        SizedBox(height: 30.h),
        _buildHeader(),
        SizedBox(height: 24.h),
        _buildProgressIndicator(),
        SizedBox(height: 28.h),
        if (_currentStep == 0) _buildStep1Form() else _buildStep2FaceCapture(),
        SizedBox(height: 24.h),
        if (_currentStep == 0) _buildTermsCheckbox(),
        SizedBox(height: 28.h),
        _buildPrimaryButton(),
        SizedBox(height: 18.h),
        _buildSecondaryAction(),
        SizedBox(height: 40.h),
      ],
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (_currentStep == 1) {
          _backStep();
        } else {
          context.pop();
        }
      },
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.darkGrey),
        ),
        child:
            Icon(Icons.arrow_back_ios_new, color: AppColors.white, size: 20.sp),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إنشاء حساب جديد',
          style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.white),
        ),
        SizedBox(height: 8.h),
        Text(
          _currentStep == 0
              ? 'المرحلة 1: معلومات الحساب ودورك في العائلة'
              : 'المرحلة 2: صور الوجه وصورة الملف الشخصي',
          style: TextStyle(fontSize: 14.sp, color: AppColors.silver),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    // 2 مراحل (بدل 3)
    return Row(
      children: List.generate(2, (index) {
        final isActive = index <= _currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            height: 4.h,
            decoration: BoxDecoration(
              color: isActive ? AppColors.neonBlue : AppColors.darkGrey,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        );
      }),
    );
  }

  // ===================== STEP 1 =====================

  Widget _buildStep1Form() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _nameController,
            label: 'الاسم الكامل',
            hint: 'أدخل اسمك',
            icon: Icons.person_outline,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'الرجاء إدخال الاسم'
                : null,
          ),
          SizedBox(height: 16.h),

          // Email (اختياري أو إجباري حسبك—هنا نجعله اختياري مع شرط واحد على الأقل)
          _buildTextField(
            controller: _emailController,
            label: 'البريد الإلكتروني (اختياري)',
            hint: 'example@email.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (_) => null,
          ),
          SizedBox(height: 16.h),

          _buildTextField(
            controller: _phoneController,
            label: 'رقم الهاتف (اختياري)',
            hint: '+213 XXX XXX XXX',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (value) {
              final email = _emailController.text.trim();
              final phone = value?.trim() ?? '';
              if (email.isEmpty && phone.isEmpty) {
                return 'أدخل البريد الإلكتروني أو رقم الهاتف (واحد على الأقل)';
              }
              return null;
            },
          ),
          SizedBox(height: 16.h),

          _buildRoleDropdown(),
          SizedBox(height: 16.h),

          _buildPasswordField(),
          SizedBox(height: 16.h),

          _buildConfirmPasswordField(),
        ],
      ),
    );
  }

  Widget _buildRoleDropdown() {
    final roles = <String>[
      'مسؤول المنزل',
      'الأب',
      'الأم',
      'ابن',
      'بنت',
      'أخ',
      'أخت',
      'جد',
      'جدة',
      'ضيف',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الدور داخل العائلة',
          style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.silver),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          initialValue: _familyRole,
          items: roles
              .map((r) => DropdownMenuItem<String>(
                    value: r,
                    child: Text(r),
                  ))
              .toList(),
          onChanged: (v) {
            setState(() => _familyRole = v);
            HapticFeedback.lightImpact();
          },
          validator: (v) => (v == null || v.isEmpty) ? 'اختر الدور' : null,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.group_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return _buildTextField(
      controller: _passwordController,
      label: 'كلمة المرور',
      hint: '••••••••',
      icon: Icons.lock_outline,
      isPassword: true,
      obscureText: _obscurePassword,
      onToggleObscure: () =>
          setState(() => _obscurePassword = !_obscurePassword),
      validator: (value) {
        if (value == null || value.isEmpty) return 'الرجاء إدخال كلمة المرور';
        if (value.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return _buildTextField(
      controller: _confirmPasswordController,
      label: 'تأكيد كلمة المرور',
      hint: '••••••••',
      icon: Icons.lock_outline,
      isPassword: true,
      obscureText: _obscureConfirmPassword,
      onToggleObscure: () =>
          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
      validator: (value) {
        if (value == null || value.isEmpty) return 'الرجاء تأكيد كلمة المرور';
        if (value != _passwordController.text) {
          return 'كلمات المرور غير متطابقة';
        }
        return null;
      },
    );
  }

  // ===================== STEP 2 =====================

  Widget _buildStep2FaceCapture() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سجّل وجهك عبر فيديو مباشر (10 لقطات) للتحقق الحيوي.',
          style: TextStyle(fontSize: 13.sp, color: AppColors.silver),
        ),
        SizedBox(height: 16.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.charcoal,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: _faceFrames.length >= 10
                  ? AppColors.neonBlue
                  : AppColors.darkGrey,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _faceFrames.length >= 10
                    ? 'تم اختبار الكاميرا بنجاح (${_faceFrames.length}/10)'
                    : 'اختياري: اختبر الكاميرا الآن قبل إنهاء التسجيل.',
                style: TextStyle(
                  color: _faceFrames.length >= 10
                      ? AppColors.neonBlue
                      : AppColors.silver,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 10.h),
              ElevatedButton.icon(
                onPressed: _captureFaceFramesFlow,
                icon: const Icon(Icons.videocam_outlined),
                label: Text(
                  _faceFrames.length >= 10
                      ? 'إعادة اختبار الكاميرا'
                      : 'اختبار الكاميرا',
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          'صورة الملف الشخصي (Profile):',
          style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.silver),
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            _profilePreview(),
            SizedBox(width: 14.w),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickProfileImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('اختر صورة'),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        if (!_step2Complete)
          Text(
            'يجب إضافة صورة بروفايل. تسجيل الحركة سيتم أثناء إنهاء الحساب مع تعليمات واضحة.',
            style: TextStyle(fontSize: 12.sp, color: AppColors.error),
          ),
      ],
    );
  }

  Widget _profilePreview() {
    return Container(
      width: 64.w,
      height: 64.w,
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        shape: BoxShape.circle,
        border: Border.all(
            color: _profileImage != null
                ? AppColors.neonBlue
                : AppColors.darkGrey),
      ),
      child: ClipOval(
        child: _profileImage == null
            ? const Icon(Icons.person_outline)
            : Image.file(_profileImage!, fit: BoxFit.cover),
      ),
    );
  }

  // ===================== Shared Widgets =====================

  Widget _buildPrimaryButton() {
    if (_currentStep == 0) {
      return AnimatedButton(
        text: 'التالي',
        isLoading: false,
        isEnabled: true,
        onPressed: _nextStep,
        icon: Icons.arrow_forward,
      );
    }

    return AnimatedButton(
      text: 'إنهاء وإنشاء الحساب',
      isLoading: _isLoading,
      isEnabled: _step2Complete,
      onPressed: _finishRegister,
      icon: Icons.person_add,
    );
  }

  Widget _buildSecondaryAction() {
    if (_currentStep == 0) {
      return _buildLoginLink();
    }
    return Center(
      child: TextButton(
        onPressed: _backStep,
        child: const Text('رجوع للمرحلة الأولى'),
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
    bool? obscureText,
    VoidCallback? onToggleObscure,
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
              color: AppColors.silver),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText ?? false,
          validator: validator,
          style: TextStyle(fontSize: 16.sp, color: AppColors.white),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 22.sp),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                        obscureText! ? Icons.visibility_off : Icons.visibility,
                        size: 22.sp),
                    onPressed: onToggleObscure,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return GestureDetector(
      onTap: () {
        setState(() => _agreeToTerms = !_agreeToTerms);
        HapticFeedback.lightImpact();
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24.w,
            height: 24.w,
            decoration: BoxDecoration(
              color: _agreeToTerms ? AppColors.neonBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(
                color: _agreeToTerms ? AppColors.neonBlue : AppColors.silver,
                width: 2,
              ),
            ),
            child: _agreeToTerms
                ? Icon(Icons.check, size: 16.sp, color: AppColors.white)
                : null,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13.sp, color: AppColors.silver),
                children: const [
                  TextSpan(text: 'أوافق على '),
                  TextSpan(
                    text: 'الشروط والأحكام',
                    style: TextStyle(
                        color: AppColors.neonBlue, fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: ' و '),
                  TextSpan(
                    text: 'سياسة الخصوصية',
                    style: TextStyle(
                        color: AppColors.neonBlue, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('لديك حساب بالفعل؟',
              style: TextStyle(fontSize: 14.sp, color: AppColors.silver)),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.pop();
            },
            child: Text(
              'تسجيل الدخول',
              style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neonBlue),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraCaptureDialog extends StatefulWidget {
  final CameraDescription camera;
  final String title;

  const _CameraCaptureDialog({required this.camera, required this.title});

  @override
  State<_CameraCaptureDialog> createState() => _CameraCaptureDialogState();
}

class _CameraCaptureDialogState extends State<_CameraCaptureDialog> {
  CameraController? _controller;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final ctrl = CameraController(
        widget.camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await ctrl.initialize();
      if (!mounted) return;
      setState(() => _controller = ctrl);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'فشل تشغيل الكاميرا: $e');
    }
  }

  Future<void> _capture() async {
    if (_busy || _controller == null || !_controller!.value.isInitialized) {
      return;
    }

    setState(() => _busy = true);
    try {
      final file = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'فشل الالتقاط: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.charcoal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: AppColors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10.h),
            Container(
              height: 340.h,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.darkGrey),
                color: AppColors.primaryBlack,
              ),
              clipBehavior: Clip.antiAlias,
              child: _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: AppColors.error, fontSize: 12.sp),
                      ),
                    )
                  : (_controller != null && _controller!.value.isInitialized)
                      ? CameraPreview(_controller!)
                      : const Center(child: CircularProgressIndicator()),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('إلغاء'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _capture,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(_busy ? 'جارٍ الالتقاط...' : 'التقاط'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceFramesCaptureDialog extends StatefulWidget {
  final String title;
  final String instruction;

  const _FaceFramesCaptureDialog({
    required this.title,
    required this.instruction,
  });

  @override
  State<_FaceFramesCaptureDialog> createState() =>
      _FaceFramesCaptureDialogState();
}

class _FaceFramesCaptureDialogState extends State<_FaceFramesCaptureDialog> {
  CameraController? _controller;
  Timer? _timer;
  bool _capturing = false;
  bool _busy = false;
  String? _error;
  final List<String> _frames = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _error = 'لا توجد كاميرا متاحة');
        return;
      }
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );

      final ctrl = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await ctrl.initialize();
      if (!mounted) return;
      setState(() => _controller = ctrl);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'فشل تشغيل الكاميرا: $e');
    }
  }

  void _startCapture() {
    if (_capturing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    setState(() {
      _capturing = true;
      _error = null;
      _frames.clear();
    });

    _timer = Timer.periodic(const Duration(milliseconds: 450), (timer) async {
      if (_busy || _controller == null) return;
      _busy = true;
      try {
        final shot = await _controller!.takePicture();
        final bytes = await shot.readAsBytes();
        _frames.add('data:image/jpeg;base64,${base64Encode(bytes)}');

        if (!mounted) return;
        setState(() {});

        if (_frames.length >= 10) {
          timer.cancel();
          if (!mounted) return;
          Navigator.of(context).pop(_frames);
        }
      } catch (e) {
        timer.cancel();
        if (!mounted) return;
        setState(() {
          _capturing = false;
          _error = 'فشل التقاط الإطارات: $e';
        });
      } finally {
        _busy = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.charcoal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: AppColors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              widget.instruction,
              style: TextStyle(color: AppColors.neonBlue, fontSize: 12.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4.h),
            Text(
              'نصيحة: اجعل وجهك داخل الإطار، بإضاءة جيدة، وتجنب الحركة السريعة.',
              style: TextStyle(color: AppColors.silver, fontSize: 12.sp),
            ),
            SizedBox(height: 10.h),
            Container(
              height: 340.h,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.darkGrey),
                color: AppColors.primaryBlack,
              ),
              clipBehavior: Clip.antiAlias,
              child: _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: AppColors.error, fontSize: 12.sp),
                      ),
                    )
                  : (_controller != null && _controller!.value.isInitialized)
                      ? CameraPreview(_controller!)
                      : const Center(child: CircularProgressIndicator()),
            ),
            SizedBox(height: 10.h),
            Text(
              'تم التقاط: ${_frames.length}/10',
              style: TextStyle(color: AppColors.silver, fontSize: 12.sp),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إلغاء'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _capturing ? null : _startCapture,
                    icon: const Icon(Icons.videocam_outlined),
                    label:
                        Text(_capturing ? 'جارٍ الالتقاط...' : 'ابدأ الالتقاط'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
