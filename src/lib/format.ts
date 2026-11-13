export function formatBrl(cents: number | null | undefined): string {
  if (cents === null || cents === undefined || !Number.isFinite(cents)) {
    return "—";
  }
  return new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
  }).format(cents / 100);
}

export function formatRelativeTimePt(isoDate: string | null | undefined): string {
  if (!isoDate) {
    return "sem registro";
  }
  const date = new Date(isoDate);
  if (Number.isNaN(date.getTime())) {
    return "recente";
  }
  const diffSeconds = Math.floor((Date.now() - date.getTime()) / 1000);
  if (diffSeconds < 60) {
    return "agora mesmo";
  }
  const diffMinutes = Math.floor(diffSeconds / 60);
  if (diffMinutes < 60) {
    return `há ${diffMinutes} min`;
  }
  const diffHours = Math.floor(diffMinutes / 60);
  if (diffHours < 24) {
    return `há ${diffHours} h`;
  }
  const diffDays = Math.floor(diffHours / 24);
  if (diffDays === 1) {
    return "há 1 dia";
  }
  if (diffDays < 30) {
    return `há ${diffDays} dias`;
  }
  return new Intl.DateTimeFormat("pt-BR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  }).format(date);
}

export function parseBrlInputToCents(raw: string): number | null {
  const cleaned = raw
    .replace(/[^\d.,]/g, "")
    .trim();
  if (!cleaned) {
    return null;
  }

  let normalized = cleaned;
  if (cleaned.includes(",") && cleaned.includes(".")) {
    normalized = cleaned.replace(/\./g, "").replace(",", ".");
  } else if (cleaned.includes(",")) {
    normalized = cleaned.replace(",", ".");
  }

  const parsed = Number.parseFloat(normalized);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return null;
  }
  return Math.round(parsed * 100);
}
