import React, { useState, useEffect, useRef } from 'react';
import './CustomSelect.css';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronDown, Check, Home } from 'lucide-react';

const CustomSelect = ({ label, icon: Icon, value, options = [], onChange, name, placeholder = "Select option...", className = '' }) => {
    const [isOpen, setIsOpen] = useState(false);
    const containerRef = useRef(null);

    useEffect(() => {
        const handleClickOutside = (event) => {
            if (containerRef.current && !containerRef.current.contains(event.target)) {
                setIsOpen(false);
            }
        };
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    const selectedOption = options.find(opt => String(opt.value) === String(value));

    const handleSelect = (val) => {
        if (onChange) {
            onChange({
                target: {
                    name,
                    value: val
                }
            });
        }
        setIsOpen(false);
    };

    return (
        <div className={`re-custom-select-container ${className}`} ref={containerRef}>
            {label && (
                <label className="re-custom-select-label">
                    {Icon && <Icon size={12} />} {label}
                </label>
            )}
            <div
                className={`re-custom-select-trigger ${isOpen ? 'active' : ''}`}
                onClick={() => setIsOpen(!isOpen)}
            >
                <div className="re-custom-select-value-group">
                    {selectedOption?.previewUrl ? (
                        <img
                            src={selectedOption.previewUrl}
                            alt=""
                            className="re-custom-select-trigger-thumb"
                            onError={(e) => { e.currentTarget.style.display = 'none'; }}
                        />
                    ) : null}
                    <span className="re-custom-select-value">
                        {selectedOption ? selectedOption.label : placeholder}
                    </span>
                    {selectedOption?.type && (
                        <span className={`re-custom-select-type-tag ${selectedOption.type}`}>
                            {selectedOption.type.toUpperCase()}
                        </span>
                    )}
                </div>
                <ChevronDown size={14} className={`re-custom-select-arrow ${isOpen ? 'open' : ''}`} />
            </div>

            <AnimatePresence>
                {isOpen && (
                    <motion.div
                        className="re-custom-select-dropdown"
                        initial={{ opacity: 0, y: -8 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -8 }}
                        transition={{ duration: 0.12, ease: 'easeOut' }}
                    >
                        {options.length === 0 ? (
                            <div className="re-custom-select-option empty">
                                <span className="option-text" style={{ opacity: 0.5 }}>No options available</span>
                            </div>
                        ) : (
                            options.map((option) => (
                                <div
                                    key={option.value}
                                    className={`re-custom-select-option ${String(value) === String(option.value) ? 'selected' : ''}`}
                                    onClick={() => handleSelect(option.value)}
                                >
                                    {option.previewUrl ? (
                                        <img
                                            src={option.previewUrl}
                                            alt=""
                                            className="re-custom-select-option-thumb"
                                            onError={(e) => { e.currentTarget.style.display = 'none'; }}
                                        />
                                    ) : (option.type ? (
                                        <div className="re-custom-select-option-placeholder">
                                            <Home size={12} />
                                        </div>
                                    ) : null)}
                                    <span className="option-text">{option.label}</span>
                                    {option.type && (
                                        <span className={`re-custom-select-type-tag ${option.type}`}>
                                            {option.type.toUpperCase()}
                                        </span>
                                    )}
                                    {String(value) === String(option.value) && <Check size={12} className="option-check" />}
                                </div>
                            ))
                        )}
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
};

export default CustomSelect;
