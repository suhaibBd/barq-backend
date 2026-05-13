import 'package:vania/vania.dart';
import '../../../models/shipment.dart';
import '../../../models/shipment_rejection.dart';
import '../../../models/user.dart';
import '../../../models/notification.dart';
import '../../../services/assignment_service.dart';
import '../../helpers.dart';
import 'shipment_pricing.dart';

class ShipmentController extends Controller {
  /// POST /api/v1/shipments
  Future<Response> create(Request request) async {
    request.validate({
      'from_city': 'required|string|max_length:100',
      'to_city': 'required|string|max_length:100',
      'description': 'required|string|max_length:500',
      'size': 'required|in:small,medium,large',
      'receiver_name': 'required|string|max_length:100',
      'receiver_phone': 'required|string|max_length:20',
    });

    final senderId = Auth().id();
    final fromCity = request.input('from_city');
    final toCity = request.input('to_city');
    final size = request.input('size');
    final urgency = request.input('urgency') ?? 'normal';
    final pickupLat = request.input('pickup_lat');
    final pickupLng = request.input('pickup_lng');

    final suggestedPrice = calculateSuggestedPrice(
      fromCity: fromCity,
      toCity: toCity,
      size: size,
      urgency: urgency,
    );

    final price = request.input('price') ?? suggestedPrice;

    await Shipment().query().insert({
      'sender_id': senderId,
      'from_city': fromCity,
      'to_city': toCity,
      'description': request.input('description'),
      'size': size,
      'price': price,
      'suggested_price': suggestedPrice,
      'status': 'pending',
      'urgency': urgency,
      'receiver_name': request.input('receiver_name'),
      'receiver_phone': request.input('receiver_phone'),
      'notes': request.input('notes'),
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Get the inserted shipment ID
    final inserted = await Shipment()
        .query()
        .where('sender_id', '=', senderId)
        .orderBy('id', 'desc')
        .first();
    final shipmentId = inserted?['id'] as int?;

    if (shipmentId != null && pickupLat != null && pickupLng != null) {
      await assignmentService.assignNearestDriver(shipmentId);
    } else if (shipmentId != null) {
      await _notifyMatchingDrivers(fromCity, toCity, senderId);
    }

    return Response.json({
      'message': 'تم إنشاء الطلب بنجاح',
      'shipment_id': shipmentId,
      'suggested_price': suggestedPrice,
    }, 201);
  }

  /// GET /api/v1/shipments/price-estimate
  Future<Response> priceEstimate(Request request) async {
    final fromCity = request.query('from_city') ?? '';
    final toCity = request.query('to_city') ?? '';
    final size = request.query('size') ?? 'small';
    final urgency = request.query('urgency') ?? 'normal';

    final price = calculateSuggestedPrice(
      fromCity: fromCity,
      toCity: toCity,
      size: size,
      urgency: urgency,
    );

    return Response.json({'suggested_price': price});
  }

  /// GET /api/v1/shipments/{id}
  Future<Response> getById(Request request, int id) async {
    await assignmentService.processExpiredAssignments();

    final shipment = await Shipment()
        .query()
        .select([
          'shipments.*',
          'sender.first_name as sender_first_name',
          'sender.last_name as sender_last_name',
          'carrier.first_name as carrier_first_name',
          'carrier.last_name as carrier_last_name',
          'assigned.first_name as assigned_first_name',
          'assigned.last_name as assigned_last_name',
        ])
        .join('users as sender', 'sender.id', '=', 'shipments.sender_id')
        .leftJoin(
            'users as carrier', 'carrier.id', '=', 'shipments.carrier_id')
        .leftJoin('users as assigned', 'assigned.id', '=',
            'shipments.assigned_driver_id')
        .where('shipments.id', '=', id)
        .first();

    if (shipment == null) {
      return Response.json({'message': 'الطلب غير موجود'}, 404);
    }

    return Response.json(sanitize(shipment));
  }

  /// GET /api/v1/shipments/my
  Future<Response> myShipments(Request request) async {
    final userId = Auth().id();
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final shipments = await Shipment()
        .query()
        .select([
          'shipments.*',
          'sender.first_name as sender_first_name',
          'sender.last_name as sender_last_name',
          'carrier.first_name as carrier_first_name',
          'carrier.last_name as carrier_last_name',
        ])
        .join('users as sender', 'sender.id', '=', 'shipments.sender_id')
        .leftJoin(
            'users as carrier', 'carrier.id', '=', 'shipments.carrier_id')
        .where('shipments.sender_id', '=', userId)
        .orWhere('shipments.carrier_id', '=', userId)
        .orderBy('shipments.created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(shipments));
  }

  /// GET /api/v1/shipments/available
  Future<Response> available(Request request) async {
    await assignmentService.processExpiredAssignments();

    final userId = Auth().id();
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;
    final fromCity = request.query('from_city');
    final toCity = request.query('to_city');

    var query = Shipment()
        .query()
        .select([
          'shipments.*',
          'users.first_name as sender_first_name',
          'users.last_name as sender_last_name',
        ])
        .join('users', 'users.id', '=', 'shipments.sender_id')
        .where('shipments.status', '=', 'pending')
        .where('shipments.sender_id', '!=', userId);

    if (fromCity != null && fromCity.isNotEmpty) {
      query = query.where('shipments.from_city', '=', fromCity);
    }
    if (toCity != null && toCity.isNotEmpty) {
      query = query.where('shipments.to_city', '=', toCity);
    }

    final shipments = await query
        .orderBy('shipments.urgency', 'desc')
        .orderBy('shipments.created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(shipments));
  }

  /// PATCH /api/v1/shipments/{id}/accept
  Future<Response> accept(Request request, int id) async {
    final carrierId = Auth().id();

    final shipment =
        await Shipment().query().where('id', '=', id).first();

    if (shipment == null) {
      return Response.json({'message': 'الطلب غير موجود'}, 404);
    }
    if (shipment['sender_id'].toString() == carrierId.toString()) {
      return Response.json({'message': 'لا يمكنك قبول طلبك الخاص'}, 422);
    }
    if (shipment['status'] != 'pending') {
      return Response.json({'message': 'الطلب ليس في حالة انتظار'}, 422);
    }

    // If assigned to a specific driver, only that driver can accept (before expiry)
    final assignedId = shipment['assigned_driver_id'];
    if (assignedId != null) {
      final expiresAt = DateTime.tryParse(
          shipment['assignment_expires_at']?.toString() ?? '');
      if (expiresAt != null && DateTime.now().isBefore(expiresAt)) {
        if (assignedId.toString() != carrierId.toString()) {
          return Response.json(
              {'message': 'هذا الطلب مخصص لسائق آخر حالياً'}, 422);
        }
      }
    }

    await Shipment().query().where('id', '=', id).update({
      'carrier_id': carrierId,
      'status': 'accepted',
      'assigned_driver_id': null,
      'assignment_expires_at': null,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Notify sender
    await _notify(
      shipment['sender_id'],
      'shipment_accepted',
      'تم قبول طلبك',
      'سائق قبل توصيل طلبك من ${shipment['from_city']} إلى ${shipment['to_city']}',
    );

    return Response.json({'message': 'تم قبول الطلب بنجاح'});
  }

  /// PATCH /api/v1/shipments/{id}/reject
  Future<Response> reject(Request request, int id) async {
    final driverId = Auth().id();

    final shipment =
        await Shipment().query().where('id', '=', id).first();

    if (shipment == null) {
      return Response.json({'message': 'الطلب غير موجود'}, 404);
    }
    if (shipment['assigned_driver_id']?.toString() != driverId.toString()) {
      return Response.json({'message': 'هذا الطلب غير مخصص لك'}, 403);
    }

    // Record rejection
    await ShipmentRejection().query().insert({
      'shipment_id': id,
      'driver_id': driverId,
      'reason': 'rejected',
      'created_at': DateTime.now().toIso8601String(),
    });

    // Clear assignment
    await Shipment().query().where('id', '=', id).update({
      'assigned_driver_id': null,
      'assignment_expires_at': null,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Try next driver
    await assignmentService.assignNearestDriver(id);

    return Response.json({'message': 'تم رفض الطلب'});
  }

  /// PATCH /api/v1/shipments/{id}/status
  Future<Response> updateStatus(Request request, int id) async {
    request.validate({
      'status': 'required|in:picked_up,delivered',
    });

    final carrierId = Auth().id();
    final newStatus = request.input('status');

    final shipment =
        await Shipment().query().where('id', '=', id).first();

    if (shipment == null) {
      return Response.json({'message': 'الطلب غير موجود'}, 404);
    }
    if (shipment['carrier_id'].toString() != carrierId.toString()) {
      return Response.json({'message': 'غير مصرح'}, 403);
    }

    await Shipment().query().where('id', '=', id).update({
      'status': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    });

    final statusMsg = newStatus == 'picked_up'
        ? 'تم استلام طلبك من قبل السائق'
        : 'تم توصيل طلبك بنجاح';
    await _notify(
      shipment['sender_id'],
      'shipment_status',
      statusMsg,
      'طلبك من ${shipment['from_city']} إلى ${shipment['to_city']}',
    );

    return Response.json({'message': 'تم تحديث حالة الطلب'});
  }

  /// PATCH /api/v1/shipments/{id}/cancel
  Future<Response> cancel(Request request, int id) async {
    final userId = Auth().id();

    final shipment = await Shipment()
        .query()
        .where('id', '=', id)
        .where('sender_id', '=', userId)
        .first();

    if (shipment == null) {
      return Response.json({'message': 'الطلب غير موجود'}, 404);
    }

    final status = shipment['status'];
    if (status != 'pending' && status != 'accepted') {
      return Response.json(
          {'message': 'لا يمكن إلغاء الطلب في هذه الحالة'}, 422);
    }

    final updateData = <String, dynamic>{
      'status': 'cancelled',
      'assigned_driver_id': null,
      'assignment_expires_at': null,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (status == 'accepted') {
      updateData['carrier_id'] = null;
    }

    await Shipment().query().where('id', '=', id).update(updateData);

    return Response.json({'message': 'تم إلغاء الطلب'});
  }

  /// GET /api/v1/admin/shipments
  Future<Response> listAll(Request request) async {
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final shipments = await Shipment()
        .query()
        .select([
          'shipments.*',
          'sender.first_name as sender_first_name',
          'sender.last_name as sender_last_name',
          'carrier.first_name as carrier_first_name',
          'carrier.last_name as carrier_last_name',
        ])
        .join('users as sender', 'sender.id', '=', 'shipments.sender_id')
        .leftJoin(
            'users as carrier', 'carrier.id', '=', 'shipments.carrier_id')
        .orderBy('shipments.created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(shipments));
  }

  // ── Private helpers ──

  Future<void> _notifyMatchingDrivers(
      String fromCity, String toCity, dynamic senderId) async {
    final onlineDrivers = await User()
        .query()
        .where('role', '=', 'driver')
        .where('is_online', '=', 1)
        .where('id', '!=', senderId)
        .get();

    for (final driver in onlineDrivers) {
      await _notify(
        driver['id'],
        'shipment_match',
        'طلب جديد!',
        'يوجد طلب توصيل من $fromCity إلى $toCity',
      );
    }
  }

  Future<void> _notify(
      dynamic userId, String type, String title, String body) async {
    await AppNotification().query().insert({
      'user_id': userId,
      'type': type,
      'title': title,
      'body': body,
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

final ShipmentController shipmentController = ShipmentController();
