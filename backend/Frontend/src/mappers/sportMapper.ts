/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { Trophy, Users, Star, Zap } from 'lucide-react';
import type { Sport } from '../types/coaching';
import { getImageUrl } from '../lib/utils';

// Map category to icon name (string) - serializable for Redux
const CATEGORY_ICON_NAME_MAP: Record<string, string> = {
 'Outdoor': 'Trophy',
 'Indoor': 'Users',
 'Aquatic': 'Star',
 'Adventure': 'Zap',
};

// Map icon name to actual component - use this in UI components
export const ICON_COMPONENT_MAP: Record<string, any> = {
 'Trophy': Trophy,
 'Users': Users,
 'Star': Star,
 'Zap': Zap,
};

export function mapSportFromBackend(backendSport: any): Sport {
 const category = backendSport.category || 'Outdoor';

 // No fallback image — when the admin hasn't uploaded one, image is '' and the
 // UI renders a "No image" placeholder instead of a fake stock photo.
 const iconName = CATEGORY_ICON_NAME_MAP[category] || 'Trophy';

 return {
 id: backendSport.id,
 name: backendSport.name,
 description: backendSport.description,
 category: category as Sport['category'],
 image: getImageUrl(backendSport.image),
 status: backendSport.status,
 iconName, // Store string instead of component
 };
}

// Helper function to get icon component from name - use in UI components
export function getIconComponent(iconName?: string) {
 return ICON_COMPONENT_MAP[iconName || 'Trophy'] || Trophy;
}

