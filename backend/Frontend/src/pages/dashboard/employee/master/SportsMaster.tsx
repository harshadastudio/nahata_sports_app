/**
 * Employee → Sports. Complex-scoped: the API returns and accepts only the
 * employee's own complex, so no complex selector is shown or sent.
 */
import React, { useCallback, useEffect, useState } from 'react';
import { Trophy, Pencil, Trash2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import {
  API, ModuleShell, DataCard, EmptyState, FormPanel, Field, inputCls, StatusPill, readError,
} from './ModuleShell';

interface Sport {
  id: number;
  name: string;
  description?: string | null;
  category?: string | null;
  minAge?: number | null;
  maxAge?: number | null;
  allowedMembers?: number | null;
  status: 'Active' | 'Inactive';
}

const CATEGORIES = ['Indoor', 'Outdoor', 'Aquatic', 'Adventure'];

const emptyDraft = {
  name: '', description: '', category: 'Indoor',
  minAge: '', maxAge: '', allowedMembers: '', status: 'Active' as 'Active' | 'Inactive',
};

export default function SportsMaster() {
  const [rows, setRows] = useState<Sport[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Sport | null>(null);
  const [draft, setDraft] = useState(emptyDraft);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetchWithAuth(`${API}/sports?limit=200`);
      if (!res.ok) throw new Error(await readError(res, 'Failed to load sports.'));
      const json = await res.json();
      const list = json.data?.sports ?? json.data ?? [];
      setRows(Array.isArray(list) ? list : []);
    } catch (err: any) {
      setError(err.message);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const openCreate = () => { setEditing(null); setDraft(emptyDraft); setFormError(null); setOpen(true); };

  const openEdit = (s: Sport) => {
    setEditing(s);
    setDraft({
      name: s.name ?? '',
      description: s.description ?? '',
      category: s.category ?? 'Indoor',
      minAge: s.minAge != null ? String(s.minAge) : '',
      maxAge: s.maxAge != null ? String(s.maxAge) : '',
      allowedMembers: s.allowedMembers != null ? String(s.allowedMembers) : '',
      status: s.status ?? 'Active',
    });
    setFormError(null);
    setOpen(true);
  };

  const save = async () => {
    if (!draft.name.trim()) { setFormError('Sport name is required.'); return; }
    setSaving(true);
    setFormError(null);
    try {
      // sportComplexId is deliberately omitted — the API stamps the employee's
      // own complex and ignores any client-supplied value.
      const payload = {
        name: draft.name.trim(),
        description: draft.description.trim() || null,
        category: draft.category || null,
        minAge: draft.minAge ? Number(draft.minAge) : null,
        maxAge: draft.maxAge ? Number(draft.maxAge) : null,
        allowedMembers: draft.allowedMembers ? Number(draft.allowedMembers) : null,
        status: draft.status,
      };
      const res = await fetchWithAuth(
        editing ? `${API}/sports/${editing.id}` : `${API}/sports`,
        { method: editing ? 'PUT' : 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) }
      );
      if (!res.ok) throw new Error(await readError(res, 'Failed to save sport.'));
      toast.success(editing ? 'Sport updated' : 'Sport created');
      setOpen(false);
      load();
    } catch (err: any) {
      setFormError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const remove = async (s: Sport) => {
    if (!window.confirm(`Delete "${s.name}"? This cannot be undone.`)) return;
    try {
      const res = await fetchWithAuth(`${API}/sports/${s.id}`, { method: 'DELETE' });
      if (!res.ok) throw new Error(await readError(res, 'Failed to delete sport.'));
      toast.success('Sport deleted');
      load();
    } catch (err: any) {
      toast.error(err.message);
    }
  };

  return (
    <ModuleShell
      title="Sports"
      subtitle="Manage the sports offered at your complex."
      icon={<Trophy size={20} />}
      loading={loading}
      error={error}
      onRefresh={load}
      onAdd={openCreate}
      addLabel="Add Sport"
    >
      {rows.length === 0 ? (
        <EmptyState message="No sports yet. Add your first sport to get started." />
      ) : (
        <DataCard headers={['Name', 'Category', 'Max Members', 'Status', 'Actions']}>
          {rows.map((s) => (
            <tr key={s.id} className="hover:bg-slate-50 transition-colors">
              <td className="px-5 py-3.5">
                <p className="text-sm font-bold text-text-dark">{s.name}</p>
                {s.description && <p className="text-[11px] text-text-muted line-clamp-1 mt-0.5">{s.description}</p>}
              </td>
              <td className="px-5 py-3.5 text-sm text-text-dark whitespace-nowrap">{s.category ?? '—'}</td>
              <td className="px-5 py-3.5 text-sm text-text-muted whitespace-nowrap">{s.allowedMembers ?? '—'}</td>
              <td className="px-5 py-3.5"><StatusPill active={s.status === 'Active'} /></td>
              <td className="px-5 py-3.5">
                <div className="flex items-center gap-2">
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
        title={editing ? 'Edit Sport' : 'Add Sport'}
        saving={saving}
        error={formError}
        onClose={() => setOpen(false)}
        onSave={save}
      >
        <Field label="Sport Name *">
          <input className={inputCls} value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} placeholder="e.g. Badminton" />
        </Field>
        <Field label="Description">
          <textarea rows={3} className={`${inputCls} resize-none`} value={draft.description} onChange={(e) => setDraft({ ...draft, description: e.target.value })} />
        </Field>
        <Field label="Category">
          <select className={inputCls} value={draft.category} onChange={(e) => setDraft({ ...draft, category: e.target.value })}>
            {CATEGORIES.map((c) => <option key={c} value={c}>{c}</option>)}
          </select>
        </Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Min Age">
            <input type="number" min={0} className={inputCls} value={draft.minAge} onChange={(e) => setDraft({ ...draft, minAge: e.target.value })} />
          </Field>
          <Field label="Max Age">
            <input type="number" min={0} className={inputCls} value={draft.maxAge} onChange={(e) => setDraft({ ...draft, maxAge: e.target.value })} />
          </Field>
        </div>
        <Field label="Max Members Per Booking">
          <input type="number" min={1} className={inputCls} value={draft.allowedMembers} onChange={(e) => setDraft({ ...draft, allowedMembers: e.target.value })} />
        </Field>
        <Field label="Status">
          <select className={inputCls} value={draft.status} onChange={(e) => setDraft({ ...draft, status: e.target.value as 'Active' | 'Inactive' })}>
            <option value="Active">Active</option>
            <option value="Inactive">Inactive</option>
          </select>
        </Field>
      </FormPanel>
    </ModuleShell>
  );
}
