"use client";

import React, { useCallback, useEffect, useState } from "react";
import {
  Barcode,
  LayoutGrid,
  ScanLine,
  ShoppingCart,
} from "lucide-react";
import { BarcodeScanner } from "@/components/BarcodeScanner";
import { CatalogBrowser } from "@/components/CatalogBrowser";
import { CartPanel, type CartItem } from "@/components/CartPanel";
import { ProductPricePanel } from "@/components/ProductPricePanel";
import { formatBrl } from "@/lib/format";
import type { ProductDetailResponse, ProductSummary } from "@/lib/types";

type ActiveView = "scanner" | "catalog" | "cart";

interface ScannerAppProps {
  initialCatalog: ProductSummary[];
  initialDetail: ProductDetailResponse | null;
}

const CART_STORAGE_KEY = "precofacil_cart_v1";

export function ScannerApp({ initialCatalog, initialDetail }: ScannerAppProps) {
  const [view, setView] = useState<ActiveView>("scanner");
  const [catalog, setCatalog] = useState<ProductSummary[]>(initialCatalog);
  const [activeBarcode, setActiveBarcode] = useState<string>(
    initialDetail?.barcode ?? initialCatalog[0]?.barcode ?? "",
  );
  const [detail, setDetail] = useState<ProductDetailResponse | null>(
    initialDetail,
  );
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [detailError, setDetailError] = useState<string | null>(null);
  const [cart, setCart] = useState<CartItem[]>([]);

  useEffect(() => {
    try {
      const saved = localStorage.getItem(CART_STORAGE_KEY);
      if (saved) {
        const parsed = JSON.parse(saved) as CartItem[];
        if (Array.isArray(parsed)) {
          setCart(parsed);
        }
      }
    } catch {
      // ignore invalid storage
    }
  }, []);

  useEffect(() => {
    try {
      localStorage.setItem(CART_STORAGE_KEY, JSON.stringify(cart));
    } catch {
      // ignore storage quota errors
    }
  }, [cart]);

  const refreshCatalog = useCallback(async () => {
    try {
      const res = await fetch("/api/products", { cache: "no-store" });
      if (res.ok) {
        const data = (await res.json()) as { products: ProductSummary[] };
        setCatalog(data.products);
      }
    } catch {
      // ignore background refresh error
    }
  }, []);

  const fetchBarcode = useCallback(async (barcode: string) => {
    setActiveBarcode(barcode);
    setView("scanner");
    setLoadingDetail(true);
    setDetailError(null);

    try {
      const res = await fetch(`/api/products/${encodeURIComponent(barcode)}`, {
        cache: "no-store",
      });
      const data = (await res.json()) as ProductDetailResponse & {
        error?: string;
      };
      if (!res.ok) {
        throw new Error(data.error || "Falha ao consultar código de barras.");
      }
      setDetail(data);
    } catch (err) {
      setDetailError(
        err instanceof Error ? err.message : "Erro ao consultar código.",
      );
    } finally {
      setLoadingDetail(false);
    }
  }, []);

  const handlePriceRecorded = useCallback(
    (updated: ProductDetailResponse) => {
      setDetail(updated);
      void refreshCatalog();
    },
    [refreshCatalog],
  );

  const handleAddToCart = useCallback(
    (newItem: Omit<CartItem, "quantity">) => {
      setCart((prev) => {
        const existingIndex = prev.findIndex(
          (i) =>
            i.barcode === newItem.barcode && i.storeName === newItem.storeName,
        );
        if (existingIndex >= 0) {
          return prev.map((item, idx) =>
            idx === existingIndex
              ? { ...item, quantity: item.quantity + 1, priceCents: newItem.priceCents }
              : item,
          );
        }
        return [...prev, { ...newItem, quantity: 1 }];
      });
    },
    [],
  );

  const handleUpdateQty = useCallback(
    (barcode: string, storeName: string, delta: number) => {
      setCart((prev) =>
        prev
          .map((item) =>
            item.barcode === barcode && item.storeName === storeName
              ? { ...item, quantity: item.quantity + delta }
              : item,
          )
          .filter((item) => item.quantity > 0),
      );
    },
    [],
  );

  const handleRemoveCartItem = useCallback(
    (barcode: string, storeName: string) => {
      setCart((prev) =>
        prev.filter(
          (item) => !(item.barcode === barcode && item.storeName === storeName),
        ),
      );
    },
    [],
  );

  const totalUnits = cart.reduce((sum, i) => sum + i.quantity, 0);
  const totalCents = cart.reduce(
    (sum, i) => sum + i.priceCents * i.quantity,
    0,
  );

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="sticky top-0 z-20 border-b border-slate-200 bg-white/95 backdrop-blur-sm">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-3 sm:px-6">
          <div className="flex items-center gap-2.5">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-600 text-white shadow-xs">
              <Barcode className="h-5 w-5" />
            </div>
            <div>
              <h1 className="text-base font-bold tracking-tight text-slate-900 sm:text-lg">
                PreçoFácil Supermercado
              </h1>
              <p className="text-xs text-slate-500">
                Leitura de código de barras e preços atuais
              </p>
            </div>
          </div>

          <nav className="flex items-center gap-1.5 rounded-xl bg-slate-100 p-1">
            <button
              type="button"
              onClick={() => setView("scanner")}
              className={`inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-semibold transition sm:text-sm ${
                view === "scanner"
                  ? "bg-white text-emerald-700 shadow-xs"
                  : "text-slate-600 hover:text-slate-900"
              }`}
            >
              <ScanLine className="h-4 w-4" />
              <span>Scanner</span>
            </button>

            <button
              type="button"
              onClick={() => setView("catalog")}
              className={`inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-semibold transition sm:text-sm ${
                view === "catalog"
                  ? "bg-white text-emerald-700 shadow-xs"
                  : "text-slate-600 hover:text-slate-900"
              }`}
            >
              <LayoutGrid className="h-4 w-4" />
              <span>Catálogo ({catalog.length})</span>
            </button>

            <button
              type="button"
              onClick={() => setView("cart")}
              className={`inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-semibold transition sm:text-sm ${
                view === "cart"
                  ? "bg-white text-emerald-700 shadow-xs"
                  : "text-slate-600 hover:text-slate-900"
              }`}
            >
              <ShoppingCart className="h-4 w-4" />
              <span>Carrinho</span>
              {totalUnits > 0 && (
                <span className="rounded-full bg-emerald-600 px-1.5 py-0.5 text-[11px] font-bold text-white tabular-nums">
                  {totalUnits} · {formatBrl(totalCents)}
                </span>
              )}
            </button>
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6">
        {view === "scanner" && (
          <div className="grid grid-cols-1 gap-6 lg:grid-cols-12 lg:items-start">
            <div className="lg:col-span-5">
              <BarcodeScanner
                activeBarcode={activeBarcode}
                loading={loadingDetail}
                quickSamples={catalog.map((c) => ({
                  barcode: c.barcode,
                  name: c.name,
                  bestPriceCents: c.bestPriceCents,
                }))}
                onScanBarcode={(code) => void fetchBarcode(code)}
              />
            </div>

            <div className="lg:col-span-7">
              <ProductPricePanel
                detail={detail}
                loading={loadingDetail}
                error={detailError}
                onPriceRecorded={handlePriceRecorded}
                onAddToCart={handleAddToCart}
              />
            </div>
          </div>
        )}

        {view === "catalog" && (
          <CatalogBrowser
            products={catalog}
            onSelectBarcode={(code) => void fetchBarcode(code)}
            onAddToCart={handleAddToCart}
          />
        )}

        {view === "cart" && (
          <CartPanel
            items={cart}
            onUpdateQty={handleUpdateQty}
            onRemoveItem={handleRemoveCartItem}
            onClearCart={() => setCart([])}
            onSelectBarcode={(code) => void fetchBarcode(code)}
          />
        )}
      </main>
    </div>
  );
}
