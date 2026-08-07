/**
 * Shared visitor-pass helpers for the SECURITY dashboard.
 *
 * A visitor pass moves through a check-in / check-out lifecycle:
 *
 *   active      → generated, nobody entered yet   (QR valid for the IN scan)
 *   checked_in  → visitor scanned IN              (QR valid ONLY for the OUT scan)
 *   checked_out → visitor scanned OUT             (QR permanently dead)
 *   expired     → ran past its validity window
 *   cancelled   → revoked
 *
 * The API used to emit a single 'used' state; it is still accepted here and read
 * as 'checked_in' so older rows keep rendering sensibly.
 */

import React from 'react';
import { CheckCircle, LogIn, LogOut, XCircle, Ban } from 'lucide-react';
import toast from 'react-hot-toast';

// ── Types ─────────────────────────────────────────────────────────────────────

export type VisitorPassStatus =
  | 'active'
  | 'checked_in'
  | 'checked_out'
  | 'expired'
  | 'cancelled';

export interface VisitorPass {
  id: number | string;
  visitorName: string;
  phoneNumber?: string;
  visitPurpose: string;
  passCode: string;
  status: VisitorPassStatus;
  generatedAt: string;
  scannedAt?: string | null;
  checkInTime?: string | null;
  checkOutTime?: string | null;
  qrValid?: boolean;
  qrValidFor?: 'entry' | 'exit' | null;
  validFrom?: string;
  validUntil?: string;
  qrCode?: string; // base64 QR image, if the API ever returns one
  qrUrl?: string; // hosted QR image URL (what the API actually returns)
}

// ── Status ────────────────────────────────────────────────────────────────────

export interface PassStatusMeta {
  label: string;
  /** Badge colours. */
  cls: string;
  /** Solid colours, for banners/headers. */
  solidCls: string;
  icon: React.ReactNode;
  /** One-line explanation of what the QR can still do. */
  hint: string;
}

export const PASS_STATUS_META: Record<VisitorPassStatus, PassStatusMeta> = {
  active: {
    label: 'Active',
    cls: 'bg-green-100 text-green-700',
    solidCls: 'bg-green-500 text-white',
    icon: <CheckCircle size={12} />,
    hint: 'QR is valid — scan IN at the gate to check the visitor in.',
  },
  checked_in: {
    label: 'Checked In',
    cls: 'bg-blue-100 text-blue-700',
    solidCls: 'bg-blue-500 text-white',
    icon: <LogIn size={12} />,
    hint: 'Visitor is inside. The QR is now only valid for the check-out scan.',
  },
  checked_out: {
    label: 'Checked Out',
    cls: 'bg-slate-200 text-slate-600',
    solidCls: 'bg-slate-600 text-white',
    icon: <LogOut size={12} />,
    hint: 'Visit complete — this QR code is no longer valid.',
  },
  expired: {
    label: 'Expired',
    cls: 'bg-red-100 text-red-700',
    solidCls: 'bg-red-500 text-white',
    icon: <XCircle size={12} />,
    hint: 'This pass ran past its validity window and can no longer be scanned.',
  },
  cancelled: {
    label: 'Cancelled',
    cls: 'bg-red-100 text-red-700',
    solidCls: 'bg-red-500 text-white',
    icon: <Ban size={12} />,
    hint: 'This pass was cancelled and can no longer be scanned.',
  },
};

/** Map anything the API might send onto a known status. */
export const normalizePassStatus = (raw?: string | null): VisitorPassStatus => {
  const key = String(raw ?? '').toLowerCase().replace(/[^a-z]/g, '');
  switch (key) {
    case 'checkedin':
    case 'used': // legacy single-use state
      return 'checked_in';
    case 'checkedout':
      return 'checked_out';
    case 'expired':
      return 'expired';
    case 'cancelled':
    case 'canceled':
      return 'cancelled';
    default:
      return 'active';
  }
};

export const getPassStatusMeta = (raw?: string | null): PassStatusMeta =>
  PASS_STATUS_META[normalizePassStatus(raw)];

/** Whether the QR can still be scanned for anything. */
export const isQrLive = (pass: Pick<VisitorPass, 'status' | 'qrValid'>): boolean => {
  if (typeof pass.qrValid === 'boolean') return pass.qrValid;
  const s = normalizePassStatus(pass.status);
  return s === 'active' || s === 'checked_in';
};

