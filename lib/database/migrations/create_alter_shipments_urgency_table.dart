import 'package:vania/vania.dart';

class CreateAlterShipmentsUrgencyTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await MigrationConnection().dbConnection?.execute('''
      ALTER TABLE shipments
        ADD COLUMN IF NOT EXISTS urgency VARCHAR(20) NOT NULL DEFAULT 'normal' AFTER status,
        ADD COLUMN IF NOT EXISTS suggested_price DECIMAL(10,2) NULL AFTER price
    ''');
  }

  @override
  Future<void> down() async {
    super.down();
  }
}
