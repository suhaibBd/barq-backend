import 'package:vania/vania.dart';

class CreateSubscriptionPaymentsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('subscription_payments', () {
      id();
      bigInt('subscription_id', unsigned: true);
      bigInt('passenger_id', unsigned: true);
      decimal('amount', precision: 8, scale: 2);
      decimal('service_fee', precision: 8, scale: 2);
      decimal('total', precision: 8, scale: 2);
      string('payment_method', length: 20, defaultValue: 'cash');
      string('status', length: 20, defaultValue: 'pending');
      date('billing_period_start');
      date('billing_period_end');
      date('due_date');
      timeStamp('paid_at', nullable: true);
      timeStamps();
      foreign('subscription_id', 'subscriptions', 'id', constrained: true, onDelete: 'CASCADE');
      foreign('passenger_id', 'users', 'id', constrained: true, onDelete: 'CASCADE');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('subscription_payments');
  }
}
