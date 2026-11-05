// lib/data/models/substitution_model.dart
//
// State of the substitute ("remplaçant") as the server sends it, next to a
// lineup, in the Result page, the Live screen and the Global League screens.
// Every field is optional: an older server sends none of them, and a lineup
// without a substitute (every lineup saved before the rule) sends null.

class SubstitutionState {
  /// pending     - the games of the lineup are not all final: nothing decided,
  ///               nothing is shown as replaced (live).
  /// not_entered - nobody eligible was absent: the substitute did not play.
  /// entered     - he came in for [replacedId].
  /// none        - no substitute.
  final String status;
  final String? replacedId;

  const SubstitutionState({required this.status, this.replacedId});

  bool get isEntered => status == 'entered';
  bool get isPending => status == 'pending';
  bool get isNotEntered => status == 'not_entered';

  /// null for a lineup without a substitute or an older server.
  static SubstitutionState? fromJson(dynamic json) {
    if (json is! Map) return null;
    final status = json['status']?.toString();
    if (status == null || status.isEmpty || status == 'none') return null;
    final replaced = json['replaced_id']?.toString();
    return SubstitutionState(
      status: status,
      replacedId: (replaced == null || replaced.isEmpty) ? null : replaced,
    );
  }
}
