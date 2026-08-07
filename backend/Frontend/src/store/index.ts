/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { configureStore } from '@reduxjs/toolkit';
import coachingReducer from './slices/coachingSlice';
import notificationReducer from './slices/notificationSlice';
// import blogReducer from './slices/blogSlice';

export const store = configureStore({
 reducer: {
 coaching: coachingReducer,
 notifications: notificationReducer,
 // blogs: blogReducer,
 },
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;

