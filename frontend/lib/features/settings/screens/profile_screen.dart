import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_home_security/core/theme/app_colors.dart';
import 'package:smart_home_security/core/services/api_service.dart';

/// شاشة الملف الشخصي
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;

  String? _email;
  String? _phone;
  String? _role;
  String? _homeName;
  String? _homeCode;
  String? _createdAt;

  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadProfile();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final result = await _api.getProfile();
    if (result.ok && result.data != null) {
      final user = result.data!['user'];
      setState(() {
        _email = user['email']?.toString();
        _phone = user['phone']?.toString();
        _role = user['role']?.toString();
        _homeName = user['home_name']?.toString();
        _homeCode = user['home_code']?.toString();
        _createdAt = user['created_at']?.toString();
        _emailController.text = _email ?? '';
        _phoneController.text = _phone ?? '';
        _loading = false;
      });
      _animController.forward();
    } else {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final result = await _api.updateProfile(
      email: _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
      phone: _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null,
    );

    setState(() => _saving = false);

    if (result.ok) {
      setState(() {
        _editing = false;
        _email = _emailController.text.trim();
        _phone = _phoneController.text.trim();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الملف الشخصي بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _translateRole(String? role) {
    switch (role) {
      case 'owner':
        return 'مالك المنزل';
      case 'admin':
        return 'مدير';
      case 'resident':
        return 'مقيم';
      case 'guest':
        return 'ضيف';
      default:
        return 'غير محدد';
    }
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'owner':
        return AppColors.neonBlue;
      case 'admin':
        return AppColors.neonPurple;
      case 'resident':
        return AppColors.neonGreen;
      case 'guest':
        return AppColors.warning;
      default:
        return AppColors.silver;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlack,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'الملف الشخصي',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.charcoal,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.arrow_forward_ios,
                color: AppColors.white, size: 18.sp),
          ),
        ),
        actions: [
          if (!_loading)
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                if (_editing) {
                  _saveProfile();
                } else {
                  setState(() => _editing = true);
                }
              },
              icon: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: _editing
                      ? AppColors.neonBlue.withValues(alpha: 0.2)
                      : AppColors.charcoal,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: _saving
                    ? SizedBox(
                        width: 18.sp,
                        height: 18.sp,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.neonBlue,
                        ),
                      )
                    : Icon(
                        _editing ? Icons.check : Icons.edit_outlined,
                        color:
                            _editing ? AppColors.neonBlue : AppColors.white,
                        size: 18.sp,
                      ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.neonBlue),
            )
          : FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(20.w),
                child: Column(
                  children: [
                    // Avatar
                    _buildAvatar(),
                    SizedBox(height: 32.h),

                    // Info cards
                    _buildInfoCard(
                      icon: Icons.email_outlined,
                      label: 'البريد الإلكتروني',
                      value: _email ?? 'غير محدد',
                      controller: _emailController,
                      editable: _editing,
                    ),
                    SizedBox(height: 12.h),

                    _buildInfoCard(
                      icon: Icons.phone_outlined,
                      label: 'رقم الهاتف',
                      value: _phone ?? 'غير محدد',
                      controller: _phoneController,
                      editable: _editing,
                    ),
                    SizedBox(height: 12.h),

                    _buildInfoCard(
                      icon: Icons.shield_outlined,
                      label: 'الدور',
                      value: _translateRole(_role),
                      valueColor: _roleColor(_role),
                    ),
                    SizedBox(height: 12.h),

                    _buildInfoCard(
                      icon: Icons.home_outlined,
                      label: 'المنزل',
                      value: _homeName ?? _homeCode ?? 'غير مرتبط',
                    ),
                    SizedBox(height: 12.h),

                    _buildInfoCard(
                      icon: Icons.calendar_today_outlined,
                      label: 'تاريخ الإنشاء',
                      value: _formatDate(_createdAt),
                    ),

                    if (_editing) ...[
                      SizedBox(height: 24.h),
                      _buildCancelButton(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow
        Container(
          width: 100.w,
          height: 100.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.neonBlue.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
        // Avatar
        Container(
          width: 100.w,
          height: 100.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.glowGradient,
            border: Border.all(
              color: AppColors.neonBlue.withValues(alpha: 0.5),
              width: 3,
            ),
          ),
          child: Icon(
            Icons.person,
            color: AppColors.white,
            size: 48.sp,
          ),
        ),
        // Role badge
        Positioned(
          bottom: 0,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: _roleColor(_role),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              _translateRole(_role),
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlack,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    TextEditingController? controller,
    bool editable = false,
    Color? valueColor,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: editable
              ? AppColors.neonBlue.withValues(alpha: 0.3)
              : AppColors.darkGrey,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.neonBlue, size: 22.sp),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.silver,
                  ),
                ),
                SizedBox(height: 4.h),
                editable && controller != null
                    ? TextField(
                        controller: controller,
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: AppColors.white,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: label,
                          hintStyle: TextStyle(
                            color: AppColors.darkGrey,
                            fontSize: 15.sp,
                          ),
                        ),
                      )
                    : Text(
                        value,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: valueColor ?? AppColors.white,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _editing = false;
          _emailController.text = _email ?? '';
          _phoneController.text = _phone ?? '';
        });
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.darkGrey,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Center(
          child: Text(
            'إلغاء التعديل',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.silver,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'غير معروف';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
