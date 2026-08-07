/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */


import { HeroSection } from './home/HeroSection';
import { SportsProgramsSection } from './home/SportsProgramsSection';
import { BookingSection } from './home/BookingSection';
import { FeaturesSection } from './home/FeaturesSection';
import { LocationsSection, EventsSection } from './home/LocationsEventsSection';
import { FAQSection, CTASection } from './home/FAQCTASection';

export const HomePage = () => (
 <main>
 <HeroSection />
 <SportsProgramsSection />
 <BookingSection />
 <FeaturesSection />
 <LocationsSection />
 <EventsSection />
 <FAQSection />
 <CTASection />
 </main>
);

