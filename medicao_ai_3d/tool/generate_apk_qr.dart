import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

void main(List<String> args) {
  if (args.isEmpty || args.first.trim().isEmpty) {
    stderr.writeln(
      'Uso: dart run tool/generate_apk_qr.dart <URL_DO_APK> [caminho_saida.png]',
    );
    stderr.writeln(
      'Exemplo: dart run tool/generate_apk_qr.dart "http://192.168.0.15:8000/app-arm64-v8a-release.apk"',
    );
    exitCode = 64;
    return;
  }

  final url = args.first.trim();
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    stderr.writeln('URL inválida: informe um endereço http:// ou https://.');
    exitCode = 64;
    return;
  }

  final outPath = args.length > 1 ? args[1].trim() : 'apk_download_qr.png';
  final qrCode = QrCode.fromData(
    data: url,
    errorCorrectLevel: QrErrorCorrectLevel.M,
  );
  final qrImage = QrImage(qrCode);
  final modules = qrImage.moduleCount;

  const scale = 10;
  const quietZone = 4;
  final sizePx = (modules + quietZone * 2) * scale;

  final bitmap = img.Image(width: sizePx, height: sizePx);
  img.fill(bitmap, color: img.ColorRgb8(255, 255, 255));
  final darkColor = img.ColorRgb8(11, 17, 23);

  for (var r = 0; r < modules; r++) {
    for (var c = 0; c < modules; c++) {
      if (qrImage.isDark(r, c)) {
        final x1 = (c + quietZone) * scale;
        final y1 = (r + quietZone) * scale;
        img.fillRect(
          bitmap,
          x1: x1,
          y1: y1,
          x2: x1 + scale - 1,
          y2: y1 + scale - 1,
          color: darkColor,
        );
      }
    }
  }

  final outFile = File(outPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsBytesSync(img.encodePng(bitmap));

  stdout.writeln('QR Code gerado para: $url');
  stdout.writeln('Arquivo PNG salvo em: ${outFile.path}');
  stdout.writeln('');

  // Compact terminal QR using half-blocks
  for (var r = -1; r <= modules; r += 2) {
    final buffer = StringBuffer('  ');
    for (var c = -1; c <= modules; c++) {
      final topDark = r >= 0 && r < modules && c >= 0 && c < modules
          ? qrImage.isDark(r, c)
          : false;
      final botDark = (r + 1) >= 0 && (r + 1) < modules && c >= 0 && c < modules
          ? qrImage.isDark(r + 1, c)
          : false;
      if (topDark && botDark) {
        buffer.write('\u2588');
      } else if (topDark) {
        buffer.write('\u2580');
      } else if (botDark) {
        buffer.write('\u2584');
      } else {
        buffer.write(' ');
      }
    }
    stdout.writeln(buffer.toString());
  }
}
