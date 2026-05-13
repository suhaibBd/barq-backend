import 'package:vania/vania.dart';

class CreateConversationsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTableNotExists('conversations', () {
      id();
      bigInt('user_one_id');
      bigInt('user_two_id');
      bigInt('booking_id', nullable: true);
      timeStamp('created_at', nullable: true);
      timeStamp('updated_at', nullable: true);
      foreign('user_one_id', 'users', 'id');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('conversations');
  }
}
