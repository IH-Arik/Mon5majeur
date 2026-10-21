import '../models/player.dart';
import 'api_service.dart';

/// The players of the pages that follow the first one, and the URL to resume
/// from: null when every page arrived, else the first page that did not.
class PlayerPagesTail {
  final List<Player> players;
  final String? nextUrl;
  const PlayerPagesTail(this.players, this.nextUrl);
}

/// Requests every remaining page of `/api/players-today/` at once, from the
/// `next` URL of the first page. The pages are returned in page order, up to
/// the first one that failed, so the list is never left with a hole. Null when
/// the page numbers cannot be worked out (the caller then follows `next` page
/// by page).
Future<PlayerPagesTail?> fetchRemainingPlayerPages({
  required ApiClient client,
  required String nextUrl,
  required int total,
  required int firstPageSize,
}) async {
  final uri = Uri.tryParse(nextUrl);
  final firstNo = int.tryParse(uri?.queryParameters['page'] ?? '');
  final size =
      int.tryParse(uri?.queryParameters['size'] ?? '') ?? firstPageSize;
  if (uri == null || firstNo == null || size <= 0) return null;
  final lastNo = (total + size - 1) ~/ size;
  if (lastNo < firstNo) return null;

  final urls = <String>[
    for (var n = firstNo; n <= lastNo; n++)
      uri.replace(queryParameters: {...uri.queryParameters, 'page': '$n'})
          .toString(),
  ];

  Future<List<Player>?> page(String url) async {
    try {
      final response = await client.get(url: url);
      if (response.statusCode != 200 || response.body is! Map) return null;
      final results = (response.body as Map)['results'] as List?;
      if (results == null) return null;
      return results
          .map((json) => Player.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  final pages = await Future.wait(urls.map(page));
  final players = <Player>[];
  for (var i = 0; i < pages.length; i++) {
    final p = pages[i];
    if (p == null) return PlayerPagesTail(players, urls[i]);
    players.addAll(p);
  }
  return PlayerPagesTail(players, null);
}
