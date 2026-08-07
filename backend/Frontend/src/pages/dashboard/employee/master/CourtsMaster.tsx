/**
 * Employee → Court. Complex-scoped by the API; the sport list is likewise
 * limited to the employee's own complex.
 */
import React, { useCallback, useEffect, useState } from 'react';
import { MapPin, Pencil, Trash2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import {
  API, ModuleShell, DataCard, EmptyState, FormPanel, Field, inputCls, StatusPill, readError,
} from './ModuleShell';

interface SportOption { id: number; name: string }

interface Court {
  id: number;
  name: string;
  sportId: number;
  Sport?: SportOption;
  capacity?: number | null;
  surfaceType?: string | null;
  lightingAvailable?: boolean;
  hourlyRate: string | number;
  status: string;
}

const emptyDraft = {
  name: '', sportId: '', capacity: '', surfaceType: '',
  lightingAvailable: false, hourlyRate: '', status: 'Active',
};

export default function CourtsMaster() {
  const [rows, setRows] = useState<Court[]>([]);
  const [sports, setSports] = useState<SportOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Court | null>(null);
  const [draft, setDraft] = useState(emptyDraft);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [courtRes, sportRes] = await Promise.all([
        fetchWithAuth(`${API}/courts?limit=200`),
        fetchWithAuth(`${API}/sports?limit=200`),
      ]);
      if (!courtRes.ok) throw new Error(await readError(courtRes, 'Failed to load courts.'));
      const courtJson = await courtRes.json();
      setRows(Array.isArray(courtJson.data) ? courtJson.data : []);

      if (sportRes.ok) {
        const sportJson = await sportRes.json();
        const list = sportJson.data?.sports ?? sportJson.data ?? [];
        setSports(Array.isArray(list) ? list.map((s: any) => ({ id: s.id, name: s.name })) : []);
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

  const openEdit = (c: Court) => {
    setEditing(c);
    setDraft({
      name: c.name ?? '',
      sportId: String(c.sportId ?? ''),
      capacity: c.capacity != null ? String(c.capacity) : '',
      surfaceType: c.surfaceType ?? '',
      lightingAvailable: !!c.lightingAvailable,
      hourlyRate: c.hourlyRate != null ? String(c.hourlyRate) : '',
      status: c.status ?? 'Active',
    });
    setFormError(null);
    setOpen(true);
  };

  const save = async () => {
    if (!draft.name.trim()) { setFormError('Court name is required.'); return; }
    if (!draft.sportId) { setFormError('Please select a sport.'); return; }
    if (draft.hourlyRate === '' || Number(draft.hourlyRate) < 0) { setFormError('Enter a valid hourly rate.'); return; }
    setSaving(true);
    setFormError(null);
    try {
      // No sportComplexId — the API stamps the employee's own complex.
      const payload = {
        name: draft.name.trim(),
        sportId: Number(draft.sportId),
        capacity: draft.capacity ? Number(draft.capacity) : null,
        surfaceType: draft.surfaceType.trim() || null,
        lightingAvailable: draft.lightingAvailable,
        hourlyRate: Number(draft.hourlyRate),
        status: draft.status,
      };
      const res = await fetchWithAuth(
        editing ? `${API}/courts/${editing.id}` : `${API}/courts`,
        { method: editing ? 'PUT' : 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) }
      );
      if (!res.ok) throw new Error(await readError(res, 'Failed to save court.'));
      toast.success(editing ? 'Court updated' : 'Court created');
      setOpen(false);
      load();
    } catch (err: any) {
      setFormError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const remove = async (c: Court) => {
    if (!window.confirm(`Delete court "${c.name}"? This cannot be undone.`)) return;
    try {
      const res = await fetchWithAuth(`${API}/courts/${c.id}`, { method: 'DELETE' });
      if (!res.ok) throw new Error(await readError(res, 'Failed to delete court.'));
      toast.success('Court deleted');
      load();
    } catch (err: any) {
      toast.error(err.message);
    }
  };

  return (
    <ModuleShell
      title="Court"
      subtitle="Manage the courts and grounds at your complex."
      icon={<MapPin size={20} />}
      loading={loading}
      error={error}
      onRefresh={load}
      onAdd={openCreate}
      addLabel="Add Court"
    >
      {rows.length === 0 ? (
        <EmptyState message="No courts yet. Add your first court to get started." />
      ) : (
        <DataCard headers={['Court', 'Sport', 'Surface', 'Capacity', 'Hourly Rate', 'Lighting', 'Status', 'Actions']}>
          {rows.map((c) => (
            <tr key={c.id} className="hover:bg-slate-50 transition-colors">
              <td className="px-5 py-3.5 text-sm font-bold text-text-dark">{c.name}</td>
              <td className="px-5 py-3.5 text-sm text-text-dark whitespace-nowrap">{c.Sport?.name ?? '—'}</td>
              <td className="px-5 py-3.5 text-sm text-text-muted whitespace-nowrap">{c.surfaceType ?? '—'}</td>
              <td className="px-5 py-3.5 text-sm text-text-muted">{c.capacity ?? '—'}</td>
              <td className="px-5 py-3.5 text-sm font-bold text-text-dark whitespace-nowrap">
                ₹{Number(c.hourlyRate ?? 0).toLocaleString('en-IN')}
              </td>
              <td className="px-5 py-3.5 text-sm text-text-muted">{c.lightingAvailable ? 'Yes' : 'No'}</td>
              <td className="px-5 py-3.5"><StatusPill active={c.status === 'Active'} label={c.status} /></td>
              <td className="px-5 py-3.5">
                <div className="flex items-center gap-2">
                  <button onClick={() => openEdit(c)} className="p-2 bg-blue-50 text-blue-600 rounded-lg hover:bg-blue-100" title="Edit">
                    <Pencil size={14} />
                  </button>
                  <button onClick={() => remove(c)} className="p-2 bg-red-50 text-red-600 rounded-lg hover:bg-red-100" title="Delete">
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
        title={editing ? 'Edit Court' : 'Add Court'}
        saving={saving}
        error={formError}
        onClose={() => setOpen(false)}
        onSave={save}
      >
        <Field label="Court Name *">
          <input className={inputCls} value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} placeholder="e.g. Badminton Court 1" />
        </Field>
        <Field label="Sport *">
          <select className={inputCls} value={draft.sportId} onChange={(e) => setDraft({ ...draft, sportId: e.target.value })}>
            <option value="">— Select Sport —</option>
            {sports.map((s) => <option key={s.id} value={String(s.id)}>{s.name}</option>)}
          </select>
        </Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Hourly Rate (₹) *">
            <input type="number" min={0} className={inputCls} value={draft.hourlyRate} onChange={(e) => setDraft({ ...draft, hourlyRate: e.target.value })} />
          </Field>
          <Field label="Capacity">
            <input type="number" min={0} className={inputCls} value={draft.capacity} onChange={(e) => setDraft({ ...draft, capacity: e.target.value })} />
          </Field>
        </div>
        <Field label="Surface Type">
          <input className={inputCls} value={draft.surfaceType} onChange={(e) => setDraft({ ...draft, surfaceType: e.target.value })} placeholder="e.g. Synthetic, Wooden, Turf" />
        </Field>
        <label className="flex items-center gap-2.5 cursor-pointer pt-1">
          <input
            type="checkbox"
            checked={draft.lightingAvailable}
            onChange={(e) => setDraft({ ...draft, lightingAvailable: e.target.checked })}
            className="w-4 h-4 accent-primary"
          />
          <span className="text-sm font-medium text-text-dark">Floodlights available</span>
        </label>
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
