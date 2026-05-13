import 'package:vania/vania.dart';

class CreateAlterAttendanceDualConfirmTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await MigrationConnection().dbConnection?.execute('''
      ALTER TABLE attendance
        ADD COLUMN IF NOT EXISTS driver_status VARCHAR(20) NOT NULL DEFAULT 'pending',
        ADD COLUMN IF NOT EXISTS rider_status VARCHAR(20) NOT NULL DEFAULT 'pending',
        ADD COLUMN IF NOT EXISTS final_status VARCHAR(20) NOT NULL DEFAULT 'pending',
        ADD COLUMN IF NOT EXISTS is_disputed SMALLINT NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS driver_confirmed_at TIMESTAMP NULL,
        ADD COLUMN IF NOT EXISTS rider_confirmed_at TIMESTAMP NULL,
        ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NULL
    ''');
  }

  @override
  Future<void> down() async {
    super.down();
  }
}
