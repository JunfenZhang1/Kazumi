import 'package:dio/dio.dart';
import 'package:pinyin/pinyin.dart';

/// Processing is opt-in; upstream subtitle display remains the default.
enum SubtitleProcessingMode {
  original,
  simplified,
  translate;

  static SubtitleProcessingMode fromStorage(int value) =>
      value >= 0 && value < values.length ? values[value] : original;
}

class SubtitleProcessingService {
  SubtitleProcessingService._();

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 8),
    sendTimeout: const Duration(seconds: 5),
  ));

  // A small in-memory cache avoids repeated requests on seeks / replays.
  static final Map<String, String> _cache = {};

  static String toSimplified(String text) =>
      ChineseHelper.convertToSimplifiedChinese(text);

  /// LibreTranslate-compatible endpoint. The user supplies the server URL
  /// and, when required, an API key. Text is sent to that server.
  static Future<String> translateToSimplified({
    required String text,
    required String endpoint,
    required String apiKey,
    CancelToken? cancelToken,
  }) async {
    final url = Uri.tryParse(endpoint.trim());
    if (url == null ||
        (url.scheme != 'https' && url.scheme != 'http') ||
        url.host.isEmpty) {
      throw const FormatException('Invalid translation endpoint');
    }

    final key = '${url.toString()}|$text';
    final cached = _cache[key];
    if (cached != null) return cached;

    final response = await _dio.postUri<Map<String, dynamic>>(
      url,
      data: {
        'q': text,
        'source': 'auto',
        'target': 'zh',
        'format': 'text',
        if (apiKey.isNotEmpty) 'api_key': apiKey,
      },
      options: Options(contentType: Headers.jsonContentType),
      cancelToken: cancelToken,
    );
    final translated = response.data?['translatedText'];
    if (translated is! String || translated.trim().isEmpty) {
      throw const FormatException('Translation response has no text');
    }

    final simplified = toSimplified(translated);
    if (_cache.length >= 400) _cache.remove(_cache.keys.first);
    _cache[key] = simplified;
    return simplified;
  }
}
