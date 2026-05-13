import 'package:vania/vania.dart';
import '../../../models/driver_credit.dart';
import '../../../models/credit_transaction.dart';
import '../../../models/trip_instance.dart';
import '../../../models/attendance.dart';
import '../../../models/recurring_trip.dart';
import '../../../models/subscription.dart';
import '../../../models/no_show_record.dart';
import '../../../models/user.dart';
import '../notification/notification_controller.dart';
import '../../helpers.dart';

class CreditController extends Controller {
  /// GET /api/v1/credits/balance
  Future<Response> getBalance(Request request) async {
    final driverId = Auth().id();

    var credit =
        await DriverCredit().query().where('driver_id', '=', driverId).first();

    if (credit == null) {
      final creditId = await DriverCredit().query().insertGetId({
        'driver_id': driverId,
        'balance': 0,
        'total_purchased': 0,
        'total_used': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      credit =
          await DriverCredit().query().where('id', '=', creditId).first();
    }

    return Response.json({
      'balance': credit!['balance'],
      'total_purchased': credit['total_purchased'],
      'total_used': credit['total_used'],
    });
  }

  /// POST /api/v1/credits/topup
  Future<Response> topup(Request request) async {
    request.validate({
      'amount': 'required|numeric',
    });

    final driverId = Auth().id();
    final amount = (request.input('amount') as num).toDouble();

    // Calculate rides based on amount
    int rides;
    switch (amount.toInt()) {
      case 5:
        rides = 20;
        break;
      case 10:
        rides = 40;
        break;
      case 25:
        rides = 110;
        break;
      case 50:
        rides = 230;
        break;
      default:
        rides = (amount * 4).toInt();
    }

    var credit =
        await DriverCredit().query().where('driver_id', '=', driverId).first();

    if (credit == null) {
      final creditId = await DriverCredit().query().insertGetId({
        'driver_id': driverId,
        'balance': 0,
        'total_purchased': 0,
        'total_used': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      credit =
          await DriverCredit().query().where('id', '=', creditId).first();
    }

    final newBalance = (credit!['balance'] as num) + rides;
    final newPurchased = (credit['total_purchased'] as num) + rides;

    await DriverCredit().query().where('id', '=', credit['id']).update({
      'balance': newBalance,
      'total_purchased': newPurchased,
      'updated_at': DateTime.now().toIso8601String(),
    });

    await CreditTransaction().query().insert({
      'driver_credit_id': credit['id'],
      'type': 'topup',
      'amount': rides,
      'cost_jod': amount,
      'created_at': DateTime.now().toIso8601String(),
    });

    return Response.json({
      'message': 'تم شحن البطاقة',
      'balance': newBalance,
      'rides_added': rides,
    });
  }

  /// GET /api/v1/credits/transactions
  Future<Response> transactions(Request request) async {
    final driverId = Auth().id();
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final credit =
        await DriverCredit().query().where('driver_id', '=', driverId).first();

    if (credit == null) {
      return Response.json({'data': [], 'total': 0});
    }

    final txns = await CreditTransaction()
        .query()
        .where('driver_credit_id', '=', credit['id'])
        .orderBy('created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(txns));
  }

  /// GET /api/v1/credits/today-trips
  Future<Response> getTodayTrips(Request request) async {
    final driverId = Auth().id();

    final now = DateTime.now();
    final todayDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final todayDayOfWeek = now.weekday % 7; // 0=Sunday, 1=Monday, ...

    // Get driver's active recurring trips
    final recurringTrips = await RecurringTrip()
        .query()
        .where('driver_id', '=', driverId)
        .where('status', '=', 'active')
        .get();

    final todayInstances = <Map<String, dynamic>>[];

    for (final trip in recurringTrips) {
      final daysOfWeek = trip['days_of_week']?.toString() ?? '';
      // Check if today's day is in the days_of_week string
      if (!daysOfWeek.contains(todayDayOfWeek.toString())) {
        continue;
      }

      // Check if trip_instance already exists for today
      var instance = await TripInstance()
          .query()
          .where('recurring_trip_id', '=', trip['id'])
          .where('trip_date', '=', todayDate)
          .first();

      if (instance == null) {
        final instanceId = await TripInstance().query().insertGetId({
          'recurring_trip_id': trip['id'],
          'trip_date': todayDate,
          'status': 'scheduled',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        instance =
            await TripInstance().query().where('id', '=', instanceId).first();
      }

      // Get subscriber info for this instance
      final subscribers = await Subscription()
          .query()
          .select([
            'subscriptions.*',
            'users.first_name',
            'users.last_name',
            'users.phone',
          ])
          .join('users', 'users.id', '=', 'subscriptions.passenger_id')
          .where('subscriptions.recurring_trip_id', '=', trip['id'])
          .where('subscriptions.status', '=', 'active')
          .get();

      // Get attendance for this instance
      final attendanceRecords = await Attendance()
          .query()
          .where('trip_instance_id', '=', instance!['id'])
          .get();

      todayInstances.add({
        ...instance,
        'recurring_trip': sanitize(trip),
        'subscribers': sanitize(subscribers),
        'attendance': sanitize(attendanceRecords),
      });
    }

    return Response.json({'data': sanitize(todayInstances)});
  }

  /// POST /api/v1/credits/trips/{instanceId}/start
  Future<Response> startTrip(int instanceId) async {
    final driverId = Auth().id();

    final instance = await TripInstance()
        .query()
        .select([
          'trip_instances.*',
          'recurring_trips.driver_id',
        ])
        .join('recurring_trips', 'recurring_trips.id', '=',
            'trip_instances.recurring_trip_id')
        .where('trip_instances.id', '=', instanceId)
        .first();

    if (instance == null) {
      return Response.json({'message': 'الرحلة غير موجودة'}, 404);
    }
    if (instance['driver_id'] != driverId) {
      return Response.json({'message': 'غير مصرح'}, 403);
    }

    await TripInstance().query().where('id', '=', instanceId).update({
      'status': 'in_progress',
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({'message': 'تم بدء الرحلة'});
  }

  /// POST /api/v1/credits/trips/{instanceId}/attendance
  /// Driver-side attendance marking: sets driver_status and driver_confirmed_at
  Future<Response> markAttendance(int instanceId, Request request) async {
    request.validate({
      'attendances': 'required',
    });

    final driverId = Auth().id();

    final instance = await TripInstance()
        .query()
        .select([
          'trip_instances.*',
          'recurring_trips.driver_id',
        ])
        .join('recurring_trips', 'recurring_trips.id', '=',
            'trip_instances.recurring_trip_id')
        .where('trip_instances.id', '=', instanceId)
        .first();

    if (instance == null) {
      return Response.json({'message': 'الرحلة غير موجودة'}, 404);
    }
    if (instance['driver_id'] != driverId) {
      return Response.json({'message': 'غير مصرح'}, 403);
    }

    final attendances = request.input('attendances') as List;
    final now = DateTime.now();

    for (final item in attendances) {
      final subscriptionId = item['subscription_id'];
      final status = item['status']; // 'present' or 'absent'

      // Check if attendance record already exists
      final existing = await Attendance()
          .query()
          .where('trip_instance_id', '=', instanceId)
          .where('subscription_id', '=', subscriptionId)
          .first();

      if (existing != null) {
        await Attendance()
            .query()
            .where('id', '=', existing['id'])
            .update({
          'driver_status': status,
          'driver_confirmed_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });

        // Re-fetch and resolve
        final updated = await Attendance()
            .query()
            .where('id', '=', existing['id'])
            .first();
        if (updated != null) {
          await _resolveAttendance(updated);
        }
      } else {
        final newId = await Attendance().query().insertGetId({
          'trip_instance_id': instanceId,
          'subscription_id': subscriptionId,
          'driver_status': status,
          'driver_confirmed_at': now.toIso8601String(),
          'rider_status': 'pending',
          'final_status': 'pending',
          'is_disputed': 0,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });

        final created =
            await Attendance().query().where('id', '=', newId).first();
        if (created != null) {
          await _resolveAttendance(created);
        }
      }
    }

    return Response.json({'message': 'تم تسجيل الحضور'});
  }

  /// POST /api/v1/credits/trips/{instanceId}/rider-attendance
  /// Rider confirms their own attendance for a trip instance
  Future<Response> riderConfirmAttendance(
      int instanceId, Request request) async {
    request.validate({
      'status': 'required|string',
    });

    final riderId = Auth().id();
    final status = request.input('status'); // 'present' or 'absent'

    if (!['present', 'absent'].contains(status)) {
      return Response.json(
          {'message': 'الحالة غير صالحة. القيم المتاحة: present, absent'},
          422);
    }

    // Find the rider's subscription for this trip instance
    final instance = await TripInstance()
        .query()
        .where('id', '=', instanceId)
        .first();

    if (instance == null) {
      return Response.json({'message': 'الرحلة غير موجودة'}, 404);
    }

    // Find the rider's active subscription for this recurring trip
    final subscription = await Subscription()
        .query()
        .where('recurring_trip_id', '=', instance['recurring_trip_id'])
        .where('passenger_id', '=', riderId)
        .where('status', '=', 'active')
        .first();

    if (subscription == null) {
      return Response.json(
          {'message': 'لا يوجد اشتراك نشط لهذا الخط'}, 404);
    }

    final now = DateTime.now();

    // Find the attendance record for this rider
    var attendance = await Attendance()
        .query()
        .where('trip_instance_id', '=', instanceId)
        .where('subscription_id', '=', subscription['id'])
        .first();

    if (attendance != null) {
      await Attendance()
          .query()
          .where('id', '=', attendance['id'])
          .update({
        'rider_status': status,
        'rider_confirmed_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Re-fetch and resolve
      final updated = await Attendance()
          .query()
          .where('id', '=', attendance['id'])
          .first();
      if (updated != null) {
        await _resolveAttendance(updated);
      }
    } else {
      // Create new attendance record with rider confirmation
      final newId = await Attendance().query().insertGetId({
        'trip_instance_id': instanceId,
        'subscription_id': subscription['id'],
        'driver_status': 'pending',
        'rider_status': status,
        'rider_confirmed_at': now.toIso8601String(),
        'final_status': 'pending',
        'is_disputed': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final created =
          await Attendance().query().where('id', '=', newId).first();
      if (created != null) {
        await _resolveAttendance(created);
      }
    }

    return Response.json({'message': 'تم تأكيد حضورك'});
  }

  /// Private helper: resolve attendance based on dual confirmation
  Future<void> _resolveAttendance(Map<String, dynamic> attendance) async {
    final driverStatus = attendance['driver_status']?.toString() ?? 'pending';
    final riderStatus = attendance['rider_status']?.toString() ?? 'pending';

    // Only resolve if both sides have confirmed (neither is 'pending')
    if (driverStatus == 'pending' || riderStatus == 'pending') {
      return;
    }

    final now = DateTime.now();

    if (driverStatus == riderStatus) {
      // Both agree
      await Attendance()
          .query()
          .where('id', '=', attendance['id'])
          .update({
        'final_status': driverStatus,
        'is_disputed': 0,
        'updated_at': now.toIso8601String(),
      });
    } else {
      // They disagree - mark as disputed
      await Attendance()
          .query()
          .where('id', '=', attendance['id'])
          .update({
        'final_status': 'disputed',
        'is_disputed': 1,
        'updated_at': now.toIso8601String(),
      });
    }
  }

  /// POST /api/v1/credits/trips/{instanceId}/complete
  Future<Response> completeTrip(int instanceId) async {
    final driverId = Auth().id();

    final instance = await TripInstance()
        .query()
        .select([
          'trip_instances.*',
          'recurring_trips.driver_id',
        ])
        .join('recurring_trips', 'recurring_trips.id', '=',
            'trip_instances.recurring_trip_id')
        .where('trip_instances.id', '=', instanceId)
        .first();

    if (instance == null) {
      return Response.json({'message': 'الرحلة غير موجودة'}, 404);
    }
    if (instance['driver_id'] != driverId) {
      return Response.json({'message': 'غير مصرح'}, 403);
    }

    // Get all attendance records for this instance
    final allAttendance = await Attendance()
        .query()
        .where('trip_instance_id', '=', instanceId)
        .get();

    int presentCount = 0;
    final now = DateTime.now();

    for (final record in allAttendance) {
      final finalStatus = record['final_status']?.toString() ?? 'pending';
      final driverStatus = record['driver_status']?.toString() ?? 'pending';
      final riderStatus = record['rider_status']?.toString() ?? 'pending';

      // Determine effective status for credit deduction
      // Present if: final_status == 'present', OR driver says present and rider hasn't confirmed
      final bool isPresent = finalStatus == 'present' ||
          (driverStatus == 'present' && riderStatus == 'pending');

      if (isPresent) {
        presentCount++;
      }

      // Handle absent riders: final_status == 'absent' OR driver says absent and rider didn't confirm
      final bool isAbsent = finalStatus == 'absent' ||
          (driverStatus == 'absent' && riderStatus == 'pending');

      if (isAbsent) {
        // Get the subscription to find the passenger
        final subscription = await Subscription()
            .query()
            .where('id', '=', record['subscription_id'])
            .first();

        if (subscription != null) {
          final passengerId = subscription['passenger_id'];

          // Create no_show_record
          await NoShowRecord().query().insert({
            'user_id': passengerId,
            'trip_instance_id': instanceId,
            'subscription_id': record['subscription_id'],
            'attendance_id': record['id'],
            'type': 'no_show',
            'role': 'rider',
            'penalty_points': 5,
            'created_at': now.toIso8601String(),
          });

          // Update user's reliability score and no-show count
          final user = await User()
              .query()
              .where('id', '=', passengerId)
              .first();

          if (user != null) {
            final currentScore =
                (user['reliability_score'] as num?)?.toInt() ?? 100;
            final newScore = currentScore - 5 < 0 ? 0 : currentScore - 5;
            final totalNoShows =
                ((user['total_no_shows'] as num?)?.toInt() ?? 0) + 1;

            await User().query().where('id', '=', passengerId).update({
              'reliability_score': newScore,
              'total_no_shows': totalNoShows,
              'updated_at': now.toIso8601String(),
            });
          }
        }
      }

      // Disputed records are kept for admin resolution - no action needed here
    }

    // Get driver's credit balance
    var credit =
        await DriverCredit().query().where('driver_id', '=', driverId).first();

    if (credit == null) {
      return Response.json({'message': 'لا يوجد رصيد'}, 422);
    }

    final currentBalance = (credit['balance'] as num).toInt();
    if (currentBalance < presentCount) {
      return Response.json({
        'message': 'رصيد غير كافٍ',
        'balance': currentBalance,
        'required': presentCount,
      }, 422);
    }

    // Deduct credits only for present riders
    final newBalance = currentBalance - presentCount;
    final newUsed = (credit['total_used'] as num) + presentCount;

    await DriverCredit().query().where('id', '=', credit['id']).update({
      'balance': newBalance,
      'total_used': newUsed,
      'updated_at': now.toIso8601String(),
    });

    // Create deduction transaction
    await CreditTransaction().query().insert({
      'driver_credit_id': credit['id'],
      'type': 'deduction',
      'amount': presentCount,
      'created_at': now.toIso8601String(),
    });

    // Set trip instance as completed
    await TripInstance().query().where('id', '=', instanceId).update({
      'status': 'completed',
      'updated_at': now.toIso8601String(),
    });

    return Response.json({
      'message': 'تم إنهاء الرحلة',
      'deducted': presentCount,
      'remaining': newBalance,
    });
  }

  /// POST /api/v1/credits/trips/{instanceId}/cancel
  Future<Response> cancelTodayTrip(int instanceId) async {
    final driverId = Auth().id();

    final instance = await TripInstance()
        .query()
        .select([
          'trip_instances.*',
          'recurring_trips.driver_id',
          'recurring_trips.id as recurring_trip_id',
        ])
        .join('recurring_trips', 'recurring_trips.id', '=',
            'trip_instances.recurring_trip_id')
        .where('trip_instances.id', '=', instanceId)
        .first();

    if (instance == null) {
      return Response.json({'message': 'الرحلة غير موجودة'}, 404);
    }
    if (instance['driver_id'] != driverId) {
      return Response.json({'message': 'غير مصرح'}, 403);
    }

    final now = DateTime.now();

    await TripInstance().query().where('id', '=', instanceId).update({
      'status': 'cancelled',
      'updated_at': now.toIso8601String(),
    });

    // Create no_show_record for driver same-day cancellation
    await NoShowRecord().query().insert({
      'user_id': driverId,
      'trip_instance_id': instanceId,
      'type': 'same_day_cancel',
      'role': 'driver',
      'penalty_points': 3,
      'created_at': now.toIso8601String(),
    });

    // Update driver's reliability score and cancellation count
    final driver =
        await User().query().where('id', '=', driverId).first();

    if (driver != null) {
      final currentScore =
          (driver['reliability_score'] as num?)?.toInt() ?? 100;
      final newScore = currentScore - 3 < 0 ? 0 : currentScore - 3;
      final totalCancellations =
          ((driver['total_cancellations'] as num?)?.toInt() ?? 0) + 1;

      await User().query().where('id', '=', driverId).update({
        'reliability_score': newScore,
        'total_cancellations': totalCancellations,
        'updated_at': now.toIso8601String(),
      });
    }

    // Notify all active subscribers
    final subscribers = await Subscription()
        .query()
        .where('recurring_trip_id', '=', instance['recurring_trip_id'])
        .where('status', '=', 'active')
        .get();

    for (final sub in subscribers) {
      await NotificationController.notify(
        userId: sub['passenger_id'],
        type: 'trip_cancelled',
        title: 'تم إلغاء رحلة اليوم',
        body: 'تم إلغاء رحلة اليوم',
      );
    }

    return Response.json({'message': 'تم إلغاء رحلة اليوم'});
  }

  /// GET /api/v1/credits/rider-today-trips
  /// Rider's view of today's trips based on their active subscriptions
  Future<Response> riderTodayTrips(Request request) async {
    final riderId = Auth().id();

    final now = DateTime.now();
    final todayDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final todayDayOfWeek = now.weekday % 7; // 0=Sunday, 1=Monday, ...

    // Get rider's active subscriptions with trip info
    final subscriptions = await Subscription()
        .query()
        .select([
          'subscriptions.*',
          'recurring_trips.from_city',
          'recurring_trips.to_city',
          'recurring_trips.departure_time',
          'recurring_trips.return_time',
          'recurring_trips.days_of_week',
          'recurring_trips.from_lat',
          'recurring_trips.from_lng',
          'recurring_trips.to_lat',
          'recurring_trips.to_lng',
          'recurring_trips.pooling_point_lat',
          'recurring_trips.pooling_point_lng',
          'recurring_trips.pooling_point_name',
          'users.first_name as driver_first_name',
          'users.last_name as driver_last_name',
          'users.avatar as driver_avatar',
          'users.rating as driver_rating',
        ])
        .join('recurring_trips', 'recurring_trips.id', '=',
            'subscriptions.recurring_trip_id')
        .join('users', 'users.id', '=', 'recurring_trips.driver_id')
        .where('subscriptions.passenger_id', '=', riderId)
        .where('subscriptions.status', '=', 'active')
        .get();

    final todayTrips = <Map<String, dynamic>>[];

    for (final sub in subscriptions) {
      final daysOfWeek = sub['days_of_week']?.toString() ?? '';
      // Check if today is a trip day
      if (!daysOfWeek.contains(todayDayOfWeek.toString())) {
        continue;
      }

      final recurringTripId = sub['recurring_trip_id'];

      // Find or create trip_instance for today
      var instance = await TripInstance()
          .query()
          .where('recurring_trip_id', '=', recurringTripId)
          .where('trip_date', '=', todayDate)
          .first();

      if (instance == null) {
        final instanceId = await TripInstance().query().insertGetId({
          'recurring_trip_id': recurringTripId,
          'trip_date': todayDate,
          'status': 'scheduled',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
        instance =
            await TripInstance().query().where('id', '=', instanceId).first();
      }

      // Get attendance status for this rider on this instance
      final attendance = await Attendance()
          .query()
          .where('trip_instance_id', '=', instance!['id'])
          .where('subscription_id', '=', sub['id'])
          .first();

      todayTrips.add({
        'trip_instance_id': instance['id'],
        'trip_instance_status': instance['status'],
        'trip_date': todayDate,
        'recurring_trip_id': recurringTripId,
        'from_city': sub['from_city'],
        'to_city': sub['to_city'],
        'departure_time': sub['departure_time'],
        'return_time': sub['return_time'],
        'pooling_point_name': sub['pooling_point_name'],
        'driver_first_name': sub['driver_first_name'],
        'driver_last_name': sub['driver_last_name'],
        'driver_avatar': sub['driver_avatar'],
        'driver_rating': sub['driver_rating'],
        'subscription_id': sub['id'],
        'attendance': attendance != null
            ? sanitize(attendance)
            : null,
      });
    }

    return Response.json({'data': sanitize(todayTrips)});
  }
}

final CreditController creditController = CreditController();
