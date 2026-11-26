import { sql } from "@/lib/db";
import {
  fetchExternalCurrentPrices,
  lookupOpenFoodFacts,
  normalizeBarcode,
} from "@/lib/price-provider";
import type {
  PriceReportItem,
  ProductDetailResponse,
  ProductSummary,
  StoreCurrentPrice,
} from "@/lib/types";

interface ProductRow {
  barcode: string;
  name: string;
  brand: string;
  category: string;
  unit_size: string;
  image_url: string;
  source: string;
  is_sample: boolean;
}

interface PriceReportRow {
  id: number;
  barcode: string;
  store_name: string;
  store_city: string;
  price_cents: number;
  is_promo: boolean;
  promo_label: string;
  source_type: string;
  reported_at: string | Date;
}

interface CatalogListRow extends ProductRow {
  best_price_cents: number | string | null;
  best_store: string | null;
  avg_price_cents: number | string | null;
  store_count: number | string;
  last_reported_at: string | Date | null;
  has_real_prices: boolean;
}

function toIsoString(value: string | Date | null | undefined): string {
  if (!value) {
    return new Date().toISOString();
  }
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}

export async function listCatalogProducts(query = ""): Promise<ProductSummary[]> {
  const trimmed = query.trim();
  const likeParam = `%${trimmed}%`;

  const rows = await sql<CatalogListRow>(
    `
    WITH latest_per_store AS (
      SELECT DISTINCT ON (barcode, store_name)
        barcode,
        store_name,
        price_cents,
        source_type,
        reported_at
      FROM price_reports
      ORDER BY barcode, store_name, reported_at DESC, id DESC
    ),
    agg AS (
      SELECT
        barcode,
        MIN(price_cents) AS best_price_cents,
        ROUND(AVG(price_cents))::integer AS avg_price_cents,
        COUNT(*)::integer AS store_count,
        MAX(reported_at) AS last_reported_at,
        BOOL_OR(source_type <> 'sample') AS has_real_prices
      FROM latest_per_store
      GROUP BY barcode
    )
    SELECT
      p.barcode,
      p.name,
      p.brand,
      p.category,
      p.unit_size,
      p.image_url,
      p.source,
      p.is_sample,
      a.best_price_cents,
      (
        SELECT l.store_name
        FROM latest_per_store l
        WHERE l.barcode = p.barcode
        ORDER BY l.price_cents ASC, l.reported_at DESC
        LIMIT 1
      ) AS best_store,
      a.avg_price_cents,
      COALESCE(a.store_count, 0) AS store_count,
      a.last_reported_at,
      COALESCE(a.has_real_prices, false) AS has_real_prices
    FROM products p
    LEFT JOIN agg a ON a.barcode = p.barcode
    WHERE (
      $1 = ''
      OR p.barcode ILIKE $2
      OR p.name ILIKE $2
      OR p.brand ILIKE $2
      OR p.category ILIKE $2
    )
    ORDER BY
      COALESCE(a.has_real_prices, false) DESC,
      a.last_reported_at DESC NULLS LAST,
      p.name ASC
    LIMIT 60
    `,
    [trimmed, likeParam],
  );

  return rows.map((row) => ({
    barcode: row.barcode,
    name: row.name,
    brand: row.brand,
    category: row.category,
    unitSize: row.unit_size,
    imageUrl: row.image_url,
    source: row.source,
    isSample: Boolean(row.is_sample),
    bestPriceCents:
      row.best_price_cents === null ? null : Number(row.best_price_cents),
    bestStore: row.best_store ?? null,
    avgPriceCents:
      row.avg_price_cents === null ? null : Number(row.avg_price_cents),
    storeCount: Number(row.store_count ?? 0),
    lastReportedAt: row.last_reported_at ? toIsoString(row.last_reported_at) : null,
    hasRealPrices: Boolean(row.has_real_prices),
  }));
}

