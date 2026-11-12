import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/subtitle_processing.dart';
import 'package:kazumi/utils/constants.dart';

void main() {
  group('Fork playback speeds', () {
    test('clamps the minimum and maximum', () {
      expect(normalizePlayerSpeed(0.01), 0.1);
      expect(normalizePlayerSpeed(20.0), 16.0);
    });

    test('rounds to 0.1x increments', () {
      expect(normalizePlayerSpeed(1.24), 1.2);
      expect(normalizePlayerSpeed(1.26), 1.3);
      expect(normalizePlayerSpeed(15.99), 16.0);
    });
  });

  test('subtitle text Traditional to Simplified conversion', () {
    expect(SubtitleProcessingService.toSimplified('繁體中文'), '繁体中文');
    expect(SubtitleProcessingService.toSimplified('電腦'), '电脑');
  });

  test('subtitle processing mode defaults to the original', () {
    expect(SubtitleProcessingMode.fromStorage(-1),
        SubtitleProcessingMode.original);
    expect(SubtitleProcessingMode.fromStorage(99),
        SubtitleProcessingMode.original);
  });
}
