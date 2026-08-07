import React, { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import {
  Trophy, Search, RefreshCw, Loader2, AlertCircle,
  Users, MapPin, ChevronRight, X, Tag, Clock,
  Dumbbell, Star, Zap, Info,
} from 'lucide-react';
import { UserMainLayout } from '../../components/user-layout/UserMainLayout';
import { getImageUrl } from '../../lib/utils';
import { SmartImage } from '../../components/ui/SmartImage';

// ── Types ─────────────────────────────────────────────────────────────────────
interface Sport {
  id: number;
  name: string;
  description?: string;
  category?: 'Indoor' | 'Outdoor' | 'Aquatic' | 'Adventure' | string;
  image?: string;
  status: 'Active' | 'Inactive';
  minAge?: number;
  maxAge?: number;
  allowedMembers?: number;
  achievements?: string;
  completeInformation?: string;
  courtCount: number;
  availableCourts: number;
  programCount: number;
}

// ── Helpers ───────────────────────────────────────────────────────────────────
const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

const CATEGORY_STYLES: Record<string, { bg: string; text: string; icon: React.ReactNode }> = {
  Outdoor:   { bg: 'bg-green-100',  text: 'text-green-700',  icon: <Trophy size={11} /> },
  Indoor:    { bg: 'bg-blue-100',   text: 'text-blue-700',   icon: <Dumbbell size={11} /> },
  Aquatic:   { bg: 'bg-cyan-100',   text: 'text-cyan-700',   icon: <Star size={11} /> },
  Adventure: { bg: 'bg-orange-100', text: 'text-orange-700', icon: <Zap size={11} /> },
};

function getSportImage(sport: Sport): string {
  return sport.image ? getImageUrl(sport.image) : '';
}

// ── Detail Modal ──────────────────────────────────────────────────────────────
interface DetailModalProps {
  sport: Sport;
  onClose: () => void;
}

const DetailModal: React.FC<DetailModalProps> = ({ sport, onClose }) => {
  const catStyle = CATEGORY_STYLES[sport.category || 'Outdoor'] ?? CATEGORY_STYLES.Outdoor;
  const isAvailable = sport.status === 'Active' && sport.availableCourts > 0;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div
        className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
        onClick={onClose}
      />
      <div className="relative bg-white rounded-3xl shadow-2xl w-full max-w-lg overflow-hidden max-h-[90vh] flex flex-col">
        {/* Hero image */}
        <div className="relative h-48 shrink-0 overflow-hidden">
          <SmartImage
            src={getSportImage(sport)}
            alt={sport.name}
            className="w-full h-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-slate-900/70 to-transparent" />
          <div className="absolute bottom-4 left-5 right-12">
            <h2 className="text-white font-black text-2xl leading-tight">{sport.name}</h2>
            {sport.category && (
              <span className={`inline-flex items-center gap-1 mt-1 px-2.5 py-0.5 rounded-full text-[10px] font-bold ${catStyle.bg} ${catStyle.text}`}>
                {catStyle.icon} {sport.category}
              </span>
            )}
          </div>
          <button
            onClick={onClose}
            className="absolute top-4 right-4 p-1.5 bg-white/20 hover:bg-white/40 rounded-full text-white transition-colors backdrop-blur-sm"
          >
            <X size={18} />
          </button>
        </div>

        {/* Content */}
        <div className="overflow-y-auto flex-1 p-6 space-y-5">
          {/* Status + stats row */}
          <div className="grid grid-cols-3 gap-3">
            <div className="bg-slate-50 rounded-2xl p-3 text-center">
              <p className="text-lg font-black text-text-dark">{sport.courtCount}</p>
              <p className="text-[10px] text-text-muted font-semibold mt-0.5">Total Courts</p>
            </div>
            <div className="bg-slate-50 rounded-2xl p-3 text-center">
              <p className="text-lg font-black text-green-600">{sport.availableCourts}</p>
              <p className="text-[10px] text-text-muted font-semibold mt-0.5">Available</p>
            </div>
            <div className="bg-slate-50 rounded-2xl p-3 text-center">
              <p className="text-lg font-black text-primary">{sport.programCount}</p>
              <p className="text-[10px] text-text-muted font-semibold mt-0.5">Programs</p>
            </div>
          </div>

          {/* Availability badge */}
          <div className={`flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-bold ${
            isAvailable ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-600'
          }`}>
            <span className={`w-2 h-2 rounded-full ${isAvailable ? 'bg-green-500' : 'bg-red-500'}`} />
            {isAvailable ? 'Courts Available for Booking' : 'No Courts Available Right Now'}
          </div>

          {/* Description */}
          {sport.description && (
            <div>
              <h3 className="text-xs font-black text-text-muted uppercase tracking-widest mb-2 flex items-center gap-1.5">
                <Info size={12} /> About
              </h3>
              <p className="text-sm text-text-muted leading-relaxed">{sport.description}</p>
            </div>
          )}

          {/* Age range + members */}
          {(sport.minAge || sport.maxAge || sport.allowedMembers) && (
            <div className="grid grid-cols-2 gap-3">
              {(sport.minAge || sport.maxAge) && (
                <div className="flex items-start gap-2.5 bg-slate-50 rounded-xl p-3">
                  <Clock size={15} className="text-primary mt-0.5 shrink-0" />
                  <div>
                    <p className="text-[10px] font-black text-text-muted uppercase tracking-wider">Age Range</p>
                    <p className="text-sm font-bold text-text-dark mt-0.5">
                      {sport.minAge ?? '—'} – {sport.maxAge ?? '—'} yrs
                    </p>
                  </div>
                </div>
              )}
              {sport.allowedMembers ? (
                <div className="flex items-start gap-2.5 bg-slate-50 rounded-xl p-3">
                  <Users size={15} className="text-primary mt-0.5 shrink-0" />
                  <div>
                    <p className="text-[10px] font-black text-text-muted uppercase tracking-wider">Max Members</p>
                    <p className="text-sm font-bold text-text-dark mt-0.5">{sport.allowedMembers}</p>
                  </div>
                </div>
              ) : null}
            </div>
          )}

          {/* Achievements */}
          {sport.achievements && (
            <div>
              <h3 className="text-xs font-black text-text-muted uppercase tracking-widest mb-2 flex items-center gap-1.5">
                <Star size={12} /> Achievements
              </h3>
              <p className="text-sm text-text-muted leading-relaxed">{sport.achievements}</p>
            </div>
          )}

          {/* Complete information */}
          {sport.completeInformation && (
            <div>
              <h3 className="text-xs font-black text-text-muted uppercase tracking-widest mb-2 flex items-center gap-1.5">
                <Tag size={12} /> More Information
              </h3>
              <p className="text-sm text-text-muted leading-relaxed">{sport.completeInformation}</p>
            </div>
          )}
        </div>

        {/* Footer CTA */}
        <div className="p-5 border-t border-border shrink-0">
          <Link
            to="/book"
            className="w-full flex items-center justify-center gap-2 bg-primary hover:bg-primary/90 text-white py-3 rounded-2xl text-sm font-bold transition-all"
          >
            <MapPin size={15} />
            Book a Court
          </Link>
        </div>
      </div>
    </div>
  );
};

