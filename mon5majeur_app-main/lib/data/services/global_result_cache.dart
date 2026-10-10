import 'dart:collection';

import '../../core/constants/api_constants.dart';
import '../../core/local_db/local_db.dart';

/// In-memory cache of the published Global League nights (Results tab and
/// "Voir l'équipe"). A published night never changes, so its content has no
/// expiry; it lives for the app session and belongs to one account
/// ([bindToCurrentUser] empties everything when the account changes).
///
/// The server addresses a night by `offset` (0 = last published night), and an
/// offset points to another date after each 09:00 publication. So the content
/// is stored by DATE, and a small offset -> date index is kept beside it. The
/// index is dropped as soon as any answer contradicts it; the date shown to the
/// user always comes from the content, never from the index.
class GlobalResultCache {
  GlobalResultCache._();

  static const int maxDaysPerMember = 30;
  static const int maxMembers = 20;

  static String? _userId;
  // Insertion order = least recently used first.
  static final LinkedHashMap<String, _Member> _members = LinkedHashMap();

  /// 'me' for my own team, `m` followed by the auto id for another member ("Voir l'équipe").
  static String memberKey(int? userAutoId) =>
      userAutoId == null ? 'me' : 'm$userAutoId';

  /// Ties the cache to the signed-in account (read from the stored session) and
  /// empties it if the account changed or there is none. Returns the account
  /// id to pass back to [put], or null when signed out.
  static Future<String?> bindToCurrentUser() async {
    final id = await SharedPrefsHelper.getString(AppConstants.userId);
    if (id.isEmpty) {
      clear();
      return null;
    }
    if (_userId != id) {
      _members.clear();
      _userId = id;
    }
    return id;
  }

  /// The night at [offset] for [member], rebuilt in the shape of the server
  /// answer, or null if unknown. The team identity is the latest received.
  static Map<String, dynamic>? page(String member, int offset) {
    final m = _members.remove(member);
    if (m == null) return null;
    _members[member] = m; // most recently used
    final entry = m.index[offset];
    final day = entry == null ? null : m.days[entry.date];
    if (entry == null || day == null || m.identity == null) return null;
    return {
      ...m.identity!,
      'available': true,
      'offset': offset,
      'has_older': entry.hasOlder,
      'has_newer': entry.hasNewer,
      'nba_date': entry.date,
      'total_points': day['total_points'],
      'selection': day['selection'],
    };
  }

  /// Stores an answer for [offset]. Returns true when it contradicted what the
  /// index said (a new night was published): the index is then dropped and the
  /// caller should go back to the latest night.
  ///
  /// Never cached: anything that is not an available night, and a night with an
  /// empty selection (the server can report one for a night that did have a
  /// team). The identity is kept up to date either way.
  static bool put(
    String? userId,
    String member,
    int offset,
    Map<String, dynamic> body,
  ) {
    if (userId == null || _userId != userId) return false;
    final m = _members.remove(member) ?? _Member();
    _members[member] = m;
    while (_members.length > maxMembers) {
      _members.remove(_members.keys.first);
    }

    if (body['available'] == true) {
      m.identity = {
        'team_name': body['team_name'],
        'team_logo': body['team_logo'],
        'jersey_index': body['jersey_index'],
        'is_me': body['is_me'],
      };
    }
    final date = body['nba_date'];
    final selection = body['selection'];
    if (body['available'] != true ||
        date is! String ||
        selection is! List ||
        selection.isEmpty) {
      return false;
    }

    var reset = false;
    final known = m.index[offset];
    final elsewhere = m.index.entries.any(
      (e) => e.key != offset && e.value.date == date,
    );
    if ((known != null && known.date != date) || elsewhere) {
      m.index.clear();
      reset = true;
    }
    m.index[offset] = _IndexEntry(
      date,
      body['has_older'] == true,
      body['has_newer'] == true,
    );
    m.days.remove(date);
    m.days[date] = {
      'total_points': body['total_points'],
      'selection': selection,
    };
    while (m.days.length > maxDaysPerMember) {
      final oldest = m.days.keys.first;
      m.days.remove(oldest);
      m.index.removeWhere((_, e) => e.date == oldest);
    }
    return reset;
  }

  static void clear() {
    _members.clear();
    _userId = null;
  }

  // For tests of the size limits.
  static int get memberCount => _members.length;
  static int daysFor(String member) => _members[member]?.days.length ?? 0;
}

class _Member {
  final LinkedHashMap<String, Map<String, dynamic>> days = LinkedHashMap();
  final Map<int, _IndexEntry> index = {};
  Map<String, dynamic>? identity;
}

class _IndexEntry {
  final String date;
  final bool hasOlder;
  final bool hasNewer;
  const _IndexEntry(this.date, this.hasOlder, this.hasNewer);
}
