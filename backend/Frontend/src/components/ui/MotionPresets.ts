/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 * 
 * @fileoverview Motion presets for Framer Motion animations.
 * Provides reusable animation variants, easing functions, and transitions
 * for consistent motion design across the application.
 * 
 * @see https://www.framer.com/motion/
 */

import { Variants, Transition } from 'motion/react';

// ── Shared easing ─────────────────────────────────────────────────────

/**
 * Smooth deceleration easing (cubic-bezier).
 * Use for: Most UI transitions, page changes, smooth exits.
 * @constant
 */
export const easeOut = [0.22, 1, 0.36, 1] as const;

/**
 * Smooth acceleration and deceleration easing (cubic-bezier).
 * Use for: Bidirectional animations, modal open/close.
 * @constant
 */
export const easeInOut = [0.45, 0, 0.55, 1] as const;

/**
 * Stiff spring transition (fast, snappy).
 * Use for: Button interactions, quick state changes.
 * @constant
 */
export const springStiff: Transition = { type: 'spring', stiffness: 400, damping: 30 };

/**
 * Gentle spring transition (smooth, natural).
 * Use for: Card animations, page transitions.
 * @constant
 */
export const springGentle: Transition = { type: 'spring', stiffness: 200, damping: 24 };

/**
 * Bouncy spring transition (playful overshoot).
 * Use for: Celebration animations, success states.
 * @constant
 */
export const springBouncy: Transition = { type: 'spring', stiffness: 500, damping: 25 };

// ── Fade animations ───────────────────────────────────────────────────

/**
 * Fade in from below with upward motion.
 * Use for: Hero content, section reveals, list items.
 * 
 * @example
 * <motion.div variants={fadeUp} initial="hidden"animate="visible">
 * <h1>Welcome</h1>
 * </motion.div>
 */
export const fadeUp: Variants = {
 hidden: { opacity: 0, y: 24 },
 visible: { opacity: 1, y: 0, transition: { duration: 0.55, ease: easeOut } },
};

/**
 * Fade in from above with downward motion.
 * Use for: Dropdown menus, notifications, tooltips.
 * 
 * @example
 * <motion.div variants={fadeDown} initial="hidden"animate="visible">
 * <Notification />
 * </motion.div>
 */
export const fadeDown: Variants = {
 hidden: { opacity: 0, y: -20 },
 visible: { opacity: 1, y: 0, transition: { duration: 0.5, ease: easeOut } },
};

/**
 * Simple fade in (no motion).
 * Use for: Overlays, backdrops, subtle reveals.
 * 
 * @example
 * <motion.div variants={fadeIn} initial="hidden"animate="visible">
 * <Backdrop />
 * </motion.div>
 */
export const fadeIn: Variants = {
 hidden: { opacity: 0 },
 visible: { opacity: 1, transition: { duration: 0.4 } },
};

// ── Slide animations ──────────────────────────────────────────────────

/**
 * Slide in from left with fade.
 * Use for: Sidebar menus, left-aligned content, navigation.
 * 
 * @example
 * <motion.div variants={slideInLeft} initial="hidden"animate="visible">
 * <Sidebar />
 * </motion.div>
 */
export const slideInLeft: Variants = {
 hidden: { opacity: 0, x: -32 },
 visible: { opacity: 1, x: 0, transition: { duration: 0.55, ease: easeOut } },
};

/**
 * Slide in from right with fade.
 * Use for: Feature cards, right-aligned content, modals.
 * 
 * @example
 * <motion.div variants={slideInRight} initial="hidden"animate="visible">
 * <FeatureCard />
 * </motion.div>
 */
export const slideInRight: Variants = {
 hidden: { opacity: 0, x: 32 },
 visible: { opacity: 1, x: 0, transition: { duration: 0.55, ease: easeOut } },
};

/**
 * Slide up from below with fade (larger distance).
 * Use for: Bottom sheets, footer content, CTA sections.
 * 
 * @example
 * <motion.div variants={slideUp} initial="hidden"animate="visible">
 * <BottomSheet />
 * </motion.div>
 */
export const slideUp: Variants = {
 hidden: { opacity: 0, y: 48 },
 visible: { opacity: 1, y: 0, transition: { duration: 0.6, ease: easeOut } },
};

// ── Scale animations ──────────────────────────────────────────────────

/**
 * Spring-based pop animation (scale from 0).
 * Use for: Badges, notifications, success checkmarks.
 * 
 * @example
 * <motion.div variants={springPop} initial="hidden"animate="visible">
 * <Badge>New</Badge>
 * </motion.div>
 */
export const springPop: Variants = {
 hidden: { scale: 0, opacity: 0 },
 visible: { scale: 1, opacity: 1, transition: { type: 'spring', stiffness: 400, damping: 20 } },
};

/**
 * Subtle scale in with fade.
 * Use for: Cards, images, content blocks.
 * 
 * @example
 * <motion.div variants={scaleIn} initial="hidden"animate="visible">
 * <Card />
 * </motion.div>
 */
