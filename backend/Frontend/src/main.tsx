import {StrictMode} from 'react';
import {createRoot} from 'react-dom/client';
import App from './App.tsx';
import './index.css';

import { BrowserRouter } from 'react-router-dom';
import { Provider } from 'react-redux';
import { store } from './store';
import { HelmetProvider } from 'react-helmet-async';

// GoogleOAuthProvider deliberately does NOT live here. Mounting it at the root
// pulled accounts.google.com/gsi/client (~97 KiB of third-party JS) into every
// page load, including for anonymous visitors who never sign in. It now wraps
// AuthModal only, so the script loads when the login dialog is opened.

createRoot(document.getElementById('root')!).render(
 <StrictMode>
 <HelmetProvider>
 <Provider store={store}>
 <BrowserRouter>
 <App />
 </BrowserRouter>
 </Provider>
 </HelmetProvider>
 </StrictMode>,
);

