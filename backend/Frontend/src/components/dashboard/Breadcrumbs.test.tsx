import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { BrowserRouter, MemoryRouter } from 'react-router-dom';
import { Breadcrumbs } from './Breadcrumbs';

describe('Breadcrumbs', () => {
 let originalTitle: string;

 beforeEach(() => {
 // Save original document title
 originalTitle = document.title;
 });

 afterEach(() => {
 // Restore original document title
 document.title = originalTitle;
 });

 it('should render nothing when not in dashboard route', () => {
 const { container } = render(
 <MemoryRouter initialEntries={['/']}>
 <Breadcrumbs />
 </MemoryRouter>
 );

 expect(container.firstChild).toBeNull();
 });

 it('should render dashboard breadcrumb for /dashboard route', () => {
 render(
 <MemoryRouter initialEntries={['/dashboard']}>
 <Breadcrumbs />
 </MemoryRouter>
 );

 expect(screen.getByText('Dashboard')).toBeInTheDocument();
 expect(screen.getByLabelText('Breadcrumb')).toBeInTheDocument();
 });

 it('should render breadcrumb trail for nested route', () => {
 render(
 <MemoryRouter initialEntries={['/dashboard/employee/bookings']}>
 <Breadcrumbs />
 </MemoryRouter>
 );

 expect(screen.getByText('Dashboard')).toBeInTheDocument();
 expect(screen.getByText('Employee')).toBeInTheDocument();
 expect(screen.getByText('Bookings')).toBeInTheDocument();
 });

 it('should highlight active breadcrumb', () => {
 render(
 <MemoryRouter initialEntries={['/dashboard/employee/bookings']}>
 <Breadcrumbs />
 </MemoryRouter>
 );

 const activeItem = screen.getByText('Bookings');
 expect(activeItem.tagName).toBe('SPAN');
 expect(activeItem).toHaveAttribute('aria-current', 'page');
 });

 it('should make non-active breadcrumbs clickable', () => {
 render(
 <MemoryRouter initialEntries={['/dashboard/employee/bookings']}>
 <Breadcrumbs />
 </MemoryRouter>
 );

 const dashboardLink = screen.getByText('Dashboard').closest('a');
 expect(dashboardLink).toHaveAttribute('href', '/dashboard');

 const employeeLink = screen.getByText('Employee').closest('a');
 expect(employeeLink).toHaveAttribute('href', '/dashboard/employee');
 });

 it('should display home icon for dashboard root', () => {
 render(
 <MemoryRouter initialEntries={['/dashboard/employee/bookings']}>
 <Breadcrumbs />
 </MemoryRouter>
 );

 // Home icon should be present (rendered as svg)
 const breadcrumbNav = screen.getByLabelText('Breadcrumb');
 const svgs = breadcrumbNav.querySelectorAll('svg');
 expect(svgs.length).toBeGreaterThan(0);
 });

 it('should update document title based on current page', () => {
 render(
 <MemoryRouter initialEntries={['/dashboard/employee/bookings']}>
 <Breadcrumbs />
 </MemoryRouter>
 );

 expect(document.title).toBe('Dashboard - Employee - Bookings - Nahata Sports');
 });

 it('should format special segment labels correctly', () => {
 render(
 <MemoryRouter initialEntries={['/dashboard/coach/coaching-enquiries']}>
 <Breadcrumbs />
 </MemoryRouter>
 );

 expect(screen.getByText('Coaching Enquiries')).toBeInTheDocument();
 });

 it('should format unknown segments with capitalization', () => {
 render(
 <MemoryRouter initialEntries={['/dashboard/some-unknown-route']}>
 <Breadcrumbs />
 </MemoryRouter>
 );

 expect(screen.getByText('Some Unknown Route')).toBeInTheDocument();
 });

 it('should render separators between breadcrumb items', () => {
 render(
 <MemoryRouter initialEntries={['/dashboard/employee/bookings']}>
 <Breadcrumbs />
 </MemoryRouter>
 );

 // ChevronRight icons are used as separators
 const breadcrumbNav = screen.getByLabelText('Breadcrumb');
 const separators = breadcrumbNav.querySelectorAll('svg[aria-hidden="true"]');
 
 // Should have separators (ChevronRight) between items
 // We have 3 items, so we expect at least 2 separators (excluding Home icon)
 expect(separators.length).toBeGreaterThanOrEqual(2);
 });
});

