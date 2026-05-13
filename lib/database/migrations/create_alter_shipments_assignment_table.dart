import 'package:vania/vania.dart';

class CreateAlterShipmentsAssignmentTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await MigrationConnection().dbConnection?.execute('''
      ALTER TABLE shipments
        ADD COLUMN IF NOT EXISTS pickup_lat DECIMAL(10,7) NULL,
        ADD COLUMN IF NOT EXISTS pickup_lng DECIMAL(10,7) NULL,
        ADD COLUMN IF NOT EXISTS assigned_driver_id BIGINT UNSIGNED NULL,
        ADD COLUMN IF NOT EXISTS assignment_expires_at TIMESTAMP NULL,
        ADD COLUMN IF NOT EXISTS assignment_attempts INT NOT NULL DEFAULT 0
    ''');
    await MigrationConnection().dbConnection?.execute('''
      ALTER TABLE shipments
        ADD CONSTRAINT fk_shipments_assigned_driver
        FOREIGN KEY (assigned_driver_id) REFERENCES users(id)
        ON DELETE SET NULL
    ''');
  }

  @override
  Future<void> down() async {
    super.down();
  }
}
