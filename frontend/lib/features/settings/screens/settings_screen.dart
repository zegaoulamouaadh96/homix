import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_home_security/core/theme/app_colors.dart';
import 'package:smart_home_security/core/router/app_router.dart';
import 'package:smart_home_security/core/services/api_service.dart';

/// شاشة الإعدادات
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            backgroundColor: AppColors.primaryBlack,
            expandedHeight: 120.h,
            pinned: true,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.charcoal,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.white,
                  size: 18.sp,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'الإعدادات',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
              centerTitle: true,
            ),
          ),

          // Settings List
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ===== Account Section =====
                _buildSectionHeader('الحساب'),
                SizedBox(height: 8.h),

                _buildSettingsTile(
                  context: context,
                  icon: Icons.person_outline,
                  iconColor: AppColors.neonBlue,
                  title: 'الملف الشخصي',
                  subtitle: 'عرض وتعديل معلوماتك',
                  onTap: () => context.push(AppRoutes.profile),
                ),
                SizedBox(height: 8.h),

                _buildSettingsTile(
                  context: context,
                  icon: Icons.lock_outline,
                  iconColor: AppColors.neonPurple,
                  title: 'تغيير كلمة المرور',
                  subtitle: 'تحديث كلمة مرور حسابك',
                  onTap: () => context.push(AppRoutes.changePassword),
                ),

                SizedBox(height: 24.h),

                // ===== Home Section =====
                _buildSectionHeader('المنزل'),
                SizedBox(height: 8.h),

                _buildSettingsTile(
                  context: context,
                  icon: Icons.people_outline,
                  iconColor: AppColors.neonGreen,
                  title: 'أعضاء المنزل',
                  subtitle: 'عرض الأعضاء وحالة تواجدهم',
                  onTap: () => context.push(AppRoutes.members),
                ),

                SizedBox(height: 24.h),

                // ===== App Section =====
                _buildSectionHeader('التطبيق'),
                SizedBox(height: 8.h),

                _buildSettingsTile(
                  context: context,
                  icon: Icons.info_outline,
                  iconColor: AppColors.silver,
                  title: 'حول التطبيق',
                  subtitle: 'HomiX v1.0.0',
                  onTap: () => _showAboutDialog(context),
                ),

                SizedBox(height: 8.h),

                _buildSettingsTile(
                  context: context,
                  icon: Icons.language_outlined,
                  iconColor: AppColors.neonBlue,
                  title: 'PFE Web',
                  subtitle: 'عرض صفحات الموقع داخل التطبيق',
                  onTap: () => context.push(AppRoutes.pfeWeb),
                ),

                SizedBox(height: 40.h),

                // ===== Logout =====
                _buildLogoutButton(context),

                SizedBox(height: 40.h),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(right: 4.w, top: 8.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.neonBlue,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: AppColors.darkGrey,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: iconColor, size: 24.sp),
            ),
            SizedBox(width: 16.w),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.silver,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.arrow_back_ios,
              color: AppColors.darkGrey,
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLogoutConfirmation(context),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: AppColors.error, size: 22.sp),
            SizedBox(width: 12.w),
            Text(
              'تسجيل الخروج',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.charcoal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Icon(Icons.logout, color: AppColors.error, size: 28.sp),
            SizedBox(width: 12.w),
            Text(
              'تسجيل الخروج',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20.sp,
              ),
            ),
          ],
        ),
        content: Text(
          'هل تريد تسجيل الخروج من حسابك؟',
          style: TextStyle(
            color: AppColors.silver,
            fontSize: 14.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: AppColors.silver),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService().logout();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.charcoal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                gradient: AppColors.glowGradient,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(Icons.home, color: AppColors.white, size: 24.sp),
            ),
            SizedBox(width: 12.w),
            Text(
              'HomiX',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نظام أمان المنزل الذكي',
              style: TextStyle(
                color: AppColors.neonBlue,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'الإصدار 1.0.0',
              style: TextStyle(color: AppColors.silver, fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            Text(
              'تطبيق متكامل لمراقبة وإدارة أمان المنزل الذكي مع دعم الكاميرات والمستشعرات والتحكم عن بعد.',
              style: TextStyle(
                color: AppColors.silver,
                fontSize: 13.sp,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'حسنًا',
              style: TextStyle(color: AppColors.neonBlue),
            ),
          ),
        ],
      ),
    );
  }
}
