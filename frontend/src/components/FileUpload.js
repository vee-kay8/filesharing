import React, { useState } from 'react';
import './FileUpload.css';

const API_ENDPOINT = 'https://qopf2wt9g7.execute-api.us-east-1.amazonaws.com/v1';

function FileUpload({ idToken, onUploadSuccess }) {
  const [selectedFile, setSelectedFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [message, setMessage] = useState('');

  const handleFileSelect = (event) => {
    const file = event.target.files[0];
    setSelectedFile(file);
    setMessage('');
  };

  const handleUpload = async () => {
    if (!selectedFile) {
      setMessage('Please select a file first');
      return;
    }

    if (!idToken) {
      setMessage('Authentication required');
      return;
    }

    setUploading(true);
    setMessage('');

    try {
      // Read file as ArrayBuffer for binary support
      const fileContent = await selectedFile.arrayBuffer();
      const base64Content = btoa(
        new Uint8Array(fileContent).reduce(
          (data, byte) => data + String.fromCharCode(byte),
          ''
        )
      );
      
      const response = await fetch(`${API_ENDPOINT}/upload`, {
        method: 'POST',
        headers: {
          'Authorization': idToken,
          'file-name': selectedFile.name,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          file_content: base64Content
        })
      });

      const data = await response.json();

      if (response.ok) {
        setMessage(`✅ File "${data.file_name}" uploaded successfully!`);
        // Store in localStorage for file list
        const uploadedFiles = JSON.parse(localStorage.getItem('uploadedFiles') || '[]');
        uploadedFiles.push({
          name: data.file_name,
          size: selectedFile.size,
          uploadedAt: new Date().toISOString()
        });
        localStorage.setItem('uploadedFiles', JSON.stringify(uploadedFiles));
        
        setSelectedFile(null);
        // Reset file input
        document.getElementById('file-input').value = '';
        if (onUploadSuccess) onUploadSuccess();
      } else {
        setMessage(`❌ Upload failed: ${data.error || 'Unknown error'}`);
      }
    } catch (error) {
      console.error('Upload error details:', error);
      setMessage(`❌ Upload error: ${error.message}`);
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="file-upload-container">
      <h2>📤 Upload File</h2>
      <div className="upload-section">
        <input
          id="file-input"
          type="file"
          onChange={handleFileSelect}
          disabled={uploading}
          className="file-input"
        />
        {selectedFile && (
          <div className="selected-file">
            Selected: <strong>{selectedFile.name}</strong> ({(selectedFile.size / 1024).toFixed(2)} KB)
          </div>
        )}
        <button
          onClick={handleUpload}
          disabled={!selectedFile || uploading}
          className="upload-btn"
        >
          {uploading ? 'Uploading...' : 'Upload'}
        </button>
      </div>
      {message && (
        <div className={`message ${message.includes('✅') ? 'success' : 'error'}`}>
          {message}
        </div>
      )}
    </div>
  );
}

export default FileUpload;
