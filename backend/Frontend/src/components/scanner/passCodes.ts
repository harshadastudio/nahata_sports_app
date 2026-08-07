/**
 * Pass-code helpers shared by the camera scanner.
 *
 * Every pass type in the system carries a distinct prefix, which is what lets a
 * single camera scan route itself to the right verification endpoint:
 *
 *   VP-…        visitor entry pass   (visitorPassService)
 *   EVTPASS-…   event pass           (eventPassService)
 *   BOOK-…      court booking pass, incl. per-member `…-M01` (courtService)
 *   GATEPASS-…  student gate pass    (feesController)
 */

export type PassKind = 'entry' | 'event' | 'court' | 'student';

export interface PassKindMeta {
  kind: PassKind;
  label: string;
  prefix: string;
  /** Whether this pass type records a direction (IN / OUT). */
  directional: boolean;
  example: string;
}

export const PASS_KINDS: PassKindMeta[] = [
  { kind: 'entry',   label: 'Visitor Entry Pass', prefix: 'VP-',       directional: true,  example: 'VP-20260731-A3F9' },
  { kind: 'event',   label: 'Event Pass',         prefix: 'EVTPASS-',  directional: true,  example: 'EVTPASS-2026-000042-001' },
  { kind: 'court',   label: 'Court Booking Pass', prefix: 'BOOK-',     directional: true,  example: 'BOOK-2026-000042-M01' },
  { kind: 'student', label: 'Student Gate Pass',  prefix: 'GATEPASS-', directional: false, example: 'GATEPASS-2026-000042' },
];

export const getPassKindMeta = (kind: PassKind): PassKindMeta =>
  PASS_KINDS.find((p) => p.kind === kind)!;

/**
 * Pick the first token that looks like one of our pass codes.
 *
 * Visitor QRs encode a pipe-delimited payload ("VISITOR|VP-…|Ravi Kumar"), so
 * the whole decoded string must not be posted to the API verbatim.
 */
function pickKnownToken(value: string): string | null {
  const tokens = value.split(/[|,;\s]+/).map((t) => t.trim()).filter(Boolean);
  return (
    tokens.find((t) => PASS_KINDS.some((p) => t.toUpperCase().startsWith(p.prefix))) ?? null
  );
}

/**
 * Reduce whatever a QR code contained down to a bare pass code.
 *
 * Handles the raw code, pipe-delimited payloads, JSON payloads, and URLs
 * (including the api.qrserver.com generator URL, whose `?data=` holds the real
 * payload). Falls back to the trimmed input so an unusual-but-valid code is
 * still sent to the API rather than silently dropped.
 */
export function extractPassCode(raw: string): string {
  let value = (raw ?? '').trim();
  if (!value) return '';

  if (value.startsWith('{')) {
    try {
      const obj = JSON.parse(value);
      const fromJson = obj?.passCode ?? obj?.pass_code ?? obj?.code ?? obj?.passNumber;
      if (typeof fromJson === 'string' && fromJson.trim()) value = fromJson.trim();
    } catch {
      // Not JSON after all — keep the original text.
    }
  }

  if (/^https?:\/\//i.test(value)) {
    try {
      const url = new URL(value);
      const param =
        url.searchParams.get('data') ??
        url.searchParams.get('passCode') ??
        url.searchParams.get('code') ??
        url.searchParams.get('pass');
      if (param?.trim()) {
        value = param.trim();
      } else {
        const segment = url.pathname.split('/').filter(Boolean).pop();
        if (segment) value = decodeURIComponent(segment);
      }
    } catch {
      // Malformed URL — fall through with the raw text.
    }
  }

  return pickKnownToken(value) ?? value;
}

/** Resolve which scanner endpoint a code belongs to, or null if unrecognised. */
export function detectPassKind(code: string): PassKind | null {
  const upper = (code ?? '').trim().toUpperCase();
  if (!upper) return null;
  return PASS_KINDS.find((p) => upper.startsWith(p.prefix))?.kind ?? null;
}
