import 'package:vania/vania.dart';

class CreateNotificationsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTableNotExists('notifications', () {
      id();
      bigInt('user_id');
      string('type', length: 50);
      string('title');
      text('body');
      tinyInt('is_read', defaultValue: 0);
      json('data', nullable: true);
      timeStamp('created_at', nullable: true);
      foreign('user_id', 'users', 'id');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('notifications');
  }
}
