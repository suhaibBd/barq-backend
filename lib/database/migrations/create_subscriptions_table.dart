import 'package:vania/vania.dart';

class CreateSubscriptionsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('subscriptions', () {
      id();
      bigInt('recurring_trip_id', unsigned: true);
      bigInt('passenger_id', unsigned: true);
      date('start_date');
      date('end_date', nullable: true);
      decimal('monthly_price', precision: 8, scale: 2);
      string('payment_method', length: 20, defaultValue: 'cash');
      string('status', length: 20, defaultValue: 'active');
      timeStamps();
      foreign('recurring_trip_id', 'recurring_trips', 'id', constrained: true, onDelete: 'CASCADE');
      foreign('passenger_id', 'users', 'id', constrained: true, onDelete: 'CASCADE');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('subscriptions');
  }
}
