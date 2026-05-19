import 'dart:io';
import 'package:vania/vania.dart';
import 'create_users_table.dart';
import 'create_otp_verifications_table.dart';
import 'create_driver_documents_table.dart';
import 'create_trips_table.dart';
import 'create_bookings_table.dart';
import 'create_wallets_table.dart';
import 'create_transactions_table.dart';
import 'create_personal_access_tokens_table.dart';
import 'create_ratings_table.dart';
import 'create_notifications_table.dart';
import 'create_conversations_table.dart';
import 'create_messages_table.dart';
import 'create_trip_requests_table.dart';
import 'create_recurring_trips_table.dart';
import 'create_subscriptions_table.dart';
import 'create_driver_credits_table.dart';
import 'create_credit_transactions_table.dart';
import 'create_trip_instances_table.dart';
import 'create_attendance_table.dart';
import 'create_alter_recurring_trips_pricing_table.dart';
import 'create_alter_subscriptions_types_table.dart';
import 'create_alter_attendance_dual_confirm_table.dart';
import 'create_alter_users_reliability_table.dart';
import 'create_subscription_payments_table.dart';
import 'create_no_show_records_table.dart';
import 'create_recharge_cards_table.dart';
import 'create_shipments_table.dart';
import 'create_alter_shipments_urgency_table.dart';
import 'create_alter_users_online_status_table.dart';
import 'create_driver_locations_table.dart';
import 'create_alter_shipments_assignment_table.dart';
import 'create_shipment_rejections_table.dart';
import 'create_alter_users_location_table.dart';

void main() async {
  Env().load();
  await Migrate().registry();
  await MigrationConnection().closeConnection();
  exit(0);
}

class Migrate {
  registry() async {
    await MigrationConnection().setup();
    await CreateUsersTable().up();
    await CreateOtpVerificationsTable().up();
    await CreateDriverDocumentsTable().up();
    await CreateTripsTable().up();
    await CreateBookingsTable().up();
    await CreateWalletsTable().up();
    await CreateTransactionsTable().up();
    await CreatePersonalAccessTokensTable().up();
    await CreateRatingsTable().up();
    await CreateNotificationsTable().up();
    await CreateConversationsTable().up();
    await CreateMessagesTable().up();
    await CreateTripRequestsTable().up();
    await CreateRecurringTripsTable().up();
    await CreateSubscriptionsTable().up();
    await CreateDriverCreditsTable().up();
    await CreateCreditTransactionsTable().up();
    await CreateTripInstancesTable().up();
    await CreateAttendanceTable().up();
    await CreateAlterRecurringTripsPricingTable().up();
    await CreateAlterSubscriptionsTypesTable().up();
    await CreateAlterAttendanceDualConfirmTable().up();
    await CreateAlterUsersReliabilityTable().up();
    await CreateSubscriptionPaymentsTable().up();
    await CreateNoShowRecordsTable().up();
    await CreateRechargeCardsTable().up();
    await CreateShipmentsTable().up();
    await CreateAlterShipmentsUrgencyTable().up();
    await CreateAlterUsersOnlineStatusTable().up();
    await CreateDriverLocationsTable().up();
    await CreateAlterShipmentsAssignmentTable().up();
    await CreateShipmentRejectionsTable().up();
    await CreateAlterUsersLocationTable().up();
  }
}
