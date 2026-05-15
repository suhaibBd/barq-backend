import 'package:vania/vania.dart';
import '../../../models/user.dart';
import '../../../models/driver_document.dart';
import '../../helpers.dart';

class UserController extends Controller {
  /// GET /api/v1/profile
  Future<Response> getProfile(Request request) async {
    final userId = Auth().id();
    final user = await User().query().where('id', '=', userId).first();

    if (user == null) {
      return Response.json({'message': 'المستخدم غير موجود'}, 404);
    }

    final result = _formatUser(user);
    final doc = await DriverDocument().query().where('user_id', '=', userId).first();
    result['document_status'] = doc?['status'];

    return Response.json(result);
  }

  /// PATCH /api/v1/profile
  Future<Response> updateProfile(Request request) async {
    final body = request.body;

    final firstName = body['first_name']?.toString();
    final lastName = body['last_name']?.toString();

    if (firstName == null || firstName.isEmpty) {
      return Response.json({'message': 'الاسم الأول مطلوب'}, 422);
    }
    if (lastName == null || lastName.isEmpty) {
      return Response.json({'message': 'اسم العائلة مطلوب'}, 422);
    }

    final userId = Auth().id();
    final data = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (body['email'] != null) {
      data['email'] = body['email'];
    }
    if (body['car_number'] != null) {
      data['car_number'] = body['car_number'];
    }

    await User().query().where('id', '=', userId).update(data);

    final user = await User().query().where('id', '=', userId).first();
    final result = _formatUser(user!);
    final doc = await DriverDocument().query().where('user_id', '=', userId).first();
    result['document_status'] = doc?['status'];
    return Response.json(result);
  }

  /// POST /api/v1/profile/avatar
  Future<Response> uploadAvatar(Request request) async {
    request.validate({
      'avatar': 'file:jpg,jpeg,png',
    });

    final userId = Auth().id();
    final RequestFile? avatar = request.file('avatar');

    if (avatar == null) {
      return Response.json({'message': 'الصورة مطلوبة'}, 422);
    }

    final path = await avatar.store(
      path: 'users/$userId',
      filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.${avatar.filename.split('.').last}',
    );

    await User().query().where('id', '=', userId).update({
      'avatar': path,
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({'avatar_url': path});
  }

  /// GET /api/v1/users (admin)
  Future<Response> listUsers(Request request) async {
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;
    final users = await User().query().orderBy('created_at', 'desc').paginate(perPage: 20, page: page);
    return Response.json(sanitize(users));
  }

  /// GET /api/v1/users/{id}
  Future<Response> getUser(int id) async {
    final user = await User().query().where('id', '=', id).first();
    if (user == null) {
      return Response.json({'message': 'المستخدم غير موجود'}, 404);
    }
    return Response.json(_formatUser(user));
  }

  /// PATCH /api/v1/users/{id}/toggle-active
  Future<Response> toggleActive(int id) async {
    final user = await User().query().where('id', '=', id).first();
    if (user == null) {
      return Response.json({'message': 'المستخدم غير موجود'}, 404);
    }

    final newStatus = (user['is_active'] ?? 0) == 1 ? 0 : 1;
    await User().query().where('id', '=', id).update({
      'is_active': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({'message': 'تم تحديث حالة المستخدم', 'is_active': newStatus == 1});
  }

  /// PATCH /api/v1/profile/toggle-online
  Future<Response> toggleOnline(Request request) async {
    final userId = Auth().id();
    final user = await User().query().where('id', '=', userId).first();

    if (user == null) {
      return Response.json({'message': 'المستخدم غير موجود'}, 404);
    }

    final newStatus = (user['is_online'] ?? 0) == 1 ? 0 : 1;
    await User().query().where('id', '=', userId).update({
      'is_online': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({
      'is_online': newStatus == 1,
      'message': newStatus == 1 ? 'أنت متصل الآن' : 'أنت غير متصل',
    });
  }

  Map<String, dynamic> _formatUser(Map<String, dynamic> user) {
    return {
      'id': user['id'].toString(),
      'phone': user['phone'],
      'email': user['email'],
      'first_name': user['first_name'] ?? '',
      'last_name': user['last_name'] ?? '',
      'avatar_url': user['avatar'],
      'role': user['role'] ?? 'store',
      'is_driver_verified': (user['is_driver_verified'] ?? 0) == 1,
      'rating': double.tryParse(user['rating']?.toString() ?? '5.0') ?? 5.0,
      'total_trips': user['total_trips'] ?? 0,
      'is_active': (user['is_active'] ?? 1) == 1,
      'is_online': (user['is_online'] ?? 0) == 1,
      'created_at': user['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    };
  }
}

final UserController userController = UserController();
