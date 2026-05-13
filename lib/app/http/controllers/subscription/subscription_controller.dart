import 'package:vania/vania.dart';
import '../../../models/subscription.dart';
import '../../../models/subscription_payment.dart';
import '../../../models/recurring_trip.dart';
import '../notification/notification_controller.dart';
import '../../helpers.dart';

class SubscriptionController extends Controller {
  /// POST /api/v1/subscriptions
  Future<Response> subscribe(Request request) async {
    request.validate({
      'recurring_trip_id': 'required|integer',
    });

    final passengerId = Auth().id();
    final tripId = request.input('recurring_trip_id');
    final type = request.input('type') ?? 'monthly';

    // Validate subscription type
    if (!['monthly', 'weekly', 'daily'].contains(type)) {
      return Response.json(
          {'message': 'نوع الاشتراك غير صالح. الأنواع المتاحة: monthly, weekly, daily'},
          422);
    }

    final trip =
        await RecurringTrip().query().where('id', '=', tripId).first();

    if (trip == null) {
      return Response.json({'message': 'الخط غير موجود'}, 404);
    }
    if (trip['status'] != 'active') {
      return Response.json({'message': 'الخط غير متاح للاشتراك'}, 422);
    }
    if ((trip['available_seats'] as num) <= 0) {
      return Response.json({'message': 'لا توجد مقاعد متاحة'}, 422);
    }

    // Check if passenger already has an active subscription
    final existing = await Subscription()
        .query()
        .where('recurring_trip_id', '=', tripId)
        .where('passenger_id', '=', passengerId)
        .where('status', '=', 'active')
        .first();

    if (existing != null) {
      return Response.json({'message': 'أنت مشترك بالفعل في هذا الخط'}, 422);
    }

    // Get the correct price based on subscription type
    double price;
    switch (type) {
      case 'weekly':
        price = (trip['weekly_price'] as num).toDouble();
        break;
      case 'daily':
        price = (trip['daily_price'] as num).toDouble();
        break;
      default:
        price = (trip['monthly_price'] as num).toDouble();
    }

    // Calculate service fee and total
    final serviceFeePercent = (trip['service_fee_percent'] as num).toDouble();
    final serviceFee =
        double.parse((price * (serviceFeePercent / 100)).toStringAsFixed(2));
    final totalPaid = double.parse((price + serviceFee).toStringAsFixed(2));

    final now = DateTime.now();
    final billingStart = now.toIso8601String().substring(0, 10);

    // Calculate billing end based on type
    DateTime billingEndDate;
    switch (type) {
      case 'weekly':
        billingEndDate = now.add(const Duration(days: 7));
        break;
      case 'daily':
        billingEndDate = now.add(const Duration(days: 1));
        break;
      default:
        billingEndDate = now.add(const Duration(days: 30));
    }
    final billingEnd = billingEndDate.toIso8601String().substring(0, 10);

    final paymentMethod = request.input('payment_method') ?? 'cash';

    final subscriptionId = await Subscription().query().insertGetId({
      'recurring_trip_id': tripId,
      'passenger_id': passengerId,
      'start_date': billingStart,
      'monthly_price': trip['monthly_price'],
      'type': type,
      'service_fee': serviceFee,
      'total_paid': totalPaid,
      'billing_start': billingStart,
      'billing_end': billingEnd,
      'auto_renew': 1,
      'payment_method': paymentMethod,
      'status': 'active',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    // Create subscription payment record
    await SubscriptionPayment().query().insert({
      'subscription_id': subscriptionId,
      'amount': price,
      'service_fee': serviceFee,
      'total_paid': totalPaid,
      'payment_method': paymentMethod,
      'billing_start': billingStart,
      'billing_end': billingEnd,
      'status': 'paid',
      'created_at': now.toIso8601String(),
    });

    // Decrement available seats
    final newSeats = (trip['available_seats'] as num) - 1;
    await RecurringTrip().query().where('id', '=', tripId).update({
      'available_seats': newSeats,
      'updated_at': now.toIso8601String(),
    });

    // Notify driver
    await NotificationController.notify(
      userId: trip['driver_id'],
      type: 'new_subscription',
      title: 'مشترك جديد في خطك',
      body: 'مشترك جديد في خطك',
    );

    return Response.json({'message': 'تم الاشتراك بنجاح'}, 201);
  }

  /// GET /api/v1/subscriptions/my
  Future<Response> mySubscriptions(Request request) async {
    final passengerId = Auth().id();
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final subscriptions = await Subscription()
        .query()
        .select([
          'subscriptions.*',
          'subscriptions.type',
          'subscriptions.service_fee',
          'subscriptions.total_paid',
          'subscriptions.billing_start',
          'subscriptions.billing_end',
          'subscriptions.auto_renew',
          'recurring_trips.from_city',
          'recurring_trips.to_city',
          'recurring_trips.departure_time',
          'recurring_trips.days_of_week',
          'recurring_trips.monthly_price as trip_monthly_price',
          'recurring_trips.weekly_price as trip_weekly_price',
          'recurring_trips.daily_price as trip_daily_price',
          'users.first_name',
          'users.last_name',
          'users.avatar',
          'users.rating',
        ])
        .join('recurring_trips', 'recurring_trips.id', '=',
            'subscriptions.recurring_trip_id')
        .join('users', 'users.id', '=', 'recurring_trips.driver_id')
        .where('subscriptions.passenger_id', '=', passengerId)
        .where('subscriptions.status', '!=', 'cancelled')
        .orderBy('subscriptions.created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(subscriptions));
  }

  /// GET /api/v1/subscriptions/trip/{tripId}
  Future<Response> tripSubscribers(int tripId) async {
    final driverId = Auth().id();

    // Verify driver owns the trip
    final trip = await RecurringTrip()
        .query()
        .where('id', '=', tripId)
        .where('driver_id', '=', driverId)
        .first();

    if (trip == null) {
      return Response.json({'message': 'الخط غير موجود'}, 404);
    }

    // Determine if phone should be visible based on trip day and time window
    final now = DateTime.now();
    final todayDayOfWeek = now.weekday % 7; // 0=Sunday, 1=Monday, ...
    final daysOfWeek = trip['days_of_week']?.toString() ?? '';
    final isTripDay = daysOfWeek.contains(todayDayOfWeek.toString());

    bool inTimeWindow = false;
    if (isTripDay && trip['departure_time'] != null) {
      // Parse departure_time (expected format HH:mm or HH:mm:ss)
      final timeParts = trip['departure_time'].toString().split(':');
      if (timeParts.length >= 2) {
        final departureHour = int.tryParse(timeParts[0]) ?? 0;
        final departureMinute = int.tryParse(timeParts[1]) ?? 0;
        final departureDateTime = DateTime(
            now.year, now.month, now.day, departureHour, departureMinute);

        // Window: 30 min before to 2 hours after departure
        final windowStart =
            departureDateTime.subtract(const Duration(minutes: 30));
        final windowEnd = departureDateTime.add(const Duration(hours: 2));

        inTimeWindow = now.isAfter(windowStart) && now.isBefore(windowEnd);
      }
    }

    // Select phone conditionally
    final phoneSelect =
        inTimeWindow ? 'users.phone' : "'***' as phone";

    final subscribers = await Subscription()
        .query()
        .select([
          'subscriptions.*',
          'users.first_name',
          'users.last_name',
          phoneSelect,
          'users.reliability_score',
        ])
        .join('users', 'users.id', '=', 'subscriptions.passenger_id')
        .where('subscriptions.recurring_trip_id', '=', tripId)
        .where('subscriptions.status', '=', 'active')
        .get();

    return Response.json({'data': sanitize(subscribers)});
  }

  /// POST /api/v1/subscriptions/{id}/renew
  Future<Response> renewSubscription(int id) async {
    final passengerId = Auth().id();

    final subscription = await Subscription()
        .query()
        .where('id', '=', id)
        .where('passenger_id', '=', passengerId)
        .first();

    if (subscription == null) {
      return Response.json({'message': 'الاشتراك غير موجود'}, 404);
    }

    // Check if billing_end has passed or is today
    final billingEnd = subscription['billing_end']?.toString() ?? '';
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);

    if (billingEnd.isNotEmpty && billingEnd.compareTo(todayStr) > 0) {
      return Response.json(
          {'message': 'لم تنته فترة الاشتراك بعد'}, 422);
    }

    // Check auto_renew flag
    if (subscription['auto_renew'] == 0) {
      return Response.json(
          {'message': 'التجديد التلقائي معطل لهذا الاشتراك'}, 422);
    }

    // Get trip for pricing
    final tripId = subscription['recurring_trip_id'];
    final trip =
        await RecurringTrip().query().where('id', '=', tripId).first();

    if (trip == null) {
      return Response.json({'message': 'الخط غير موجود'}, 404);
    }

    final type = subscription['type'] ?? 'monthly';

    // Get the correct price based on type
    double price;
    switch (type) {
      case 'weekly':
        price = (trip['weekly_price'] as num).toDouble();
        break;
      case 'daily':
        price = (trip['daily_price'] as num).toDouble();
        break;
      default:
        price = (trip['monthly_price'] as num).toDouble();
    }

    final serviceFeePercent = (trip['service_fee_percent'] as num).toDouble();
    final serviceFee =
        double.parse((price * (serviceFeePercent / 100)).toStringAsFixed(2));
    final totalPaid = double.parse((price + serviceFee).toStringAsFixed(2));

    final billingStart = now.toIso8601String().substring(0, 10);

    DateTime billingEndDate;
    switch (type) {
      case 'weekly':
        billingEndDate = now.add(const Duration(days: 7));
        break;
      case 'daily':
        billingEndDate = now.add(const Duration(days: 1));
        break;
      default:
        billingEndDate = now.add(const Duration(days: 30));
    }
    final newBillingEnd = billingEndDate.toIso8601String().substring(0, 10);

    final paymentMethod = subscription['payment_method'] ?? 'cash';

    // Create new subscription record with renewed_from_id
    final newSubscriptionId = await Subscription().query().insertGetId({
      'recurring_trip_id': tripId,
      'passenger_id': passengerId,
      'start_date': billingStart,
      'monthly_price': trip['monthly_price'],
      'type': type,
      'service_fee': serviceFee,
      'total_paid': totalPaid,
      'billing_start': billingStart,
      'billing_end': newBillingEnd,
      'auto_renew': 1,
      'renewed_from_id': id,
      'payment_method': paymentMethod,
      'status': 'active',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    // Create subscription payment record
    await SubscriptionPayment().query().insert({
      'subscription_id': newSubscriptionId,
      'amount': price,
      'service_fee': serviceFee,
      'total_paid': totalPaid,
      'payment_method': paymentMethod,
      'billing_start': billingStart,
      'billing_end': newBillingEnd,
      'status': 'paid',
      'created_at': now.toIso8601String(),
    });

    // Mark old subscription as renewed
    await Subscription().query().where('id', '=', id).update({
      'status': 'renewed',
      'updated_at': now.toIso8601String(),
    });

    return Response.json({
      'message': 'تم تجديد الاشتراك بنجاح',
      'new_subscription_id': newSubscriptionId,
    });
  }

  /// GET /api/v1/subscriptions/{subscriptionId}/payments
  Future<Response> getSubscriptionPayments(
      int subscriptionId, Request request) async {
    final passengerId = Auth().id();
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    // Verify the subscription belongs to this passenger
    final subscription = await Subscription()
        .query()
        .where('id', '=', subscriptionId)
        .where('passenger_id', '=', passengerId)
        .first();

    if (subscription == null) {
      return Response.json({'message': 'الاشتراك غير موجود'}, 404);
    }

    final payments = await SubscriptionPayment()
        .query()
        .where('subscription_id', '=', subscriptionId)
        .orderBy('created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(payments));
  }

  /// PATCH /api/v1/subscriptions/{id}/cancel
  Future<Response> cancelSubscription(int id) async {
    final passengerId = Auth().id();

    final subscription = await Subscription()
        .query()
        .where('id', '=', id)
        .where('passenger_id', '=', passengerId)
        .first();

    if (subscription == null) {
      return Response.json({'message': 'الاشتراك غير موجود'}, 404);
    }

    await Subscription().query().where('id', '=', id).update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Increment available seats
    final tripId = subscription['recurring_trip_id'];
    final trip =
        await RecurringTrip().query().where('id', '=', tripId).first();
    if (trip != null) {
      final newSeats = (trip['available_seats'] as num) + 1;
      await RecurringTrip().query().where('id', '=', tripId).update({
        'available_seats': newSeats,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    return Response.json({'message': 'تم إلغاء الاشتراك'});
  }

  /// PATCH /api/v1/subscriptions/{id}/pause
  Future<Response> pauseSubscription(int id) async {
    final passengerId = Auth().id();

    final subscription = await Subscription()
        .query()
        .where('id', '=', id)
        .where('passenger_id', '=', passengerId)
        .first();

    if (subscription == null) {
      return Response.json({'message': 'الاشتراك غير موجود'}, 404);
    }

    await Subscription().query().where('id', '=', id).update({
      'status': 'paused',
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({'message': 'تم إيقاف الاشتراك مؤقتاً'});
  }
}

final SubscriptionController subscriptionController =
    SubscriptionController();
