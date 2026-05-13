import 'package:vania/vania.dart';

class CreateShipmentsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('shipments', () {
      id();
      bigInt('sender_id', unsigned: true);
      bigInt('carrier_id', unsigned: true, nullable: true);
      bigInt('trip_id', unsigned: true, nullable: true);
      string('from_city', length: 100);
      string('to_city', length: 100);
      string('description', length: 500);
      string('size', length: 20);
      decimal('price', precision: 10, scale: 2);
      string('status', length: 20, defaultValue: 'pending');
      text('notes', nullable: true);
      string('receiver_name', length: 100);
      string('receiver_phone', length: 20);
      timeStamps();
      foreign('sender_id', 'users', 'id', constrained: true, onDelete: 'CASCADE');
      foreign('carrier_id', 'users', 'id', constrained: true, onDelete: 'SET NULL');
      foreign('trip_id', 'trips', 'id', constrained: true, onDelete: 'SET NULL');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('shipments');
  }
}
