import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/deal.dart';
import '../services/api_client.dart';
import '../utils/app_logger.dart';

/// 찜은 웹 타임딜 찜 목록(상품 기준)과 같은 데이터를 씁니다.
/// 화면은 딜 ID로 묻기 때문에 Deal.productIdOf로 상품 ID로 바꿔서 확인합니다.
class WishlistProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  Set<String> _likedProductIds = {};
  bool _disposed = false;

  WishlistProvider() {
    _load();
    _supabase.auth.onAuthStateChange.listen((_) {
      if (!_disposed) _load();
    });
  }

  Future<void> _load() async {
    if (_supabase.auth.currentSession == null) {
      _likedProductIds = {};
      if (!_disposed) notifyListeners();
      return;
    }
    try {
      final data = await ApiClient.get('/wishlist/ids');
      _likedProductIds = {for (final id in (data['productIds'] as List<dynamic>? ?? [])) id.toString()};
    } catch (e, st) {
      AppLogger.error('Failed to load wishlist', e, st);
    }
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String _productId(String dealId) => Deal.productIdOf[dealId] ?? dealId;

  bool isLiked(String dealId) => _likedProductIds.contains(_productId(dealId));

  int get count => _likedProductIds.length;

  Future<void> toggle(Deal deal) async {
    final productId = deal.productId.isNotEmpty ? deal.productId : _productId(deal.id);
    final wasLiked = _likedProductIds.contains(productId);
    wasLiked ? _likedProductIds.remove(productId) : _likedProductIds.add(productId);
    notifyListeners();
    if (_supabase.auth.currentSession == null) return;
    try {
      await ApiClient.post('/wishlist/$productId/toggle');
    } catch (e, st) {
      AppLogger.error('찜 토글 실패', e, st);
      wasLiked ? _likedProductIds.add(productId) : _likedProductIds.remove(productId);
      notifyListeners();
    }
  }
}
