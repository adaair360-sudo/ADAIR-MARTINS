import 'package:material_ui/material_ui.dart';

enum AppModuleId {
  cameraMeasurement,
  materialIdentification,
  fastenerMeasurement,
  torqueCalculator,
  weightAndVolume,
  technicalDrawing,
  mechanicalComponents,
  historyAndReports,
  settings,
}

class AppModuleInfo {
  const AppModuleInfo({
    required this.id,
    required this.order,
    required this.title,
    required this.shortLabel,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.stageNumber,
    required this.isImplemented,
    required this.technicalScope,
    required this.safetyNotice,
  });

  final AppModuleId id;
  final int order;
  final String title;
  final String shortLabel;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final int stageNumber;
  final bool isImplemented;
  final List<String> technicalScope;
  final String safetyNotice;

  String get formattedCode => order.toString().padLeft(2, '0');
}

const List<AppModuleInfo> appModules = [
  AppModuleInfo(
    id: AppModuleId.cameraMeasurement,
    order: 1,
    title: 'Medição por câmera',
    shortLabel: 'Câmera',
    subtitle: 'ARCore, OpenCV, calibração visual e incerteza em mm, cm e m.',
    icon: Icons.camera_alt_outlined,
    accentColor: Color(0xFF00BCD4),
    stageNumber: 2,
    isImplemented: true,
    technicalScope: [
      'Captura fotográfica com solicitação explícita de permissão da câmera',
      'Detecção de contornos (OpenCV) e marcação manual de pontos',
      'Medição de comprimento, largura, altura, diâmetro e profundidade (ARCore)',
      'Calibração obrigatória por objeto de dimensão conhecida ou referência visual',
      'Indicação de qualidade da calibração e faixa estimada de incerteza',
    ],
    safetyNotice:
        'Medições sem calibração nunca são apresentadas como medida industrial exata e não substituem paquímetro, micrômetro ou instrumentos certificados.',
  ),
  AppModuleInfo(
    id: AppModuleId.materialIdentification,
    order: 2,
    title: 'Identificação de materiais',
    shortLabel: 'Materiais',
    subtitle: 'Análise visual de metais, polímeros, borracha, vidro e cerâmica.',
    icon: Icons.layers_outlined,
    accentColor: Color(0xFF26A69A),
    stageNumber: 3,
    isImplemented: true,
    technicalScope: [
      'Classificação visual assistida para 14 famílias/materiais industriais',
      'Exibição de nome provável, família, características visuais e confiança',
      'Densidade de referência e aplicações mecânicas comuns',
      'Correção manual do material identificado antes de cálculos derivados',
    ],
    safetyNotice:
        'A análise visual por câmera não determina composição química nem certifica ligas metálicas. Confirme ligas críticas por ensaio ou certificado do fabricante.',
  ),
  AppModuleInfo(
    id: AppModuleId.fastenerMeasurement,
    order: 3,
    title: 'Medição de parafusos e roscas',
    shortLabel: 'Parafusos',
    subtitle: 'Sextavado, Allen, roscas ISO/UNC/UNF e classe de resistência OCR.',
    icon: Icons.hardware_outlined,
    accentColor: Color(0xFFFFB300),
    stageNumber: 4,
    isImplemented: true,
    technicalScope: [
      'Identificação de sextavado, Allen, francês, prisioneiro, flangeado, porcas e arruelas',
      'Medição de diâmetro externo, comprimento, passo, altura da cabeça e entre faces',
      'Classificação de rosca métrica ISO (M6–M20+), UNC/UNF, grossa/fina, direita/esquerda',
      'Leitura OCR de marcações de resistência (4.6, 5.8, 8.8, 10.9, 12.9, A2, A4)',
      'Entrada manual assistida quando a câmera não atingir confiança suficiente',
    ],
    safetyNotice:
        'A classe de resistência nunca é inferida apenas pela aparência externa; exige leitura legível da marcação na cabeça ou especificação técnica.',
  ),
  AppModuleInfo(
    id: AppModuleId.torqueCalculator,
    order: 4,
    title: 'Calculadora de torque',
    shortLabel: 'Torque',
    subtitle: 'Cálculo em N·m com passo, classe, lubrificação e fonte técnica.',
    icon: Icons.build_circle_outlined,
    accentColor: Color(0xFFFF7043),
    stageNumber: 5,
    isImplemented: true,
    technicalScope: [
      'Consideração de diâmetro, passo, classe de resistência e material unido',
      'Fator de atrito por lubrificação, condição de montagem e uso de arruelas',
      'Distinção explícita entre torque calculado, recomendado pelo fabricante e de projeto',
      'Exibição obrigatória da norma/fonte técnica, condições e advertências',
    ],
    safetyNotice:
        'O módulo não inventa limites de torque e bloqueia recomendações quando faltarem parâmetros essenciais da união.',
  ),
  AppModuleInfo(
    id: AppModuleId.weightAndVolume,
    order: 5,
    title: 'Cálculo de peso e volume',
    shortLabel: 'Peso/Vol.',
    subtitle: 'Massa (g, kg) e volume (cm³, m³, L) para peças maciças e ocas.',
    icon: Icons.scale_outlined,
    accentColor: Color(0xFF42A5F5),
    stageNumber: 6,
    isImplemented: true,
    technicalScope: [
      'Fórmulas para blocos, cilindros, tubos, chapas, esferas, cones e peças ocas',
      'Conversão automática de volume em cm³, m³ e litros',
      'Estimativa de peso em gramas e quilogramas com densidade editável',
      'Integração direta com o módulo de identificação de materiais',
    ],
    safetyNotice:
        'Resultados de massa dependem da precisão dimensional e da densidade real da liga ou polímero utilizado.',
  ),
  AppModuleInfo(
    id: AppModuleId.technicalDrawing,
    order: 6,
    title: 'Desenho técnico 2D e 3D',
    shortLabel: 'Desenho 3D',
    subtitle: 'Vistas 2D cotadas, modelo 3D rotacionável e exportação em PDF.',
    icon: Icons.view_in_ar_outlined,
    accentColor: Color(0xFF7E57C2),
    stageNumber: 7,
    isImplemented: true,
    technicalScope: [
      'Geração de desenhos 2D com cotas automáticas a partir de medidas reais',
      'Visualização 3D interativa com rotação para parafusos, eixos, tubos e chapas',
      'Edição, salvamento local e exportação em formato PDF técnico',
    ],
    safetyNotice:
        'Nenhum desenho é gerado com dimensões inventadas: todas as cotas exigem valores medidos ou informados pelo usuário.',
  ),
  AppModuleInfo(
    id: AppModuleId.mechanicalComponents,
    order: 7,
    title: 'Identificação de componentes mecânicos',
    shortLabel: 'Componentes',
    subtitle: 'Rolamentos, retentores, engrenagens, polias, correias e mancais.',
    icon: Icons.precision_manufacturing_outlined,
    accentColor: Color(0xFF29B6F6),
    stageNumber: 8,
    isImplemented: true,
    technicalScope: [
      'Catálogo técnico para rolamentos, retentores, engrenagens, eixos e polias',
      'Suporte a buchas, acoplamentos, correntes, correias e mancais',
      'Pesquisa por código de referência, fabricante e dimensões principais',
      'Solicitação de dados complementares quando a identificação for ambígua',
    ],
    safetyNotice:
        'Quando os dados visuais ou dimensionais forem insuficientes, o sistema solicita medidas adicionais antes de sugerir equivalências.',
  ),
  AppModuleInfo(
    id: AppModuleId.historyAndReports,
    order: 8,
    title: 'Histórico e relatórios',
    shortLabel: 'Histórico',
    subtitle: 'Banco SQLite local, projetos de manutenção e exportação PDF.',
    icon: Icons.folder_copy_outlined,
    accentColor: Color(0xFF66BB6A),
    stageNumber: 9,
    isImplemented: true,
    technicalScope: [
      'Armazenamento local offline em SQLite com fotos, medidas e fontes técnicas',
      'Organização por projetos, busca, edição e exclusão de registros',
      'Geração e exportação de relatórios técnicos completos em PDF',
    ],
    safetyNotice:
        'Todos os registros permanecem armazenados localmente no dispositivo sem envio externo automático.',
  ),
  AppModuleInfo(
    id: AppModuleId.settings,
    order: 9,
    title: 'Configurações',
    shortLabel: 'Config.',
    subtitle: 'Unidades (mm/cm/m), privacidade offline, tema e parâmetros.',
    icon: Icons.tune_outlined,
    accentColor: Color(0xFF90A4AE),
    stageNumber: 1,
    isImplemented: true,
    technicalScope: [
      'Seleção de unidade padrão (milímetros, centímetros ou metros)',
      'Controle de casas decimais e aparência industrial (escuro/claro)',
      'Modo offline estrito e consentimento explícito para envio de imagens à IA',
      'Exibição de avisos metrológicos e restauração de configurações padrão',
    ],
    safetyNotice:
        'Por padrão, o modo offline permanece ativo e nenhuma fotografia é enviada para serviços externos sem autorização explícita.',
  ),
];

AppModuleInfo moduleById(AppModuleId id) {
  return appModules.firstWhere((module) => module.id == id);
}
