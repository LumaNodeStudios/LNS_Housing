import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  X,
  Eye,
  EyeOff,
  Check,
  Delete,
  AlertCircle,
  Lock,
  Unlock,
  RotateCcw,
  KeyRound,
  ShieldCheck
} from 'lucide-react';
import { useLocale } from '../../context/LocaleContext';
import './StorageKeypad.css';

const PASSCODE_LENGTH = 4;

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
  const { t } = useLocale();
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

  const isFridge = data?.isFridge || false;
  const title = data?.title || (isFridge ? t('ui.refrigerator', 'Refrigerator') : t('ui.storage_unit', 'Storage Unit'));
  const canReset = data?.canReset || false;

  const handleDigit = (digit) => {
    if (statusRef.current === 'loading' || statusRef.current === 'success') return;
    if (codeRef.current.length >= PASSCODE_LENGTH) return;
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

    if (codeRef.current.length < PASSCODE_LENGTH) {
      setStatus('error');
      setErrorMessage(t('ui.passcode_4_digits', 'Enter 4 digits'));
      setShake(true);
      setTimeout(() => setShake(false), 450);
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
      }, 450);
    } else {
      setStatus('error');
      setErrorMessage(res?.message || t('ui.incorrect_passcode', 'Incorrect passcode'));
      setShake(true);
      setTimeout(() => {
        setShake(false);
        setCode('');
      }, 600);
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
      } else if (e.key === 'Delete') {
        e.preventDefault();
        handleClear();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const getModeInfo = () => {
    switch (mode) {
      case 'register':
        return {
          badge: t('ui.set_passcode', 'SET PASSCODE'),
          badgeClass: 'badge-register',
          subtitle: t('ui.set_passcode_sub', 'Create a 4-digit passcode to secure this storage'),
          submitLabel: t('ui.register_passcode_btn', 'SET PASSCODE'),
          icon: <ShieldCheck size={18} />,
          submitIcon: <ShieldCheck size={16} />,
        };
      case 'reset':
        return {
          badge: t('ui.reset_passcode', 'RESET PASSCODE'),
          badgeClass: 'badge-reset',
          subtitle: t('ui.reset_passcode_sub', 'Enter a new 4-digit passcode for this storage'),
          submitLabel: t('ui.save_passcode_btn', 'SAVE NEW PASSCODE'),
          icon: <KeyRound size={18} />,
          submitIcon: <KeyRound size={16} />,
        };
      case 'unlock':
      default:
        return {
          badge: t('ui.locked', 'LOCKED'),
          badgeClass: 'badge-locked',
          subtitle: t('ui.enter_passcode_sub', 'Enter 4-digit passcode to unlock and open'),
          submitLabel: t('ui.unlock_storage_btn', 'UNLOCK STORAGE'),
          icon: <Lock size={18} />,
          submitIcon: <Unlock size={16} />,
        };
    }
  };

  const modeInfo = getModeInfo();

  return (
    <div className="keypad-overlay">
      <motion.div
        className={`keypad-container ${shake ? 'keypad-shake' : ''}`}
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.95 }}
        transition={{ duration: 0.18 }}
      >
        {/* Header */}
        <div className="keypad-header">
          <div className="keypad-header-left">
            <div className={`keypad-icon-box ${modeInfo.badgeClass}`}>
              {modeInfo.icon}
            </div>
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
                title={t('ui.change_passcode', 'Change passcode')}
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  setMode('reset');
                  setCode('');
                  setStatus('idle');
                  setErrorMessage('');
                }}
              >
                <RotateCcw size={13} />
                <span>{t('ui.reset', 'Reset')}</span>
              </button>
            )}

            {mode === 'reset' && (
              <button
                type="button"
                className="keypad-action-btn"
                title={t('ui.back_to_unlock', 'Back to unlock')}
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  setMode('unlock');
                  setCode('');
                  setStatus('idle');
                  setErrorMessage('');
                }}
              >
                <Lock size={13} />
                <span>{t('ui.unlock', 'Unlock')}</span>
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
              title={t('ui.close_keypad', 'Close keypad')}
            >
              <X size={16} />
            </button>
          </div>
        </div>

        {/* PIN Screen / Display */}
        <div
          className={`keypad-screen ${
            status === 'error' ? 'screen-error' : ''
          } ${status === 'success' ? 'screen-success' : ''}`}
        >
          {/* Top row with Visibility toggle */}
          <div className="screen-top-bar">
            <span className="screen-top-label">{t('ui.enter_passcode', 'ENTER PASSCODE')}</span>
            <button
              className={`screen-toggle-vis ${showCode ? 'active' : ''}`}
              onClick={() => setShowCode(!showCode)}
              title={showCode ? t('ui.hide_passcode', 'Hide passcode') : t('ui.show_passcode', 'Show passcode')}
              type="button"
            >
              {showCode ? <EyeOff size={14} /> : <Eye size={14} />}
            </button>
          </div>

          {/* Fixed 4 Slots Row */}
          <div className="screen-slots-row">
            {Array.from({ length: PASSCODE_LENGTH }).map((_, idx) => {
              const isFilled = idx < code.length;
              const isCurrent = idx === code.length && status === 'idle';
              const char = code[idx];

              let slotClass = 'screen-slot-box';
              if (status === 'success') {
                slotClass += ' success';
              } else if (status === 'error') {
                slotClass += ' error';
              } else if (isFilled) {
                slotClass += ' filled';
              } else if (isCurrent) {
                slotClass += ' current';
              } else {
                slotClass += ' empty';
              }

              return (
                <div key={idx} className={slotClass}>
                  {isFilled ? (
                    showCode ? (
                      <span className="slot-digit">{char}</span>
                    ) : (
                      <span className="slot-bullet" />
                    )
                  ) : isCurrent ? (
                    <span className="slot-cursor" />
                  ) : (
                    <span className="slot-dash" />
                  )}
                </div>
              );
            })}
          </div>

          {/* Status Feedback Message */}
          <AnimatePresence>
            {status === 'error' && (
              <motion.div
                className="screen-feedback-banner error"
                initial={{ opacity: 0, y: -2 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -2 }}
                transition={{ duration: 0.12 }}
              >
                <AlertCircle size={13} />
                <span>{errorMessage || t('ui.incorrect_passcode', 'Incorrect passcode')}</span>
              </motion.div>
            )}
            {status === 'success' && (
              <motion.div
                className="screen-feedback-banner success"
                initial={{ opacity: 0, y: -2 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -2 }}
                transition={{ duration: 0.12 }}
              >
                <Check size={13} />
                <span>
                  {mode === 'unlock'
                    ? t('ui.access_granted', 'ACCESS GRANTED')
                    : t('ui.passcode_accepted', 'PASSCODE ACCEPTED')}
                </span>
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        {/* Keypad Grid (0-9, Clear, Backspace) */}
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
            title={t('ui.clear', 'Clear')}
          >
            <span className="btn-action-text">{t('ui.clr', 'CLR')}</span>
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
            title={t('ui.backspace', 'Backspace')}
          >
            <Delete size={19} />
          </button>
        </div>

        {/* Submit Button */}
        <button
          type="button"
          className={`keypad-submit-btn ${
            mode === 'register' ? 'btn-register' : mode === 'reset' ? 'btn-reset' : 'btn-unlock'
          } ${status === 'loading' ? 'loading' : ''} ${status === 'success' ? 'success' : ''}`}
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            handleSubmit();
          }}
          disabled={status === 'loading' || status === 'success' || code.length < PASSCODE_LENGTH}
        >
          {status === 'loading' ? (
            <div className="submit-spinner" />
          ) : status === 'success' ? (
            <>
              <Check size={16} />
              <span>
                {mode === 'unlock'
                  ? t('ui.access_granted', 'ACCESS GRANTED')
                  : t('ui.passcode_accepted', 'PASSCODE ACCEPTED')}
              </span>
            </>
          ) : (
            <>
              {modeInfo.submitIcon}
              <span>{modeInfo.submitLabel}</span>
            </>
          )}
        </button>

        {/* Footer Hint */}
        <div className="keypad-footer-hint">
          <span>{t('ui.keypad_tip', 'Tip: You can also use your physical keyboard numpad & Enter')}</span>
        </div>
      </motion.div>
    </div>
  );
}
