/**
 * Employee → Fees Management. Student fee records for the employee's own
 * complex (the API joins through Batch.sportComplexId to enforce that).
 *
 * Full CRUD: create an enrollment fee record, edit the amount/status, delete a
 * record. Approving a payment (which issues the student gate pass) stays in the
 * separate Fees Approval module so the two permissions can be granted apart.
 */
import React, { useCallback, useEffect, useState } from 'react';
import { IndianRupee, Pencil, Trash2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import {
  API, ModuleShell, DataCard, EmptyState, FormPanel, Field, inputCls, readError,
} from './ModuleShell';

interface FeeRecord {
  id: number;
  studentId: number;
  batchId: number;
  amountPaid: string | number;
  paymentStatus: 'Pending' | 'Paid' | 'Partial' | 'Overdue';
  approvalStatus: 'Pending' | 'Approved' | 'Rejected';
  enrollmentDate?: string | null;
  notes?: string | null;
  student?: { id: number; User?: { name?: string; phone_number?: string } } | null;
  batch?: { id: number; name?: string; fees?: string | number; sport?: { name?: string } } | null;
}

interface StudentOption { id: number; name: string }
interface BatchOption { id: number; name: string; fees?: string | number }

const PAYMENT_STATUS = ['Pending', 'Paid', 'Partial', 'Overdue'] as const;

const STATUS_STYLES: Record<string, string> = {
  Paid: 'bg-green-50 text-green-700',
  Pending: 'bg-amber-50 text-amber-700',
  Partial: 'bg-blue-50 text-blue-700',
  Overdue: 'bg-red-50 text-red-600',
  Approved: 'bg-green-50 text-green-700',
  Rejected: 'bg-red-50 text-red-600',
};

const Pill: React.FC<{ value: string }> = ({ value }) => (
  <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold ${STATUS_STYLES[value] ?? 'bg-slate-100 text-slate-600'}`}>
    {value}
  </span>
);

const emptyDraft = {
  studentId: '', batchId: '', amountPaid: '',
  paymentStatus: 'Pending', enrollmentDate: '', notes: '',
};

export default function FeesManagementPage() {
  const [rows, setRows] = useState<FeeRecord[]>([]);
  const [students, setStudents] = useState<StudentOption[]>([]);
  const [batches, setBatches] = useState<BatchOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState('');

  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<FeeRecord | null>(null);
  const [draft, setDraft] = useState(emptyDraft);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const qs = new URLSearchParams({ limit: '200' });
      if (statusFilter) qs.set('paymentStatus', statusFilter);
      const res = await fetchWithAuth(`${API}/fees?${qs.toString()}`);
      if (!res.ok) throw new Error(await readError(res, 'Failed to load fee records.'));
      const json = await res.json();
      const list = json.data?.fees ?? json.data ?? [];
      setRows(Array.isArray(list) ? list : []);
    } catch (err: any) {
      setError(err.message);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [statusFilter]);

  useEffect(() => { load(); }, [load]);

  // Pickers for the create form. Both lists are complex-scoped by the API.
  useEffect(() => {
    (async () => {
      try {
        const [sRes, bRes] = await Promise.all([
          fetchWithAuth(`${API}/students?limit=300`),
          fetchWithAuth(`${API}/batches?limit=200`),
        ]);
        if (sRes.ok) {
          const j = await sRes.json();
          const l = j.data?.students ?? j.data ?? [];
          setStudents(
            (Array.isArray(l) ? l : []).map((s: any) => ({
              id: s.id,
              name: s.User?.name ?? s.name ?? `Student #${s.id}`,
            }))
          );
        }
        if (bRes.ok) {
          const j = await bRes.json();
          const l = j.data?.batches ?? j.data ?? [];
          setBatches((Array.isArray(l) ? l : []).map((b: any) => ({ id: b.id, name: b.name, fees: b.fees })));
        }
      } catch {
        /* non-fatal: the create form just shows empty pickers */
      }
    })();
  }, []);

  const openCreate = () => { setEditing(null); setDraft(emptyDraft); setFormError(null); setOpen(true); };

  const openEdit = (r: FeeRecord) => {
    setEditing(r);
    setDraft({
      studentId: String(r.studentId ?? ''),
      batchId: String(r.batchId ?? ''),
      amountPaid: r.amountPaid != null ? String(r.amountPaid) : '',
      paymentStatus: r.paymentStatus ?? 'Pending',
      enrollmentDate: (r.enrollmentDate ?? '').slice(0, 10),
      notes: r.notes ?? '',
    });
    setFormError(null);
    setOpen(true);
  };

  const save = async () => {
    if (!editing && (!draft.studentId || !draft.batchId)) {
      setFormError('Select both a student and a batch.');
      return;
    }
    if (draft.amountPaid === '' || Number(draft.amountPaid) < 0) {
      setFormError('Enter a valid amount.');
      return;
    }
    setSaving(true);
    setFormError(null);
    try {
      const body: Record<string, any> = {
        amountPaid: Number(draft.amountPaid),
        paymentStatus: draft.paymentStatus,
        notes: draft.notes.trim() || null,
      };
      if (!editing) {
        body.studentId = Number(draft.studentId);
        body.batchId = Number(draft.batchId);
        body.enrollmentDate = draft.enrollmentDate || new Date().toISOString().slice(0, 10);
      }
      const res = await fetchWithAuth(
        editing ? `${API}/fees/${editing.id}` : `${API}/fees`,
        { method: editing ? 'PUT' : 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }
      );
      if (!res.ok) throw new Error(await readError(res, 'Failed to save fee record.'));
      toast.success(editing ? 'Fee record updated' : 'Fee record created');
      setOpen(false);
      load();
    } catch (err: any) {
      setFormError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const remove = async (r: FeeRecord) => {
    const who = r.student?.User?.name ?? 'this student';
    if (!window.confirm(`Delete the fee record for ${who}? This cannot be undone.`)) return;
    try {
      const res = await fetchWithAuth(`${API}/fees/${r.id}`, { method: 'DELETE' });
      if (!res.ok) throw new Error(await readError(res, 'Failed to delete fee record.'));
      toast.success('Fee record deleted');
      load();
    } catch (err: any) {
      toast.error(err.message);
    }
  };

  const selectedBatch = batches.find((b) => String(b.id) === draft.batchId);

  return (
    <ModuleShell
      title="Fees Management"
      subtitle="Record and correct student fee payments for your complex."
      icon={<IndianRupee size={20} />}
      loading={loading}
      error={error}
      onRefresh={load}
      onAdd={openCreate}
      addLabel="Add Fee Record"
      toolbar={
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-4 py-2.5 bg-white border border-border rounded-xl text-sm font-medium focus:outline-none focus:ring-2 focus:ring-primary/20"
        >
          <option value="">All Payment Status</option>
          {PAYMENT_STATUS.map((s) => <option key={s} value={s}>{s}</option>)}
        </select>
      }
    >
      {rows.length === 0 ? (
        <EmptyState message="No fee records found for your complex." />
      ) : (
        <DataCard headers={['Student', 'Batch', 'Sport', 'Batch Fee', 'Paid', 'Payment', 'Approval', 'Actions']}>
          {rows.map((r) => (
            <tr key={r.id} className="hover:bg-slate-50 transition-colors">
              <td className="px-5 py-3.5">
                <p className="text-sm font-bold text-text-dark">{r.student?.User?.name ?? '—'}</p>
                {r.student?.User?.phone_number && (
                  <p className="text-[11px] text-text-muted mt-0.5">{r.student.User.phone_number}</p>
                )}
              </td>
              <td className="px-5 py-3.5 text-sm text-text-dark whitespace-nowrap">{r.batch?.name ?? '—'}</td>
              <td className="px-5 py-3.5 text-sm text-text-muted whitespace-nowrap">{r.batch?.sport?.name ?? '—'}</td>
              <td className="px-5 py-3.5 text-sm text-text-muted whitespace-nowrap">
                ₹{Number(r.batch?.fees ?? 0).toLocaleString('en-IN')}
              </td>
              <td className="px-5 py-3.5 text-sm font-bold text-text-dark whitespace-nowrap">
                ₹{Number(r.amountPaid ?? 0).toLocaleString('en-IN')}
              </td>
              <td className="px-5 py-3.5"><Pill value={r.paymentStatus} /></td>
              <td className="px-5 py-3.5"><Pill value={r.approvalStatus} /></td>
              <td className="px-5 py-3.5">
                <div className="flex items-center gap-2">
                  <button onClick={() => openEdit(r)} className="p-2 bg-blue-50 text-blue-600 rounded-lg hover:bg-blue-100" title="Edit">
                    <Pencil size={14} />
                  </button>
                  <button onClick={() => remove(r)} className="p-2 bg-red-50 text-red-600 rounded-lg hover:bg-red-100" title="Delete">
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
        title={editing ? 'Update Fee Payment' : 'Add Fee Record'}
        saving={saving}
        error={formError}
        onClose={() => setOpen(false)}
        onSave={save}
      >
        {editing ? (
          <div className="bg-slate-50 border border-border rounded-xl p-3 text-xs">
            <p className="font-bold text-text-dark">{editing.student?.User?.name ?? 'Student'}</p>
            <p className="text-text-muted mt-0.5">
              {editing.batch?.name ?? '—'} · Batch fee ₹{Number(editing.batch?.fees ?? 0).toLocaleString('en-IN')}
            </p>
          </div>
        ) : (
          <>
            <Field label="Student *">
              <select className={inputCls} value={draft.studentId} onChange={(e) => setDraft({ ...draft, studentId: e.target.value })}>
                <option value="">— Select Student —</option>
                {students.map((s) => <option key={s.id} value={String(s.id)}>{s.name}</option>)}
              </select>
            </Field>
            <Field label="Batch *">
              <select className={inputCls} value={draft.batchId} onChange={(e) => setDraft({ ...draft, batchId: e.target.value })}>
                <option value="">— Select Batch —</option>
                {batches.map((b) => <option key={b.id} value={String(b.id)}>{b.name}</option>)}
              </select>
            </Field>
            {selectedBatch && (
              <p className="text-[11px] text-text-muted -mt-2">
                Batch fee: ₹{Number(selectedBatch.fees ?? 0).toLocaleString('en-IN')}
              </p>
            )}
            <Field label="Enrollment Date">
              <input type="date" className={inputCls} value={draft.enrollmentDate} onChange={(e) => setDraft({ ...draft, enrollmentDate: e.target.value })} />
            </Field>
          </>
        )}

        <Field label="Amount Paid (₹) *">
          <input type="number" min={0} className={inputCls} value={draft.amountPaid} onChange={(e) => setDraft({ ...draft, amountPaid: e.target.value })} />
        </Field>
        <Field label="Payment Status">
          <select className={inputCls} value={draft.paymentStatus} onChange={(e) => setDraft({ ...draft, paymentStatus: e.target.value })}>
            {PAYMENT_STATUS.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
        </Field>
        <Field label="Notes">
          <textarea rows={3} className={`${inputCls} resize-none`} value={draft.notes} onChange={(e) => setDraft({ ...draft, notes: e.target.value })} />
        </Field>
        <p className="text-[11px] text-text-muted">
          Approving a payment (which issues the student gate pass) is handled in the Fees Approval module.
        </p>
      </FormPanel>
    </ModuleShell>
  );
}
