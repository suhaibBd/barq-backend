import 'package:vania/vania.dart';

class CreateMessagesTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTableNotExists('messages', () {
      id();
      bigInt('conversation_id');
      bigInt('sender_id');
      text('body');
      tinyInt('is_read', defaultValue: 0);
      timeStamp('created_at', nullable: true);
      foreign('conversation_id', 'conversations', 'id');
      foreign('sender_id', 'users', 'id');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('messages');
  }
}
