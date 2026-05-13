import 'dart:convert';
import 'dart:math';
import 'package:vania/vania.dart';
import '../../../models/user.dart';
import '../../../models/otp_verification.dart';
import '../../../models/wallet.dart';
import '../../helpers.dart';

class AuthController extends Controller {
  /// POST /api/v1/auth/send-otp
  Future<Response> sendOtp(Request request) async {
    request.validate({
      'phone': 'required|string',
    }, {
      'phone.required': 'رقم الموبايل مطلوب',
    });

    final phone = request.input('phone');
    final code = _generateOtp();
    final verificationId = _generateVerificationId();

    await OtpVerification().query().insert({
      'phone': phone,
      'code': code,
      'verification_id': verificationId,
      'is_used': 0,
      'expires_at': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });

    // TODO: integrate SMS provider (Twilio, etc.)
    // For dev: code is returned in response
    final response = <String, dynamic>{
      'verification_id': verificationId,
      'message': 'تم إرسال رمز التحقق',
    };
    if (Env.get('APP_DEBUG') == 'true') {
      response['dev_code'] = code;
    }
    return Response.json(response);
  }

  /// POST /api/v1/auth/verify-otp
  Future<Response> verifyOtp(Request request) async {
    request.validate({
      'verification_id': 'required|string',
      'code': 'required|string',
    }, {
      'verification_id.required': 'معرّف التحقق مطلوب',
      'code.required': 'رمز التحقق مطلوب',
    });

    final verificationId = request.input('verification_id');
    final code = request.input('code');

    final otp = await OtpVerification()
        .query()
        .where('verification_id', '=', verificationId)
        .where('code', '=', code)
        .where('is_used', '=', 0)
        .first();

    if (otp == null) {
      return Response.json({'message': 'رمز التحقق غير صحيح أو منتهي الصلاحية'}, 401);
    }

    final expiresAt = DateTime.parse(otp['expires_at'].toString());
    if (DateTime.now().isAfter(expiresAt)) {
      return Response.json({'message': 'رمز التحقق منتهي الصلاحية'}, 401);
    }

    await OtpVerification()
        .query()
        .where('id', '=', otp['id'])
        .update({'is_used': 1});

    final phone = otp['phone'];
    var user = await User().query().where('phone', '=', phone).first();
    bool isNewUser = false;

    if (user == null) {
      isNewUser = true;
      final userId = await User().query().insertGetId({
        'phone': phone,
        'first_name': '',
        'last_name': '',
        'role': 'passenger',
        'is_driver_verified': 0,
        'rating': 5.0,
        'total_trips': 0,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await Wallet().query().insert({
        'user_id': userId,
        'balance': 0.00,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      user = await User().query().where('id', '=', userId).first();
    }

    final token = await Auth()
        .login(sanitizeRow(user!))
        .createToken(expiresIn: const Duration(days: 30), withRefreshToken: true);

    return Response.json({
      'access_token': token['access_token'],
      'refresh_token': token['refresh_token'],
      'is_new_user': isNewUser,
      'user': _formatUser(user),
    });
  }

  /// POST /api/v1/auth/refresh
  Future<Response> refreshToken(Request request) async {
    final newToken = Auth().createTokenByRefreshToken(
      request.header('Authorization')!,
      expiresIn: const Duration(days: 30),
    );
    return Response.json(newToken);
  }

  /// POST /api/v1/auth/logout
  Future<Response> logout(Request request) async {
    await Auth().deleteCurrentToken();
    return Response.json({'message': 'تم تسجيل الخروج بنجاح'});
  }

  /// POST /api/v1/auth/firebase-verify
  Future<Response> firebaseVerify(Request request) async {
    final firebaseToken = request.input('firebase_token');
    if (firebaseToken == null || firebaseToken.toString().isEmpty) {
      return Response.json({'message': 'Firebase token مطلوب'}, 422);
    }

    // Decode Firebase ID token (JWT) to extract phone and uid
    // In production, verify the token signature with Firebase Admin SDK
    final parts = firebaseToken.toString().split('.');
    if (parts.length != 3) {
      return Response.json({'message': 'Token غير صالح'}, 401);
    }

    Map<String, dynamic> payload;
    try {
      final normalized = base64Url.normalize(parts[1]);
      payload = json.decode(utf8.decode(base64Url.decode(normalized)));
    } catch (_) {
      return Response.json({'message': 'Token غير صالح'}, 401);
    }

    final phone = payload['phone_number'];
    final firebaseUid = payload['user_id'] ?? payload['sub'];

    if (phone == null) {
      return Response.json({'message': 'رقم الهاتف غير موجود في Token'}, 401);
    }

    var user = await User().query().where('phone', '=', phone).first();
    bool isNewUser = false;

    if (user == null) {
      isNewUser = true;
      final userId = await User().query().insertGetId({
        'phone': phone,
        'first_name': '',
        'last_name': '',
        'role': 'passenger',
        'is_driver_verified': 0,
        'rating': 5.0,
        'total_trips': 0,
        'is_active': 1,
        'firebase_uid': firebaseUid,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await Wallet().query().insert({
        'user_id': userId,
        'balance': 0.00,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      user = await User().query().where('id', '=', userId).first();
    } else if (user['firebase_uid'] == null) {
      await User().query().where('id', '=', user['id']).update({
        'firebase_uid': firebaseUid,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    final token = await Auth()
        .login(sanitizeRow(user!))
        .createToken(expiresIn: const Duration(days: 30), withRefreshToken: true);

    return Response.json({
      'access_token': token['access_token'],
      'refresh_token': token['refresh_token'],
      'is_new_user': isNewUser,
      'user': _formatUser(user),
    });
  }

  /// POST /api/v1/auth/fcm-token
  Future<Response> registerFcmToken(Request request) async {
    final userId = Auth().id();
    final fcmToken = request.input('fcm_token');

    if (fcmToken == null || fcmToken.toString().isEmpty) {
      return Response.json({'message': 'FCM token مطلوب'}, 422);
    }

    await User().query().where('id', '=', userId).update({
      'fcm_token': fcmToken,
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({'message': 'تم تسجيل FCM token'});
  }

  /// POST /api/v1/auth/admin-login (dev only)
  Future<Response> adminDevLogin(Request request) async {
    if (Env.get('APP_DEBUG') != 'true') {
      return Response.json({'message': 'Not found'}, 404);
    }

    final user = await User().query().where('role', '=', 'admin').first();
    if (user == null) {
      return Response.json({'message': 'لا يوجد حساب مشرف'}, 404);
    }

    final token = await Auth()
        .login(sanitizeRow(user))
        .createToken(expiresIn: const Duration(days: 30), withRefreshToken: true);

    return Response.json({
      'access_token': token['access_token'],
      'refresh_token': token['refresh_token'],
      'user': _formatUser(user),
    });
  }

  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  String _generateVerificationId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Map<String, dynamic> _formatUser(Map<String, dynamic> user) {
    return {
      'id': user['id'].toString(),
      'phone': user['phone'],
      'email': user['email'],
      'first_name': user['first_name'] ?? '',
      'last_name': user['last_name'] ?? '',
      'avatar_url': user['avatar'],
      'role': user['role'] ?? 'passenger',
      'is_driver_verified': (user['is_driver_verified'] ?? 0) == 1,
      'rating': double.tryParse(user['rating']?.toString() ?? '5.0') ?? 5.0,
      'total_trips': user['total_trips'] ?? 0,
      'created_at': user['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    };
  }
}

final AuthController authController = AuthController();
