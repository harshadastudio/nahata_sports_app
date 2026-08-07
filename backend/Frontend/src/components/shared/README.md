# Shared Components Documentation

This directory contains reusable components used across all operational role dashboards (EMPLOYEE, COACH, SECURITY, USER).

## 📁 Directory Structure

```
shared/
├── table/              # Table components
│   ├── DataTable.tsx
│   ├── TableHeader.tsx
│   ├── TableRow.tsx
│   ├── Pagination.tsx
│   └── index.ts
├── form/               # Form components
│   ├── FormActions.tsx
│   ├── Checkbox.tsx
│   └── index.ts
├── loading/            # Loading components
│   ├── Spinner.tsx
│   ├── Skeleton.tsx
│   └── index.ts
├── empty/              # Empty state components
│   ├── EmptyState.tsx
│   └── index.ts
├── index.ts            # Main export file
└── README.md           # This file
```

---

## 🗂️ Table Components

### DataTable

A full-featured data table component with built-in search, pagination, row selection, and loading states.

#### Features
- ✅ Generic type support for any data structure
- ✅ Built-in search functionality
- ✅ Pagination (local or server-side)
- ✅ Row selection with checkboxes
- ✅ Loading states with skeleton UI
- ✅ Empty state handling
- ✅ Responsive design
- ✅ Custom actions toolbar
- ✅ Row click handlers
- ✅ Custom column rendering

#### Props

```typescript
interface DataTableProps<T extends { id: string | number }> {
  columns: Column<T>[];           // Column definitions
  data: T[];                      // Data array
  loading?: boolean;              // Show loading state
  totalRecords?: number;          // Total records (for server-side pagination)
  pageSize?: number;              // Items per page (default: 10)
  onPageChange?: (page: number) => void;  // Page change handler
  currentPage?: number;           // Current page (default: 1)
  onRowClick?: (row: T) => void;  // Row click handler
  title?: string;                 // Table title
  actions?: React.ReactNode;      // Custom action buttons
  searchPlaceholder?: string;     // Search input placeholder
}
```

#### Column Definition

```typescript
interface Column<T> {
  key: keyof T | 'action' | 'selection' | 'index';
  label: string;
  render?: (row: T, index: number) => React.ReactNode;
  className?: string;
}
```

#### Usage Example

```tsx
import { DataTable } from '@/src/components/shared/table';
import { Column } from '@/src/types';
import { Edit, Trash } from 'lucide-react';

interface Booking {
  id: number;
  userName: string;
  sportName: string;
  date: string;
  status: string;
}

const BookingsPage = () => {
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);

  const columns: Column<Booking>[] = [
    { key: 'selection', label: '' },
    { key: 'index', label: '#' },
    { key: 'userName', label: 'User Name' },
    { key: 'sportName', label: 'Sport' },
    { key: 'date', label: 'Date' },
    {
      key: 'status',
      label: 'Status',
      render: (booking) => (
        <span className={`px-2 py-1 rounded-full text-xs ${
          booking.status === 'Confirmed' 
            ? 'bg-green-100 text-green-700' 
            : 'bg-yellow-100 text-yellow-700'
        }`}>
          {booking.status}
        </span>
      )
    },
    {
      key: 'action',
      label: 'Actions',
      render: (booking) => (
        <div className="flex gap-2">
          <button onClick={() => handleEdit(booking)}>
            <Edit size={16} />
          </button>
          <button onClick={() => handleDelete(booking.id)}>
            <Trash size={16} />
          </button>
        </div>
      )
    }
  ];

  return (
    <DataTable
      columns={columns}
      data={bookings}
      loading={loading}
      currentPage={currentPage}
      totalPages={10}
      onPageChange={setCurrentPage}
      title="Bookings Management"
      searchPlaceholder="Search bookings..."
      actions={
        <button className="px-4 py-2 bg-blue-600 text-white rounded-lg">
          Add Booking
        </button>
      }
    />
  );
};
```

#### Special Column Keys

- **`selection`**: Renders a checkbox for row selection
- **`index`**: Renders the row number (1-indexed)
- **`action`**: Custom column for action buttons (use with `render`)

#### Local vs Server-Side Pagination

**Local Pagination** (default):
```tsx
<DataTable
  columns={columns}
  data={allData}  // Pass all data
  pageSize={10}
  // No onPageChange handler
/>
```

**Server-Side Pagination**:
```tsx
<DataTable
  columns={columns}
  data={currentPageData}  // Pass only current page data
  totalRecords={totalCount}
  pageSize={10}
  currentPage={page}
  onPageChange={handlePageChange}  // Fetch new page data
/>
```

---

### Pagination

Standalone pagination component with first/last/prev/next navigation.

#### Props