export const scaleIn: Variants = {
 hidden: { opacity: 0, scale: 0.92 },
 visible: { opacity: 1, scale: 1, transition: { duration: 0.45, ease: easeOut } },
};

/**
 * Scale up with spring (larger scale change).
 * Use for: Modals, dialogs, important announcements.
 * 
 * @example
 * <motion.div variants={scaleUp} initial="hidden"animate="visible">
 * <Modal />
 * </motion.div>
 */
export const scaleUp: Variants = {
 hidden: { opacity: 0, scale: 0.85 },
 visible: { opacity: 1, scale: 1, transition: { type: 'spring', stiffness: 300, damping: 22 } },
};

// ── Container / stagger ───────────────────────────────────────────────

/**
 * Container for staggered children animations (60ms delay).
 * Use for: Lists, grids, navigation menus.
 * 
 * @example
 * <motion.ul variants={staggerContainer} initial="hidden"animate="visible">
 * <motion.li variants={fadeUp}>Item 1</motion.li>
 * <motion.li variants={fadeUp}>Item 2</motion.li>
 * </motion.ul>
 */
export const staggerContainer: Variants = {
 hidden: {},
 visible: { transition: { staggerChildren: 0.06 } },
};

/**
 * Container for slow staggered animations (100ms delay).
 * Use for: Hero sections, feature showcases, important content.
 * 
 * @example
 * <motion.div variants={staggerSlow} initial="hidden"animate="visible">
 * <motion.h1 variants={fadeUp}>Title</motion.h1>
 * <motion.p variants={fadeUp}>Description</motion.p>
 * </motion.div>
 */
export const staggerSlow: Variants = {
 hidden: {},
 visible: { transition: { staggerChildren: 0.1 } },
};

/**
 * Container for fast staggered animations (40ms delay).
 * Use for: Quick reveals, table rows, small UI elements.
 * 
 * @example
 * <motion.div variants={staggerFast} initial="hidden"animate="visible">
 * {items.map(item => (
 * <motion.div key={item.id} variants={fadeUp}>{item.name}</motion.div>
 * ))}
 * </motion.div>
 */
export const staggerFast: Variants = {
 hidden: {},
 visible: { transition: { staggerChildren: 0.04 } },
};

// ── Page transitions ──────────────────────────────────────────────────

/**
 * Page-level transition with enter/exit states.
 * Use for: Route changes, page navigation.
 * 
 * @example
 * <AnimatePresence mode="wait">
 * <motion.div
 * key={location.pathname}
 * variants={pageEnter}
 * initial="hidden"
 * animate="visible"
 * exit="exit"
 * >
 * <PageContent />
 * </motion.div>
 * </AnimatePresence>
 */
export const pageEnter: Variants = {
 hidden: { opacity: 0, y: 12 },
 visible: { opacity: 1, y: 0, transition: { duration: 0.4, ease: easeOut } },
 exit: { opacity: 0, y: -8, transition: { duration: 0.25, ease: easeInOut } },
};

// ── Card hover presets (for motion.div whileHover) ────────────────────

/**
 * Subtle card lift on hover.
 * Use for: Content cards, clickable items.
 * 
 * @example
 * <motion.div whileHover={cardHover}>
 * <Card />
 * </motion.div>
 */
export const cardHover = {
 y: -4,
 transition: { type: 'spring', stiffness: 400, damping: 20 },
};

/**
 * Pronounced card lift on hover.
 * Use for: Featured cards, important CTAs.
 * 
 * @example
 * <motion.div whileHover={cardHoverLift}>
 * <FeaturedCard />
 * </motion.div>
 */
export const cardHoverLift = {
 y: -8,
 transition: { type: 'spring', stiffness: 300, damping: 18 },
};

/**
 * Button lift on hover.
 * Use for: Buttons, interactive elements.
 * 
 * @example
 * <motion.button whileHover={buttonHover} whileTap={buttonTap}>
 * Click Me
 * </motion.button>
 */
export const buttonHover = {
 y: -2,
 transition: { type: 'spring', stiffness: 500, damping: 25 },
};

/**
 * Button press effect.
 * Use for: Buttons, clickable elements.
 * 
 * @example
 * <motion.button whileHover={buttonHover} whileTap={buttonTap}>
 * Click Me
 * </motion.button>
 */
export const buttonTap = { scale: 0.97 };

// ── Viewport animation defaults ───────────────────────────────────────

/**
 * Viewport settings for scroll-triggered animations.
 * Triggers once when element enters viewport (with -60px margin).
 * 
 * @example
 * <motion.div
 * initial={{ opacity: 0 }}
 * whileInView={{ opacity: 1 }}
 * viewport={viewportOnce}
 * >
 * <Content />
 * </motion.div>
 */
export const viewportOnce = { once: true, margin: '-60px' } as const;

