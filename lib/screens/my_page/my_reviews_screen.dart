// [Antigravity | 2026-08-21] 수정범위: MyReviewsScreen — 내가 쓴 리뷰 전용 풀스크린 (작성 가능한 리뷰 / 작성한 리뷰 2개 탭, 세련된 빈 상태 UI 및 리뷰 관리)
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/models/reservation.dart';
import '../../core/providers/reservation_provider.dart';
import '../../core/services/api_client.dart';
import '../../core/theme/app_colors.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // [Claude | 2026-11-03] 수정범위: 리뷰 작성·작성한 리뷰 목록을 서버(/mobile/reviews)와 연결
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final data = await ApiClient.get('/mobile/reviews');
      if (!mounted) return;
      setState(() => _reviews = List<Map<String, dynamic>>.from(data['reviews'] as List? ?? []));
    } catch (_) {
      // 목록을 못 불러와도 화면은 빈 상태로 보여줍니다.
    }
  }

  Future<void> _openReviewSheet(Reservation res) async {
    int rating = 5;
    final controller = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        bool sending = false;
        String? error;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(res.deal.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(res.deal.storeName, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(5, (i) => IconButton(
                    onPressed: () => setSheet(() => rating = i + 1),
                    icon: Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.primary, size: 32),
                  )),
                ),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(hintText: '상품은 어땠나요? 이웃들에게 솔직한 후기를 남겨주세요.', border: OutlineInputBorder()),
                ),
                if (error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    onPressed: sending
                        ? null
                        : () async {
                            setSheet(() { sending = true; error = null; });
                            try {
                              await ApiClient.post('/mobile/reservations/${res.id}/review', {'rating': rating, 'content': controller.text.trim()});
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setSheet(() { sending = false; error = e.toString(); });
                            }
                          },
                    child: Text(sending ? '등록 중...' : '리뷰 등록', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
    controller.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('리뷰를 등록했어요. 고마워요!'), behavior: SnackBarBehavior.floating));
      await _loadReviews();
      _tabController.animateTo(1);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rp = context.watch<ReservationProvider>();
    final reviewedIds = _reviews.map((r) => r['reservation_id']).toSet();
    final completedPickups = rp.byStatus('픽업완료').where((r) => !reviewedIds.contains(r.id)).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141417) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('내가 쓴 리뷰', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: '작성 가능한 리뷰 (${completedPickups.length})'),
            Tab(text: '작성한 리뷰 (${_reviews.length})'),
          ],
        ),
        // [Claude | 2026-08-21] 수정범위: TabBar dividerColor 추가 — M3 기본 전체폭 구분선(검은 줄) 제거
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 탭 1: 작성 가능한 리뷰
          completedPickups.isEmpty
              ? _buildEmptyState(
                  icon: LucideIcons.edit3,
                  title: '작성 가능한 리뷰가 없어요',
                  subtitle: '타임딜 상품을 픽업 완료한 후\n동네 이웃들에게 솔직한 후기를 남겨보세요!',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: completedPickups.length,
                  itemBuilder: (ctx, i) {
                    final res = completedPickups[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('픽업완료',
                                    style: TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                              ),
                              const SizedBox(width: 8),
                              Text(res.deal.storeName,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(res.deal.title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('${res.formattedPrice}원 · ${res.formattedDate}',
                              style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _openReviewSheet(res),
                              icon: Icon(LucideIcons.star, size: 16),
                              label: const Text('리뷰 작성하기', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

          // 탭 2: 작성한 리뷰
          _reviews.isEmpty
              ? _buildEmptyState(
                  icon: LucideIcons.star,
                  title: '아직 작성한 리뷰가 없어요',
                  subtitle: '동네 타임딜 픽업 후 남겨주신 소중한 리뷰가\n이곳에 모이게 됩니다.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reviews.length,
                  itemBuilder: (ctx, i) {
                    final review = _reviews[i];
                    final rating = (review['rating'] as num?)?.toInt() ?? 0;
                    final date = DateTime.tryParse(review['created_at'] as String? ?? '')?.toLocal();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(review['product_name'] as String? ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Row(children: [
                            ...List.generate(5, (s) => Icon(s < rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: AppColors.primary)),
                            if (date != null) ...[
                              const SizedBox(width: 8),
                              Text('${date.year}.${date.month}.${date.day}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            ],
                          ]),
                          const SizedBox(height: 8),
                          Text(review['content'] as String? ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
