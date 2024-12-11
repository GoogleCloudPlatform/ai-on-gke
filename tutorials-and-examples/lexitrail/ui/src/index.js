import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { GoogleOAuthProvider } from "@react-oauth/google"

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <GoogleOAuthProvider clientId={window.config.GOOGLE_CLIENT_ID}>
    {/* un-comment the below after switch out the deployment mode */}
    {/* <React.StrictMode> */}
      <App />
    {/* </React.StrictMode> */}
  </GoogleOAuthProvider>

  
);
