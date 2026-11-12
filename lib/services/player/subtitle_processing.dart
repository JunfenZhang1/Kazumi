import 'package:dio/dio.dart';
import 'package:pinyin/pinyin.dart';

/// Processing is opt-in; upstream subtitle display remains the default.
enum SubtitleProcessingMode {
  original,
  simplified,
  translate,
  localAi;

  static SubtitleProcessingMode fromStorage(int value) =>
      value >= 0 && value < values.length ? values[value] : original;
  /// OpenAI-compatible local LLM, including Ollama and LM Studio.
  /// No cloud service is contacted by the app when configured with a
  /// loopback / private-LAN URL. The model server is user-managed.
  static Future<String> translateWithLocalAi({
    required String text,
    required String endpoint,
    required String model,
    CancelToken? cancelToken,
  }) async {
    final url = Uri.tryParse(endpoint.trim());
    if (url == null ||
        (url.scheme != 'http' && url.scheme != 'https') ||
        url.host.isEmpty ||
        model.trim().isEmpty) {
      throw const FormatException('Invalid local AI endpoint or model');
    }
    if (!_isLocalAddress(url.host)) {
      throw const FormatException(
          'Local AI endpoint must be on localhost or a private LAN');
    }
    final key = 'local-ai|${url.toString()}|${model.trim()}|$text';
    final cached = _cache[key];
    if (cached != null) return cached;

    final response = await _dio.postUri<Map<String, dynamic>>(
      url,
      data: {
        'model': model.trim(),
        'stream': false,
        'temperature': 0,
        'messages': [
          {
            'role': 'system',
            'content':
                'You translate video subtitle text into natural, concise Simplified Chinese. '
                'Preserve proper nouns, speaker labels, and line breaks when practical. '
                'Output only the translation, with no explanations or markdown.',
          },
          {'role': 'user', 'content': text},
        ],
      },
      options: Options(contentType: Headers.jsonContentType),
      cancelToken: cancelToken,
    );
    final choices = response.data?['choices'];
    final content = choices is List && choices.isNotEmpty
        ? choices.first['message']?['content']
        : null;
    if (content is! String || content.trim().isEmpty) {
      throw const FormatException('Local AI did not return subtitle text');
    }
    final result = toSimplified(content.trim());
    if (_cache.length >= 400) _cache.remove(_cache.keys.first);
    _cache[key] = result;
    return result;
  }

  static bool _isLocalAddress(String host) {
    if (host == 'localhost' || host.endsWith('.localhost') ||
        host.endsWith('.local')) return true;
    final parts = host.split('.');
    if (parts.length == 4) {
      final ip = parts.map(int.tryParse).toList();
      if (ip.every((part) => part != null && part >= 0 && part <= 255)) {
        final a = ip[0]!, b = ip[1]!;
        return a == 10 || a == 127 ||
            (a == 172 && b >= 16 && b <= 31) ||
            (a == 192 && b == 168);
      }
    }
    return host == '::1' || host.toLowerCase().startsWith('fd') ||
        host.toLowerCase().startsWith('fc');
  }

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
