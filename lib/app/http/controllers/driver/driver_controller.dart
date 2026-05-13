import 'package:vania/vania.dart';
import '../../../models/driver_document.dart';
import '../../../models/user.dart';
import '../../helpers.dart';

class DriverController extends Controller {
  /// POST /api/v1/driver/documents
  Future<Response> submitDocuments(Request request) async {
    final userId = Auth().id();

    final RequestFile? nationalId = request.file('national_id');
    final RequestFile? driverLicense = request.file('driver_license');
    final RequestFile? carImage = request.file('car_image');
    final carNumber = request.input('car_number');

    if (nationalId == null || driverLicense == null || carImage == null) {
      return Response.json({'message': 'جميع الوثائق مطلوبة'}, 422);
    }
    if (carNumber == null || carNumber.toString().isEmpty) {
      return Response.json({'message': 'رقم لوحة المركبة مطلوب'}, 422);
    }

    final nationalIdPath = await nationalId.store(
      path: 'drivers/$userId',
      filename: 'national_id_${DateTime.now().millisecondsSinceEpoch}.${nationalId.filename.split('.').last}',
    );
    final licensePath = await driverLicense.store(
      path: 'drivers/$userId',
      filename: 'license_${DateTime.now().millisecondsSinceEpoch}.${driverLicense.filename.split('.').last}',
    );
    final carImagePath = await carImage.store(
      path: 'drivers/$userId',
      filename: 'car_${DateTime.now().millisecondsSinceEpoch}.${carImage.filename.split('.').last}',
    );

    final existing = await DriverDocument()
        .query()
        .where('user_id', '=', userId)
        .first();

    if (existing != null) {
      await DriverDocument().query().where('id', '=', existing['id']).update({
        'national_id_url': nationalIdPath,
        'driver_license_url': licensePath,
        'car_image_url': carImagePath,
        'car_number': carNumber,
        'status': 'pending',
        'rejection_reason': null,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } else {
      await DriverDocument().query().insert({
        'user_id': userId,
        'national_id_url': nationalIdPath,
        'driver_license_url': licensePath,
        'car_image_url': carImagePath,
        'car_number': carNumber,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    await User().query().where('id', '=', userId).update({
      'role': 'driver',
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({'message': 'تم إرسال الوثائق للمراجعة'});
  }

  /// GET /api/v1/driver/documents
  Future<Response> getMyDocuments(Request request) async {
    final userId = Auth().id();
    final doc = await DriverDocument()
        .query()
        .where('user_id', '=', userId)
        .first();

    if (doc == null) {
      return Response.json({'message': 'لا توجد وثائق'}, 404);
    }

    return Response.json(_formatDoc(doc));
  }

  /// GET /api/v1/driver/documents/pending (admin)
  Future<Response> listPending(Request request) async {
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;
    final docs = await DriverDocument()
        .query()
        .select([
          'driver_documents.*',
          'users.first_name',
          'users.last_name',
          'users.phone',
        ])
        .join('users', 'users.id', '=', 'driver_documents.user_id')
        .where('driver_documents.status', '=', 'pending')
        .orderBy('driver_documents.created_at', 'asc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(docs));
  }

  /// GET /api/v1/driver/documents/all (admin)
  Future<Response> listAll(Request request) async {
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;
    final status = request.query('status');

    var query = DriverDocument()
        .query()
        .select([
          'driver_documents.*',
          'users.first_name',
          'users.last_name',
          'users.phone',
        ])
        .join('users', 'users.id', '=', 'driver_documents.user_id');

    if (status != null && status.isNotEmpty) {
      query = query.where('driver_documents.status', '=', status);
    }

    final docs = await query.orderBy('driver_documents.created_at', 'desc').paginate(perPage: 20, page: page);
    return Response.json(sanitize(docs));
  }

  /// PATCH /api/v1/driver/documents/{id}/approve (admin)
  Future<Response> approve(int id) async {
    final doc = await DriverDocument().query().where('id', '=', id).first();
    if (doc == null) {
      return Response.json({'message': 'الوثيقة غير موجودة'}, 404);
    }

    await DriverDocument().query().where('id', '=', id).update({
      'status': 'approved',
      'reviewed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await User().query().where('id', '=', doc['user_id']).update({
      'is_driver_verified': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({'message': 'تمت الموافقة على السائق'});
  }

  /// PATCH /api/v1/driver/documents/{id}/reject (admin)
  Future<Response> reject(Request request, int id) async {
    final doc = await DriverDocument().query().where('id', '=', id).first();
    if (doc == null) {
      return Response.json({'message': 'الوثيقة غير موجودة'}, 404);
    }

    await DriverDocument().query().where('id', '=', id).update({
      'status': 'rejected',
      'rejection_reason': request.input('reason') ?? '',
      'reviewed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await User().query().where('id', '=', doc['user_id']).update({
      'is_driver_verified': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });

    return Response.json({'message': 'تم رفض الوثائق'});
  }

  Map<String, dynamic> _formatDoc(Map<String, dynamic> doc) {
    return {
      'id': doc['id'],
      'user_id': doc['user_id'],
      'national_id_url': doc['national_id_url'],
      'driver_license_url': doc['driver_license_url'],
      'car_image_url': doc['car_image_url'],
      'car_number': doc['car_number'],
      'status': doc['status'],
      'rejection_reason': doc['rejection_reason'],
      'reviewed_at': doc['reviewed_at']?.toString(),
      'created_at': doc['created_at']?.toString(),
    };
  }
}

final DriverController driverController = DriverController();
