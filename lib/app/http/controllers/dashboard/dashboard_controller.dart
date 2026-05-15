import 'package:vania/vania.dart';
import '../../../models/user.dart';
import '../../../models/shipment.dart';
import '../../../models/driver_document.dart';
import '../../../models/rating.dart';
import '../../helpers.dart';

class DashboardController extends Controller {
  /// GET /api/v1/dashboard/stats
  Future<Response> stats(Request request) async {
    final totalUsers = await User().query().count();
    final totalDrivers = await User().query().where('role', '=', 'driver').count();
    final totalStores = await User().query().where('role', '=', 'store').count();
    final verifiedDrivers = await User().query().where('is_driver_verified', '=', 1).count();
    final totalOrders = await Shipment().query().count();
    final pendingOrders = await Shipment().query().where('status', '=', 'pending').count();
    final deliveredOrders = await Shipment().query().where('status', '=', 'delivered').count();
    final pendingDocuments = await DriverDocument().query().where('status', '=', 'pending').count();
    final totalRatings = await Rating().query().count();

    return Response.json({
      'users_count': totalUsers,
      'drivers_count': totalDrivers,
      'stores_count': totalStores,
      'verified_drivers': verifiedDrivers,
      'total_orders': totalOrders,
      'pending_orders': pendingOrders,
      'delivered_orders': deliveredOrders,
      'pending_docs_count': pendingDocuments,
      'ratings_count': totalRatings,
    });
  }

  /// GET /api/v1/dashboard/recent-users
  Future<Response> recentUsers(Request request) async {
    final users = await User()
        .query()
        .orderBy('created_at', 'desc')
        .limit(10)
        .get();

    return Response.json(sanitize(users));
  }

  /// GET /api/v1/dashboard/recent-orders
  Future<Response> recentOrders(Request request) async {
    final orders = await Shipment()
        .query()
        .select([
          'shipments.*',
          'users.first_name',
          'users.last_name',
        ])
        .join('users', 'users.id', '=', 'shipments.sender_id')
        .orderBy('shipments.created_at', 'desc')
        .limit(10)
        .get();

    return Response.json(sanitize(orders));
  }
}

final DashboardController dashboardController = DashboardController();
