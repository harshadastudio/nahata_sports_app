/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import type { Coach } from '../types/coaching';
import { getImageUrl } from '../lib/utils';

export function mapCoachFromBackend(backendCoach: any): Coach {
 return {
 id: backendCoach.id,
 name: backendCoach.name,
 email: backendCoach.email,
 phone: backendCoach.phone,
 sportId: backendCoach.sportId,
 sport: backendCoach.sport,
 ground: backendCoach.ground,
 certification: backendCoach.certification,
 bio: backendCoach.bio,
 image: getImageUrl(backendCoach.image), // '' when none — UI shows a "No image" placeholder
 experience: backendCoach.experience,
 specialization: backendCoach.specialization,
 qualifications: backendCoach.qualifications,
 availability: backendCoach.availability,
 status: backendCoach.status,
 awards: parseAwards(backendCoach.qualifications),
 achievements: parseAchievements(backendCoach.specialization),
 };
}

function parseAwards(qualifications?: string): string[] {
 if (!qualifications) return ['Certified Professional Coach'];
 // Parse comma-separated or newline-separated awards
 return qualifications
 .split(/[,\n]/)
 .map(award => award.trim())
 .filter(award => award.length > 0);
}

function parseAchievements(specialization?: string): string[] {
 if (!specialization) return ['Experienced in coaching all skill levels'];
 // Parse comma-separated or newline-separated achievements
 return specialization
 .split(/[,\n]/)
 .map(achievement => achievement.trim())
 .filter(achievement => achievement.length > 0);
}