export function VisitorPassStatusBadge({
  status,
  size = 'sm',
}: {
  status?: string | null;
  size?: 'sm' | 'md';
}) {
  const { label, cls, icon } = getPassStatusMeta(status);
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full font-semibold whitespace-nowrap ${cls} ${
        size === 'md' ? 'px-3 py-1 text-sm' : 'px-2.5 py-0.5 text-xs'
      }`}
    >
      {icon}
      {label}
    </span>
  );
}

// ── Dates ─────────────────────────────────────────────────────────────────────

/**
 * The API sends timestamps either as ISO or as an already-localized en-IN string
 * ("01/08/2026, 10:07:00 am"). `new Date()` reads the latter as MM/DD, turning
 * 1 Aug into 8 Jan — so parse the day-first form explicitly.
 */
export const parseApiDate = (value?: string | null): Date | null => {
  if (!value) return null;

  const dayFirst = value.match(
    /(\d{1,2})\/(\d{1,2})\/(\d{4}),?\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm)?/i
  );
  if (dayFirst) {
    let hour = parseInt(dayFirst[4], 10);
    const ap = dayFirst[7]?.toLowerCase();
    if (ap === 'pm' && hour < 12) hour += 12;
    if (ap === 'am' && hour === 12) hour = 0;
    return new Date(
      +dayFirst[3],
      +dayFirst[2] - 1,
      +dayFirst[1],
      hour,
      +dayFirst[5],
      dayFirst[6] ? +dayFirst[6] : 0
    );
  }

  const native = new Date(value);
  return isNaN(native.getTime()) ? null : native;
};

export const formatDateTime = (value?: string | null): string => {
  const d = parseApiDate(value);
  if (!d) return value || '—';
  return d.toLocaleString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
  });
};

// ── QR + sharing ──────────────────────────────────────────────────────────────

/** Resolve the QR image for a pass, generating one from the code if needed. */
export const qrImageUrl = (pass: VisitorPass, size = 400): string => {
  const hosted = pass.qrUrl ?? pass.qrCode;
  if (hosted) return hosted;
  const payload = `VISITOR|${pass.passCode}|${pass.visitorName}`;
  return `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(payload)}`;
};

export const buildShareText = (pass: VisitorPass): string => {
  const status = normalizePassStatus(pass.status);
  return (
    `🎟️ *Nahata Sports — Visitor Pass*\n\n` +
    `Name: ${pass.visitorName}\n` +
    (pass.phoneNumber ? `Phone: ${pass.phoneNumber}\n` : '') +
    `Purpose: ${pass.visitPurpose}\n` +
    `Pass Code: ${pass.passCode}\n` +
    (pass.validUntil ? `Valid Until: ${formatDateTime(pass.validUntil)}\n` : '') +
    `\nQR: ${qrImageUrl(pass)}\n` +
    (status === 'checked_out' || status === 'expired' || status === 'cancelled'
      ? `\n⚠️ This pass is ${PASS_STATUS_META[status].label.toLowerCase()} and can no longer be scanned.`
      : `\nPlease show this pass at the gate for entry.`)
  );
};

export const shareOnWhatsApp = (pass: VisitorPass): void => {
  const text = encodeURIComponent(buildShareText(pass));
  // Pre-fill the visitor's own number when it looks like an Indian mobile.
  const phone = (pass.phoneNumber ?? '').replace(/\D/g, '');
  const target = phone.length === 10 ? `91${phone}` : '';
  window.open(`https://wa.me/${target}?text=${text}`, '_blank', 'noopener');
};

export const copyPassDetails = (pass: VisitorPass): void => {
  navigator.clipboard
    .writeText(buildShareText(pass))
    .then(() => toast.success('Pass details copied'))
    .catch(() => toast.error('Failed to copy'));
};

export const copyPassCode = (code: string): void => {
  navigator.clipboard
    .writeText(code)
    .then(() => toast.success('Pass code copied to clipboard'))
    .catch(() => toast.error('Failed to copy pass code'));
};

