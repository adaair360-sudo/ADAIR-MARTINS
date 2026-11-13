"use client";

import React, { useEffect, useState } from "react";
import {
  BadgePercent,
  CheckCircle2,
  Clock,
  Info,
  Loader2,
  MapPin,
  Package,
  Plus,
  ShoppingCart,
  Store,
  Tag,
  TrendingDown,
} from "lucide-react";
import { Ean13Barcode } from "@/components/Ean13Barcode";
import {
  formatBrl,
  formatRelativeTimePt,
  parseBrlInputToCents,
} from "@/lib/format";
import type { ProductDetailResponse, StoreCurrentPrice } from "@/lib/types";

const POPULAR_STORES = [
  "Assaí Atacadista",
  "Atacadão",
  "Carrefour",
  "Pão de Açúcar",
  "Extra Mercado",
  "Mercado Local",
];

interface ProductPricePanelProps {
  detail: ProductDetailResponse | null;
  loading: boolean;
  error: string | null;
  onPriceRecorded: (updated: ProductDetailResponse) => void;
  onAddToCart: (item: {
    barcode: string;
    name: string;
    brand: string;
    unitSize: string;
    storeName: string;
    priceCents: number;
  }) => void;
}

export function ProductPricePanel({
  detail,
  loading,
  error,
  onPriceRecorded,
  onAddToCart,
}: ProductPricePanelProps) {
  const [showPriceForm, setShowPriceForm] = useState(false);
  const [storeName, setStoreName] = useState("Carrefour");
  const [storeCity, setStoreCity] = useState("São Paulo, SP");
  const [priceInput, setPriceInput] = useState("");
  const [isPromo, setIsPromo] = useState(false);
  const [promoLabel, setPromoLabel] = useState("");

  const [productName, setProductName] = useState("");
  const [productBrand, setProductBrand] = useState("");
  const [productCategory, setProductCategory] = useState("Mercearia");
  const [productUnitSize, setProductUnitSize] = useState("");

  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [submitSuccess, setSubmitSuccess] = useState<string | null>(null);
  const [addedFeedback, setAddedFeedback] = useState<string | null>(null);

  useEffect(() => {
    setSubmitError(null);
    setSubmitSuccess(null);
    setAddedFeedback(null);
    if (detail && !detail.found) {
      setShowPriceForm(true);
    } else if (detail && detail.found && detail.currentByStore.length === 0) {
      setShowPriceForm(true);
    } else {
      setShowPriceForm(false);
    }
  }, [detail]);

  const handleSubmitPrice = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!detail) return;

    const priceCents = parseBrlInputToCents(priceInput);
    if (!priceCents) {
      setSubmitError("Informe um preço válido (ex.: 19,90).");
      return;
    }

    setSubmitting(true);
    setSubmitError(null);
    setSubmitSuccess(null);

    try {
      const response = await fetch(
        `/api/products/${encodeURIComponent(detail.barcode)}/prices`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            storeName,
            storeCity,
            priceCents,
            isPromo,
            promoLabel,
            productName: detail.found ? undefined : productName,
            productBrand: detail.found ? undefined : productBrand,
            productCategory: detail.found ? undefined : productCategory,
            productUnitSize: detail.found ? undefined : productUnitSize,
          }),
        },
      );

      const data = (await response.json()) as ProductDetailResponse & {
        error?: string;
      };
      if (!response.ok) {
        throw new Error(data.error || "Não foi possível salvar o preço.");
      }

      setPriceInput("");
      setIsPromo(false);
      setPromoLabel("");
      setProductName("");
      setProductBrand("");
      setProductUnitSize("");
      setShowPriceForm(false);
      setSubmitSuccess(
        `Preço atual (${formatBrl(priceCents)}) registrado em ${storeName}!`,
      );
      onPriceRecorded(data);
    } catch (err) {
      setSubmitError(
        err instanceof Error ? err.message : "Erro ao registrar preço.",
      );
    } finally {
      setSubmitting(false);
    }
  };

  const handleCartClick = (store: StoreCurrentPrice) => {
    if (!detail?.product) return;
    onAddToCart({
      barcode: detail.product.barcode,
      name: detail.product.name,
      brand: detail.product.brand,
      unitSize: detail.product.unitSize,
      storeName: store.storeName,
      priceCents: store.priceCents,
    });
    setAddedFeedback(store.storeName);
    window.setTimeout(() => setAddedFeedback(null), 1800);
  };

  if (loading) {
    return (
      <section className="flex min-h-[380px] flex-col items-center justify-center rounded-2xl border border-slate-200 bg-white p-8 text-center shadow-xs">
        <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
        <p className="mt-3 text-sm font-semibold text-slate-800">
          Consultando produto e preços atuais...
        </p>
        <p className="mt-1 text-xs text-slate-500">
          Buscando no catálogo local e no Open Food Facts
        </p>
      </section>
    );
  }

  if (error) {
    return (
      <section className="rounded-2xl border border-rose-200 bg-rose-50 p-6 text-rose-900">
        <h3 className="text-sm font-semibold">Erro na consulta</h3>
        <p className="mt-1 text-xs text-rose-700">{error}</p>
      </section>
    );
  }

  if (!detail) {
    return (
      <section className="flex min-h-[380px] flex-col items-center justify-center rounded-2xl border border-dashed border-slate-300 bg-white p-8 text-center">
        <Package className="h-10 w-10 text-slate-300" />
        <p className="mt-3 text-sm font-semibold text-slate-700">
          Nenhum produto selecionado
        </p>
        <p className="mt-1 max-w-sm text-xs text-slate-500">
          Escaneie um código de barras com a câmera, envie uma foto ou clique em um item de teste.
        </p>
      </section>
    );
  }

  const product = detail.product;
  const stats = detail.stats;

  return (
    <section className="space-y-4">
      <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-xs sm:p-5">
        {detail.found && product ? (
          <>
            <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
              <div className="flex items-start gap-3.5">
                {product.imageUrl ? (
                  /* eslint-disable-next-line @next/next/no-img-element */
                  <img
                    src={product.imageUrl}
                    alt={product.name}
                    className="h-20 w-20 shrink-0 rounded-xl border border-slate-200 bg-white object-contain p-1"
                  />
                ) : (
                  <div className="flex h-20 w-20 shrink-0 items-center justify-center rounded-xl border border-emerald-100 bg-emerald-50 text-emerald-700">
                    <Package className="h-9 w-9" />
                  </div>
                )}

                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-1.5">
                    <span className="inline-flex items-center rounded-full bg-slate-100 px-2.5 py-0.5 text-[11px] font-semibold text-slate-700">
                      {product.category || "Supermercado"}
                    </span>
                    {product.unitSize && (
                      <span className="inline-flex items-center rounded-full bg-emerald-50 px-2.5 py-0.5 text-[11px] font-semibold text-emerald-800">
                        {product.unitSize}
                      </span>
                    )}
                    {product.source === "openfoodfacts" && (
                      <span className="inline-flex items-center rounded-full bg-sky-50 px-2.5 py-0.5 text-[11px] font-semibold text-sky-700">
                        Open Food Facts
                      </span>
                    )}
                    {stats?.hasOnlySamplePrices && (
                      <span className="inline-flex items-center gap-1 rounded-full bg-amber-50 px-2.5 py-0.5 text-[11px] font-semibold text-amber-800">
                        <Info className="h-3 w-3" />
                        Preços de exemplo
                      </span>
                    )}
                  </div>

                  <h2 className="mt-1.5 text-lg font-bold leading-snug text-slate-900">
                    {product.name}
                  </h2>
                  <p className="text-xs text-slate-500">
                    {product.brand ? `Marca: ${product.brand} · ` : ""}
                    EAN: <span className="font-mono font-medium">{product.barcode}</span>
                  </p>
                </div>
              </div>

              <Ean13Barcode code={product.barcode} className="self-start shrink-0" />
            </div>

            {submitSuccess && (
              <div className="mt-4 flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 px-3.5 py-2.5 text-xs font-medium text-emerald-900">
                <CheckCircle2 className="h-4 w-4 shrink-0 text-emerald-600" />
                <span>{submitSuccess}</span>
              </div>
            )}

            {stats && detail.currentByStore.length > 0 ? (
              <div className="mt-5 grid grid-cols-1 gap-3 sm:grid-cols-3">
                <div className="rounded-xl border border-emerald-200 bg-emerald-50/70 p-3.5">
                  <div className="flex items-center justify-between text-xs font-medium text-emerald-800">
                    <span>Menor Preço Atual</span>
                    <TrendingDown className="h-4 w-4 text-emerald-600" />
                  </div>
                  <p className="mt-1 text-2xl font-extrabold tracking-tight text-emerald-950 tabular-nums">
                    {formatBrl(stats.lowestPriceCents)}
                  </p>
                  <p className="mt-0.5 truncate text-xs font-medium text-emerald-800">
                    {stats.bestStore}
                  </p>
                </div>

                <div className="rounded-xl border border-slate-200 bg-slate-50 p-3.5">
                  <div className="flex items-center justify-between text-xs font-medium text-slate-600">
                    <span>Preço Médio</span>
                    <Tag className="h-4 w-4 text-slate-400" />
                  </div>
                  <p className="mt-1 text-2xl font-bold tracking-tight text-slate-900 tabular-nums">
                    {formatBrl(stats.averagePriceCents)}
                  </p>
                  <p className="mt-0.5 text-xs text-slate-500">
                    Em {stats.storeCount}{" "}
                    {stats.storeCount === 1 ? "supermercado" : "supermercados"}
                  </p>
                </div>

                <div className="rounded-xl border border-slate-200 bg-slate-50 p-3.5">
                  <div className="flex items-center justify-between text-xs font-medium text-slate-600">
                    <span>Economia Máxima</span>
                    <BadgePercent className="h-4 w-4 text-amber-500" />
                  </div>
                  <p className="mt-1 text-2xl font-bold tracking-tight text-slate-900 tabular-nums">
                    {formatBrl(stats.savingsCents)}
                  </p>
                  <p className="mt-0.5 text-xs text-slate-500">
                    Diferença entre maior e menor
                  </p>
                </div>
              </div>
            ) : (
              <div className="mt-4 rounded-xl border border-amber-200 bg-amber-50 p-3.5 text-xs text-amber-900">
                Produto identificado, mas ainda sem preço atual registrado. Informe abaixo o preço encontrado na prateleira!
              </div>
            )}

            <div className="mt-5 flex flex-wrap items-center justify-between gap-2">
              <h3 className="text-sm font-semibold text-slate-900">
                Preços atuais por supermercado
              </h3>

              <div className="flex flex-wrap gap-2">
                {detail.currentByStore[0] && (
                  <button
                    type="button"
                    onClick={() => handleCartClick(detail.currentByStore[0])}
                    className="inline-flex items-center gap-1.5 rounded-xl border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-xs font-semibold text-emerald-800 transition hover:bg-emerald-100"
                  >
                    <ShoppingCart className="h-3.5 w-3.5" />
                    {addedFeedback === detail.currentByStore[0].storeName
                      ? "Adicionado!"
                      : "Adicionar menor preço"}
                  </button>
                )}

                <button
                  type="button"
                  onClick={() => setShowPriceForm((prev) => !prev)}
                  className="inline-flex items-center gap-1.5 rounded-xl bg-slate-900 px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-slate-800"
                >
                  <Plus className="h-3.5 w-3.5" />
                  {showPriceForm ? "Fechar formulário" : "Atualizar preço atual"}
                </button>
              </div>
            </div>

            {detail.currentByStore.length > 0 && (
              <div className="mt-3 space-y-2">
                {detail.currentByStore.map((store, index) => {
                  const isCheapest = index === 0 && detail.currentByStore.length > 1;
                  return (
                    <div
                      key={`${store.storeName}-${store.id}`}
                      className={`flex flex-wrap items-center justify-between gap-3 rounded-xl border p-3 transition ${
                        isCheapest
                          ? "border-emerald-300 bg-emerald-50/40"
                          : "border-slate-200 bg-white"
                      }`}
                    >
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-1.5">
                          <Store className="h-4 w-4 text-slate-500" />
                          <span className="text-sm font-semibold text-slate-900">
                            {store.storeName}
                          </span>
                          {isCheapest && (
                            <span className="rounded-full bg-emerald-600 px-2 py-0.5 text-[10px] font-bold uppercase text-white">
                              Melhor preço
                            </span>
                          )}
                          {store.isPromo && (
                            <span className="rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-semibold text-amber-800">
                              {store.promoLabel || "Promoção"}
                            </span>
                          )}
                          <span
                            className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${
                              store.sourceType === "sample"
                                ? "bg-slate-100 text-slate-500"
                                : "bg-sky-100 text-sky-800"
                            }`}
                          >
                            {store.sourceType === "sample"
                              ? "Exemplo"
                              : store.sourceType === "api"
                                ? "API ao vivo"
                                : "Atualizado"}
                          </span>
                        </div>

                        <div className="mt-1 flex flex-wrap items-center gap-3 text-xs text-slate-500">
                          <span className="inline-flex items-center gap-1">
                            <MapPin className="h-3 w-3" />
                            {store.storeCity}
                          </span>
                          <span className="inline-flex items-center gap-1">
                            <Clock className="h-3 w-3" />
                            {formatRelativeTimePt(store.reportedAt)}
                          </span>
                        </div>
                      </div>

                      <div className="flex items-center gap-3">
                        <span className="text-lg font-extrabold text-slate-900 tabular-nums">
                          {formatBrl(store.priceCents)}
                        </span>
                        <button
                          type="button"
                          onClick={() => handleCartClick(store)}
                          className="rounded-lg border border-slate-200 bg-white px-2.5 py-1.5 text-xs font-semibold text-slate-700 transition hover:border-emerald-300 hover:bg-emerald-50 hover:text-emerald-800"
                          title="Adicionar este item ao carrinho"
                        >
                          {addedFeedback === store.storeName ? "No carrinho" : "+ Carrinho"}
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </>
        ) : (
          <div className="space-y-3">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <span className="inline-flex items-center rounded-full bg-amber-100 px-2.5 py-0.5 text-[11px] font-semibold text-amber-800">
                  Novo código de barras
                </span>
                <h2 className="mt-1.5 text-lg font-bold text-slate-900">
                  Produto ainda não cadastrado
                </h2>
                <p className="text-xs text-slate-500">
                  Código lido: <span className="font-mono font-semibold">{detail.barcode}</span>. Cadastre o produto e o preço atual encontrado na loja.
                </p>
              </div>
              <Ean13Barcode code={detail.barcode} />
            </div>
          </div>
        )}

        {showPriceForm && (
          <form
            onSubmit={handleSubmitPrice}
            className="mt-5 rounded-xl border border-slate-200 bg-slate-50 p-4 space-y-3.5"
          >
            <h4 className="text-sm font-semibold text-slate-900">
              {detail.found
                ? "Registrar / Atualizar Preço Atual"
                : "Cadastrar Produto e Preço Atual"}
            </h4>

            {!detail.found && (
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <div className="sm:col-span-2">
                  <label className="mb-1 block text-xs font-medium text-slate-700">
                    Nome do produto *
                  </label>
                  <input
                    type="text"
                    required
                    value={productName}
                    onChange={(e) => setProductName(e.target.value)}
                    placeholder="Ex: Macarrão Espaguete Renata 500g"
                    className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm focus:border-emerald-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="mb-1 block text-xs font-medium text-slate-700">
                    Marca
                  </label>
                  <input
                    type="text"
                    value={productBrand}
                    onChange={(e) => setProductBrand(e.target.value)}
                    placeholder="Ex: Renata"
                    className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm focus:border-emerald-500 focus:outline-none"
                  />
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="mb-1 block text-xs font-medium text-slate-700">
                      Peso/Volume
                    </label>
                    <input
                      type="text"
                      value={productUnitSize}
                      onChange={(e) => setProductUnitSize(e.target.value)}
                      placeholder="Ex: 500 g"
                      className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm focus:border-emerald-500 focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="mb-1 block text-xs font-medium text-slate-700">
                      Categoria
                    </label>
                    <input
                      type="text"
                      value={productCategory}
                      onChange={(e) => setProductCategory(e.target.value)}
                      placeholder="Mercearia"
                      className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm focus:border-emerald-500 focus:outline-none"
                    />
                  </div>
                </div>
              </div>
            )}

            <div>
              <span className="mb-1.5 block text-xs font-medium text-slate-700">
                Supermercado
              </span>
              <div className="mb-2 flex flex-wrap gap-1.5">
                {POPULAR_STORES.map((s) => (
                  <button
                    key={s}
                    type="button"
                    onClick={() => setStoreName(s)}
                    className={`rounded-lg border px-2.5 py-1 text-xs font-medium transition ${
                      storeName === s
                        ? "border-emerald-500 bg-emerald-50 text-emerald-800"
                        : "border-slate-200 bg-white text-slate-600 hover:bg-slate-100"
                    }`}
                  >
                    {s}
                  </button>
                ))}
              </div>
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
                <div>
                  <label className="mb-1 block text-xs font-medium text-slate-700">
                    Nome do mercado *
                  </label>
                  <input
                    type="text"
                    required
                    value={storeName}
                    onChange={(e) => setStoreName(e.target.value)}
                    placeholder="Ex: Carrefour"
                    className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm focus:border-emerald-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="mb-1 block text-xs font-medium text-slate-700">
                    Preço atual (R$) *
                  </label>
                  <input
                    type="text"
                    inputMode="decimal"
                    required
                    value={priceInput}
                    onChange={(e) => setPriceInput(e.target.value)}
                    placeholder="Ex: 19,90"
                    className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-semibold tabular-nums focus:border-emerald-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="mb-1 block text-xs font-medium text-slate-700">
                    Cidade / Bairro
                  </label>
                  <input
                    type="text"
                    value={storeCity}
                    onChange={(e) => setStoreCity(e.target.value)}
                    placeholder="São Paulo, SP"
                    className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm focus:border-emerald-500 focus:outline-none"
                  />
                </div>
              </div>
            </div>

            <div className="flex flex-wrap items-center gap-3">
              <label className="inline-flex items-center gap-2 text-xs font-medium text-slate-700">
                <input
                  type="checkbox"
                  checked={isPromo}
                  onChange={(e) => setIsPromo(e.target.checked)}
                  className="h-4 w-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500"
                />
                Está em promoção / oferta
              </label>
              {isPromo && (
                <input
                  type="text"
                  value={promoLabel}
                  onChange={(e) => setPromoLabel(e.target.value)}
                  placeholder="Ex: Clube de descontos / Leve 3 pague 2"
                  className="flex-1 min-w-[200px] rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs focus:border-emerald-500 focus:outline-none"
                />
              )}
            </div>

            {submitError && (
              <p className="text-xs font-medium text-rose-600">{submitError}</p>
            )}

            <div className="flex justify-end gap-2">
              {detail.found && (
                <button
                  type="button"
                  onClick={() => setShowPriceForm(false)}
                  className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100"
                >
                  Cancelar
                </button>
              )}
              <button
                type="submit"
                disabled={submitting}
                className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-xs font-semibold text-white transition hover:bg-emerald-500 disabled:opacity-60"
              >
                {submitting && <Loader2 className="h-3.5 w-3.5 animate-spin" />}
                Salvar preço atual
              </button>
            </div>
          </form>
        )}
      </div>

      {detail.history.length > 0 && (
        <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-xs sm:p-5">
          <h3 className="text-sm font-semibold text-slate-900">
            Histórico recente de leituras de preço
          </h3>
          <div className="mt-3 divide-y divide-slate-100">
            {detail.history.slice(0, 8).map((entry) => (
              <div
                key={entry.id}
                className="flex items-center justify-between py-2 text-xs"
              >
                <div className="min-w-0">
                  <span className="font-medium text-slate-800">
                    {entry.storeName}
                  </span>
                  <span className="ml-2 text-slate-400">
                    {formatRelativeTimePt(entry.reportedAt)}
                  </span>
                  {entry.isPromo && (
                    <span className="ml-2 rounded bg-amber-100 px-1.5 py-0.5 text-[10px] font-semibold text-amber-800">
                      {entry.promoLabel || "Oferta"}
                    </span>
                  )}
                </div>
                <span className="font-semibold text-slate-900 tabular-nums">
                  {formatBrl(entry.priceCents)}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </section>
  );
}
