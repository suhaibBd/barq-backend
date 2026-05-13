import 'package:vania/vania.dart';

class CreateTransactionsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('transactions', () {
      id();
      bigInt('wallet_id', unsigned: true);
      string('type', length: 20);
      decimal('amount', precision: 10, scale: 2);
      string('description', nullable: true);
      bigInt('reference_id', unsigned: true, nullable: true);
      string('reference_type', length: 50, nullable: true);
      timeStamp('created_at', nullable: true);
      foreign('wallet_id', 'wallets', 'id', constrained: true, onDelete: 'CASCADE');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('transactions');
  }
}
