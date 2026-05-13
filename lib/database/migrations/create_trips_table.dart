import 'package:vania/vania.dart';

class CreateTripsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('trips', () {
      id();
      bigInt('driver_id', unsigned: true);
      string('from_city', length: 100);
      string('to_city', length: 100);
      string('from_lat', length: 30);
      string('from_lng', length: 30);
      string('to_lat', length: 30);
      string('to_lng', length: 30);
      timeStamp('departure_time');
      decimal('price', precision: 8, scale: 2);
      integer('available_seats');
      integer('total_seats');
      text('notes', nullable: true);
      string('pooling_point_lat', length: 30, nullable: true);
      string('pooling_point_lng', length: 30, nullable: true);
      string('pooling_point_name', length: 200, nullable: true);
      smallInt('pickup_from_home', defaultValue: 0);
      string('status', length: 20, defaultValue: 'active');
      timeStamps();
      foreign('driver_id', 'users', 'id', constrained: true, onDelete: 'CASCADE');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('trips');
  }
}
