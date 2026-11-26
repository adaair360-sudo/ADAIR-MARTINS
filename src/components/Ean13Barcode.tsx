"use client";

import React from "react";

const L_CODES = [
  "0001101",
  "0011001",
  "0010011",
  "0111101",
  "0100011",
  "0110001",
  "0101111",
  "0111011",
  "0110111",
  "0001011",
];

const G_CODES = [
  "0100111",
  "0110011",
  "0011011",
  "0100001",
  "0011101",
  "0111001",
  "0000101",
  "0010001",
  "0001001",
  "0010111",
];

const R_CODES = [
  "1110010",
  "1100110",
  "1101100",
  "1000010",
  "1011100",
  "1001110",
  "1010000",
  "1000100",
  "1001000",
  "1110100",
];

const PARITY_PATTERNS = [
  "LLLLLL",
  "LLGLGG",
  "LLGGLG",
  "LLGGGL",
  "LGLLGG",
  "LGGLLG",
  "LGGGLL",
  "LGLGLG",
  "LGLGGL",
  "LGGLGL",
];

function encodeEan13Bits(code: string): string | null {
  if (!/^\d{13}$/.test(code)) {
    return null;
  }
  const digits = code.split("").map(Number);
  const parity = PARITY_PATTERNS[digits[0]];
  let bits = "101";

  for (let i = 1; i <= 6; i++) {
    const d = digits[i];
    bits += parity[i - 1] === "L" ? L_CODES[d] : G_CODES[d];
  }

  bits += "01010";

  for (let i = 7; i <= 12; i++) {
    bits += R_CODES[digits[i]];
  }

  bits += "101";
  return bits;
}

export function Ean13Barcode({
  code,
  className = "",
}: {
  code: string;
  className?: string;
}) {
  const bits = encodeEan13Bits(code);

  if (!bits) {
    return (
      <div
        className={`inline-flex flex-col items-center rounded-lg border border-slate-200 bg-white px-3 py-2 ${className}`}
      >
        <span className="font-mono text-xs font-semibold tracking-widest text-slate-700">
          {code}
        </span>
      </div>
    );
  }

  const barWidth = 2;
  const quietZone = 14;
  const width = bits.length * barWidth + quietZone * 2;
  const height = 64;

  const rects: Array<{ x: number; h: number }> = [];
  for (let i = 0; i < bits.length; i++) {
    if (bits[i] === "1") {
      const isGuard =
        i < 3 || (i >= 45 && i < 50) || i >= bits.length - 3;
      rects.push({
        x: quietZone + i * barWidth,
        h: isGuard ? 48 : 42,
      });
    }
  }

  return (
    <div
      className={`inline-flex flex-col items-center rounded-xl border border-slate-200 bg-white px-3 py-2 shadow-xs ${className}`}
    >
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="h-14 w-44"
        role="img"
        aria-label={`Código de barras EAN-13 ${code}`}
      >
        <rect x="0" y="0" width={width} height={height} fill="#ffffff" />
        {rects.map((r) => (
          <rect
            key={r.x}
            x={r.x}
            y={4}
            width={barWidth}
            height={r.h}
            fill="#0f172a"
          />
        ))}
        <text
          x={5}
          y={59}
          fontSize="10"
          fontFamily="monospace"
          fill="#0f172a"
          fontWeight="600"
        >
          {code[0]}
        </text>
        <text
          x={26}
          y={59}
          fontSize="10"
          fontFamily="monospace"
          fill="#0f172a"
          fontWeight="600"
          letterSpacing="1.6"
        >
          {code.slice(1, 7)}
        </text>
        <text
          x={116}
          y={59}
          fontSize="10"
          fontFamily="monospace"
          fill="#0f172a"
          fontWeight="600"
          letterSpacing="1.6"
        >
          {code.slice(7, 13)}
        </text>
      </svg>
    </div>
  );
}
