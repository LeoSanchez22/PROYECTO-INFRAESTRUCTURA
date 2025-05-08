import React, { useEffect, useState } from 'react';
import { Auth } from 'aws-amplify';
import { useNavigate } from 'react-router-dom';

const CallbackPage = ({ setUser }) => {
  const [error, setError] = useState(null);
  const navigate = useNavigate();

  useEffect(() => {
    handleAuthentication();
  }, []);

  async function handleAuthentication() {
    try {
      // This is for Cognito Hosted UI redirect flow
      await Auth.currentAuthenticatedUser();
      
      // Get the user info
      const currentUser = await Auth.currentAuthenticatedUser();
      setUser(currentUser);
      
      // Redirect to dashboard after successful authentication
      navigate('/dashboard');
    } catch (error) {
      console.error('Error during authentication callback:', error);
      setError('Authentication failed. Please try again.');
      setTimeout(() => {
        navigate('/');
      }, 3000);
    }
  }

  return (
    <div>
      {error ? (
        <div className="error-message">{error}</div>
      ) : (
        <div>
          <p>Completing authentication...</p>
          <p>Please wait while we redirect you.</p>
        </div>
      )}
    </div>
  );
};

export default CallbackPage;

