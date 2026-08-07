/**
 * Employee → Blocked Slots. Pick a court + date, then block or unblock
 * individual time slots (maintenance, private events, closures).
 *
 * Blocks apply to the SELECTED DATE ONLY. Slots held by a booking partner
 * (KheloMore, Huddle) show up here too, badged with the partner's name — an
 * employee can release those as well, so the venue is never locked out.
 *
 * The court list is complex-scoped by the API, so an employee can only ever
 * block slots belonging to their own sports complex.
 */
import React, { useCallback, useEffect, useState } from 'react';
import { Ban, Lock, Unlock, Loader2, Search, CheckCircle2, User, Globe, Repeat } from 'lucide-react';
import toast from 'react-hot-toast';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import { API, ModuleShell, EmptyState, Field, inputCls, readError } from './ModuleShell';

interface CourtOption { id: number; name: string }

interface AvailableSlot {
  id: number;
  startTime: string;
  endTime: string;
  slotType: string;
  price: number;
  /** Unavailable for any reason — a customer booking OR a block. */
  isBooked: boolean;
  /** A real customer reserved it: not ours to block or release. */
  isUserBooked?: boolean;
  isBlocked?: boolean;
  /** 'Admin' | 'KheloMore' | 'Huddle' | 'Template' | null */
  blockedBy?: string | null;
  blockId?: number | null;
}

/** Blocks placed by an aggregator — anything that isn't us or the legacy template. */
const isPartnerBlock = (s: AvailableSlot) =>
  !!s.blockedBy && s.blockedBy !== 'Admin' && s.blockedBy !== 'Template';

/** The legacy all-dates block (slot template set Inactive). */
const isTemplateBlock = (s: AvailableSlot) => s.blockedBy === 'Template';

