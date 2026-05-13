import 'package:vania/vania.dart';

class CreateTripInstancesTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('trip_instances', () {
      id();
      bigInt('recurring_trip_id', unsigned: true, nullable: true);
      date('date');
      string('departure_time', length: 10);
      string('status', length: 20, defaultValue: 'scheduled');
      timeStamp('created_at', nullable: true);
      foreign('recurring_trip_id', 'recurring_trips', 'id', constrained: true, onDelete: 'CASCADE');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('trip_instances');
  }
}
