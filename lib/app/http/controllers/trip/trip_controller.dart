import 'package:vania/vania.dart';
import '../../../models/trip.dart';
import '../../helpers.dart';

class TripController extends Controller {
  /// POST /api/v1/trips
  Future<Response> create(Request request) async {
    request.validate({
      'from_city': 'required|string',
      'to_city': 'required|string',
      'from_lat': 'required|numeric',
      'from_lng': 'required|numeric',
      'to_lat': 'required|numeric',
      'to_lng': 'required|numeric',
      'departure_time': 'required',
      'price': 'required|numeric',
      'total_seats': 'required|integer',
    });

    final driverId = Auth().id();
    final totalSeats = request.input('total_seats');

    final tripId = await Trip().query().insertGetId({
      'driver_id': driverId,
      'from_city': request.input('from_city'),
      'to_city': request.input('to_city'),
      'from_lat': request.input('from_lat'),
      'from_lng': request.input('from_lng'),
      'to_lat': request.input('to_lat'),
      'to_lng': request.input('to_lng'),
      'departure_time': request.input('departure_time'),
      'price': request.input('price'),
      'available_seats': totalSeats,
      'total_seats': totalSeats,
      'notes': request.input('notes'),
      'pooling_point_lat': request.input('pooling_point_lat'),
      'pooling_point_lng': request.input('pooling_point_lng'),
      'pooling_point_name': request.input('pooling_point_name'),
      'pickup_from_home': request.input('pickup_from_home') == true ? true : false,
      'smoking_allowed': request.input('smoking_allowed') == true ? true : false,
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    final trip = await Trip().query().where('id', '=', tripId).first();
    return Response.json({'message': 'تم إنشاء الرحلة', 'data': sanitize(trip)}, 201);
  }

  /// GET /api/v1/trips/search?from=&to=&date=
  Future<Response> search(Request request) async {
    final from = request.query('from');
    final to = request.query('to');
    final date = request.query('date');
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;
    final userId = Auth().id();

    var query = Trip()
        .query()
        .select([
          'trips.*',
          'users.first_name',
          'users.last_name',
          'users.avatar',
          'users.rating',
        ])
        .join('users', 'users.id', '=', 'trips.driver_id')
        .where('trips.status', '=', 'active')
        .where('trips.driver_id', '!=', userId);

    if (from != null && from.isNotEmpty) {
      query = query.where('trips.from_city', 'like', '%$from%');
    }
    if (to != null && to.isNotEmpty) {
      query = query.where('trips.to_city', 'like', '%$to%');
    }
    if (date != null && date.isNotEmpty) {
      query = query.whereDate('trips.departure_time', '=', date);
    }

    final trips = await query
        .orderBy('trips.departure_time', 'asc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(trips));
  }

  /// GET /api/v1/trips/{id}
  Future<Response> show(int id) async {
    final trip = await Trip()
        .query()
        .select([
          'trips.*',
          'users.first_name',
          'users.last_name',
          'users.phone',
          'users.avatar',
          'users.rating',
        ])
        .join('users', 'users.id', '=', 'trips.driver_id')
        .where('trips.id', '=', id)
        .first();

    if (trip == null) {
      return Response.json({'message': 'الرحلة غير موجودة'}, 404);
    }

    return Response.json({'data': sanitize(trip)});
  }

  /// GET /api/v1/trips/my
  Future<Response> myTrips(Request request) async {
    final userId = Auth().id();
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final trips = await Trip()
        .query()
        .where('driver_id', '=', userId)
        .orderBy('departure_time', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(trips));
  }

  /// PATCH /api/v1/trips/{id}/cancel
  Future<Response> cancel(int id) async {
    final userId = Auth().id();
    final trip = await Trip().query().where('id', '=', id).where('driver_id', '=', userId).first();

    if (trip == null) {
      return Response.json({'message': 'الرحلة غير موجودة'}, 404);
    }

    await Trip().query().where('id', '=', id).update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({'message': 'تم إلغاء الرحلة'});
  }

  /// GET /api/v1/trips/all (admin)
  Future<Response> listAll(Request request) async {
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;
    final status = request.query('status');

    var query = Trip()
        .query()
        .select([
          'trips.*',
          'users.first_name',
          'users.last_name',
          'users.phone',
        ])
        .join('users', 'users.id', '=', 'trips.driver_id');

    if (status != null && status.isNotEmpty) {
      query = query.where('trips.status', '=', status);
    }

    final trips = await query.orderBy('trips.created_at', 'desc').paginate(perPage: 20, page: page);
    return Response.json(sanitize(trips));
  }
}

final TripController tripController = TripController();
