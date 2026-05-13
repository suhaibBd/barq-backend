import 'package:vania/vania.dart';
import '../../../models/booking.dart';
import '../../../models/trip.dart';
import '../../../models/wallet.dart';
import '../../../models/transaction.dart';
import '../notification/notification_controller.dart';
import '../../helpers.dart';

const double bookingCommission = 0.25;

class BookingController extends Controller {
  /// POST /api/v1/bookings
  Future<Response> create(Request request) async {
    request.validate({
      'trip_id': 'required|integer',
      'seats': 'required|integer|min:1',
    });

    final passengerId = Auth().id();
    final tripId = request.input('trip_id');
    final seats = request.input('seats');

    final trip = await Trip().query().where('id', '=', tripId).first();
    if (trip == null) {
      return Response.json({'message': 'الرحلة غير موجودة'}, 404);
    }
    if (trip['driver_id'].toString() == passengerId.toString()) {
      return Response.json({'message': 'لا يمكنك حجز رحلتك الخاصة'}, 422);
    }
    if (trip['status'] != 'active') {
      return Response.json({'message': 'الرحلة غير متاحة للحجز'}, 422);
    }

    final existingBooking = await Booking()
        .query()
        .where('trip_id', '=', tripId)
        .where('passenger_id', '=', passengerId)
        .where('status', '!=', 'cancelled')
        .first();
    if (existingBooking != null) {
      return Response.json({'message': 'لديك حجز مسبق على هذه الرحلة'}, 422);
    }

    if (trip['available_seats'] < seats) {
      return Response.json({'message': 'لا توجد مقاعد كافية'}, 422);
    }

    final totalPrice = (trip['price'] as num) * (seats as num);

    await Booking().query().insert({
      'trip_id': tripId,
      'passenger_id': passengerId,
      'seats': seats,
      'total_price': totalPrice,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await NotificationController.notify(
      userId: trip['driver_id'],
      type: 'new_booking',
      title: 'طلب حجز جديد',
      body: 'لديك طلب حجز جديد بعدد $seats مقاعد',
    );

    return Response.json({'message': 'تم إنشاء طلب الحجز'}, 201);
  }

  /// GET /api/v1/bookings/my
  Future<Response> myBookings(Request request) async {
    final userId = Auth().id();
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final bookings = await Booking()
        .query()
        .select([
          'bookings.*',
          'trips.from_city',
          'trips.to_city',
          'trips.departure_time',
          'trips.price',
        ])
        .join('trips', 'trips.id', '=', 'bookings.trip_id')
        .where('bookings.passenger_id', '=', userId)
        .orderBy('bookings.created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(bookings));
  }

  /// GET /api/v1/bookings/requests
  Future<Response> driverRequests(Request request) async {
    final driverId = Auth().id();
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final bookings = await Booking()
        .query()
        .select([
          'bookings.*',
          'trips.from_city',
          'trips.to_city',
          'trips.departure_time',
          'users.first_name',
          'users.last_name',
          'users.phone',
          'users.rating',
        ])
        .join('trips', 'trips.id', '=', 'bookings.trip_id')
        .join('users', 'users.id', '=', 'bookings.passenger_id')
        .where('trips.driver_id', '=', driverId)
        .where('bookings.status', '=', 'pending')
        .orderBy('bookings.created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(bookings));
  }

  /// PATCH /api/v1/bookings/{id}/confirm
  Future<Response> confirm(int id) async {
    final driverId = Auth().id();

    final booking = await Booking()
        .query()
        .select(['bookings.*', 'trips.driver_id', 'trips.available_seats'])
        .join('trips', 'trips.id', '=', 'bookings.trip_id')
        .where('bookings.id', '=', id)
        .first();

    if (booking == null) {
      return Response.json({'message': 'الحجز غير موجود'}, 404);
    }
    if (booking['driver_id'] != driverId) {
      return Response.json({'message': 'غير مصرح'}, 403);
    }
    if (booking['status'] != 'pending') {
      return Response.json({'message': 'الحجز ليس في حالة انتظار'}, 422);
    }

    // Check driver wallet balance for commission (auto-create if missing)
    var driverWallet = await Wallet().query().where('user_id', '=', driverId).first();
    if (driverWallet == null) {
      await Wallet().query().insert({
        'user_id': driverId,
        'balance': 0.0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      driverWallet = await Wallet().query().where('user_id', '=', driverId).first();
    }

    final driverBalance = (driverWallet!['balance'] as num).toDouble();
    if (driverBalance < bookingCommission) {
      return Response.json({
        'message': 'رصيدك غير كافٍ. يُخصم $bookingCommission د.أ عمولة لكل حجز. رصيدك الحالي: $driverBalance د.أ',
      }, 422);
    }

    // Deduct commission from driver wallet
    final newDriverBalance = driverBalance - bookingCommission;
    await Wallet().query().where('id', '=', driverWallet['id']).update({
      'balance': newDriverBalance,
      'updated_at': DateTime.now().toIso8601String(),
    });

    await Transaction().query().insert({
      'wallet_id': driverWallet['id'],
      'type': 'commission',
      'amount': -bookingCommission,
      'description': 'عمولة تأكيد حجز #$id',
      'created_at': DateTime.now().toIso8601String(),
    });

    // Confirm the booking
    await Booking().query().where('id', '=', id).update({
      'status': 'confirmed',
      'updated_at': DateTime.now().toIso8601String(),
    });

    final newSeats = (booking['available_seats'] as num) - (booking['seats'] as num);
    final tripUpdate = <String, dynamic>{
      'available_seats': newSeats,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (newSeats <= 0) {
      tripUpdate['status'] = 'full';
    }
    await Trip().query().where('id', '=', booking['trip_id']).update(tripUpdate);

    await NotificationController.notify(
      userId: booking['passenger_id'],
      type: 'booking_confirmed',
      title: 'تم تأكيد حجزك',
      body: 'تم تأكيد حجزك بنجاح. استعد للرحلة!',
    );

    return Response.json({
      'message': 'تم تأكيد الحجز',
      'commission_deducted': bookingCommission,
      'new_balance': newDriverBalance,
    });
  }

  /// PATCH /api/v1/bookings/{id}/reject
  Future<Response> reject(int id) async {
    final driverId = Auth().id();

    final booking = await Booking()
        .query()
        .select(['bookings.*', 'trips.driver_id'])
        .join('trips', 'trips.id', '=', 'bookings.trip_id')
        .where('bookings.id', '=', id)
        .first();

    if (booking == null) {
      return Response.json({'message': 'الحجز غير موجود'}, 404);
    }
    if (booking['driver_id'] != driverId) {
      return Response.json({'message': 'غير مصرح'}, 403);
    }

    await Booking().query().where('id', '=', id).update({
      'status': 'rejected',
      'updated_at': DateTime.now().toIso8601String(),
    });

    await NotificationController.notify(
      userId: booking['passenger_id'],
      type: 'booking_rejected',
      title: 'تم رفض حجزك',
      body: 'للأسف، لم يتم قبول حجزك. جرب رحلة أخرى.',
    );

    return Response.json({'message': 'تم رفض الحجز'});
  }

  /// PATCH /api/v1/bookings/{id}/cancel
  Future<Response> cancel(int id) async {
    final userId = Auth().id();

    final booking = await Booking()
        .query()
        .select(['bookings.*', 'trips.driver_id'])
        .join('trips', 'trips.id', '=', 'bookings.trip_id')
        .where('bookings.id', '=', id)
        .where('bookings.passenger_id', '=', userId)
        .first();

    if (booking == null) {
      return Response.json({'message': 'الحجز غير موجود'}, 404);
    }

    if (booking['status'] == 'confirmed') {
      // Restore available seats
      await Trip().query().where('id', '=', booking['trip_id']).update({
        'available_seats': booking['seats'],
        'status': 'active',
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Refund commission to driver
      final driverWallet = await Wallet()
          .query()
          .where('user_id', '=', booking['driver_id'])
          .first();
      if (driverWallet != null) {
        final currentBalance = (driverWallet['balance'] as num).toDouble();
        await Wallet().query().where('id', '=', driverWallet['id']).update({
          'balance': currentBalance + bookingCommission,
          'updated_at': DateTime.now().toIso8601String(),
        });
        await Transaction().query().insert({
          'wallet_id': driverWallet['id'],
          'type': 'refund',
          'amount': bookingCommission,
          'description': 'استرداد عمولة حجز ملغي #$id',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }

    await Booking().query().where('id', '=', id).update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({'message': 'تم إلغاء الحجز'});
  }

  /// GET /api/v1/bookings/all (admin)
  Future<Response> listAll(Request request) async {
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final bookings = await Booking()
        .query()
        .select([
          'bookings.*',
          'trips.from_city',
          'trips.to_city',
          'trips.departure_time',
          'users.first_name',
          'users.last_name',
        ])
        .join('trips', 'trips.id', '=', 'bookings.trip_id')
        .join('users', 'users.id', '=', 'bookings.passenger_id')
        .orderBy('bookings.created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(bookings));
  }
}

final BookingController bookingController = BookingController();
