import 'package:prepswipe/services/api_service.dart';

enum CardType { importantTopic, currentAffair, didYouKnow, todayInHistory }

class FeedCard {
  final CardType type;
  final Map<String, dynamic> data;
  FeedCard({required this.type, required this.data});
}

class FeedRepository {
  final ApiService _api = ApiService();

  Future<List<Map<String, dynamic>>> _fetchAllImportantTopics() async {
    const pageSize = 1000;
    final all = <Map<String, dynamic>>[];
    int skip = 0;
    while (true) {
      final res = await _api.getImportantTopics(limit: pageSize, skip: skip);
      final page = List<Map<String, dynamic>>.from((res)['data'] ?? []);
      all.addAll(page);
      if (page.length < pageSize) break;
      skip += pageSize;
    }
    return all;
  }

  Future<List<Map<String, dynamic>>> _fetchAllCurrentAffairs() async {
    const pageSize = 1000;
    final all = <Map<String, dynamic>>[];
    int skip = 0;
    while (true) {
      final res = await _api.getCurrentAffairs(limit: pageSize, skip: skip);
      final page = List<Map<String, dynamic>>.from((res)['data'] ?? []);
      all.addAll(page);
      if (page.length < pageSize) break;
      skip += pageSize;
    }
    return all;
  }

  Future<List<Map<String, dynamic>>> _fetchAllDidYouKnow() async {
    const pageSize = 1000;
    final all = <Map<String, dynamic>>[];
    int skip = 0;
    while (true) {
      final res = await _api.getDidYouKnow(limit: pageSize, skip: skip);
      final page = List<Map<String, dynamic>>.from((res)['data'] ?? []);
      all.addAll(page);
      if (page.length < pageSize) break;
      skip += pageSize;
    }
    return all;
  }

  Future<List<FeedCard>> loadFeed() async {
    try {
      final results = await Future.wait([
        _fetchAllImportantTopics(),
        _fetchAllCurrentAffairs(),
        _fetchAllDidYouKnow(),
        _api.getTodayInPastToday(),
      ]);

      final importantTopics = results[0] as List<Map<String, dynamic>>;
      final currentAffairs = results[1] as List<Map<String, dynamic>>;
      final didYouKnow = results[2] as List<Map<String, dynamic>>;

      final todayRaw = results[3] as Map<String, dynamic>;
      final todayItems =
          List<Map<String, dynamic>>.from(todayRaw['data'] ?? []);

      final Map<String, List<Map<String, dynamic>>> tipBySubject = {};
      for (final item in todayItems) {
        final subject = item['subject'] as String? ?? 'General';
        tipBySubject.putIfAbsent(subject, () => []).add(item);
      }

      final List<Map<String, dynamic>> todayInHistory =
          tipBySubject.entries.map((entry) {
        return {
          'subject': entry.key,
          'date': entry.value.isNotEmpty
              ? (entry.value.first['date'] as String? ?? '')
              : '',
          'events': entry.value,
        };
      }).toList();

      final cards = await _buildCardList(
          importantTopics, currentAffairs, didYouKnow, todayInHistory);

      return cards;
    } catch (e) {
      return [];
    }
  }

  Future<List<FeedCard>> _buildCardList(
    List<Map<String, dynamic>> importantTopics,
    List<Map<String, dynamic>> currentAffairs,
    List<Map<String, dynamic>> didYouKnow,
    List<Map<String, dynamic>> todayInHistory,
  ) async {
    final List<FeedCard> itCards = importantTopics
        .map((d) => FeedCard(type: CardType.importantTopic, data: d))
        .toList();
    final List<FeedCard> caCards = currentAffairs
        .map((d) => FeedCard(type: CardType.currentAffair, data: d))
        .toList();
    final List<FeedCard> dykCards = didYouKnow
        .map((d) => FeedCard(type: CardType.didYouKnow, data: d))
        .toList();
    final List<FeedCard> tipCards = todayInHistory
        .map((d) => FeedCard(type: CardType.todayInHistory, data: d))
        .toList();

    FeedCard? pickFrom(
      List<FeedCard> preferred,
      List<List<FeedCard>> fallbacks,
    ) {
      if (preferred.isNotEmpty) return preferred.removeAt(0);
      for (final fb in fallbacks) {
        if (fb.isNotEmpty) return fb.removeAt(0);
      }
      return null;
    }

    final List<FeedCard> cards = [];

    final it = List<FeedCard>.from(itCards);
    final ca = List<FeedCard>.from(caCards);
    final dyk = List<FeedCard>.from(dykCards);
    final tip = List<FeedCard>.from(tipCards);

    while (it.isNotEmpty || ca.isNotEmpty || dyk.isNotEmpty || tip.isNotEmpty) {
      final c1 = pickFrom(it, [dyk, ca, tip]);
      if (c1 != null) cards.add(c1);

      final c2 = pickFrom(it, [dyk, ca, tip]);
      if (c2 != null) cards.add(c2);

      final c3 = pickFrom(tip, [dyk, ca, it]);
      if (c3 != null) cards.add(c3);

      final c4 = pickFrom(ca, [dyk, it, tip]);
      if (c4 != null) cards.add(c4);

      final c5 = pickFrom(dyk, [it, ca, tip]);
      if (c5 != null) cards.add(c5);
    }

    return cards;
  }
}
