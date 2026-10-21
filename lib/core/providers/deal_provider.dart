import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_client.dart';
import '../data/mock_data.dart';
import '../models/deal.dart';
import '../services/device_id.dart';
import '../utils/geo_utils.dart';
import '../utils/app_logger.dart';

class DealProvider extends ChangeNotifier {
  List<Deal> _deals = [];
  Timer? _pollTimer;
  Timer? _expiryTimer;
  bool _disposed = false;
  String? error;

  // GPS를 받기 전에도 거리가 보이도록 기본 동네(성수동) 중심에서 계산해 둡니다.
  double? _lastLat = dealCenter.lat;
  double? _lastLng = dealCenter.lng;

  List<Deal> get deals => List.unmodifiable(_deals);

  DealProvider() {
    _load();
    _expiryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final before = _deals.length;
      _deals.removeWhere((d) => d.isExpired);
      if (_deals.length != before && !_disposed) notifyListeners();
    });
  }

  Future<void> refresh() => _load();

  // 웹 타임딜 서버의 딜(상품+딜)을 모바일 모양으로 받아옵니다. 웹에서 바뀐 내용도 20초마다 반영됩니다.
  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/mobile/deals');
      final list = (data['deals'] as List<dynamic>? ?? []);
      _deals = list.map((j) => Deal.fromJson(j as Map<String, dynamic>)).toList();
      error = null;
    } catch (e, st) {
      AppLogger.error('Failed to load deals from web API', e, st);
      error = e.toString();
    }
    _applyDistancesIfKnown();
    if (_disposed) return;
    notifyListeners();
    _pollTimer ??= Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _disposed = true;
    _expiryTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  List<Deal> byCategory(String category) {
    final active = _deals.where((d) => !d.isClosed).toList();
    return category == '전체'
        ? active
        : active.where((d) => d.storeCategory == category).toList();
  }

  Future<void> cancelDeal(String dealId) async {
    _deals.removeWhere((d) => d.id == dealId);
    notifyListeners();
    try {
      await ApiClient.post('/mobile/merchant/deals/$dealId/close');
    } catch (e, st) {
      AppLogger.error('Failed to cancel deal', e, st);
    }
    await _load();
  }

  /// 사장님 딜 등록: 사진이 있으면 웹 Storage에 올린 뒤 상품+딜을 함께 만듭니다.
  Future<Deal?> createDeal({
    required String title,
    required String description,
    required String category,
    required int originalPrice,
    required int discountedPrice,
    required int stock,
    required int hours,
    List<int>? imageBytes,
    String? imageUrl,
  }) async {
    String? imagePath;
    if (imageBytes != null) {
      final upload = await ApiClient.post('/seller-products/image-upload-url', {
        'fileName': 'deal.jpg',
        'contentType': 'image/jpeg',
        'size': imageBytes.length,
      });
      await ApiClient.putSigned(upload['signedUrl'] as String, imageBytes, 'image/jpeg');
      imagePath = upload['objectPath'] as String;
    }
    final data = await ApiClient.post('/mobile/merchant/deals', {
      'title': title,
      'description': description,
      'category': category,
      'originalPrice': originalPrice,
      'discountedPrice': discountedPrice,
      'stock': stock,
      'hours': hours,
      if (imagePath != null) 'imagePath': imagePath else if (imageUrl != null) 'imageUrl': imageUrl,
    });
    final created = Deal.fromJson(data['deal'] as Map<String, dynamic>);
    _deals.insert(0, created);
    _applyDistancesIfKnown();
    notifyListeners();
    return created;
  }

  void updateDistances(double userLat, double userLng, {String? neighborhood, double? centerLat, double? centerLng}) {
    final refLat = centerLat ?? dealCenter.lat;
    final refLng = centerLng ?? dealCenter.lng;
    final distToCenter = GeoUtils.haversine(userLat, userLng, refLat, refLng);
    if (distToCenter > 50.0) {
      _lastLat = refLat;
      _lastLng = refLng;
    } else {
      _lastLat = userLat;
      _lastLng = userLng;
    }

    _applyDistancesIfKnown();
    notifyListeners();
  }
  // [Antigravity | 2026-08-21] 수정범위: DealProvider — 데모 목(mock) 데이터 전면 제거, Supabase 실시간 백엔드 데이터만 바인딩

  void _applyDistancesIfKnown() {
    if (_lastLat == null || _lastLng == null) return;
    _deals = _deals.map((deal) {
      final (lat, lng) = _coordForDeal(deal);
      return deal.copyWith(
        distanceKm: GeoUtils.haversine(_lastLat!, _lastLng!, lat, lng),
      );
    }).toList();
    _deals.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  }

  (double, double) _coordForDeal(Deal deal) {
    // 실제 가게 위치가 저장돼 있으면 그걸 사용 (웹/앱 공통으로 같은 좌표를 봄)
    if (deal.storeLat != null && deal.storeLng != null) {
      return (deal.storeLat!, deal.storeLng!);
    }
    // 위치가 없는 옛날/mock 딜은 뷰어 위치 기준 가짜 좌표로 대체 표시 (하위호환)
    final baseLat = _lastLat ?? dealCenter.lat;
    final baseLng = _lastLng ?? dealCenter.lng;
    final offset = mockDealOffsets[deal.id];
    if (offset != null) {
      return (baseLat + offset.latOffset, baseLng + offset.lngOffset);
    }
    final hash = deal.id.hashCode;
    final latOffset = ((hash % 100) - 50) * 0.00015;
    final lngOffset = ((hash ~/ 100 % 100) - 50) * 0.00015;
    return (baseLat + latOffset, baseLng + lngOffset);
  }
  // [Claude | 2026-08-21] 수정범위: _coordForDeal() — 저장된 실제 store_lat/store_lng 우선 사용, 없을 때만 기존 가짜 좌표 폴백

  static Deal createFromForm({
    required String id,
    required String title,
    required String description,
    required int originalPrice,
    required int discountedPrice,
    required int stock,
    required int hours,
    required String storeCategory,
    required String iconName,
    required String imageUrl,
    String storeName = '우리 동네 가게',
    double? storeLat,
    double? storeLng,
    String? neighborhood,
  }) {
    final now = DateTime.now();
    return Deal(
      id: id,
      storeId: Supabase.instance.client.auth.currentUser?.id ?? DeviceId.value,
      storeName: storeName,
      storeCategory: storeCategory,
      title: title,
      description: description,
      originalPrice: originalPrice,
      discountedPrice: discountedPrice,
      totalStock: stock,
      remainingStock: stock,
      expiresAt: now.add(Duration(hours: hours)),
      distanceKm: 0.2,
      iconName: iconName,
      imageUrl: imageUrl,
      storeLat: storeLat,
      storeLng: storeLng,
      neighborhood: neighborhood,
    );
  }
  // [Claude | 2026-08-21] 수정범위: createFromForm() storeId — DeviceId.value → Supabase Auth user.id 전환 (Kiro 요청 Auth 전환 작업 #2)
  // [Claude | 2026-08-21] 수정범위: createFromForm() storeLat/storeLng/neighborhood 파라미터 추가 — 딜 등록 시 실제 가게 위치를 DB에 저장 (웹 연동용)
}
