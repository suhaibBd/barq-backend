import 'package:vania/vania.dart';

class CreateWalletsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('wallets', () {
      id();
      bigInt('user_id', unsigned: true);
      decimal('balance', precision: 10, scale: 2, defaultValue: '0.00');
      timeStamps();
      foreign('user_id', 'users', 'id', constrained: true, onDelete: 'CASCADE');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('wallets');
  }
}
