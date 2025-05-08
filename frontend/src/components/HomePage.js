import React from 'react';

const HomePage = ({ user }) => {
  return (
    <div>
      <h2>Welcome to LeoCorp Application</h2>
      
      {user ? (
        <div>
          <p>You are logged in as {user.username}.</p>
          <p>Navigate to the Dashboard to manage your data.</p>
        </div>
      ) : (
        <div>
          <p>Please sign in to access the application features.</p>
          <p>This application demonstrates integration of AWS Cognito for authentication and AppSync for GraphQL operations.</p>
        </div>
      )}
    </div>
  );
};

export default HomePage;

