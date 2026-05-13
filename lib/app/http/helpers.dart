import 'package:eloquent/src/contracts/pagination/default_length_aware_paginator.dart';

dynamic sanitize(dynamic value) {
  if (value is DefaultLengthAwarePaginator) {
    return {
      'data': sanitize(value.items()),
      'current_page': value.currentPage(),
      'last_page': value.lastPage(),
      'per_page': value.perPage(),
      'total': value.total(),
    };
  }
  if (value is DateTime) return value.toIso8601String();
  if (value is Map) {
    return value.map((k, v) => MapEntry(k, sanitize(v)));
  }
  if (value is List) return value.map(sanitize).toList();
  return value;
}

Map<String, dynamic> sanitizeRow(Map<String, dynamic> row) {
  return row.map((key, value) => MapEntry(key, sanitize(value)));
}

List<Map<String, dynamic>> sanitizeRows(List<Map<String, dynamic>> rows) {
  return rows.map(sanitizeRow).toList();
}
