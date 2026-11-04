/// App-wide feature flags.
///
/// Ads are disabled for the initial launch (we are shipping late and will add
/// real ads afterwards). Flip [kAdsEnabled] back to `true` to restore the
/// ad-related shop surfaces (the "watch a rewarded ad → tokens" button and the
/// "Stop-Pub / Remove all ads" card).
const bool kAdsEnabled = false;

/// "Share as a story" (the 9:16 result image), open to every player.
const bool kShareStoryEnabled = true;
