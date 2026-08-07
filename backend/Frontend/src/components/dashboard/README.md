# UnifiedDashboardLayout Component

## Overview

The `UnifiedDashboardLayout` component provides the main layout structure for all operational roles (EMPLOYEE, COACH, SECURITY, USER) in the unified dashboard.

## Features

- **Responsive Design**: Adapts to mobile, tablet, and desktop screen sizes
- **Sidebar Management**: Handles sidebar visibility and toggle functionality
- **Flexible Content**: Accepts sidebar, navbar, and content as props
- **Mobile Overlay**: Shows overlay when sidebar is open on mobile devices
- **Auto-close**: Automatically closes sidebar when clicking outside on mobile

## Responsive Behavior

### Mobile (< 768px)
- Sidebar hidden by default
- Overlay when sidebar is opened
- Toggle button in navbar
- Close button in sidebar
- Click outside to close

### Tablet (768px - 1023px)
- Sidebar visible (can be condensed based on sidebar component implementation)
- No overlay
- No toggle button

### Desktop (>= 1024px)
- Sidebar always visible
- Full-width sidebar
- No overlay
- No toggle button

## Usage

```tsx
import { UnifiedDashboardLayout } from '@/components/dashboard';
import { RoleBasedSidebar } from '@/components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '@/components/dashboard/DashboardNavbar';

function DashboardPage() {
  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar />}
    >
      <div>
        <h1>Dashboard Content</h1>
        <p>Your page content goes here</p>
      </div>
    </UnifiedDashboardLayout>
  );
}
```

## Props

### `UnifiedDashboardLayoutProps`

| Prop | Type | Required | Description |
|------|------|----------|-------------|
| `children` | `React.ReactNode` | Yes | The main content to display in the content area |
| `sidebar` | `React.ReactNode` | Yes | The sidebar component (e.g., RoleBasedSidebar) |
| `navbar` | `React.ReactNode` | Yes | The navbar component (e.g., DashboardNavbar) |

## Requirements Validation

This component validates the following requirements:

- **2.1**: Role-based sidebar with menu items filtered by user's role and permissions
- **2.2**: Navbar showing user's name and role
- **2.6**: Consistent styling across all operational role views
- **2.7**: Responsive design for mobile, tablet, and desktop
- **14.1**: Mobile responsive behavior (< 768px)
- **14.2**: Tablet responsive behavior (768px - 1023px)
- **14.3**: Desktop responsive behavior (>= 1024px)

## Implementation Details

### State Management

The component manages two pieces of state:
- `sidebarOpen`: Controls sidebar visibility on mobile
- `isMobile`: Tracks whether the current screen size is mobile

### Event Listeners

- **Resize**: Updates mobile state when window is resized
- **Click Outside**: Closes sidebar when clicking outside on mobile

### CSS Classes

The component uses Tailwind CSS classes for styling and responsive behavior:
- `flex`: Main container layout
- `fixed lg:sticky`: Sidebar positioning (fixed on mobile, sticky on desktop)
- `transition-transform`: Smooth sidebar slide animation
- `overflow-y-auto`: Scrollable content area

---

# DashboardNavbar Component

## Overview

The `DashboardNavbar` component provides the top navigation bar for the unified dashboard, displaying page title, notifications, user information, and logout functionality.

## Features

- **Page Title Display**: Shows the current page title
- **Notification Integration**: Uses the existing NotificationBell component
- **User Avatar**: Displays user initials in a circular avatar
- **User Info**: Shows user name and role badge
- **Role Badge**: Color-coded badge based on user role
- **Logout Button**: Allows users to log out
- **Responsive Design**: Adapts to mobile and desktop screens

## Usage

```tsx
import { DashboardNavbar } from '@/components/dashboard';

function DashboardPage() {
  return (
    <UnifiedDashboardLayout
      navbar={<DashboardNavbar pageTitle="Dashboard Overview" />}
      sidebar={<RoleBasedSidebar />}
    >
      {/* Your content */}
    </UnifiedDashboardLayout>
  );
}
```

## Props

### `DashboardNavbarProps`

| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `pageTitle` | `string` | No | `'Dashboard'` | The title to display in the navbar |

## Role Badge Colors

The component uses color-coded badges for different roles:

- **ADMIN**: Purple (`bg-purple-100 text-purple-700`)
- **EMPLOYEE**: Blue (`bg-blue-100 text-blue-700`)
- **COACH**: Green (`bg-green-100 text-green-700`)
- **SECURITY**: Orange (`bg-orange-100 text-orange-700`)
- **USER**: Slate (`bg-slate-100 text-slate-700`)

## Responsive Behavior

### Mobile (< 640px)
- Shows only user avatar (initials)
- Hides user name and role badge
- Shows logout icon only (no text)

### Desktop (>= 640px)
- Shows full user info card with avatar, name, and role badge
- Shows logout button with icon and text

## Requirements Validation

This component validates the following requirements:

- **2.2**: Navbar showing user's name and role
- **15.4**: Current page title in the navbar

## Implementation Details

### User Avatar

The avatar displays the user's initials (first letter of each word in the name, up to 2 letters):
- "John Doe" → "JD"
- "Alice" → "A"
- "Bob Smith Johnson" → "BS"

### Logout Functionality

The logout button calls the `logout()` method from `AuthContext`, which:
1. Clears the authentication token
2. Clears the user state
3. Redirects to the home page (/)

### Notification Bell

The component integrates the existing `NotificationBell` component, which:
- Shows unread notification count
- Opens notification popup on click
- Polls for new notifications every 30 seconds

## Next Steps

After creating this navbar component, the following components need to be created:

1. **RoleBasedSidebar** (Task 2.3): Sidebar with role-based menu items
2. **Breadcrumbs**: Breadcrumb navigation component

## Testing

Unit tests will be added in Phase 6 of the migration strategy. Tests should cover:

- Rendering of sidebar, navbar, and content
- Mobile menu toggle functionality
- Sidebar open/close behavior
- Overlay click handling
- Responsive behavior at different screen sizes
- Click outside to close functionality
