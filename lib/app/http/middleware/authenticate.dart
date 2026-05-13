import 'package:vania/vania.dart';
import '../../models/user.dart';

class AuthenticateMiddleware extends Authenticate {}

class AdminMiddleware extends Middleware {
  @override
  Future<Response?> handle(Request request) async {
    final userId = Auth().id();
    if (userId == null) {
      return Response.json({'message': 'Unauthorized'}, 401);
    }

    final user = await User().query().where('id', '=', userId).first();
    if (user == null || user['role'] != 'admin') {
      return Response.json({'message': 'Unauthorized'}, 403);
    }

    return null;
  }
}
