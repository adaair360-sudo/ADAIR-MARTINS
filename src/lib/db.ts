import { readdir, readFile } from "node:fs/promises";
import { PGlite } from "@electric-sql/pglite";
import pg from "pg";

const databaseUrl = process.env.DATABASE_URL?.trim() ?? "";

declare global {
  var __precofacilPool: pg.Pool | undefined;
  var __precofacilLocalDb: Promise<PGlite> | undefined;
}

export async function sql<T = Record<string, unknown>>(
  text: string,
  params: unknown[] = [],
): Promise<T[]> {
  if (databaseUrl !== "") {
    globalThis.__precofacilPool ??= new pg.Pool({
      connectionString: databaseUrl,
      max: 5,
    });
    return (await globalThis.__precofacilPool.query(text, params)).rows as T[];
  }

  globalThis.__precofacilLocalDb ??= startLocal().catch((error: unknown) => {
    globalThis.__precofacilLocalDb = undefined;
    throw error;
  });

  return (await (await globalThis.__precofacilLocalDb).query<T>(text, params)).rows;
}

async function startLocal(): Promise<PGlite> {
  const db = new PGlite();
  const files = (await readdir("migrations").catch(() => []))
    .filter((f) => f.endsWith(".sql"))
    .sort();
  for (const file of files) {
    await db.exec(await readFile(`migrations/${file}`, "utf8"));
  }
  return db;
}
