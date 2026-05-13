import 'package:vania/vania.dart';
import '../../../models/wallet.dart';
import '../../../models/transaction.dart';
import '../../helpers.dart';

class WalletController extends Controller {
  /// GET /api/v1/wallet
  Future<Response> getWallet(Request request) async {
    final userId = Auth().id();
    final wallet = await Wallet().query().where('user_id', '=', userId).first();

    if (wallet == null) {
      return Response.json({'balance': 0.00, 'transactions': []});
    }

    return Response.json({
      'id': wallet['id'],
      'balance': (wallet['balance'] as num).toDouble(),
    });
  }

  /// GET /api/v1/wallet/transactions
  Future<Response> transactions(Request request) async {
    final userId = Auth().id();
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final wallet = await Wallet().query().where('user_id', '=', userId).first();
    if (wallet == null) {
      return Response.json({'data': [], 'total': 0});
    }

    final txns = await Transaction()
        .query()
        .where('wallet_id', '=', wallet['id'])
        .orderBy('created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(txns));
  }

  /// POST /api/v1/wallet/topup
  /// NOTE: This endpoint requires payment gateway integration before production.
  /// Currently gated behind APP_DEBUG for development/testing only.
  Future<Response> topup(Request request) async {
    if (Env.get('APP_DEBUG') != 'true') {
      return Response.json(
        {'message': 'بوابة الدفع غير مفعّلة حالياً'},
        503,
      );
    }

    request.validate({
      'amount': 'required|numeric|min:1',
    }, {
      'amount.required': 'المبلغ مطلوب',
      'amount.min': 'الحد الأدنى للشحن 1 د.أ',
    });

    final userId = Auth().id();
    final amount = (request.input('amount') as num).toDouble();

    var wallet = await Wallet().query().where('user_id', '=', userId).first();
    if (wallet == null) {
      final walletId = await Wallet().query().insertGetId({
        'user_id': userId,
        'balance': 0.00,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      wallet = await Wallet().query().where('id', '=', walletId).first();
    }

    final newBalance = (wallet!['balance'] as num).toDouble() + amount;
    await Wallet().query().where('id', '=', wallet['id']).update({
      'balance': newBalance,
      'updated_at': DateTime.now().toIso8601String(),
    });

    await Transaction().query().insert({
      'wallet_id': wallet['id'],
      'type': 'topup',
      'amount': amount,
      'description': 'شحن رصيد',
      'created_at': DateTime.now().toIso8601String(),
    });

    return Response.json({
      'message': 'تم شحن الرصيد بنجاح',
      'balance': newBalance,
    });
  }
  /// GET /admin/transactions
  Future<Response> listAllTransactions(Request request) async {
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final txns = await Transaction()
        .query()
        .select([
          'transactions.*',
          'users.first_name',
          'users.last_name',
        ])
        .join('wallets', 'wallets.id', '=', 'transactions.wallet_id')
        .join('users', 'users.id', '=', 'wallets.user_id')
        .orderBy('transactions.created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(txns));
  }
}

final WalletController walletController = WalletController();
