import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  X,
  Eye,
  EyeOff,
  Check,
  Delete,
  AlertCircle
} from 'lucide-react';
import './StorageKeypad.css';

const fetchNui = async (eventName, data = {}) => {
  const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing';
  try {
    const resp = await fetch(`https://${resourceName}/${eventName}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    });
    return await resp.json();
  } catch (err) {
    return null;
  }
};

export default function StorageKeypad({ data, onClose }) {
  const [mode, setMode] = useState(data?.mode || 'unlock'); // 'unlock' | 'register' | 'reset'
  const [code, setCode] = useState('');
  const [showCode, setShowCode] = useState(false);
  const [status, setStatus] = useState('idle'); // 'idle' | 'loading' | 'success' | 'error'
  const [errorMessage, setErrorMessage] = useState('');
  const [shake, setShake] = useState(false);
  const codeRef = useRef(code);
  const statusRef = useRef(status);
  const modeRef = useRef(mode);

  codeRef.current = code;
  statusRef.current = status;
  modeRef.current = mode;

  const title = data?.title || (data?.isFridge ? 'Refrigerator' : 'Storage Unit');
  const isFridge = data?.isFridge || false;
  const canReset = data?.canReset || false;
  const maxDigits = 8;
  const minDigits = 4;

  const handleDigit = (digit) => {
    if (statusRef.current === 'loading' || statusRef.current === 'success') return;
    if (codeRef.current.length >= maxDigits) return;
    if (statusRef.current === 'error') {
      setStatus('idle');
      setErrorMessage('');
    }
    setCode((prev) => prev + digit);
  };

  const handleDelete = () => {
    if (statusRef.current === 'loading' || statusRef.current === 'success') return;
    if (codeRef.current.length === 0) return;
    if (statusRef.current === 'error') {
      setStatus('idle');
      setErrorMessage('');
    }
    setCode((prev) => prev.slice(0, -1));
  };

  const handleClear = () => {
    if (statusRef.current === 'loading' || statusRef.current === 'success') return;
    setCode('');
    setStatus('idle');
    setErrorMessage('');
  };

  const handleSubmit = async () => {
    if (statusRef.current === 'loading' || statusRef.current === 'success') return;

    if (codeRef.current.length < minDigits) {
      setStatus('error');
      setErrorMessage(`Passcode must be at least ${minDigits} digits`);
      setShake(true);
      setTimeout(() => setShake(false), 500);
      return;
    }

    setStatus('loading');
    setErrorMessage('');

    const res = await fetchNui('submitStoragePasscode', {
      propertyId: data?.propertyId,
      stashId: data?.stashId,
      furnitureId: data?.furnitureId,
      passcode: codeRef.current,
      mode: modeRef.current,
    });

    if (res && res.success) {
      setStatus('success');
      setTimeout(() => {
        if (onClose) onClose();
      }, 400);
    } else {
      setStatus('error');
      setErrorMessage(res?.message || 'Incorrect passcode');
      setShake(true);
      setTimeout(() => {
        setShake(false);
        setCode('');
      }, 500);
    }
  };

  // Keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        if (onClose) onClose();
        return;
      }

      if (e.key >= '0' && e.key <= '9') {
        e.preventDefault();
        handleDigit(e.key);
      } else if (e.key === 'Backspace') {
        e.preventDefault();
        handleDelete();
      } else if (e.key === 'Enter') {
        e.preventDefault();
        handleSubmit();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const getModeInfo = () => {
    switch (mode) {
      case 'register':
        return {
          badge: 'SET PASSCODE',
          badgeClass: 'badge-register',
          subtitle: 'Create a 4-8 digit passcode to secure this storage',
          submitLabel: 'REGISTER PASSCODE',
        };
      case 'reset':
        return {
          badge: 'RESET PASSCODE',
          badgeClass: 'badge-reset',
          subtitle: 'Enter a new 4-8 digit passcode for this storage',
          submitLabel: 'SAVE NEW PASSCODE',
        };
      case 'unlock':
      default:
        return {
          badge: 'LOCKED',
          badgeClass: 'badge-locked',
          subtitle: 'Enter storage passcode to unlock and open',
          submitLabel: 'UNLOCK STORAGE',
        };
    }
  };

  const modeInfo = getModeInfo();

  return (
    <div className="keypad-overlay">
      <motion.div
        className={`keypad-container ${shake ? 'keypad-shake' : ''}`}
        initial={{ opacity: 0, scale: 0.92, y: 15 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.92, y: 15 }}
        transition={{ duration: 0.22, ease: [0.16, 1, 0.3, 1] }}
      >
        {/* Header */}
        <div className="keypad-header">
          <div className="keypad-header-left">
            <div className="keypad-header-text">
              <div className="keypad-title-row">
                <span className="keypad-title">{title}</span>
                <span className={`keypad-badge ${modeInfo.badgeClass}`}>{modeInfo.badge}</span>
              </div>
              <p className="keypad-subtitle">{modeInfo.subtitle}</p>
            </div>
          </div>
          <div className="keypad-header-actions">
            {mode === 'unlock' && canReset && (
              <button
                type="button"
                className="keypad-action-btn"
                title="Change passcode"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  setMode('reset');
                  setCode('');
                  setStatus('idle');
                  setErrorMessage('');
                }}
              >
                <span>Reset</span>
              </button>
            )}
            {mode === 'reset' && (
              <button
                type="button"
                className="keypad-action-btn"
                title="Back to unlock"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  setMode('unlock');
                  setCode('');
                  setStatus('idle');
                  setErrorMessage('');
                }}
              >
                <span>Unlock</span>
              </button>
            )}
            <button
              type="button"
              className="keypad-close-btn"
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                if (onClose) onClose();
              }}
              title="Close keypad"
            >
              <X size={18} />
            </button>
          </div>
        </div>

        {/* PIN Screen / Display */}
        <div className={`keypad-screen ${status === 'error' ? 'screen-error' : ''} ${status === 'success' ? 'screen-success' : ''}`}>
          <div className="screen-content">
            {status === 'success' ? (
              <div className="screen-status-msg success">
                <Check size={22} className="success-icon" />
                <span>PASSCODE ACCEPTED</span>
              </div>
            ) : status === 'error' ? (
              <div className="screen-status-msg error">
                <AlertCircle size={20} className="error-icon" />
                <span>{errorMessage || 'INCORRECT PASSCODE'}</span>
              </div>
            ) : (
              <div className="screen-digits-row">
                {Array.from({ length: Math.max(code.length, minDigits) }).map((_, idx) => {
                  const hasChar = idx < code.length;
                  const char = code[idx];
                  return (
                    <div
                      key={idx}
                      className={`screen-dot-slot ${hasChar ? 'filled' : ''} ${idx === code.length ? 'current' : ''}`}
                    >
                      {hasChar ? (
                        showCode ? (
                          <span className="dot-char">{char}</span>
                        ) : (
                          <span className="dot-bullet" />
                        )
                      ) : (
                        <span className="dot-placeholder" />
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
          <div className="screen-controls">
            <button
              className="screen-toggle-vis"
              onClick={() => setShowCode(!showCode)}
              title={showCode ? 'Hide passcode' : 'Show passcode'}
              type="button"
            >
              {showCode ? <EyeOff size={16} /> : <Eye size={16} />}
            </button>
          </div>
        </div>

        {/* Keypad Grid */}
        <div className="keypad-grid">
          {[
            { num: '1', sub: '' },
            { num: '2', sub: 'ABC' },
            { num: '3', sub: 'DEF' },
            { num: '4', sub: 'GHI' },
            { num: '5', sub: 'JKL' },
            { num: '6', sub: 'MNO' },
            { num: '7', sub: 'PQRS' },
            { num: '8', sub: 'TUV' },
            { num: '9', sub: 'WXYZ' },
          ].map((keyItem) => (
            <button
              key={keyItem.num}
              type="button"
              className="keypad-btn digit-btn"
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                handleDigit(keyItem.num);
              }}
              disabled={status === 'loading' || status === 'success'}
            >
              <span className="btn-main-num">{keyItem.num}</span>
              {keyItem.sub && <span className="btn-sub-letters">{keyItem.sub}</span>}
            </button>
          ))}

          {/* Row 4: Clear, 0, Backspace */}
          <button
            type="button"
            className="keypad-btn action-key clear-btn"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              handleClear();
            }}
            disabled={status === 'loading' || status === 'success' || code.length === 0}
            title="Clear all"
          >
            <span>CLR</span>
          </button>

          <button
            type="button"
            className="keypad-btn digit-btn"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              handleDigit('0');
            }}
            disabled={status === 'loading' || status === 'success'}
          >
            <span className="btn-main-num">0</span>
            <span className="btn-sub-letters">+</span>
          </button>

          <button
            type="button"
            className="keypad-btn action-key backspace-btn"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              handleDelete();
            }}
            disabled={status === 'loading' || status === 'success' || code.length === 0}
            title="Backspace"
          >
            <Delete size={20} />
          </button>
        </div>

        {/* Submit Button */}
        <button
          type="button"
          className={`keypad-submit-btn ${mode === 'register' ? 'btn-register' : mode === 'reset' ? 'btn-reset' : 'btn-unlock'} ${
            status === 'loading' ? 'loading' : ''
          }`}
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            handleSubmit();
          }}
          disabled={status === 'loading' || status === 'success' || code.length < minDigits}
        >
          {status === 'loading' ? (
            <div className="submit-spinner" />
          ) : status === 'success' ? (
            <span>ACCESS GRANTED</span>
          ) : (
            <span>{modeInfo.submitLabel}</span>
          )}
        </button>

        {/* Footer Hint */}
        <div className="keypad-footer-hint">
          <span>Tip: You can also use your physical keyboard numpad & Enter</span>
        </div>
      </motion.div>
    </div>
  );
}
