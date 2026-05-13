import 'package:vania/vania.dart';

class CreateDriverCreditsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('driver_credits', () {
      id();
      bigInt('driver_id', unsigned: true);
      integer('balance', defaultValue: 0);
      integer('total_purchased', defaultValue: 0);
      integer('total_used', defaultValue: 0);
      timeStamps();
      foreign('driver_id', 'users', 'id', constrained: true, onDelete: 'CASCADE');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('driver_credits');
  }
}
