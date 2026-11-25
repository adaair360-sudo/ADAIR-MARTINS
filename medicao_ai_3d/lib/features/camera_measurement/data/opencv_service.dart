import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../domain/camera_measurement_models.dart';

class OpenCvService {
  static const MethodChannel _channel = MethodChannel(
    'br.com.medicaoai3d/opencv',
  );

  Future<bool> isNativeAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<ContourAnalysisResult> analyzeImage(
    String imagePath, {
    double cannyLow = 55.0,
    double cannyHigh = 155.0,
    double minAreaRatio = 0.008,
  }) async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'analyzeContours',
        {
          'imagePath': imagePath,
          'cannyLow': cannyLow,
          'cannyHigh': cannyHigh,
          'minAreaRatio': minAreaRatio,
        },
      );
      if (raw != null) {
        return _parseNativeResult(raw);
      }
    } on MissingPluginException {
      // Fallback to real pure-Dart pixel analyzer in unit tests / non-Android hosts
    } on PlatformException {
      // Fallback to real pure-Dart pixel analyzer if native OpenCV fails to load
    }

    return analyzeImageInDart(imagePath);
  }

  ContourAnalysisResult _parseNativeResult(Map<String, dynamic> raw) {
    final rawContours = (raw['contours'] as List<dynamic>? ?? const []);
    final rawCircles = (raw['circles'] as List<dynamic>? ?? const []);

    final contours = rawContours.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final pts = (map['boxPoints'] as List<dynamic>? ?? const []).map((p) {
        final pMap = Map<String, dynamic>.from(p as Map);
        return ImagePoint(
          (pMap['x'] as num).toDouble(),
          (pMap['y'] as num).toDouble(),
        );
      }).toList();

      return DetectedContour(
        id: map['id'] as String? ?? 'c',
        majorPx: (map['majorPx'] as num).toDouble(),
        minorPx: (map['minorPx'] as num).toDouble(),
        areaPx2: (map['areaPx2'] as num).toDouble(),
        perimeterPx: (map['perimeterPx'] as num).toDouble(),
        circularity: (map['circularity'] as num).toDouble(),
        vertexCount: (map['vertexCount'] as num).toInt(),
        angleDeg: (map['angleDeg'] as num).toDouble(),
        centerX: (map['centerX'] as num).toDouble(),
        centerY: (map['centerY'] as num).toDouble(),
        shapeHint: map['shapeHint'] as String? ?? 'irregular',
        boxPoints: pts,
      );
    }).toList();

    final circles = rawCircles.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return DetectedCircle(
        centerX: (map['centerX'] as num).toDouble(),
        centerY: (map['centerY'] as num).toDouble(),
        diameterPx: (map['diameterPx'] as num).toDouble(),
      );
    }).toList();

    return ContourAnalysisResult(
      engine: raw['engine'] as String? ?? 'opencv_native',
      imageWidth: (raw['imageWidth'] as num).toInt(),
      imageHeight: (raw['imageHeight'] as num).toInt(),
      overlayPath: raw['overlayPath'] as String?,
      sharpnessVariance: (raw['sharpnessVariance'] as num).toDouble(),
      contrastStdDev: (raw['contrastStdDev'] as num).toDouble(),
      contours: contours,
      circles: circles,
    );
  }

  /// Real pure-Dart Sobel gradient & bounding contour detector used in unit tests
  /// and as a deterministic fallback when native Android OpenCV is unavailable.
  Future<ContourAnalysisResult> analyzeImageInDart(String imagePath) async {
    final bytes = File(imagePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw ArgumentError('Não foi possível decodificar a imagem em $imagePath');
    }

    final originalW = decoded.width;
    final originalH = decoded.height;
    final maxSide = math.max(originalW, originalH);
    final scale = maxSide > 480 ? 480.0 / maxSide : 1.0;
    final work = scale < 1.0
        ? img.copyResize(
            decoded,
            width: math.max(16, (originalW * scale).round()),
            height: math.max(16, (originalH * scale).round()),
          )
        : decoded;

    final w = work.width;
    final h = work.height;
    final gray = List<double>.filled(w * h, 0);
    var sum = 0.0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final px = work.getPixel(x, y);
        final lum = 0.299 * px.r + 0.587 * px.g + 0.114 * px.b;
        gray[y * w + x] = lum;
        sum += lum;
      }
    }

    final mean = sum / (w * h);
    var varianceSum = 0.0;
    for (final v in gray) {
      final d = v - mean;
      varianceSum += d * d;
    }
    final contrastStd = math.sqrt(varianceSum / (w * h));

    var lapSum = 0.0;
    var lapSqSum = 0.0;
    var lapCount = 0;
    var minX = w;
    var minY = h;
    var maxX = -1;
    var maxY = -1;
    var edgePixelCount = 0;

    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final idx = y * w + x;
        final gx =
            -gray[(y - 1) * w + (x - 1)] +
            gray[(y - 1) * w + (x + 1)] -
            2 * gray[y * w + (x - 1)] +
            2 * gray[y * w + (x + 1)] -
            gray[(y + 1) * w + (x - 1)] +
            gray[(y + 1) * w + (x + 1)];
        final gy =
            -gray[(y - 1) * w + (x - 1)] -
            2 * gray[(y - 1) * w + x] -
            gray[(y - 1) * w + (x + 1)] +
            gray[(y + 1) * w + (x - 1)] +
            2 * gray[(y + 1) * w + x] +
            gray[(y + 1) * w + (x + 1)];
        final mag = math.sqrt(gx * gx + gy * gy);
        if (mag > 90) {
          edgePixelCount++;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }

        final lap =
            gray[(y - 1) * w + x] +
            gray[(y + 1) * w + x] +
            gray[y * w + (x - 1)] +
            gray[y * w + (x + 1)] -
            4 * gray[idx];
        lapSum += lap;
        lapSqSum += lap * lap;
        lapCount++;
      }
    }

    final lapMean = lapCount > 0 ? lapSum / lapCount : 0.0;
    final sharpnessVariance = lapCount > 0
        ? math.max(0.0, (lapSqSum / lapCount) - (lapMean * lapMean))
        : 0.0;

    final contours = <DetectedContour>[];
    final invScale = 1.0 / scale;

    if (edgePixelCount > 12 && maxX > minX + 4 && maxY > minY + 4) {
      final bw = (maxX - minX) * invScale;
      final bh = (maxY - minY) * invScale;
      final major = math.max(bw, bh);
      final minor = math.min(bw, bh);
      final boxArea = bw * bh;
      final perimeter = 2 * (bw + bh);
      final ratio = minor / math.max(major, 1.0);
      final shapeHint = ratio > 0.85 ? 'cylindrical' : 'rectangular';

      contours.add(
        DetectedContour(
          id: 'c_1',
          majorPx: major,
          minorPx: minor,
          areaPx2: boxArea,
          perimeterPx: perimeter,
          circularity: (4 * math.pi * boxArea) / (perimeter * perimeter),
          vertexCount: 4,
          angleDeg: 0,
          centerX: ((minX + maxX) / 2.0) * invScale,
          centerY: ((minY + maxY) / 2.0) * invScale,
          shapeHint: shapeHint,
          boxPoints: [
            ImagePoint(minX * invScale, minY * invScale),
            ImagePoint(maxX * invScale, minY * invScale),
            ImagePoint(maxX * invScale, maxY * invScale),
            ImagePoint(minX * invScale, maxY * invScale),
          ],
        ),
      );
    }

    return ContourAnalysisResult(
      engine: 'dart_sobel_fallback',
      imageWidth: originalW,
      imageHeight: originalH,
      overlayPath: null,
      sharpnessVariance: sharpnessVariance,
      contrastStdDev: contrastStd,
      contours: contours,
      circles: const [],
    );
  }
}
