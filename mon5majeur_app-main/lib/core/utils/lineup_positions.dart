/// Which slot kinds a position label can fill, and how to draw a lineup by
/// position (QA #9 10.3 / 6.1). Mirrors the backend rule
/// (Mon5majeur-Backend/app/modules/leagues/positions.py): 2 backcourt,
/// 2 wings, 1 center, where hybrid labels (G-F, F-C ...) may fit several.
library;

const _guard = 'B', _wing = 'W', _center = 'C';

/// Court order of the five starters: left wing, center, right wing,
/// left guard, right guard (the Global League layout).
const _courtOrder = [_wing, _center, _wing, _guard, _guard];

Set<String> slotsFor(String? label) {
  const map = {
    'PG': _guard, 'SG': _guard, 'G': _guard,
    'SF': _wing, 'PF': _wing, 'F': _wing,
    'C': _center,
  };
  final kinds = <String>{};
  for (final token in (label ?? '').toUpperCase().trim().split(RegExp(r'[-/ ,]+'))) {
    final kind = map[token];
    if (kind != null) kinds.add(kind);
  }
  return kinds;
}

/// Indexes of [labels] arranged in court order, or null when the five labels
/// cannot form a valid lineup.
List<int>? courtOrder(List<String?> labels) {
  if (labels.length != 5) return null;
  final allowed = [for (final l in labels) slotsFor(l)];
  final used = List<bool>.filled(5, false);
  final result = <int>[];

  bool place(int slot) {
    if (slot == 5) return true;
    for (var i = 0; i < 5; i++) {
      if (used[i] || !allowed[i].contains(_courtOrder[slot])) continue;
      used[i] = true;
      result.add(i);
      if (place(slot + 1)) return true;
      result.removeLast();
      used[i] = false;
    }
    return false;
  }

  return place(0) ? result : null;
}

/// [items] rearranged in court order when a valid arrangement exists,
/// otherwise unchanged.
List<T> inCourtOrder<T>(List<T> items, String? Function(T) position) {
  final order = courtOrder([for (final i in items) position(i)]);
  return order == null ? items : [for (final i in order) items[i]];
}
