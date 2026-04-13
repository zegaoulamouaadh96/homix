import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// خدمة الإشعارات المحلية
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// تهيئة خدمة الإشعارات
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // التعامل مع النقر على الإشعار
        print('Notification tapped: ${response.payload}');
      },
    );

    _isInitialized = true;
  }

  /// طلب إذن الإشعارات (iOS)
  Future<bool> requestPermissions() async {
    if (!Platform.isIOS) return true;

    final bool? result = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    return result ?? false;
  }

  /// إرسال إشعار اكتشاف شخص غريب
  Future<void> showStrangerAlert({
    required String cameraName,
    required String location,
    required int count,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'stranger_alerts',
      'تنبيهات الأشخاص الغرباء',
      channelDescription: 'إشعارات عند اكتشاف أشخاص غير معروفين',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = count > 1 ? 'تم اكتشاف $count أشخاص غرباء' : 'تم اكتشاف شخص غريب';
    final body = 'الكاميرا: $cameraName\nالموقع: $location';

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: 'stranger_detected',
    );
  }

  /// إرسال إشعار حساس
  Future<void> showSensorAlert({
    required String sensorName,
    required String sensorType,
    required String location,
    required String alertType,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'sensor_alerts',
      'تنبيهات الحساسات',
      channelDescription: 'إشعارات تنبيه الحساسات',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = _getSensorTitle(sensorType, alertType);
    final body = 'الحساس: $sensorName\nالموقع: $location\nالنوع: ${_getSensorName(sensorType)}';

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: 'sensor_alert:$sensorType',
    );
  }

  /// إرسال إشعار عام
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'general_notifications',
      'إشعارات عامة',
      channelDescription: 'إشعارات النظام العامة',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// مسح جميع الإشعارات
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// الحصول على عنوان الإشعار حسب نوع الحساس
  String _getSensorTitle(String sensorType, String alertType) {
    switch (sensorType.toLowerCase()) {
      case 'motion':
        return '⚠️ تم اكتشاف حركة';
      case 'smoke':
        return '🔥 تنبيه دخان';
      case 'flood':
        return '💧 تنبيه فيضان';
      case 'glass':
        return '🔨 تنبيه كسر زجاج';
      case 'seismic':
        return '🌍 تنبيه زلزال';
      default:
        return '⚠️ تنبيه حساس';
    }
  }

  /// الحصول على اسم الحساس بالعربية
  String _getSensorName(String sensorType) {
    switch (sensorType.toLowerCase()) {
      case 'motion':
        return 'حساس حركة';
      case 'smoke':
        return 'حساس دخان';
      case 'flood':
        return 'حساس فيضان';
      case 'glass':
        return 'حساس كسر زجاج';
      case 'seismic':
        return 'حساس زلازل';
      default:
        return 'حساس';
    }
  }
}
