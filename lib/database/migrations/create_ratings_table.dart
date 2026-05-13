import 'package:vania/vania.dart';

class CreateRatingsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTableNotExists('ratings', () {
      id();
      bigInt('booking_id');
      bigInt('rater_id');
      bigInt('rated_user_id');
      integer('rating');
      text('comment', nullable: true);
      timeStamp('created_at', nullable: true);
      foreign('booking_id', 'bookings', 'id');
      foreign('rater_id', 'users', 'id');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('ratings');
  }
}
