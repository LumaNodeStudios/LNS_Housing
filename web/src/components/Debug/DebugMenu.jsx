import React from 'react';
import './DebugMenu.css';

const DebugMenu = ({ currentUI, setCurrentUI }) => {
  const interfaces = [
    { id: 'panel', label: 'Panel' },
    { id: 'creator', label: 'Creator' },
    { id: 'furniture', label: 'Furniture' },
    { id: 'realestate', label: 'Real Estate' },
    { id: 'none', label: 'Hide All' }
  ];

  return (
    <div className="debug-menu">
      <div className="debug-title">DEBUG UI</div>
      <div className="debug-buttons">
        {interfaces.map((ui) => (
          <button
            key={ui.id}
            className={`debug-btn ${currentUI === ui.id ? 'active' : ''}`}
            onClick={() => setCurrentUI(ui.id)}
          >
            {ui.label}
          </button>
        ))}
      </div>
    </div>
  );
};

export default DebugMenu;
