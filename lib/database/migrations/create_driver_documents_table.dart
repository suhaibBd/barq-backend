import 'package:vania/vania.dart';

class CreateDriverDocumentsTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('driver_documents', () {
      id();
      bigInt('user_id', unsigned: true);
      string('national_id_url');
      string('driver_license_url');
      string('car_image_url');
      string('car_number', length: 20);
      string('status', length: 20, defaultValue: 'pending');
      text('rejection_reason', nullable: true);
      timeStamp('reviewed_at', nullable: true);
      timeStamps();
      foreign('user_id', 'users', 'id', constrained: true, onDelete: 'CASCADE');
    });
  }

  @override
  Future<void> down() async {
    super.down();
    await dropIfExists('driver_documents');
  }
}
