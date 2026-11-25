# MEDIÇÃO AI 3D

Aplicativo Android desenvolvido em Flutter para medição assistida, inteligência artificial aplicada à manutenção mecânica industrial, metrologia básica e documentação técnica.

> **Aviso Metrológico:** O MEDIÇÃO AI 3D é uma ferramenta auxiliar de inspeção e manutenção. Não substitui paquímetros, micrômetros, torquímetros ou instrumentos certificados.

## Status Atual — Etapas 1 a 4 Concluídas

- **Etapa 1:** Estrutura Flutter Android (`br.com.medicaoai3d.medicao_ai_3d`), tema industrial, Tela Principal com os 9 módulos e módulo funcional **Configurações** (`shared_preferences`).
- **Etapa 2:** Módulo **Medição por câmera** implementado com permissão explícita, preview ao vivo, OpenCV nativo (`4.12.0`), modo ARCore 3D (`1.57.0`), calibração por objeto conhecido, incerteza e exibição em `mm`, `cm` e `m`.
- **Etapa 3:** Módulo **Identificação de materiais** implementado com extração visual local de cor HSV, brilho especular, microtextura e direcionalidade via OpenCV/Dart para os 14 materiais industriais, exibição de família, características, confiança limitada, densidade de referência, aplicações, correção manual e aviso de não-determinação química.
- **Etapa 4:** Módulo **Medição de parafusos e roscas** implementado com suporte a sextavado, Allen, francês, prisioneiro, flangeado, porcas e arruelas; medição por foto calibrada e entrada manual das 7 dimensões; classificação de rosca ISO, UNC e UNF (grossa/fina, direita/esquerda, incluindo exemplos M6 a M20) e leitura OCR on-device (`google_mlkit_text_recognition`) das marcações de resistência `4.6`, `5.8`, `8.8`, `10.9`, `12.9`, `A2` e `A4`.
- **Etapa 5:** Módulo **Calculadora de torque** implementado com cálculo analítico VDI 2230 / ISO 16047 em N·m, bloqueio de recomendação quando faltarem dados essenciais ou em juntas poliméricas, diferenciação entre torque calculado, do fabricante e de projeto, exibição de fonte técnica, condições e advertências.
- **Etapa 6:** Módulo **Cálculo de peso e volume** implementado com fórmulas reais offline para blocos, cilindros, tubos, chapas, esferas, cones, peças ocas e geometrias irregulares (com dados suficientes), exibição simultânea em `cm³`, `m³` e `L`, e cálculo de peso em gramas (`g`) e quilogramas (`kg`) com densidade editável integrada ao catálogo de materiais.
- **Etapa 7:** Módulo **Desenho técnico 2D e 3D** implementado com bloqueio de cotas inventadas, vistas ortográficas 2D cotadas (`Frontal`, `Superior`, `Lateral`), visualizador 3D paramétrico interativo (rotação por arraste, zoom, vistas rápidas e modo wireframe/sólido), salvamento local offline em JSON e exportação vetorial em PDF técnico com carimbo.
- **Etapa 8:** Módulo **Identificação de componentes mecânicos** implementado para todas as 10 categorias (rolamentos, retentores, engrenagens, eixos, polias, buchas, acoplamentos, correntes, correias e mancais) com pesquisa por código/fabricante, leitura OCR on-device de gravações, identificação dimensional, cálculo auxiliar de módulo de engrenagem e solicitação explícita de dados complementares em casos ambíguos.
- **Etapa 9:** Módulo **Histórico e relatórios** implementado com banco SQLite local (`sqflite`), projetos de manutenção, busca por texto/tipo/projeto, criação, edição e exclusão de registros com fotos e fonte técnica, além de exportação de relatórios técnicos completos em PDF com imagens embutidas.
- **Etapa 10:** Testes finais integrados ponta a ponta (`test/integration_end_to_end_test.dart`) validando os 9 módulos ativos e o fluxo completo entre câmera/calibração, materiais, peso/volume, parafusos/torque, desenho 2D/3D, componentes mecânicos, SQLite e relatórios PDF, além da geração e verificação dos APKs finais (`app-debug.apk` e `app-release.apk`).

## Compilação do APK Final

```bash
cd medicao_ai_3d
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
flutter build apk --release
```

### Build automático e link direto via GitHub Actions

O workflow `.github/workflows/medicao-ai-3d-android-apk.yml` compila automaticamente os APKs (`app-arm64-v8a-release.apk` e `app-release.apk`), valida `flutter analyze` e `flutter test`, gera o QR Code (`apk-download-qr.png`) e publica os arquivos em **Releases** (quando acionado manualmente via **Run workflow** ou por tag `v*`), gerando um link direto `https://.../*.apk` para baixar e instalar no Android.

### Gerar QR Code para um link local (Wi-Fi) ou de hospedagem

```bash
cd medicao_ai_3d
dart run tool/generate_apk_qr.dart "http://<IP-DO-PC>:8000/app-arm64-v8a-release.apk"
```

## Como executar

```bash
cd medicao_ai_3d
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```
