import 'package:vania/vania.dart';

class CreateAlterSubscriptionsTypesTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await MigrationConnection().dbConnection?.execute('''
      ALTER TABLE subscriptions
        ADD COLUMN IF NOT EXISTS type VARCHAR(10) NOT NULL DEFAULT 'monthly',
        ADD COLUMN IF NOT EXISTS service_fee DECIMAL(8,2) NOT NULL DEFAULT 0.00,
        ADD COLUMN IF NOT EXISTS total_paid DECIMAL(8,2) NOT NULL DEFAULT 0.00,
        ADD COLUMN IF NOT EXISTS billing_start DATE NULL,
        ADD COLUMN IF NOT EXISTS billing_end DATE NULL,
        ADD COLUMN IF NOT EXISTS auto_renew SMALLINT NOT NULL DEFAULT 1,
        ADD COLUMN IF NOT EXISTS renewed_from_id BIGINT NULL
    ''');
  }

  @override
  Future<void> down() async {
    super.down();
  }
}
