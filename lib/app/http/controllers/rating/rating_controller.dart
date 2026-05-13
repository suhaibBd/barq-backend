import 'package:vania/vania.dart';
import '../../../models/rating.dart';
import '../../../models/user.dart';
import '../../../models/booking.dart';
import '../../helpers.dart';

class RatingController extends Controller {
  /// POST /api/v1/ratings
  Future<Response> create(Request request) async {
    request.validate({
      'booking_id': 'required|integer',
      'rated_user_id': 'required|integer',
      'rating': 'required|integer|min:1|max:5',
    });

    final raterId = Auth().id();
    final bookingId = request.input('booking_id');
    final ratedUserId = request.input('rated_user_id');
    final rating = request.input('rating');
    final comment = request.input('comment');

    final booking = await Booking().query().where('id', '=', bookingId).first();
    if (booking == null) {
      return Response.json({'message': 'الحجز غير موجود'}, 404);
    }

    final existing = await Rating()
        .query()
        .where('booking_id', '=', bookingId)
        .where('rater_id', '=', raterId)
        .first();
    if (existing != null) {
      return Response.json({'message': 'تم التقييم مسبقاً'}, 422);
    }

    await Rating().query().insert({
      'booking_id': bookingId,
      'rater_id': raterId,
      'rated_user_id': ratedUserId,
      'rating': rating,
      'comment': comment,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Update user average rating
    final ratings = await Rating()
        .query()
        .where('rated_user_id', '=', ratedUserId)
        .get();
    if (ratings.isNotEmpty) {
      double sum = 0;
      for (final r in ratings) {
        sum += (r['rating'] as num).toDouble();
      }
      final avg = sum / ratings.length;
      await User().query().where('id', '=', ratedUserId).update({
        'rating': avg.toStringAsFixed(1),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    return Response.json({'message': 'تم إرسال التقييم'});
  }

  /// GET /api/v1/ratings/my
  Future<Response> myRatings(Request request) async {
    final userId = Auth().id();
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final ratings = await Rating()
        .query()
        .select([
          'ratings.*',
          'users.first_name',
          'users.last_name',
          'users.avatar',
        ])
        .join('users', 'users.id', '=', 'ratings.rater_id')
        .where('ratings.rated_user_id', '=', userId)
        .orderBy('ratings.created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(ratings));
  }

  /// GET /api/v1/ratings/user/{id}
  Future<Response> userRatings(Request request, int id) async {
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final ratings = await Rating()
        .query()
        .select([
          'ratings.*',
          'users.first_name',
          'users.last_name',
          'users.avatar',
        ])
        .join('users', 'users.id', '=', 'ratings.rater_id')
        .where('ratings.rated_user_id', '=', id)
        .orderBy('ratings.created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(ratings));
  }

  /// GET /api/v1/admin/ratings (admin)
  Future<Response> listAll(Request request) async {
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final ratings = await Rating()
        .query()
        .select([
          'ratings.*',
          'u1.first_name as rater_first_name',
          'u1.last_name as rater_last_name',
          'u2.first_name as rated_first_name',
          'u2.last_name as rated_last_name',
        ])
        .join('users as u1', 'u1.id', '=', 'ratings.rater_id')
        .join('users as u2', 'u2.id', '=', 'ratings.rated_user_id')
        .orderBy('ratings.created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(ratings));
  }
}

final RatingController ratingController = RatingController();
