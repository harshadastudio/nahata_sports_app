import { describe, it, expect } from 'vitest';
import {
 roleMenuConfig,
 getMenuForRole,
 filterMenuByPermissions,
 type MenuSection,
} from './roleMenuConfig';

describe('roleMenuConfig', () => {
 describe('Role Menu Configuration', () => {
 it('should have configuration for all operational roles', () => {
 expect(roleMenuConfig).toHaveProperty('USER');
 expect(roleMenuConfig).toHaveProperty('EMPLOYEE');
 expect(roleMenuConfig).toHaveProperty('COACH');
 expect(roleMenuConfig).toHaveProperty('SECURITY');
 });

 it('should have valid menu structure for USER role', () => {
 const userMenu = roleMenuConfig.USER;
 expect(Array.isArray(userMenu)).toBe(true);
 expect(userMenu.length).toBeGreaterThan(0);

 // Check that each section has required properties
 userMenu.forEach((section) => {
 expect(section).toHaveProperty('section');
 expect(section).toHaveProperty('items');
 expect(Array.isArray(section.items)).toBe(true);
 });
 });

 it('should have valid menu structure for EMPLOYEE role', () => {
 const employeeMenu = roleMenuConfig.EMPLOYEE;
 expect(Array.isArray(employeeMenu)).toBe(true);
 expect(employeeMenu.length).toBeGreaterThan(0);

 employeeMenu.forEach((section) => {
 expect(section).toHaveProperty('section');
 expect(section).toHaveProperty('items');
 expect(Array.isArray(section.items)).toBe(true);
 });
 });

 it('should have valid menu structure for COACH role', () => {
 const coachMenu = roleMenuConfig.COACH;
 expect(Array.isArray(coachMenu)).toBe(true);
 expect(coachMenu.length).toBeGreaterThan(0);

 coachMenu.forEach((section) => {
 expect(section).toHaveProperty('section');
 expect(section).toHaveProperty('items');
 expect(Array.isArray(section.items)).toBe(true);
 });
 });

 it('should have valid menu structure for SECURITY role', () => {
 const securityMenu = roleMenuConfig.SECURITY;
 expect(Array.isArray(securityMenu)).toBe(true);
 expect(securityMenu.length).toBeGreaterThan(0);

 securityMenu.forEach((section) => {
 expect(section).toHaveProperty('section');
 expect(section).toHaveProperty('items');
 expect(Array.isArray(section.items)).toBe(true);
 });
 });
 });

 describe('Menu Item Structure', () => {
 it('should have all required properties for each menu item', () => {
 const allRoles: Array<'USER' | 'EMPLOYEE' | 'COACH' | 'SECURITY'> = [
 'USER',
 'EMPLOYEE',
 'COACH',
 'SECURITY',
 ];

 allRoles.forEach((role) => {
 const menu = roleMenuConfig[role];
 menu.forEach((section) => {
 section.items.forEach((item) => {
 expect(item).toHaveProperty('name');
 expect(item).toHaveProperty('path');
 expect(item).toHaveProperty('icon');
 expect(item).toHaveProperty('permissionId');

 expect(typeof item.name).toBe('string');
 expect(typeof item.path).toBe('string');
 expect(typeof item.permissionId).toBe('string');
 expect(item.name.length).toBeGreaterThan(0);
 expect(item.path.length).toBeGreaterThan(0);
 expect(item.permissionId.length).toBeGreaterThan(0);
 });
 });
 });
 });

 it('should have Dashboard Overview as first item for all roles', () => {
 const allRoles: Array<'USER' | 'EMPLOYEE' | 'COACH' | 'SECURITY'> = [
 'USER',
 'EMPLOYEE',
 'COACH',
 'SECURITY',
 ];

 allRoles.forEach((role) => {
 const menu = roleMenuConfig[role];
 const firstSection = menu[0];
 const firstItem = firstSection.items[0];

 expect(firstItem.name).toBe('Dashboard Overview');
 expect(firstItem.path).toBe('/dashboard');
 });
 });

 it('should have Logout as last item for all roles', () => {
 const allRoles: Array<'USER' | 'EMPLOYEE' | 'COACH' | 'SECURITY'> = [
 'USER',
 'EMPLOYEE',
 'COACH',
 'SECURITY',
 ];

 allRoles.forEach((role) => {
 const menu = roleMenuConfig[role];
 const lastSection = menu[menu.length - 1];
 const lastItem = lastSection.items[lastSection.items.length - 1];

 expect(lastItem.name).toBe('Logout');
 expect(lastItem.path).toBe('/logout');
 });
 });
 });

 describe('Permission IDs', () => {
 it('should have role-specific permission IDs for USER', () => {
 const userMenu = roleMenuConfig.USER;
 userMenu.forEach((section) => {
 section.items.forEach((item) => {
 expect(item.permissionId).toMatch(/^user_/);
 });
 });
 });

 it('should have role-specific permission IDs for EMPLOYEE', () => {
 const employeeMenu = roleMenuConfig.EMPLOYEE;
 employeeMenu.forEach((section) => {
 section.items.forEach((item) => {
 if (item.name !== 'Logout') {
 expect(item.permissionId).toMatch(/^employee_/);
 }
 });
 });
 });

 it('should have role-specific permission IDs for COACH', () => {
 const coachMenu = roleMenuConfig.COACH;
 coachMenu.forEach((section) => {
 section.items.forEach((item) => {
 if (item.name !== 'Logout') {
 expect(item.permissionId).toMatch(/^coach_/);
 }
 });
 });
 });

 it('should have role-specific permission IDs for SECURITY', () => {
 const securityMenu = roleMenuConfig.SECURITY;
 securityMenu.forEach((section) => {
 section.items.forEach((item) => {
 if (item.name !== 'Logout') {
 expect(item.permissionId).toMatch(/^security_/);
 }
 });
 });
 });
 });

 describe('getMenuForRole', () => {
 it('should return correct menu for USER role', () => {
 const menu = getMenuForRole('USER');
 expect(menu).toEqual(roleMenuConfig.USER);
 });

 it('should return correct menu for EMPLOYEE role', () => {
 const menu = getMenuForRole('EMPLOYEE');
 expect(menu).toEqual(roleMenuConfig.EMPLOYEE);
 });

 it('should return correct menu for COACH role', () => {
 const menu = getMenuForRole('COACH');
 expect(menu).toEqual(roleMenuConfig.COACH);
 });

 it('should return correct menu for SECURITY role', () => {
 const menu = getMenuForRole('SECURITY');
 expect(menu).toEqual(roleMenuConfig.SECURITY);
 });
 });

 describe('filterMenuByPermissions', () => {
 it('should return all items when user has all permissions', () => {
 const menuSections: MenuSection[] = [
 {
 section: 'TEST',
 items: [
 {
 name: 'Item 1',
 path: '/item1',
 icon: {} as any,
 permissionId: 'perm1',
 },
 {
 name: 'Item 2',
 path: '/item2',
 icon: {} as any,
 permissionId: 'perm2',
 },
 ],
 },
 ];

 const permissions = ['perm1', 'perm2'];
 const filtered = filterMenuByPermissions(menuSections, permissions);

 expect(filtered).toHaveLength(1);
 expect(filtered[0].items).toHaveLength(2);
 });

 it('should filter out items without permissions', () => {
 const menuSections: MenuSection[] = [
 {
 section: 'TEST',
 items: [
 {
 name: 'Item 1',
 path: '/item1',
 icon: {} as any,
 permissionId: 'perm1',
 },
 {
 name: 'Item 2',
 path: '/item2',
 icon: {} as any,
 permissionId: 'perm2',
 },
 ],
 },
 ];

 const permissions = ['perm1'];
 const filtered = filterMenuByPermissions(menuSections, permissions);

 expect(filtered).toHaveLength(1);
 expect(filtered[0].items).toHaveLength(1);
 expect(filtered[0].items[0].name).toBe('Item 1');
 });

 it('should remove empty sections after filtering', () => {
 const menuSections: MenuSection[] = [
 {
 section: 'TEST1',
 items: [
 {
 name: 'Item 1',
 path: '/item1',
 icon: {} as any,
 permissionId: 'perm1',
 },
 ],
 },
 {
 section: 'TEST2',
 items: [
 {
 name: 'Item 2',
 path: '/item2',
 icon: {} as any,
 permissionId: 'perm2',
 },
 ],
 },
 ];

 const permissions = ['perm1'];
 const filtered = filterMenuByPermissions(menuSections, permissions);

 expect(filtered).toHaveLength(1);
 expect(filtered[0].section).toBe('TEST1');
 });

 it('should return empty array when no permissions match', () => {
 const menuSections: MenuSection[] = [
 {
 section: 'TEST',
 items: [
 {
 name: 'Item 1',
 path: '/item1',
 icon: {} as any,
 permissionId: 'perm1',
 },
 ],
 },
 ];

 const permissions: string[] = [];
 const filtered = filterMenuByPermissions(menuSections, permissions);

 expect(filtered).toHaveLength(0);
 });

 it('should handle multiple sections correctly', () => {
 const menuSections: MenuSection[] = [
 {
 section: 'SECTION1',
 items: [
 {
 name: 'Item 1',
 path: '/item1',
 icon: {} as any,
 permissionId: 'perm1',
 },
 {
 name: 'Item 2',
 path: '/item2',
 icon: {} as any,
 permissionId: 'perm2',
 },
 ],
 },
 {
 section: 'SECTION2',
 items: [
 {
 name: 'Item 3',
 path: '/item3',
 icon: {} as any,
 permissionId: 'perm3',
 },
 ],
 },
 ];

 const permissions = ['perm1', 'perm3'];
 const filtered = filterMenuByPermissions(menuSections, permissions);

 expect(filtered).toHaveLength(2);
 expect(filtered[0].items).toHaveLength(1);
 expect(filtered[0].items[0].name).toBe('Item 1');
 expect(filtered[1].items).toHaveLength(1);
 expect(filtered[1].items[0].name).toBe('Item 3');
 });
 });

 describe('Specific Role Menu Items', () => {
 it('should have correct USER menu items', () => {
 const userMenu = roleMenuConfig.USER;
 const allItems = userMenu.flatMap((section) => section.items);

 const expectedItems = [
 'Dashboard Overview',
 'View Sports',
 'My Bookings',
 'My Event Pass',
 'Feedback',
 'Students/Parents',
 'Entry Pass',
 'Attendance Sheet',
 'Logout',
 ];

 expectedItems.forEach((itemName) => {
 const found = allItems.find((item) => item.name === itemName);
 expect(found).toBeDefined();
 });
 });

 it('should have correct EMPLOYEE menu items', () => {
 const employeeMenu = roleMenuConfig.EMPLOYEE;
 const allItems = employeeMenu.flatMap((section) => section.items);

 const expectedItems = [
 'Dashboard Overview',
 'Bookings Management',
 'Users Management',
 'Payments Management',
 'Attendance Management',
 'Coaches Management',
 'Notifications',
 'Logout',
 ];

 expectedItems.forEach((itemName) => {
 const found = allItems.find((item) => item.name === itemName);
 expect(found).toBeDefined();
 });
 });

 it('should have correct COACH menu items', () => {
 const coachMenu = roleMenuConfig.COACH;
 const allItems = coachMenu.flatMap((section) => section.items);

 const expectedItems = [
 'Dashboard Overview',
 'My Students',
 'Attendance Sheet',
 'Coaching Enquiries',
 'My Schedule',
 'Student Progress',
 'Logout',
 ];

 expectedItems.forEach((itemName) => {
 const found = allItems.find((item) => item.name === itemName);
 expect(found).toBeDefined();
 });
 });

 it('should have correct SECURITY menu items', () => {
 const securityMenu = roleMenuConfig.SECURITY;
 const allItems = securityMenu.flatMap((section) => section.items);

 const expectedItems = [
 'Dashboard Overview',
 'Entry Scanner',
 'Verify Pass',
 'Generate Pass',
 'Visitor List',
 'Logout',
 ];

 expectedItems.forEach((itemName) => {
 const found = allItems.find((item) => item.name === itemName);
 expect(found).toBeDefined();
 });
 });
 });
});

