export interface ProductSummary {
  barcode: string;
  name: string;
  brand: string;
  category: string;
  unitSize: string;
  imageUrl: string;
  source: string;
  isSample: boolean;
  bestPriceCents: number | null;
  bestStore: string | null;
  avgPriceCents: number | null;
  storeCount: number;
  lastReportedAt: string | null;
  hasRealPrices: boolean;
}

export interface StoreCurrentPrice {
  id: number;
  storeName: string;
  storeCity: string;
  priceCents: number;
  isPromo: boolean;
  promoLabel: string;
  sourceType: "sample" | "user" | "api";
  reportedAt: string;
}

export interface PriceReportItem {
  id: number;
  storeName: string;
  storeCity: string;
  priceCents: number;
  isPromo: boolean;
  promoLabel: string;
  sourceType: "sample" | "user" | "api";
  reportedAt: string;
}

export interface ProductDetailResponse {
  found: boolean;
  barcode: string;
  product?: {
    barcode: string;
    name: string;
    brand: string;
    category: string;
    unitSize: string;
    imageUrl: string;
    source: string;
    isSample: boolean;
  };
  stats?: {
    lowestPriceCents: number | null;
    highestPriceCents: number | null;
    averagePriceCents: number | null;
    bestStore: string | null;
    savingsCents: number;
    storeCount: number;
    reportCount: number;
    hasOnlySamplePrices: boolean;
  };
  currentByStore: StoreCurrentPrice[];
  history: PriceReportItem[];
}
