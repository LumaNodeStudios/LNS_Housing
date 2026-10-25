import React, { useState, useEffect } from 'react';
import { Plus, X, Home, MapPin, DollarSign, Database, Save, Trash2, Camera, Tag, Zap, EyeOff, ChevronLeft, ChevronRight, Maximize2, ImageOff } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import CustomSelect from '../Common/CustomSelect';
import './Creator.css';

const Creator = ({ electricityEnabled = true, shells = [] }) => {
  const shellOptions = (shells && shells.length > 0) ? shells : [
    { value: 'Standard Motel', label: 'Standard Motel', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/standardmotel_shell.png', type: 'shell' },
    { value: 'Modern Hotel', label: 'Modern Hotel', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/modernhotel_shell.png', type: 'shell' },
    { value: 'Apartment Furnished', label: 'Apartment Furnished', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/furnitured_midapart.png', type: 'shell' },
    { value: 'Apartment Unfurnished', label: 'Apartment Unfurnished', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_v16mid.png', type: 'shell' },
    { value: 'Apartment 2 Unfurnished', label: 'Apartment 2 Unfurnished', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_v16low.png', type: 'shell' },
    { value: 'Garage', label: 'Garage', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_garagem.png', type: 'shell' },
    { value: 'Office', label: 'Office', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_office1.png', type: 'shell' },
    { value: 'Store', label: 'Store', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_store1.png', type: 'shell' },
    { value: 'Warehouse', label: 'Warehouse', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_warehouse1.png', type: 'shell' },
    { value: 'Container', label: 'Container', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/container_shell.png', type: 'shell' },
    { value: '2 Floor House', label: '2 Floor House', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_michael.png', type: 'shell' },
    { value: 'House 1', label: 'House 1', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_frankaunt.png', type: 'shell' },
    { value: 'House 2', label: 'House 2', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_ranch.png', type: 'shell' },
    { value: 'House 3', label: 'House 3', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_lester.png', type: 'shell' },
    { value: 'House 4', label: 'House 4', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_trevor.png', type: 'shell' },
    { value: 'Trailer', label: 'Trailer', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_trailer.png', type: 'shell' },
    { value: 'Eclipse Penthouse 1', label: 'Eclipse Penthouse 1', previewUrl: '', type: 'ipl' },
    { value: 'Eclipse Penthouse 2', label: 'Eclipse Penthouse 2', previewUrl: '', type: 'ipl' },
    { value: 'Eclipse Penthouse 3', label: 'Eclipse Penthouse 3', previewUrl: '', type: 'ipl' }
  ];

  const [previewModalImage, setPreviewModalImage] = useState(null);
  const [formData, setFormData] = useState({
    name: 'New Property',
    type: 'Residential',
    price: 150000,
    mlo: true,
    shell: 'mlo',
    interiorId: null,
    interiorCoords: null,
    interiorCenter: null,
    roomCount: null,
    currentRoom: null,
    slots: 2,
    allowWallColors: true,
    saleType: 'direct',
    doors: [],
    zone_data: null,
    yard_zone_data: null,
    hasYard: false,
    image: null,
    entranceType: 'door',
    entranceCoords: null,
    breakerCoords: null
  });

  const currentShellOption = shellOptions.find(opt => String(opt.value) === String(formData.shell)) || shellOptions[0];
  const currentShellIndex = shellOptions.findIndex(opt => String(opt.value) === String(formData.shell));

  const handlePrevShell = () => {
    const idx = currentShellIndex <= 0 ? shellOptions.length - 1 : currentShellIndex - 1;
    setFormData(prev => ({ ...prev, shell: shellOptions[idx].value }));
  };
  const handleNextShell = () => {
    const idx = currentShellIndex >= shellOptions.length - 1 ? 0 : currentShellIndex + 1;
    setFormData(prev => ({ ...prev, shell: shellOptions[idx].value }));
  };

  const [walkMode, setWalkMode] = useState(false);

  const toggleWalkMode = (force) => {
    const next = force !== undefined ? force : !walkMode;
    setWalkMode(next);
    if (window.GetParentResourceName) {
      fetch(`https://${window.GetParentResourceName()}/setWalkMode`, {
        method: 'POST',
        body: JSON.stringify({ enabled: next })
      });
    }
  };

  const handleClose = () => {
    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/closeUI`, {
      method: 'POST',
      body: JSON.stringify({})
    });
  };

  const handleInputChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value
    }));
  };

  const handleCaptureInterior = () => {
    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/captureInterior`, {
      method: 'POST',
      body: JSON.stringify({})
    })
      .then(resp => resp.json())
      .then(data => {
        if (data && data.interiorId) {
          setFormData(prev => ({
            ...prev,
            interiorId: data.interiorId,
            interiorCoords: data.coords,
            interiorCenter: data.center,
            roomCount: data.roomCount,
            currentRoom: data.currentRoom
          }));
        }
      });
  };

  const handleCreateZone = () => {
    fetch(`https://${window.GetParentResourceName()}/createZone`, {
      method: 'POST',
      body: JSON.stringify({})
    })
      .then(resp => resp.json())
      .then(data => {
        if (data) {
          setFormData(prev => ({ ...prev, zone_data: data }));
        }
      });
  };

  const handleCreateYardZone = () => {
    fetch(`https://${window.GetParentResourceName()}/createYardZone`, {
      method: 'POST',
      body: JSON.stringify({})
    })
      .then(resp => resp.json())
      .then(data => {
        if (data) {
          setFormData(prev => ({ ...prev, yard_zone_data: data }));
        }
      });
  };

  const handleTakePhoto = () => {
    fetch(`https://${window.GetParentResourceName()}/takePhoto`, {
      method: 'POST',
      body: JSON.stringify({})
    })
      .then(resp => resp.json())
      .then(url => {
        if (url) {
          setFormData(prev => ({ ...prev, image: url }));
        }
      });
  };

  const handlePickEntranceCoords = () => {
    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/pickEntranceCoords`, {
      method: 'POST',
      body: JSON.stringify({})
    })
      .then(resp => resp.json())
      .then(coords => {
        if (coords) {
          setFormData(prev => ({ ...prev, entranceCoords: coords }));
        }
      });
  };

  const handlePickBreakerCoords = () => {
    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/pickBreakerCoords`, {
      method: 'POST',
      body: JSON.stringify({})
    })
      .then(resp => resp.json())
      .then(coords => {
        if (coords) {
          setFormData(prev => ({ ...prev, breakerCoords: coords }));
        }
      });
  };

  useEffect(() => {
    const handleMessage = (event) => {
      const { action, data } = event.data;
      if (action === 'addDoor') {
        setFormData(prev => {
          const alreadyExists = prev.doors.some(door => {
            if (data?.isDouble && door?.isDouble) {
              return door.doors?.[0]?.coords?.x === data.doors?.[0]?.coords?.x &&
                door.doors?.[0]?.coords?.y === data.doors?.[0]?.coords?.y;
            }
            if (typeof door === 'object' && typeof data === 'object' && !data.isDouble) {
              return door.coords?.x === data.coords?.x && door.coords?.y === data.coords?.y;
            }
            return door === data;
          });
          if (alreadyExists) return prev;
          return { ...prev, doors: [...prev.doors, data] };
        });
      }
      if (action === 'restoreWalkMode') {
        setWalkMode(false);
      }
    };
    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, []);

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Tab') {
        e.preventDefault();
        toggleWalkMode();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [walkMode]);

  return (
    <motion.div
      className="creator-container glass"
      style={walkMode ? { opacity: 0.15, pointerEvents: 'none', filter: 'blur(0.5px)' } : {}}
      initial={{ opacity: 0, scale: 0.9, y: 30 }}
      animate={{ opacity: walkMode ? 0.15 : 1, scale: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.9, y: 30 }}
    >
      <div className="creator-header">
        <div className="header-title-group">
          <Database className="header-icon" size={24} />
          <div className="title-texts">
            <h1>Property Creator</h1>
            <span>System Administrator Panel</span>
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <button
            className="walk-btn"
            onClick={() => toggleWalkMode()}
            title="Toggle Walk Mode - Lowers UI opacity so you can walk into properties. Press G to resume UI"
            type="button"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              background: walkMode ? 'rgba(56, 189, 248, 0.3)' : 'rgba(56, 189, 248, 0.12)',
              border: '1px solid rgba(56, 189, 248, 0.35)',
              color: '#38bdf8',
              padding: '6px 12px',
              borderRadius: '6px',
              fontSize: '11px',
              fontWeight: 600,
              cursor: 'pointer',
              transition: 'all 0.2s'
            }}
          >
            <EyeOff size={13} />
            <span>Walk Mode <small style={{ opacity: 0.7 }}>(G to resume)</small></span>
          </button>
          <button className="close-btn" onClick={handleClose}><X size={20} /></button>
        </div>
      </div>

      <div className="creator-content">
        <div className="creator-section">
          <h3 className="section-subtitle">Basic Information</h3>
          <div className="input-group">
            <div className="input-field">
              <label><Home size={14} /> Property Name</label>
              <input
                name="name"
                value={formData.name}
                onChange={handleInputChange}
                placeholder="e.g. 124 Vinewood Hills"
              />
            </div>
            <div className="input-field">
              <label><Database size={14} /> Property Type</label>
              <select name="type" value={formData.type === 'Commerce' ? 'Commercial' : (formData.type || 'Residential')} onChange={handleInputChange}>
                <option value="Residential">Residential</option>
                <option value="Commercial">Commercial</option>
                <option value="Industrial">Industrial</option>
                <option value="Apartment">Apartment</option>
              </select>
            </div>
          </div>

          <div className="input-field" style={{ marginTop: '15px' }}>
            <label><Camera size={14} /> Property Image</label>
            <div className="photo-capture-container glass-heavy">
              {formData.image ? (
                <div className="photo-preview">
                  <img src={formData.image} alt="Property Preview" />
                  <button className="remove-photo-btn" onClick={() => setFormData(prev => ({ ...prev, image: null }))}>
                    <Trash2 size={14} />
                  </button>
                </div>
              ) : (
                <div className="photo-placeholder">
                  <Camera size={32} opacity={0.3} />
                  <span>No photo taken yet</span>
                </div>
              )}
              <button className="pick-btn full-width" style={{ marginTop: '10px' }} onClick={handleTakePhoto}>
                <Camera size={14} /> {formData.image ? 'Retake Photo' : 'Take Property Photo'}
              </button>
            </div>
          </div>
        </div>

        <div className="creator-section">
          <h3 className="section-subtitle">Financials & Logistics</h3>
          <div className="input-group">
            <div className="input-field">
              <label><DollarSign size={14} /> Purchase Price</label>
              <input
                name="price"
                type="number"
                value={formData.price}
                onChange={handleInputChange}
              />
            </div>
            <div className="input-field">
              <label><Tag size={14} /> Sale Type</label>
              <select name="saleType" value={formData.saleType} onChange={handleInputChange}>
                <option value="direct">Direct Sale (Bank)</option>
                <option value="auction">Auction (Bidding)</option>
              </select>
            </div>
          </div>
          <div className="input-field" style={{ marginTop: '15px' }}>
            <label><MapPin size={14} /> Parking Slots</label>
            <input
              name="slots"
              type="number"
              value={formData.slots}
              onChange={handleInputChange}
            />
          </div>
        </div>

        <div className="creator-section">
          <h3 className="section-subtitle">Technical Details</h3>

          <div className="input-field" style={{ marginTop: '10px', marginBottom: '15px' }}>
            <label><Database size={14} /> Interior Type</label>
            <select
              name="mlo"
              value={formData.mlo ? 'true' : 'false'}
              onChange={(e) => {
                const isMlo = e.target.value === 'true';
                setFormData(prev => ({
                  ...prev,
                  mlo: isMlo,
                  shell: isMlo ? 'mlo' : 'Standard Motel'
                }));
              }}
            >
              <option value="true">MLO (Physical Map Interior)</option>
              <option value="false">Shell (Instanced Interior)</option>
            </select>
          </div>

          {!formData.mlo && (
            <>
              <div style={{ marginTop: '10px', marginBottom: '15px' }}>
                <CustomSelect
                  icon={Database}
                  label="Shell Model"
                  name="shell"
                  value={formData.shell || 'Standard Motel'}
                  options={shellOptions}
                  onChange={(e) => setFormData(prev => ({ ...prev, shell: e.target.value }))}
                />

                <div className="re-shell-preview-card" style={{ marginTop: '8px' }}>
                  {currentShellOption?.previewUrl ? (
                    <div className="re-shell-preview-media">
                      <img
                        src={currentShellOption.previewUrl}
                        alt={currentShellOption.label}
                        className="re-shell-preview-img"
                        onError={(e) => {
                          e.currentTarget.style.display = 'none';
                          const fallback = e.currentTarget.parentElement?.querySelector('.re-shell-preview-fallback');
                          if (fallback) fallback.style.display = 'flex';
                        }}
                      />
                      <div className="re-shell-preview-fallback" style={{ display: 'none' }}>
                        <ImageOff size={24} />
                        <span>Failed to load preview image</span>
                        <small className="re-shell-preview-url-text">{currentShellOption.previewUrl}</small>
                      </div>

                      <div className="re-shell-preview-overlay">
                        <div className="re-shell-preview-top">
                          <span className={`re-shell-type-pill ${currentShellOption.type || 'shell'}`}>
                            {(currentShellOption.type || 'shell').toUpperCase()}
                          </span>
                          <button
                            type="button"
                            className="re-shell-zoom-btn"
                            title="View Full Resolution"
                            onClick={() => setPreviewModalImage({ url: currentShellOption.previewUrl, title: currentShellOption.label, type: currentShellOption.type })}
                          >
                            <Maximize2 size={13} />
                          </button>
                        </div>

                        <div className="re-shell-nav-controls">
                          <button type="button" className="re-shell-nav-btn left" onClick={handlePrevShell} title="Previous Interior">
                            <ChevronLeft size={16} />
                          </button>
                          <button type="button" className="re-shell-nav-btn right" onClick={handleNextShell} title="Next Interior">
                            <ChevronRight size={16} />
                          </button>
                        </div>

                        <div className="re-shell-preview-bottom">
                          <div className="re-shell-preview-info">
                            <span className="re-shell-preview-title">{currentShellOption.label}</span>
                          </div>
                          <span className="re-shell-counter">{Math.max(1, currentShellIndex + 1)} / {shellOptions.length}</span>
                        </div>
                      </div>
                    </div>
                  ) : (
                    <div className="re-shell-preview-empty">
                      <div className="re-shell-empty-icon-wrap">
                        <Home size={24} className="re-shell-empty-icon" />
                      </div>
                      <div className="re-shell-empty-texts">
                        <span className="re-shell-empty-title">{currentShellOption?.label || 'Selected Interior'}</span>
                        <span className="re-shell-empty-desc">
                          No preview image configured. Add <code>previewUrl = "..."</code> in <code>shared/settings.lua</code>
                        </span>
                      </div>
                      <div className="re-shell-empty-nav">
                        <button type="button" className="re-shell-mini-nav-btn" onClick={handlePrevShell}>
                          <ChevronLeft size={12} /> Previous
                        </button>
                        <span className="re-shell-counter">{Math.max(1, currentShellIndex + 1)} / {shellOptions.length}</span>
                        <button type="button" className="re-shell-mini-nav-btn" onClick={handleNextShell}>
                          Next <ChevronRight size={12} />
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              <div className="input-field" style={{ marginTop: '10px', marginBottom: '15px' }}>
                <label><Database size={14} /> Entrance Type</label>
                <select
                  name="entranceType"
                  value={formData.entranceType || 'door'}
                  onChange={(e) => setFormData(prev => ({ ...prev, entranceType: e.target.value }))}
                >
                  <option value="door">Physical Door (ox_doorlock)</option>
                  <option value="coords">Standing Coordinates</option>
                </select>
              </div>
            </>
          )}

          <div className="checkbox-field glass-heavy" style={{ marginTop: '10px' }}>
            <div className="checkbox-info">
              <span className="checkbox-label">Allow Wall Colors</span>
              <span className="checkbox-desc">Enables the interior tinting system for this property.</span>
            </div>
            <input
              type="checkbox"
              name="allowWallColors"
              checked={formData.allowWallColors}
              onChange={handleInputChange}
            />
          </div>

          {(formData.mlo || formData.entranceType === 'door') ? (
            <div className="input-group" style={{ marginTop: '15px' }}>
              <div className="input-field" style={{ width: '100%' }}>
                <label><Database size={14} /> Property Doors (ox_doorlock)</label>
                <div className="doors-list-container glass-heavy">
                  {formData.doors.length === 0 ? (
                    <span className="no-doors">No doors added yet. Use "Pick Nearby" to add doors.</span>
                  ) : (
                    <div className="doors-tags">
                      {formData.doors.map((door, index) => (
                        <div key={index} className="door-tag">
                          <span>
                            {door?.isDouble
                              ? `New Double Door (${Math.floor(door.doors?.[0]?.coords?.x ?? 0)}, ${Math.floor(door.doors?.[0]?.coords?.y ?? 0)})`
                              : typeof door === 'object' && door?.coords
                                ? `New Door (${Math.floor(door.coords.x)}, ${Math.floor(door.coords.y)})`
                                : `ID: ${door}`}
                          </span>
                          <button
                            className="remove-door-btn"
                            onClick={() => setFormData(prev => ({ ...prev, doors: prev.doors.filter(d => d !== door) }))}
                          >
                            <X size={12} />
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
                <button
                  className="pick-btn full-width"
                  style={{ marginTop: '10px' }}
                  onClick={() => fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/pickDoor`)}
                >
                  <Plus size={14} /> Pick Nearby Door
                </button>
              </div>
            </div>
          ) : (
            <div className="input-field" style={{ marginTop: '15px' }}>
              <label><MapPin size={14} /> Entrance Location (Standing)</label>
              <div className="input-with-btn">
                <div className={`zone-status ${formData.entranceCoords ? 'defined' : ''}`}>
                  {formData.entranceCoords ? `Coords Defined (${Math.floor(formData.entranceCoords.x)}, ${Math.floor(formData.entranceCoords.y)}, ${Math.floor(formData.entranceCoords.z)})` : 'Not Defined'}
                </div>
                <button className="pick-btn" onClick={handlePickEntranceCoords}>
                  {formData.entranceCoords ? 'Redefine Location' : 'Set Standing Location'}
                </button>
              </div>
            </div>
          )}

          {electricityEnabled !== false && (
            <div className="input-field" style={{ marginTop: '15px' }}>
              <label><Zap size={14} /> Breaker Box Location</label>
              <div className="input-with-btn">
                <div className={`zone-status ${formData.breakerCoords ? 'defined' : ''}`}>
                  {formData.breakerCoords ? `Coords Defined (${Math.floor(formData.breakerCoords.x)}, ${Math.floor(formData.breakerCoords.y)}, ${Math.floor(formData.breakerCoords.z)})` : 'Default (Entrance)'}
                </div>
                <button className="pick-btn" onClick={handlePickBreakerCoords}>
                  {formData.breakerCoords ? 'Redefine Breaker' : 'Set Breaker Location'}
                </button>
              </div>
            </div>
          )}

          {formData.mlo && (
            <>
              <div className="input-field" style={{ marginTop: '15px' }}>
                <label><MapPin size={14} /> Interior Detection</label>
                <div className="input-with-btn">
                  <div className={`zone-status ${formData.interiorId ? 'defined' : ''}`}>
                    {formData.interiorId ? `Interior ID: #${formData.interiorId} (${formData.roomCount || 1} Rooms)` : 'Stand inside MLO & Capture'}
                  </div>
                  <button className="pick-btn" onClick={handleCaptureInterior}>
                    {formData.interiorId ? 'Recapture Interior' : 'Capture Interior'}
                  </button>
                </div>
              </div>

              <div className="checkbox-field glass-heavy" style={{ marginTop: '15px' }}>
                <div className="checkbox-info">
                  <span className="checkbox-label">Has Outside Yard</span>
                  <span className="checkbox-desc">Enables an interactive lawn/yard area that grows grass.</span>
                </div>
                <input
                  type="checkbox"
                  name="hasYard"
                  checked={formData.hasYard || false}
                  onChange={(e) => setFormData(prev => ({ ...prev, hasYard: e.target.checked }))}
                />
              </div>

              {formData.hasYard && (
                <div className="input-field" style={{ marginTop: '15px' }}>
                  <label><MapPin size={14} /> Outside Yard Zone</label>
                  <div className="input-with-btn">
                    <div className={`zone-status ${formData.yard_zone_data ? 'defined' : ''}`}>
                      {formData.yard_zone_data ? 'Yard Zone Defined' : 'Not Defined'}
                    </div>
                    <button className="pick-btn" onClick={handleCreateYardZone}>
                      {formData.yard_zone_data ? 'Redefine Yard' : 'Define Yard'}
                    </button>
                  </div>
                </div>
              )}
            </>
          )}

        </div>
      </div>

      <div className="creator-footer">
        <button className="btn btn-secondary" onClick={handleClose}><Trash2 size={16} /> Discard</button>
        <button className="btn btn-primary" onClick={() => fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/createHouse`, { method: 'POST', body: JSON.stringify(formData) })}><Save size={16} /> Create Property</button>
      </div>

      <AnimatePresence>
        {previewModalImage && (
          <div className="re-shell-lightbox-modal" onClick={() => setPreviewModalImage(null)}>
            <motion.div
              className="re-shell-lightbox-content"
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.9 }}
              transition={{ duration: 0.2 }}
              onClick={(e) => e.stopPropagation()}
            >
              <img
                src={previewModalImage.url}
                alt={previewModalImage.title}
                className="re-shell-lightbox-img"
              />
              <div className="re-shell-lightbox-bar">
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <span className={`re-shell-type-pill ${previewModalImage.type || 'shell'}`}>
                    {(previewModalImage.type || 'shell').toUpperCase()}
                  </span>
                  <span className="re-shell-lightbox-title">{previewModalImage.title}</span>
                </div>
                <button
                  type="button"
                  className="re-shell-lightbox-close"
                  onClick={() => setPreviewModalImage(null)}
                >
                  <X size={14} /> Close Preview
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </motion.div>
  );
};

export default Creator;
