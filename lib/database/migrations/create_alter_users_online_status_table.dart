import 'package:vania/vania.dart';

class CreateAlterUsersOnlineStatusTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await MigrationConnection().dbConnection?.execute('''
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS is_online SMALLINT NOT NULL DEFAULT 0
    ''');
  }

  @override
  Future<void> down() async {
    super.down();
  }
}
