import 'dart:io';
import 'package:vania/vania.dart';

class StorageController extends Controller {
  Future<Response> serve(Request request) async {
    final path = request.uri.path.replaceFirst('/api/v1/storage/', '');

    if (path.contains('..') || path.contains('\x00')) {
      return Response.json({'message': 'Forbidden'}, 403);
    }

    final file = File('storage/app/public/$path');
    final canonicalPath = file.resolveSymbolicLinksSync();
    final basePath = Directory('storage/app/public').resolveSymbolicLinksSync();
    if (!canonicalPath.startsWith(basePath)) {
      return Response.json({'message': 'Forbidden'}, 403);
    }

    if (!await file.exists()) {
      return Response.json({'message': 'File not found'}, 404);
    }

    final bytes = await file.readAsBytes();
    final filename = file.uri.pathSegments.last;
    return Response.file(filename, bytes);
  }
}

final StorageController storageController = StorageController();
