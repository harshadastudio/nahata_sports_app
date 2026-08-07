import React, { useCallback, useEffect, useRef, useState } from 'react';
import jsQR from 'jsqr';
import {
  Camera,
  CameraOff,
  RefreshCcw,
  Zap,
  ZapOff,
  Loader2,
  AlertTriangle,
  SwitchCamera,
} from 'lucide-react';

/**
 * QrCameraScanner — live QR scanning from the device camera.
 *
 * Uses the browser's native BarcodeDetector when available (Chrome/Edge/Android,
 * hardware accelerated) and falls back to the pure-JS jsQR decoder everywhere
 * else (Safari/Firefox), so the same component works on a guard's phone, a
 * tablet at the gate, or a desktop webcam.
 *
 * The camera stream is kept alive while `paused` is true — only decoding stops —
 * so the preview does not flicker between scans.
 */

type ScannerStatus = 'idle' | 'starting' | 'scanning' | 'error';

export interface QrCameraScannerProps {
  /** Called with the raw decoded text of a QR code. */
  onDetected: (text: string) => void;
  /** When true the preview keeps running but decoding is skipped. */
  paused?: boolean;
  /** Ignore a repeat of the same code within this many ms. */
  dedupeMs?: number;
  /** Change this value to forget the last scanned code (allows an immediate re-scan). */
  resetSignal?: number;
  /** Request the camera as soon as the component mounts. */
  autoStart?: boolean;
  className?: string;
}

/** Longest edge fed to jsQR — bigger frames cost CPU without helping accuracy. */
const MAX_DECODE_WIDTH = 640;
/** Decode at most ~12fps; the camera still previews at full frame rate. */
const DECODE_INTERVAL_MS = 80;
/** Give up on BarcodeDetector after this many consecutive failures. */
const DETECTOR_ERROR_LIMIT = 5;

function describeCameraError(err: any): string {
  switch (err?.name) {
    case 'NotAllowedError':
    case 'SecurityError':
      return 'Camera permission was denied. Allow camera access for this site in your browser settings, then press Retry.';
    case 'NotFoundError':
    case 'DevicesNotFoundError':
      return 'No camera was found on this device. Connect a camera or type the pass code manually.';
    case 'NotReadableError':
    case 'TrackStartError':
      return 'The camera is already in use by another app or tab. Close it and press Retry.';
    case 'OverconstrainedError':
      return 'The selected camera is not available. Pick a different camera and try again.';
    default:
      return err?.message
        ? `Could not start the camera: ${err.message}`
        : 'Could not start the camera. Please try again.';
  }
}