export const downloadQr = async (pass: VisitorPass): Promise<void> => {
  const url = qrImageUrl(pass);
  try {
    const resp = await fetch(url);
    const blob = await resp.blob();
    const blobUrl = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = blobUrl;
    a.download = `visitor-pass-${pass.passCode}.png`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(blobUrl);
  } catch {
    // Fallback: open the image in a new tab if the download fetch is blocked.
    window.open(url, '_blank', 'noopener');
  }
};

/**
 * Email the pass + QR to a recipient via the backend.
 * `request` is injected so this stays free of any fetch/auth wiring.
 */
export const emailPass = async (
  pass: VisitorPass,
  request: (path: string, init: RequestInit) => Promise<Response>
): Promise<void> => {
  const recipient = window.prompt('Send this pass to which email address?', '');
  if (recipient === null) return;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(recipient.trim())) {
    toast.error('Please enter a valid email address');
    return;
  }

  const tId = toast.loading('Sending pass…');
  try {
    const res = await request(`/visitor-passes/${pass.id}/send-email`, {
      method: 'POST',
      body: JSON.stringify({ recipientEmail: recipient.trim(), recipientName: pass.visitorName }),
    });
    const data = await res.json();
    if (res.ok && data.success) {
      toast.success(`Pass emailed to ${recipient.trim()}`, { id: tId });
    } else {
      toast.error(data.message || 'Failed to email pass', { id: tId });
    }
  } catch {
    toast.error('Unable to send email. Please try again.', { id: tId });
  }
};

/** Open a printable, self-contained copy of the pass in a new window. */
export const printPass = (pass: VisitorPass): void => {
  const meta = getPassStatusMeta(pass.status);
  const win = window.open('', '_blank', 'width=520,height=760');
  if (!win) {
    toast.error('Please allow pop-ups to print the pass');
    return;
  }

  const row = (label: string, value?: string | null) =>
    value ? `<tr><td class="k">${label}</td><td class="v">${value}</td></tr>` : '';

  win.document.write(`<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Visitor Pass ${pass.passCode}</title>
    <style>
      * { box-sizing: border-box; }
      body { font-family: system-ui, -apple-system, "Segoe UI", sans-serif; margin: 0; padding: 28px; color: #0f172a; }
      .card { border: 2px solid #1e293b; border-radius: 18px; padding: 24px; text-align: center; }
      h1 { font-size: 20px; margin: 0 0 2px; letter-spacing: .04em; }
      .sub { font-size: 12px; color: #64748b; margin-bottom: 16px; }
      .status { display: inline-block; padding: 5px 14px; border-radius: 999px; font-size: 11px;
                font-weight: 700; text-transform: uppercase; letter-spacing: .08em;
                border: 1px solid #cbd5e1; margin-bottom: 18px; }
      img { width: 240px; height: 240px; }
      .code { font-family: ui-monospace, monospace; font-size: 16px; font-weight: 700; letter-spacing: .12em; margin: 12px 0 18px; }
      table { width: 100%; border-collapse: collapse; text-align: left; font-size: 13px; }
      td { padding: 7px 0; border-bottom: 1px solid #e2e8f0; }
      .k { color: #64748b; }
      .v { font-weight: 600; text-align: right; }
      .foot { margin-top: 16px; font-size: 11px; color: #64748b; }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>NAHATA SPORTS</h1>
      <div class="sub">Visitor Entry Pass</div>
      <div class="status">${meta.label}</div>
      <div><img src="${qrImageUrl(pass)}" alt="QR code" /></div>
      <div class="code">${pass.passCode}</div>
      <table>
        ${row('Visitor', pass.visitorName)}
        ${row('Phone', pass.phoneNumber)}
        ${row('Purpose', pass.visitPurpose)}
        ${row('Generated', formatDateTime(pass.generatedAt))}
        ${row('Valid Until', pass.validUntil ? formatDateTime(pass.validUntil) : null)}
        ${row('Checked In', pass.checkInTime ? formatDateTime(pass.checkInTime) : null)}
        ${row('Checked Out', pass.checkOutTime ? formatDateTime(pass.checkOutTime) : null)}
      </table>
      <div class="foot">${meta.hint}</div>
    </div>
    <script>
      window.onload = function () { window.focus(); window.print(); };
    </script>
  </body>
</html>`);
  win.document.close();
};
