import 'package:vania/vania.dart';

class CreateAlterUsersReliabilityTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await MigrationConnection().dbConnection?.execute('''
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS reliability_score DECIMAL(5,2) NOT NULL DEFAULT 100.00,
        ADD COLUMN IF NOT EXISTS total_no_shows INT NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS total_cancellations INT NOT NULL DEFAULT 0
    ''');
  }

  @override
  Future<void> down() async {
    super.down();
  }
}
