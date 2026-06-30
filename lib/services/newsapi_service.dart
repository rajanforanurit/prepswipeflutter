import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prepswipe/models/news.dart';

class NewsApiService {
  static const String apiKey = '886613c33ed641e0b3c40b8ec4688520';
  static const String baseUrl = 'https://newsapi.org/v2';

  static const List<String> categories = [
    'All',
    'Sci & Tech',
    'Defence',
    'Environment',
    'Sports',
    'Social',
    'State',
    'Awards',
  ];

  String _queryForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'sci & tech':
      case 'sci&tech':
      case 'science':
      case 'tech':
        return '(ISRO OR DRDO OR "science and technology" OR "space mission" OR "India technology policy" OR satellite OR semiconductor)';

      case 'defence':
        return '(India defence OR DRDO OR "Indian Army" OR "Indian Navy" OR "Indian Air Force" OR "defence deal" OR "border security" OR military exercise India)';

      case 'environment':
        return '(India environment OR climate policy India OR "Ministry of Environment" OR wildlife conservation India OR pollution India OR "COP summit" OR biodiversity India)';

      case 'sports':
        return '(India sports OR Olympics India OR "Commonwealth Games" OR cricket India OR "Asian Games" OR "sports ministry" OR Khelo India)';

      case 'social':
        return '(India social issues OR "social justice" India OR welfare scheme India OR "women empowerment" India OR education policy India OR health policy India)';

      case 'state':
        return '(state government India OR "state assembly" OR "chief minister" India OR "state scheme" OR "state policy" India)';

      case 'awards':
        return '("Padma Shri" OR "Padma Bhushan" OR "Padma Vibhushan" OR "Bharat Ratna" OR "Nobel Prize" OR "national award" India OR "Sahitya Akademi" OR "Jnanpith")';

      case 'crypto':
        return '(cryptocurrency OR bitcoin OR ethereum OR "crypto regulation")';
      case 'indian stocks':
        return '(Indian stocks OR Sensex OR Nifty OR "Indian shares")';
      case 'indian markets':
        return '("Indian financial markets" OR Sensex OR Nifty)';
      case 'nse':
        return '("National Stock Exchange" OR NSE India)';
      case 'bse':
        return '("Bombay Stock Exchange" OR BSE India)';
      case 'indian commodity':
        return '("Indian commodity market" OR MCX OR "commodity prices India")';
      case 'indian business':
        return '("Indian business" OR "Indian companies" OR "Indian economy")';

      default:
        return '(UPSC OR "civil services" OR "current affairs India" OR "government scheme" OR "Indian polity" OR "national news India")';
    }
  }

  Future<List<NewsModel>> getNewsByCategory(String category) async {
    final query = _queryForCategory(category);
    return _fetchArticles(query: query, category: category);
  }

  Future<List<NewsModel>> getCurrentAffairs({String category = 'All'}) async {
    const base =
        '(UPSC OR "current affairs" OR "government scheme" OR "cabinet approves" OR "ministry of" OR appointment OR committee OR report OR summit OR index OR ranking)';
    final categoryQuery = category.toLowerCase() == 'all'
        ? ''
        : ' AND ${_queryForCategory(category)}';
    return _fetchArticles(
      query: '$base$categoryQuery',
      category: category,
    );
  }

  Future<List<NewsModel>> _fetchArticles({
    required String query,
    required String category,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/everything').replace(queryParameters: {
        'q': query,
        'sortBy': 'publishedAt',
        'language': 'en',
        'pageSize': '30',
        'apiKey': apiKey,
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['articles'] != null) {
          final articles = (data['articles'] as List)
              .where((a) => a['title'] != null && a['title'] != '[Removed]')
              .map((article) {
            final map = Map<String, dynamic>.from(article as Map);
            map['category'] = category;
            map['is_trending'] = false;
            return NewsModel.fromJson(map);
          }).toList();
          return articles;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
