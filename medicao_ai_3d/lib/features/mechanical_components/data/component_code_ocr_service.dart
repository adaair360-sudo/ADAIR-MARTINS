import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ComponentOcrResult {
  const ComponentOcrResult({
    required this.rawText,
    required this.extractedCodeCandidate,
    required this.wasExecutedOnDevice,
    this.errorMessage,
  });

  final String rawText;
  final String extractedCodeCandidate;
  final bool wasExecutedOnDevice;
  final String? errorMessage;
}

class ComponentCodeOcrService {
  ComponentCodeOcrService({this.customExtractor});

  final Future<String> Function(String imagePath)? customExtractor;

  Future<ComponentOcrResult> extractFromImage(String imagePath) async {
    try {
      String rawText;
      if (customExtractor != null) {
        rawText = await customExtractor!(imagePath);
      } else {
        if (!Platform.isAndroid && !Platform.isIOS) {
          return const ComponentOcrResult(
            rawText: '',
            extractedCodeCandidate: '',
            wasExecutedOnDevice: false,
            errorMessage:
                'OCR de gravação em componente via ML Kit está disponível no dispositivo Android.',
          );
        }
        final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
        try {
          final inputImage = InputImage.fromFilePath(imagePath);
          final recognized = await recognizer.processImage(inputImage);
          rawText = recognized.text;
        } finally {
          await recognizer.close();
        }
      }

      final candidate = extractBestReferenceToken(rawText);
      return ComponentOcrResult(
        rawText: rawText,
        extractedCodeCandidate: candidate,
        wasExecutedOnDevice: true,
      );
    } catch (e) {
      return ComponentOcrResult(
        rawText: '',
        extractedCodeCandidate: '',
        wasExecutedOnDevice: false,
        errorMessage: 'Não foi possível executar OCR na foto: $e',
      );
    }
  }

  static String extractBestReferenceToken(String rawText) {
    final upper = rawText.toUpperCase();
    // Look for common mechanical reference patterns: bearings, housings, seals, belts, chains
    final patterns = [
      RegExp(r'\b(UCP|UCF|UCT|UCFL)\s*-?\s*\d{3}\b'),
      RegExp(r'\b(60|62|63|222|302|320)\d{2}(\s*-?\s*(2RS|ZZ|2Z|E|C3))?\b'),
      RegExp(r'\b\d{2,3}\s*[X×]\s*\d{2,3}\s*[X×]\s*\d{1,2}\b'),
      RegExp(r'\b(08B|10B|12B|16B)(-\d)?\b'),
      RegExp(r'\b(SPA|SPB|SPC|HTD)\s*-?\s*\d{1,4}M?\b'),
      RegExp(r'\bROTEX\s*-?\s*\d{2}\b'),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(upper);
      if (m != null) {
        return m.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }
    final words = upper
        .split(RegExp(r'[\s\n\r]+'))
        .where((w) => w.length >= 3 && RegExp(r'\d').hasMatch(w))
        .toList();
    return words.isNotEmpty ? words.first : '';
  }
}
