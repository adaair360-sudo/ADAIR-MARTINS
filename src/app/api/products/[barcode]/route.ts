import { NextRequest, NextResponse } from "next/server";
import { normalizeBarcode } from "@/lib/price-provider";
import { getProductByBarcode } from "@/lib/products-service";
import { checkRateLimit, getClientKey } from "@/lib/rate-limit";

export async function GET(
  request: NextRequest,
  context: { params: Promise<{ barcode: string }> },
) {
  try {
    const clientKey = `get-barcode:${getClientKey(request)}`;
    if (!checkRateLimit(clientKey, 60, 60_000)) {
      return NextResponse.json(
        { error: "Muitas consultas em sequência. Aguarde alguns segundos." },
        { status: 429 },
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

    const detail = await getProductByBarcode(barcode);
    return NextResponse.json(detail);
  } catch (error) {
    console.error("Failed to read product by barcode", error);
    return NextResponse.json(
      { error: "Erro ao consultar código de barras." },
      { status: 500 },
    );
  }
}
