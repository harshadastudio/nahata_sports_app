/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { motion } from 'motion/react';
import { ReactNode } from 'react';

/**
 * Props for PageTransition and SectionReveal components.
 */
interface PageTransitionProps {
 /** Content to animate */
 children: ReactNode;
 /** Additional CSS classes */
 className?: string;
}

/**
 * PageTransition — wraps page content with a subtle fade+slide animation on mount.
 * 
 * **Usage Guidelines:**
 * - Use once per page-level component, not on individual sections
 * - Provides consistent page entry animation across the app
 * - Duration: 380ms with custom easing
 * 
 * @component
 * @example
 * // Wrap entire page content
 * const AboutPage = () => (
 * <PageTransition>
 * <h1>About Us</h1>
 * <p>Content...</p>
 * </PageTransition>
 * );
 * 
 * @example
 * // With custom className
 * <PageTransition className="min-h-screen">
 * <DashboardContent />
 * </PageTransition>
 */
export const PageTransition = ({ children, className = '' }: PageTransitionProps) => (
 <motion.div
 initial={{ opacity: 0, y: 10 }}
 animate={{ opacity: 1, y: 0 }}
 exit={{ opacity: 0, y: -6 }}
 transition={{ duration: 0.38, ease: [0.22, 1, 0.36, 1] }}
 className={className}
 >
 {children}
 </motion.div>
);

/**
 * SectionReveal — animates a section into view when it enters the viewport.
 * 
 * **Usage Guidelines:**
 * - Use for individual sections within a page
 * - Lightweight alternative to full page-level motion
 * - Triggers once when section enters viewport
 * - Viewport margin: -60px (triggers slightly before visible)
 * 
 * @component
 * @example
 * // Animate section on scroll
 * <SectionReveal>
 * <h2>Our Programs</h2>
 * <ProgramsGrid />
 * </SectionReveal>
 * 
 * @example
 * // With delay for staggered effect
 * <SectionReveal delay={0.2}>
 * <StatsSection />
 * </SectionReveal>
 */
export const SectionReveal = ({
 children,
 className = '',
 delay = 0,
}: PageTransitionProps & { delay?: number }) => (
 <motion.div
 initial={{ opacity: 0, y: 32 }}
 whileInView={{ opacity: 1, y: 0 }}
 viewport={{ once: true, margin: '-60px' }}
 transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1], delay }}
 className={className}
 >
 {children}
 </motion.div>
);

