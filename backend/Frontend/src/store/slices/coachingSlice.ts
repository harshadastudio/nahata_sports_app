/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import { coachingApi } from '../../services/coachingApi';
import { mapSportFromBackend } from '../../mappers/sportMapper';
import { mapCoachFromBackend } from '../../mappers/coachMapper';
import { mapBatchFromBackend } from '../../mappers/batchMapper';
import type { Sport, Coach, Batch, SportComplex } from '../../types/coaching';

interface CoachingState {
 // Data
 sports: Sport[];
 coaches: Coach[];
 batches: Batch[];
 sportComplexes: SportComplex[];
 
 // Loading states
 loadingSports: boolean;
 loadingCoaches: boolean;
 loadingBatches: boolean;
 loadingSportComplexes: boolean;
 
 // Error states
 sportsError: string | null;
 coachesError: string | null;
 batchesError: string | null;
 sportComplexesError: string | null;
}

const initialState: CoachingState = {
 sports: [],
 coaches: [],
 batches: [],
 sportComplexes: [],
 loadingSports: true,
 loadingCoaches: false,
 loadingBatches: false,
 loadingSportComplexes: true,
 sportsError: null,
 coachesError: null,
 batchesError: null,
 sportComplexesError: null,
};

// Async Thunks
export const fetchSports = createAsyncThunk(
 'coaching/fetchSports',
 async (ground?: string) => {
 console.log('🔄 [Redux] fetchSports started with ground:', ground);
 const data = await coachingApi.getSports(ground);
 const mapped = data.map(mapSportFromBackend);
 console.log('✅ [Redux] fetchSports completed:', mapped);
 return mapped;
 }
);

export const fetchCoaches = createAsyncThunk(
 'coaching/fetchCoaches',
 async (filters: { sportId?: number; ground?: string }) => {
 const data = await coachingApi.getCoaches({
 ...filters,
 status: 'Active',
 });
 return data.map(mapCoachFromBackend);
 }
);

export const fetchBatchesAndPrograms = createAsyncThunk(
 'coaching/fetchBatchesAndPrograms',
 async (arg: number | { sportId: number; ground?: string }) => {
 const sportId = typeof arg === 'number' ? arg : arg.sportId;
 const ground = typeof arg === 'number' ? undefined : arg.ground;
 const batchesData = await coachingApi.getBatchesBySport(sportId, ground);
 const batches = batchesData.map(mapBatchFromBackend);

 return {
 batches,
 combined: batches,
 };
 }
);

export const fetchSportComplexes = createAsyncThunk(
 'coaching/fetchSportComplexes',
 async () => {
 console.log('🔄 [Redux] fetchSportComplexes started');
 const result = await coachingApi.getSportComplexes();
 console.log('✅ [Redux] fetchSportComplexes completed:', result);
 return result;
 }
);

const coachingSlice = createSlice({
 name: 'coaching',
 initialState,
 reducers: {
 clearError: (state) => {
 state.sportsError = null;
 state.coachesError = null;
 state.batchesError = null;
 state.sportComplexesError = null;
 },
 },
 extraReducers: (builder) => {
 // Fetch Sports
 builder
 .addCase(fetchSports.pending, (state) => {
 state.loadingSports = true;
 state.sportsError = null;
 })
 .addCase(fetchSports.fulfilled, (state, action) => {
 state.loadingSports = false;
 state.sports = action.payload;
 })
 .addCase(fetchSports.rejected, (state, action) => {
 state.loadingSports = false;
 state.sportsError = action.error.message || 'Failed to fetch sports';
 });
 
 // Fetch Coaches
 builder
 .addCase(fetchCoaches.pending, (state) => {
 state.coaches = []; // Clear coaches immediately when fetching starts
 state.loadingCoaches = true;
 state.coachesError = null;
 })
 .addCase(fetchCoaches.fulfilled, (state, action) => {
 state.loadingCoaches = false;
 state.coaches = action.payload;
 })
 .addCase(fetchCoaches.rejected, (state, action) => {
 state.loadingCoaches = false;
 state.coaches = []; // Clear coaches on error too
 state.coachesError = action.error.message || 'Failed to fetch coaches';
 });
 
 // Fetch Batches and Programs
 builder
 .addCase(fetchBatchesAndPrograms.pending, (state) => {
 state.loadingBatches = true;
 state.batchesError = null;
 })
 .addCase(fetchBatchesAndPrograms.fulfilled, (state, action) => {
 state.loadingBatches = false;
 state.batches = action.payload.combined;
 })
 .addCase(fetchBatchesAndPrograms.rejected, (state, action) => {
 state.loadingBatches = false;
 state.batchesError = action.error.message || 'Failed to fetch batches and programs';
 });
 
 // Fetch Sport Complexes
 builder
 .addCase(fetchSportComplexes.pending, (state) => {
 state.loadingSportComplexes = true;
 state.sportComplexesError = null;
 })
 .addCase(fetchSportComplexes.fulfilled, (state, action) => {
 state.loadingSportComplexes = false;
 state.sportComplexes = action.payload;
 })
 .addCase(fetchSportComplexes.rejected, (state, action) => {
 state.loadingSportComplexes = false;
 state.sportComplexesError = action.error.message || 'Failed to fetch sport complexes';
 });
 },
});

export const { clearError } = coachingSlice.actions;
export default coachingSlice.reducer;

