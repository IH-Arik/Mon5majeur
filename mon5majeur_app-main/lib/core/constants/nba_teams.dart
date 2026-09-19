/// All 30 NBA teams, full names, alphabetical (QA 15/09/2026 item 3).
/// Proper nouns — deliberately not translated.
const List<String> kNbaTeams = [
  'Atlanta Hawks',
  'Boston Celtics',
  'Brooklyn Nets',
  'Charlotte Hornets',
  'Chicago Bulls',
  'Cleveland Cavaliers',
  'Dallas Mavericks',
  'Denver Nuggets',
  'Detroit Pistons',
  'Golden State Warriors',
  'Houston Rockets',
  'Indiana Pacers',
  'Los Angeles Clippers',
  'Los Angeles Lakers',
  'Memphis Grizzlies',
  'Miami Heat',
  'Milwaukee Bucks',
  'Minnesota Timberwolves',
  'New Orleans Pelicans',
  'New York Knicks',
  'Oklahoma City Thunder',
  'Orlando Magic',
  'Philadelphia 76ers',
  'Phoenix Suns',
  'Portland Trail Blazers',
  'Sacramento Kings',
  'San Antonio Spurs',
  'Toronto Raptors',
  'Utah Jazz',
  'Washington Wizards',
];

/// Maps whatever an older build stored ("LAKERS", "Lakers", "Boston
/// Celtics") to the canonical full name, or returns [raw] unchanged when it
/// matches nothing.
String canonicalNbaTeam(String raw) {
  final v = raw.trim().toLowerCase();
  if (v.isEmpty) return raw;
  for (final t in kNbaTeams) {
    if (t.toLowerCase() == v) return t;
  }
  for (final t in kNbaTeams) {
    if (t.toLowerCase().endsWith(v) || v.endsWith(t.toLowerCase())) return t;
  }
  return raw;
}
