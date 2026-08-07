# Breadcrumbs Component Usage Guide

## Overview

The `Breadcrumbs` component automatically generates a navigation breadcrumb trail based on the current route. It provides visual feedback about the user's location in the dashboard hierarchy and allows quick navigation to parent pages.

## Features

✅ **Automatic breadcrumb generation** from current route path  
✅ **Clickable navigation** for all non-active breadcrumb items  
✅ **Active breadcrumb highlighting** for the current page  
✅ **Browser document title updates** based on current page  
✅ **Home icon** for dashboard root  
✅ **Responsive design** with proper spacing and separators  

## Installation

The component is already exported from the dashboard components:

```typescript
import { Breadcrumbs } from '@/components/dashboard';
// or
import { Breadcrumbs } from '@/components/dashboard/Breadcrumbs';
```

## Basic Usage

### Option 1: Use in UnifiedDashboardLayout (Recommended)

The Breadcrumbs component can be integrated into the `UnifiedDashboardLayout` to automatically show breadcrumbs on all dashboard pages:

```tsx
import { UnifiedDashboardLayout, DashboardNavbar, Breadcrumbs } from '@/components/dashboard';

function MyDashboardPage() {
  return (
    <UnifiedDashboardLayout
      navbar={<DashboardNavbar pageTitle="My Page" />}
      sidebar={<MySidebar />}
    >
      <Breadcrumbs />
      <div className="mt-4">
        {/* Your page content */}
      </div>
    </UnifiedDashboardLayout>
  );
}
```

### Option 2: Use Standalone

You can also use the Breadcrumbs component standalone in any dashboard page:

```tsx
import { Breadcrumbs } from '@/components/dashboard';

function MyPage() {
  return (
    <div>
      <Breadcrumbs />
      <div className="mt-4">
        {/* Your page content */}
      </div>
    </div>
  );
}
```

## How It Works

### Automatic Route Parsing

The component automatically parses the current URL path and generates breadcrumb items:

| Route | Breadcrumbs Generated |
|-------|----------------------|
| `/dashboard` | Dashboard |
| `/dashboard/employee/bookings` | Dashboard > Employee > Bookings |
| `/dashboard/coach/students` | Dashboard > Coach > Students |
| `/dashboard/security/scanner` | Dashboard > Security > Entry Scanner |

### Label Formatting

The component includes special formatting for common dashboard segments:

```typescript
// Special cases (automatically formatted)
'bookings' → 'Bookings'
'coaching-enquiries' → 'Coaching Enquiries'
'verify-pass' → 'Verify Pass'
'student-progress' → 'Student Progress'

// Unknown segments (auto-capitalized)
'my-custom-page' → 'My Custom Page'
```

### Document Title Updates

The component automatically updates the browser document title:

```
Route: /dashboard/employee/bookings
Title: Dashboard - Employee - Bookings - Nahata Sports
```

## Styling

The component uses Tailwind CSS classes and follows the project's design system:

- **Active breadcrumb**: `text-brand-primary` with `font-medium`
- **Inactive breadcrumbs**: `text-slate-600` with hover effects
- **Separators**: ChevronRight icons in `text-slate-400`
- **Home icon**: Displayed for the dashboard root

## Accessibility

The component follows accessibility best practices:

- Uses semantic `<nav>` with `aria-label="Breadcrumb"`
- Active breadcrumb has `aria-current="page"`
- Proper focus states with keyboard navigation support
- Screen reader friendly with proper ARIA attributes

## Customization

### Adding Custom Labels

To add custom labels for new routes, edit the `formatSegmentLabel` function in `Breadcrumbs.tsx`:

```typescript
const specialCases: Record<string, string> = {
  // ... existing cases
  'my-new-route': 'My Custom Label',
};
```

### Styling Customization

The component uses utility classes that can be customized:

```tsx
// Active breadcrumb color
className="text-brand-primary"  // Change to your preferred color

// Hover effects
className="hover:text-brand-primary"  // Customize hover color
```

## Examples

### Example 1: Employee Dashboard

```tsx
// Route: /dashboard/employee/bookings
// Renders: Dashboard > Employee > Bookings
// - "Dashboard" and "Employee" are clickable
// - "Bookings" is highlighted as active
```

### Example 2: Coach Dashboard

```tsx
// Route: /dashboard/coach/coaching-enquiries
// Renders: Dashboard > Coach > Coaching Enquiries
// - "Dashboard" and "Coach" are clickable
// - "Coaching Enquiries" is highlighted as active
```

### Example 3: Security Dashboard

```tsx
// Route: /dashboard/security/verify-pass
// Renders: Dashboard > Security > Verify Pass
// - "Dashboard" and "Security" are clickable
// - "Verify Pass" is highlighted as active
```

## Testing

The component includes comprehensive unit tests. Run tests with:

```bash
npm test -- src/components/dashboard/Breadcrumbs.test.tsx
```

Test coverage includes:
- ✅ Breadcrumb generation from routes
- ✅ Active breadcrumb highlighting
- ✅ Clickable navigation links
- ✅ Document title updates
- ✅ Special label formatting
- ✅ Home icon rendering
- ✅ Separator rendering

## Requirements Validation

This component validates the following requirements from the spec:

- **Requirement 15.1**: Active menu item highlighting in sidebar (breadcrumbs complement this)
- **Requirement 15.2**: Breadcrumb trail showing current location ✅
- **Requirement 15.3**: Clickable breadcrumb navigation ✅
- **Requirement 15.5**: Browser document title updates ✅

## Notes

- The component only renders when the current route starts with `/dashboard`
- Non-dashboard routes will not display breadcrumbs
- The component is fully responsive and works on all screen sizes
- No props are required - it automatically detects the current route using React Router's `useLocation` hook

## Support

For issues or questions about the Breadcrumbs component, refer to:
- Component source: `src/components/dashboard/Breadcrumbs.tsx`
- Tests: `src/components/dashboard/Breadcrumbs.test.tsx`
- Design document: `.kiro/specs/unified-role-based-dashboard/design.md`
