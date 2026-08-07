/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { motion, AnimatePresence } from 'motion/react';
import { 
 Trophy, 
 Clock, 
 Calendar, 
 Award, 
 CheckCircle2, 
 ShieldCheck,
 ArrowRight,
 AlertCircle,
 Loader2,
 X,
 Phone,
 Mail,
 User,
 Users,
 CalendarRange,
 Lock
} from 'lucide-react';
import { useState, useEffect, useMemo } from 'react';
import { Button } from '../components/UI';
import { PhoneInput } from '../components/PhoneInput';
import { useAppDispatch, useAppSelector } from '../store/hooks';
import { 
 fetchSports, 
 fetchCoaches, 
 fetchBatchesAndPrograms,
 fetchSportComplexes,
 clearError 
} from '../store/slices/coachingSlice';
import type { Batch, Ground, Coach } from '../types/coaching';
import { coachingApi } from '../services/coachingApi';
import { useNavigate, useSearchParams } from 'react-router-dom';
import axios from 'axios';
import toast from 'react-hot-toast';
import { useAuth } from '../contexts/AuthContext';
import { getIconComponent } from '../mappers/sportMapper';
import { SmartImage } from '../components/ui/SmartImage';

// ── Logical Dummy Data ────────────────────────────────────────────────────────
const DUMMY_SPORTS = [
  { id: 101, name: 'Cricket', iconName: 'cricket', image: '' },
  { id: 102, name: 'Badminton', iconName: 'badminton', image: '' },
  { id: 103, name: 'Basketball', iconName: 'basketball', image: '' },
  { id: 104, name: 'Football', iconName: 'football', image: '' },
  { id: 105, name: 'Skating', iconName: 'skating', image: '' },
  { id: 106, name: 'Karate', iconName: 'karate', image: '' },
  { id: 107, name: 'Zumba', iconName: 'zumba', image: '' },
  { id: 108, name: 'Yoga', iconName: 'yoga', image: '' },
];

const DUMMY_BATCHES: Batch[] = [
  {
    id: -1,
    name: 'Morning Champions',
    type: 'Professional',
    price: '₹2,500',
    timing: '06:00 AM - 08:00 AM',
    days: 'Mon, Wed, Fri',
    currentStudents: 12,
    maxStudents: 20,
    availableSlots: 8,
    isFull: false,
    isLimitedSpots: true,
    sessions: '12',
    duration: '2 months',
    ageGroup: '10-15 years',
    status: 'Active'
  },
  {
    id: -2,
    name: 'Evening Stars',
    type: 'Beginner',
    price: '₹2,000',
    timing: '04:00 PM - 06:00 PM',
    days: 'Tue, Thu, Sat',
    currentStudents: 15,
    maxStudents: 15,
    availableSlots: 0,
    isFull: true,
    isLimitedSpots: false,
    sessions: '12',
    duration: '2 months',
    ageGroup: '8-12 years',
    status: 'Active'
  },
  {
    id: -3,
    name: 'Weekend Intensive',
    type: 'Advanced',
    price: '₹3,000',
    timing: '09:00 AM - 12:00 PM',
    days: 'Sat, Sun',
    currentStudents: 8,
    maxStudents: 12,
    availableSlots: 4,
    isFull: false,
    isLimitedSpots: true,
    sessions: '8',
    duration: '1 month',
    ageGroup: '15+ years',
    status: 'Active'
  }
];

// A batch is enrollable only if it is a real backend batch (positive id).
// Sample/placeholder batches use non-positive ids and cannot be enrolled.
function isEnrollableBatch(batchId: Batch['id']): boolean {
  return typeof batchId === 'number' && Number.isFinite(batchId) && batchId > 0;
}

// Error State Component
const ErrorState = ({ message, onRetry }: { message: string; onRetry: () => void }) => (
 <div className="flex flex-col items-center justify-center p-12 bg-red-50 rounded-3xl">
 <AlertCircle className="w-16 h-16 text-red-500 mb-4"/>
 <p className="text-slate-700 mb-4 text-center">{message}</p>
 <Button onClick={onRetry} variant="primary">
 Retry
 </Button>
 </div>
);

// Empty State Component
const EmptyState = ({ message, suggestion }: { message: string; suggestion?: string }) => (
 <div className="flex flex-col items-center justify-center p-12 bg-slate-50 rounded-3xl">
 <div className="w-16 h-16 rounded-full bg-slate-200 flex items-center justify-center mb-4">
 <Trophy className="w-8 h-8 text-slate-400"/>
 </div>
 <p className="text-slate-700 mb-2 text-center">{message}</p>
 {suggestion && <p className="text-slate-500 text-sm text-center">{suggestion}</p>}
 </div>
);

// Loading Skeleton Components
const SportCardSkeleton = () => (
 <div className="aspect-[4/5] rounded-[2rem] bg-slate-200 animate-pulse"/>
);

const CoachSidebarSkeleton = () => (
 <div className="bg-slate-900 rounded-[3rem] p-10 shadow-2xl">
 <div className="flex flex-col items-center text-center">
 <div className="w-32 h-32 rounded-[2.5rem] bg-slate-700 animate-pulse mb-8"/>
 <div className="h-4 w-32 bg-slate-700 rounded animate-pulse mb-2"/>
 <div className="h-6 w-48 bg-slate-700 rounded animate-pulse mb-4"/>
 <div className="h-20 w-full bg-slate-700 rounded animate-pulse mb-8"/>
 <div className="w-full space-y-4">
 <div className="h-20 bg-slate-700 rounded-2xl animate-pulse"/>
 <div className="h-20 bg-slate-700 rounded-2xl animate-pulse"/>
 </div>
 </div>
 </div>
);

const BatchCardSkeleton = () => (
 <div className="bg-white rounded-[2.5rem] p-8 border-2 border-white shadow-premium">
 <div className="h-6 w-24 bg-slate-200 rounded-full animate-pulse mb-6"/>
 <div className="h-8 w-full bg-slate-200 rounded animate-pulse mb-8"/>
 <div className="grid grid-cols-2 gap-4 mb-8">
 <div className="h-12 bg-slate-200 rounded-xl animate-pulse"/>
 <div className="h-12 bg-slate-200 rounded-xl animate-pulse"/>
 </div>
 <div className="h-10 bg-slate-200 rounded-xl animate-pulse"/>
 </div>
);

