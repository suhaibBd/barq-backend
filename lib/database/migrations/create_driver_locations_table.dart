import 'package:vania/vania.dart';

class CreateDriverLocationsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('driver_locations', () {
      id();
      bigInt('user_id', unsigned: true);
      decimal('latitude', precision: 10, scale: 7);
      decimal('longitude', precision: 10, scale: 7);
      timeStamp('updated_at', nullable: true);
      foreign('user_id', 'users', 'id',
          constrained: true, onDelete: 'CASCADE');
    });
    await MigrationConnection().dbConnection?.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_driver_locations_user_id
        ON driver_locations (user_id)
    ''');
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('driver_locations');
  }
}
