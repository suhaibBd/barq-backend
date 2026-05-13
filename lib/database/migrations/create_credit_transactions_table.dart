import 'package:vania/vania.dart';

class CreateCreditTransactionsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('credit_transactions', () {
      id();
      bigInt('driver_credit_id', unsigned: true);
      string('type', length: 20);
      integer('amount');
      decimal('cost_jod', precision: 8, scale: 2, nullable: true);
      bigInt('trip_instance_id', unsigned: true, nullable: true);
      string('description', length: 200, nullable: true);
      timeStamp('created_at', nullable: true);
      foreign('driver_credit_id', 'driver_credits', 'id', constrained: true, onDelete: 'CASCADE');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('credit_transactions');
  }
}
