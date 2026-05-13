import 'dart:math';
import '../models/driver_location.dart';
import '../models/shipment.dart';
import '../models/shipment_rejection.dart';
import '../models/notification.dart';

class AssignmentService {
  static const _assignmentTimeoutMinutes = 2;
  static const _staleLocationMinutes = 10;

  Future<Map<String, dynamic>?> assignNearestDriver(int shipmentId) async {
    final shipment =
        await Shipment().query().where('id', '=', shipmentId).first();
    if (shipment == null) return null;

    final pickupLat = (shipment['pickup_lat'] as num?)?.toDouble();
    final pickupLng = (shipment['pickup_lng'] as num?)?.toDouble();
    if (pickupLat == null || pickupLng == null) return null;

    final rejections = await ShipmentRejection()
        .query()
        .where('shipment_id', '=', shipmentId)
        .get();
    final rejectedIds =
        rejections.map((r) => r['driver_id'].toString()).toSet();

    final staleThreshold = DateTime.now()
        .subtract(const Duration(minutes: _staleLocationMinutes))
        .toIso8601String();

    final drivers = await DriverLocation()
        .query()
        .select([
          'driver_locations.*',
          'users.id as uid',
          'users.fcm_token',
          'users.first_name',
          'users.last_name',
        ])
        .join('users', 'users.id', '=', 'driver_locations.user_id')
        .where('users.role', '=', 'driver')
        .where('users.is_online', '=', 1)
        .where('users.is_driver_verified', '=', 1)
        .where('users.id', '!=', shipment['sender_id'])
        .where('driver_locations.updated_at', '>', staleThreshold)
        .get();

    final eligible = drivers
        .where((d) => !rejectedIds.contains(d['uid'].toString()))
        .toList();

    if (eligible.isEmpty) {
      await _notifySender(
        shipment['sender_id'],
        shipmentId,
        'لا يوجد سائقون متاحون حالياً',
      );
      return null;
    }

    eligible.sort((a, b) {
      final distA = _haversineKm(
        pickupLat,
        pickupLng,
        (a['latitude'] as num).toDouble(),
        (a['longitude'] as num).toDouble(),
      );
      final distB = _haversineKm(
        pickupLat,
        pickupLng,
        (b['latitude'] as num).toDouble(),
        (b['longitude'] as num).toDouble(),
      );
      return distA.compareTo(distB);
    });

    final nearest = eligible.first;
    final expiresAt = DateTime.now()
        .add(const Duration(minutes: _assignmentTimeoutMinutes));

    await Shipment().query().where('id', '=', shipmentId).update({
      'assigned_driver_id': nearest['uid'],
      'assignment_expires_at': expiresAt.toIso8601String(),
      'assignment_attempts':
          (shipment['assignment_attempts'] as int? ?? 0) + 1,
      'updated_at': DateTime.now().toIso8601String(),
    });

    await AppNotification().query().insert({
      'user_id': nearest['uid'],
      'type': 'shipment_assignment',
      'title': 'طلب توصيل جديد!',
      'body':
          'طلب من ${shipment['from_city']} إلى ${shipment['to_city']} - ${shipment['price']} د.أ',
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    return nearest;
  }

  Future<void> processExpiredAssignments() async {
    final now = DateTime.now().toIso8601String();

    final expired = await Shipment()
        .query()
        .where('status', '=', 'pending')
        .where('assigned_driver_id', '!=', null)
        .where('assignment_expires_at', '<', now)
        .get();

    for (final shipment in expired) {
      await ShipmentRejection().query().insert({
        'shipment_id': shipment['id'],
        'driver_id': shipment['assigned_driver_id'],
        'reason': 'timeout',
        'created_at': now,
      });

      await Shipment().query().where('id', '=', shipment['id']).update({
        'assigned_driver_id': null,
        'assignment_expires_at': null,
        'updated_at': now,
      });

      await assignNearestDriver(shipment['id'] as int);
    }
  }

  Future<void> _notifySender(
      dynamic senderId, int shipmentId, String message) async {
    await AppNotification().query().insert({
      'user_id': senderId,
      'type': 'no_drivers_available',
      'title': message,
      'body': 'طلب رقم #$shipmentId - سيتم المحاولة لاحقاً',
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * pi / 180;
}

final AssignmentService assignmentService = AssignmentService();
