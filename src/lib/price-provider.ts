export interface ExternalProductMetadata {
  barcode: string;
  name: string;
  brand: string;
  category: string;
  unitSize: string;
  imageUrl: string;
  source: "openfoodfacts";
}

export interface ExternalPriceQuote {
  storeName: string;
  storeCity: string;
  priceCents: number;
  isPromo: boolean;
  promoLabel: string;
  sourceType: "api";
}

export function normalizeBarcode(raw: string): string | null {
  const cleaned = raw.replace(/\s+/g, "").trim();
  if (!/^\d{8,14}$/.test(cleaned)) {
    return null;
  }
  return cleaned;
}

function sanitizeHttpsUrl(raw: unknown): string {
  if (typeof raw !== "string" || raw.trim() === "") {
    return "";
  }
  try {
    const parsed = new URL(raw.trim());
    if (parsed.protocol === "https:") {
      return parsed.toString();
    }
    return "";
  } catch {
    return "";
  }
}

export async function lookupOpenFoodFacts(
  barcode: string,
): Promise<ExternalProductMetadata | null> {
  const normalized = normalizeBarcode(barcode);
  if (!normalized) {
    return null;
  }

  try {
    const response = await fetch(
      `https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(normalized)}.json`,
      {
        headers: {
          "User-Agent": "PrecoFacilScanner/1.0 (supermarket-barcode-price-reader)",
        },
        signal: AbortSignal.timeout(4500),
        cache: "no-store",
      },
    );

    if (!response.ok) {
      return null;
    }

    const data = (await response.json()) as {
      status?: number;
      product?: {
        product_name_pt?: string;
        product_name?: string;
        generic_name_pt?: string;
        brands?: string;
        quantity?: string;
        categories?: string;
        image_front_small_url?: string;
        image_url?: string;
      };
    };

    if (data.status !== 1 || !data.product) {
      return null;
    }

    const product = data.product;
    const rawName =
      product.product_name_pt?.trim() ||
      product.product_name?.trim() ||
      product.generic_name_pt?.trim() ||
      "";

    if (!rawName) {
      return null;
    }

    const brand = (product.brands ?? "").split(",")[0]?.trim() ?? "";
    const rawCategory = (product.categories ?? "")
      .split(",")
      .map((c) => c.trim())
      .filter(Boolean)
      .slice(-1)[0] ?? "Supermercado";

    return {
      barcode: normalized,
      name: rawName.slice(0, 160),
      brand: brand.slice(0, 80),
      category: rawCategory.replace(/^en:|^pt:/, "").slice(0, 60) || "Supermercado",
      unitSize: (product.quantity ?? "").trim().slice(0, 40),
      imageUrl: sanitizeHttpsUrl(product.image_front_small_url || product.image_url),
      source: "openfoodfacts",
    };
  } catch {
    return null;
  }
}

/**
 * Ponto único de integração para leitura externa de preços em tempo real
 * (ex.: API Cosmos/Bluesoft, NFC-e / SEFAZ estadual, Google Shopping/SerpApi
 * ou feed ERP da rede de supermercados).
 *
 * Quando nenhum provedor externo estiver configurado, retorna lista vazia e o
 * app utiliza os preços registrados no banco de dados (comunidade + exemplos).
 */
export async function fetchExternalCurrentPrices(
  barcode: string,
): Promise<ExternalPriceQuote[]> {
  if (!normalizeBarcode(barcode)) {
    return [];
  }
  return [];
}
