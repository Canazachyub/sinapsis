import 'package:flutter_test/flutter_test.dart';
import 'package:sinapsis/core/constants/image_constants.dart';

void main() {
  group('ImageConstants', () {
    test('occlusionImageWidth is 800', () {
      expect(ImageConstants.occlusionImageWidth, 800.0);
    });

    test('imageCenterPadding is 20', () {
      expect(ImageConstants.imageCenterPadding, 20.0);
    });

    group('calculateHeight', () {
      test('landscape image 1920x1080 gives correct height', () {
        // aspectRatio = 1920/1080 = 1.777...
        final height = ImageConstants.calculateHeight(1920 / 1080);
        expect(height, closeTo(450.0, 1.0));
      });

      test('square image gives equal width height', () {
        final height = ImageConstants.calculateHeight(1.0);
        expect(height, 800.0);
      });

      test('portrait image gives height > width', () {
        // aspectRatio = 1080/1920 = 0.5625
        final height = ImageConstants.calculateHeight(1080 / 1920);
        expect(height, closeTo(1422.2, 1.0));
      });

      test('standard 4:3 image', () {
        final height = ImageConstants.calculateHeight(4 / 3);
        expect(height, closeTo(600.0, 0.1));
      });

      test('FIXED: aspectRatio of 0 returns safe fallback', () {
        expect(ImageConstants.calculateHeight(0), ImageConstants.occlusionImageWidth);
      });

      test('FIXED: negative aspectRatio returns safe fallback', () {
        final height = ImageConstants.calculateHeight(-1.0);
        expect(height, ImageConstants.occlusionImageWidth);
      });

      test('very small aspectRatio gives very large height', () {
        final height = ImageConstants.calculateHeight(0.001);
        expect(height, closeTo(800000.0, 1.0));
      });

      test('very large aspectRatio gives very small height', () {
        final height = ImageConstants.calculateHeight(1000.0);
        expect(height, closeTo(0.8, 0.01));
      });
    });
  });
}
