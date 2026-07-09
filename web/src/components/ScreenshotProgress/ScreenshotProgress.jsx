import React from 'react';
import './ScreenshotProgress.css';

function ScreenshotProgress({ progress }) {
  if (!progress) return null;

  const percentage = progress.total > 0 ? (progress.current / progress.total) * 100 : 0;

  return (
    <div className="screenshot-progress-widget">
      <div className="progress-header">
        <span className="progress-title">Screenshotting Catalog</span>
        <span className="progress-count">{progress.current} / {progress.total}</span>
      </div>
      <div className="progress-bar-bg">
        <div 
          className="progress-bar-fill" 
          style={{ width: `${percentage}%` }}
        />
      </div>
      <div className="progress-details">
        <div className="detail-row">
          <span className="detail-label">Current Model</span>
          <span className="detail-value">{progress.model || 'Initializing...'}</span>
        </div>
        <div className="detail-row cancel-row">
          <span className="progress-cancel">[BACKSPACE] Cancel Session</span>
        </div>
      </div>
    </div>
  );
}

export default ScreenshotProgress;
