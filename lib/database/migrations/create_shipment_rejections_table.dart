import 'package:vania/vania.dart';

class CreateShipmentRejectionsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('shipment_rejections', () {
      id();
      bigInt('shipment_id', unsigned: true);
      bigInt('driver_id', unsigned: true);
      string('reason', length: 20);
      timeStamp('created_at', nullable: true);
      foreign('shipment_id', 'shipments', 'id',
          constrained: true, onDelete: 'CASCADE');
      foreign('driver_id', 'users', 'id',
          constrained: true, onDelete: 'CASCADE');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('shipment_rejections');
  }
}
