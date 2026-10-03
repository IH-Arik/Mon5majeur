import 'package:get/get.dart';

/// The backend answers in English and has no i18n layer; some messages also
/// carry a name or a number. Fixed texts are translated through the normal
/// `.tr` dictionary; the ones with variable parts are recognised here and
/// re-built from a French template (QA 30/09 #8 walkthrough: French users saw
/// English errors). Unknown messages are shown as received.
String localizeServerMessage(String message) {
  final text = message.trim();
  for (final rule in _rules) {
    final m = rule.pattern.firstMatch(text);
    if (m == null) continue;
    final params = <String, String>{
      for (var i = 0; i < rule.params.length; i++)
        rule.params[i]: m.group(i + 1) ?? '',
    };
    return params.isEmpty ? rule.key.tr : rule.key.trParams(params);
  }
  return text.tr;
}

class _Rule {
  final RegExp pattern;
  final String key; // translation key (the English template)
  final List<String> params;
  const _Rule(this.pattern, this.key, [this.params = const []]);
}

final _rules = <_Rule>[
  _Rule(
    RegExp(r'^Insufficient tokens: have (\d+), need (\d+)$'),
    'Insufficient tokens: have @have, need @need',
    ['have', 'need'],
  ),
  _Rule(
    RegExp(r"^(?:Bonus|Token pack) '(.+)' is currently unavailable$"),
    'This item is currently unavailable',
  ),
  _Rule(
    RegExp(r'^Daily video already claimed\. Try again in (\d+)h (\d+)m\.$'),
    'Daily video already claimed. Try again in @h h @m m.',
    ['h', 'm'],
  ),
  _Rule(
    RegExp(r'^Exactly 5 players required — got (\d+)$'),
    'Exactly 5 players required — got @n',
    ['n'],
  ),
  _Rule(
    RegExp(r'^(?:Player )?(.+) is OUT and cannot be selected$'),
    '@name is OUT and cannot be selected',
    ['name'],
  ),
  _Rule(
    RegExp(r'^Player (.+) is listed twice$'),
    '@name is listed twice',
    ['name'],
  ),
  _Rule(
    RegExp(r'^(.+) does not play tonight$'),
    '@name does not play tonight',
    ['name'],
  ),
  _Rule(
    RegExp(r'^League (\d+) not found$'),
    'League not found',
  ),
  _Rule(
    RegExp(r'^No matches for league (\d+) match day (\d+)$'),
    'No matches for this match day',
  ),
  _Rule(
    RegExp(r'^Language must be one of .*$'),
    'Unsupported language',
  ),
];
