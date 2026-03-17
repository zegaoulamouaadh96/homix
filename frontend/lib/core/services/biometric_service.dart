import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// خدمة المصادقة البيومترية (بصمة الإصبع / التعرف على الوجه)
/// لا يتم إرسال أي بيانات بيومترية للسيرفر
/// تُستخدم فقط كتأكيد محلي قبل إرسال أوامر خطيرة
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// هل الجهاز يدعم المصادقة البيومترية؟
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// هل تم تسجيل بصمات/وجوه على الجهاز؟
  Future<bool> hasBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// الحصول على الأنواع المتاحة (بصمة، وجه، إلخ)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// هل بصمة الإصبع متاحة؟
  Future<bool> isFingerprintAvailable() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.fingerprint);
  }

  /// هل التعرف على الوجه متاح؟
  Future<bool> isFaceIdAvailable() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  /// طلب مصادقة بيومترية من المستخدم
  /// [reason] سبب الطلب يظهر للمستخدم
  /// يرجع true إذا نجحت المصادقة
  Future<bool> authenticate({
    String reason = 'يرجى التحقق من هويتك للمتابعة',
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) return false;

      final hasBio = await hasBiometrics();
      if (!hasBio) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // يسمح أيضًا بـ PIN/Pattern كبديل
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      // ignore auth errors gracefully
      return false;
    }
  }

  /// مصادقة بيومترية فقط (بدون PIN)
  Future<bool> authenticateBiometricOnly({
    String reason = 'استخدم البصمة أو التعرف على الوجه',
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) return false;

      final hasBio = await hasBiometrics();
      if (!hasBio) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  /// الحصول على وصف نصي للأنواع المتاحة
  Future<String> getBiometricLabel() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.contains(BiometricType.face)) {
      return 'التعرف على الوجه';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'بصمة الإصبع';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'مسح القزحية';
    }
    return 'المصادقة البيومترية';
  }
}
