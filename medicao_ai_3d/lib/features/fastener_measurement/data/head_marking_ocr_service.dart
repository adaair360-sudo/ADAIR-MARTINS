import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../material_id/data/material_analyzer_service.dart';
import '../domain/fastener_classifier.dart';
import '../domain/fastener_models.dart';

typedef RawOcrExtractor = Future<String> Function(String imagePath);

class HeadMarkingOcrService {
  HeadMarkingOcrService({
    this.customExtractor,
    MaterialAnalyzerService? materialAnalyzer,
  }) : _materialAnalyzer = materialAnalyzer ?? MaterialAnalyzerService();

  final RawOcrExtractor? customExtractor;
  final MaterialAnalyzerService _materialAnalyzer;

  Future<StrengthClassificationResult> readHeadMarking(
    String imagePath,
  ) async {
    String rawText = '';
    try {
      if (customExtractor != null) {
        rawText = await customExtractor!(imagePath);
      } else {
        final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
        try {
          final inputImage = InputImage.fromFilePath(imagePath);
          final recognized = await recognizer.processImage(inputImage);
          rawText = recognized.text;
        } finally {
          await recognizer.close();
        }
      }
    } on MissingPluginException {
      return const StrengthClassificationResult(
        spec: null,
        source: StrengthClassSource.indeterminate,
        rawOcrText: null,
        warnings: [
          'Motor OCR ML Kit disponível apenas no dispositivo Android.',
          'Não é possível classificar resistência pela aparência externa; informe a marcação gravada manualmente.',
        ],
      );
    } catch (e) {
      return StrengthClassificationResult(
        spec: null,
        source: StrengthClassSource.indeterminate,
        rawOcrText: null,
        warnings: [
          'Falha ao executar leitura OCR da cabeça: $e',
          'Informe a classe gravada manualmente.',
        ],
      );
    }

    var hasStainlessEvidence = false;
    try {
      final features = await _materialAnalyzer.extractFeatures(imagePath);
      hasStainlessEvidence =
          features.meanSaturation < 42 &&
          features.meanValue >= 120 &&
          features.warmMetalRatio < 0.25;
    } catch (_) {
      hasStainlessEvidence = false;
    }

    return FastenerClassifier.classifyStrengthFromOcr(
      rawText,
      hasStainlessAppearanceEvidence: hasStainlessEvidence,
    );
  }
}