function fmt(t: string) {
  if (!t) return '';
  const [h, m] = t.split(':').map(Number);
  const ampm = h >= 12 ? 'PM' : 'AM';
  return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${ampm}`;
}

type Filter = 'all' | 'available' | 'blocked';

export default function BlockedSlotsPage() {
  const [courts, setCourts] = useState<CourtOption[]>([]);
  const [courtId, setCourtId] = useState('');
  const [date, setDate] = useState('');
  const [slots, setSlots] = useState<AvailableSlot[]>([]);
  const [fetched, setFetched] = useState(false);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState<number | null>(null);
  const [bulkBusy, setBulkBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<Filter>('all');

  useEffect(() => {
    (async () => {
      try {
        const res = await fetchWithAuth(`${API}/courts?limit=200`);
        if (!res.ok) throw new Error(await readError(res, 'Failed to load courts.'));
        const json = await res.json();
        setCourts((Array.isArray(json.data) ? json.data : []).map((c: any) => ({ id: c.id, name: c.name })));
      } catch (err: any) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const fetchSlots = useCallback(async () => {
    if (!courtId || !date) { toast.error('Choose a court and a date first.'); return; }
    setLoading(true);
    setError(null);
    try {
      const res = await fetchWithAuth(`${API}/courts/${courtId}/available-slots?date=${date}`);
      if (!res.ok) throw new Error(await readError(res, 'Failed to fetch slots.'));
      const json = await res.json();
      setSlots(Array.isArray(json.data) ? json.data : []);
      setFetched(true);
    } catch (err: any) {
      setError(err.message);
      setSlots([]);
    } finally {
      setLoading(false);
    }
  }, [courtId, date]);

  /**
   * Block / unblock one slot for THIS DATE. Persisted immediately, so a
   * half-finished session can't leave the grid showing a state the server
   * doesn't have.
   *
   * A legacy recurring block has no date-specific row to release, so it falls
   * back to reactivating the slot template — which reopens every date, and is
   * confirmed first.
   */
  const toggle = async (slot: AvailableSlot) => {
    if (slot.isUserBooked) {
      toast.error('Booked by a customer — cancel the booking to free this slot.');
      return;
    }

    const blocked = !!slot.isBlocked;

    if (blocked && isTemplateBlock(slot)) {
      const ok = window.confirm(
        'This is a recurring block — it applies to every date, not just this one.\n\n' +
        'Unblocking reopens this time on all dates. Continue?'
      );
      if (!ok) return;
    }

    setBusyId(slot.id);
    try {
      let res: Response;
      if (blocked && isTemplateBlock(slot)) {
        res = await fetchWithAuth(`${API}/courts/${courtId}/slots/${slot.id}/toggle`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: 'Active' }),
        });
      } else {
        res = await fetchWithAuth(`${API}/courts/${courtId}/slots/${slot.id}/${blocked ? 'unblock' : 'block'}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ date }),
        });
      }
      if (!res.ok) throw new Error(await readError(res, 'Failed to update slot.'));

      // Re-read rather than guess: the server decides who owns the block.
      await fetchSlots();
      toast.success(blocked ? 'Slot unblocked' : 'Slot blocked');
    } catch (err: any) {
      toast.error(err.message);
    } finally {
      setBusyId(null);
    }
  };

  /**
   * Bulk block / unblock, matching the admin panel's Block All / Unblock All.
   * Only the slots that actually need changing are toggled, so this can't flip
   * an already-correct slot back the wrong way.
   */
  const bulkSet = async (blocked: boolean) => {
    // Customer bookings are skipped entirely — bulk actions must never touch
    // a slot somebody paid for.
    const targets = slots.filter((s) => !s.isUserBooked && !!s.isBlocked !== blocked);
    if (targets.length === 0) {
      toast(blocked ? 'All slots are already blocked.' : 'All slots are already available.');
      return;
    }

    const recurring = targets.filter((s) => !blocked && isTemplateBlock(s)).length;
    const warning = recurring
      ? `\n\n${recurring} of them are recurring blocks — unblocking those reopens the time on EVERY date.`
      : '';
    if (!window.confirm(`${blocked ? 'Block' : 'Unblock'} ${targets.length} slot(s) for ${date}?${warning}`)) return;

    setBulkBusy(true);
    let ok = 0;
    for (const s of targets) {
      try {
        let res: Response;
        if (!blocked && isTemplateBlock(s)) {
          res = await fetchWithAuth(`${API}/courts/${courtId}/slots/${s.id}/toggle`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status: 'Active' }),
          });
        } else {
          res = await fetchWithAuth(`${API}/courts/${courtId}/slots/${s.id}/${blocked ? 'block' : 'unblock'}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ date }),
          });
        }
        if (res.ok) ok += 1;
      } catch {
        /* counted as failed below */
      }
    }
    setBulkBusy(false);
    await fetchSlots();
    if (ok === targets.length) toast.success(`${ok} slot(s) ${blocked ? 'blocked' : 'unblocked'}`);
    else toast.error(`${ok} of ${targets.length} updated — check the current state above.`);
  };

  const visible = slots.filter((s) =>
    filter === 'all' ? true : filter === 'blocked' ? s.isBooked : !s.isBooked
  );
  const blockedCount = slots.filter((s) => s.isBooked).length;

  return (
    <ModuleShell
      title="Blocked Slots"
      subtitle="Block or unblock court time slots for the selected date — maintenance, private events, or partner holds."
      icon={<Ban size={20} />}
      loading={loading && !fetched}
      error={error}
      onRefresh={fetched ? fetchSlots : undefined}
    >
      {/* Selector */}
      <div className="bg-white rounded-2xl border border-border p-5 grid grid-cols-1 md:grid-cols-3 gap-4 items-end">
        <Field label="Select Date">
          <input type="date" className={inputCls} value={date} onChange={(e) => setDate(e.target.value)} />
        </Field>
        <Field label="Select Court">
          <select className={inputCls} value={courtId} onChange={(e) => setCourtId(e.target.value)}>
            <option value="">— Select Court —</option>
            {courts.map((c) => <option key={c.id} value={String(c.id)}>{c.name}</option>)}
          </select>
        </Field>
        <button
          onClick={fetchSlots}
          disabled={loading || !courtId || !date}
          className="flex items-center justify-center gap-2 bg-primary text-white py-2.5 rounded-xl text-sm font-bold disabled:opacity-50 transition-opacity"
        >
          {loading && fetched ? <Loader2 size={16} className="animate-spin" /> : <Search size={16} />}
          Fetch Time Slots
        </button>
      </div>

      {!fetched ? (
        <EmptyState message="Choose a court and date above, then fetch the time slots to manage availability." />
      ) : slots.length === 0 ? (
        <EmptyState message="No slots configured for this court. Add slots from the Slot module first." />
      ) : (
        <>
          <div className="flex items-center justify-between gap-3 flex-wrap">
            <div className="flex items-center gap-2">
              {(['all', 'available', 'blocked'] as Filter[]).map((f) => (
                <button
                  key={f}
                  onClick={() => setFilter(f)}
                  className={`px-3.5 py-2 rounded-xl text-xs font-bold capitalize transition-colors ${
                    filter === f ? 'bg-primary text-white' : 'bg-white border border-border text-text-muted hover:bg-slate-50'
                  }`}
                >
                  {f}
                </button>
              ))}
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => bulkSet(true)}
                disabled={bulkBusy}
                className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-red-50 text-red-600 border border-red-200 text-xs font-bold hover:bg-red-100 disabled:opacity-50 transition-colors"
              >
                {bulkBusy ? <Loader2 size={13} className="animate-spin" /> : <Lock size={13} />} Block All
              </button>
              <button
                onClick={() => bulkSet(false)}
                disabled={bulkBusy}
                className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-emerald-50 text-emerald-700 border border-emerald-200 text-xs font-bold hover:bg-emerald-100 disabled:opacity-50 transition-colors"
              >
                {bulkBusy ? <Loader2 size={13} className="animate-spin" /> : <Unlock size={13} />} Unblock All
              </button>
              <p className="text-xs text-text-muted ml-1">
                <span className="font-bold text-text-dark">{blockedCount}</span> of {slots.length} blocked
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3">
            {visible.map((s) => {
              const byCustomer = !!s.isUserBooked;
              const byPartner = isPartnerBlock(s) && !!s.isBlocked;
              const blocked = !!s.isBlocked;

              return (
                <button
                  key={s.id}
                  onClick={() => toggle(s)}
                  disabled={busyId === s.id || byCustomer}
                  className={`text-left p-4 rounded-2xl border transition-all disabled:opacity-70 disabled:cursor-not-allowed ${
                    byCustomer
                      ? 'bg-purple-50 border-purple-200'
                      : byPartner
                        ? 'bg-amber-50 border-amber-200 hover:border-amber-300'
                        : blocked
                          ? 'bg-red-50 border-red-200 hover:border-red-300'
                          : 'bg-white border-border hover:border-primary/40'
                  }`}
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-sm font-bold text-text-dark">{fmt(s.startTime)} – {fmt(s.endTime)}</span>
                    {busyId === s.id
                      ? <Loader2 size={15} className="animate-spin text-slate-400" />
                      : byCustomer
                        ? <User size={15} className="text-purple-500" />
                        : byPartner
                          ? <Globe size={15} className="text-amber-600" />
                          : blocked
                            ? <Lock size={15} className="text-red-500" />
                            : <Unlock size={15} className="text-emerald-500" />}
                  </div>
                  <div className="flex items-center justify-between mt-2">
                    <span className={`text-[10px] font-bold uppercase tracking-wider ${
                      byCustomer ? 'text-purple-600' : byPartner ? 'text-amber-700' : blocked ? 'text-red-600' : 'text-emerald-600'
                    }`}>
                      {byCustomer
                        ? 'Booked by user'
                        : byPartner
                          ? `Blocked by ${s.blockedBy}`
                          : blocked ? 'Blocked' : 'Available'}
                    </span>
                    <span className="text-[11px] text-text-muted">{s.slotType}</span>
                  </div>

                  {isTemplateBlock(s) && blocked && (
                    <p className="flex items-start gap-1 text-[10px] font-semibold text-amber-700 mt-1.5 leading-snug">
                      <Repeat size={11} className="shrink-0 mt-px" /> Recurring — applies to every date
                    </p>
                  )}

                  <p className="text-[11px] text-text-muted mt-1">
                    {byCustomer ? 'Cancel the booking to free this slot' : `Tap to ${blocked ? 'unblock' : 'block'}`}
                  </p>
                </button>
              );
            })}
          </div>

          {visible.length === 0 && (
            <div className="bg-white rounded-2xl border border-border py-10 text-center">
              <CheckCircle2 size={26} className="text-slate-300 mx-auto mb-2" />
              <p className="text-text-muted text-sm">No {filter} slots for this court and date.</p>
            </div>
          )}
        </>
      )}
    </ModuleShell>
  );
}
