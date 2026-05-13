import 'dart:convert';
import 'package:vania/vania.dart';
import '../../../models/trip_request.dart';
import '../../../models/trip.dart';
import '../../../models/booking.dart';
import '../notification/notification_controller.dart';
import '../../helpers.dart';

class TripRequestController extends Controller {
  /// POST /api/v1/trip-requests
  Future<Response> create(Request request) async {
    request.validate({
      'from_city': 'required|string',
      'to_city': 'required|string',
      'from_lat': 'required|numeric',
      'from_lng': 'required|numeric',
      'to_lat': 'required|numeric',
      'to_lng': 'required|numeric',
      'requested_time': 'required',
      'seats_needed': 'required|integer|min:1',
    });

    final passengerId = Auth().id();
    final recurringDays = request.input('recurring_days');

    final id = await TripRequest().query().insertGetId({
      'passenger_id': passengerId,
      'from_city': request.input('from_city'),
      'to_city': request.input('to_city'),
      'from_lat': request.input('from_lat'),
      'from_lng': request.input('from_lng'),
      'to_lat': request.input('to_lat'),
      'to_lng': request.input('to_lng'),
      'requested_time': request.input('requested_time'),
      'seats_needed': request.input('seats_needed'),
      'is_recurring': request.input('is_recurring') == true ? 1 : 0,
      'recurring_days':
          recurringDays != null ? jsonEncode(recurringDays) : null,
      'notes': request.input('notes'),
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    final tripRequest = await TripRequest().query().where('id', '=', id).first();
    return Response.json(
        {'message': 'تم إرسال طلبك', 'data': sanitize(tripRequest)}, 201);
  }

  /// GET /api/v1/trip-requests/my
  Future<Response> myRequests(Request request) async {
    final userId = Auth().id();
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final requests = await TripRequest()
        .query()
        .where('passenger_id', '=', userId)
        .orderBy('created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(requests));
  }

  /// GET /api/v1/trip-requests/nearby
  Future<Response> nearbyDemand(Request request) async {
    final requests = await TripRequest()
        .query()
        .select([
          'trip_requests.*',
          'users.first_name',
          'users.last_name',
          'users.phone',
          'users.rating',
          'users.avatar',
        ])
        .join('users', 'users.id', '=', 'trip_requests.passenger_id')
        .where('trip_requests.status', '=', 'pending')
        .where('trip_requests.requested_time', '>=',
            DateTime.now().toIso8601String())
        .orderBy('trip_requests.requested_time', 'asc')
        .get();

    // Group by route + approximate time (same day)
    final clusters = <String, Map<String, dynamic>>{};
    for (final req in requests) {
      final time = DateTime.parse(req['requested_time'].toString());
      final key =
          '${req['from_city']}_${req['to_city']}_${time.year}-${time.month}-${time.day}';

      if (!clusters.containsKey(key)) {
        clusters[key] = {
          'from_city': req['from_city'],
          'to_city': req['to_city'],
          'requested_time': req['requested_time'],
          'total_passengers': 0,
          'total_seats': 0,
          'requests': [],
        };
      }

      clusters[key]!['total_passengers'] =
          (clusters[key]!['total_passengers'] as int) + 1;
      clusters[key]!['total_seats'] =
          (clusters[key]!['total_seats'] as int) +
              (req['seats_needed'] as int? ?? 1);
      (clusters[key]!['requests'] as List).add(sanitize(req));
    }

    final result = clusters.values.toList();
    return Response.json({'data': result});
  }

  /// POST /api/v1/trip-requests/accept
  Future<Response> acceptDemand(Request request) async {
    request.validate({
      'request_ids': 'required',
      'price_per_seat': 'required|numeric',
      'total_seats': 'required|integer|min:1',
    });

    final driverId = Auth().id();
    final requestIds = request.input('request_ids') as List;
    final pricePerSeat = request.input('price_per_seat');
    final totalSeats = request.input('total_seats');

    // Get the first request to use its route
    final firstRequest = await TripRequest()
        .query()
        .where('id', '=', requestIds.first)
        .first();

    if (firstRequest == null) {
      return Response.json({'message': 'الطلب غير موجود'}, 404);
    }

    // Create trip from driver
    int bookedSeats = 0;
    final pendingRequests = <Map<String, dynamic>>[];

    for (final reqId in requestIds) {
      final req = await TripRequest()
          .query()
          .where('id', '=', reqId)
          .where('status', '=', 'pending')
          .first();
      if (req != null) {
        pendingRequests.add(req);
        bookedSeats += (req['seats_needed'] as int? ?? 1);
      }
    }

    final tripId = await Trip().query().insertGetId({
      'driver_id': driverId,
      'from_city': firstRequest['from_city'],
      'to_city': firstRequest['to_city'],
      'from_lat': firstRequest['from_lat'],
      'from_lng': firstRequest['from_lng'],
      'to_lat': firstRequest['to_lat'],
      'to_lng': firstRequest['to_lng'],
      'departure_time': firstRequest['requested_time'],
      'price': pricePerSeat,
      'available_seats': (totalSeats as int) - bookedSeats,
      'total_seats': totalSeats,
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Create bookings for each request and notify passengers
    for (final req in pendingRequests) {
      final seats = req['seats_needed'] as int? ?? 1;
      await Booking().query().insert({
        'trip_id': tripId,
        'passenger_id': req['passenger_id'],
        'seats': seats,
        'total_price': (pricePerSeat as num) * seats,
        'status': 'confirmed',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await TripRequest().query().where('id', '=', req['id']).update({
        'status': 'matched',
        'matched_trip_id': tripId,
        'updated_at': DateTime.now().toIso8601String(),
      });

      await NotificationController.notify(
        userId: req['passenger_id'],
        type: 'request_matched',
        title: 'تم إيجاد سائق لطلبك',
        body:
            'سائق قبل طلبك للرحلة من ${req['from_city']} إلى ${req['to_city']}',
      );
    }

    final trip = await Trip()
        .query()
        .select([
          'trips.*',
          'users.first_name',
          'users.last_name',
        ])
        .join('users', 'users.id', '=', 'trips.driver_id')
        .where('trips.id', '=', tripId)
        .first();

    return Response.json(
        {'message': 'تم إنشاء الرحلة وإشعار الركاب', 'data': sanitize(trip)},
        201);
  }

  /// DELETE /api/v1/trip-requests/{id}
  Future<Response> cancel(int id) async {
    final userId = Auth().id();

    final req = await TripRequest()
        .query()
        .where('id', '=', id)
        .where('passenger_id', '=', userId)
        .first();

    if (req == null) {
      return Response.json({'message': 'الطلب غير موجود'}, 404);
    }

    await TripRequest().query().where('id', '=', id).update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({'message': 'تم إلغاء الطلب'});
  }

  /// GET /admin/trip-requests (admin)
  Future<Response> listAll(Request request) async {
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;
    final status = request.query('status');

    var query = TripRequest()
        .query()
        .select([
          'trip_requests.*',
          'users.first_name',
          'users.last_name',
          'users.phone',
        ])
        .join('users', 'users.id', '=', 'trip_requests.passenger_id');

    if (status != null && status.isNotEmpty) {
      query = query.where('trip_requests.status', '=', status);
    }

    final requests = await query
        .orderBy('trip_requests.created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(requests));
  }
}

final TripRequestController tripRequestController = TripRequestController();