export const QrCameraScanner: React.FC<QrCameraScannerProps> = ({
  onDetected,
  paused = false,
  dedupeMs = 3000,
  resetSignal = 0,
  autoStart = true,
  className = '',
}) => {
  const [status, setStatus] = useState<ScannerStatus>('idle');
  const [error, setError] = useState('');
  const [devices, setDevices] = useState<MediaDeviceInfo[]>([]);
  const [activeDeviceId, setActiveDeviceId] = useState('');
  const [torchSupported, setTorchSupported] = useState(false);
  const [torchOn, setTorchOn] = useState(false);
  const [flash, setFlash] = useState(false);
  const [usingNative, setUsingNative] = useState(false);

  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const rafRef = useRef<number | null>(null);
  const runningRef = useRef(false);
  const detectorRef = useRef<any>(null);
  const detectorErrorsRef = useRef(0);
  const lastDecodeRef = useRef(0);
  const lastTextRef = useRef('');
  const lastTextAtRef = useRef(0);
  const flashTimerRef = useRef<number | null>(null);
  /** Guards against two overlapping start() calls leaving a camera stream running. */
  const startTokenRef = useRef(0);

  // Keep callback + paused in refs so the decode loop never has to restart.
  const onDetectedRef = useRef(onDetected);
  const pausedRef = useRef(paused);
  useEffect(() => { onDetectedRef.current = onDetected; }, [onDetected]);
  useEffect(() => { pausedRef.current = paused; }, [paused]);

  // Parent asked us to forget the last code so the same badge can be re-scanned.
  useEffect(() => {
    lastTextRef.current = '';
    lastTextAtRef.current = 0;
  }, [resetSignal]);

  // ── Decoding ────────────────────────────────────────────────────────────────

  const decodeFrame = useCallback(async (video: HTMLVideoElement): Promise<string | null> => {
    const detector = detectorRef.current;
    if (detector) {
      try {
        const codes = await detector.detect(video);
        detectorErrorsRef.current = 0;
        return codes?.[0]?.rawValue || null;
      } catch {
        // Some devices expose BarcodeDetector but fail on every frame —
        // drop it and let jsQR take over for the rest of the session.
        detectorErrorsRef.current += 1;
        if (detectorErrorsRef.current >= DETECTOR_ERROR_LIMIT) {
          detectorRef.current = null;
          setUsingNative(false);
        }
        return null;
      }
    }

    const vw = video.videoWidth;
    const vh = video.videoHeight;
    if (!vw || !vh) return null;

    if (!canvasRef.current) canvasRef.current = document.createElement('canvas');
    const canvas = canvasRef.current;
    const scale = Math.min(1, MAX_DECODE_WIDTH / vw);
    const w = Math.round(vw * scale);
    const h = Math.round(vh * scale);
    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
    }

    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    if (!ctx) return null;
    ctx.drawImage(video, 0, 0, w, h);
    const frame = ctx.getImageData(0, 0, w, h);
    const result = jsQR(frame.data, w, h, { inversionAttempts: 'dontInvert' });
    return result?.data ?? null;
  }, []);

  const emit = useCallback((text: string) => {
    const now = performance.now();
    if (text === lastTextRef.current && now - lastTextAtRef.current < dedupeMs) return;
    lastTextRef.current = text;
    lastTextAtRef.current = now;

    setFlash(true);
    if (flashTimerRef.current) window.clearTimeout(flashTimerRef.current);
    flashTimerRef.current = window.setTimeout(() => setFlash(false), 300);

    onDetectedRef.current(text);
  }, [dedupeMs]);

  const tick = useCallback(async () => {
    if (!runningRef.current) return;
    const video = videoRef.current;

    if (video && video.readyState >= 2 && !pausedRef.current) {
      const now = performance.now();
      if (now - lastDecodeRef.current >= DECODE_INTERVAL_MS) {
        lastDecodeRef.current = now;
        try {
          const text = await decodeFrame(video);
          if (text) emit(text);
        } catch {
          // A single bad frame is never fatal — keep scanning.
        }
      }
    }

    if (!runningRef.current) return;
    rafRef.current = requestAnimationFrame(() => { void tick(); });
  }, [decodeFrame, emit]);

  // ── Camera lifecycle ────────────────────────────────────────────────────────

  const stopStream = useCallback(() => {
    // Invalidate any start() still awaiting getUserMedia.
    startTokenRef.current += 1;
    runningRef.current = false;
    if (rafRef.current !== null) {
      cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
    }
    streamRef.current?.getTracks().forEach((track) => track.stop());
    streamRef.current = null;
    const video = videoRef.current;
    if (video) video.srcObject = null;
    setTorchOn(false);
    setTorchSupported(false);
  }, []);

  const start = useCallback(async (preferredId?: string) => {
    setError('');
    setStatus('starting');

    if (typeof navigator === 'undefined' || !navigator.mediaDevices?.getUserMedia) {
      setStatus('error');
      setError(
        typeof window !== 'undefined' && window.isSecureContext === false
          ? 'Camera access requires a secure connection. Open this page over HTTPS (or on localhost) and try again.'
          : 'This browser does not support camera access. Use Chrome, Edge or Safari, or type the pass code manually.'
      );
      return;
    }

    stopStream();
    const token = ++startTokenRef.current;

    const buildConstraints = (deviceId?: string): MediaStreamConstraints => ({
      audio: false,
      video: deviceId
        ? { deviceId: { exact: deviceId }, width: { ideal: 1280 }, height: { ideal: 720 } }
        : { facingMode: { ideal: 'environment' }, width: { ideal: 1280 }, height: { ideal: 720 } },
    });

    let stream: MediaStream;
    try {
      stream = await navigator.mediaDevices.getUserMedia(buildConstraints(preferredId));
    } catch (err: any) {
      // A remembered device can disappear (unplugged webcam) — retry with any camera.
      if (preferredId && (err?.name === 'OverconstrainedError' || err?.name === 'NotFoundError')) {
        try {
          stream = await navigator.mediaDevices.getUserMedia(buildConstraints());
        } catch (retryErr: any) {
          setStatus('error');
          setError(describeCameraError(retryErr));
          return;
        }
      } else {
        setStatus('error');
        setError(describeCameraError(err));
        return;
      }
    }

    const video = videoRef.current;
    // A newer start()/stop() won the race, or we unmounted — release this stream
    // instead of leaving the camera light on.
    if (!video || token !== startTokenRef.current) {
      stream.getTracks().forEach((t) => t.stop());
      return;
    }

    streamRef.current = stream;
    video.srcObject = stream;
    try {
      await video.play();
    } catch {
      // Autoplay can be rejected until the user interacts; the preview still
      // renders once the stream produces frames.
    }

    const track = stream.getVideoTracks()[0];
    const capabilities: any = track?.getCapabilities?.() ?? {};
    setTorchSupported(Boolean(capabilities.torch));
    setActiveDeviceId(track?.getSettings?.().deviceId ?? preferredId ?? '');

    // Labels are only populated once permission has been granted.
    try {
      const all = await navigator.mediaDevices.enumerateDevices();
      setDevices(all.filter((d) => d.kind === 'videoinput'));
    } catch {
      setDevices([]);
    }

    // Prefer the native detector; it is both faster and more tolerant of angle.
    if (!detectorRef.current && typeof window !== 'undefined' && 'BarcodeDetector' in window) {
      try {
        const Detector = (window as any).BarcodeDetector;
        const formats: string[] = await Detector.getSupportedFormats();
        if (formats.includes('qr_code')) {
          detectorRef.current = new Detector({ formats: ['qr_code'] });
          detectorErrorsRef.current = 0;
          setUsingNative(true);
        }
      } catch {
        detectorRef.current = null;
      }
    }

    // Bail if the camera was stopped/switched while we were awaiting above.
    if (token !== startTokenRef.current) return;

    setStatus('scanning');
    runningRef.current = true;
    lastDecodeRef.current = 0;
    rafRef.current = requestAnimationFrame(() => { void tick(); });
  }, [stopStream, tick]);

  const stop = useCallback(() => {
    stopStream();
    setStatus('idle');
    setError('');
  }, [stopStream]);

  const switchCamera = useCallback(() => {
    if (devices.length < 2) return;
    const currentIndex = devices.findIndex((d) => d.deviceId === activeDeviceId);
    const next = devices[(currentIndex + 1) % devices.length];
    if (next) void start(next.deviceId);
  }, [devices, activeDeviceId, start]);

  const toggleTorch = useCallback(async () => {
    const track = streamRef.current?.getVideoTracks()[0];
    if (!track) return;
    try {
      await track.applyConstraints({ advanced: [{ torch: !torchOn }] } as any);
      setTorchOn((v) => !v);
    } catch {
      setTorchSupported(false);
    }
  }, [torchOn]);

  useEffect(() => {
    if (autoStart) void start();
    return () => {
      stopStream();
      if (flashTimerRef.current) window.clearTimeout(flashTimerRef.current);
    };
    // Mount-only: start()/stopStream() are stable and re-running this would
    // tear the camera down on every render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const isLive = status === 'scanning';

  // ── Render ──────────────────────────────────────────────────────────────────

  return (
    <div className={`bg-white rounded-2xl border border-border overflow-hidden ${className}`}>
      {/* Viewport */}
      <div className="relative bg-slate-900 aspect-[4/3] sm:aspect-video">
        <video
          ref={videoRef}
          playsInline
          muted
          autoPlay
          className={`w-full h-full object-cover ${isLive ? 'opacity-100' : 'opacity-0'} transition-opacity duration-300`}
        />

        {/* Targeting frame */}
        {isLive && (
          <div className="absolute inset-0 pointer-events-none flex items-center justify-center">
            <div
              className={`relative w-[62%] max-w-[280px] aspect-square rounded-2xl transition-colors duration-200 ${
                flash ? 'bg-emerald-400/25' : ''
              }`}
            >
              {[
                'top-0 left-0 border-t-4 border-l-4 rounded-tl-2xl',
                'top-0 right-0 border-t-4 border-r-4 rounded-tr-2xl',
                'bottom-0 left-0 border-b-4 border-l-4 rounded-bl-2xl',
                'bottom-0 right-0 border-b-4 border-r-4 rounded-br-2xl',
              ].map((corner) => (
                <span
                  key={corner}
                  className={`absolute w-10 h-10 ${corner} ${
                    flash ? 'border-emerald-400' : 'border-white/90'
                  } transition-colors duration-200`}
                />
              ))}
              {!paused && (
                <span className="absolute left-2 right-2 h-0.5 bg-emerald-400/80 shadow-[0_0_12px_2px_rgba(52,211,153,0.7)] animate-[qrsweep_2s_ease-in-out_infinite]" />
              )}
            </div>
          </div>
        )}

        {/* Paused veil */}
        {isLive && paused && (
          <div className="absolute inset-0 bg-slate-900/55 flex items-center justify-center">
            <span className="px-4 py-2 rounded-full bg-white/90 text-xs font-bold uppercase tracking-widest text-slate-700">
              Scanning paused
            </span>
          </div>
        )}

        {/* Idle / starting / error states */}
        {!isLive && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-3 px-6 text-center">
            {status === 'starting' ? (
              <>
                <Loader2 size={34} className="text-white/80 animate-spin" />
                <p className="text-sm text-white/80">Starting camera…</p>
              </>
            ) : status === 'error' ? (
              <>
                <div className="w-14 h-14 rounded-2xl bg-red-500/20 flex items-center justify-center">
                  <AlertTriangle size={28} className="text-red-300" />
                </div>
                <p className="text-sm text-red-100 max-w-sm">{error}</p>
                <button
                  onClick={() => void start(activeDeviceId || undefined)}
                  className="mt-1 inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white text-slate-800 text-sm font-semibold hover:bg-slate-100 transition-all"
                >
                  <RefreshCcw size={15} /> Retry
                </button>
              </>
            ) : (
              <>
                <div className="w-16 h-16 rounded-2xl bg-white/10 flex items-center justify-center">
                  <Camera size={30} className="text-white/70" />
                </div>
                <p className="text-sm text-white/70">Camera is off</p>
                <button
                  onClick={() => void start(activeDeviceId || undefined)}
                  className="mt-1 inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-brand-primary text-white text-sm font-semibold hover:bg-brand-primary/90 transition-all"
                >
                  <Camera size={15} /> Start Camera
                </button>
              </>
            )}
          </div>
        )}

        {/* Live badge */}
        {isLive && (
          <span className="absolute top-3 left-3 inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-black/55 text-[10px] font-bold uppercase tracking-widest text-white">
            <span className={`w-1.5 h-1.5 rounded-full ${paused ? 'bg-amber-400' : 'bg-emerald-400 animate-pulse'}`} />
            {paused ? 'Paused' : 'Live'}
          </span>
        )}
      </div>

      {/* Controls */}
      <div className="flex flex-wrap items-center gap-2 p-3 border-t border-border">
        {isLive ? (
          <button
            onClick={stop}
            className="inline-flex items-center gap-2 px-3.5 py-2 rounded-xl bg-slate-100 text-slate-600 text-xs font-bold hover:bg-slate-200 transition-all"
          >
            <CameraOff size={14} /> Stop
          </button>
        ) : (
          <button
            onClick={() => void start(activeDeviceId || undefined)}
            disabled={status === 'starting'}
            className="inline-flex items-center gap-2 px-3.5 py-2 rounded-xl bg-brand-primary text-white text-xs font-bold hover:bg-brand-primary/90 disabled:opacity-50 transition-all"
          >
            <Camera size={14} /> Start Camera
          </button>
        )}

        {devices.length > 1 && (
          <button
            onClick={switchCamera}
            disabled={!isLive}
            className="inline-flex items-center gap-2 px-3.5 py-2 rounded-xl bg-slate-100 text-slate-600 text-xs font-bold hover:bg-slate-200 disabled:opacity-40 transition-all"
            title="Switch camera"
          >
            <SwitchCamera size={14} /> Flip
          </button>
        )}

        {torchSupported && (
          <button
            onClick={() => void toggleTorch()}
            disabled={!isLive}
            className={`inline-flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all disabled:opacity-40 ${
              torchOn ? 'bg-amber-400 text-white hover:bg-amber-500' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            }`}
            title="Torch"
          >
            {torchOn ? <ZapOff size={14} /> : <Zap size={14} />} {torchOn ? 'Torch Off' : 'Torch'}
          </button>
        )}

        {devices.length > 1 && (
          <select
            value={activeDeviceId}
            onChange={(e) => void start(e.target.value)}
            className="ml-auto max-w-[180px] sm:max-w-[220px] bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-xs font-medium truncate focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
          >
            {devices.map((d, i) => (
              <option key={d.deviceId} value={d.deviceId}>
                {d.label || `Camera ${i + 1}`}
              </option>
            ))}
          </select>
        )}
      </div>

      {isLive && (
        <p className="px-3 pb-3 text-[10px] text-slate-400">
          Hold the QR code inside the frame — it is read automatically.
          {usingNative ? ' Using this device’s built-in QR decoder.' : ''}
        </p>
      )}

      {/* Sweep animation for the targeting frame */}
      <style>{`
        @keyframes qrsweep {
          0%   { top: 6%;  opacity: 0.25; }
          50%  { top: 92%; opacity: 1; }
          100% { top: 6%;  opacity: 0.25; }
        }
      `}</style>
    </div>
  );
};

export default QrCameraScanner;
