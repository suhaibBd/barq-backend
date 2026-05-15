import 'package:vania/vania.dart';
import 'package:barq_backend/app/providers/route_service_provider.dart';
import 'auth.dart';
import 'cors.dart';

Map<String, dynamic> config = {
  'name': env('APP_NAME'),
  'url': env('APP_URL'),
  'timezone': 'Asia/Amman',
  'websocket': false,
  'isolate': false,
  'isolateCount': 4,
  'cors': cors,
  'database': null,
  'auth': authConfig,
  'mail': {
    'driver': env('MAIL_MAILER'),
    'host': env('MAIL_HOST'),
    'port': env('MAIL_PORT'),
    'username': env('MAIL_USERNAME'),
    'password': env('MAIL_PASSWORD'),
    'encryption': env('MAIL_ENCRYPTION'),
    'from_name': env('MAIL_FROM_NAME'),
    'from_address': env('MAIL_FROM_ADDRESS'),
  },
  'providers': <ServiceProvider>[
    RouteServiceProvider(),
  ],
};
