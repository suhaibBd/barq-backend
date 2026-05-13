import 'package:vania/vania.dart';
import '../../../models/driver_location.dart';

class DriverLocationController extends Controller {
  /// POST /api/v1/driver/location
  Future<Response> updateLocation(Request request) async {
    request.validate({
      'latitude': 'required|numeric',
      'longitude': 'required|numeric',
    });

    final userId = Auth().id();
    final lat = request.input('latitude');
    final lng = request.input('longitude');
    final now = DateTime.now().toIso8601String();

    final existing = await DriverLocation()
        .query()
        .where('user_id', '=', userId)
        .first();

    if (existing != null) {
      await DriverLocation()
          .query()
          .where('user_id', '=', userId)
          .update({
        'latitude': lat,
        'longitude': lng,
        'updated_at': now,
      });
    } else {
      await DriverLocation().query().insert({
        'user_id': userId,
        'latitude': lat,
        'longitude': lng,
        'updated_at': now,
      });
    }

    return Response.json({'message': 'تم تحديث الموقع'});
  }

  /// GET /api/v1/driver/location
  Future<Response> getLocation(Request request) async {
    final userId = Auth().id();
    final location = await DriverLocation()
        .query()
        .where('user_id', '=', userId)
        .first();

    if (location == null) {
      return Response.json({'message': 'لا يوجد موقع مسجل'}, 404);
    }

    return Response.json({
      'latitude': location['latitude'],
      'longitude': location['longitude'],
      'updated_at': location['updated_at']?.toString(),
    });
  }
}

final DriverLocationController driverLocationController =
    DriverLocationController();
