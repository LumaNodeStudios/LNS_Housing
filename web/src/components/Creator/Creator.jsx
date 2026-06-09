import React, { useState } from 'react';
import { Plus, X, Home, MapPin, DollarSign, Database, Save, Trash2, Camera, Tag } from 'lucide-react';
import { motion } from 'framer-motion';
import './Creator.css';

const Creator = () => {
  const [formData, setFormData] = useState({
    name: 'New Property',
    type: 'Residential',
    price: 150000,
    mlo: true,
    shell: 'mlo',
    slots: 2,
    allowWallColors: true,
    saleType: 'direct',
    doors: [],
    zone_data: null,
    image: null,
    entranceType: 'door',
    entranceCoords: null
  });

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

  React.useEffect(() => {
    const handleMessage = (event) => {
      const { action, data } = event.data;
      if (action === 'addDoor') {
        setFormData(prev => {
          const alreadyExists = prev.doors.some(door => {
            if (typeof door === 'object' && typeof data === 'object') {
              return door.coords?.x === data.coords?.x && door.coords?.y === data.coords?.y;
            }
            return door === data;
          });
          if (alreadyExists) return prev;
          return { ...prev, doors: [...prev.doors, data] };
        });
      }
    };
    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, []);

  return (
    <motion.div
      className="creator-container glass"
      initial={{ opacity: 0, scale: 0.9, y: 30 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
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
        <button className="close-btn" onClick={handleClose}><X size={20} /></button>
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
              <select name="type" value={formData.type} onChange={handleInputChange}>
                <option value="Residential">Residential</option>
                <option value="Commerce">Commerce</option>
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
              <div className="input-field" style={{ marginTop: '10px', marginBottom: '15px' }}>
                <label><Database size={14} /> Shell Model</label>
                <select
                  name="shell"
                  value={formData.shell || 'Standard Motel'}
                  onChange={(e) => setFormData(prev => ({ ...prev, shell: e.target.value }))}
                >
                  <option value="Standard Motel">Standard Motel</option>
                  <option value="Modern Hotel">Modern Hotel</option>
                  <option value="Apartment Furnished">Apartment Furnished</option>
                  <option value="Apartment Unfurnished">Apartment Unfurnished</option>
                  <option value="Apartment 2 Unfurnished">Apartment 2 Unfurnished</option>
                  <option value="Garage">Garage</option>
                  <option value="Office">Office</option>
                  <option value="Store">Store</option>
                  <option value="Warehouse">Warehouse</option>
                  <option value="Container">Container</option>
                  <option value="2 Floor House">2 Floor House</option>
                  <option value="House 1">House 1</option>
                  <option value="House 2">House 2</option>
                  <option value="House 3">House 3</option>
                  <option value="House 4">House 4</option>
                  <option value="Trailer">Trailer</option>
                </select>
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
                          <span>{typeof door === 'object' ? `New Door (${Math.floor(door.coords.x)}, ${Math.floor(door.coords.y)})` : `ID: ${door}`}</span>
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

          {formData.mlo && (
            <>
              <div className="input-field" style={{ marginTop: '15px' }}>
                <label><MapPin size={14} /> Property Zone</label>
                <div className="input-with-btn">
                  <div className={`zone-status ${formData.zone_data ? 'defined' : ''}`}>
                    {formData.zone_data ? 'Zone Defined' : 'Not Defined'}
                  </div>
                  <button className="pick-btn" onClick={handleCreateZone}>
                    {formData.zone_data ? 'Redefine Zone' : 'Define Zone'}
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
        <button className="btn btn-primary" onClick={() => fetch(`https://${window.GetParentResourceName()}/createHouse`, { method: 'POST', body: JSON.stringify(formData) })}><Save size={16} /> Create Property</button>
      </div>
    </motion.div>
  );
};

export default Creator;
