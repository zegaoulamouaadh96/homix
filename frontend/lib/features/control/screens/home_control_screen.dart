import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smart_home_security/core/services/api_service.dart';
import 'package:smart_home_security/core/services/biometric_service.dart';
import 'package:smart_home_security/core/theme/app_colors.dart';

/// شاشة التحكم الديناميكي بالأبواب والنوافذ عبر السيرفر + MQTT
class HomeControlScreen extends StatefulWidget {
  const HomeControlScreen({super.key});

  @override
  State<HomeControlScreen> createState() => _HomeControlScreenState();
}

class _HomeControlScreenState extends State<HomeControlScreen> {
  final ApiService _api = ApiService();
  final BiometricService _biometric = BiometricService();

  Timer? _pollTimer;
  int? _homeId;
  bool _isLoading = true;
  String? _error;
  bool _biometricAvailable = false;

  List<Map<String, dynamic>> _doors = [];
  List<Map<String, dynamic>> _windows = [];

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
    await _checkBiometric();
    await _loadDevices();

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _loadDevices(silent: true);
    });
  }

  Future<void> _checkBiometric() async {
    final supported = await _biometric.isDeviceSupported();
    final hasBio = await _biometric.hasBiometrics();
    if (!mounted) return;
    setState(() => _biometricAvailable = supported && hasBio);
  }

  bool _isDoor(Map<String, dynamic> d) {
    final category = (d['category'] ?? '').toString().toLowerCase();
    final id = (d['device_id'] ?? '').toString().toLowerCase();
    return category == 'door' || id.contains('door');
  }

  bool _isWindow(Map<String, dynamic> d) {
    final category = (d['category'] ?? '').toString().toLowerCase();
    final id = (d['device_id'] ?? '').toString().toLowerCase();
    return category == 'window' || id.contains('window');
  }

  Future<void> _loadDevices({bool silent = false}) async {
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
    final all = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
        .toList();

    setState(() {
      _isLoading = false;
      _error = null;
      _doors = all.where(_isDoor).toList();
      _windows = all.where(_isWindow).toList();
    });
  }

  bool _needsReauth(String cmd) {
    return cmd == 'UNLOCK_DOOR' || cmd == 'OPEN_WINDOW';
  }

  Future<String?> _reauthTokenIfNeeded(String cmd) async {
    if (!_needsReauth(cmd)) return null;

    if (!_biometricAvailable) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا الأمر يحتاج بصمة/وجه مفعّل على الجهاز'),
          backgroundColor: AppColors.warning,
        ),
      );
      return null;
    }

    final authenticated = await _biometric.authenticate(
      reason: 'تأكيد أمر حساس للمنزل',
    );
    if (!authenticated) return null;

    final tokenResult = await _api.requestReauth();
    if (!tokenResult.ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tokenResult.errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    }

    return tokenResult.data?['reauth_token']?.toString();
  }

  Future<void> _sendDeviceCommand({
    required String deviceId,
    required String cmd,
    dynamic value,
  }) async {
    final homeId = _homeId;
    if (homeId == null) return;

    final reauth = await _reauthTokenIfNeeded(cmd);
    if (_needsReauth(cmd) && reauth == null) return;

    final result = await _api.sendCommand(
      homeId: homeId,
      deviceId: deviceId,
      cmd: cmd,
      value: value,
      reauthToken: reauth,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? 'تم إرسال الأمر' : result.errorMessage),
        backgroundColor: result.ok ? AppColors.secure : AppColors.error,
      ),
    );

    if (result.ok) {
      HapticFeedback.mediumImpact();
      await _loadDevices(silent: true);
    }
  }

  Future<void> _addDeviceDialog({required String category}) async {
    final homeId = _homeId;
    if (homeId == null) return;

    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final locationCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.charcoal,
        title: Text(category == 'door' ? 'إضافة باب' : 'إضافة نافذة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم')),
              SizedBox(height: 10.h),
              TextField(
                  controller: idCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Device ID (اختياري)')),
              SizedBox(height: 10.h),
              TextField(
                  controller: locationCtrl,
                  decoration:
                      const InputDecoration(labelText: 'الموقع (اختياري)')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إضافة')),
        ],
      ),
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final result = await _api.addDevice(
      homeId: homeId,
      name: name,
      category: category,
      deviceId: idCtrl.text.trim().isEmpty ? null : idCtrl.text.trim(),
      location:
          locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? 'تمت الإضافة بنجاح' : result.errorMessage),
        backgroundColor: result.ok ? AppColors.secure : AppColors.error,
      ),
    );

    if (result.ok) await _loadDevices();
  }

  Future<void> _deleteDevice(Map<String, dynamic> device) async {
    final homeId = _homeId;
    if (homeId == null) return;

    final deviceId = (device['device_id'] ?? '').toString();
    if (deviceId.isEmpty) return;

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.charcoal,
        title: const Text('حذف الجهاز'),
        content:
            Text('هل تريد حذف ${(device['name'] ?? deviceId).toString()}؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );

    if (approved != true) return;

    final result = await _api.deleteDevice(homeId: homeId, deviceId: deviceId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? 'تم حذف الجهاز' : result.errorMessage),
        backgroundColor: result.ok ? AppColors.warning : AppColors.error,
      ),
    );

    if (result.ok) await _loadDevices();
  }

  Future<void> _lockAllDoors() async {
    for (final d in _doors) {
      final deviceId = (d['device_id'] ?? '').toString();
      if (deviceId.isEmpty) continue;
      await _sendDeviceCommand(deviceId: deviceId, cmd: 'LOCK_DOOR');
    }
  }

  Future<void> _closeAllWindows() async {
    for (final w in _windows) {
      final deviceId = (w['device_id'] ?? '').toString();
      if (deviceId.isEmpty) continue;
      await _sendDeviceCommand(deviceId: deviceId, cmd: 'CLOSE_WINDOW');
    }
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
                Text(_error!,
                    style: TextStyle(color: AppColors.error, fontSize: 14.sp),
                    textAlign: TextAlign.center),
                SizedBox(height: 12.h),
                ElevatedButton(
                    onPressed: _bootstrap, child: const Text('إعادة المحاولة')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDevices,
          child: ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'التحكم بالمنزل',
                      style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white),
                    ),
                  ),
                  IconButton(
                      onPressed: _loadDevices,
                      icon: const Icon(Icons.refresh, color: AppColors.silver)),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                'الأبواب: ${_doors.length} • النوافذ: ${_windows.length}',
                style: TextStyle(color: AppColors.silver, fontSize: 13.sp),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _lockAllDoors,
                      icon: const Icon(Icons.lock),
                      label: const Text('قفل كل الأبواب'),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _closeAllWindows,
                      icon: const Icon(Icons.window),
                      label: const Text('إغلاق كل النوافذ'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _addDeviceDialog(category: 'door'),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة باب'),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _addDeviceDialog(category: 'window'),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة نافذة'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),
              Text('الأبواب',
                  style: TextStyle(
                      fontSize: 18.sp,
                      color: AppColors.white,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 10.h),
              if (_doors.isEmpty)
                _emptyBlock('لا توجد أبواب مضافة')
              else
                ..._doors.map(_buildDoorCard),
              SizedBox(height: 18.h),
              Text('النوافذ',
                  style: TextStyle(
                      fontSize: 18.sp,
                      color: AppColors.white,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 10.h),
              if (_windows.isEmpty)
                _emptyBlock('لا توجد نوافذ مضافة')
              else
                ..._windows.map(_buildWindowCard),
              SizedBox(height: 110.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyBlock(String text) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.silver)),
    );
  }

  Widget _buildDoorCard(Map<String, dynamic> door) {
    final state = Map<String, dynamic>.from(
        (door['state'] as Map?)?.cast<String, dynamic>() ?? {});
    final isOpen = state['open'] == true;
    final isLocked = state['locked'] != false;
    final online = state['online'] == true;
    final deviceId = (door['device_id'] ?? '').toString();

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
            color:
                online ? AppColors.darkGrey : AppColors.error.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(isLocked ? Icons.lock : Icons.lock_open,
                  color: isLocked ? AppColors.secure : AppColors.warning),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((door['name'] ?? deviceId).toString(),
                        style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700)),
                    Text(
                      '${(door['location'] ?? 'بدون موقع').toString()} • ${online ? 'متصل' : 'غير متصل'}',
                      style: const TextStyle(color: AppColors.silver),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _deleteDevice(door),
                icon:
                    const Icon(Icons.delete_outline, color: AppColors.warning),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _sendDeviceCommand(
                    deviceId: deviceId,
                    cmd: isLocked ? 'UNLOCK_DOOR' : 'LOCK_DOOR',
                  ),
                  child: Text(isLocked ? 'فتح القفل' : 'قفل الباب'),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _sendDeviceCommand(
                    deviceId: deviceId,
                    cmd: isOpen ? 'CLOSE_DOOR' : 'OPEN_DOOR',
                  ),
                  child: Text(isOpen ? 'إغلاق الباب' : 'فتح الباب'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWindowCard(Map<String, dynamic> window) {
    final state = Map<String, dynamic>.from(
        (window['state'] as Map?)?.cast<String, dynamic>() ?? {});
    final isOpen = state['open'] == true;
    final online = state['online'] == true;
    final deviceId = (window['device_id'] ?? '').toString();

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
            color:
                online ? AppColors.darkGrey : AppColors.error.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.window,
                  color: isOpen ? AppColors.warning : AppColors.secure),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((window['name'] ?? deviceId).toString(),
                        style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700)),
                    Text(
                      '${(window['location'] ?? 'بدون موقع').toString()} • ${online ? 'متصل' : 'غير متصل'}',
                      style: const TextStyle(color: AppColors.silver),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _deleteDevice(window),
                icon:
                    const Icon(Icons.delete_outline, color: AppColors.warning),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _sendDeviceCommand(
                    deviceId: deviceId,
                    cmd: isOpen ? 'CLOSE_WINDOW' : 'OPEN_WINDOW',
                  ),
                  child: Text(isOpen ? 'إغلاق النافذة' : 'فتح النافذة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
