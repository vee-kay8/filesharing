import React, { useState, useEffect } from 'react';
import { Amplify } from 'aws-amplify';
import { Authenticator } from '@aws-amplify/ui-react';
import { fetchAuthSession, signOut } from 'aws-amplify/auth';
import '@aws-amplify/ui-react/styles.css';
import './App.css';
import awsConfig from './aws-config';
import FileUpload from './components/FileUpload';
import FileList from './components/FileList';

Amplify.configure(awsConfig);

function App() {
  const [idToken, setIdToken] = useState(null);
  const [user, setUser] = useState(null);

  const fetchIdToken = async () => {
    try {
      const session = await fetchAuthSession({ forceRefresh: true });
      console.log('Session:', session);
      const token = session.tokens?.idToken?.toString();
      console.log('ID Token fetched:', token ? 'Success' : 'Failed');
      if (token) {
        console.log('Token preview:', token.substring(0, 50) + '...');
      }
      setIdToken(token);
    } catch (error) {
      console.error('Error fetching ID token:', error);
      console.error('Error details:', JSON.stringify(error, null, 2));
      setIdToken(null);
    }
  };

  const handleSignOut = async () => {
    try {
      await signOut();
      setIdToken(null);
      setUser(null);
    } catch (error) {
      console.error('Error signing out:', error);
    }
  };

  // Fetch token when user becomes available
  useEffect(() => {
    if (user && !idToken) {
      console.log('User authenticated, fetching token...');
      fetchIdToken();
    }
  }, [user, idToken]);

  return (
    <Authenticator>
      {({ signOut, user: authUser }) => {
        // Update user state when auth changes
        if (authUser && authUser !== user) {
          setUser(authUser);
        }

        return (
          <div className="App">
            <header className="App-header">
              <h1>🗂️ File Sharing App</h1>
              <div className="user-info">
                <span>Welcome, {authUser?.signInDetails?.loginId || authUser?.username}</span>
                <button onClick={handleSignOut} className="sign-out-btn">
                  Sign Out
                </button>
              </div>
            </header>
            
            <main className="App-main">
              <FileUpload idToken={idToken} onUploadSuccess={fetchIdToken} />
              <FileList idToken={idToken} />
            </main>
          </div>
        );
      }}
    </Authenticator>
  );
}

export default App;
