import 'package:flutter/material.dart';

import '../data/profile.dart';
import '../data/shop_ledger.dart';
import '../l10n/app_language.dart';
import 'audio_feedback.dart';
import 'components.dart';
import 'reward_popup.dart';

/// One optional rewarded-ad offer. Hidden where ads can never run (web),
/// greyed out once today's count is used. With the ad pass it pays at once.
class AdOfferButton extends StatelessWidget {
  const AdOfferButton({
    super.key,
    required this.profile,
    required this.offer,
    required this.reward,
    this.runId,
    this.runCredits = 0,
    this.onDone,
  });
  final Profile profile;
  final AdOffer offer;

  /// What the button pays, e.g. "+130 츄르" or "2배".
  final String reward;
  final String? runId;
  final int runCredits;

  /// Called after a successful grant (popups, flights).
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final store = profile.commerce;
    if (store == null || !store.offerVisible(offer)) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: Listenable.merge([profile, store]),
      builder: (context, _) {
        final left = profile.shop.left(offer);
        final pass = store.adPassActive;
        final ready = store.canWatch(
          offer,
          runId: runId,
          runCredits: runCredits,
        );
        return GameActionButton(
          key: ValueKey('ad-offer-${offer.name}'),
          label: message(
            pass ? '광고 패스 · {0} 바로 받기 · 오늘 {1}회 남음' : '광고 보고 {0} · 오늘 {1}회 남음',
            [reward, left],
          ),
          displayLabel: message(pass ? '{0} 바로 받기' : '광고 보고 {0}', [reward]),
          image: 'assets/art/shop_v1/ad.webp',
          onPressed: audible(
            ready
                ? () async {
                    final before = RewardSnapshot(profile);
                    final ok = await store.watch(
                      offer,
                      runId: runId,
                      runCredits: runCredits,
                    );
                    if (!context.mounted) return;
                    if (ok) {
                      showTransactionFeedback(context, profile, before);
                      onDone?.call();
                    } else {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              tr(store.status),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                    }
                  }
                : null,
          ),
        );
      },
    );
  }
}
