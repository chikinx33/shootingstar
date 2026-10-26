import 'package:flutter/foundation.dart';

/// Public store/ad identifiers. AdMob IDs are not secrets; the AdMob app ID
/// itself is set for the manifest in android/gradle.properties (admobAppId).
class CommerceConfig {
  /// AdMob app "Purrtectors: Cat Sky Squad", rewarded unit rewarded_bonus.
  static const releaseRewardedUnit = 'ca-app-pub-1789414876927818/3867676865';

  /// Google's published test unit; debug builds only.
  static const _testRewardedUnit = 'ca-app-pub-3940256099942544/5224354917';

  static String get rewardedUnit =>
      kReleaseMode ? releaseRewardedUnit : _testRewardedUnit;
}
