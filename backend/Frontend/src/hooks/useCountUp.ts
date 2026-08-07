/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useEffect, useState } from 'react';

/**
 * Custom hook for animated counter with easing
 * @param end - Target number to count up to
 * @param duration - Animation duration in milliseconds (default: 2000)
 * @param start - Starting number (default: 0)
 * @returns Current animated value
 */
export const useCountUp = (end: number, duration: number = 2000, start: number = 0) => {
 const [count, setCount] = useState(start);

 useEffect(() => {
 let startTime: number | null = null;
 let animationFrame: number;

 // Easing function (ease-out cubic)
 const easeOutCubic = (t: number): number => {
 return 1 - Math.pow(1 - t, 3);
 };

 const animate = (currentTime: number) => {
 if (!startTime) startTime = currentTime;
 const elapsed = currentTime - startTime;
 const progress = Math.min(elapsed / duration, 1);

 // Apply easing
 const easedProgress = easeOutCubic(progress);
 const currentCount = start + (end - start) * easedProgress;

 setCount(Math.floor(currentCount));

 if (progress < 1) {
 animationFrame = requestAnimationFrame(animate);
 } else {
 setCount(end); // Ensure we end at exact target
 }
 };

 animationFrame = requestAnimationFrame(animate);

 return () => {
 if (animationFrame) {
 cancelAnimationFrame(animationFrame);
 }
 };
 }, [end, duration, start]);

 return count;
};

