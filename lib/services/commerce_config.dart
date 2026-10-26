import 'package:flutter/foundation.dart';

/// Public store/ad identifiers. AdMob IDs are not secrets; the AdMob app ID
/// itself is set for the manifest in android/gradle.properties (admobAppId).
class CommerceConfig {
  /// Fill in after the AdMob rewarded unit is created (ca-app-pub-…/…).
  static const releaseRewardedUnit = '';

  /// Google's published test unit; debug builds only.
  static const _testRewardedUnit = 'ca-app-pub-3940256099942544/5224354917';

  static String get rewardedUnit =>
      kReleaseMode ? releaseRewardedUnit : _testRewardedUnit;
}