// ── Main Component ────────────────────────────────────────────────────────────
const CATEGORIES = ['All', 'Outdoor', 'Indoor', 'Aquatic', 'Adventure'] as const;

export const ViewSports: React.FC = () => {
  const [sports, setSports]         = useState<Sport[]>([]);
  const [loading, setLoading]       = useState(true);
  const [error, setError]           = useState<string | null>(null);
  const [search, setSearch]         = useState('');
  const [category, setCategory]     = useState<string>('All');
  const [selected, setSelected]     = useState<Sport | null>(null);

  const fetchSports = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`${API_BASE}/sports?status=Active&limit=100`);
      const json = await res.json();
      if (!res.ok) throw new Error(json.message || `Error ${res.status}`);
      setSports(Array.isArray(json.data) ? json.data : []);
    } catch (err: any) {
      setError(err.message || 'Failed to load sports');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchSports(); }, [fetchSports]);

  // Client-side filter
  const filtered = sports.filter((s) => {
    const matchSearch = !search || s.name.toLowerCase().includes(search.toLowerCase());
    const matchCat    = category === 'All' || s.category === category;
    return matchSearch && matchCat;
  });

  const availableCount   = sports.filter((s) => s.availableCourts > 0).length;
  const unavailableCount = sports.filter((s) => s.availableCourts === 0).length;

  return (
    <UserMainLayout
      breadcrumbs={[
        { label: 'Dashboard' },
        { label: 'View Sports', active: true },
      ]}
    >
      <div className="space-y-6">

        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">View Sports</h1>
            <p className="text-text-muted text-sm mt-1">
              Browse all available sports and facilities.
            </p>
          </div>
          <button
            onClick={fetchSports}
            disabled={loading}
            className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm font-semibold text-text-muted hover:bg-slate-50 transition-colors disabled:opacity-50 self-start sm:self-auto"
          >
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
            Refresh
          </button>
        </div>

        {/* Error */}
        {error && (
          <div className="flex items-center gap-3 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl text-sm">
            <AlertCircle size={16} className="shrink-0" />
            {error}
          </div>
        )}

        {loading ? (
          <div className="flex items-center justify-center py-24 text-slate-400">
            <Loader2 size={32} className="animate-spin" />
          </div>
        ) : (
          <>
            {/* Summary strip */}
            {sports.length > 0 && (
              <div className="grid grid-cols-3 gap-4">
                {[
                  { label: 'Total Sports',  value: sports.length,    color: 'text-text-dark' },
                  { label: 'Available',     value: availableCount,   color: 'text-green-600' },
                  { label: 'Unavailable',   value: unavailableCount, color: 'text-red-500'   },
                ].map((s) => (
                  <div key={s.label} className="bg-white rounded-2xl border border-border p-4 text-center">
                    <p className={`text-2xl font-bold ${s.color}`}>{s.value}</p>
                    <p className="text-xs text-text-muted mt-1">{s.label}</p>
                  </div>
                ))}
              </div>
            )}

            {/* Search + Category filters */}
            <div className="flex flex-col sm:flex-row gap-3">
              <div className="relative flex-1">
                <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                <input
                  type="text"
                  placeholder="Search sports…"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="w-full pl-9 pr-4 py-2.5 bg-white border border-border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                />
              </div>
              <div className="flex gap-2 flex-wrap">
                {CATEGORIES.map((cat) => (
                  <button
                    key={cat}
                    onClick={() => setCategory(cat)}
                    className={`px-3 py-2 rounded-xl text-xs font-bold transition-colors ${
                      category === cat
                        ? 'bg-primary text-white'
                        : 'bg-white border border-border text-text-muted hover:bg-slate-50'
                    }`}
                  >
                    {cat}
                  </button>
                ))}
              </div>
            </div>

            {/* Cards grid */}
            {filtered.length === 0 ? (
              <div className="bg-white rounded-2xl border border-border p-16 text-center">
                <Trophy size={36} className="text-slate-300 mx-auto mb-3" />
                <p className="font-semibold text-text-dark mb-1">No sports found</p>
                <p className="text-text-muted text-sm">
                  {search || category !== 'All' ? 'Try adjusting your filters.' : 'No sports are available right now.'}
                </p>
              </div>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                {filtered.map((sport) => {
                  const catStyle = CATEGORY_STYLES[sport.category || 'Outdoor'] ?? CATEGORY_STYLES.Outdoor;
                  const isAvailable = sport.status === 'Active' && sport.availableCourts > 0;

                  return (
                    <div
                      key={sport.id}
                      className="bg-white rounded-2xl border border-border overflow-hidden hover:shadow-md transition-shadow cursor-pointer group"
                      onClick={() => setSelected(sport)}
                    >
                      {/* Sport image */}
                      <div className="relative h-36 overflow-hidden">
                        <SmartImage
                          src={getSportImage(sport)}
                          alt={sport.name}
                          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                        />
                        <div className="absolute inset-0 bg-gradient-to-t from-slate-900/50 to-transparent" />
                        {/* Category badge */}
                        {sport.category && (
                          <span className={`absolute top-3 left-3 inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold ${catStyle.bg} ${catStyle.text}`}>
                            {catStyle.icon} {sport.category}
                          </span>
                        )}
                        {/* Availability badge */}
                        <span className={`absolute top-3 right-3 px-2 py-0.5 rounded-full text-[10px] font-bold ${
                          isAvailable ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-600'
                        }`}>
                          {isAvailable ? 'Available' : 'Unavailable'}
                        </span>
                      </div>

                      {/* Card body */}
                      <div className="p-5">
                        <div className="flex items-start justify-between gap-2 mb-3">
                          <div>
                            <p className="font-bold text-text-dark text-base leading-tight">{sport.name}</p>
                            {sport.description && (
                              <p className="text-xs text-text-muted mt-1 line-clamp-2 leading-relaxed">
                                {sport.description}
                              </p>
                            )}
                          </div>
                          <ChevronRight size={16} className="text-slate-300 group-hover:text-primary transition-colors shrink-0 mt-0.5" />
                        </div>

                        {/* Stats row */}
                        <div className="flex items-center gap-4 text-xs text-text-muted">
                          <span className="flex items-center gap-1">
                            <MapPin size={11} className="text-primary" />
                            {sport.courtCount} court{sport.courtCount !== 1 ? 's' : ''}
                          </span>
                          {sport.availableCourts > 0 && (
                            <span className="flex items-center gap-1 text-green-600 font-semibold">
                              <span className="w-1.5 h-1.5 rounded-full bg-green-500" />
                              {sport.availableCourts} available
                            </span>
                          )}
                          {sport.programCount > 0 && (
                            <span className="flex items-center gap-1">
                              <Users size={11} className="text-primary" />
                              {sport.programCount} program{sport.programCount !== 1 ? 's' : ''}
                            </span>
                          )}
                        </div>

                        {/* Age range */}
                        {(sport.minAge || sport.maxAge) && (
                          <p className="text-[10px] text-text-muted mt-2 flex items-center gap-1">
                            <Clock size={10} />
                            Age: {sport.minAge ?? '—'} – {sport.maxAge ?? '—'} yrs
                          </p>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </>
        )}
      </div>

      {/* Detail Modal */}
      {selected && (
        <DetailModal sport={selected} onClose={() => setSelected(null)} />
      )}
    </UserMainLayout>
  );
};

export default ViewSports;
