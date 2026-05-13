import 'package:vania/vania.dart';
import '../../../models/recurring_trip.dart';
import '../../../models/subscription.dart';
import '../../helpers.dart';

class RecurringTripController extends Controller {
  /// POST /api/v1/recurring-trips
  Future<Response> create(Request request) async {
    request.validate({
      'from_city': 'required|string',
      'to_city': 'required|string',
      'from_lat': 'required|numeric',
      'from_lng': 'required|numeric',
      'to_lat': 'required|numeric',
      'to_lng': 'required|numeric',
      'departure_time': 'required|string',
      'days_of_week': 'required|string',
      'monthly_price': 'required|numeric',
      'total_seats': 'required|integer',
    });

    final driverId = Auth().id();
    final totalSeats = request.input('total_seats');
    final monthlyPrice = (request.input('monthly_price') as num).toDouble();

    // Auto-calculate weekly and daily prices if not provided
    final weeklyPrice = request.input('weekly_price') != null
        ? (request.input('weekly_price') as num).toDouble()
        : double.parse((monthlyPrice / 3.5).toStringAsFixed(2));
    final dailyPrice = request.input('daily_price') != null
        ? (request.input('daily_price') as num).toDouble()
        : double.parse((monthlyPrice / 16).toStringAsFixed(2));

    final serviceFeePercent = request.input('service_fee_percent') != null
        ? (request.input('service_fee_percent') as num).toDouble()
        : 10.00;
    final feeModel = request.input('fee_model') ?? 'service_fee';

    final tripId = await RecurringTrip().query().insertGetId({
      'driver_id': driverId,
      'from_city': request.input('from_city'),
      'to_city': request.input('to_city'),
      'from_lat': request.input('from_lat'),
      'from_lng': request.input('from_lng'),
      'to_lat': request.input('to_lat'),
      'to_lng': request.input('to_lng'),
      'departure_time': request.input('departure_time'),
      'return_time': request.input('return_time'),
      'days_of_week': request.input('days_of_week'),
      'monthly_price': monthlyPrice,
      'weekly_price': weeklyPrice,
      'daily_price': dailyPrice,
      'service_fee_percent': serviceFeePercent,
      'fee_model': feeModel,
      'total_seats': totalSeats,
      'available_seats': totalSeats,
      'pooling_point_lat': request.input('pooling_point_lat'),
      'pooling_point_lng': request.input('pooling_point_lng'),
      'pooling_point_name': request.input('pooling_point_name'),
      'pickup_from_home':
          request.input('pickup_from_home') == true ? true : false,
      'female_only': request.input('female_only') == true ? true : false,
      'notes': request.input('notes'),
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    final trip =
        await RecurringTrip().query().where('id', '=', tripId).first();
    return Response.json(
        {'message': 'تم إنشاء الخط', 'data': sanitize(trip)}, 201);
  }

  /// GET /api/v1/recurring-trips/search?from=&to=
  Future<Response> search(Request request) async {
    final from = request.query('from');
    final to = request.query('to');
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    var query = RecurringTrip()
        .query()
        .select([
          'recurring_trips.*',
          'users.first_name',
          'users.last_name',
          'users.rating',
          'users.avatar',
          'users.reliability_score',
        ])
        .join('users', 'users.id', '=', 'recurring_trips.driver_id')
        .where('recurring_trips.status', '=', 'active')
        .where('recurring_trips.available_seats', '>', 0);

    if (from != null && from.isNotEmpty) {
      query = query.where('recurring_trips.from_city', 'like', '%$from%');
    }
    if (to != null && to.isNotEmpty) {
      query = query.where('recurring_trips.to_city', 'like', '%$to%');
    }

    final trips = await query
        .orderBy('recurring_trips.created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(trips));
  }

  /// GET /api/v1/recurring-trips/my
  Future<Response> myLines(Request request) async {
    final driverId = Auth().id();
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final trips = await RecurringTrip()
        .query()
        .where('driver_id', '=', driverId)
        .orderBy('created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(trips));
  }

  /// GET /api/v1/recurring-trips/{id}
  Future<Response> show(int id) async {
    final trip = await RecurringTrip()
        .query()
        .select([
          'recurring_trips.*',
          'users.first_name',
          'users.last_name',
          'users.avatar',
          'users.rating',
          'users.reliability_score',
        ])
        .join('users', 'users.id', '=', 'recurring_trips.driver_id')
        .where('recurring_trips.id', '=', id)
        .first();

    if (trip == null) {
      return Response.json({'message': 'الخط غير موجود'}, 404);
    }

    return Response.json({'data': sanitize(trip)});
  }

  /// PATCH /api/v1/recurring-trips/{id}
  Future<Response> update(int id, Request request) async {
    final driverId = Auth().id();

    final trip = await RecurringTrip()
        .query()
        .where('id', '=', id)
        .where('driver_id', '=', driverId)
        .first();

    if (trip == null) {
      return Response.json({'message': 'الخط غير موجود'}, 404);
    }

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    final allowedFields = [
      'monthly_price',
      'weekly_price',
      'daily_price',
      'service_fee_percent',
      'fee_model',
      'total_seats',
      'available_seats',
      'departure_time',
      'return_time',
      'notes',
      'pickup_from_home',
      'female_only',
      'status',
    ];

    for (final field in allowedFields) {
      final input = request.input(field);
      if (input != null) {
        updates[field] = input;
      }
    }

    await RecurringTrip().query().where('id', '=', id).update(updates);

    final updated =
        await RecurringTrip().query().where('id', '=', id).first();
    return Response.json(
        {'message': 'تم تحديث الخط', 'data': sanitize(updated)});
  }

  /// PATCH /api/v1/recurring-trips/{id}/pause
  Future<Response> pause(int id) async {
    final driverId = Auth().id();

    final trip = await RecurringTrip()
        .query()
        .where('id', '=', id)
        .where('driver_id', '=', driverId)
        .first();

    if (trip == null) {
      return Response.json({'message': 'الخط غير موجود'}, 404);
    }

    await RecurringTrip().query().where('id', '=', id).update({
      'status': 'paused',
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({'message': 'تم إيقاف الخط مؤقتاً'});
  }

  /// PATCH /api/v1/recurring-trips/{id}/resume
  Future<Response> resume(int id) async {
    final driverId = Auth().id();

    final trip = await RecurringTrip()
        .query()
        .where('id', '=', id)
        .where('driver_id', '=', driverId)
        .first();

    if (trip == null) {
      return Response.json({'message': 'الخط غير موجود'}, 404);
    }

    await RecurringTrip().query().where('id', '=', id).update({
      'status': 'active',
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({'message': 'تم تفعيل الخط'});
  }

  /// DELETE /api/v1/recurring-trips/{id}
  Future<Response> close(int id) async {
    final driverId = Auth().id();

    final trip = await RecurringTrip()
        .query()
        .where('id', '=', id)
        .where('driver_id', '=', driverId)
        .first();

    if (trip == null) {
      return Response.json({'message': 'الخط غير موجود'}, 404);
    }

    await RecurringTrip().query().where('id', '=', id).update({
      'status': 'closed',
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Cancel all active subscriptions for this trip
    await Subscription()
        .query()
        .where('recurring_trip_id', '=', id)
        .where('status', '=', 'active')
        .update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({'message': 'تم إغلاق الخط'});
  }
}

final RecurringTripController recurringTripController =
    RecurringTripController();
