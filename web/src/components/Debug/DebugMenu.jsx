import React from 'react';
import { useLocale } from '../../context/LocaleContext';
import './DebugMenu.css';

const DebugMenu = ({ currentUI, setCurrentUI }) => {
  const { t } = useLocale();

  const interfaces = [
    { id: 'panel', label: t('ui.panel', 'Panel') },
    { id: 'creator', label: t('ui.creator', 'Creator') },
    { id: 'furniture', label: t('ui.furniture', 'Furniture') },
    { id: 'realestate', label: t('ui.realestate', 'Real Estate') },
    { id: 'none', label: t('ui.hide_all', 'Hide All') }
  ];

  return (
    <div className="debug-menu">
      <div className="debug-title">{t('ui.debug_ui', 'DEBUG UI')}</div>
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
