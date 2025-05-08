import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import { Amplify } from 'aws-amplify';
import { BrowserRouter } from 'react-router-dom';

// AWS Configuration
Amplify.configure({
  // Cognito Configuration
  Auth: {
    region: 'us-east-1',
    userPoolId: 'us-east-1_MtJ6RVKHZ',
    userPoolWebClientId: '6d2sl4910tde34rc5r8fau818v',
    oauth: {
      domain: 'leocorp-auth-domain-new.auth.us-east-1.amazoncognito.com',
      scope: ['email', 'profile', 'openid'],
      redirectSignIn: 'https://d1k30yyvg3g3zs.cloudfront.net/callback',
      redirectSignOut: 'https://d1k30yyvg3g3zs.cloudfront.net',
      responseType: 'code'
    }
  },
  // AppSync Configuration
  API: {
    graphql_endpoint: 'https://sisnjq4mvffercnivggnu5son4.appsync-api.us-east-1.amazonaws.com/graphql',
    graphql_headers: async () => {
      try {
        const session = await Amplify.Auth.currentSession();
        return {
          Authorization: session.getIdToken().getJwtToken(),
        };
      } catch (error) {
        console.error('Error getting current session:', error);
        return {};
      }
    }
  }
});

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </React.StrictMode>
);

