import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_home_security/core/theme/app_colors.dart';
import 'package:smart_home_security/core/services/api_service.dart';

/// شاشة أعضاء المنزل
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _members = [];
  int _totalCount = 0;
  int _activeCount = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadMembers();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final homeId = await _api.getHomeId();
    if (homeId == null) {
      setState(() => _loading = false);
      return;
    }

    final result = await _api.getMembers(homeId);
    if (result.ok && result.data != null) {
      final list = (result.data!['members'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      setState(() {
        _members = list;
        _totalCount = list.length;
        _activeCount = list.where((m) => m['is_active'] == 1).length;
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

  String _translateRole(String? role) {
    switch (role) {
      case 'owner':
        return 'مالك';
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

  IconData _roleIcon(String? role) {
    switch (role) {
      case 'owner':
        return Icons.star;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'resident':
        return Icons.person;
      case 'guest':
        return Icons.person_outline;
      default:
        return Icons.person;
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
          'أعضاء المنزل',
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
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.neonBlue),
            )
          : FadeTransition(
              opacity: _fadeAnim,
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() => _loading = true);
                  await _loadMembers();
                },
                color: AppColors.neonBlue,
                backgroundColor: AppColors.charcoal,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    // Summary card
                    SliverToBoxAdapter(
                      child: _buildSummaryCard(),
                    ),

                    // Members list
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 8.h),
                      sliver: _members.isEmpty
                          ? SliverToBoxAdapter(
                              child: _buildEmptyState(),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, index) {
                                  return TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration: Duration(
                                        milliseconds: 400 + index * 100),
                                    builder: (ctx, value, child) {
                                      return Opacity(
                                        opacity: value,
                                        child: Transform.translate(
                                          offset: Offset(0, 20 * (1 - value)),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _buildMemberCard(
                                        _members[index], index),
                                  );
                                },
                                childCount: _members.length,
                              ),
                            ),
                    ),

                    SliverToBoxAdapter(
                      child: SizedBox(height: 32.h),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.neonBlue.withValues(alpha: 0.15),
            AppColors.neonPurple.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.neonBlue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Total members
          Expanded(
            child: _buildStatItem(
              icon: Icons.people,
              value: '$_totalCount',
              label: 'إجمالي الأعضاء',
              color: AppColors.neonBlue,
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: 50.h,
            color: AppColors.darkGrey,
          ),

          // Active members
          Expanded(
            child: _buildStatItem(
              icon: Icons.circle,
              value: '$_activeCount',
              label: 'نشط حالياً',
              color: AppColors.neonGreen,
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: 50.h,
            color: AppColors.darkGrey,
          ),

          // Inactive
          Expanded(
            child: _buildStatItem(
              icon: Icons.circle_outlined,
              value: '${_totalCount - _activeCount}',
              label: 'غير نشط',
              color: AppColors.silver,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20.sp),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: AppColors.silver,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member, int index) {
    final role = member['role']?.toString();
    final isActive = member['is_active'] == 1;
    final email = member['email']?.toString();
    final phone = member['phone']?.toString();
    final displayName = email ?? phone ?? 'عضو ${index + 1}';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isActive
              ? _roleColor(role).withValues(alpha: 0.2)
              : AppColors.darkGrey,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 50.w,
                height: 50.w,
                decoration: BoxDecoration(
                  color: _roleColor(role).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _roleColor(role).withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _roleIcon(role),
                  color: _roleColor(role),
                  size: 24.sp,
                ),
              ),
              // Status indicator
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 14.w,
                  height: 14.w,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.neonGreen : AppColors.darkGrey,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.charcoal,
                      width: 2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.neonGreen.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(width: 16.w),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    // Role badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: _roleColor(role).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        _translateRole(role),
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: _roleColor(role),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Status text
                    Text(
                      isActive ? 'في المنزل' : 'خارج المنزل',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isActive
                            ? AppColors.neonGreen
                            : AppColors.silver,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status icon
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.neonGreen.withValues(alpha: 0.1)
                  : AppColors.darkGrey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              isActive ? Icons.home : Icons.logout,
              color: isActive ? AppColors.neonGreen : AppColors.silver,
              size: 20.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60.h),
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              color: AppColors.darkGrey,
              size: 64.sp,
            ),
            SizedBox(height: 16.h),
            Text(
              'لا يوجد أعضاء',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.silver,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'لم يتم العثور على أعضاء في هذا المنزل',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.darkGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
