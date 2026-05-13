import 'package:vania/vania.dart';
import 'package:autostrad_backend/app/http/controllers/auth/auth_controller.dart';
import 'package:autostrad_backend/app/http/controllers/user/user_controller.dart';
import 'package:autostrad_backend/app/http/controllers/driver/driver_controller.dart';
import 'package:autostrad_backend/app/http/controllers/wallet/wallet_controller.dart';
import 'package:autostrad_backend/app/http/controllers/dashboard/dashboard_controller.dart';
import 'package:autostrad_backend/app/http/controllers/rating/rating_controller.dart';
import 'package:autostrad_backend/app/http/controllers/notification/notification_controller.dart';
import 'package:autostrad_backend/app/http/controllers/chat/chat_controller.dart';
import 'package:autostrad_backend/app/http/controllers/storage/storage_controller.dart';
import 'package:autostrad_backend/app/http/controllers/wallet/recharge_card_controller.dart';
import 'package:autostrad_backend/app/http/controllers/shipment/shipment_controller.dart';
import 'package:autostrad_backend/app/http/controllers/driver/driver_location_controller.dart';
import 'package:autostrad_backend/app/http/middleware/authenticate.dart'
    show AuthenticateMiddleware, AdminMiddleware;

class ApiRoute implements Route {
  @override
  void register() {
    Router.basePrefix('api/v1');

    // ── Storage / file serving ──
    Router.get('/storage/drivers/{userId}/{filename}', storageController.serve);
    Router.get('/storage/users/{userId}/{filename}', storageController.serve);

    // ── Public auth routes ──
    Router.post('/auth/send-otp', authController.sendOtp)
        .middleware([Throttle(maxAttempts: 5, duration: Duration(minutes: 1))]);
    Router.post('/auth/verify-otp', authController.verifyOtp);
    Router.post('/auth/firebase-verify', authController.firebaseVerify);
    Router.post('/auth/refresh', authController.refreshToken);
    Router.post('/auth/admin-login', authController.adminDevLogin);

    // ── Authenticated routes ──
    Router.group(() {
      // Auth
      Router.post('/auth/logout', authController.logout);
      Router.post('/auth/fcm-token', authController.registerFcmToken);

      // Profile
      Router.get('/profile', userController.getProfile);
      Router.post('/profile/update', userController.updateProfile);
      Router.post('/profile/avatar', userController.uploadAvatar);
      Router.patch('/profile/toggle-online', userController.toggleOnline);

      // Driver documents
      Router.post('/driver/documents', driverController.submitDocuments);
      Router.get('/driver/documents', driverController.getMyDocuments);

      // Driver location
      Router.post('/driver/location', driverLocationController.updateLocation);
      Router.get('/driver/location', driverLocationController.getLocation);

      // Wallet
      Router.get('/wallet', walletController.getWallet);
      Router.get('/wallet/transactions', walletController.transactions);
      Router.post('/wallet/topup', walletController.topup);
      Router.post('/wallet/recharge', rechargeCardController.recharge);

      // Ratings
      Router.post('/ratings', ratingController.create);
      Router.get('/ratings/my', ratingController.myRatings);
      Router.get('/ratings/user/{id}', ratingController.userRatings);

      // Notifications
      Router.get('/notifications', notificationController.index);
      Router.get('/notifications/unread-count', notificationController.unreadCount);
      Router.patch('/notifications/{id}/read', notificationController.markRead);
      Router.patch('/notifications/read-all', notificationController.markAllRead);

      // Chat / Messaging
      Router.get('/conversations', chatController.conversations);
      Router.post('/conversations', chatController.createConversation);
      Router.get('/conversations/{id}/messages', chatController.messages);
      Router.post('/conversations/{id}/messages', chatController.sendMessage);
      Router.patch('/conversations/{id}/read', chatController.markRead);

      // Shipments
      Router.post('/shipments', shipmentController.create);
      Router.get('/shipments/my', shipmentController.myShipments);
      Router.get('/shipments/available', shipmentController.available);
      Router.get('/shipments/price-estimate', shipmentController.priceEstimate);
      Router.get('/shipments/{id}', shipmentController.getById);
      Router.patch('/shipments/{id}/accept', shipmentController.accept);
      Router.patch('/shipments/{id}/reject', shipmentController.reject);
      Router.patch('/shipments/{id}/status', shipmentController.updateStatus);
      Router.patch('/shipments/{id}/cancel', shipmentController.cancel);
    }, middleware: [AuthenticateMiddleware()]);

    // ── Admin / Dashboard routes ──
    Router.group(() {
      Router.get('/dashboard/stats', dashboardController.stats);
      Router.get('/dashboard/recent-users', dashboardController.recentUsers);
      Router.get('/dashboard/recent-orders', dashboardController.recentOrders);

      Router.get('/users', userController.listUsers);
      Router.get('/users/{id}', userController.getUser);
      Router.patch('/users/{id}/toggle-active', userController.toggleActive);

      Router.get('/drivers/documents/pending', driverController.listPending);
      Router.get('/drivers/documents/all', driverController.listAll);
      Router.patch('/drivers/documents/{id}/approve', driverController.approve);
      Router.patch('/drivers/documents/{id}/reject', driverController.reject);

      Router.get('/ratings', ratingController.listAll);
      Router.get('/transactions', walletController.listAllTransactions);
      Router.get('/notifications', notificationController.listAll);

      // Shipments
      Router.get('/shipments', shipmentController.listAll);

      // Recharge Cards
      Router.get('/recharge-cards', rechargeCardController.index);
      Router.post('/recharge-cards', rechargeCardController.store);
      Router.delete('/recharge-cards/{id}', rechargeCardController.destroy);
    }, prefix: 'admin', middleware: [AuthenticateMiddleware(), AdminMiddleware()]);
  }
}
