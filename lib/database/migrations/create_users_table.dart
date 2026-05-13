import 'package:vania/vania.dart';

class CreateUsersTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('users', () {
      id();
      string('phone', length: 20);
      string('first_name', length: 50, nullable: true);
      string('last_name', length: 50, nullable: true);
      string('email', length: 100, nullable: true);
      string('password', nullable: true);
      string('avatar', nullable: true);
      string('role', length: 20, defaultValue: 'passenger');
      tinyInt('is_driver_verified', defaultValue: 0);
      string('rating', length: 10, defaultValue: '5.0');
      integer('total_trips', defaultValue: 0);
      tinyInt('is_active', defaultValue: 1);
      string('firebase_uid', nullable: true);
      string('fcm_token', nullable: true);
      timeStamps();
      softDeletes('deleted_at');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('users');
  }
}