export const CoachingPage = () => {
 const dispatch = useAppDispatch();
 const navigate = useNavigate();
 const { user, isAuthenticated } = useAuth();
 const [searchParams, setSearchParams] = useSearchParams();
 const { 
 sports, 
 coaches, 
 batches, 
 sportComplexes,
 loadingSports, 
 loadingCoaches, 
 loadingBatches,
 loadingSportComplexes,
 sportsError, 
 coachesError, 
 batchesError,
 sportComplexesError
 } = useAppSelector((state) => state.coaching);

 const [selectedGroundId, setSelectedGroundId] = useState<number | null>(null);
 const [selectedSportId, setSelectedSportId] = useState<number | null>(null);
 // Set of ground names (lowercased) that have at least one coach (a batch's ground
 // derives from its coach), used to hide grounds with no coaches/batches.
 const [groundsWithContent, setGroundsWithContent] = useState<Set<string> | null>(null);
 const [selectedBatch, setSelectedBatch] = useState<Batch | null>(null);
 const [selectedCoachId, setSelectedCoachId] = useState<number | null>(null);
 const [isEnquiryModalOpen, setIsEnquiryModalOpen] = useState(false);
 const [isLoginPromptOpen, setIsLoginPromptOpen] = useState(false);
 const [isCoachModalOpen, setIsCoachModalOpen] = useState(false);
 const [pendingBatch, setPendingBatch] = useState<Batch | null>(null);
 const [submittedRef, setSubmittedRef] = useState<string | null>(null);
 const [enquiryFormData, setEnquiryFormData] = useState({
 name: '',
 email: '',
 phone: '',
 message: ''
 });
 const [isSubmittingEnquiry, setIsSubmittingEnquiry] = useState(false);

 // Auto-fill form when user is logged in
 useEffect(() => {
 if (user) {
 setEnquiryFormData(prev => ({
 ...prev,
 name: user.name || prev.name,
 email: user.email || prev.email,
 phone: user.phone_number || prev.phone,
 }));
 }
 }, [user]);

 // Convert sport complexes to grounds format. Once we know which grounds have
 // coaches/batches, hide the grounds that have none.
 const grounds: Ground[] = useMemo(() => {
 const converted = sportComplexes.map(complex => ({
 id: complex.id.toString(),
 name: complex.name,
 image: complex.image || ''
 }));
 // Until we know which grounds actually have coaches, show nothing rather than
 // every ground — otherwise an empty ground (whichever the API returns first)
 // gets auto-selected as the default before the filter resolves.
 if (!groundsWithContent) return [];
 return converted.filter(g => groundsWithContent.has(g.name.trim().toLowerCase()));
 }, [sportComplexes, groundsWithContent]);

 // Fetch initial data
 useEffect(() => {
 console.log('🚀 [Coaching] Component mounted, fetching sport complexes...');
 dispatch(fetchSportComplexes());
 }, [dispatch]);

 // Determine which grounds actually have coaches (so empty grounds are hidden).
 useEffect(() => {
 let active = true;
 coachingApi.getCoaches({ status: 'Active' })
 .then(list => {
 if (!active) return;
 const set = new Set(
 (list || [])
 .map(c => (c.ground || '').trim().toLowerCase())
 .filter(Boolean)
 );
 setGroundsWithContent(set);
 })
 .catch(() => { if (active) setGroundsWithContent(new Set()); });
 return () => { active = false; };
 }, []);

 // If the currently selected ground gets filtered out (no content), switch to the
 // first available ground.
 useEffect(() => {
 if (selectedGroundId === null || grounds.length === 0) return;
 const stillVisible = grounds.some(g => parseInt(g.id) === selectedGroundId);
 if (!stillVisible) {
 handleGroundChange(parseInt(grounds[0].id));
 }
 // eslint-disable-next-line react-hooks/exhaustive-deps
 }, [grounds]);

 // Set default ground when grounds are loaded
 useEffect(() => {
 console.log('🎯 [Coaching] Grounds changed:', { groundsLength: grounds.length, selectedGroundId });
 if (grounds.length > 0 && selectedGroundId === null) {
 // Restore from URL params if present
 const urlGround = searchParams.get('ground');
 const urlSport = searchParams.get('sport');
 const firstGroundId = urlGround ? parseInt(urlGround) : parseInt(grounds[0].id);
 const matchedGround = grounds.find(g => g.id === firstGroundId.toString()) || grounds[0];
 console.log('✅ [Coaching] Setting default ground:', matchedGround.id, matchedGround.name);
 setSelectedGroundId(parseInt(matchedGround.id));
 dispatch(fetchSports(matchedGround.name));
 if (urlSport) setSelectedSportId(parseInt(urlSport));
 }
 }, [grounds, selectedGroundId, dispatch]);

 // Handler for ground change
 const handleGroundChange = (groundId: number) => {
 console.log(`🏟️ Ground changed to ID: ${groundId}`);
 setSelectedGroundId(groundId);
 setSelectedSportId(null); // Reset sport selection
 setSelectedBatch(null); // Reset batch selection
 setSelectedCoachId(null);
 
 // Fetch sports for this ground
 const selectedGround = grounds.find(g => g.id === groundId.toString());
 if (selectedGround) {
 console.log(`🔍 Fetching sports for ground: ${selectedGround.name}`);
 dispatch(fetchSports(selectedGround.name));
 }
 // Sync URL
 setSearchParams({ ground: groundId.toString() });
 };

 // Set default sport when sports are loaded (only if no sport is selected)
 useEffect(() => {
 if (sports.length > 0 && selectedSportId === null && selectedGroundId !== null) {
 setSelectedSportId(sports[0].id);
 }
 }, [sports, selectedSportId, selectedGroundId]);

  // Fetch coaches and batches when sport changes.
  // setSelectedCoachId(null) runs here (not in the click handler) so that
  // re-clicking the SAME sport card doesn't blank the coach panel — this
  // effect only fires when selectedSportId actually changes.
  useEffect(() => {
  if (selectedSportId) {
  setSelectedCoachId(null);
  setSelectedBatch(null);
  const selectedGround = selectedGroundId ? grounds.find(g => g.id === selectedGroundId.toString()) : null;
  dispatch(fetchCoaches({
  sportId: selectedSportId
  }));
  // Batches are scoped to the selected ground (via the batch's coach ground)
  dispatch(fetchBatchesAndPrograms({ sportId: selectedSportId, ground: selectedGround?.name }));
  }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedSportId, dispatch]);

 // Refetch coaches when GROUND changes (only — sport changes are handled by the
 // effect above). Removing selectedSportId from deps prevents a second
 // fetchCoaches dispatch on every sport click which would clear coaches and
 // potentially return empty ("No Coach Assigned") for the ground filter.
 useEffect(() => {
 if (selectedSportId && selectedGroundId) {
 setSelectedCoachId(null);
 const selectedGround = grounds.find(g => g.id === selectedGroundId.toString());
 if (selectedGround) {
 dispatch(fetchCoaches({ 
 sportId: selectedSportId, 
 ground: selectedGround?.name 
 }));
 }
 }
 // eslint-disable-next-line react-hooks/exhaustive-deps
 }, [selectedGroundId, dispatch, grounds]);

 // Filter coaches by ground (coaches are already filtered by sport from API)
 const filteredCoaches = useMemo(() => {
 if (!selectedGroundId || coaches.length === 0) return coaches;
 const selectedGround = grounds.find(g => g.id === selectedGroundId.toString());
 if (!selectedGround) return coaches;
 
 // Filter coaches that match the selected ground
 const filtered = coaches.filter(coach => {
 // If coach has no ground assigned, include them (they're available everywhere)
 if (!coach.ground) return true;
 // Match by ground name (case-insensitive)
 return coach.ground.toLowerCase() === selectedGround.name.toLowerCase();
 });
 
 // If no coaches match the ground filter, return all coaches for the sport
 // This prevents the "No Coach Assigned" error when ground filtering is too strict
 return filtered.length > 0 ? filtered : coaches;
 }, [coaches, selectedGroundId, grounds]);

 const filteredBatches = useMemo(() => {
 // Batches are ground-scoped on the backend (by the batch's coach ground).
 // Hide everything when no sport is selected (e.g. a ground with no sports)
 // so stale batches from a previous ground don't linger.
 if (!selectedSportId) return [];
 return batches;
 }, [batches, selectedSportId]);

 // Auto-select the first batch when batches load (or the current selection is no
 // longer in the list, e.g. after a sport change) so the Expert Coach card shows
 // that batch's assigned coach by default instead of falling back to the first coach.
 useEffect(() => {
 if (filteredBatches.length === 0) {
 // No batches for this ground/sport — clear any stale selection so the
 // coach card doesn't keep showing a previous ground's coach.
 if (selectedBatch) {
 setSelectedBatch(null);
 setSelectedCoachId(null);
 }
 return;
 }
 const stillValid = selectedBatch && filteredBatches.some(b => b.id === selectedBatch.id);
 if (!stillValid) {
 const first = filteredBatches[0];
 setSelectedBatch(first);
 setSelectedCoachId(first.coach?.id ?? null);
 }
 }, [filteredBatches, selectedBatch]);

 // The Expert Coach card is driven entirely by the selected batch's coach.
 // No selected batch -> no coach (instead of falling back to some other coach).
 const currentCoach = useMemo(() => {
 if (!selectedBatch?.coach) return null;
 // Prefer the full coach record (for bio/certification/awards/image)
 const matched = coaches.find(
 c => c.id === selectedBatch.coach!.id ||
 c.name.toLowerCase() === selectedBatch.coach!.name.toLowerCase()
 );
 if (matched) return matched;
 // Coach isn't in the active coaches list — show the batch's coach with minimal info
 return {
 id: selectedBatch.coach.id,
 name: selectedBatch.coach.name,
 sportId: selectedSportId ?? 0,
 status: 'Active',
 image: '',
 } as Coach;
 }, [coaches, selectedBatch, selectedSportId]);

 // Retry handlers
 const handleRetrySports = () => {
 dispatch(clearError());
 // Retry with current ground if selected
 if (selectedGroundId) {
 const selectedGround = grounds.find(g => g.id === selectedGroundId.toString());
 if (selectedGround) {
 dispatch(fetchSports(selectedGround.name));
 } else {
 dispatch(fetchSports(undefined));
 }
 } else {
 dispatch(fetchSports(undefined));
 }
 };

 const handleRetryCoaches = () => {
 dispatch(clearError());
 if (selectedSportId && selectedGroundId) {
 const selectedGround = grounds.find(g => g.id === selectedGroundId.toString());
 dispatch(fetchCoaches({ 
 sportId: selectedSportId, 
 ground: selectedGround?.name 
 }));
 }
 };

 const handleRetryBatches = () => {
 dispatch(clearError());
 if (selectedSportId) {
 const selectedGround = selectedGroundId ? grounds.find(g => g.id === selectedGroundId.toString()) : null;
 dispatch(fetchBatchesAndPrograms({ sportId: selectedSportId, ground: selectedGround?.name }));
 }
 };

 const handleRetryGrounds = () => {
 dispatch(clearError());
 dispatch(fetchSportComplexes());
 };

 // Enquiry modal handlers
 const handleEnrollClick = (batch: Batch) => {
 // Check if user is logged in
 if (!isAuthenticated) {
 // Save the batch they wanted and show login prompt
 setPendingBatch(batch);
 setIsLoginPromptOpen(true);
 return;
 }

 // Set selected batch and open modal
 setSelectedBatch(batch);
 setIsEnquiryModalOpen(true);
 };

 const handleEnquirySubmit = async (e: React.FormEvent) => {
 e.preventDefault();
 
 if (!selectedBatch || !selectedSportId) return;

 setIsSubmittingEnquiry(true);

 try {
 // Coaching.tsx appends /api/... paths itself
 const _rawCoachBase = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');
 const API_URL = _rawCoachBase.endsWith('/api') ? _rawCoachBase.slice(0, -4) : _rawCoachBase;
 
 if (!isEnrollableBatch(selectedBatch.id)) {
   toast.error('Please select a valid batch before submitting enquiry.');
   setIsSubmittingEnquiry(false);
   return;
 }
 const batchId = selectedBatch.id;

 // Attach Bearer token from localStorage (cross-origin auth)
 const accessToken = localStorage.getItem('accessToken');
 const response = await axios.post(
 `${API_URL}/api/coaching-enquiries`,
 {
 batchId,
 sportId: selectedSportId,
 coachId: currentCoach?.id || undefined,
 name: enquiryFormData.name,
 email: enquiryFormData.email,
 phone: enquiryFormData.phone,
 message: enquiryFormData.message
 },
 {
 withCredentials: true,
 headers: accessToken ? { Authorization: `Bearer ${accessToken}` } : {},
 }
 );

 const refNumber = response.data?.data?.referenceNumber;
 setSubmittedRef(refNumber || null);
 setIsEnquiryModalOpen(false);
 // Reset only message, keep name/email/phone for next enquiry
 setEnquiryFormData(prev => ({ ...prev, message: '' }));
 setSelectedBatch(null);
 } catch (error: any) {
 console.error('❌ Error submitting enquiry:', error);
 const errorMessage = error.response?.data?.message || 'Failed to submit enquiry. Please try again.';
 toast.error(errorMessage);
 } finally {
 setIsSubmittingEnquiry(false);
 }
 };

 return (
 <div className="pt-32 pb-24 bg-[#f8fafc] min-h-screen">
 <div className="container-custom max-w-7xl">
 {/* Modern Header */}
  <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 mb-6 md:mb-16">
  <div>
  <h1 className="text-4xl md:text-6xl text-slate-900 uppercase tracking-tight leading-[0.9] mb-2">
  Sports <span className="text-brand-primary">Coaching</span>
  </h1>
  <p className="text-slate-500 text-base md:text-lg italic">
  Professional training at Nahata Sports Complex
  </p>
  </div>
  <div className="flex gap-3 overflow-x-auto pb-2 -mx-4 px-4 scrollbar-hide md:overflow-visible md:pb-0 md:mx-0 md:px-0">
  {loadingSportComplexes || groundsWithContent === null ? (
  <div className="flex items-center gap-2 text-slate-400 shrink-0">
  <Loader2 className="w-4 h-4 animate-spin"/>
  <span className="text-xs">Loading grounds...</span>
  </div>
  ) : sportComplexesError ? (
  <Button onClick={handleRetryGrounds} variant="outline"className="text-xs shrink-0">
  Retry Loading Grounds
  </Button>
  ) : grounds.length === 0 ? (
  <div className="text-slate-400 text-xs shrink-0">No grounds available</div>
  ) : (
  grounds.map(g => (
  <button
  key={g.id}
  onClick={() => handleGroundChange(parseInt(g.id))}
  className={`px-6 py-3 rounded-2xl text-[10px] uppercase tracking-widest transition-all border-2 shrink-0 ${
  selectedGroundId === parseInt(g.id)
  ? 'bg-slate-900 text-white border-slate-900 shadow-xl' 
  : 'bg-white text-slate-400 border-slate-100 hover:border-slate-200'
  }`}
  >
  {g.name}
  </button>
  ))
  )}
  </div>
  </div>

 {/* Sport Hub - Big Visual Cards */}
 <div className="mb-8 md:mb-16">
 <div className="flex items-center gap-3 mb-4 md:mb-8">
 <div className="w-1.5 h-6 bg-brand-primary rounded-full"/>
 <h2 className="text-xl text-slate-800 uppercase tracking-tight">Choose Your Sport</h2>
 </div>
 
 {loadingSports ? (
  /* Mobile: horizontal scroll row so skeletons are always visible */
  <div className="flex overflow-x-auto gap-4 pb-2 -mx-4 px-4 scrollbar-hide md:grid md:grid-cols-4 lg:grid-cols-8 md:overflow-visible md:pb-0 md:mx-0 md:px-0">
  {[...Array(8)].map((_, i) => (
  <div key={i} className="shrink-0 w-[100px] md:w-auto">
  <SportCardSkeleton />
  </div>
  ))}
  </div>
  ) : sportsError ? (
  <ErrorState message={sportsError} onRetry={handleRetrySports} />
  ) : (
  /* Mobile: horizontal scroll so the first sport card is always in view.
     md+: reverts to the original grid layout — no visual change on desktop. */
  <div className="flex overflow-x-auto gap-4 pb-2 -mx-4 px-4 scrollbar-hide snap-x snap-mandatory md:grid md:grid-cols-4 lg:grid-cols-8 md:overflow-visible md:pb-0 md:mx-0 md:px-0">
  {sports.map(s => {
  const Icon = getIconComponent(s.iconName);
         return (
          <button
            key={s.id}
            onClick={() => {
              setSelectedSportId(s.id);
              setSelectedBatch(null);
              // Do NOT clear selectedCoachId here — the useEffect above
              // handles that only when the sport ID truly changes.
              setSearchParams(prev => {
                const next = new URLSearchParams(prev);
                next.set('sport', s.id.toString());
                return next;
              });
            }}
            className={`group relative shrink-0 snap-start
              w-[100px] h-[125px]
              md:w-auto md:h-auto md:aspect-[4/5]
              rounded-[2rem] overflow-hidden transition-all duration-500 border-4 ${
              selectedSportId === s.id
                ? 'border-brand-primary shadow-2xl scale-105 z-10'
                : 'border-white shadow-sm hover:border-slate-200 hover:translate-y-[-4px]'
            }`}
          >
            <SmartImage
              src={s.image}
              className={`w-full h-full object-cover transition-transform duration-700 ${
                selectedSportId === s.id ? 'scale-110' : 'group-hover:scale-110 grayscale-[0.5] group-hover:grayscale-0'
              }`}
              alt={s.name}
            />
            <div className={`absolute inset-0 transition-opacity duration-500 ${
              selectedSportId === s.id ? 'bg-brand-primary/20' : 'bg-black/40 group-hover:bg-black/20'
            }`} />
            <div className="absolute inset-x-0 bottom-0 p-4 text-center">
              <div className={`inline-flex p-2 rounded-xl mb-2 transition-colors ${
                selectedSportId === s.id ? 'bg-white text-brand-primary' : 'bg-white/20 text-white backdrop-blur-md'
              }`}>
                <Icon size={16} />
              </div>
              <p className="text-[10px] text-white uppercase tracking-[0.2em]">{s.name}</p>
            </div>
          </button>
        );
      })}
  </div>
  )}
 </div>

 {/* Content Grid */}
 <div className="grid lg:grid-cols-12 gap-12">
 {/* Result Cards - Left/Center */}
 <div className="lg:col-span-8 space-y-8">
 <div className="flex items-center gap-3">
 <div className="w-1.5 h-6 bg-brand-primary rounded-full"/>
 <h2 className="text-xl text-slate-800 uppercase tracking-tight">Available Programs</h2>
 </div>
 
 {loadingBatches ? (
 <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
 {[...Array(4)].map((_, i) => (
 <BatchCardSkeleton key={i} />
 ))}
 </div>
 ) : batchesError ? (
 <ErrorState message={batchesError} onRetry={handleRetryBatches} />
 ) : filteredBatches.length === 0 ? (
  <EmptyState
    message="No batches are currently available for this sport."
    suggestion="Please try another sport or check back later."
  />
 ) : (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
      {filteredBatches.map((batch, idx) => (
 <motion.div
 key={batch.id}
 initial={{ opacity: 0, y: 20 }}
 animate={{ opacity: 1, y: 0 }}
 transition={{ delay: idx * 0.1 }}
 className={`bg-white rounded-[2.5rem] p-8 border-2 transition-all cursor-pointer relative overflow-hidden group ${
 selectedBatch?.id === batch.id 
 ? 'border-brand-primary shadow-2xl shadow-brand-primary/10' 
 : 'border-white shadow-premium hover:border-slate-100 hover:shadow-2xl'
 }`}
 onClick={() => {
 setSelectedBatch(batch);
 // Sync the Expert Coach card to the batch's assigned coach
 setSelectedCoachId(batch.coach?.id ?? null);
 }}
 >
 {/* Decorative element */}
 <div className={`absolute top-0 right-0 w-24 h-24 -mr-8 -mt-8 rounded-full transition-colors ${
 selectedBatch?.id === batch.id ? 'bg-brand-primary/5' : 'bg-slate-50'
 }`} />

 <div className="relative z-10">
 <div className="flex justify-between items-start mb-6">
 <div className="flex gap-2 flex-wrap">
 <span className={`px-4 py-1.5 rounded-full text-[10px] uppercase tracking-widest ${
 selectedBatch?.id === batch.id ? 'bg-brand-primary text-white' : 'bg-slate-100 text-slate-400'
 }`}>
 {batch.type}
 </span>
 {batch.isFull && (
 <span className="px-4 py-1.5 rounded-full text-[10px] uppercase tracking-widest bg-red-100 text-red-600">
 Full
 </span>
 )}
 {batch.isLimitedSpots && !batch.isFull && (
 <span className="px-4 py-1.5 rounded-full text-[10px] uppercase tracking-widest bg-yellow-100 text-yellow-600">
 Limited Spots
 </span>
 )}
 </div>
 <div className="text-right">
 <p className="text-2xl text-slate-900 leading-none">{batch.price}</p>
 <p className="text-[9px] text-slate-400 uppercase mt-1">Monthly</p>
 </div>
 </div>

 <h3 className="text-xl text-slate-900 uppercase tracking-tight mb-4 group-hover:text-brand-primary transition-colors">
 {batch.name}
 </h3>

 {/* Batch details */}
 <div className="flex items-center gap-3 mb-6">
 <div className="w-8 h-8 rounded-xl bg-slate-50 flex items-center justify-center text-slate-400 shrink-0">
 <User size={14} />
 </div>
 <div className="min-w-0">
 <p className="text-[9px] text-slate-400 uppercase">Coach</p>
 <p className="text-[11px] text-slate-700 truncate">{batch.coach?.name || 'Not assigned'}</p>
 </div>
 </div>

 <div className="grid grid-cols-2 gap-4 mb-8">
 <div className="flex items-center gap-3">
 <div className="w-8 h-8 rounded-xl bg-slate-50 flex items-center justify-center text-slate-400 shrink-0">
 <Clock size={14} />
 </div>
 <div className="min-w-0">
 <p className="text-[9px] text-slate-400 uppercase">Timing</p>
 <p className="text-[11px] text-slate-700 truncate">{batch.timing}</p>
 </div>
 </div>
 <div className="flex items-center gap-3">
 <div className="w-8 h-8 rounded-xl bg-slate-50 flex items-center justify-center text-slate-400 shrink-0">
 <Calendar size={14} />
 </div>
 <div className="min-w-0">
 <p className="text-[9px] text-slate-400 uppercase">Days</p>
 <p className="text-[11px] text-slate-700 truncate">{batch.days}</p>
 </div>
 </div>
 {batch.duration && (
 <div className="flex items-center gap-3">
 <div className="w-8 h-8 rounded-xl bg-slate-50 flex items-center justify-center text-slate-400 shrink-0">
 <CalendarRange size={14} />
 </div>
 <div className="min-w-0">
 <p className="text-[9px] text-slate-400 uppercase">Duration</p>
 <p className="text-[11px] text-slate-700 truncate">{batch.duration}</p>
 </div>
 </div>
 )}
 {batch.ageGroup && (
 <div className="flex items-center gap-3">
 <div className="w-8 h-8 rounded-xl bg-slate-50 flex items-center justify-center text-slate-400 shrink-0">
 <Users size={14} />
 </div>
 <div className="min-w-0">
 <p className="text-[9px] text-slate-400 uppercase">Age Group</p>
 <p className="text-[11px] text-slate-700 truncate">{batch.ageGroup}</p>
 </div>
 </div>
 )}
 </div>

 <div className="flex items-center justify-between pt-6 border-t border-slate-50">
 <span className={`px-3 py-1 rounded-full text-[10px] uppercase tracking-widest ${
 batch.status === 'Active' ? 'bg-green-50 text-green-600' : 'bg-slate-100 text-slate-400'
 }`}>
 {batch.status}
 </span>
 <Button
 variant={selectedBatch?.id === batch.id ? 'primary' : 'outline'}
 className="rounded-xl px-8"
 disabled={batch.isFull}
 onClick={(e) => {
 e.stopPropagation();
 handleEnrollClick(batch);
 }}
 >
 {batch.isFull ? 'Batch Full' : 'Enroll'}
 </Button>
 </div>
 </div>
 </motion.div>
 ))}
 </div>
 )}
 </div>

 {/* Coach & Info Sidebar */}
 <div className="lg:col-span-4 lg:sticky lg:top-28 h-fit space-y-8">
 {/* Coach is shown based on the selected batch (see currentCoach) */}
 {loadingCoaches ? (
 <CoachSidebarSkeleton />
 ) : coachesError ? (
 <ErrorState message={coachesError} onRetry={handleRetryCoaches} />
 ) : !currentCoach ? (
 <div className="bg-slate-900 rounded-[3rem] p-10 text-white shadow-2xl relative overflow-hidden">
 {/* Pattern overlay */}
 <div className="absolute inset-0 opacity-10 pointer-events-none bg-[radial-gradient(circle_at_top_right,_var(--tw-gradient-stops))] from-white via-transparent to-transparent"/>
 
 <div className="relative z-10 flex flex-col items-center text-center">
 <div className="w-32 h-32 rounded-[2.5rem] bg-white/10 flex items-center justify-center mb-8">
 <AlertCircle size={48} className="text-white/40"/>
 </div>

 <span className="text-[10px] text-brand-primary uppercase tracking-[0.3em] mb-2">Coach Information</span>
 <h3 className="text-2xl uppercase tracking-tight mb-4">No Coach Assigned</h3>
 <p className="text-slate-400 text-sm leading-relaxed mb-8">
 There is currently no coach assigned to this sport. Please check back later or contact us for more information.
 </p>

 <div className="w-full bg-white/5 border border-white/10 rounded-2xl p-6 text-center">
 <p className="text-xs text-slate-400">
 Coaches will be assigned soon. Stay tuned for updates!
 </p>
 </div>
 </div>
 </div>
 ) : (
 <div className="bg-slate-900 rounded-[3rem] p-10 text-white shadow-2xl relative overflow-hidden group">
 {/* Pattern overlay */}
 <div className="absolute inset-0 opacity-10 pointer-events-none bg-[radial-gradient(circle_at_top_right,_var(--tw-gradient-stops))] from-white via-transparent to-transparent"/>
 
 <div className="relative z-10 flex flex-col items-center text-center">
 <div className="relative mb-8">
 <div className="w-32 h-32 rounded-[2.5rem] overflow-hidden border-4 border-white/20 rotate-6 group-hover:rotate-0 transition-transform duration-500 shadow-2xl">
 <SmartImage src={currentCoach.image} className="w-full h-full object-cover" alt="coach" />
 </div>
 <div className="absolute -bottom-2 -right-2 bg-brand-primary text-white p-2 rounded-xl shadow-xl">
 <ShieldCheck size={20} />
 </div>
 </div>

<span className="text-[10px] text-[#8FA8FF] uppercase tracking-[0.3em] mb-2 font-medium">Expert Coach</span>
 <h3 className="text-3xl uppercase tracking-tight mb-4">{currentCoach.name}</h3>
 {/* Experience (short info shown directly; Availability moved to the popup) */}
 {currentCoach.experience && (
 <div className="w-full mb-6 mt-2">
 <div className="bg-white/5 border border-white/10 rounded-2xl p-4 text-left">
 <h4 className="text-[9px] text-[#8FA8FF] uppercase tracking-widest mb-1 flex items-center gap-2 font-medium">
 <Award size={13} /> Experience
 </h4>
 <p className="text-xs text-slate-200">{currentCoach.experience}</p>
 </div>
 </div>
 )}

 {/* Detailed info (Availability, Specialization, Certification, Bio) opens in a popup */}
 {(currentCoach.availability || currentCoach.specialization || currentCoach.certification || currentCoach.bio) && (
 <button
 type="button"
 onClick={() => setIsCoachModalOpen(true)}
 className="w-full mb-8 py-3 text-[11px] uppercase tracking-widest rounded-2xl border border-white/15 bg-white/5 text-slate-200 hover:bg-white/10 transition-colors"
 >
 View Full Profile
 </button>
 )}

 <Button 
 className="w-full py-4 text-xs uppercase tracking-widest bg-brand-primary hover:bg-white hover:text-slate-900 border-none transition-all"
 onClick={() => {
 if (selectedBatch) {
 handleEnrollClick(selectedBatch);
 } else if (filteredBatches.length > 0) {
 handleEnrollClick(filteredBatches[0]);
 }
 }}
 >
 Confirm Enrollment
 <ArrowRight size={18} className="ml-2"/>
 </Button>
 </div>
 </div>
 )}

 {/* Quick Benefits */}
 <div className="bg-white rounded-[2.5rem] p-8 border border-slate-100 shadow-sm">
 <h4 className="text-[10px] text-slate-400 uppercase tracking-widest mb-6">Course Highlights</h4>
 <div className="space-y-4">
 {[
 'Professional Training',
 'Bi-weekly Match Practice',
 'Personal Performance Review',
 'Holistic Fitness Programs'
 ].map((item, i) => (
 <div key={i} className="flex items-center gap-3 text-xs text-slate-600">
 <CheckCircle2 size={16} className="text-emerald-500"/>
 {item}
 </div>
 ))}
 </div>
 </div>
 </div>
 </div>
 </div>

 {/* Enquiry Modal */}
 <AnimatePresence>
 {isEnquiryModalOpen && selectedBatch && (
 <>
 <motion.div 
 initial={{ opacity: 0 }}
 animate={{ opacity: 1 }}
 exit={{ opacity: 0 }}
 onClick={() => setIsEnquiryModalOpen(false)}
 className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-[100]"
 />
 <motion.div 
 initial={{ scale: 0.9, opacity: 0 }}
 animate={{ scale: 1, opacity: 1 }}
 exit={{ scale: 0.9, opacity: 0 }}
 className="fixed inset-0 flex items-center justify-center z-[101] p-4"
 >
 <div className="bg-white rounded-[2.5rem] shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
 <div className="p-8 border-b border-slate-100 flex items-center justify-between">
 <div>
 <h2 className="text-2xl text-slate-900 tracking-tight uppercase">Enrollment Enquiry</h2>
 <p className="text-xs text-slate-400 uppercase tracking-widest mt-1">
 {selectedBatch.name}
 </p>
 </div>
 <button 
 onClick={() => setIsEnquiryModalOpen(false)}
 className="p-2 hover:bg-slate-100 rounded-xl text-slate-400 transition-colors"
 >
 <X size={22} />
 </button>
 </div>

 <form onSubmit={handleEnquirySubmit} className="p-8">
{!isEnrollableBatch(selectedBatch.id) && (
  <div className="mb-6 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-xs text-amber-700">
    This appears to be a sample batch card. Please choose a live batch to submit enquiry.
  </div>
)}
 <div className="space-y-6">
 <div>
 <label className="text-xs text-slate-400 uppercase tracking-widest block mb-2">
 Full Name *
 </label>
 <input
 type="text"
 required
 value={enquiryFormData.name}
 onChange={(e) => setEnquiryFormData({ ...enquiryFormData, name: e.target.value })}
 className="w-full px-4 py-3 border-2 border-slate-100 rounded-xl text-sm focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
 placeholder="Enter your full name"
 />
 </div>

 <div>
 <label className="text-xs text-slate-400 uppercase tracking-widest block mb-2">
 Email Address *
 </label>
 <input
 type="email"
 required
 value={enquiryFormData.email}
 onChange={(e) => setEnquiryFormData({ ...enquiryFormData, email: e.target.value })}
 className="w-full px-4 py-3 border-2 border-slate-100 rounded-xl text-sm focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
 placeholder="your.email@example.com"
 />
 </div>

 <PhoneInput
 value={enquiryFormData.phone}
 onChange={(value) => setEnquiryFormData({ ...enquiryFormData, phone: value })}
 label="Phone Number *"
 placeholder="Enter 10-digit mobile number"
 required
 />

 <div>
 <label className="text-xs text-slate-400 uppercase tracking-widest block mb-2">
 Message (Optional)
 </label>
 <textarea
 value={enquiryFormData.message}
 onChange={(e) => setEnquiryFormData({ ...enquiryFormData, message: e.target.value })}
 rows={4}
 className="w-full px-4 py-3 border-2 border-slate-100 rounded-xl text-sm focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all resize-none"
 placeholder="Any specific questions or requirements..."
 />
 </div>

 <div className="bg-slate-50 rounded-xl p-4">
 <h4 className="text-xs text-slate-700 uppercase tracking-widest mb-3">Program Details</h4>
 <div className="grid grid-cols-2 gap-4 text-xs">
 <div>
 <span className="text-slate-400">Batch:</span>
 <span className="ml-2 text-slate-900">{selectedBatch.name}</span>
 </div>
 <div>
 <span className="text-slate-400">Coach:</span>
 <span className="ml-2 text-slate-900">{selectedBatch.coach?.name || 'Not assigned'}</span>
 </div>
 <div>
 <span className="text-slate-400">Price:</span>
 <span className="ml-2 text-slate-900">{selectedBatch.price}</span>
 </div>
 <div>
 <span className="text-slate-400">Timing:</span>
 <span className="ml-2 text-slate-900">{selectedBatch.timing}</span>
 </div>
 <div>
 <span className="text-slate-400">Days:</span>
 <span className="ml-2 text-slate-900">{selectedBatch.days}</span>
 </div>
 {selectedBatch.duration && (
 <div>
 <span className="text-slate-400">Duration:</span>
 <span className="ml-2 text-slate-900">{selectedBatch.duration}</span>
 </div>
 )}
 {selectedBatch.ageGroup && (
 <div>
 <span className="text-slate-400">Age Group:</span>
 <span className="ml-2 text-slate-900">{selectedBatch.ageGroup}</span>
 </div>
 )}
 <div>
 <span className="text-slate-400">Available Spots:</span>
 <span className="ml-2 text-slate-900">{selectedBatch.availableSlots}</span>
 </div>
 <div>
 <span className="text-slate-400">Status:</span>
 <span className="ml-2 text-slate-900">{selectedBatch.status}</span>
 </div>
 </div>
 </div>
 </div>

 <div className="flex gap-4 mt-8">
 <button
 type="button"
 onClick={() => setIsEnquiryModalOpen(false)}
 className="flex-1 px-6 py-3 border-2 border-slate-200 text-slate-600 rounded-xl text-sm uppercase tracking-widest hover:bg-slate-50 transition-all"
 >
 Cancel
 </button>
 <button
 type="submit"
disabled={isSubmittingEnquiry || !isEnrollableBatch(selectedBatch.id)}
 className="flex-1 px-6 py-3 bg-brand-primary text-white rounded-xl text-sm uppercase tracking-widest hover:bg-brand-primary/90 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
 >
 {isSubmittingEnquiry ? (
 <>
 <Loader2 size={16} className="animate-spin"/>
 Submitting...
 </>
 ) : (
 'Submit Enquiry'
 )}
 </button>
 </div>
 </form>
 </div>
 </motion.div>
 </>
 )}
 </AnimatePresence>

 {/* Login Prompt Modal — shown when unauthenticated user clicks Enroll */}
 <AnimatePresence>
 {isLoginPromptOpen && (
 <>
 <motion.div
 initial={{ opacity: 0 }}
 animate={{ opacity: 1 }}
 exit={{ opacity: 0 }}
 onClick={() => setIsLoginPromptOpen(false)}
 className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-[100]"
 />
 <motion.div
 initial={{ scale: 0.9, opacity: 0, y: 20 }}
 animate={{ scale: 1, opacity: 1, y: 0 }}
 exit={{ scale: 0.9, opacity: 0, y: 20 }}
 className="fixed inset-0 flex items-center justify-center z-[101] p-4"
 >
 <div className="bg-white rounded-[2.5rem] shadow-2xl max-w-md w-full p-10 text-center">
 <div className="w-16 h-16 bg-brand-secondary rounded-2xl flex items-center justify-center mx-auto mb-6">
 <Lock size={28} className="text-brand-primary"/>
 </div>
 <h2 className="text-2xl text-slate-900 uppercase tracking-tight mb-3">
 Login Required
 </h2>
 <p className="text-slate-500 text-sm mb-2">
 You need to be logged in to submit a coaching enquiry.
 </p>
 {pendingBatch && (
 <p className="text-xs text-brand-primary mb-6">
 Program: {pendingBatch.name}
 </p>
 )}
 <div className="flex gap-3 mt-6">
 <button
 onClick={() => setIsLoginPromptOpen(false)}
 className="flex-1 px-6 py-3 border-2 border-slate-200 text-slate-600 rounded-xl text-sm uppercase tracking-widest hover:bg-slate-50 transition-all"
 >
 Cancel
 </button>
 <button
 onClick={() => {
 setIsLoginPromptOpen(false);
 // Dispatch a custom event to open the auth modal in App.tsx
 window.dispatchEvent(new CustomEvent('open-auth-modal'));
 }}
 className="flex-1 px-6 py-3 bg-brand-primary text-white rounded-xl text-sm uppercase tracking-widest hover:bg-brand-primary/90 transition-all flex items-center justify-center gap-2"
 >
 <User size={16} />
 Login Now
 </button>
 </div>
 </div>
 </motion.div>
 </>
 )}
 </AnimatePresence>

 {/* Coach Profile Modal — full details (Specialization, Certification, Bio) */}
 <AnimatePresence>
 {isCoachModalOpen && currentCoach && (
 <>
 <motion.div
 initial={{ opacity: 0 }}
 animate={{ opacity: 1 }}
 exit={{ opacity: 0 }}
 onClick={() => setIsCoachModalOpen(false)}
 className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-[100]"
 />
 <motion.div
 initial={{ scale: 0.9, opacity: 0, y: 20 }}
 animate={{ scale: 1, opacity: 1, y: 0 }}
 exit={{ scale: 0.9, opacity: 0, y: 20 }}
 className="fixed inset-0 flex items-center justify-center z-[101] p-4"
 >
 <div className="bg-white rounded-[2.5rem] shadow-2xl max-w-lg w-full max-h-[85vh] overflow-y-auto p-8 sm:p-10 relative">
 <button
 onClick={() => setIsCoachModalOpen(false)}
 className="absolute top-6 right-6 w-9 h-9 rounded-full bg-slate-100 text-slate-500 flex items-center justify-center hover:bg-slate-200 transition-colors"
 >
 <X size={18} />
 </button>

 <div className="flex items-center gap-4 mb-8">
 <div className="w-16 h-16 rounded-2xl overflow-hidden border border-slate-100 shrink-0">
 <SmartImage src={currentCoach.image} alt={currentCoach.name} className="w-full h-full object-cover" />
 </div>
 <div className="min-w-0">
 <span className="text-[10px] text-brand-primary uppercase tracking-[0.3em] font-medium">Expert Coach</span>
 <h3 className="text-2xl text-slate-900 uppercase tracking-tight">{currentCoach.name}</h3>
 </div>
 </div>

 <div className="space-y-5">
 {currentCoach.availability && (
 <div>
 <h4 className="text-[10px] text-slate-400 uppercase tracking-widest mb-2 flex items-center gap-2">
 <Calendar size={14} className="text-brand-primary" /> Availability
 </h4>
 <p className="text-sm text-slate-700 leading-relaxed">{currentCoach.availability.split(',').map(d => d.trim()).filter(Boolean).join(', ')}</p>
 </div>
 )}
 {currentCoach.specialization && (
 <div>
 <h4 className="text-[10px] text-slate-400 uppercase tracking-widest mb-2 flex items-center gap-2">
 <Award size={14} className="text-brand-primary" /> Specialization
 </h4>
 <p className="text-sm text-slate-700 leading-relaxed">{currentCoach.specialization}</p>
 </div>
 )}
 {currentCoach.certification && (
 <div>
 <h4 className="text-[10px] text-slate-400 uppercase tracking-widest mb-2 flex items-center gap-2">
 <ShieldCheck size={14} className="text-brand-primary" /> Certification
 </h4>
 <p className="text-sm text-slate-700 leading-relaxed">{currentCoach.certification}</p>
 </div>
 )}
 {currentCoach.bio && (
 <div>
 <h4 className="text-[10px] text-slate-400 uppercase tracking-widest mb-2 flex items-center gap-2">
 <User size={14} className="text-brand-primary" /> Bio
 </h4>
 <p className="text-sm text-slate-700 leading-relaxed">{currentCoach.bio}</p>
 </div>
 )}
 </div>
 </div>
 </motion.div>
 </>
 )}
 </AnimatePresence>

 {/* Booking Confirmation Modal — shown after successful enquiry submission */}
 <AnimatePresence>
 {submittedRef && (
 <>
 <motion.div
 initial={{ opacity: 0 }}
 animate={{ opacity: 1 }}
 exit={{ opacity: 0 }}
 className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-[100]"
 />
 <motion.div
 initial={{ scale: 0.9, opacity: 0, y: 20 }}
 animate={{ scale: 1, opacity: 1, y: 0 }}
 exit={{ scale: 0.9, opacity: 0, y: 20 }}
 className="fixed inset-0 flex items-center justify-center z-[101] p-4"
 >
 <div className="bg-white rounded-[2.5rem] shadow-2xl max-w-md w-full p-10 text-center">
 <motion.div
 initial={{ scale: 0 }}
 animate={{ scale: 1 }}
 transition={{ delay: 0.2, type: 'spring', stiffness: 200 }}
 className="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-6"
 >
 <CheckCircle2 size={40} className="text-green-600"/>
 </motion.div>
 <h2 className="text-2xl text-slate-900 uppercase tracking-tight mb-2">
 Enquiry Submitted!
 </h2>
 <p className="text-slate-500 text-sm mb-6">
 Your coaching enquiry has been received. Our team will review it and contact you within 24 hours.
 </p>

 <div className="bg-slate-50 border-2 border-dashed border-slate-200 rounded-2xl p-5 mb-6">
 <p className="text-xs text-slate-400 uppercase tracking-widest mb-2">
 Your Reference Number
 </p>
 <p className="text-xl text-slate-900 tracking-widest">
 {submittedRef}
 </p>
 <p className="text-xs text-slate-400 mt-2">
 A confirmation email has been sent to {enquiryFormData.email}
 </p>
 </div>

 <div className="flex gap-3">
 <button
 onClick={() => setSubmittedRef(null)}
 className="flex-1 px-6 py-3 border-2 border-slate-200 text-slate-600 rounded-xl text-sm uppercase tracking-widest hover:bg-slate-50 transition-all"
 >
 Close
 </button>
 <button
 onClick={() => {
 setSubmittedRef(null);
 navigate('/dashboard/coaching-enquiries');
 }}
 className="flex-1 px-6 py-3 bg-brand-primary text-white rounded-xl text-sm uppercase tracking-widest hover:bg-brand-primary/90 transition-all flex items-center justify-center gap-2"
 >
 Track Enquiry
 <ArrowRight size={16} />
 </button>
 </div>
 </div>
 </motion.div>
 </>
 )}
 </AnimatePresence>
 </div>
 );
};