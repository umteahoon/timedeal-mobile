import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/deal.dart';
import '../models/reservation.dart';
import '../services/api_client.dart';
import '../utils/app_logger.dart';

/// 예약은 웹 타임딜 주문(현장결제 예약)으로 저장됩니다.
/// 소비자 예약은 웹 주문 내역에, 사장님 예약은 웹 판매자 센터 주문 현황에 그대로 보입니다.
class ReservationProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<Reservation> _reservations = [];
  List<Reservation> _merchantReservations = [];
  Timer? _pollTimer;
  StreamSubscription<AuthState>? _authSub;
  bool _disposed = false;
  String? lastError;

  bool get _signedIn => _supabase.auth.currentSession != null;

  List<Reservation> get all => List.unmodifiable(_reservations);
  List<Reservation> get merchantAll => List.unmodifiable(_merchantReservations);

  ReservationProvider() {
    _load();
    _authSub = _supabase.auth.onAuthStateChange.listen((_) {
      if (!_disposed) _load();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  Future<void> refresh() => _load();

  List<Reservation> _parse(Map<String, dynamic> data) =>
      (data['reservations'] as List<dynamic>? ?? [])
          .map((j) => Reservation.fromJson(j as Map<String, dynamic>))
          .toList();

  Future<void> _load() async {
    if (!_signedIn) {
      _reservations = [];
      _merchantReservations = [];
      if (!_disposed) notifyListeners();
      return;
    }
    try {
      _reservations = _parse(await ApiClient.get('/mobile/reservations'));
    } catch (e, st) {
      AppLogger.error('Failed to load reservations', e, st);
      lastError = e.toString();
    }
    try {
      _merchantReservations = _parse(await ApiClient.get('/mobile/merchant/reservations'));
    } on ApiException catch (e) {
      // 판매자 권한이 없는 계정이면 사장님 예약 목록은 비워 둡니다.
      if (e.status != 401 && e.status != 403) lastError = e.message;
      _merchantReservations = [];
    } catch (e, st) {
      AppLogger.error('Failed to load merchant reservations', e, st);
    }
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  List<Reservation> byStatus(String status) =>
      _reservations.where((r) => r.status == status).toList();

  List<Reservation> merchantByStatus(String status) =>
      _merchantReservations.where((r) => r.status == status).toList();

  bool isReserved(String dealId) =>
      _reservations.any((r) => r.deal.id == dealId && r.status == '진행중');

  Future<bool> reserve(Deal deal, {String paymentMethod = '신용/체크카드'}) async {
    if (!_signedIn) {
      lastError = '로그인이 필요해요';
      return false;
    }
    if (isReserved(deal.id)) return false;
    if (deal.remainingStock <= 0) return false;

    final temp = Reservation(
      id: '_tmp_${DateTime.now().millisecondsSinceEpoch}',
      userId: _supabase.auth.currentUser?.id ?? '',
      deal: deal,
      reservedAt: DateTime.now(),
      depositAmount: deal.discountedPrice,
      paymentMethod: paymentMethod,
    );
    _reservations.insert(0, temp);
    notifyListeners();

    try {
      final data = await ApiClient.post('/mobile/deals/${deal.id}/reserve', {
        'paymentMethod': paymentMethod,
        'idempotencyKey': 'mobile-${temp.userId}-${deal.id}-${temp.reservedAt.millisecondsSinceEpoch}',
      });
      final created = Reservation.fromJson(data['reservation'] as Map<String, dynamic>);
      final idx = _reservations.indexWhere((r) => r.id == temp.id);
      if (idx != -1) _reservations[idx] = created;
      notifyListeners();
      unawaited(_load());
      return true;
    } catch (e, st) {
      AppLogger.error('Failed to reserve deal', e, st);
      lastError = e.toString();
      _reservations.remove(temp);
      notifyListeners();
      return false;
    }
  }

  Future<void> _merchantAction(String id, String action, String status, String paymentStatus) async {
    for (final list in [_merchantReservations, _reservations]) {
      final idx = list.indexWhere((r) => r.id == id);
      if (idx != -1) {
        list[idx].status = status;
        list[idx].paymentStatus = paymentStatus;
      }
    }
    notifyListeners();
    try {
      await ApiClient.post('/mobile/merchant/reservations/$id/status', {'action': action});
    } catch (e, st) {
      AppLogger.error('예약 상태 변경 실패', e, st);
      lastError = e.toString();
    }
    await _load();
  }

  /// 사장님: 픽업 완료 처리
  Future<void> complete(String id) => _merchantAction(id, 'complete', '픽업완료', 'released');

  /// 사장님: 노쇼 처리
  Future<void> markNoShow(String id) => _merchantAction(id, 'no_show', '노쇼', 'captured');

  /// 소비자: 예약 취소(웹 주문 취소와 같아서 재고도 복구됩니다)
  Future<void> cancel(String id) async {
    final idx = _reservations.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _reservations[idx].status = '취소';
      _reservations[idx].paymentStatus = 'cancelled';
      notifyListeners();
    }
    if (id.startsWith('_tmp_')) return;
    try {
      await ApiClient.post('/orders/$id/cancel');
    } catch (e, st) {
      AppLogger.error('예약 취소 실패', e, st);
      lastError = e.toString();
    }
    await _load();
  }
}
