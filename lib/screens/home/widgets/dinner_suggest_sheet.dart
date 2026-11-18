import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/models/deal.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../deal_detail/deal_detail_screen.dart';

/// 손님 홈의 "AI 저녁 추천" 창. 문장으로 조건을 적으면 지금 판매 중인 딜에서 최대 3개를 골라 줍니다.
/// 추천은 서버가 실제 목록·재고·마감·예산을 다시 확인한 것만 보여 줍니다.
class DinnerSuggestSheet extends StatefulWidget {
  const DinnerSuggestSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => const DinnerSuggestSheet(),
      );

  @override
  State<DinnerSuggestSheet> createState() => _DinnerSuggestSheetState();
}

class _Pick {
  final Deal deal;
  final String reason;
  _Pick(this.deal, this.reason);
}

class _DinnerSuggestSheetState extends State<DinnerSuggestSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _message;
  List<_Pick> _picks = [];

  static const _examples = ['혼자 먹을 저녁, 만 원 이하', '아침에 먹을 빵', '2인분 반찬 2만 원 이하'];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final query = _ctrl.text.trim();
    if (query.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _message = null;
      _picks = [];
    });
    try {
      final data = await ApiClient.post('/mobile/ai/dinner-suggest', {'query': query});
      final picks = <_Pick>[];
      for (final item in (data['picks'] as List? ?? [])) {
        final map = item as Map<String, dynamic>;
        try {
          picks.add(_Pick(Deal.fromJson(map['deal'] as Map<String, dynamic>), map['reason'] as String? ?? ''));
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _picks = picks;
        _message = data['message'] as String?;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _message = e.status == 401
          ? '로그인하거나 "로그인 없이 체험하기"로 들어오면 쓸 수 있어요.'
          : e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = '추천을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Icon(LucideIcons.sparkles, color: AppColors.primary, size: 20),
            const SizedBox(width: 6),
            const Text('AI 저녁 추천', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          Text('원하는 조건을 문장으로 적으면 지금 판매 중인 딜에서 골라 드려요.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text('생성형 AI(Google Gemini)가 후보를 고르고, 서버가 재고·마감·예산을 다시 확인해요.',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLength: 200,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _ask(),
            decoration: InputDecoration(
              hintText: '예: 혼자 먹을 저녁, 만 원 이하',
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: IconButton(
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(LucideIcons.send, color: AppColors.primary),
                onPressed: _loading ? null : _ask,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _examples
                .map((e) => ActionChip(
                      label: Text(e, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _ctrl.text = e;
                        _ask();
                      },
                    ))
                .toList(),
          ),
          if (_message != null) ...[
            const SizedBox(height: 14),
            Text(_message!, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ],
          if (_picks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: const Text('AI가 추천한 결과', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: ListView(
                shrinkWrap: true,
                children: _picks
                    .map((p) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: p.deal.imageUrl.isEmpty
                                ? Container(width: 52, height: 52, color: Colors.grey[200], child: Icon(LucideIcons.store))
                                : Image.network(p.deal.imageUrl, width: 52, height: 52, fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(width: 52, height: 52, color: Colors.grey[200])),
                          ),
                          title: Text(p.deal.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${p.deal.storeName} · ${Formatters.price(p.deal.discountedPrice)}원\n${p.reason}', style: const TextStyle(fontSize: 12)),
                          isThreeLine: true,
                          trailing: Icon(LucideIcons.chevronRight, size: 18),
                          onTap: () {
                            final nav = Navigator.of(context);
                            nav.pop();
                            nav.push(MaterialPageRoute(builder: (_) => DealDetailScreen(deal: p.deal)));
                          },
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
// [Claude | 2026-11-18] 엘리스 AI 챌린지 PoC — 손님 홈 AI 저녁 추천 창
