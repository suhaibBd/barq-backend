import 'package:vania/vania.dart';

class CreateAttendanceTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('attendance', () {
      id();
      bigInt('trip_instance_id', unsigned: true);
      bigInt('subscription_id', unsigned: true);
      bigInt('passenger_id', unsigned: true);
      string('status', length: 20, defaultValue: 'present');
      string('confirmed_by', length: 20, defaultValue: 'driver');
      timeStamp('created_at', nullable: true);
      foreign('trip_instance_id', 'trip_instances', 'id', constrained: true, onDelete: 'CASCADE');
      foreign('subscription_id', 'subscriptions', 'id', constrained: true, onDelete: 'CASCADE');
      foreign('passenger_id', 'users', 'id', constrained: true, onDelete: 'CASCADE');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('attendance');
  }
}
