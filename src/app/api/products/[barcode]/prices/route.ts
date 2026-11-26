import { NextRequest, NextResponse } from "next/server";
import { normalizeBarcode } from "@/lib/price-provider";
import { recordCurrentPrice } from "@/lib/products-service";
import {
  checkRateLimit,
  getClientKey,
  isSameOriginRequest,
} from "@/lib/rate-limit";

export async function POST(
  request: NextRequest,
  context: { params: Promise<{ barcode: string }> },
) {
  try {
    if (!isSameOriginRequest(request)) {
      return NextResponse.json(
        { error: "Origem da requisição não permitida." },
        { status: 403 },
      );
    }

    const clientKey = `post-price:${getClientKey(request)}`;
    if (!checkRateLimit(clientKey, 20, 60_000)) {
      return NextResponse.json(
        { error: "Muitas atualizações seguidas. Aguarde um minuto e tente novamente." },
        { status: 429 },
      );
    }

    const contentLength = Number(request.headers.get("content-length") ?? "0");
    if (Number.isFinite(contentLength) && contentLength > 4096) {
      return NextResponse.json(
        { error: "Payload muito grande." },
        { status: 413 },
      );
    }

    const { barcode: rawBarcode } = await context.params;
    const barcode = normalizeBarcode(rawBarcode);
    if (!barcode) {
      return NextResponse.json(
        { error: "Código de barras inválido. Use entre 8 e 14 dígitos numéricos." },
        { status: 400 },
      );
    }

    const rawText = await request.text();
    if (rawText.length > 4096) {
      return NextResponse.json(
        { error: "Payload muito grande." },
        { status: 413 },
      );
    }

    let body: Record<string, unknown> | null = null;
    try {
      const parsed = JSON.parse(rawText) as unknown;
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        body = parsed as Record<string, unknown>;
      }
    } catch {
      body = null;
    }

    if (!body) {
      return NextResponse.json(
        { error: "Corpo da requisição inválido." },
        { status: 400 },
      );
    }

    const storeName = typeof body.storeName === "string" ? body.storeName : "";
    const storeCity = typeof body.storeCity === "string" ? body.storeCity : "";
    const priceCents =
      typeof body.priceCents === "number" ? body.priceCents : Number(body.priceCents);
    const isPromo = Boolean(body.isPromo);
    const promoLabel = typeof body.promoLabel === "string" ? body.promoLabel : "";
    const productName =
      typeof body.productName === "string" ? body.productName : undefined;
    const productBrand =
      typeof body.productBrand === "string" ? body.productBrand : undefined;
    const productCategory =
      typeof body.productCategory === "string" ? body.productCategory : undefined;
    const productUnitSize =
      typeof body.productUnitSize === "string" ? body.productUnitSize : undefined;

    const updated = await recordCurrentPrice({
      barcode,
      storeName,
      storeCity,
      priceCents,
      isPromo,
      promoLabel,
      productName,
      productBrand,
      productCategory,
      productUnitSize,
    });

    return NextResponse.json(updated, { status: 201 });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Erro ao registrar preço atual.";
    const isValidation =
      message.includes("Informe") || message.includes("inválido");
    return NextResponse.json(
      { error: message },
      { status: isValidation ? 400 : 500 },
    );
  }
}
