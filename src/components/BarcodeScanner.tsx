"use client";

import React, { useCallback, useEffect, useRef, useState } from "react";
import { BrowserMultiFormatReader, type IScannerControls } from "@zxing/browser";
import { BarcodeFormat, DecodeHintType } from "@zxing/library";
import {
  Camera,
  CameraOff,
  Flashlight,
  ImageUp,
  Keyboard,
  Loader2,
  ScanBarcode,
  Volume2,
  VolumeX,
} from "lucide-react";

type ScanTab = "camera" | "image" | "manual";

interface BarcodeScannerProps {
  activeBarcode: string;
  loading: boolean;
  quickSamples: Array<{
    barcode: string;
    name: string;
    bestPriceCents: number | null;
  }>;
  onScanBarcode: (barcode: string) => void;
}

function createBarcodeReader(): BrowserMultiFormatReader {
  const hints = new Map();
  hints.set(DecodeHintType.POSSIBLE_FORMATS, [
    BarcodeFormat.EAN_13,
    BarcodeFormat.EAN_8,
    BarcodeFormat.UPC_A,
    BarcodeFormat.UPC_E,
    BarcodeFormat.CODE_128,
    BarcodeFormat.CODE_39,
    BarcodeFormat.ITF,
  ]);
  hints.set(DecodeHintType.TRY_HARDER, true);
  return new BrowserMultiFormatReader(hints);
}

function playBeep() {
  try {
    const AudioCtx =
      window.AudioContext ||
      (window as unknown as { webkitAudioContext?: typeof AudioContext })
        .webkitAudioContext;
    if (!AudioCtx) return;
    const ctx = new AudioCtx();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(1046.5, ctx.currentTime);
    gain.gain.setValueAtTime(0.08, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.14);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + 0.14);
    window.setTimeout(() => {
      void ctx.close().catch(() => undefined);
    }, 250);
  } catch {
    // Ignore audio context restrictions
  }
}