```typescript
interface PaginationProps {
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  className?: string;
}
```

#### Usage Example

```tsx
import { Pagination } from '@/src/components/shared/table';

<Pagination
  currentPage={currentPage}
  totalPages={totalPages}
  onPageChange={setCurrentPage}
/>
```

#### Features
- First/last page buttons
- Previous/next page buttons
- Smart page number display (shows nearby pages)
- Ellipsis for skipped pages
- Disabled states for boundary pages

---

### TableHeader

Table header component with column labels and select-all checkbox.

#### Props

```typescript
interface TableHeaderProps<T> {
  columns: Column<T>[];
  onSelectAll: (checked: boolean) => void;
  isAllSelected: boolean;
  className?: string;
}
```

#### Usage

Typically used internally by `DataTable`, but can be used standalone:

```tsx
import { TableHeader } from '@/src/components/shared/table';

<table>
  <TableHeader
    columns={columns}
    onSelectAll={handleSelectAll}
    isAllSelected={allSelected}
  />
  <tbody>
    {/* rows */}
  </tbody>
</table>
```

---

### TableRow

Table row component with selection and custom rendering.

#### Props

```typescript
interface TableRowProps<T extends { id: string | number }> {
  row: T;
  columns: Column<T>[];
  index: number;
  isSelected?: boolean;
  onSelect?: (checked: boolean) => void;
  className?: string;
  onRowClick?: (row: T) => void;
}
```

#### Usage

Typically used internally by `DataTable`, but can be used standalone:

```tsx
import { TableRow } from '@/src/components/shared/table';

<tbody>
  {data.map((row, index) => (
    <TableRow
      key={row.id}
      row={row}
      columns={columns}
      index={index}
      isSelected={selectedIds.has(row.id)}
      onSelect={(checked) => handleSelect(row.id, checked)}
      onRowClick={handleRowClick}
    />
  ))}
</tbody>
```

---

## 📝 Form Components

### FormActions

Standardized form action buttons (Save, Cancel, Reset).

#### Props

```typescript
interface FormActionsProps {
  onSave?: () => void;
  onCancel?: () => void;
  onReset?: () => void;
  saveText?: string;
  cancelText?: string;
  resetText?: string;
  showReset?: boolean;
  disabled?: boolean;
  className?: string;
}
```

#### Usage Example

```tsx
import { FormActions } from '@/src/components/shared/form';

const UserForm = () => {
  const handleSave = () => {
    // Save logic
  };

  const handleCancel = () => {
    // Cancel logic
  };

  const handleReset = () => {
    // Reset form
  };

  return (
    <form>
      {/* Form fields */}
      
      <FormActions
        onSave={handleSave}
        onCancel={handleCancel}
        onReset={handleReset}
        showReset={true}
        disabled={loading}
        saveText="Save User"
        cancelText="Cancel"
        resetText="Reset Form"
      />
    </form>
  );
};
```

#### Features
- Primary save button with icon
- Secondary cancel button
- Optional reset button
- Disabled state support
- Customizable button text
- Consistent styling

---

### Checkbox

Custom styled checkbox with smooth animations.

#### Props

```typescript
interface CheckboxProps extends React.InputHTMLAttributes<HTMLInputElement> {
  className?: string;
}
```

#### Usage Example

```tsx
import { Checkbox } from '@/src/components/shared/form';

const [isChecked, setIsChecked] = useState(false);

<Checkbox
  checked={isChecked}
  onChange={(e) => setIsChecked(e.target.checked)}
/>

// With label
<label className="flex items-center gap-2">
  <Checkbox
    checked={isChecked}
    onChange={(e) => setIsChecked(e.target.checked)}
  />
  <span>Accept terms and conditions</span>
</label>
```

#### Features
- Custom styling matching design system
- Smooth check animation
- Hover states
- Active states (scale effect)
- Accessible (uses native input)

---

## ⏳ Loading Components

### Spinner

Loading spinner for async operations.

#### Props

```typescript
interface SpinnerProps {
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}
```

#### Usage Example

```tsx
import { Spinner } from '@/src/components/shared/loading';

const MyComponent = () => {
  const [loading, setLoading] = useState(true);

  if (loading) {
    return <Spinner size="md" />;
  }

  return <div>Content</div>;
};
```

#### Sizes
- `sm`: 24px (h-6 w-6)
- `md`: 48px (h-12 w-12) - default
- `lg`: 64px (h-16 w-16)

---

### Skeleton

Skeleton loaders for content placeholders.

#### Props

```typescript
interface SkeletonProps {
  className?: string;
  rows?: number;
}

interface SkeletonTableProps {
  columns: number;
  rows?: number;
}
```

#### Usage Example

