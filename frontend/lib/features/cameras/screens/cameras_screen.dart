import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smart_home_security/core/services/api_service.dart';
import 'package:smart_home_security/core/theme/app_colors.dart';

/// شاشة الكاميرات الديناميكية المرتبطة بالسيرفر
class CamerasScreen extends StatefulWidget {
  const CamerasScreen({super.key});

  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  final ApiService _api = ApiService();

  Timer? _pollTimer;
  int? _homeId;
  bool _isLoading = true;
  String? _error;
  int _selectedCameraIndex = 0;
  List<Map<String, dynamic>> _cameras = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final homeId = await _api.getHomeId();
    if (!mounted) return;

    if (homeId == null) {
      setState(() {
        _isLoading = false;
        _error = 'لم يتم ربط هذا الحساب بمنزل بعد';
      });
      return;
    }

    _homeId = homeId;
    await _loadCameras();

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _loadCameras(silent: true);
    });
  }

  bool _isCamera(Map<String, dynamic> d) {
    final category = (d['category'] ?? '').toString().toLowerCase();
    final id = (d['device_id'] ?? '').toString().toLowerCase();
    return category == 'camera' || id.contains('cam') || id.contains('camera');
  }

  Future<void> _loadCameras({bool silent = false}) async {
    final homeId = _homeId;
    if (homeId == null) return;

    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final result = await _api.getDevicesCatalog(homeId);
    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _isLoading = false;
        _error = result.errorMessage;
      });
      return;
    }

    final raw = (result.data?['devices'] as List?) ?? const [];
    final cameras = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
        .where(_isCamera)
        .toList();

    final clampedIndex =
        cameras.isEmpty ? 0 : _selectedCameraIndex.clamp(0, cameras.length - 1);

    setState(() {
      _isLoading = false;
      _error = null;
      _cameras = cameras;
      _selectedCameraIndex = clampedIndex;
    });
  }

  Future<void> _showAddCameraDialog() async {
    final homeId = _homeId;
    if (homeId == null) return;

    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final streamCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.charcoal,
        title: const Text('إضافة كاميرا'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الكاميرا'),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: idCtrl,
                decoration: const InputDecoration(
                  labelText: 'Device ID (اختياري)',
                ),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: locationCtrl,
                decoration:
                    const InputDecoration(labelText: 'الموقع (اختياري)'),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: streamCtrl,
                decoration: const InputDecoration(
                  labelText: 'stream_url (اختياري)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final result = await _api.addDevice(
      homeId: homeId,
      name: name,
      category: 'camera',
      deviceId: idCtrl.text.trim().isEmpty ? null : idCtrl.text.trim(),
      location:
          locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
      metadata: {
        if (streamCtrl.text.trim().isNotEmpty)
          'stream_url': streamCtrl.text.trim(),
      },
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? 'تمت إضافة الكاميرا' : result.errorMessage),
        backgroundColor: result.ok ? AppColors.secure : AppColors.error,
      ),
    );

    if (result.ok) {
      HapticFeedback.mediumImpact();
      await _loadCameras();
    }
  }

  Future<void> _deleteSelectedCamera() async {
    final homeId = _homeId;
    if (homeId == null || _cameras.isEmpty) return;

    final selected = _cameras[_selectedCameraIndex];
    final deviceId = (selected['device_id'] ?? '').toString();
    if (deviceId.isEmpty) return;

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.charcoal,
        title: const Text('حذف الكاميرا'),
        content:
            Text('هل تريد حذف ${(selected['name'] ?? deviceId).toString()}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (approved != true) return;

    final result = await _api.deleteDevice(homeId: homeId, deviceId: deviceId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? 'تم حذف الكاميرا' : result.errorMessage),
        backgroundColor: result.ok ? AppColors.warning : AppColors.error,
      ),
    );

    if (result.ok) await _loadCameras();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.primaryBlack,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.primaryBlack,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.error, fontSize: 14.sp),
                ),
                SizedBox(height: 12.h),
                ElevatedButton(
                  onPressed: _bootstrap,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'الكاميرات (${_cameras.length})',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _loadCameras,
                    icon: const Icon(Icons.refresh, color: AppColors.silver),
                  ),
                  IconButton(
                    onPressed: _showAddCameraDialog,
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppColors.neonBlue),
                  ),
                  IconButton(
                    onPressed: _deleteSelectedCamera,
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.warning),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              if (_cameras.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_off_outlined,
                            color: AppColors.silver, size: 52.sp),
                        SizedBox(height: 10.h),
                        Text('لا توجد كاميرات بعد',
                            style: TextStyle(
                                color: AppColors.silver, fontSize: 14.sp)),
                        SizedBox(height: 10.h),
                        ElevatedButton(
                          onPressed: _showAddCameraDialog,
                          child: const Text('إضافة أول كاميرا'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                _buildMainCard(_cameras[_selectedCameraIndex]),
                SizedBox(height: 14.h),
                Expanded(
                  child: ListView.separated(
                    itemCount: _cameras.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8.h),
                    itemBuilder: (context, index) {
                      final camera = _cameras[index];
                      final state = Map<String, dynamic>.from(
                        (camera['state'] as Map?)?.cast<String, dynamic>() ??
                            {},
                      );
                      final online = state['online'] == true;

                      return ListTile(
                        tileColor: index == _selectedCameraIndex
                            ? AppColors.charcoal
                            : AppColors.deepBlack,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r)),
                        leading: Icon(
                          online ? Icons.videocam : Icons.videocam_off,
                          color: online ? AppColors.secure : AppColors.error,
                        ),
                        title: Text(
                          (camera['name'] ?? camera['device_id']).toString(),
                          style: const TextStyle(color: AppColors.white),
                        ),
                        subtitle: Text(
                          (camera['location'] ?? 'بدون موقع').toString(),
                          style: const TextStyle(color: AppColors.silver),
                        ),
                        trailing: Icon(
                          state['motion'] == true
                              ? Icons.motion_photos_on
                              : Icons.chevron_right,
                          color: state['motion'] == true
                              ? AppColors.warning
                              : AppColors.silver,
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedCameraIndex = index);
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard(Map<String, dynamic> camera) {
    final state = Map<String, dynamic>.from(
      (camera['state'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    final metadata = Map<String, dynamic>.from(
      (camera['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    final online = state['online'] == true;
    final stream = metadata['stream_url']?.toString();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: online
              ? AppColors.secure.withValues(alpha: 0.5)
              : AppColors.error.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                online ? Icons.circle : Icons.circle_outlined,
                size: 12.sp,
                color: online ? AppColors.secure : AppColors.error,
              ),
              SizedBox(width: 8.w),
              Text(
                online ? 'متصلة' : 'غير متصلة',
                style: TextStyle(
                    color: online ? AppColors.secure : AppColors.error),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            (camera['name'] ?? '').toString(),
            style: TextStyle(
              fontSize: 18.sp,
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'الموقع: ${(camera['location'] ?? 'غير محدد').toString()}',
            style: TextStyle(fontSize: 13.sp, color: AppColors.silver),
          ),
          SizedBox(height: 6.h),
          Text(
            'المعرف: ${(camera['device_id'] ?? '').toString()}',
            style: TextStyle(fontSize: 12.sp, color: AppColors.silver),
          ),
          if (stream != null && stream.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              'stream_url: $stream',
              style: TextStyle(fontSize: 12.sp, color: AppColors.neonBlue),
            ),
          ],
        ],
      ),
    );
  }
}
