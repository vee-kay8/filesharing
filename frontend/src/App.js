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

  useEffect(() => {
    fetchIdToken();
  }, []);

  const fetchIdToken = async () => {
    try {
      const session = await fetchAuthSession();
      const token = session.tokens?.idToken?.toString();
      setIdToken(token);
    } catch (error) {
      console.error('Error fetching ID token:', error);
    }
  };

  const handleSignOut = async () => {
    try {
      await signOut();
      setIdToken(null);
    } catch (error) {
      console.error('Error signing out:', error);
    }
  };

  return (
    <Authenticator>
      {({ signOut, user }) => (
        <div className="App">
          <header className="App-header">
            <h1>🗂️ File Sharing App</h1>
            <div className="user-info">
              <span>Welcome, {user?.signInDetails?.loginId || user?.username}</span>
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
      )}
    </Authenticator>
  );
}

export default App;
