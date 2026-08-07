/**
 * Employee → Batch. Coaching batches for the employee's own complex; the sport
 * and coach pickers are populated from that same complex-scoped data.
 */
import React, { useCallback, useEffect, useState } from 'react';
import { CalendarDays, Pencil, Trash2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import {
  API, ModuleShell, DataCard, EmptyState, FormPanel, Field, inputCls, StatusPill, readError,
} from './ModuleShell';

interface Option { id: number; name: string }

interface Batch {
  id: number;
  name: string;
  sport?: Option | null;
  coach?: Option | null;
  schedule?: string | null;
  days?: string | null;
  startDate: string;
  endDate?: string | null;
  maxStudents?: number | null;
  currentStudents?: number | null;
  fees: string | number;
  status: string;
}

const emptyDraft = {
  name: '', sportId: '', coachId: '', schedule: '', days: '',
  startDate: '', endDate: '', maxStudents: '20', fees: '', status: 'Active',
};

function fmtDate(d?: string | null) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

export default function BatchesMaster() {
  const [rows, setRows] = useState<Batch[]>([]);
  const [sports, setSports] = useState<Option[]>([]);
  const [coaches, setCoaches] = useState<Option[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Batch | null>(null);
  const [draft, setDraft] = useState(emptyDraft);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [batchRes, sportRes, coachRes] = await Promise.all([
        fetchWithAuth(`${API}/batches?limit=200`),
        fetchWithAuth(`${API}/sports?limit=200`),
        fetchWithAuth(`${API}/coaches?limit=200`),
      ]);
      if (!batchRes.ok) throw new Error(await readError(batchRes, 'Failed to load batches.'));
      const batchJson = await batchRes.json();
      const list = batchJson.data?.batches ?? batchJson.data ?? [];
      setRows(Array.isArray(list) ? list : []);

      if (sportRes.ok) {
        const j = await sportRes.json();
        const l = j.data?.sports ?? j.data ?? [];
        setSports(Array.isArray(l) ? l.map((s: any) => ({ id: s.id, name: s.name })) : []);
      }
      if (coachRes.ok) {
        const j = await coachRes.json();
        const l = j.data?.coaches ?? j.data ?? [];
        setCoaches(Array.isArray(l) ? l.map((c: any) => ({ id: c.id, name: c.name })) : []);
      }
    } catch (err: any) {
      setError(err.message);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const openCreate = () => { setEditing(null); setDraft(emptyDraft); setFormError(null); setOpen(true); };

  const openEdit = (b: Batch) => {
    setEditing(b);
    setDraft({
      name: b.name ?? '',
      sportId: b.sport?.id ? String(b.sport.id) : '',
      coachId: b.coach?.id ? String(b.coach.id) : '',
      schedule: b.schedule ?? '',
      days: b.days ?? '',
      startDate: (b.startDate ?? '').slice(0, 10),
      endDate: (b.endDate ?? '').slice(0, 10),
      maxStudents: b.maxStudents != null ? String(b.maxStudents) : '20',
      fees: b.fees != null ? String(b.fees) : '',
      status: b.status ?? 'Active',
    });
    setFormError(null);
    setOpen(true);
  };

  const save = async () => {
    if (!draft.name.trim()) { setFormError('Batch name is required.'); return; }
    if (!draft.sportId) { setFormError('Please select a sport.'); return; }
    if (!draft.startDate) { setFormError('Start date is required.'); return; }
    if (draft.fees === '' || Number(draft.fees) < 0) { setFormError('Enter a valid fee amount.'); return; }
    setSaving(true);
    setFormError(null);
    try {
      // No sportComplexId — the API stamps the employee's own complex.
      const payload = {
        name: draft.name.trim(),
        sportId: Number(draft.sportId),
        coachId: draft.coachId ? Number(draft.coachId) : null,
        schedule: draft.schedule.trim() || null,
        days: draft.days.trim() || null,
        startDate: draft.startDate,
        endDate: draft.endDate || null,
        maxStudents: draft.maxStudents ? Number(draft.maxStudents) : 20,
        fees: Number(draft.fees),
        status: draft.status,
      };
      const res = await fetchWithAuth(
        editing ? `${API}/batches/${editing.id}` : `${API}/batches`,
        { method: editing ? 'PUT' : 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) }
      );
      if (!res.ok) throw new Error(await readError(res, 'Failed to save batch.'));
      toast.success(editing ? 'Batch updated' : 'Batch created');
      setOpen(false);
      load();
    } catch (err: any) {
      setFormError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const remove = async (b: Batch) => {
    if (!window.confirm(`Delete batch "${b.name}"? This cannot be undone.`)) return;
    try {
      const res = await fetchWithAuth(`${API}/batches/${b.id}`, { method: 'DELETE' });
      if (!res.ok) throw new Error(await readError(res, 'Failed to delete batch.'));
      toast.success('Batch deleted');
      load();
    } catch (err: any) {
      toast.error(err.message);
    }
  };

  return (
    <ModuleShell
      title="Batch"
      subtitle="Manage coaching batches, schedules and fees."
      icon={<CalendarDays size={20} />}
      loading={loading}
      error={error}
      onRefresh={load}
      onAdd={openCreate}
      addLabel="Add Batch"
    >
      {rows.length === 0 ? (
        <EmptyState message="No batches yet. Add your first batch to get started." />
      ) : (
        <DataCard headers={['Batch', 'Sport', 'Coach', 'Schedule', 'Starts', 'Ends', 'Students', 'Fees', 'Status', 'Actions']}>
          {rows.map((b) => (
            <tr key={b.id} className="hover:bg-slate-50 transition-colors">
              <td className="px-5 py-3.5 text-sm font-bold text-text-dark">{b.name}</td>
              <td className="px-5 py-3.5 text-sm text-text-dark whitespace-nowrap">{b.sport?.name ?? '—'}</td>
              <td className="px-5 py-3.5 text-sm text-text-dark whitespace-nowrap">{b.coach?.name ?? '—'}</td>
              <td className="px-5 py-3.5 text-sm text-text-muted whitespace-nowrap">{b.schedule || b.days || '—'}</td>
              <td className="px-5 py-3.5 text-sm text-text-muted whitespace-nowrap">{fmtDate(b.startDate)}</td>
              <td className="px-5 py-3.5 text-sm text-text-muted whitespace-nowrap">{fmtDate(b.endDate)}</td>
              <td className="px-5 py-3.5 text-sm text-text-muted whitespace-nowrap">
                {b.currentStudents ?? 0}/{b.maxStudents ?? '—'}
              </td>
              <td className="px-5 py-3.5 text-sm font-bold text-text-dark whitespace-nowrap">
                ₹{Number(b.fees ?? 0).toLocaleString('en-IN')}
              </td>
              <td className="px-5 py-3.5"><StatusPill active={b.status === 'Active'} label={b.status} /></td>
              <td className="px-5 py-3.5">
                <div className="flex items-center gap-2">
                  <button onClick={() => openEdit(b)} className="p-2 bg-blue-50 text-blue-600 rounded-lg hover:bg-blue-100" title="Edit">
                    <Pencil size={14} />
                  </button>
                  <button onClick={() => remove(b)} className="p-2 bg-red-50 text-red-600 rounded-lg hover:bg-red-100" title="Delete">
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
        title={editing ? 'Edit Batch' : 'Add Batch'}
        saving={saving}
        error={formError}
        onClose={() => setOpen(false)}
        onSave={save}
      >
        <Field label="Batch Name *">
          <input className={inputCls} value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} placeholder="e.g. Morning Batch" />
        </Field>
        <Field label="Sport *">
          <select className={inputCls} value={draft.sportId} onChange={(e) => setDraft({ ...draft, sportId: e.target.value })}>
            <option value="">— Select Sport —</option>
            {sports.map((s) => <option key={s.id} value={String(s.id)}>{s.name}</option>)}
          </select>
        </Field>
        <Field label="Coach">
          <select className={inputCls} value={draft.coachId} onChange={(e) => setDraft({ ...draft, coachId: e.target.value })}>
            <option value="">— Unassigned —</option>
            {coaches.map((c) => <option key={c.id} value={String(c.id)}>{c.name}</option>)}
          </select>
        </Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Start Date *">
            <input type="date" className={inputCls} value={draft.startDate} onChange={(e) => setDraft({ ...draft, startDate: e.target.value })} />
          </Field>
          <Field label="End Date">
            <input type="date" className={inputCls} value={draft.endDate} onChange={(e) => setDraft({ ...draft, endDate: e.target.value })} />
          </Field>
        </div>
        <Field label="Schedule">
          <input className={inputCls} value={draft.schedule} onChange={(e) => setDraft({ ...draft, schedule: e.target.value })} placeholder="e.g. 6:00 AM - 7:30 AM" />
        </Field>
        <Field label="Days">
          <input className={inputCls} value={draft.days} onChange={(e) => setDraft({ ...draft, days: e.target.value })} placeholder="e.g. Mon,Wed,Fri" />
        </Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Max Students">
            <input type="number" min={1} className={inputCls} value={draft.maxStudents} onChange={(e) => setDraft({ ...draft, maxStudents: e.target.value })} />
          </Field>
          <Field label="Fees (₹) *">
            <input type="number" min={0} className={inputCls} value={draft.fees} onChange={(e) => setDraft({ ...draft, fees: e.target.value })} />
          </Field>
        </div>
        <Field label="Status">
          <select className={inputCls} value={draft.status} onChange={(e) => setDraft({ ...draft, status: e.target.value })}>
            <option value="Active">Active</option>
            <option value="Inactive">Inactive</option>
            <option value="Completed">Completed</option>
            <option value="Cancelled">Cancelled</option>
          </select>
        </Field>
      </FormPanel>
    </ModuleShell>
  );
}
