"use client";

import React, { useState } from "react";
import { Package, Search, ShoppingCart, Store } from "lucide-react";
import { formatBrl, formatRelativeTimePt } from "@/lib/format";
import type { ProductSummary } from "@/lib/types";

interface CatalogBrowserProps {
  products: ProductSummary[];
  onSelectBarcode: (barcode: string) => void;
  onAddToCart: (item: {
    barcode: string;
    name: string;
    brand: string;
    unitSize: string;
    storeName: string;
    priceCents: number;
  }) => void;
}

export function CatalogBrowser({
  products,
  onSelectBarcode,
  onAddToCart,
}: CatalogBrowserProps) {
  const [search, setSearch] = useState("");
  const [categoryFilter, setCategoryFilter] = useState("Todos");

  const categories = [
    "Todos",
    ...Array.from(new Set(products.map((p) => p.category).filter(Boolean))),
  ];

  const filtered = products.filter((p) => {
    const matchesCategory =
      categoryFilter === "Todos" || p.category === categoryFilter;
    const q = search.trim().toLowerCase();
    const matchesSearch =
      q === "" ||
      p.name.toLowerCase().includes(q) ||
      p.brand.toLowerCase().includes(q) ||
      p.barcode.includes(q);
    return matchesCategory && matchesSearch;
  });

  return (
    <section className="space-y-4">
      <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-xs sm:p-5">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="text-base font-semibold text-slate-900">
              Catálogo de Produtos e Preços Atuais
            </h2>
            <p className="text-xs text-slate-500">
              Busque por nome, marca ou código EAN para consultar e comparar preços
            </p>
          </div>
          <div className="relative w-full sm:w-72">
            <Search className="pointer-events-none absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Buscar arroz, café, código..."
              className="w-full rounded-xl border border-slate-300 bg-white py-2 pr-3 pl-9 text-sm text-slate-900 placeholder:text-slate-400 focus:border-emerald-500 focus:outline-none"
            />
          </div>
        </div>

        <div className="mt-3 flex flex-wrap gap-1.5">
          {categories.map((cat) => (
            <button
              key={cat}
              type="button"
              onClick={() => setCategoryFilter(cat)}
              className={`rounded-full px-3 py-1 text-xs font-medium transition ${
                categoryFilter === cat
                  ? "bg-emerald-600 text-white"
                  : "bg-slate-100 text-slate-600 hover:bg-slate-200"
              }`}
            >
              {cat}
            </button>
          ))}
        </div>
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center">
          <Package className="mx-auto h-9 w-9 text-slate-300" />
          <p className="mt-2 text-sm font-medium text-slate-700">
            Nenhum produto encontrado para essa busca.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {filtered.map((item) => (
            <div
              key={item.barcode}
              className="flex flex-col justify-between rounded-2xl border border-slate-200 bg-white p-4 shadow-xs transition hover:border-emerald-300"
            >
              <div>
                <div className="flex items-start justify-between gap-2">
                  <span className="rounded-full bg-slate-100 px-2.5 py-0.5 text-[11px] font-semibold text-slate-600">
                    {item.category}
                  </span>
                  <span
                    className={`rounded-full px-2 py-0.5 text-[10px] font-semibold ${
                      item.hasRealPrices
                        ? "bg-sky-50 text-sky-700"
                        : "bg-amber-50 text-amber-800"
                    }`}
                  >
                    {item.hasRealPrices ? "Atualizado" : "Exemplo"}
                  </span>
                </div>

                <button
                  type="button"
                  onClick={() => onSelectBarcode(item.barcode)}
                  className="mt-2.5 block text-left"
                >
                  <h3 className="text-sm font-bold text-slate-900 hover:text-emerald-700">
                    {item.name}
                  </h3>
                </button>
                <p className="mt-0.5 text-xs text-slate-500">
                  {item.brand}
                  {item.unitSize ? ` · ${item.unitSize}` : ""}
                </p>
                <p className="mt-1 font-mono text-[11px] text-slate-400">
                  EAN {item.barcode}
                </p>
              </div>

              <div className="mt-4 border-t border-slate-100 pt-3">
                <div className="flex items-end justify-between">
                  <div>
                    <p className="text-[11px] text-slate-500">Menor preço atual</p>
                    <p className="text-xl font-extrabold text-emerald-700 tabular-nums">
                      {formatBrl(item.bestPriceCents)}
                    </p>
                    {item.bestStore && (
                      <p className="flex items-center gap-1 text-[11px] text-slate-500">
                        <Store className="h-3 w-3" />
                        {item.bestStore} · {formatRelativeTimePt(item.lastReportedAt)}
                      </p>
                    )}
                  </div>

                  <div className="flex gap-1.5">
                    <button
                      type="button"
                      onClick={() => onSelectBarcode(item.barcode)}
                      className="rounded-lg border border-slate-200 px-2.5 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-50"
                    >
                      Comparar
                    </button>
                    {item.bestPriceCents !== null && item.bestStore && (
                      <button
                        type="button"
                        onClick={() =>
                          onAddToCart({
                            barcode: item.barcode,
                            name: item.name,
                            brand: item.brand,
                            unitSize: item.unitSize,
                            storeName: item.bestStore!,
                            priceCents: item.bestPriceCents!,
                          })
                        }
                        className="inline-flex items-center gap-1 rounded-lg bg-emerald-600 px-2.5 py-1.5 text-xs font-semibold text-white hover:bg-emerald-500"
                        title="Adicionar ao carrinho"
                      >
                        <ShoppingCart className="h-3.5 w-3.5" />
                      </button>
                    )}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </section>
  );
}