```tsx
import { Skeleton, SkeletonTable } from '@/src/components/shared/loading';

// Single skeleton
<Skeleton className="h-4 w-full" />

// Multiple skeleton rows
<Skeleton className="h-4 w-full" rows={3} />

// Skeleton table
<table>
  <thead>{/* headers */}</thead>
  <tbody>
    {loading ? (
      <SkeletonTable columns={5} rows={10} />
    ) : (
      {/* actual rows */}
    )}
  </tbody>
</table>
```

#### Features
- Pulse animation
- Customizable size and shape
- Table-specific skeleton component
- Configurable number of rows

---

## 🚫 Empty State Components

### EmptyState

Empty state component with icon, title, description, and optional action.

#### Props

```typescript
interface EmptyStateProps {
  icon?: LucideIcon;
  title: string;
  description?: string;
  action?: React.ReactNode;
  className?: string;
}
```

#### Usage Example

```tsx
import { EmptyState } from '@/src/components/shared/empty';
import { Users, Plus } from 'lucide-react';

const UsersPage = () => {
  const [users, setUsers] = useState([]);

  if (users.length === 0) {
    return (
      <EmptyState
        icon={Users}
        title="No users found"
        description="Get started by adding your first user"
        action={
          <button className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg">
            <Plus size={16} />
            Add User
          </button>
        }
      />
    );
  }

  return <div>{/* users list */}</div>;
};
```

#### Features
- Optional icon from lucide-react
- Title and description
- Optional action button/element
- Centered layout
- Customizable styling

---

## 🎨 Styling Guidelines

### Consistent Colors

All shared components use consistent colors from the design system:

```css
/* Primary */
bg-blue-600, text-blue-600, border-blue-600

/* Text */
text-gray-900 (dark), text-gray-600 (muted)

/* Borders */
border-gray-200

/* Backgrounds */
bg-white, bg-slate-50, bg-[#fcfcfd]
```

### Responsive Design

All components are responsive by default:

- **Mobile**: Stacked layouts, full-width elements
- **Tablet**: Condensed layouts, optimized spacing
- **Desktop**: Full layouts, optimal spacing

### Accessibility

All components follow accessibility best practices:

- ✅ Keyboard navigation support
- ✅ ARIA labels where appropriate
- ✅ Focus states
- ✅ Semantic HTML
- ✅ Screen reader friendly

---

## 🔧 Customization

### Extending Components

All components accept a `className` prop for custom styling:

```tsx
<DataTable
  columns={columns}
  data={data}
  className="custom-table-class"
/>

<Checkbox
  checked={checked}
  onChange={onChange}
  className="custom-checkbox-class"
/>
```

### Custom Rendering

Use the `render` function in column definitions for custom cell rendering:

```tsx
const columns: Column<User>[] = [
  {
    key: 'status',
    label: 'Status',
    render: (user) => (
      <CustomStatusBadge status={user.status} />
    )
  }
];
```

---

## 🧪 Testing

### Unit Tests

All shared components should have unit tests:

```tsx
import { render, screen } from '@testing-library/react';
import { Checkbox } from './Checkbox';

describe('Checkbox', () => {
  it('renders correctly', () => {
    render(<Checkbox checked={false} onChange={() => {}} />);
    expect(screen.getByRole('checkbox')).toBeInTheDocument();
  });

  it('handles checked state', () => {
    render(<Checkbox checked={true} onChange={() => {}} />);
    expect(screen.getByRole('checkbox')).toBeChecked();
  });
});
```

### Integration Tests

Test components with real data:

```tsx
import { render, screen } from '@testing-library/react';
import { DataTable } from './DataTable';

describe('DataTable', () => {
  it('renders data correctly', () => {
    const data = [
      { id: 1, name: 'John', email: 'john@example.com' }
    ];
    const columns = [
      { key: 'name', label: 'Name' },
      { key: 'email', label: 'Email' }
    ];

    render(<DataTable columns={columns} data={data} />);
    
    expect(screen.getByText('John')).toBeInTheDocument();
    expect(screen.getByText('john@example.com')).toBeInTheDocument();
  });
});
```

---

## 📚 Additional Resources

- **Main README**: See `/README.md` for project overview
- **Dashboard Components**: See `/src/components/dashboard/README.md`
- **Type Definitions**: See `/src/types/index.ts`
- **Utilities**: See `/src/lib/utils.ts`

---

## 🤝 Contributing

When adding new shared components:

1. Place in appropriate subdirectory (`table/`, `form/`, `loading/`, `empty/`)
2. Export from subdirectory `index.ts`
3. Add to main `shared/index.ts`
4. Document in this README
5. Add unit tests
6. Update TypeScript types if needed

---

**Last Updated:** May 7, 2026  
**Version:** 1.0.0
