import 'package:vania/vania.dart';

class CreateAlterUsersLocationTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await MigrationConnection().dbConnection?.execute('''
      ALTER TABLE users
      ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
      ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION
    ''');
  }

  @override
  Future<void> down() async {
    super.down();
    await MigrationConnection().dbConnection?.execute('''
      ALTER TABLE users
      DROP COLUMN IF EXISTS latitude,
      DROP COLUMN IF EXISTS longitude
    ''');
  }
}
