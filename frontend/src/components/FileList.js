import React, { useState, useEffect } from 'react';
import './FileList.css';

const API_ENDPOINT = 'https://qopf2wt9g7.execute-api.us-east-1.amazonaws.com/v1';

function FileList({ idToken }) {
  const [files, setFiles] = useState([]);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    if (idToken) {
      fetchFiles();
    }
  }, [idToken]);

  const fetchFiles = async () => {
    setLoading(true);
    setMessage('');
    
    try {
      // Get files from localStorage (uploaded in this session)
      const uploadedFiles = JSON.parse(localStorage.getItem('uploadedFiles') || '[]');
      
      // Remove duplicates by file name (keep the most recent upload)
      const uniqueFiles = uploadedFiles.reduce((acc, file) => {
        const existing = acc.find(f => f.name === file.name);
        if (!existing || new Date(file.uploadedAt) > new Date(existing.uploadedAt)) {
          return [...acc.filter(f => f.name !== file.name), file];
        }
        return acc;
      }, []);
      
      // Transform to match S3 object format with unique IDs
      const fileObjects = uniqueFiles.map((file, index) => ({
        id: `${file.name}-${file.uploadedAt}`, // Unique ID for React key
        Key: file.name,
        Size: file.size,
        LastModified: file.uploadedAt
      }));
      
      setFiles(fileObjects);
      
      if (fileObjects.length === 0) {
        setMessage('No files uploaded yet. Upload your first file!');
      }
    } catch (error) {
      console.error('Error fetching files:', error);
      setMessage('Error loading files');
      setFiles([]);
    } finally {
      setLoading(false);
    }
  };

  const getPresignedUrl = async (fileName) => {
    if (!idToken) {
      setMessage('Authentication required');
      return;
    }

    try {
      const response = await fetch(`${API_ENDPOINT}/presign?file_name=${encodeURIComponent(fileName)}`, {
        headers: {
          'Authorization': idToken
        }
      });

      const data = await response.json();

      if (response.ok && data.url) {
        window.open(data.url, '_blank');
        setMessage(`✅ Opening ${fileName}`);
      } else {
        setMessage(`❌ Failed to get download link: ${data.error || 'Unknown error'}`);
      }
    } catch (error) {
      setMessage(`❌ Error: ${error.message}`);
    }
  };

  const downloadFile = async (fileName) => {
    if (!idToken) {
      setMessage('Authentication required');
      return;
    }

    try {
      const response = await fetch(`${API_ENDPOINT}/download/${encodeURIComponent(fileName)}`, {
        headers: {
          'Authorization': idToken
        }
      });

      if (response.ok) {
        const contentType = response.headers.get('content-type');
        
        if (contentType && contentType.includes('application/json')) {
          // Response might be base64 encoded
          const data = await response.json();
          // Handle base64 if needed
          const blob = new Blob([atob(data)], { type: 'application/octet-stream' });
          const url = window.URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = url;
          a.download = fileName;
          a.click();
          window.URL.revokeObjectURL(url);
        } else {
          const blob = await response.blob();
          const url = window.URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = url;
          a.download = fileName;
          a.click();
          window.URL.revokeObjectURL(url);
        }
        
        setMessage(`✅ Downloaded ${fileName}`);
      } else {
        setMessage(`❌ Download failed`);
      }
    } catch (error) {
      setMessage(`❌ Error: ${error.message}`);
    }
  };

  return (
    <div className="file-list-container">
      <h2>📁 Your Files</h2>
      <button onClick={fetchFiles} disabled={loading} className="refresh-btn">
        {loading ? 'Loading...' : '🔄 Refresh'}
      </button>
      
      {message && (
        <div className={`message ${message.includes('✅') ? 'success' : 'error'}`}>
          {message}
        </div>
      )}

      <div className="file-list">
        {loading ? (
          <p>Loading files...</p>
        ) : files.length > 0 ? (
          <table>
            <thead>
              <tr>
                <th>File Name</th>
                <th>Size</th>
                <th>Last Modified</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {files.map((file) => (
                <tr key={file.id}>
                  <td>{file.Key}</td>
                  <td>{(file.Size / 1024).toFixed(2)} KB</td>
                  <td>{new Date(file.LastModified).toLocaleString()}</td>
                  <td>
                    <button onClick={() => getPresignedUrl(file.Key)} className="action-btn">
                      🔗 Get Link
                    </button>
                    <button onClick={() => downloadFile(file.Key)} className="action-btn">
                      ⬇️ Download
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <p className="empty-state">No files uploaded yet. Upload your first file!</p>
        )}
      </div>
    </div>
  );
}

export default FileList;
