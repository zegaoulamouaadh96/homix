import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_home_security/core/theme/app_colors.dart';
import 'package:smart_home_security/core/router/app_router.dart';
import 'package:smart_home_security/features/cameras/screens/cameras_screen.dart';
import 'package:smart_home_security/features/access/screens/guest_access_screen.dart';
import 'package:smart_home_security/features/control/screens/home_control_screen.dart';
import 'package:smart_home_security/features/sensors/screens/sensors_screen.dart';
import 'package:smart_home_security/features/home/widgets/custom_bottom_nav.dart';

/// الشاشة الرئيسية مع التنقل السفلي
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _fabController;
  late Animation<double> _fabScale;

  final List<Widget> _screens = [
    const CamerasScreen(),
    const GuestAccessScreen(),
    const HomeControlScreen(),
    const SensorsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _fabScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    if (index == _currentIndex) return;
    
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      extendBody: true,
      body: Stack(
        children: [
          // Pages
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: _screens,
          ),
          
          // Status overlay (optional notification badge)
          _buildStatusOverlay(),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabChanged,
      ),
      floatingActionButton: _buildEmergencyButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildStatusOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Settings button
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push(AppRoutes.settings);
                },
                child: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.charcoal.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: AppColors.darkGrey,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    color: AppColors.silver,
                    size: 22.sp,
                  ),
                ),
              ),
              // Home status indicator
              _buildStatusBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.secure.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.secure.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              color: AppColors.secure,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secure.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            'المنزل آمن',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.secure,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyButton() {
    return GestureDetector(
      onTapDown: (_) => _fabController.forward(),
      onTapUp: (_) => _fabController.reverse(),
      onTapCancel: () => _fabController.reverse(),
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _showEmergencyDialog();
      },
      onTap: () {
        HapticFeedback.mediumImpact();
        _showQuickActions();
      },
      child: AnimatedBuilder(
        animation: _fabController,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScale.value,
            child: Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.neonBlue,
                    AppColors.neonPurple,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonBlue.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.home,
                color: AppColors.white,
                size: 28.sp,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildQuickActionsSheet(),
    );
  }

  Widget _buildQuickActionsSheet() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.darkGrey,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          
          SizedBox(height: 24.h),
          
          Text(
            'إجراءات سريعة',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          
          SizedBox(height: 24.h),
          
          // Quick action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickAction(
                icon: Icons.lock,
                label: 'قفل الكل',
                color: AppColors.secure,
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.heavyImpact();
                },
              ),
              _buildQuickAction(
                icon: Icons.notifications_off,
                label: 'كتم الإنذار',
                color: AppColors.warning,
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.heavyImpact();
                },
              ),
              _buildQuickAction(
                icon: Icons.emergency,
                label: 'طوارئ',
                color: AppColors.error,
                onTap: () {
                  Navigator.pop(context);
                  _showEmergencyDialog();
                },
              ),
            ],
          ),
          
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.silver,
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.charcoal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Icon(Icons.emergency, color: AppColors.error, size: 28.sp),
            SizedBox(width: 12.w),
            Text(
              'حالة طوارئ',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20.sp,
              ),
            ),
          ],
        ),
        content: Text(
          'هل تريد تفعيل وضع الطوارئ؟\nسيتم:\n• تشغيل جميع الإنذارات\n• إقفال جميع الأبواب\n• إرسال إشعار طوارئ',
          style: TextStyle(
            color: AppColors.silver,
            fontSize: 14.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: AppColors.silver),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () {
              Navigator.pop(context);
              HapticFeedback.heavyImpact();
              // TODO: Activate emergency mode
            },
            child: const Text('تفعيل الطوارئ'),
          ),
        ],
      ),
    );
  }
}
