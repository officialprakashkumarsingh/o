import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  static AdService get instance => _instance;
  
  AdService._internal();

  // AdMob IDs - Replace with your actual ad unit IDs
  static const String _rewardedAdUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/5224354917' // Test ID for rewarded video
      : 'ca-app-pub-3394897715416901/YOUR_REWARDED_AD_ID'; // TODO: Add your production rewarded ad ID

  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;
  Function? _onRewardEarned;
  Function? _onAdDismissed;
  
  // Track if user has watched ad this session
  static const String _adWatchedKey = 'ad_watched_timestamp';
  
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadRewardedAd();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          _setRewardedAdCallbacks();
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Failed to load rewarded ad: ${error.message}');
          _rewardedAd = null;
          _isRewardedAdReady = false;
          // Retry loading after a delay
          Future.delayed(const Duration(seconds: 30), () {
            _loadRewardedAd();
          });
        },
      ),
    );
  }

  void _setRewardedAdCallbacks() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        _onAdDismissed?.call();
        _loadRewardedAd(); // Load next ad
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        _onAdDismissed?.call();
        _loadRewardedAd();
      },
    );
  }

  bool get isRewardedAdReady => _isRewardedAdReady;

  Future<bool> showRewardedAd({
    required Function onRewardEarned,
    Function? onAdDismissed,
  }) async {
    if (!_isRewardedAdReady || _rewardedAd == null) {
      return false;
    }

    _onRewardEarned = onRewardEarned;
    _onAdDismissed = onAdDismissed;

    await _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        // Save timestamp when ad was watched
        final now = DateTime.now().millisecondsSinceEpoch;
        AppService.prefs.setInt(_adWatchedKey, now);
        _onRewardEarned?.call();
      },
    );

    return true;
  }

  // Check if user needs to watch ad (once per app session)
  bool needsToWatchAd() {
    final lastWatched = AppService.prefs.getInt(_adWatchedKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceLastWatch = (now - lastWatched) / (1000 * 60 * 60);
    
    // Require ad watch if more than 1 hour since last watch
    return hoursSinceLastWatch > 1;
  }

  // Check if user has premium features unlocked
  bool hasUnlockedPremiumFeatures() {
    return !needsToWatchAd();
  }

  void dispose() {
    _rewardedAd?.dispose();
  }
}