export function BarcodeScanner({
  activeBarcode,
  loading,
  quickSamples,
  onScanBarcode,
}: BarcodeScannerProps) {
  const [tab, setTab] = useState<ScanTab>("camera");
  const [manualInput, setManualInput] = useState(activeBarcode);
  const [manualError, setManualError] = useState<string | null>(null);

  const [cameraActive, setCameraActive] = useState(false);
  const [cameraStarting, setCameraStarting] = useState(false);
  const [cameraError, setCameraError] = useState<string | null>(null);
  const [devices, setDevices] = useState<MediaDeviceInfo[]>([]);
  const [selectedDeviceId, setSelectedDeviceId] = useState<string>("");
  const [torchSupported, setTorchSupported] = useState(false);
  const [torchOn, setTorchOn] = useState(false);
  const [soundEnabled, setSoundEnabled] = useState(true);

  const [imageLoading, setImageLoading] = useState(false);
  const [imageMessage, setImageMessage] = useState<string | null>(null);
  const [imagePreviewUrl, setImagePreviewUrl] = useState<string | null>(null);

  const videoRef = useRef<HTMLVideoElement | null>(null);
  const controlsRef = useRef<IScannerControls | null>(null);
  const lastScannedRef = useRef<{ code: string; time: number }>({
    code: "",
    time: 0,
  });
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    setManualInput(activeBarcode);
  }, [activeBarcode]);

  const stopCamera = useCallback(() => {
    if (controlsRef.current) {
      try {
        controlsRef.current.stop();
      } catch {
        // ignore
      }
      controlsRef.current = null;
    }
    const videoEl = videoRef.current;
    if (videoEl?.srcObject) {
      const stream = videoEl.srcObject as MediaStream;
      for (const track of stream.getTracks()) {
        track.stop();
      }
      videoEl.srcObject = null;
    }
    setCameraActive(false);
    setCameraStarting(false);
    setTorchOn(false);
    setTorchSupported(false);
  }, []);

  useEffect(() => {
    return () => {
      stopCamera();
    };
  }, [stopCamera]);

  useEffect(() => {
    if (tab !== "camera" && cameraActive) {
      stopCamera();
    }
  }, [tab, cameraActive, stopCamera]);

  const handleDetectedCode = useCallback(
    (rawText: string) => {
      const cleaned = rawText.replace(/\s+/g, "").trim();
      if (!/^\d{8,14}$/.test(cleaned)) {
        return;
      }
      const now = Date.now();
      if (
        lastScannedRef.current.code === cleaned &&
        now - lastScannedRef.current.time < 2200
      ) {
        return;
      }
      lastScannedRef.current = { code: cleaned, time: now };
      if (soundEnabled) {
        playBeep();
      }
      setManualInput(cleaned);
      onScanBarcode(cleaned);
    },
    [onScanBarcode, soundEnabled],
  );

  const startCamera = useCallback(
    async (explicitDeviceId?: string) => {
      setCameraError(null);
      setCameraStarting(true);
      stopCamera();

      try {
        if (!navigator.mediaDevices?.getUserMedia) {
          throw new Error(
            "Este navegador não suporta acesso à câmera. Use a aba Foto ou Digitar.",
          );
        }

        const reader = createBarcodeReader();
        const videoDevices = await BrowserMultiFormatReader.listVideoInputDevices();
        setDevices(videoDevices);

        let deviceId = explicitDeviceId ?? selectedDeviceId;
        if (!deviceId && videoDevices.length > 0) {
          const rearCamera = videoDevices.find((d) =>
            /back|rear|traseira|environment/i.test(d.label),
          );
          deviceId = rearCamera?.deviceId ?? videoDevices[0].deviceId;
          setSelectedDeviceId(deviceId);
        }

        const videoEl = videoRef.current;
        if (!videoEl) {
          throw new Error("Elemento de vídeo não inicializado.");
        }

        const controls = await reader.decodeFromVideoDevice(
          deviceId || undefined,
          videoEl,
          (result) => {
            if (result) {
              handleDetectedCode(result.getText());
            }
          },
        );

        controlsRef.current = controls;
        setCameraActive(true);
        setCameraStarting(false);

        const stream = videoEl.srcObject as MediaStream | null;
        const track = stream?.getVideoTracks()[0];
        const caps = track?.getCapabilities?.() as
          | (MediaTrackCapabilities & { torch?: boolean })
          | undefined;
        setTorchSupported(Boolean(caps?.torch));
      } catch (err) {
        stopCamera();
        const msg =
          err instanceof Error
            ? err.message
            : "Não foi possível iniciar a câmera.";
        if (/permission|denied|notallowed/i.test(msg)) {
          setCameraError(
            "Permissão de câmera negada. Autorize a câmera no navegador ou envie uma foto na aba ao lado.",
          );
        } else if (/notfound|device/i.test(msg)) {
          setCameraError(
            "Nenhuma câmera encontrada neste dispositivo. Use a aba Foto do Código ou Digitar.",
          );
        } else {
          setCameraError(msg);
        }
      }
    },
    [handleDetectedCode, selectedDeviceId, stopCamera],
  );

  const toggleTorch = async () => {
    const videoEl = videoRef.current;
    const stream = videoEl?.srcObject as MediaStream | null;
    const track = stream?.getVideoTracks()[0];
    if (!track) return;
    const nextState = !torchOn;
    try {
      await track.applyConstraints({
        advanced: [{ torch: nextState } as MediaTrackConstraintSet],
      });
      setTorchOn(nextState);
    } catch {
      setTorchSupported(false);
    }
  };

  const handleImageFile = async (file: File) => {
    setImageLoading(true);
    setImageMessage(null);

    const objectUrl = URL.createObjectURL(file);
    setImagePreviewUrl((prev) => {
      if (prev) URL.revokeObjectURL(prev);
      return objectUrl;
    });

    try {
      let decodedText: string | null = null;

      if ("BarcodeDetector" in window) {
        try {
          const DetectorCtor = (
            window as unknown as {
              BarcodeDetector: new (opts?: { formats: string[] }) => {
                detect: (
                  img: ImageBitmap,
                ) => Promise<Array<{ rawValue?: string }>>;
              };
            }
          ).BarcodeDetector;
          const detector = new DetectorCtor({
            formats: ["ean_13", "ean_8", "upc_a", "upc_e", "code_128", "code_39"],
          });
          const bitmap = await createImageBitmap(file);
          const barcodes = await detector.detect(bitmap);
          bitmap.close();
          if (barcodes.length > 0 && barcodes[0].rawValue) {
            decodedText = barcodes[0].rawValue;
          }
        } catch {
          // fallback to ZXing
        }
      }

      if (!decodedText) {
        const reader = createBarcodeReader();
        const result = await reader.decodeFromImageUrl(objectUrl);
        decodedText = result.getText();
      }

      const cleaned = decodedText.replace(/\s+/g, "").trim();
      if (!/^\d{8,14}$/.test(cleaned)) {
        setImageMessage(
          `Código lido (${decodedText}), mas não parece um código EAN/UPC de produto (8 a 14 dígitos).`,
        );
      } else {
        setImageMessage(`Código identificado: ${cleaned}`);
        if (soundEnabled) playBeep();
        setManualInput(cleaned);
        onScanBarcode(cleaned);
      }
    } catch {
      setImageMessage(
        "Não foi possível localizar um código de barras nítido nessa imagem. Tente aproximar o código com boa iluminação.",
      );
    } finally {
      setImageLoading(false);
    }
  };

  const handleManualSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const cleaned = manualInput.replace(/\s+/g, "").trim();
    if (!/^\d{8,14}$/.test(cleaned)) {
      setManualError("Digite um código de barras válido com 8 a 14 números.");
      return;
    }
    setManualError(null);
    onScanBarcode(cleaned);
  };

  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-4 shadow-xs sm:p-5">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2.5">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-50 text-emerald-700">
            <ScanBarcode className="h-5 w-5" />
          </div>
          <div>
            <h2 className="text-base font-semibold text-slate-900">
              Leitor de Código de Barras
            </h2>
            <p className="text-xs text-slate-500">
              EAN-13, EAN-8, UPC e Code-128 para consulta instantânea de preço
            </p>
          </div>
        </div>

        <button
          type="button"
          onClick={() => setSoundEnabled((prev) => !prev)}
          className="inline-flex items-center gap-1.5 rounded-lg border border-slate-200 px-2.5 py-1.5 text-xs font-medium text-slate-600 transition hover:bg-slate-50"
          title={soundEnabled ? "Silenciar bipe" : "Ativar bipe"}
        >
          {soundEnabled ? (
            <>
              <Volume2 className="h-3.5 w-3.5 text-emerald-600" />
              Bipe ativo
            </>
          ) : (
            <>
              <VolumeX className="h-3.5 w-3.5 text-slate-400" />
              Sem som
            </>
          )}
        </button>
      </div>

      <div className="mb-4 grid grid-cols-3 gap-1.5 rounded-xl bg-slate-100 p-1">
        <button
          type="button"
          onClick={() => setTab("camera")}
          className={`flex items-center justify-center gap-1.5 rounded-lg px-3 py-2 text-xs font-semibold transition sm:text-sm ${
            tab === "camera"
              ? "bg-white text-emerald-700 shadow-xs"
              : "text-slate-600 hover:text-slate-900"
          }`}
        >
          <Camera className="h-4 w-4" />
          <span>Câmera</span>
        </button>
        <button
          type="button"
          onClick={() => setTab("image")}
          className={`flex items-center justify-center gap-1.5 rounded-lg px-3 py-2 text-xs font-semibold transition sm:text-sm ${
            tab === "image"
              ? "bg-white text-emerald-700 shadow-xs"
              : "text-slate-600 hover:text-slate-900"
          }`}
        >
          <ImageUp className="h-4 w-4" />
          <span>Foto</span>
        </button>
        <button
          type="button"
          onClick={() => setTab("manual")}
          className={`flex items-center justify-center gap-1.5 rounded-lg px-3 py-2 text-xs font-semibold transition sm:text-sm ${
            tab === "manual"
              ? "bg-white text-emerald-700 shadow-xs"
              : "text-slate-600 hover:text-slate-900"
          }`}
        >
          <Keyboard className="h-4 w-4" />
          <span>Digitar</span>
        </button>
      </div>

      {tab === "camera" && (
        <div className="space-y-3">
          <div className="relative overflow-hidden rounded-xl border border-slate-200 bg-slate-950">
            <video
              ref={videoRef}
              className="aspect-[16/10] w-full object-cover"
              playsInline
              muted
            />

            {!cameraActive && !cameraStarting && (
              <div className="absolute inset-0 flex flex-col items-center justify-center bg-slate-900/90 p-5 text-center text-white">
                <div className="mb-3 flex h-12 w-12 items-center justify-center rounded-full bg-emerald-500/20 text-emerald-400">
                  <Camera className="h-6 w-6" />
                </div>
                <p className="text-sm font-medium">
                  Aponte a câmera para o código de barras do produto
                </p>
                <p className="mt-1 max-w-xs text-xs text-slate-300">
                  A leitura é automática e exibe na hora os preços atuais nos supermercados.
                </p>
                <button
                  type="button"
                  onClick={() => void startCamera()}
                  className="mt-4 inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-emerald-500"
                >
                  <Camera className="h-4 w-4" />
                  Ativar Câmera
                </button>
              </div>
            )}

            {cameraStarting && (
              <div className="absolute inset-0 flex flex-col items-center justify-center bg-slate-900/85 text-white">
                <Loader2 className="h-7 w-7 animate-spin text-emerald-400" />
                <p className="mt-2 text-xs font-medium text-slate-200">
                  Abrindo câmera...
                </p>
              </div>
            )}

            {cameraActive && (
              <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
                <div className="relative h-32 w-64 rounded-xl border-2 border-emerald-400/90 shadow-[0_0_0_9999px_rgba(15,23,42,0.38)]">
                  <div className="animate-scan-sweep absolute right-2 left-2 h-0.5 rounded-full bg-emerald-400 shadow-[0_0_10px_#34d399]" />
                </div>
              </div>
            )}
          </div>

          {cameraError && (
            <div className="rounded-xl border border-amber-200 bg-amber-50 px-3.5 py-2.5 text-xs text-amber-900">
              {cameraError}
            </div>
          )}

          {cameraActive && (
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="flex flex-wrap items-center gap-2">
                <button
                  type="button"
                  onClick={stopCamera}
                  className="inline-flex items-center gap-1.5 rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-50"
                >
                  <CameraOff className="h-3.5 w-3.5 text-rose-500" />
                  Parar câmera
                </button>

                {torchSupported && (
                  <button
                    type="button"
                    onClick={() => void toggleTorch()}
                    className={`inline-flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-semibold transition ${
                      torchOn
                        ? "border-amber-300 bg-amber-50 text-amber-800"
                        : "border-slate-200 bg-white text-slate-700 hover:bg-slate-50"
                    }`}
                  >
                    <Flashlight className="h-3.5 w-3.5" />
                    {torchOn ? "Flash ligado" : "Ligar flash"}
                  </button>
                )}
              </div>

              {devices.length > 1 && (
                <select
                  aria-label="Selecionar câmera"
                  value={selectedDeviceId}
                  onChange={(e) => {
                    const nextId = e.target.value;
                    setSelectedDeviceId(nextId);
                    void startCamera(nextId);
                  }}
                  className="rounded-lg border border-slate-200 bg-white px-2.5 py-1.5 text-xs text-slate-700"
                >
                  {devices.map((d, idx) => (
                    <option key={d.deviceId} value={d.deviceId}>
                      {d.label || `Câmera ${idx + 1}`}
                    </option>
                  ))}
                </select>
              )}
            </div>
          )}
        </div>
      )}

      {tab === "image" && (
        <div className="space-y-3">
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) {
                void handleImageFile(file);
              }
            }}
          />

          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            onDragOver={(e) => e.preventDefault()}
            onDrop={(e) => {
              e.preventDefault();
              const file = e.dataTransfer.files?.[0];
              if (file) {
                void handleImageFile(file);
              }
            }}
            className="flex w-full flex-col items-center justify-center rounded-xl border-2 border-dashed border-slate-300 bg-slate-50 px-4 py-7 text-center transition hover:border-emerald-400 hover:bg-emerald-50/40"
          >
            {imageLoading ? (
              <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
            ) : (
              <ImageUp className="h-8 w-8 text-emerald-600" />
            )}
            <span className="mt-2 text-sm font-semibold text-slate-800">
              {imageLoading
                ? "Lendo código de barras da imagem..."
                : "Enviar ou arrastar foto do código de barras"}
            </span>
            <span className="mt-1 text-xs text-slate-500">
              Aceita PNG, JPG ou WebP tirada da embalagem do produto
            </span>
          </button>

          {imagePreviewUrl && (
            <div className="flex items-center gap-3 rounded-xl border border-slate-200 bg-slate-50 p-2.5">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={imagePreviewUrl}
                alt="Prévia da foto enviada"
                className="h-14 w-20 rounded-lg border border-slate-200 bg-white object-contain"
              />
              <p className="text-xs text-slate-600">
                {imageMessage ?? "Imagem carregada."}
              </p>
            </div>
          )}

          {!imagePreviewUrl && imageMessage && (
            <div className="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-xs text-slate-700">
              {imageMessage}
            </div>
          )}
        </div>
      )}

      {tab === "manual" && (
        <form onSubmit={handleManualSubmit} className="space-y-3">
          <div>
            <label
              htmlFor="manual-barcode-input"
              className="mb-1.5 block text-xs font-medium text-slate-700"
            >
              Digite ou cole os números abaixo das barras (EAN-13 / EAN-8 / UPC)
            </label>
            <div className="flex gap-2">
              <input
                id="manual-barcode-input"
                type="text"
                inputMode="numeric"
                value={manualInput}
                onChange={(e) => {
                  setManualInput(e.target.value);
                  setManualError(null);
                }}
                placeholder="Ex: 7896006711117"
                className="w-full rounded-xl border border-slate-300 bg-white px-3.5 py-2.5 font-mono text-sm text-slate-900 placeholder:text-slate-400 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 focus:outline-none"
              />
              <button
                type="submit"
                disabled={loading}
                className="inline-flex shrink-0 items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-emerald-500 disabled:opacity-60"
              >
                {loading ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <ScanBarcode className="h-4 w-4" />
                )}
                Consultar
              </button>
            </div>
            {manualError && (
              <p className="mt-1.5 text-xs text-rose-600">{manualError}</p>
            )}
          </div>
        </form>
      )}

      <div className="mt-4 border-t border-slate-100 pt-3.5">
        <p className="mb-2 text-xs font-semibold tracking-wide text-slate-500 uppercase">
          Teste rápido — Clique em um produto para ler código e preço atual
        </p>
        <div className="flex flex-wrap gap-1.5">
          {quickSamples.slice(0, 6).map((item) => {
            const selected = item.barcode === activeBarcode;
            return (
              <button
                key={item.barcode}
                type="button"
                onClick={() => {
                  setManualInput(item.barcode);
                  onScanBarcode(item.barcode);
                }}
                className={`rounded-lg border px-2.5 py-1.5 text-left text-xs transition ${
                  selected
                    ? "border-emerald-500 bg-emerald-50 font-semibold text-emerald-900"
                    : "border-slate-200 bg-slate-50 text-slate-700 hover:border-slate-300 hover:bg-white"
                }`}
              >
                <span className="block max-w-[165px] truncate">{item.name}</span>
                <span className="font-mono text-[11px] text-slate-500">
                  {item.barcode}
                </span>
              </button>
            );
          })}
        </div>
      </div>
    </section>
  );
}
