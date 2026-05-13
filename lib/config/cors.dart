import 'package:vania/vania.dart';

// PRODUCTION: Replace origin with your actual domains e.g. 'https://dashboard.sahm-app.com'
CORSConfig cors = CORSConfig(
  enabled: true,
  origin: env('CORS_ORIGIN') ?? '*',
  methods: 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
  headers: 'Content-Type,Authorization,Accept,Accept-Language',
  exposeHeaders: <String>[
    'cache-control',
    'content-language',
    'content-type',
    'expires',
    'last-modified',
    'pragma',
  ],
  credentials: true,
  maxAge: 90,
);
