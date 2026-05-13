import 'package:vania/vania.dart';

class CreateNoShowRecordsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('no_show_records', () {
      id();
      bigInt('user_id', unsigned: true);
      bigInt('trip_instance_id', unsigned: true);
      string('type', length: 20);
      string('role', length: 10);
      decimal('penalty_points', precision: 4, scale: 2, defaultValue: '0.00');
      text('reason', nullable: true);
      timeStamp('created_at', nullable: true);
      foreign('user_id', 'users', 'id', constrained: true, onDelete: 'CASCADE');
      foreign('trip_instance_id', 'trip_instances', 'id', constrained: true, onDelete: 'CASCADE');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('no_show_records');
  }
}
