import 'package:vania/vania.dart';

class CreateTripRequestsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('trip_requests', () {
      id();
      bigInt('passenger_id', unsigned: true);
      string('from_city', length: 100);
      string('to_city', length: 100);
      string('from_lat', length: 30);
      string('from_lng', length: 30);
      string('to_lat', length: 30);
      string('to_lng', length: 30);
      timeStamp('requested_time');
      integer('seats_needed', defaultValue: 1);
      tinyInt('is_recurring', defaultValue: 0);
      text('recurring_days', nullable: true);
      string('status', length: 20, defaultValue: 'pending');
      text('notes', nullable: true);
      bigInt('matched_trip_id', unsigned: true, nullable: true);
      timeStamps();
      foreign('passenger_id', 'users', 'id', constrained: true, onDelete: 'CASCADE');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('trip_requests');
  }
}
