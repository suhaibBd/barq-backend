import 'package:vania/vania.dart';
import '../../../models/notification.dart';
import '../../helpers.dart';

class NotificationController extends Controller {
  /// GET /api/v1/notifications
  Future<Response> index(Request request) async {
    final userId = Auth().id();
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final notifications = await AppNotification()
        .query()
        .where('user_id', '=', userId)
        .orderBy('created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(notifications));
  }

  /// GET /api/v1/notifications/unread-count
  Future<Response> unreadCount(Request request) async {
    final userId = Auth().id();

    final result = await AppNotification()
        .query()
        .where('user_id', '=', userId)
        .where('is_read', '=', 0)
        .get();

    return Response.json({'count': result.length});
  }

  /// PATCH /api/v1/notifications/{id}/read
  Future<Response> markRead(int id) async {
    final userId = Auth().id();

    await AppNotification()
        .query()
        .where('id', '=', id)
        .where('user_id', '=', userId)
        .update({'is_read': 1});

    return Response.json({'message': 'تم'});
  }

  /// PATCH /api/v1/notifications/read-all
  Future<Response> markAllRead(Request request) async {
    final userId = Auth().id();

    await AppNotification()
        .query()
        .where('user_id', '=', userId)
        .where('is_read', '=', 0)
        .update({'is_read': 1});

    return Response.json({'message': 'تم قراءة جميع الإشعارات'});
  }

  /// Helper: Create a notification for a user
  static Future<void> notify({
    required int userId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await AppNotification().query().insert({
      'user_id': userId,
      'type': type,
      'title': title,
      'body': body,
      'is_read': 0,
      'data': data?.toString(),
      'created_at': DateTime.now().toIso8601String(),
    });
    // TODO: Send FCM push notification using user's fcm_token
  }
  /// GET /admin/notifications
  Future<Response> listAll(Request request) async {
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final notifications = await AppNotification()
        .query()
        .select([
          'notifications.*',
          'users.first_name',
          'users.last_name',
        ])
        .join('users', 'users.id', '=', 'notifications.user_id')
        .orderBy('notifications.created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(notifications));
  }
}

final NotificationController notificationController = NotificationController();
