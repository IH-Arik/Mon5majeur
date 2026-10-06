import '../custom_assets/assets.gen.dart';

/// ONE place that turns a saved logo value into an image, used by every
/// screen (QA #9 11.1 / 11.2: each screen had its own partial copy of this
/// switch and fell back to the red devil, so the chosen logo/avatar showed up
/// in some screens only).

/// A league logo (value saved at league creation) or a team avatar (value
/// saved on the profile). Empty/unknown values give the default image.
AssetGenImage logoAsset(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    // League logo pool (league creation).
    case 'league_flaming_ball':
      return Assets.icons.leagueLogoFlamingBall;
    case 'league_cap':
      return Assets.icons.leagueLogoCap;
    case 'league_yeti':
      return Assets.icons.leagueLogoYeti;
    case 'league_lion':
      return Assets.icons.leagueLogoLion;
    case 'league_ball':
      return Assets.icons.leagueLogoBall;
    case 'league_shark':
      return Assets.icons.leagueLogoShark;
    case 'league_snake':
      return Assets.icons.leagueLogoSnake;
    // Team avatars (profile).
    case 'paris_fc':
    case 'logo1':
      return Assets.icons.logo1;
    case 'lakers':
    case 'logo2':
      return Assets.icons.logo2;
    case 'boston_celtics':
    case 'logo3':
      return Assets.icons.logo3;
    case 'chicago_bulls':
    case 'logo4':
      return Assets.icons.logo4;
    case 'atlanta_hawks':
    case 'logo5':
      return Assets.icons.logo5;
    case 'golden_state_warriors':
    case 'logo6':
      return Assets.icons.logo6;
    // Legacy values from before the league logo pool.
    case 'lion':
      return Assets.icons.lion;
    case 'cap':
      return Assets.icons.cap;
    case 'runningball':
      return Assets.icons.runningball;
    default:
      return Assets.icons.logo1;
  }
}

/// The six jerseys, in the order of the jersey picker (index saved on the
/// account).
List<AssetGenImage> get jerseyAssets => [
  Assets.icons.jerseyDevil,
  Assets.icons.jerseyFlower,
  Assets.icons.jerseyUfo,
  Assets.icons.jerseyShark,
  Assets.icons.jerseySnake,
  Assets.icons.jerseyZebra,
];

AssetGenImage jerseyAsset(int? index) {
  final list = jerseyAssets;
  return list[(index != null && index >= 0 && index < list.length) ? index : 0];
}
