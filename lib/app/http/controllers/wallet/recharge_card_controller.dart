import 'dart:math';
import 'package:vania/vania.dart';
import '../../../models/recharge_card.dart';
import '../../../models/wallet.dart';
import '../../../models/transaction.dart';
import '../../helpers.dart';

class RechargeCardController extends Controller {
  /// POST /api/v1/wallet/recharge — User redeems a card
  Future<Response> recharge(Request request) async {
    request.validate({
      'code': 'required|string',
    }, {
      'code.required': 'رمز البطاقة مطلوب',
    });

    final userId = Auth().id();
    final code = (request.input('code') as String).trim().toUpperCase();

    // Atomic update: only marks the card if it exists AND is unused
    final affected = await RechargeCard()
        .query()
        .where('code', '=', code)
        .where('is_used', '=', 0)
        .update({
      'is_used': 1,
      'used_by': userId,
      'used_at': DateTime.now().toIso8601String(),
    });

    if (affected == 0) {
      final exists = await RechargeCard()
          .query()
          .where('code', '=', code)
          .first();
      if (exists == null) {
        return Response.json(
          {'message': 'رمز بطاقة الشحن غير صالح'},
          404,
        );
      }
      return Response.json(
        {'message': 'بطاقة الشحن هذه مستخدمة بالفعل'},
        400,
      );
    }

    final card = await RechargeCard()
        .query()
        .where('code', '=', code)
        .first();
    final amount = (card!['amount'] as num).toDouble();

    // Get or create wallet
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
      'type': 'recharge',
      'amount': amount,
      'description': 'بطاقة شحن: $code',
      'created_at': DateTime.now().toIso8601String(),
    });

    return Response.json({
      'message': 'تم شحن الرصيد بنجاح',
      'amount': amount,
      'new_balance': newBalance,
    });
  }

  /// GET /admin/recharge-cards — List all cards
  Future<Response> index(Request request) async {
    final page = int.tryParse(request.query('page') ?? '1') ?? 1;

    final cards = await RechargeCard()
        .query()
        .select([
          'recharge_cards.*',
          'users.first_name',
          'users.last_name',
        ])
        .leftJoin('users', 'users.id', '=', 'recharge_cards.used_by')
        .orderBy('recharge_cards.created_at', 'desc')
        .paginate(perPage: 20, page: page);

    return Response.json(sanitize(cards));
  }

  /// POST /admin/recharge-cards — Create new cards
  Future<Response> store(Request request) async {
    request.validate({
      'amount': 'required|numeric|min:0.5',
      'count': 'required|integer|min:1|max:100',
    }, {
      'amount.required': 'المبلغ مطلوب',
      'amount.min': 'الحد الأدنى 0.5 د.أ',
      'count.required': 'العدد مطلوب',
      'count.max': 'الحد الأقصى 100 بطاقة',
    });

    final amount = (request.input('amount') as num).toDouble();
    final count = (request.input('count') as num).toInt();
    final adminId = Auth().id();

    final created = <Map<String, dynamic>>[];

    for (int i = 0; i < count; i++) {
      final code = _generateCode();
      await RechargeCard().query().insert({
        'code': code,
        'amount': amount,
        'is_used': 0,
        'created_by': adminId,
        'created_at': DateTime.now().toIso8601String(),
      });
      created.add({'code': code, 'amount': amount});
    }

    return Response.json({
      'message': 'تم إنشاء $count بطاقة شحن',
      'cards': created,
    });
  }

  /// DELETE /admin/recharge-cards/{id}
  Future<Response> destroy(Request request, int id) async {
    final card = await RechargeCard().query().where('id', '=', id).first();
    if (card == null) {
      return Response.json({'message': 'البطاقة غير موجودة'}, 404);
    }
    if (card['is_used'] == 1) {
      return Response.json({'message': 'لا يمكن حذف بطاقة مستخدمة'}, 400);
    }

    await RechargeCard().query().where('id', '=', id).delete();
    return Response.json({'message': 'تم حذف البطاقة'});
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final segments = List.generate(3, (_) {
      return List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    });
    return segments.join('-');
  }
}

final RechargeCardController rechargeCardController = RechargeCardController();
