import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smart_home_security/core/services/api_service.dart';
import 'package:smart_home_security/core/theme/app_colors.dart';

/// شاشة الحساسات والإنذارات المرتبطة بـ MQTT عبر السيرفر
class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
  final ApiService _api = ApiService();

  Timer? _pollTimer;
  int? _homeId;
  int _selectedTab = 0;
  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _sensors = [];
  List<Map<String, dynamic>> _events = [];

  final List<String> _sensorCategories = [
    'seismic',
    'motion',
    'smoke',
    'flood',
    'glass',
    'custom',
  ];

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
    await _loadData();

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _loadData(silent: true);
    });
  }

  bool _isSensor(Map<String, dynamic> d) {
    final category = (d['category'] ?? '').toString().toLowerCase();
    return category != 'camera' && category != 'door' && category != 'window';
  }

  Future<void> _loadData({bool silent = false}) async {
    final homeId = _homeId;
    if (homeId == null) return;

    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final devicesResult = await _api.getDevicesCatalog(homeId);
    final eventsResult = await _api.getEvents(homeId);

    if (!mounted) return;

    if (!devicesResult.ok) {
      setState(() {
        _isLoading = false;
        _error = devicesResult.errorMessage;
      });
      return;
    }

    if (!eventsResult.ok) {
      setState(() {
        _isLoading = false;
        _error = eventsResult.errorMessage;
      });
      return;
    }

    final rawDevices = (devicesResult.data?['devices'] as List?) ?? const [];
    final rawEvents = (eventsResult.data?['events'] as List?) ?? const [];

    final sensors = rawDevices
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
        .where(_isSensor)
        .toList();

    final events = rawEvents
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
        .toList();

    setState(() {
      _isLoading = false;
      _error = null;
      _sensors = sensors;
      _events = events;
    });
  }

  Future<void> _showAddSensorDialog() async {
    final homeId = _homeId;
    if (homeId == null) return;

    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String category = 'seismic';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.charcoal,
              title: const Text('إضافة حساس جديد'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      items: _sensorCategories
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() => category = v);
                      },
                      decoration:
                          const InputDecoration(labelText: 'نوع الحساس'),
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'الاسم')),
                    SizedBox(height: 10.h),
                    TextField(
                        controller: idCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Device ID (اختياري)')),
                    SizedBox(height: 10.h),
                    TextField(
                        controller: locationCtrl,
                        decoration: const InputDecoration(
                            labelText: 'الموقع (اختياري)')),
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
            );
          },
        );
      },
    );

    if (confirmed != true) return;
    if (nameCtrl.text.trim().isEmpty) return;

    final result = await _api.addDevice(
      homeId: homeId,
      name: nameCtrl.text.trim(),
      category: category,
      deviceId: idCtrl.text.trim().isEmpty ? null : idCtrl.text.trim(),
      location:
          locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? 'تمت إضافة الحساس' : result.errorMessage),
        backgroundColor: result.ok ? AppColors.secure : AppColors.error,
      ),
    );

    if (result.ok) {
      HapticFeedback.mediumImpact();
      await _loadData();
    }
  }

  Future<void> _deleteSensor(Map<String, dynamic> sensor) async {
    final homeId = _homeId;
    if (homeId == null) return;

    final deviceId = (sensor['device_id'] ?? '').toString();
    if (deviceId.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.charcoal,
        title: const Text('حذف الحساس'),
        content:
            Text('هل تريد حذف ${(sensor['name'] ?? deviceId).toString()}؟'),
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

    if (ok != true) return;

    final result = await _api.deleteDevice(homeId: homeId, deviceId: deviceId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? 'تم حذف الحساس' : result.errorMessage),
        backgroundColor: result.ok ? AppColors.warning : AppColors.error,
      ),
    );

    if (result.ok) await _loadData();
  }

  Future<void> _toggleSensorArm(Map<String, dynamic> sensor) async {
    final homeId = _homeId;
    if (homeId == null) return;

    final deviceId = (sensor['device_id'] ?? '').toString();
    if (deviceId.isEmpty) return;

    final state = Map<String, dynamic>.from(
        (sensor['state'] as Map?)?.cast<String, dynamic>() ?? {});
    final armed = state['armed'] == true;

    final result = await _api.sendCommand(
      homeId: homeId,
      deviceId: deviceId,
      cmd: armed ? 'DISARM_SENSOR' : 'ARM_SENSOR',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? 'تم تحديث حالة الحساس' : result.errorMessage),
        backgroundColor: result.ok ? AppColors.secure : AppColors.error,
      ),
    );

    if (result.ok) await _loadData(silent: true);
  }

  String _eventMessage(Map<String, dynamic> event) {
    final type = (event['type'] ?? '').toString();
    final deviceName =
        (event['device_name'] ?? event['device_id'] ?? 'جهاز').toString();
    final payload = Map<String, dynamic>.from(
        (event['payload'] as Map?)?.cast<String, dynamic>() ?? {});

    if (type == 'command_sent') {
      return 'تم إرسال أمر ${payload['cmd'] ?? ''} إلى $deviceName';
    }
    if (type == 'ack') {
      return 'استجابة من $deviceName';
    }
    if (type == 'motion' || type == 'seismic' || type == 'triggered') {
      return 'إنذار من $deviceName';
    }

    return '$type • $deviceName';
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
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.error, fontSize: 14.sp)),
                SizedBox(height: 12.h),
                ElevatedButton(
                    onPressed: _bootstrap, child: const Text('إعادة المحاولة')),
              ],
            ),
          ),
        ),
      );
    }

    final triggeredCount = _sensors.where((s) {
      final state = Map<String, dynamic>.from(
          (s['state'] as Map?)?.cast<String, dynamic>() ?? {});
      return state['triggered'] == true || state['motion'] == true;
    }).length;

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
                      'الحساسات',
                      style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white),
                    ),
                  ),
                  IconButton(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh, color: AppColors.silver)),
                  IconButton(
                      onPressed: _showAddSensorDialog,
                      icon: const Icon(Icons.add_circle_outline,
                          color: AppColors.neonBlue)),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                'عدد الحساسات: ${_sensors.length} • الإنذارات الحالية: $triggeredCount',
                style: TextStyle(color: AppColors.silver, fontSize: 13.sp),
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: _tabButton(
                      active: _selectedTab == 0,
                      icon: Icons.sensors,
                      label: 'الحساسات',
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _tabButton(
                      active: _selectedTab == 1,
                      icon: Icons.notifications_active,
                      label: 'الإشعارات',
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Expanded(
                child: _selectedTab == 0
                    ? _buildSensorsList()
                    : _buildEventsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton({
    required bool active,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: active ? AppColors.neonBlue : AppColors.charcoal,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18.sp,
                color: active ? AppColors.white : AppColors.silver),
            SizedBox(width: 8.w),
            Text(label,
                style: TextStyle(
                    color: active ? AppColors.white : AppColors.silver,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorsList() {
    if (_sensors.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors_off, color: AppColors.silver, size: 52.sp),
            SizedBox(height: 10.h),
            Text('لا توجد حساسات بعد',
                style: TextStyle(color: AppColors.silver, fontSize: 14.sp)),
            SizedBox(height: 10.h),
            ElevatedButton(
                onPressed: _showAddSensorDialog,
                child: const Text('إضافة حساس')),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _sensors.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (context, index) {
        final sensor = _sensors[index];
        final state = Map<String, dynamic>.from(
            (sensor['state'] as Map?)?.cast<String, dynamic>() ?? {});
        final online = state['online'] == true;
        final triggered = state['triggered'] == true || state['motion'] == true;
        final armed = state['armed'] != false;

        return Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.charcoal,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: triggered
                  ? AppColors.error.withValues(alpha: 0.7)
                  : (online
                      ? AppColors.darkGrey
                      : AppColors.warning.withValues(alpha: 0.7)),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    triggered ? Icons.warning_amber_rounded : Icons.sensors,
                    color: triggered ? AppColors.error : AppColors.neonBlue,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((sensor['name'] ?? '').toString(),
                            style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700)),
                        Text(
                          '${(sensor['category'] ?? 'custom').toString()} • ${(sensor['location'] ?? 'بدون موقع').toString()}',
                          style: const TextStyle(color: AppColors.silver),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _deleteSensor(sensor),
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.warning),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      online ? (triggered ? 'إنذار نشط' : 'متصل') : 'غير متصل',
                      style: TextStyle(
                        color: online
                            ? (triggered ? AppColors.error : AppColors.secure)
                            : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _toggleSensorArm(sensor),
                    child: Text(armed ? 'تعطيل' : 'تفعيل'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventsList() {
    if (_events.isEmpty) {
      return Center(
        child: Text('لا توجد أحداث حالياً',
            style: TextStyle(color: AppColors.silver, fontSize: 14.sp)),
      );
    }

    return ListView.separated(
      itemCount: _events.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (context, index) {
        final event = _events[index];
        final type = (event['type'] ?? '').toString().toLowerCase();
        final createdAt = (event['created_at'] ?? '').toString();
        final isDanger = type.contains('trigger') ||
            type.contains('alert') ||
            type.contains('seismic');

        return Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.charcoal,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
                color: isDanger
                    ? AppColors.error.withValues(alpha: 0.6)
                    : AppColors.darkGrey),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isDanger ? Icons.warning_amber_rounded : Icons.info_outline,
                    color: isDanger ? AppColors.error : AppColors.neonBlue,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _eventMessage(event),
                      style: const TextStyle(
                          color: AppColors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(createdAt, style: const TextStyle(color: AppColors.silver)),
            ],
          ),
        );
      },
    );
  }
}
