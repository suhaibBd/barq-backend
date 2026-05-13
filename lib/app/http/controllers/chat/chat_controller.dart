import 'package:vania/vania.dart';
import '../../../models/conversation.dart';
import '../../../models/message.dart';
import '../../helpers.dart';

class ChatController extends Controller {
  /// GET /api/v1/conversations
  Future<Response> conversations(Request request) async {
    final userId = Auth().id();

    final convos = await Conversation()
        .query()
        .select([
          'conversations.*',
          'u1.first_name as user_one_first_name',
          'u1.last_name as user_one_last_name',
          'u1.avatar as user_one_avatar',
          'u2.first_name as user_two_first_name',
          'u2.last_name as user_two_last_name',
          'u2.avatar as user_two_avatar',
        ])
        .join('users as u1', 'u1.id', '=', 'conversations.user_one_id')
        .join('users as u2', 'u2.id', '=', 'conversations.user_two_id')
        .where('conversations.user_one_id', '=', userId)
        .orWhere('conversations.user_two_id', '=', userId)
        .orderBy('conversations.updated_at', 'desc')
        .get();

    return Response.json({'data': sanitize(convos)});
  }

  /// POST /api/v1/conversations
  Future<Response> createConversation(Request request) async {
    final userId = Auth().id();
    final otherUserId = request.input('user_id');
    final bookingId = request.input('booking_id');

    if (otherUserId == null) {
      return Response.json({'message': 'user_id مطلوب'}, 422);
    }

    // Check if conversation already exists
    final existing = await Conversation()
        .query()
        .where('user_one_id', '=', userId)
        .where('user_two_id', '=', otherUserId)
        .first();
    if (existing != null) {
      return Response.json({'data': sanitize(existing)});
    }
    final existingReverse = await Conversation()
        .query()
        .where('user_one_id', '=', otherUserId)
        .where('user_two_id', '=', userId)
        .first();
    if (existingReverse != null) {
      return Response.json({'data': sanitize(existingReverse)});
    }

    final convoId = await Conversation().query().insertGetId({
      'user_one_id': userId,
      'user_two_id': otherUserId,
      'booking_id': bookingId,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    final convo = await Conversation().query().where('id', '=', convoId).first();
    return Response.json({'data': sanitize(convo)}, 201);
  }

  Future<bool> _isParticipant(int conversationId, dynamic userId) async {
    final convo = await Conversation()
        .query()
        .where('id', '=', conversationId)
        .first();
    if (convo == null) return false;
    return convo['user_one_id'].toString() == userId.toString() ||
        convo['user_two_id'].toString() == userId.toString();
  }

  /// GET /api/v1/conversations/{id}/messages
  Future<Response> messages(Request request, int id) async {
    final userId = Auth().id();
    if (!await _isParticipant(id, userId)) {
      return Response.json({'message': 'غير مصرح'}, 403);
    }

    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final msgs = await Message()
        .query()
        .select([
          'messages.*',
          'users.first_name',
          'users.last_name',
          'users.avatar',
        ])
        .join('users', 'users.id', '=', 'messages.sender_id')
        .where('messages.conversation_id', '=', id)
        .orderBy('messages.created_at', 'desc')
        .paginate(perPage: 50, page: page);

    return Response.json(sanitize(msgs));
  }

  /// POST /api/v1/conversations/{id}/messages
  Future<Response> sendMessage(Request request, int id) async {
    final senderId = Auth().id();
    if (!await _isParticipant(id, senderId)) {
      return Response.json({'message': 'غير مصرح'}, 403);
    }

    final body = request.input('body');

    if (body == null || body.toString().isEmpty) {
      return Response.json({'message': 'محتوى الرسالة مطلوب'}, 422);
    }

    await Message().query().insert({
      'conversation_id': id,
      'sender_id': senderId,
      'body': body,
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    await Conversation().query().where('id', '=', id).update({
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({'message': 'تم إرسال الرسالة'}, 201);
  }

  /// PATCH /api/v1/conversations/{id}/read
  Future<Response> markRead(Request request, int id) async {
    final userId = Auth().id();

    await Message()
        .query()
        .where('conversation_id', '=', id)
        .where('sender_id', '!=', userId)
        .where('is_read', '=', 0)
        .update({'is_read': 1});

    return Response.json({'message': 'تم'});
  }
}

final ChatController chatController = ChatController();
