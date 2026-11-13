"use client";

import React from "react";
import { Minus, Plus, ShoppingCart, Store, Trash2 } from "lucide-react";
import { formatBrl } from "@/lib/format";

export interface CartItem {
  barcode: string;
  name: string;
  brand: string;
  unitSize: string;
  storeName: string;
  priceCents: number;
  quantity: number;
}

interface CartPanelProps {
  items: CartItem[];
  onUpdateQty: (barcode: string, storeName: string, delta: number) => void;
  onRemoveItem: (barcode: string, storeName: string) => void;
  onClearCart: () => void;
  onSelectBarcode: (barcode: string) => void;
}

export function CartPanel({
  items,
  onUpdateQty,
  onRemoveItem,
  onClearCart,
  onSelectBarcode,
}: CartPanelProps) {
  const totalCents = items.reduce(
    (sum, item) => sum + item.priceCents * item.quantity,
    0,
  );
  const totalUnits = items.reduce((sum, item) => sum + item.quantity, 0);

  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-4 shadow-xs sm:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 pb-4">
        <div className="flex items-center gap-2.5">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-50 text-emerald-700">
            <ShoppingCart className="h-5 w-5" />
          </div>
          <div>
            <h2 className="text-base font-semibold text-slate-900">
              Carrinho de Compras Inteligente
            </h2>
            <p className="text-xs text-slate-500">
              Some os produtos escaneados no supermercado em tempo real
            </p>
          </div>
        </div>

        {items.length > 0 && (
          <button
            type="button"
            onClick={onClearCart}
            className="inline-flex items-center gap-1.5 rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-rose-50 hover:text-rose-700"
          >
            <Trash2 className="h-3.5 w-3.5" />
            Limpar carrinho
          </button>
        )}
      </div>

      {items.length === 0 ? (
        <div className="py-12 text-center">
          <ShoppingCart className="mx-auto h-10 w-10 text-slate-300" />
          <p className="mt-3 text-sm font-semibold text-slate-700">
            Seu carrinho está vazio
          </p>
          <p className="mt-1 text-xs text-slate-500">
            Escaneie um produto ou consulte o catálogo e clique em &ldquo;+ Carrinho&rdquo; para acompanhar o valor total da compra.
          </p>
        </div>
      ) : (
        <>
          <div className="mt-4 divide-y divide-slate-100">
            {items.map((item) => (
              <div
                key={`${item.barcode}-${item.storeName}`}
                className="flex flex-wrap items-center justify-between gap-3 py-3"
              >
                <div className="min-w-0 flex-1">
                  <button
                    type="button"
                    onClick={() => onSelectBarcode(item.barcode)}
                    className="text-left text-sm font-semibold text-slate-900 hover:text-emerald-700"
                  >
                    {item.name}
                  </button>
                  <div className="mt-0.5 flex flex-wrap items-center gap-2 text-xs text-slate-500">
                    <span className="inline-flex items-center gap-1">
                      <Store className="h-3 w-3" />
                      {item.storeName}
                    </span>
                    <span>·</span>
                    <span className="tabular-nums">
                      {formatBrl(item.priceCents)} / un
                    </span>
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  <div className="inline-flex items-center rounded-lg border border-slate-200 bg-slate-50">
                    <button
                      type="button"
                      onClick={() =>
                        onUpdateQty(item.barcode, item.storeName, -1)
                      }
                      className="p-1.5 text-slate-600 hover:text-slate-900"
                      aria-label="Diminuir quantidade"
                    >
                      <Minus className="h-3.5 w-3.5" />
                    </button>
                    <span className="min-w-[2rem] text-center text-xs font-bold text-slate-900 tabular-nums">
                      {item.quantity}
                    </span>
                    <button
                      type="button"
                      onClick={() =>
                        onUpdateQty(item.barcode, item.storeName, 1)
                      }
                      className="p-1.5 text-slate-600 hover:text-slate-900"
                      aria-label="Aumentar quantidade"
                    >
                      <Plus className="h-3.5 w-3.5" />
                    </button>
                  </div>

                  <span className="min-w-[5.5rem] text-right text-sm font-bold text-slate-900 tabular-nums">
                    {formatBrl(item.priceCents * item.quantity)}
                  </span>

                  <button
                    type="button"
                    onClick={() => onRemoveItem(item.barcode, item.storeName)}
                    className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600"
                    aria-label="Remover item"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>

          <div className="mt-4 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-emerald-200 bg-emerald-50/70 p-4">
            <div>
              <p className="text-xs font-medium text-emerald-800">
                Total estimado ({totalUnits}{" "}
                {totalUnits === 1 ? "unidade" : "unidades"})
              </p>
              <p className="text-2xl font-extrabold text-emerald-950 tabular-nums">
                {formatBrl(totalCents)}
              </p>
            </div>
            <p className="max-w-xs text-xs text-emerald-800">
              Os valores usam o preço de cada mercado escolhido no momento da leitura.
            </p>
          </div>
        </>
      )}
    </section>
  );
}
