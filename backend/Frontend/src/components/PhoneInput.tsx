import React, { useState } from 'react';

interface PhoneInputProps {
 value: string;
 onChange: (value: string) => void;
 label?: string;
 placeholder?: string;
 required?: boolean;
 disabled?: boolean;
 error?: string;
 className?: string;
}

export const PhoneInput: React.FC<PhoneInputProps> = ({
 value,
 onChange,
 label = 'Mobile Number',
 placeholder = 'Enter 10-digit mobile number',
 required = false,
 disabled = false,
 error: externalError,
 className = ''
}) => {
 const [internalError, setInternalError] = useState('');
 const [touched, setTouched] = useState(false);

 const error = externalError || internalError;

 const validatePhone = (phone: string): string => {
 if (!phone && required) {
 return 'Mobile number is required';
 }
 
 if (phone && phone.length > 0) {
 const cleaned = phone.replace(/\D/g, '');
 
 if (cleaned.length > 10) {
 return 'Mobile number cannot exceed 10 digits';
 }
 
 if (cleaned.length > 0 && cleaned.length < 10) {
 return 'Mobile number must be exactly 10 digits';
 }
 
 if (cleaned.length === 10 && !/^[6-9][0-9]{9}$/.test(cleaned)) {
 return 'Please enter a valid Indian mobile number';
 }
 }
 
 return '';
 };

 const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
 const input = e.target.value;
 const cleaned = input.replace(/\D/g, '');
 const limited = cleaned.slice(0, 10);
 
 onChange(limited);
 
 if (touched) {
 const validationError = validatePhone(limited);
 setInternalError(validationError);
 }
 };

 const handleBlur = () => {
 setTouched(true);
 const validationError = validatePhone(value);
 setInternalError(validationError);
 };

 const isValid = value.length === 10 && !error;
 const showError = touched && error;

 return (
 <div className={`space-y-2 ${className}`}>
 {label && (
 <label className="block text-sm text-gray-700 mb-2">
 {label} {required && <span className="text-red-500">*</span>}
 </label>
 )}
 
 <div className="relative">
 <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
 <svg className="h-5 w-5 text-gray-400"fill="none"stroke="currentColor"viewBox="0 0 24 24">
 <path strokeLinecap="round"strokeLinejoin="round"strokeWidth={2} d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
 </svg>
 </div>
 
 <input
 type="tel"
 value={value}
 onChange={handleChange}
 onBlur={handleBlur}
 placeholder={placeholder}
 disabled={disabled}
 maxLength={10}
 className={`
 block w-full pl-12 pr-12 py-3 
 border rounded-lg 
 text-sm 
 focus:ring-2 focus:ring-blue-500 focus:border-blue-500
 transition-all
 ${showError ? 'border-red-300 bg-red-50' : 'border-gray-300'}
 ${isValid ? 'border-green-300 bg-green-50' : ''}
 ${disabled ? 'opacity-50 cursor-not-allowed bg-gray-100' : 'bg-white'}
 `}
 />
 
 <div className="absolute inset-y-0 right-0 pr-4 flex items-center gap-2">
 {value.length > 0 && (
 <span className={`text-xs ${
 value.length === 10 ? 'text-green-600' : 'text-gray-400'
 }`}>
 {value.length}/10
 </span>
 )}
 
 {isValid && (
 <div className="w-5 h-5 bg-green-500 rounded-full flex items-center justify-center">
 <svg className="w-3 h-3 text-white"fill="none"stroke="currentColor"viewBox="0 0 24 24">
 <path strokeLinecap="round"strokeLinejoin="round"strokeWidth={3} d="M5 13l4 4L19 7"/>
 </svg>
 </div>
 )}
 </div>
 </div>
 
 {showError && (
 <div className="flex items-center gap-2 text-red-600 text-sm">
 <svg className="w-4 h-4"fill="currentColor"viewBox="0 0 20 20">
 <path fillRule="evenodd"d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z"clipRule="evenodd"/>
 </svg>
 <span>{error}</span>
 </div>
 )}
 </div>
 );
};

