/**
 * Employee → Slot. Time slots belong to a court, so the court is picked first
 * and the court list is already limited to the employee's own complex.
 *
 * NOTE: slots are stored as 1-hour rows on purpose — partner feeds read them
 * literally — so the form keeps start/end as explicit times rather than
 * generating ranges.
 */
import React, { useCallback, useEffect, useState } from 'react';
import { Clock, Pencil, Trash2, ToggleLeft, ToggleRight } from 'lucide-react';
import toast from 'react-hot-toast';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import {
  API, ModuleShell, DataCard, EmptyState, FormPanel, Field, inputCls, StatusPill, readError,
} from './ModuleShell';

interface CourtOption { id: number; name: string }

interface Slot {
  id: number;
  courtId: number;
  startTime: string;
  endTime: string;
  slotType: string;
  priceOverride?: string | number | null;
  availableDays?: string | null;
  status: string;
}

function fmt(t?: string) {
  if (!t) return '—';
  const [h, m] = t.split(':').map(Number);
  const ampm = h >= 12 ? 'PM' : 'AM';
  return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${ampm}`;
}

// Slot availability is stored as a comma-separated day string (or null = every
// day). The picker works on an array and converts at the edges.
const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'] as const;
type Day = typeof DAYS[number];

/** Keep days in week order regardless of the click order. */
const orderedDays = (days: string[]) => DAYS.filter((d) => days.includes(d));

const parseDays = (raw?: string | null): Day[] => {
  if (!raw || !raw.trim()) return [...DAYS];   // null/blank = every day
  const parts = raw.split(',').map((p) => p.trim().slice(0, 3).toLowerCase());
  return DAYS.filter((d) => parts.includes(d.toLowerCase()));
};

const emptyDraft = { startTime: '', endTime: '', slotType: 'Regular', priceOverride: '', status: 'Active' };

export default function SlotsMaster() {
  const [courts, setCourts] = useState<CourtOption[]>([]);
  const [courtId, setCourtId] = useState('');
  const [rows, setRows] = useState<Slot[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Slot | null>(null);
  const [draft, setDraft] = useState(emptyDraft);
  const [selectedDays, setSelectedDays] = useState<Day[]>([...DAYS]);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  // Courts first — the slot list depends on which court is selected.
  useEffect(() => {
    (async () => {
      try {
        const res = await fetchWithAuth(`${API}/courts?limit=200`);
        if (!res.ok) throw new Error(await readError(res, 'Failed to load courts.'));
        const json = await res.json();
        const list: CourtOption[] = (Array.isArray(json.data) ? json.data : []).map((c: any) => ({ id: c.id, name: c.name }));
        setCourts(list);
        if (list.length > 0) setCourtId(String(list[0].id));
      } catch (err: any) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const load = useCallback(async () => {
    if (!courtId) { setRows([]); return; }
    setLoading(true);
    setError(null);
    try {
      const res = await fetchWithAuth(`${API}/courts/${courtId}/slots`);
      if (!res.ok) throw new Error(await readError(res, 'Failed to load slots.'));
      const json = await res.json();
      setRows(Array.isArray(json.data) ? json.data : []);
    } catch (err: any) {
      setError(err.message);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [courtId]);

  useEffect(() => { if (courtId) load(); }, [courtId, load]);

  const openCreate = () => {
    if (!courtId) { toast.error('Select a court first.'); return; }
    setEditing(null); setDraft(emptyDraft); setSelectedDays([...DAYS]); setFormError(null); setOpen(true);
  };

  const openEdit = (s: Slot) => {
    setEditing(s);
    setDraft({
      startTime: (s.startTime ?? '').slice(0, 5),
      endTime: (s.endTime ?? '').slice(0, 5),
      slotType: s.slotType ?? 'Regular',
      priceOverride: s.priceOverride != null ? String(s.priceOverride) : '',
      status: s.status ?? 'Active',
    });
    setSelectedDays(parseDays(s.availableDays));
    setFormError(null);
    setOpen(true);
  };

  const save = async () => {
    if (!draft.startTime || !draft.endTime) { setFormError('Start and end time are required.'); return; }
    setSaving(true);
    setFormError(null);
    try {
      const payload = {
        startTime: `${draft.startTime}:00`,
        endTime: `${draft.endTime}:00`,
        slotType: draft.slotType,
        priceOverride: draft.priceOverride ? Number(draft.priceOverride) : null,
        // Every day (or none picked) is stored as null, matching how the rest
        // of the system reads "no day restriction".
        availableDays:
          selectedDays.length === 0 || selectedDays.length === DAYS.length
            ? null
            : orderedDays(selectedDays).join(','),
        status: draft.status,
      };
      const res = await fetchWithAuth(
        editing ? `${API}/courts/${courtId}/slots/${editing.id}` : `${API}/courts/${courtId}/slots`,
        { method: editing ? 'PUT' : 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) }
      );
      if (!res.ok) throw new Error(await readError(res, 'Failed to save slot.'));
      toast.success(editing ? 'Slot updated' : 'Slot created');
      setOpen(false);
      load();
    } catch (err: any) {
      setFormError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const toggle = async (s: Slot) => {
    try {
      // The API sets an explicit status rather than flipping it; a PATCH with
      // no body 400s.
      const res = await fetchWithAuth(`${API}/courts/${courtId}/slots/${s.id}/toggle`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: s.status === 'Active' ? 'Inactive' : 'Active' }),
      });
      if (!res.ok) throw new Error(await readError(res, 'Failed to toggle slot.'));
      load();
    } catch (err: any) {
      toast.error(err.message);
    }
  };

  const remove = async (s: Slot) => {
    if (!window.confirm(`Delete the ${fmt(s.startTime)} – ${fmt(s.endTime)} slot?`)) return;
    try {
      const res = await fetchWithAuth(`${API}/courts/${courtId}/slots/${s.id}`, { method: 'DELETE' });
      if (!res.ok) throw new Error(await readError(res, 'Failed to delete slot.'));
      toast.success('Slot deleted');
      load();
    } catch (err: any) {
      toast.error(err.message);
    }
  };

  return (
    <ModuleShell
      title="Slot"
      subtitle="Manage court time slots, pricing and availability."
      icon={<Clock size={20} />}
      loading={loading}
      error={error}
      onRefresh={load}
      onAdd={openCreate}
      addLabel="Add Slot"
      toolbar={
        <select
          value={courtId}
          onChange={(e) => setCourtId(e.target.value)}
          className="px-4 py-2.5 bg-white border border-border rounded-xl text-sm font-medium focus:outline-none focus:ring-2 focus:ring-primary/20"
        >
          {courts.length === 0 && <option value="">No courts</option>}
          {courts.map((c) => <option key={c.id} value={String(c.id)}>{c.name}</option>)}
        </select>
      }
    >
      {rows.length === 0 ? (
        <EmptyState message={courts.length === 0 ? 'No courts exist yet — add a court first.' : 'No slots for this court yet.'} />
      ) : (
        <DataCard headers={['Time', 'Type', 'Price Override', 'Available Days', 'Status', 'Actions']}>
          {rows.map((s) => (
            <tr key={s.id} className="hover:bg-slate-50 transition-colors">
              <td className="px-5 py-3.5 text-sm font-bold text-text-dark whitespace-nowrap">
                {fmt(s.startTime)} – {fmt(s.endTime)}
              </td>
              <td className="px-5 py-3.5 text-sm text-text-dark">{s.slotType}</td>
              <td className="px-5 py-3.5 text-sm text-text-muted whitespace-nowrap">
                {s.priceOverride != null && s.priceOverride !== '' ? `₹${Number(s.priceOverride).toLocaleString('en-IN')}` : '—'}
              </td>
              <td className="px-5 py-3.5 text-sm text-text-muted">
                {s.availableDays ? orderedDays(parseDays(s.availableDays)).join(', ') : 'All days'}
              </td>
              <td className="px-5 py-3.5"><StatusPill active={s.status === 'Active'} label={s.status} /></td>
              <td className="px-5 py-3.5">
                <div className="flex items-center gap-2">
                  <button onClick={() => toggle(s)} className="p-2 bg-slate-100 text-slate-600 rounded-lg hover:bg-slate-200" title="Toggle Active/Inactive">
                    {s.status === 'Active' ? <ToggleRight size={14} /> : <ToggleLeft size={14} />}
                  </button>
                  <button onClick={() => openEdit(s)} className="p-2 bg-blue-50 text-blue-600 rounded-lg hover:bg-blue-100" title="Edit">
                    <Pencil size={14} />
                  </button>
                  <button onClick={() => remove(s)} className="p-2 bg-red-50 text-red-600 rounded-lg hover:bg-red-100" title="Delete">
                    <Trash2 size={14} />
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </DataCard>
      )}

      <FormPanel
        open={open}
        title={editing ? 'Edit Slot' : 'Add Slot'}
        saving={saving}
        error={formError}
        onClose={() => setOpen(false)}
        onSave={save}
      >
        <div className="grid grid-cols-2 gap-3">
          <Field label="Start Time *">
            <input type="time" className={inputCls} value={draft.startTime} onChange={(e) => setDraft({ ...draft, startTime: e.target.value })} />
          </Field>
          <Field label="End Time *">
            <input type="time" className={inputCls} value={draft.endTime} onChange={(e) => setDraft({ ...draft, endTime: e.target.value })} />
          </Field>
        </div>
        <p className="text-[11px] text-text-muted">Keep slots to one hour — partner booking feeds read these rows literally.</p>
        <Field label="Slot Type">
          <select className={inputCls} value={draft.slotType} onChange={(e) => setDraft({ ...draft, slotType: e.target.value })}>
            <option value="Regular">Regular</option>
            <option value="Peak">Peak</option>
          </select>
        </Field>
        <Field label="Price Override (₹)">
          <input type="number" min={0} className={inputCls} value={draft.priceOverride} onChange={(e) => setDraft({ ...draft, priceOverride: e.target.value })} placeholder="Leave blank to use the court's hourly rate" />
        </Field>
        <Field label="Available Days">
          {/* All days ticked = available every day, which the API stores as
              null. Untick to restrict the slot to specific days. */}
          <div className="space-y-2">
            <label className="flex items-center gap-2.5 cursor-pointer">
              <input
                type="checkbox"
                checked={selectedDays.length === DAYS.length}
                onChange={(e) => setSelectedDays(e.target.checked ? [...DAYS] : [])}
                className="w-4 h-4 accent-primary"
              />
              <span className="text-sm font-bold text-text-dark">All days</span>
            </label>
            <div className="flex flex-wrap gap-2">
              {DAYS.map((d) => {
                const on = selectedDays.includes(d);
                return (
                  <button
                    key={d}
                    type="button"
                    onClick={() =>
                      setSelectedDays((prev) => (on ? prev.filter((x) => x !== d) : [...prev, d]))
                    }
                    className={`px-3.5 py-2 rounded-xl text-xs font-bold border transition-colors ${
                      on
                        ? 'bg-primary text-white border-primary'
                        : 'bg-white text-text-muted border-slate-200 hover:bg-slate-50'
                    }`}
                  >
                    {d}
                  </button>
                );
              })}
            </div>
            <p className="text-[11px] text-text-muted">
              {selectedDays.length === 0
                ? 'No days selected — the slot will be available every day.'
                : selectedDays.length === DAYS.length
                  ? 'Available every day.'
                  : `Available on ${orderedDays(selectedDays).join(', ')}.`}
            </p>
          </div>
        </Field>
        <Field label="Status">
          <select className={inputCls} value={draft.status} onChange={(e) => setDraft({ ...draft, status: e.target.value })}>
            <option value="Active">Active</option>
            <option value="Inactive">Inactive</option>
          </select>
        </Field>
      </FormPanel>
    </ModuleShell>
  );
}