export async function getProductByBarcode(
  rawBarcode: string,
): Promise<ProductDetailResponse> {
  const barcode = normalizeBarcode(rawBarcode);
  if (!barcode) {
    throw new Error("Código de barras inválido. Informe entre 8 e 14 dígitos.");
  }

  let rows = await sql<ProductRow>(
    `SELECT barcode, name, brand, category, unit_size, image_url, source, is_sample
     FROM products
     WHERE barcode = $1
     LIMIT 1`,
    [barcode],
  );

  if (rows.length === 0) {
    const external = await lookupOpenFoodFacts(barcode);
    if (external) {
      await sql(
        `INSERT INTO products (barcode, name, brand, category, unit_size, image_url, source, is_sample)
         VALUES ($1, $2, $3, $4, $5, $6, $7, false)
         ON CONFLICT (barcode) DO NOTHING`,
        [
          external.barcode,
          external.name,
          external.brand,
          external.category,
          external.unitSize,
          external.imageUrl,
          external.source,
        ],
      );
      rows = await sql<ProductRow>(
        `SELECT barcode, name, brand, category, unit_size, image_url, source, is_sample
         FROM products
         WHERE barcode = $1
         LIMIT 1`,
        [barcode],
      );
    }
  } else if (!rows[0].image_url) {
    const external = await lookupOpenFoodFacts(barcode);
    if (external?.imageUrl) {
      await sql(
        `UPDATE products SET image_url = $2, updated_at = now() WHERE barcode = $1 AND image_url = ''`,
        [barcode, external.imageUrl],
      );
      rows[0] = { ...rows[0], image_url: external.imageUrl };
    }
  }

  if (rows.length === 0) {
    return {
      found: false,
      barcode,
      currentByStore: [],
      history: [],
    };
  }

  const product = rows[0];

  const [reportRows, externalQuotes] = await Promise.all([
    sql<PriceReportRow>(
      `SELECT id, barcode, store_name, store_city, price_cents, is_promo, promo_label, source_type, reported_at
       FROM price_reports
       WHERE barcode = $1
       ORDER BY reported_at DESC, id DESC
       LIMIT 30`,
      [barcode],
    ),
    fetchExternalCurrentPrices(barcode),
  ]);

  const history: PriceReportItem[] = reportRows.map((r) => ({
    id: Number(r.id),
    storeName: r.store_name,
    storeCity: r.store_city,
    priceCents: Number(r.price_cents),
    isPromo: Boolean(r.is_promo),
    promoLabel: r.promo_label,
    sourceType:
      r.source_type === "user" || r.source_type === "api" ? r.source_type : "sample",
    reportedAt: toIsoString(r.reported_at),
  }));

  const storeMap = new Map<string, StoreCurrentPrice>();
  for (const item of history) {
    const key = item.storeName.toLowerCase();
    if (!storeMap.has(key)) {
      storeMap.set(key, {
        id: item.id,
        storeName: item.storeName,
        storeCity: item.storeCity,
        priceCents: item.priceCents,
        isPromo: item.isPromo,
        promoLabel: item.promoLabel,
        sourceType: item.sourceType,
        reportedAt: item.reportedAt,
      });
    }
  }

  for (const quote of externalQuotes) {
    const key = quote.storeName.toLowerCase();
    storeMap.set(key, {
      id: -1,
      storeName: quote.storeName,
      storeCity: quote.storeCity,
      priceCents: quote.priceCents,
      isPromo: quote.isPromo,
      promoLabel: quote.promoLabel,
      sourceType: "api",
      reportedAt: new Date().toISOString(),
    });
  }

  const currentByStore = Array.from(storeMap.values()).sort(
    (a, b) => a.priceCents - b.priceCents,
  );

  const prices = currentByStore.map((s) => s.priceCents);
  const lowestPriceCents = prices.length > 0 ? Math.min(...prices) : null;
  const highestPriceCents = prices.length > 0 ? Math.max(...prices) : null;
  const averagePriceCents =
    prices.length > 0
      ? Math.round(prices.reduce((acc, p) => acc + p, 0) / prices.length)
      : null;

  const hasOnlySamplePrices =
    currentByStore.length > 0 &&
    currentByStore.every((item) => item.sourceType === "sample");

  return {
    found: true,
    barcode,
    product: {
      barcode: product.barcode,
      name: product.name,
      brand: product.brand,
      category: product.category,
      unitSize: product.unit_size,
      imageUrl: product.image_url,
      source: product.source,
      isSample: Boolean(product.is_sample),
    },
    stats: {
      lowestPriceCents,
      highestPriceCents,
      averagePriceCents,
      bestStore: currentByStore[0]?.storeName ?? null,
      savingsCents:
        lowestPriceCents !== null && highestPriceCents !== null
          ? highestPriceCents - lowestPriceCents
          : 0,
      storeCount: currentByStore.length,
      reportCount: history.length,
      hasOnlySamplePrices,
    },
    currentByStore,
    history,
  };
}

export interface AddPriceInput {
  barcode: string;
  storeName: string;
  storeCity?: string;
  priceCents: number;
  isPromo?: boolean;
  promoLabel?: string;
  productName?: string;
  productBrand?: string;
  productCategory?: string;
  productUnitSize?: string;
}

export async function recordCurrentPrice(
  input: AddPriceInput,
): Promise<ProductDetailResponse> {
  const barcode = normalizeBarcode(input.barcode);
  if (!barcode) {
    throw new Error("Código de barras inválido.");
  }

  const storeName = input.storeName.trim().slice(0, 80);
  if (storeName.length < 2) {
    throw new Error("Informe o nome do supermercado.");
  }

  const storeCity = (input.storeCity?.trim() || "São Paulo, SP").slice(0, 80);
  const priceCents = Math.round(Number(input.priceCents));
  if (!Number.isFinite(priceCents) || priceCents <= 0 || priceCents >= 100000000) {
    throw new Error("Informe um preço válido maior que R$ 0,00.");
  }

  const isPromo = Boolean(input.isPromo);
  const promoLabel = isPromo ? (input.promoLabel?.trim() || "Oferta").slice(0, 60) : "";

  const existing = await sql<{ barcode: string }>(
    `SELECT barcode FROM products WHERE barcode = $1 LIMIT 1`,
    [barcode],
  );

  if (existing.length === 0) {
    const productName = input.productName?.trim().slice(0, 160) ?? "";
    if (productName.length < 2) {
      throw new Error("Informe o nome do produto para cadastrá-lo.");
    }
    await sql(
      `INSERT INTO products (barcode, name, brand, category, unit_size, image_url, source, is_sample)
       VALUES ($1, $2, $3, $4, $5, '', 'manual', false)
       ON CONFLICT (barcode) DO NOTHING`,
      [
        barcode,
        productName,
        (input.productBrand?.trim() || "").slice(0, 80),
        (input.productCategory?.trim() || "Mercearia").slice(0, 60),
        (input.productUnitSize?.trim() || "").slice(0, 40),
      ],
    );
  }

  await sql(
    `INSERT INTO price_reports (barcode, store_name, store_city, price_cents, is_promo, promo_label, source_type)
     VALUES ($1, $2, $3, $4, $5, $6, 'user')`,
    [barcode, storeName, storeCity, priceCents, isPromo, promoLabel],
  );

  return getProductByBarcode(barcode);
}
