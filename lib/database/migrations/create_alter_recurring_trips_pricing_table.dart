import 'package:vania/vania.dart';

class CreateAlterRecurringTripsPricingTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await MigrationConnection().dbConnection?.execute('''
      ALTER TABLE recurring_trips
        ADD COLUMN IF NOT EXISTS weekly_price DECIMAL(8,2) NULL,
        ADD COLUMN IF NOT EXISTS daily_price DECIMAL(8,2) NULL,
        ADD COLUMN IF NOT EXISTS service_fee_percent DECIMAL(4,2) NOT NULL DEFAULT 10.00,
        ADD COLUMN IF NOT EXISTS fee_model VARCHAR(20) NOT NULL DEFAULT 'service_fee'
    ''');
  }

  @override
  Future<void> down() async {
    super.down();
  }
}
