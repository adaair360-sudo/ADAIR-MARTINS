import { ScannerApp } from "@/components/ScannerApp";
import { getProductByBarcode, listCatalogProducts } from "@/lib/products-service";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const initialCatalog = await listCatalogProducts();
  const firstBarcode = initialCatalog[0]?.barcode ?? "7896006711117";
  const initialDetail = await getProductByBarcode(firstBarcode).catch(() => null);

  return (
    <ScannerApp
      initialCatalog={initialCatalog}
      initialDetail={initialDetail}
    />
  );
}
