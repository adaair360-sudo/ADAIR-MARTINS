import { NextRequest, NextResponse } from "next/server";
import { listCatalogProducts } from "@/lib/products-service";

export async function GET(request: NextRequest) {
  try {
    const query = request.nextUrl.searchParams.get("q") ?? "";
    const products = await listCatalogProducts(query);
    return NextResponse.json({ products });
  } catch (error) {
    console.error("Failed to list products", error);
    return NextResponse.json(
      { error: "Não foi possível carregar os produtos." },
      { status: 500 },
    );
  }
}
