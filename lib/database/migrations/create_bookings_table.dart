import 'package:vania/vania.dart';

class CreateBookingsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('bookings', () {
      id();
      bigInt('trip_id', unsigned: true);
      bigInt('passenger_id', unsigned: true);
      integer('seats');
      decimal('total_price', precision: 8, scale: 2);
      string('status', length: 20, defaultValue: 'pending');
      timeStamps();
      foreign('trip_id', 'trips', 'id', constrained: true, onDelete: 'CASCADE');
      foreign('passenger_id', 'users', 'id', constrained: true, onDelete: 'CASCADE');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('bookings');
  }
}
