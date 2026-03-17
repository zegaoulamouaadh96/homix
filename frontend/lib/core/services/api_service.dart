import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// خدمة API للاتصال بالسيرفر
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // غيّر هذا العنوان حسب بيئتك:
  // للمحاكي Android: 10.0.2.2
  // للجهاز الحقيقي على نفس الشبكة: IP الكمبيوتر
  // للويب: localhost
  // عند استخدام جهاز فعلي مع ADB reverse استخدم localhost (adb reverse tcp:3000 tcp:3000)
  static const String _baseUrl = 'http://localhost:3000/api';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ==================== Token Management ====================

  Future<void> _saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<void> _saveUserId(int userId) async {
    await _storage.write(key: 'user_id', value: userId.toString());
  }

  Future<int?> getUserId() async {
    final id = await _storage.read(key: 'user_id');
    return id != null ? int.tryParse(id) : null;
  }

  Future<void> _saveHomeId(int homeId) async {
    await _storage.write(key: 'home_id', value: homeId.toString());
  }

  Future<int?> getHomeId() async {
    final id = await _storage.read(key: 'home_id');
    return id != null ? int.tryParse(id) : null;
  }

  Future<void> _saveHomeCode(String code) async {
    await _storage.write(key: 'home_code', value: code);
  }

  Future<String?> getHomeCode() async {
    return await _storage.read(key: 'home_code');
  }

  Future<void> _saveRole(String role) async {
    await _storage.write(key: 'user_role', value: role);
  }

  Future<String?> getRole() async {
    return await _storage.read(key: 'user_role');
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  /// إضافة التوكن تلقائيًا لكل طلب
  Options _authHeaders(String token) {
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ==================== Auth ====================

  /// تسجيل حساب جديد
  Future<ApiResult> register({
    String? email,
    String? phone,
    required String password,
  }) async {
    try {
      final res = await _dio.post('/auth/register', data: {
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'password': password,
      });
      final data = res.data;
      if (data['ok'] == true) {
        await _saveToken(data['token']);
        await _saveUserId(data['user_id']);
        return ApiResult.success(data);
      }
      return ApiResult.error(data['error'] ?? 'unknown_error');
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// تسجيل الدخول
  Future<ApiResult> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    try {
      final res = await _dio.post('/auth/login', data: {
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'password': password,
      });
      final data = res.data;
      if (data['ok'] == true) {
        await _saveToken(data['token']);
        await _saveUserId(data['user_id']);
        return ApiResult.success(data);
      }
      return ApiResult.error(data['error'] ?? 'unknown_error');
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ==================== Home ====================

  /// ربط المستخدم بالمنزل عبر الكود
  Future<ApiResult> pairHome(String homeCode) async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final res = await _dio.post(
        '/homes/pair',
        data: {'home_code': homeCode},
        options: _authHeaders(token),
      );
      final data = res.data;
      if (data['ok'] == true) {
        await _saveHomeId(data['home_id']);
        await _saveRole(data['role']);
        await _saveHomeCode(homeCode);
        return ApiResult.success(data);
      }
      return ApiResult.error(data['error'] ?? 'unknown_error');
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// التحقق من كود المنزل قبل تسجيل الدخول
  Future<ApiResult> verifyHomeCode(String homeCode) async {
    try {
      final res = await _dio.post(
        '/public/verify-home-code',
        data: {'home_code': homeCode},
      );
      final data = res.data;
      if (data['success'] == true) {
        return ApiResult.success(data);
      }
      return ApiResult.error(data['error'] ?? 'invalid_code');
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// عدد أفراد المنزل
  Future<ApiResult> getMembersCount(int homeId) async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final res = await _dio.get(
        '/homes/$homeId/members/count',
        options: _authHeaders(token),
      );
      return ApiResult.success(res.data);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ==================== ReAuth (بعد البصمة/الوجه) ====================

  /// طلب reauth_token بعد نجاح المصادقة البيومترية المحلية
  Future<ApiResult> requestReauth() async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final res = await _dio.post(
        '/reauth',
        options: _authHeaders(token),
      );
      final data = res.data;
      if (data['ok'] == true) {
        return ApiResult.success(data);
      }
      return ApiResult.error(data['error'] ?? 'unknown_error');
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ==================== Devices ====================

  /// الحصول على حالات الأجهزة
  Future<ApiResult> getDevices(int homeId) async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final res = await _dio.get(
        '/homes/$homeId/devices/catalog',
        options: _authHeaders(token),
      );
      return ApiResult.success(res.data);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// Alias واضح للاستخدام في الشاشات الجديدة
  Future<ApiResult> getDevicesCatalog(int homeId) => getDevices(homeId);

  /// إضافة جهاز جديد (كاميرا/باب/حساس...)
  Future<ApiResult> addDevice({
    required int homeId,
    required String name,
    required String category,
    String? deviceId,
    String? location,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final res = await _dio.post(
        '/homes/$homeId/devices',
        data: {
          'name': name,
          'category': category,
          if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
          if (location != null) 'location': location,
          if (metadata != null) 'metadata': metadata,
        },
        options: _authHeaders(token),
      );
      return ApiResult.success(res.data);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// تعديل جهاز موجود
  Future<ApiResult> updateDevice({
    required int homeId,
    required String deviceId,
    String? name,
    String? category,
    String? location,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final res = await _dio.put(
        '/homes/$homeId/devices/$deviceId',
        data: {
          if (name != null) 'name': name,
          if (category != null) 'category': category,
          if (location != null) 'location': location,
          if (metadata != null) 'metadata': metadata,
        },
        options: _authHeaders(token),
      );
      return ApiResult.success(res.data);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// حذف جهاز من المنزل (تعطيل)
  Future<ApiResult> deleteDevice({
    required int homeId,
    required String deviceId,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final res = await _dio.delete(
        '/homes/$homeId/devices/$deviceId',
        options: _authHeaders(token),
      );
      return ApiResult.success(res.data);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// إرسال أمر تحكم (مع reauth_token اختياري للأوامر الخطيرة)
  Future<ApiResult> sendCommand({
    required int homeId,
    required String deviceId,
    required String cmd,
    dynamic value,
    String? reauthToken,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final res = await _dio.post(
        '/homes/$homeId/devices/$deviceId/command',
        data: {
          'cmd': cmd,
          if (value != null) 'value': value,
          if (reauthToken != null) 'reauth_token': reauthToken,
        },
        options: _authHeaders(token),
      );
      final data = res.data;
      if (data['ok'] == true) return ApiResult.success(data);
      return ApiResult.error(data['error'] ?? 'unknown_error');
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ==================== Guest Codes ====================

  /// إنشاء كود ضيف لمرة واحدة
  Future<ApiResult> createGuestCode({
    required int homeId,
    required String code,
    required int minutes,
    String? scopeDeviceId,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final res = await _dio.post(
        '/homes/$homeId/guest-codes',
        data: {
          'code': code,
          'minutes': minutes,
          if (scopeDeviceId != null) 'scope_device_id': scopeDeviceId,
        },
        options: _authHeaders(token),
      );
      final data = res.data;
      if (data['ok'] == true) return ApiResult.success(data);
      return ApiResult.error(data['error'] ?? 'unknown_error');
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ==================== Events ====================

  /// آخر 50 حدث
  Future<ApiResult> getEvents(int homeId) async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final res = await _dio.get(
        '/homes/$homeId/events',
        options: _authHeaders(token),
      );
      return ApiResult.success(res.data);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ==================== Health ====================

  Future<bool> checkHealth() async {
    try {
      final res = await Dio().get('${_baseUrl.replaceAll('/api', '')}/health');
      return res.data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  // ==================== Profile ====================

  /// الحصول على الملف الشخصي
  Future<ApiResult> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final res = await _dio.get(
        '/auth/profile',
        options: _authHeaders(token),
      );
      return ApiResult.success(res.data);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// تحديث الملف الشخصي (بيانات أساسية + صورة + دور العائلة)
  Future<ApiResult> updateProfile({
    String? email,
    String? phone,
    String? fullName,
    String? familyRole,
    String? profileImageUrl,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final res = await _dio.put(
        '/auth/profile',
        data: {
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          if (fullName != null) 'full_name': fullName,
          if (familyRole != null) 'family_role': familyRole,
          if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
        },
        options: _authHeaders(token),
      );
      return ApiResult.success(res.data);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// رفع صورة واحدة (صورة البروفايل)
  Future<ApiResult> uploadSingleImage({required String filePath}) async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final file = await MultipartFile.fromFile(filePath);
      final formData = FormData()..files.add(MapEntry('file', file));

      final res = await _dio.post(
        '/upload/image',
        data: formData,
        options: _authHeaders(token),
      );
      return ApiResult.success(res.data);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// رفع 3 صور الوجه
  Future<ApiResult> uploadFaceImages({required List<String> filePaths}) async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final formData = FormData();
      for (int i = 0; i < filePaths.length; i++) {
        final file = await MultipartFile.fromFile(filePaths[i]);
        formData.files.add(MapEntry('faces', file));
      }

      final res = await _dio.post(
        '/upload/faces',
        data: formData,
        options: _authHeaders(token),
      );
      return ApiResult.success(res.data);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// تغيير كلمة المرور
  Future<ApiResult> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final res = await _dio.post(
        '/auth/change-password',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
        options: _authHeaders(token),
      );
      final data = res.data;
      if (data['ok'] == true) return ApiResult.success(data);
      return ApiResult.error(data['error'] ?? 'unknown_error');
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// قائمة أعضاء المنزل
  Future<ApiResult> getMembers(int homeId) async {
    try {
      final token = await getToken();
      if (token == null) return ApiResult.error('not_authenticated');

      final res = await _dio.get(
        '/homes/$homeId/members',
        options: _authHeaders(token),
      );
      return ApiResult.success(res.data);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ==================== Error Handling ====================

  ApiResult _handleDioError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('error')) {
        return ApiResult.error(data['error']);
      }
      return ApiResult.error('server_error_${e.response?.statusCode}');
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ApiResult.error('timeout');
    }
    if (e.type == DioExceptionType.connectionError) {
      return ApiResult.error('connection_error');
    }
    return ApiResult.error('network_error');
  }
}

/// نتيجة عملية API
class ApiResult {
  final bool ok;
  final Map<String, dynamic>? data;
  final String? errorCode;

  ApiResult._({required this.ok, this.data, this.errorCode});

  factory ApiResult.success(Map<String, dynamic> data) {
    return ApiResult._(ok: true, data: data);
  }

  factory ApiResult.error(String code) {
    return ApiResult._(ok: false, errorCode: code);
  }

  /// ترجمة رموز الأخطاء إلى رسائل عربية
  String get errorMessage {
    switch (errorCode) {
      case 'bad_credentials':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      case 'duplicate_entry':
        return 'هذا الحساب موجود مسبقًا';
      case 'home_not_found':
        return 'كود المنزل غير صحيح';
      case 'home_not_activated':
        return 'المنزل غير مفعّل بعد من لوحة الإدارة';
      case 'not_authenticated':
        return 'يرجى تسجيل الدخول أولاً';
      case 'missing_token':
        return 'الجلسة منتهية، يرجى تسجيل الدخول';
      case 'invalid_token':
        return 'الجلسة منتهية، يرجى تسجيل الدخول مرة أخرى';
      case 'not_in_home':
        return 'أنت لست عضوًا في هذا المنزل';
      case 'no_permission':
        return 'ليس لديك صلاحية لهذا الإجراء';
      case 'reauth_required':
        return 'يجب التحقق بالبصمة أو الوجه أولاً';
      case 'reauth_invalid_or_expired':
        return 'انتهت صلاحية التحقق، أعد المحاولة';
      case 'invalid_code':
        return 'الكود غير صحيح أو منتهي الصلاحية';
      case 'already_used':
        return 'هذا الكود مستخدم بالفعل';
      case 'device_not_found':
        return 'الجهاز غير موجود في هذا المنزل';
      case 'wrong_password':
        return 'كلمة المرور الحالية غير صحيحة';
      case 'user_not_found':
        return 'المستخدم غير موجود';
      case 'connection_error':
        return 'لا يمكن الاتصال بالسيرفر';
      case 'timeout':
        return 'انتهت مهلة الاتصال';
      case 'validation_error':
        return 'البيانات المدخلة غير صحيحة';
      case 'phone_or_email_required':
        return 'يرجى إدخال البريد الإلكتروني أو رقم الهاتف';
      default:
        return 'حدث خطأ غير متوقع ($errorCode)';
    }
  }
}
