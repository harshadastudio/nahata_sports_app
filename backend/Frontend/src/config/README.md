# Role-Based Menu Configuration

This directory contains configuration files for the unified role-based dashboard.

## Overview

The `roleMenuConfig.ts` file defines the menu structure for each operational role in the system:
- **USER**: Regular users accessing their personal dashboard
- **EMPLOYEE**: Staff members managing operations
- **COACH**: Coaches managing students and schedules
- **SECURITY**: Security personnel managing facility access

## Structure

### MenuSection

A menu section groups related menu items together:

```typescript
interface MenuSection {
  section: string;      // Section name (e.g., "MAIN", "OPERATIONS")
  items: MenuItem[];    // Array of menu items in this section
}
```

### MenuItem

Each menu item represents a navigable link in the dashboard:

```typescript
interface MenuItem {
  name: string;           // Display name (e.g., "Dashboard Overview")
  path: string;           // Route path (e.g., "/dashboard")
  icon: LucideIcon;       // Lucide React icon component
  permissionId: string;   // Permission identifier for access control
}
```

## Usage

### Getting Menu for a Role

```typescript
import { getMenuForRole } from '@/config/roleMenuConfig';

const userMenu = getMenuForRole('USER');
const employeeMenu = getMenuForRole('EMPLOYEE');
```

### Filtering by Permissions

```typescript
import { filterMenuByPermissions, getMenuForRole } from '@/config/roleMenuConfig';

const userRole = 'EMPLOYEE';
const userPermissions = ['employee_dashboard', 'employee_bookings'];

const menu = getMenuForRole(userRole);
const filteredMenu = filterMenuByPermissions(menu, userPermissions);
```

### Using in Components

```typescript
import { roleMenuConfig } from '@/config/roleMenuConfig';
import { useAuth } from '@/contexts/AuthContext';
import { useUserPermissions } from '@/hooks/useUserPermissions';

function Sidebar() {
  const { user } = useAuth();
  const { permissions } = useUserPermissions();
  
  const menu = roleMenuConfig[user.role];
  const filteredMenu = filterMenuByPermissions(menu, permissions);
  
  return (
    <nav>
      {filteredMenu.map((section) => (
        <div key={section.section}>
          <h3>{section.section}</h3>
          {section.items.map((item) => (
            <a key={item.path} href={item.path}>
              <item.icon />
              {item.name}
            </a>
          ))}
        </div>
      ))}
    </nav>
  );
}
```

## Role-Specific Menus

### USER Role

**Sections**: MAIN, FAMILY, ACCESS, ACCOUNT

**Menu Items**:
- Dashboard Overview
- View Sports
- My Bookings
- My Event Pass
- Feedback
- Students/Parents
- Entry Pass
- Attendance Sheet
- Logout

### EMPLOYEE Role

**Sections**: MAIN, OPERATIONS, COMMUNICATION, ACCOUNT

**Menu Items**:
- Dashboard Overview
- Bookings Management
- Users Management
- Payments Management
- Attendance Management
- Coaches Management
- Notifications
- Logout

### COACH Role

**Sections**: MAIN, COACHING, ACCOUNT

**Menu Items**:
- Dashboard Overview
- My Students
- Attendance Sheet
- Coaching Enquiries
- My Schedule
- Student Progress
- Logout

### SECURITY Role

**Sections**: MAIN, SECURITY, ACCOUNT

**Menu Items**:
- Dashboard Overview
- Entry Scanner
- Visitor Logs
- Entry Pass Verification
- Generate Pass
- Logout

## Permission IDs

Permission IDs follow a naming convention: `{role}_{feature}`

Examples:
- `user_dashboard` - USER role dashboard access
- `employee_bookings` - EMPLOYEE role bookings management
- `coach_students` - COACH role student management
- `security_event_pass_scanner` - SECURITY role entry scanner

## Adding New Menu Items

To add a new menu item:

1. **Import the icon** from `lucide-react`:
   ```typescript
   import { NewIcon } from 'lucide-react';
   ```

2. **Add the menu item** to the appropriate role's configuration:
   ```typescript
   {
     name: 'New Feature',
     path: '/dashboard/new-feature',
     icon: NewIcon,
     permissionId: 'role_new_feature',
   }
   ```

3. **Ensure the permission exists** in the backend permission system

4. **Create the corresponding route** in `App.tsx`

5. **Update tests** in `roleMenuConfig.test.ts`

## Testing

Run tests for the menu configuration:

```bash
npm test -- roleMenuConfig.test.ts
```

The test suite validates:
- All roles have valid menu structures
- All menu items have required properties
- Permission IDs follow naming conventions
- Menu filtering works correctly
- Role-specific menu items are present

## Design Validation

This configuration validates the following requirements from the design document:
- **Requirement 2.1**: Role-based menu filtering
- **Requirement 2.3**: Permission-based menu item display
- **Requirement 4.1**: EMPLOYEE role menu items
- **Requirement 5.1**: COACH role menu items
- **Requirement 6.1**: SECURITY role menu items
- **Requirement 7.1**: USER role menu items

## Notes

- Menu items are filtered at runtime based on user permissions
- The configuration is type-safe using TypeScript
- Icons are from the `lucide-react` library
- All roles have "Dashboard Overview" as the first item
- All roles have "Logout" as the last item
- Empty sections (after permission filtering) are automatically removed
