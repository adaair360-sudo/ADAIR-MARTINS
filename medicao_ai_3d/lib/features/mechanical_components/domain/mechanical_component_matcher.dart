import 'mechanical_component_models.dart';
import 'mechanical_components_catalog.dart';

class MechanicalComponentMatcher {
  const MechanicalComponentMatcher._();

  static String _normalizeToken(String input) {
    return input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static double? estimateGearModule({
    required double? outerDiameterMm,
    required int? teethCount,
  }) {
    if (outerDiameterMm == null ||
        outerDiameterMm <= 0 ||
        teethCount == null ||
        teethCount < 6) {
      return null;
    }
    return outerDiameterMm / (teethCount + 2);
  }

  static ComponentIdentificationResult identify(
    ComponentQueryInput query, {
    List<MechanicalComponentSpec> catalog = mechanicalComponentsCatalog,
  }) {
    final normalizedRef = _normalizeToken(query.referenceText);
    final hasRef = normalizedRef.length >= 2;
    final rawTokens = query.referenceText
        .toUpperCase()
        .split(RegExp(r'[\s,;:/_-]+'))
        .map(_normalizeToken)
        .where((t) => t.length >= 2)
        .toList();

    final dimensionCount = [
      query.innerDiameterMm,
      query.outerDiameterMm,
      query.widthOrLengthMm,
      query.pitchMm,
      query.mountingSpanMm,
      query.teethCount?.toDouble(),
    ].where((v) => v != null && v > 0).length;

    final estimatedModule = estimateGearModule(
      outerDiameterMm: query.outerDiameterMm,
      teethCount: query.teethCount,
    );

    if (!hasRef && dimensionCount == 0) {
      return ComponentIdentificationResult(
        status: ComponentMatchStatus.needsMoreData,
        candidates: const [],
        requestedAdditionalData: [
          query.category.requiredMeasuresHint,
          'Você também pode digitar ou fotografar o código estampado na peça.',
        ],
        summaryMessage:
            'Nenhum código ou dimensão informada. Forneça medidas ou código de referência para identificar o componente.',
      );
    }

    final filtered = query.category == MechanicalComponentCategory.all
        ? catalog
        : catalog.where((c) => c.category == query.category).toList();

    final matches = <ComponentMatchCandidate>[];
    final tol = query.toleranceMm;

    for (final spec in filtered) {
      var score = 0.0;
      var dimCompatible = true;
      final matchedBy = <String>[];

      if (hasRef) {
        final specRef = _normalizeToken(spec.referenceCode);
        final specName = _normalizeToken(spec.name);
        final specProf = _normalizeToken(spec.profileCode ?? '');
        final mfgHit = spec.manufacturers.any(
          (m) =>
              _normalizeToken(m).contains(normalizedRef) ||
              rawTokens.any((t) => _normalizeToken(m) == t),
        );

        if (specRef == normalizedRef ||
            rawTokens.any((t) => t == specRef)) {
          score += 65;
          matchedBy.add('Código exato (${spec.referenceCode})');
        } else if (specRef.contains(normalizedRef) ||
            normalizedRef.contains(specRef) ||
            rawTokens.any(
              (t) => t.length >= 3 && (specRef.contains(t) || specName.contains(t)),
            )) {
          score += 48;
          matchedBy.add('Referência parcial (${spec.referenceCode})');
        } else if (specProf.isNotEmpty &&
            (specProf.contains(normalizedRef) ||
                rawTokens.any((t) => specProf.contains(t)))) {
          score += 36;
          matchedBy.add('Perfil (${spec.profileCode})');
        } else if (mfgHit) {
          score += 22;
          matchedBy.add('Fabricante de referência');
        } else if (dimensionCount == 0) {
          continue;
        }
      }

      void checkDim(
        double? qVal,
        double? sVal,
        String label,
        double weight,
      ) {
        if (qVal == null || qVal <= 0) return;
        if (sVal == null) {
          dimCompatible = false;
          return;
        }
        final diff = (qVal - sVal).abs();
        if (diff <= tol) {
          score += weight * (1.0 - (diff / (tol + 0.01)) * 0.25);
          matchedBy.add('$label ≈ ${sVal.toStringAsFixed(diff < 0.05 ? 0 : 2)} mm');
        } else {
          dimCompatible = false;
        }
      }

      checkDim(query.innerDiameterMm, spec.innerDiameterMm, 'Furo/Eixo d', 24);
      checkDim(query.outerDiameterMm, spec.outerDiameterMm, 'Ext. D', 24);
      checkDim(query.widthOrLengthMm, spec.widthOrLengthMm, 'Larg./Comp.', 20);
      checkDim(query.pitchMm, spec.pitchMm, 'Passo P', 24);
      checkDim(query.mountingSpanMm, spec.mountingSpanMm, 'Entre furos J', 24);

      if (query.teethCount != null && query.teethCount! > 0) {
        if (spec.teethCount == query.teethCount) {
          score += 24;
          matchedBy.add('Dentes Z = ${spec.teethCount}');
        } else {
          dimCompatible = false;
        }
      }

      if (!dimCompatible) {
        continue;
      }

      if (matchedBy.isNotEmpty) {
        matches.add(
          ComponentMatchCandidate(
            spec: spec,
            score: score.clamp(0, 100),
            matchedBy: matchedBy,
          ),
        );
      }
    }

    matches.sort((a, b) => b.score.compareTo(a.score));

    if (matches.isEmpty) {
      return ComponentIdentificationResult(
        status: ComponentMatchStatus.noMatch,
        candidates: const [],
        requestedAdditionalData: [
          'Verifique a tolerância de medição, o código estampado ou a categoria selecionada.',
          query.category.requiredMeasuresHint,
        ],
        summaryMessage:
            'Nenhum componente do catálogo técnico corresponde exatamente aos dados informados.',
        estimatedGearModuleMm: estimatedModule,
      );
    }

    // Ambiguity & insufficient-data enforcement:
    // If searched only by 1 dimension (without reference code) OR multiple distinct candidates tie closely
    final requested = <String>[];
    final hasExactCode = matches.first.matchedBy.any(
      (m) => m.startsWith('Código exato') || m.startsWith('Referência parcial'),
    );

    if (!hasExactCode && dimensionCount < 2) {
      requested.addAll(_missingMeasuresForAmbiguity(query, matches));
      return ComponentIdentificationResult(
        status: ComponentMatchStatus.needsMoreData,
        candidates: matches.take(5).toList(),
        requestedAdditionalData: requested,
        summaryMessage:
            'Dados insuficientes para definir equivalência segura (${matches.length} candidato(s) preliminares compartilham essa medida). Informe as medidas complementares solicitadas.',
        estimatedGearModuleMm: estimatedModule,
      );
    }

    if (!hasExactCode && matches.length > 1) {
      final topScore = matches.first.score;
      final closeTies = matches
          .where((m) => (topScore - m.score).abs() <= 4.0)
          .toList();
      if (closeTies.length > 1) {
        requested.addAll(_missingMeasuresForAmbiguity(query, closeTies));
        return ComponentIdentificationResult(
          status: ComponentMatchStatus.needsMoreData,
          candidates: closeTies.take(5).toList(),
          requestedAdditionalData: requested,
          summaryMessage:
              'Identificação ambígua entre ${closeTies.length} componentes com dimensões próximas. Confirme os dados complementares antes de definir substituição.',
          estimatedGearModuleMm: estimatedModule,
        );
      }
    }

    return ComponentIdentificationResult(
      status: ComponentMatchStatus.identified,
      candidates: matches.take(6).toList(),
      requestedAdditionalData: const [],
      summaryMessage:
          '${matches.length} componente(s) compatível(is) localizado(s) no catálogo técnico offline.',
      estimatedGearModuleMm: estimatedModule,
    );
  }

  static List<String> _missingMeasuresForAmbiguity(
    ComponentQueryInput query,
    List<ComponentMatchCandidate> matches,
  ) {
    final prompts = <String>[];
    final categories = matches.map((m) => m.spec.category).toSet();

    if (query.innerDiameterMm == null &&
        categories.any(
          (c) =>
              c == MechanicalComponentCategory.bearing ||
              c == MechanicalComponentCategory.oilSeal ||
              c == MechanicalComponentCategory.bushing ||
              c == MechanicalComponentCategory.housing,
        )) {
      prompts.add('Informe o diâmetro interno / do eixo (d em mm).');
    }
    if (query.outerDiameterMm == null &&
        categories.any(
          (c) =>
              c == MechanicalComponentCategory.bearing ||
              c == MechanicalComponentCategory.oilSeal ||
              c == MechanicalComponentCategory.bushing ||
              c == MechanicalComponentCategory.chain,
        )) {
      prompts.add(
        categories.contains(MechanicalComponentCategory.chain)
            ? 'Informe o diâmetro do rolo (d1 em mm) para diferenciar padrão ISO (08B) de ANSI (#40).'
            : 'Informe o diâmetro externo / alojamento (D em mm).',
      );
    }
    if (query.widthOrLengthMm == null &&
        categories.any(
          (c) =>
              c == MechanicalComponentCategory.bearing ||
              c == MechanicalComponentCategory.oilSeal ||
              c == MechanicalComponentCategory.bushing ||
              c == MechanicalComponentCategory.chain,
        )) {
      prompts.add(
        categories.contains(MechanicalComponentCategory.chain)
            ? 'Informe a largura interna entre placas (b1 em mm).'
            : 'Informe a largura / altura / comprimento (B ou H em mm).',
      );
    }
    if (query.mountingSpanMm == null &&
        categories.contains(MechanicalComponentCategory.housing)) {
      prompts.add(
        'Informe a distância entre furos de fixação (J em mm) e o formato da caixa (pedestal UCP vs flange UCF).',
      );
    }
    if (query.referenceText.trim().isEmpty) {
      prompts.add(
        'Se legível na peça, digite ou fotografe o código estampado (ex.: 6205-2RS, UCP 205, 08B-1).',
      );
    }
    if (prompts.isEmpty) {
      prompts.add(query.category.requiredMeasuresHint);
    }
    return prompts;
  }
}
