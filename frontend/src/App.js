import React, { useEffect, useState } from 'react';
import { Amplify, Auth, API, graphqlOperation } from 'aws-amplify';
import { Route, Routes, Link, useNavigate } from 'react-router-dom';
import HomePage from './components/HomePage';
import CallbackPage from './components/CallbackPage';
import Dashboard from './components/Dashboard';

function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    checkAuthState();
  }, []);

  async function checkAuthState() {
    try {
      const currentUser = await Auth.currentAuthenticatedUser();
      setUser(currentUser);
    } catch (error) {
      setUser(null);
    } finally {
      setLoading(false);
    }
  }

  async function signIn() {
    try {
      Auth.federatedSignIn();
    } catch (error) {
      console.error('Error signing in:', error);
    }
  }

  async function signOut() {
    try {
      await Auth.signOut();
      setUser(null);
      navigate('/');
    } catch (error) {
      console.error('Error signing out:', error);
    }
  }

  if (loading) {
    return <div className="app">Loading...</div>;
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>LeoCorp Application</h1>
      </header>
      
      <nav className="nav-menu">
        <Link to="/">Home</Link>
        {user && <Link to="/dashboard">Dashboard</Link>}
      </nav>
      
      <div className="auth-buttons">
        {!user ? (
          <button onClick={signIn}>Sign In</button>
        ) : (
          <button onClick={signOut}>Sign Out</button>
        )}
      </div>
      
      {user && (
        <div className="user-info">
          <h3>User Information</h3>
          <p><strong>Username:</strong> {user.username}</p>
          <p><strong>Email:</strong> {user.attributes?.email || 'Not available'}</p>
        </div>
      )}

      <div className="app-content">
        <Routes>
          <Route path="/" element={<HomePage user={user} />} />
          <Route path="/callback" element={<CallbackPage setUser={setUser} />} />
          <Route path="/dashboard" element={<Dashboard user={user} />} />
        </Routes>
      </div>
    </div>
  );
}

export default App;

