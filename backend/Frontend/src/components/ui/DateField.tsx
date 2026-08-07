import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Calendar as CalendarIcon, ChevronLeft, ChevronRight } from 'lucide-react';

/**
 * Custom, dependency-free, brand-styled date picker.
 * Replaces the native <input type="date"> so the calendar matches the site UI.
 * Values are local "YYYY-MM-DD" strings; selection is constrained to [minDate, maxDate].
 */

const WEEKDAYS = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

const pad = (n: number) => String(n).padStart(2, '0');
const isoOf = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const parseISO = (s: string) => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d); };
const startOfMonth = (d: Date) => new Date(d.getFullYear(), d.getMonth(), 1);
const sameDay = (a: Date | null, b: Date | null) =>
  !!a && !!b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

interface DateFieldProps {
  value: string;
  onChange: (iso: string) => void;
  minDate?: string;
  maxDate?: string;
  disabled?: boolean;
  placeholder?: string;
}

export const DateField: React.FC<DateFieldProps> = ({ value, onChange, minDate, maxDate, disabled, placeholder = 'Select date' }) => {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  const selected = value ? parseISO(value) : null;
  const min = minDate ? parseISO(minDate) : null;
  const max = maxDate ? parseISO(maxDate) : null;

  const [view, setView] = useState<Date>(() => startOfMonth(selected || min || new Date()));

  // Re-centre the calendar on open.
  useEffect(() => {
    if (open) setView(startOfMonth(selected || min || new Date()));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  // Close on outside click / Escape.
  useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => { if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false); };
    const onEsc = (e: KeyboardEvent) => { if (e.key === 'Escape') setOpen(false); };
    document.addEventListener('mousedown', onDoc);
    document.addEventListener('keydown', onEsc);
    return () => { document.removeEventListener('mousedown', onDoc); document.removeEventListener('keydown', onEsc); };
  }, [open]);

  const cells = useMemo(() => {
    const y = view.getFullYear(), m = view.getMonth();
    const startWeekday = new Date(y, m, 1).getDay();
    const daysInMonth = new Date(y, m + 1, 0).getDate();
    const out: { date: Date; inMonth: boolean }[] = [];
    for (let i = 0; i < startWeekday; i++) out.push({ date: new Date(y, m, i - startWeekday + 1), inMonth: false });
    for (let d = 1; d <= daysInMonth; d++) out.push({ date: new Date(y, m, d), inMonth: true });
    while (out.length < 42) { const l = out[out.length - 1].date; out.push({ date: new Date(l.getFullYear(), l.getMonth(), l.getDate() + 1), inMonth: false }); }
    return out;
  }, [view]);

  const isDisabledDay = (d: Date) => (!!min && d < min) || (!!max && d > max);
  const canPrev = !min || startOfMonth(view) > startOfMonth(min);
  const canNext = !max || new Date(view.getFullYear(), view.getMonth() + 1, 1) <= startOfMonth(max);

  const label = selected ? selected.toLocaleDateString('en-US', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' }) : '';

  return (
    <div className="relative" ref={ref}>
      <button
        type="button"
        disabled={disabled}
        onClick={() => setOpen((o) => !o)}
        className={`w-full flex items-center justify-between bg-white border rounded-[12px] pl-4 pr-3 py-3 text-[15px] text-left transition-colors focus:outline-none ${open ? 'border-brand-primary' : 'border-slate-200'} ${disabled ? 'bg-slate-50 text-slate-400 cursor-not-allowed' : 'hover:border-slate-300'}`}
      >
        <span className={selected ? 'text-slate-900' : 'text-slate-400'}>{selected ? label : placeholder}</span>
        <CalendarIcon size={17} className="text-slate-400 shrink-0" />
      </button>

      {open && !disabled && (
        <div className="absolute z-50 mt-2 left-0 w-[300px] bg-white border border-slate-200 rounded-[16px] shadow-xl p-3">
          <div className="flex items-center justify-between mb-2 px-1">
            <button type="button" disabled={!canPrev} onClick={() => setView(new Date(view.getFullYear(), view.getMonth() - 1, 1))}
              className={`w-8 h-8 rounded-lg flex items-center justify-center transition-colors ${canPrev ? 'hover:bg-brand-tint text-slate-600' : 'text-slate-300 cursor-not-allowed'}`} aria-label="Previous month">
              <ChevronLeft size={18} />
            </button>
            <span className="text-[14px] font-semibold text-slate-900">{MONTHS[view.getMonth()]} {view.getFullYear()}</span>
            <button type="button" disabled={!canNext} onClick={() => setView(new Date(view.getFullYear(), view.getMonth() + 1, 1))}
              className={`w-8 h-8 rounded-lg flex items-center justify-center transition-colors ${canNext ? 'hover:bg-brand-tint text-slate-600' : 'text-slate-300 cursor-not-allowed'}`} aria-label="Next month">
              <ChevronRight size={18} />
            </button>
          </div>

          <div className="grid grid-cols-7 mb-1">
            {WEEKDAYS.map((w) => <div key={w} className="text-center text-[11px] text-slate-400 py-1">{w}</div>)}
          </div>

          <div className="grid grid-cols-7 gap-0.5">
            {cells.map(({ date, inMonth }, i) => {
              const dis = isDisabledDay(date);
              const sel = sameDay(date, selected);
              return (
                <button
                  key={i}
                  type="button"
                  disabled={dis}
                  onClick={() => { onChange(isoOf(date)); setOpen(false); }}
                  className={`h-9 rounded-lg text-[13px] flex items-center justify-center transition-colors ${
                    sel ? 'bg-brand-bright text-white font-semibold'
                      : dis ? 'text-slate-300 cursor-not-allowed'
                      : inMonth ? 'text-slate-700 hover:bg-brand-tint' : 'text-slate-300 hover:bg-slate-50'
                  }`}
                >
                  {date.getDate()}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
};

export default DateField;
