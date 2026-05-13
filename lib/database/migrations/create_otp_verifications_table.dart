import 'package:vania/vania.dart';

class CreateOtpVerificationsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('otp_verifications', () {
      id();
      string('phone', length: 20);
      string('code', length: 6);
      string('verification_id', length: 100);
      tinyInt('is_used', defaultValue: 0);
      timeStamp('expires_at');
      timeStamp('created_at', nullable: true);
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('otp_verifications');
  }
}
