import 'package:vania/vania.dart';

class CreateRechargeCardsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('recharge_cards', () {
      id();
      string('code', length: 20);
      decimal('amount', precision: 10, scale: 2);
      tinyInt('is_used', length: 1, defaultValue: 0);
      bigInt('used_by', unsigned: true, nullable: true);
      timeStamp('used_at', nullable: true);
      bigInt('created_by', unsigned: true, nullable: true);
      timeStamp('created_at', nullable: true);
      foreign('used_by', 'users', 'id', constrained: true, onDelete: 'SET NULL');
      foreign('created_by', 'users', 'id', constrained: true, onDelete: 'SET NULL');
      index(ColumnIndex.unique, 'code', ['code']);
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('recharge_cards');
  }
}
