enum MaterialFamily {
  ferrousMetal('Metal ferroso'),
  nonFerrousMetal('Metal não ferroso'),
  thermoplastic('Polímero termoplástico'),
  elastomer('Elastômero'),
  naturalWood('Madeira natural / compósito'),
  glassSilicate('Silicato amorfo (Vidro)'),
  ceramic('Material cerâmico');

  const MaterialFamily(this.label);
  final String label;
}

class IndustrialMaterial {
  const IndustrialMaterial({
    required this.id,
    required this.name,
    required this.family,
    required this.densityGcm3,
    required this.densityRangeNote,
    required this.visualCharacteristics,
    required this.commonApplications,
  });

  final String id;
  final String name;
  final MaterialFamily family;
  final double densityGcm3;
  final String densityRangeNote;
  final String visualCharacteristics;
  final List<String> commonApplications;

  double get densityKgM3 => densityGcm3 * 1000.0;
}

const String materialChemicalDisclaimer =
    'A câmera avalia apenas cor, reflexo e textura superficial. Não é possível afirmar composição química, teor de carbono ou classificação exata de liga (ex.: AISI 1020 vs 1045, 304 vs 316, 6061 vs 7075) apenas por imagem.';

const List<IndustrialMaterial> industrialMaterialsCatalog = [
  IndustrialMaterial(
    id: 'carbon_steel',
    name: 'Aço carbono',
    family: MaterialFamily.ferrousMetal,
    densityGcm3: 7.85,
    densityRangeNote: '7,80 – 7,87 g/cm³ (referência média: 7,85 g/cm³)',
    visualCharacteristics:
        'Cinza metálico médio a escuro; brilho moderado quando usinado ou aspecto oxidado/fosco quando laminado.',
    commonApplications: [
      'Eixos, engrenagens, chapas estruturais e suportes',
      'Parafusos de alta resistência e pinos mecânicos',
      'Estruturas soldadas e componentes de máquinas',
    ],
  ),
  IndustrialMaterial(
    id: 'stainless_steel',
    name: 'Aço inoxidável',
    family: MaterialFamily.ferrousMetal,
    densityGcm3: 7.93,
    densityRangeNote: '7,75 – 8,05 g/cm³ (referência austenítica: 7,93 g/cm³)',
    visualCharacteristics:
        'Prateado claro e limpo, alto reflexo especular em acabamento polido ou linhas finas direcionais quando escovado.',
    commonApplications: [
      'Fixadores A2/A4 resistentes à corrosão',
      'Tubulações, flanges, válvulas e bombas industriais',
      'Equipamentos alimentícios, químicos e farmacêuticos',
    ],
  ),
  IndustrialMaterial(
    id: 'cast_iron',
    name: 'Ferro fundido',
    family: MaterialFamily.ferrousMetal,
    densityGcm3: 7.20,
    densityRangeNote: '6,80 – 7,40 g/cm³ (referência cinzento/nodular: 7,20 g/cm³)',
    visualCharacteristics:
        'Cinza escuro grafite com superfície porosa/granular de fundição e baixo reflexo especular fora das faces usinadas.',
    commonApplications: [
      'Carcaças de mancais, blocos, tampas e bases de máquinas',
      'Polias pesadas, volantes e engrenagens de grande porte',
      'Corpos de bombas e conexões robustas',
    ],
  ),
  IndustrialMaterial(
    id: 'aluminum',
    name: 'Alumínio',
    family: MaterialFamily.nonFerrousMetal,
    densityGcm3: 2.70,
    densityRangeNote: '2,66 – 2,81 g/cm³ (referência comercial: 2,70 g/cm³)',
    visualCharacteristics:
        'Prateado fosco ou acetinado claro, reflexo difuso suave, baixa tonalidade cromática e marcas de extrusão ou usinagem.',
    commonApplications: [
      'Perfis estruturais, carcaças leves e dissipadores térmicos',
      'Polias leves, tampas e suportes automotivos/aeroespaciais',
      'Chapas e blocos usinados CNC',
    ],
  ),
  IndustrialMaterial(
    id: 'copper',
    name: 'Cobre',
    family: MaterialFamily.nonFerrousMetal,
    densityGcm3: 8.96,
    densityRangeNote: '8,90 – 8,96 g/cm³ (referência eletrolítica: 8,96 g/cm³)',
    visualCharacteristics:
        'Coloração avermelhada-alaranjada metálica característica e brilho metálico vivo (ou pátina escura/esverdeada se oxidado).',
    commonApplications: [
      'Barramentos elétricos, terminais e bobinamentos',
      'Trocadores de calor, tubos hidráulicos e anéis de vedação',
      'Juntas esmagáveis e componentes de alta condutividade',
    ],
  ),
  IndustrialMaterial(
    id: 'bronze',
    name: 'Bronze',
    family: MaterialFamily.nonFerrousMetal,
    densityGcm3: 8.80,
    densityRangeNote: '8,40 – 8,90 g/cm³ (referência média: 8,80 g/cm³)',
    visualCharacteristics:
        'Tom dourado-acastanhado mais escuro que o latão, com reflexo metálico quente e textura usinada ou sinterizada.',
    commonApplications: [
      'Buchas autolubrificantes e mancais de deslizamento',
      'Coroas de rosca sem-fim e guias de desgaste',
      'Válvulas marítimas e anéis sincronizadores',
    ],
  ),
  IndustrialMaterial(
    id: 'brass',
    name: 'Latão',
    family: MaterialFamily.nonFerrousMetal,
    densityGcm3: 8.50,
    densityRangeNote: '8,40 – 8,70 g/cm³ (referência média: 8,50 g/cm³)',
    visualCharacteristics:
        'Amarelo dourado brilhante, alto contraste especular em peças torneadas e ausência de porosidade grosseira.',
    commonApplications: [
      'Conexões pneumáticas, niples, registros e bicos',
      'Porcas especiais, terminais e engrenagens leves',
      'Instrumentação e válvulas hidráulicas de baixa/média pressão',
    ],
  ),
  IndustrialMaterial(
    id: 'pvc',
    name: 'PVC',
    family: MaterialFamily.thermoplastic,
    densityGcm3: 1.38,
    densityRangeNote: '1,35 – 1,45 g/cm³ (PVC rígido: 1,38 g/cm³)',
    visualCharacteristics:
        'Superfície polimérica lisa e uniforme (comum em marrom, cinza ou branco industrial) com brilho acetinado baixo.',
    commonApplications: [
      'Tubulações, conexões prediais e industriais de baixa pressão',
      'Eletrodutos, flanges plásticos e dutos químicos',
      'Revestimentos e isolamentos elétricos',
    ],
  ),
  IndustrialMaterial(
    id: 'nylon',
    name: 'Nylon',
    family: MaterialFamily.thermoplastic,
    densityGcm3: 1.14,
    densityRangeNote: '1,12 – 1,16 g/cm³ (Poliamida PA6/PA66: 1,14 g/cm³)',
    visualCharacteristics:
        'Aspecto plástico levemente translúcido ou branco-creme/preto técnico, superfície lisa com baixo atrito visual.',
    commonApplications: [
      'Engrenagens silenciosas, roldanas e buchas leves',
      'Porcas autotravantes (insertos), abraçadeiras e guias',
      'Calços e sapatas resistentes à abrasão',
    ],
  ),
  IndustrialMaterial(
    id: 'polyethylene',
    name: 'Polietileno',
    family: MaterialFamily.thermoplastic,
    densityGcm3: 0.95,
    densityRangeNote: '0,92 – 0,97 g/cm³ (PEAD/UHMW: ~0,95 g/cm³)',
    visualCharacteristics:
        'Acabamento ceroso/acetinado característico, baixa refletividade especular e coloração uniforme (branco, preto, azul ou verde).',
    commonApplications: [
      'Guias de corrente e réguas de desgaste (UHMW)',
      'Tubos PEAD, reservatórios e tampões de proteção',
      'Placas de corte e componentes resistentes a produtos químicos',
    ],
  ),
  IndustrialMaterial(
    id: 'rubber',
    name: 'Borracha',
    family: MaterialFamily.elastomer,
    densityGcm3: 1.15,
    densityRangeNote: '0,95 – 1,35 g/cm³ (NBR/EPDM/Neoprene médio: 1,15 g/cm³)',
    visualCharacteristics:
        'Superfície escura/fosca (tipicamente preta), ausência de reflexos metálicos pontuais e microtextura elastomérica.',
    commonApplications: [
      'Retentores, anéis O-ring, gaxetas e juntas',
      'Correias transportadoras, correias em V e mangueiras',
      'Coxins antivibratórios e elementos elásticos de acoplamentos',
    ],
  ),
  IndustrialMaterial(
    id: 'wood',
    name: 'Madeira',
    family: MaterialFamily.naturalWood,
    densityGcm3: 0.65,
    densityRangeNote: '0,45 – 0,95 g/cm³ conforme espécie (média: 0,65 g/cm³)',
    visualCharacteristics:
        'Tons terrosos/amarelados com veios fibrosos direcionais visíveis, textura orgânica e ausência de brilho metálico.',
    commonApplications: [
      'Calços, berços de apoio, paletes e gabaritos de montagem',
      'Moldes de fundição e proteção de superfícies usinadas',
      'Estruturas auxiliares de oficina',
    ],
  ),
  IndustrialMaterial(
    id: 'glass',
    name: 'Vidro',
    family: MaterialFamily.glassSilicate,
    densityGcm3: 2.50,
    densityRangeNote: '2,45 – 2,58 g/cm³ (soda-cal/borossilicato: ~2,50 g/cm³)',
    visualCharacteristics:
        'Transparência elevada, bordas esverdeadas/vítreas e reflexos especulares nítidos com textura superficial nula.',
    commonApplications: [
      'Visores de nível de óleo, manômetros e janelas de inspeção',
      'Tubos de laboratório e isoladores industriais',
      'Proteções transparentes resistentes ao calor',
    ],
  ),
  IndustrialMaterial(
    id: 'ceramic',
    name: 'Cerâmica',
    family: MaterialFamily.ceramic,
    densityGcm3: 3.20,
    densityRangeNote: '2,30 – 3,95 g/cm³ (porcelana/alumina técnica: ~3,20 g/cm³)',
    visualCharacteristics:
        'Brilho vítreo uniforme em peças esmaltadas ou superfície mineral fosca granular (branca, bege, terracota) sem brilho metálico.',
    commonApplications: [
      'Isoladores elétricos de alta tensão e buchas térmicas',
      'Anéis de selos mecânicos e bicos resistentes à abrasão',
      'Revestimentos refratários e placas isolantes',
    ],
  ),
];

IndustrialMaterial materialById(String id) {
  return industrialMaterialsCatalog.firstWhere((m) => m.id == id);
}
