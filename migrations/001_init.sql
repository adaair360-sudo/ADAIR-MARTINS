CREATE TABLE IF NOT EXISTS products (
  barcode TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  brand TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT 'Mercearia',
  unit_size TEXT NOT NULL DEFAULT '',
  image_url TEXT NOT NULL DEFAULT '',
  source TEXT NOT NULL DEFAULT 'catalog',
  is_sample BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS price_reports (
  id SERIAL PRIMARY KEY,
  barcode TEXT NOT NULL REFERENCES products(barcode) ON DELETE CASCADE,
  store_name TEXT NOT NULL,
  store_city TEXT NOT NULL DEFAULT 'São Paulo, SP',
  price_cents INTEGER NOT NULL CHECK (price_cents > 0 AND price_cents < 100000000),
  is_promo BOOLEAN NOT NULL DEFAULT false,
  promo_label TEXT NOT NULL DEFAULT '',
  source_type TEXT NOT NULL DEFAULT 'user',
  reported_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_price_reports_barcode_reported_at
  ON price_reports (barcode, reported_at DESC);

INSERT INTO products (barcode, name, brand, category, unit_size, image_url, source, is_sample)
VALUES
  ('7896006711117', 'Arroz Branco Tipo 1 Tio João', 'Tio João', 'Grãos e Cereais', '5 kg', '', 'catalog', true),
  ('7896006744115', 'Feijão Carioca Tipo 1 Camil', 'Camil', 'Grãos e Cereais', '1 kg', '', 'catalog', true),
  ('7891000100103', 'Leite Condensado Moça Integral', 'Nestlé', 'Laticínios e Doces', '395 g', '', 'catalog', true),
  ('7891000053508', 'Achocolatado em Pó Nescau 2.0', 'Nestlé', 'Matinais', '370 g', '', 'catalog', true),
  ('7894900011517', 'Refrigerante Coca-Cola Original', 'Coca-Cola', 'Bebidas', '2 L', '', 'catalog', true),
  ('7896089012347', 'Café Torrado e Moído Pilão Tradicional', 'Pilão', 'Café e Chás', '500 g', '', 'catalog', true),
  ('7891107000108', 'Óleo de Soja Refinado Liza', 'Liza', 'Óleos e Azeites', '900 ml', '', 'catalog', true),
  ('7891910000197', 'Açúcar Refinado Especial União', 'União', 'Mercearia', '1 kg', '', 'catalog', true),
  ('7891150056893', 'Sabão em Pó Omo Lavagem Perfeita', 'Omo', 'Limpeza', '1,6 kg', '', 'catalog', true),
  ('7898080640017', 'Leite UHT Integral Italac', 'Italac', 'Laticínios', '1 L', '', 'catalog', true),
  ('8000500310427', 'Creme de Avelã com Cacau Nutella', 'Ferrero', 'Mercearia Doce', '350 g', '', 'catalog', true),
  ('7896036090244', 'Azeite de Oliva Extra Virgem Gallo', 'Gallo', 'Óleos e Azeites', '500 ml', '', 'catalog', true)
ON CONFLICT (barcode) DO NOTHING;

INSERT INTO price_reports (barcode, store_name, store_city, price_cents, is_promo, promo_label, source_type, reported_at)
SELECT v.barcode, v.store_name, v.store_city, v.price_cents, v.is_promo, v.promo_label, 'sample', now() - (v.hours_ago || ' hours')::interval
FROM (
  VALUES
    ('7896006711117', 'Assaí Atacadista', 'São Paulo, SP', 2890, true, 'Oferta Atacado', 2),
    ('7896006711117', 'Atacadão', 'São Paulo, SP', 2950, false, '', 5),
    ('7896006711117', 'Carrefour', 'São Paulo, SP', 3190, false, '', 8),
    ('7896006711117', 'Pão de Açúcar', 'São Paulo, SP', 3490, false, '', 14),
    ('7896006711117', 'Carrefour', 'São Paulo, SP', 3290, false, '', 72),

    ('7896006744115', 'Atacadão', 'São Paulo, SP', 749, true, 'Semana do Feijão', 1),
    ('7896006744115', 'Assaí Atacadista', 'São Paulo, SP', 789, false, '', 4),
    ('7896006744115', 'Carrefour', 'São Paulo, SP', 899, false, '', 12),
    ('7896006744115', 'Pão de Açúcar', 'São Paulo, SP', 979, false, '', 24),

    ('7891000100103', 'Assaí Atacadista', 'São Paulo, SP', 629, false, '', 3),
    ('7891000100103', 'Carrefour', 'São Paulo, SP', 699, true, 'Leve 3 Pague Menos', 6),
    ('7891000100103', 'Pão de Açúcar', 'São Paulo, SP', 789, false, '', 18),

    ('7891000053508', 'Atacadão', 'São Paulo, SP', 849, false, '', 4),
    ('7891000053508', 'Carrefour', 'São Paulo, SP', 929, true, 'Clube Meu Carrefour', 7),
    ('7891000053508', 'Extra Mercado', 'São Paulo, SP', 999, false, '', 20),

    ('7894900011517', 'Assaí Atacadista', 'São Paulo, SP', 879, true, 'Pack Família', 1),
    ('7894900011517', 'Carrefour', 'São Paulo, SP', 949, false, '', 3),
    ('7894900011517', 'Extra Mercado', 'São Paulo, SP', 999, false, '', 9),
    ('7894900011517', 'Pão de Açúcar', 'São Paulo, SP', 1099, false, '', 16),

    ('7896089012347', 'Atacadão', 'São Paulo, SP', 1990, true, 'Preço Baixo', 2),
    ('7896089012347', 'Carrefour', 'São Paulo, SP', 2249, false, '', 10),
    ('7896089012347', 'Pão de Açúcar', 'São Paulo, SP', 2490, false, '', 30),

    ('7891107000108', 'Assaí Atacadista', 'São Paulo, SP', 649, false, '', 3),
    ('7891107000108', 'Carrefour', 'São Paulo, SP', 699, false, '', 11),
    ('7891107000108', 'Extra Mercado', 'São Paulo, SP', 749, false, '', 22),

    ('7891910000197', 'Atacadão', 'São Paulo, SP', 459, false, '', 4),
    ('7891910000197', 'Carrefour', 'São Paulo, SP', 499, false, '', 9),
    ('7891910000197', 'Pão de Açúcar', 'São Paulo, SP', 569, false, '', 19),

    ('7891150056893', 'Assaí Atacadista', 'São Paulo, SP', 1990, true, 'Super Oferta', 2),
    ('7891150056893', 'Carrefour', 'São Paulo, SP', 2390, false, '', 8),
    ('7891150056893', 'Pão de Açúcar', 'São Paulo, SP', 2690, false, '', 25),

    ('7898080640017', 'Atacadão', 'São Paulo, SP', 479, true, 'Caixa c/ 12 un.', 1),
    ('7898080640017', 'Assaí Atacadista', 'São Paulo, SP', 499, false, '', 5),
    ('7898080640017', 'Carrefour', 'São Paulo, SP', 549, false, '', 12),
    ('7898080640017', 'Pão de Açúcar', 'São Paulo, SP', 599, false, '', 18),

    ('8000500310427', 'Carrefour', 'São Paulo, SP', 2490, true, 'Festival de Inverno', 3),
    ('8000500310427', 'Pão de Açúcar', 'São Paulo, SP', 2890, false, '', 10),
    ('8000500310427', 'Extra Mercado', 'São Paulo, SP', 2790, false, '', 15),

    ('7896036090244', 'Assaí Atacadista', 'São Paulo, SP', 3890, true, 'Importado em Oferta', 2),
    ('7896036090244', 'Carrefour', 'São Paulo, SP', 4290, false, '', 7),
    ('7896036090244', 'Pão de Açúcar', 'São Paulo, SP', 4690, false, '', 21)
) AS v(barcode, store_name, store_city, price_cents, is_promo, promo_label, hours_ago)
WHERE NOT EXISTS (
  SELECT 1 FROM price_reports pr WHERE pr.barcode = v.barcode AND pr.source_type = 'sample'
);
