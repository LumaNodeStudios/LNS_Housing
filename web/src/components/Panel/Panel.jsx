import React, { useState, useEffect } from 'react';
import {
  Clock, Calendar, MapPin, Building, Zap, Droplets,
  Thermometer, Settings, Flame, Droplet, Shield, Car, Users, DollarSign, X, Power, Package, Wrench, Wind, UserPlus, Key, Shirt, Trash2, Check, MoreVertical, Crown, CreditCard, History, CalendarCheck, Palette, EyeOff, BellRing, ShieldCheck, Navigation
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import './Panel.css';

const Panel = ({ data: initialData }) => {
  const [activeTab, setActiveTab] = useState('home');
  const [currentTime, setCurrentTime] = useState(new Date());
  const [showAddModal, setShowAddModal] = useState(false);
  const [newRoommateId, setNewRoommateId] = useState('');
  const [propertyData, setPropertyData] = useState(initialData || {
    id: 1,
    name: 'Grove St',
    allowWallColors: true,
  });

  const [selectedWallColor, setSelectedWallColor] = useState(0);
  const [lockNotifications, setLockNotifications] = useState(true);
  const [privacyMode, setPrivacyMode] = useState(false);
  const [securityHistory, setSecurityHistory] = useState([]);

  const WALL_COLORS = [
    { id: 0, name: 'White', hex: '#F1F1F1' },
    { id: 1, name: 'Light Beige', hex: '#DFD7CD' },
    { id: 2, name: 'Dark Beige', hex: '#E1BE8E' },
    { id: 3, name: 'Orange', hex: '#EBAB69' },
    { id: 4, name: 'Baby Blue', hex: '#7E9AB1' },
    { id: 5, name: 'Satin Blue', hex: '#736DD2' },
    { id: 6, name: 'Navy Blue', hex: '#38356E' },
    { id: 7, name: 'Maroon Red', hex: '#A85E53' },
    { id: 8, name: 'Red', hex: '#F13B59' },
    { id: 9, name: 'Burgundy Red', hex: '#8E4D58' },
    { id: 10, name: 'Earthy Green', hex: '#96A08A' },
    { id: 11, name: 'Dull Green', hex: '#646F69' },
    { id: 12, name: 'Purple', hex: '#473C5B' },
    { id: 13, name: 'Light Pink', hex: '#D5A6DE' },
    { id: 14, name: 'Grey', hex: '#6B6A6C' },
    { id: 15, name: 'Dark Grey', hex: '#343435' },
    { id: 16, name: 'Light Blue', hex: '#C1CDE0' },
    { id: 17, name: 'Dark Green', hex: '#023020' },
    { id: 18, name: 'Aqua Blue', hex: '#4fEDE5' },
    { id: 19, name: 'Blue', hex: '#62C1E5' },
    { id: 20, name: 'Geraldine Red', hex: '#FF7B7B' },
    { id: 21, name: 'Black', hex: '#000000' },
    { id: 22, name: 'Yellow', hex: '#FFEE8C' },
    { id: 23, name: 'Light Grey', hex: '#C0C0C0' },
    { id: 24, name: 'Forest Green', hex: '#012D21' },
    { id: 25, name: 'Pink', hex: '#E190B7' },
    { id: 26, name: 'Lime Green', hex: '#A2E783' },
    { id: 27, name: 'Green', hex: '#49862E' },
    { id: 28, name: 'Deep Red', hex: '#5E0606' },
    { id: 29, name: 'Brown', hex: '#653E21' },
    { id: 30, name: 'Tea Green', hex: '#D5F3C6' },
    { id: 31, name: 'Light Purple', hex: '#AE4BFF' },
  ];

  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentTime(new Date());
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  const formatTime = (date) => {
    return new Intl.DateTimeFormat('en-AU', {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
      timeZone: 'Australia/Sydney'
    }).format(date);
  };

  const formatDate = (date) => {
    return new Intl.DateTimeFormat('en-AU', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      timeZone: 'Australia/Sydney'
    }).format(date);
  };

  const tabs = [
    { id: 'home', label: 'Home' },
    ...(!propertyData.isApartment ? [{ id: 'security', label: 'Security' }] : []),
    { id: 'access', label: 'Access' },
    ...(!propertyData.isApartment ? [{ id: 'rent', label: 'Rent' }] : []),
    { id: 'settings', label: 'Settings' }
  ];

  const handleClose = () => {
    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/closeUI`, {
      method: 'POST',
      body: JSON.stringify({})
    });
  };

  const processPropertyData = (data) => {
    if (!data) return;
    setPropertyData(data);
    if (data.wallColor !== undefined) {
      setSelectedWallColor(data.wallColor);
    }

    if (data.security_log) setSecurityHistory(data.security_log);
    if (data.rent_history) setRentHistory(data.rent_history);

    if (data.permissions) {
      const allCids = new Set([
        ...(data.owner ? [data.owner] : []),
        ...(data.permissions.entry || []),
        ...(data.permissions.storage || []),
        ...(data.permissions.wardrobe || []),
        ...(data.permissions.manage || [])
      ]);

      const residentList = Array.from(allCids).map(cid => ({
        id: cid,
        name: cid === data.owner ? (data.ownerName || 'Owner') : (cid),
        citizenid: cid,
        isOwner: cid === data.owner,
        permissions: {
          doors: (data.permissions.entry || []).includes(cid),
          storage: (data.permissions.storage || []).includes(cid),
          wardrobe: (data.permissions.wardrobe || []).includes(cid),
          panel: (data.permissions.manage || []).includes(cid)
        }
      }));
      setRoommates(residentList);
    }

    setActiveTab('home');
  };

  useEffect(() => {
    if (initialData) {
      processPropertyData(initialData);
    }
  }, []);

  useEffect(() => {
    const handleMessage = (event) => {
      const { action, data } = event.data;
      if (action === 'openPanel') {
        processPropertyData(data);
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, []);

  const handleUpgradeSecurity = (upgradeId) => {
    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/upgradeSecurity`, {
      method: 'POST',
      body: JSON.stringify({ propertyId: propertyData.id, upgradeId })
    });
  };

  const handlePayRent = () => {
    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/payRent`, {
      method: 'POST',
      body: JSON.stringify({ propertyId: propertyData.id })
    });
  };

  const handleWallColorChange = (colorId) => {
    setSelectedWallColor(colorId);
    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/changeWallColor`, {
      method: 'POST',
      body: JSON.stringify({
        propertyId: propertyData.id,
        color: colorId
      })
    });
  };

  const handleUpdateSpawnPoint = () => {
    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/updateSpawnPoint`, {
      method: 'POST',
      body: JSON.stringify({ propertyId: propertyData.id })
    });
  };



  const infoBoxes = [
    {
      id: 'protection',
      title: 'Protection',
      desc: 'Easily monitor your house locks and get notified when someone tries to lockpick your lock.',
      icon: Shield,
      actionLabel: 'Upgrade',
      targetTab: 'security'
    },
    {
      id: 'parking',
      title: 'Parking Spots',
      number: '2',
      desc: 'This is how many parking spots you have outside of your house.',
      icon: Car
    },
    {
      id: 'roommates',
      title: 'Manage your roommates',
      number: '1',
      desc: 'See who has access to your house and manage their permissions.',
      icon: Users,
      actionLabel: 'Manage'
    }
  ];

  const upgrades = [
    {
      id: 'security',
      title: 'Security System',
      desc: 'Upgrade your locks and install reinforced door frames to deter intruders.',
      icon: Shield,
      level: propertyData.metadata?.security_level || 0,
      maxLevel: 5,
      price: 10000 * ((propertyData.metadata?.security_level || 0) + 1)
    }
  ];


  const [roommates, setRoommates] = useState([]);

  const [autoPay, setAutoPay] = useState(true);
  const [rentHistory, setRentHistory] = useState([]);

  const syncPermissions = (updatedRoommates) => {
    const entry = updatedRoommates.filter(r => r.permissions.doors).map(r => r.citizenid);
    const storage = updatedRoommates.filter(r => r.permissions.storage).map(r => r.citizenid);
    const wardrobe = updatedRoommates.filter(r => r.permissions.wardrobe).map(r => r.citizenid);
    const manage = updatedRoommates.filter(r => r.permissions.panel).map(r => r.citizenid);

    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/updateProperty`, {
      method: 'POST',
      body: JSON.stringify({
        id: propertyData.id,
        permissions: { entry, storage, wardrobe, manage }
      })
    });
  };

  const rentStats = [
    { label: 'Weekly Rent', value: '$1,250', icon: DollarSign, color: '#10b981' },
    { label: 'Next Payment', value: '18/05/2026', icon: CalendarCheck, color: '#3b82f6' },
  ];

  const handleDeleteRoommate = (id) => {
    setRoommates(prev => {
      const updated = prev.filter(r => r.id !== id);
      syncPermissions(updated);
      return updated;
    });
  };

  const handleTogglePermission = (roommateId, permission) => {
    setRoommates(prev => {
      const updated = prev.map(r => {
        if (r.id === roommateId && !r.isOwner) {
          return {
            ...r,
            permissions: {
              ...r.permissions,
              [permission]: !r.permissions[permission]
            }
          };
        }
        return r;
      });
      syncPermissions(updated);
      return updated;
    });
  };

  const handleAddRoommate = () => {
    if (!newRoommateId) return;
    const newRoommate = {
      id: Date.now(),
      name: 'New Roommate',
      citizenid: newRoommateId,
      permissions: {
        doors: true,
        storage: true,
        wardrobe: false,
        panel: false
      }
    };
    setRoommates(prev => {
      const updated = [...prev, newRoommate];
      syncPermissions(updated);
      return updated;
    });
    setNewRoommateId('');
    setShowAddModal(false);
  };

  return (
    <motion.div
      className="panel-container main-glass"
      initial={{ opacity: 0, scale: 0.98 }}
      animate={{ opacity: 1, scale: 1 }}
    >
      {/* Header with Tabs and Close */}
      <div className="panel-header">
        <div className="tabs-container glass-heavy">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              className={`nav-tab ${activeTab === tab.id ? 'active' : ''}`}
              onClick={() => setActiveTab(tab.id)}
            >
              {tab.label}
            </button>
          ))}
        </div>
        <div className="header-actions">
          <span className="close-text">Close</span>
          <button className="header-icon-btn" onClick={handleClose}><Power size={20} /></button>
        </div>
      </div>

      <div className="panel-content-area">
        <AnimatePresence mode="wait">
          {activeTab === 'home' && (
            <motion.div
              key="home"
              className="home-tab-new"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
            >
              <div className="home-hero-section">
                <div className="hero-content">
                  <div className="location-badge">
                    <MapPin size={14} />
                    <span>{propertyData.streetName || propertyData.label || 'Unknown'}, {propertyData.zoneName || 'Los Santos'}</span>
                  </div>
                  <h1 className="welcome-text">
                    Good evening, <br />
                    <span>{propertyData.playerName || 'Resident'}</span>
                  </h1>
                  <p className="property-type-label">{propertyData.isApartment ? 'Apartment Room' : 'Residential Property'} • ID #{propertyData.id}</p>
                </div>
                <div className="hero-stats">
                  <div className="hero-stat-item">
                    <Clock size={20} />
                    <div className="stat-details">
                      <span className="s-label">Current Time</span>
                      <span className="s-value">{formatTime(currentTime)}</span>
                    </div>
                  </div>
                  <div className="hero-stat-item">
                    <Calendar size={20} />
                    <div className="stat-details">
                      <span className="s-label">Current Date</span>
                      <span className="s-value">{formatDate(currentTime)}</span>
                    </div>
                  </div>
                </div>
              </div>

              <div className="home-grid-layout">
                <div className="info-cards-grid">
                  {infoBoxes.map((box) => (
                    <div key={box.id} className="modern-info-card glass-heavy">
                      <div className="card-icon-wrapper">
                        <box.icon size={24} />
                        {box.number && <span className="card-badge">{box.number}</span>}
                      </div>
                      <div className="card-body">
                        <h3>{box.title}</h3>
                        <p>{box.desc}</p>
                      </div>
                      {box.actionLabel && (
                        <button
                          className="card-action-btn"
                          onClick={() => box.targetTab && setActiveTab(box.targetTab)}
                        >
                          {box.actionLabel}
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </motion.div>
          )}

          {activeTab === 'security' && (
            <motion.div
              key="security"
              className="security-tab-layout"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
            >
              <div className="tab-header-block">
                <h1 className="tab-title">Security & Protection</h1>
                <p className="tab-subtitle">Monitor and upgrade your property's defensive systems.</p>
              </div>

              <div className="security-main-grid">
                <div className="security-upgrades-col">
                  <h3 className="sub-section-title">System Upgrades</h3>
                  <div className="upgrades-list">
                    {upgrades.map((upgrade) => (
                      <div key={upgrade.id} className="upgrade-card-new glass-heavy">
                        <div className="upgrade-icon-box">
                          <upgrade.icon size={24} />
                        </div>
                        <div className="upgrade-content">
                          <div className="upgrade-top-row">
                            <h3>{upgrade.title}</h3>
                            <span className="lvl-badge">LVL {upgrade.level}/{upgrade.maxLevel}</span>
                          </div>
                          <p>{upgrade.desc}</p>
                          <div className="upgrade-action-row">
                            <span className="price-tag">${upgrade.price.toLocaleString()}</span>
                            <button
                              className="purchase-btn"
                              disabled={upgrade.level >= upgrade.maxLevel}
                              onClick={() => handleUpgradeSecurity(upgrade.id)}
                            >
                              {upgrade.level >= upgrade.maxLevel ? 'MAXED' : 'PURCHASE'}
                            </button>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="security-history-col glass-heavy">
                  <div className="history-header">
                    <History size={18} />
                    <h3>Security Log</h3>
                  </div>
                  <div className="history-scroll-list">
                    {securityHistory.map((event) => (
                      <div key={event.id} className="history-log-item">
                        <div className="log-icon-box" style={{ backgroundColor: `${event.color}15`, color: event.color }}>
                          <event.icon size={18} />
                        </div>
                        <div className="log-details">
                          <div className="log-row">
                            <span className="log-title">{event.title}</span>
                            <span className="log-date">{event.date}</span>
                          </div>
                          <p className="log-desc">{event.desc}</p>
                          <span className="log-time">{event.time}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </motion.div>
          )}


          {activeTab === 'access' && (
            <motion.div
              key="access"
              className="access-tab-layout-new"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
            >
              <div className="access-header-new">
                <div className="tab-header-block">
                  <h1 className="tab-title">Access Control</h1>
                  <p className="tab-subtitle">Manage residents and their specific property permissions.</p>
                </div>
                <button
                  className="add-resident-btn"
                  onClick={() => setShowAddModal(true)}
                >
                  <UserPlus size={16} /> <span>Add Resident</span>
                </button>
              </div>

              <div className="residents-grid">
                {roommates.map((person) => (
                  <div key={person.id} className="resident-card glass-heavy">
                    <div className="resident-top">
                      <div className="resident-avatar">
                        <Users size={20} />
                      </div>
                      <div className="resident-main">
                        <div className="name-row">
                          <span className="resident-name">{person.name}</span>
                          {person.isOwner && <span className="owner-badge"><Crown size={10} /> OWNER</span>}
                        </div>
                        <span className="resident-cid">{person.citizenid}</span>
                      </div>
                      {!person.isOwner && (
                        <button
                          className="remove-resident-btn"
                          onClick={() => handleDeleteRoommate(person.id)}
                        >
                          <Trash2 size={16} />
                        </button>
                      )}
                    </div>

                    <div className="permissions-section">
                      <span className="perm-label">Permissions</span>
                      <div className="perm-switches">
                        <button
                          className={`perm-toggle-btn ${person.permissions.doors ? 'active' : ''}`}
                          onClick={() => handleTogglePermission(person.id, 'doors')}
                          disabled={person.isOwner}
                        >
                          <Key size={14} /> Doors
                        </button>
                        <button
                          className={`perm-toggle-btn ${person.permissions.storage ? 'active' : ''}`}
                          onClick={() => handleTogglePermission(person.id, 'storage')}
                          disabled={person.isOwner}
                        >
                          <Package size={14} /> Storage
                        </button>
                        <button
                          className={`perm-toggle-btn ${person.permissions.wardrobe ? 'active' : ''}`}
                          onClick={() => handleTogglePermission(person.id, 'wardrobe')}
                          disabled={person.isOwner}
                        >
                          <Shirt size={14} /> Wardrobe
                        </button>
                        <button
                          className={`perm-toggle-btn ${person.permissions.panel ? 'active' : ''}`}
                          onClick={() => handleTogglePermission(person.id, 'panel')}
                          disabled={person.isOwner}
                        >
                          <Settings size={14} /> Panel
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </motion.div>
          )}

          {activeTab === 'rent' && (
            <motion.div
              key="rent"
              className="rent-tab-layout-new"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
            >
              <div className="tab-header-block">
                <h1 className="tab-title">Rental & Finance</h1>
                <p className="tab-subtitle">Manage your property payments and lease history.</p>
              </div>

              <div className="rent-content-new">
                <div className="rent-summary-side">
                  <div className="rent-overview-card glass-heavy">
                    <div className="overview-header">
                      <CreditCard size={20} />
                      <h3>Payment Overview</h3>
                    </div>
                    <div className="overview-stats">
                      <div className="o-stat">
                        <span className="o-label">Weekly Rent</span>
                        <span className="o-value">$1,250</span>
                      </div>
                      <div className="o-stat highlight">
                        <span className="o-label">Next Due Date</span>
                        <span className="o-value">18/05/2026</span>
                      </div>
                    </div>
                    <div className="auto-pay-row">
                      <div className="auto-pay-info">
                        <h4>Bank Auto-Pay</h4>
                        <p>Deduct rent automatically</p>
                      </div>
                      <button
                        className={`modern-toggle ${autoPay ? 'active' : ''}`}
                        onClick={() => setAutoPay(!autoPay)}
                      >
                        <div className="toggle-thumb" />
                      </button>
                    </div>
                    <button className="pay-now-btn-new" onClick={handlePayRent}>
                      Pay Total Balance
                    </button>
                  </div>

                  <div className="rent-info-card-new glass-heavy">
                    <DollarSign size={20} />
                    <div className="info-text">
                      <h4>Total Paid</h4>
                      <p>$4,600.00 to date</p>
                    </div>
                  </div>
                </div>

                <div className="rent-history-side glass-heavy">
                  <div className="history-header-new">
                    <History size={18} />
                    <h3>Transaction History</h3>
                  </div>
                  <div className="history-table-wrapper">
                    <table className="modern-table">
                      <thead>
                        <tr>
                          <th>Date</th>
                          <th>Description</th>
                          <th>Amount</th>
                          <th>Status</th>
                        </tr>
                      </thead>
                      <tbody>
                        {rentHistory.map((item) => (
                          <tr key={item.id}>
                            <td>{item.date}</td>
                            <td>{item.type}</td>
                            <td className="amount">${item.amount.toLocaleString()}</td>
                            <td>
                              <span className={`status-pill ${item.status.toLowerCase()}`}>
                                {item.status}
                              </span>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </motion.div>
          )}

          {activeTab === 'settings' && (
            <motion.div
              key="settings"
              className="settings-tab-layout"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
            >
              <div className="tab-header-block">
                <h1 className="tab-title">Property Settings</h1>
                <p className="tab-subtitle">Configure your home's systems and appearance.</p>
              </div>

              <div className="settings-grid">
                <div className="settings-left-col">
                  {/* Security & System */}
                  <div className="settings-section glass-heavy">
                    <div className="section-header-row">
                      <h3>Security & Privacy</h3>
                    </div>

                    <div className="settings-list">
                      <div className="setting-item">
                        <div className="setting-info">
                          <BellRing size={16} />
                          <div>
                            <h4>Lock Notifications</h4>
                            <p>Get alerted when someone interacts with your locks.</p>
                          </div>
                        </div>
                        <button
                          className={`toggle-switch ${lockNotifications ? 'active' : ''}`}
                          onClick={() => setLockNotifications(!lockNotifications)}
                        >
                          <div className="toggle-thumb" />
                        </button>
                      </div>
                    </div>
                  </div>

                  {!propertyData.isApartment && (
                    <div className="settings-section glass-heavy" style={{ marginTop: '20px' }}>
                      <div className="section-header-row">
                        <MapPin size={18} className="section-icon" />
                        <h3>Spawn Point</h3>
                      </div>
                      <div className="settings-list">
                        <div className="setting-item" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: '10px' }}>
                          <div className="setting-info" style={{ width: '100%' }}>
                            <Navigation size={16} />
                            <div>
                              <h4>Custom Spawn Location</h4>
                              <p>Set the spawn location to your current position and heading.</p>
                            </div>
                          </div>
                          <button
                            type="button"
                            className="spawn-point-btn"
                            onClick={handleUpdateSpawnPoint}
                          >
                            <MapPin size={16} /> Set Spawn Point Here
                          </button>
                        </div>
                      </div>
                    </div>
                  )}
                </div>

                <div className="settings-right-col">
                  {/* Interior Design */}
                  {propertyData.allowWallColors && (
                    <div className="settings-section glass-heavy design-section">
                      <div className="section-header-row">
                        <Palette size={18} className="section-icon" />
                        <h3>Interior Design</h3>
                      </div>

                      <div className="color-picker-container">
                        <div className="picker-header">
                          <label>Wall Tint Color</label>
                          <span className="selected-color-name">
                            {WALL_COLORS.find(c => c.id === selectedWallColor)?.name}
                          </span>
                        </div>

                        <div className="color-grid">
                          {WALL_COLORS.map((color) => (
                            <button
                              key={color.id}
                              className={`color-swatch ${selectedWallColor === color.id ? 'active' : ''}`}
                              style={{ backgroundColor: color.hex }}
                              title={color.name}
                              onClick={() => handleWallColorChange(color.id)}
                            >
                              {selectedWallColor === color.id && <Check size={12} />}
                            </button>
                          ))}
                        </div>
                      </div>

                      <div className="design-footer">
                        <p>Changes are applied immediately to all interior walls.</p>
                        <button className="apply-btn">Reset Defaults</button>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
      <AnimatePresence>
        {showAddModal && (
          <motion.div
            className="modal-overlay"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            <motion.div
              className="modal-container glass-heavy"
              initial={{ scale: 0.9, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.9, opacity: 0, y: 20 }}
            >
              <div className="modal-header">
                <h3>Add New Roommate</h3>
                <button className="close-modal" onClick={() => setShowAddModal(false)}><X size={18} /></button>
              </div>
              <div className="modal-body">
                <p>Enter the Citizen ID of the person you want to add to your property.</p>
                <div className="modal-input-group">
                  <label>Citizen ID</label>
                  <input
                    type="text"
                    placeholder="e.g. ABC12345"
                    value={newRoommateId}
                    onChange={(e) => setNewRoommateId(e.target.value)}
                  />
                </div>
                <div className="permissions-selector">
                  <label>Initial Permissions</label>
                  <div className="perms-grid">
                    <div className="perm-toggle active"><Key size={14} /> Doors</div>
                    <div className="perm-toggle active"><Package size={14} /> Storage</div>
                    <div className="perm-toggle"><Shirt size={14} /> Wardrobe</div>
                    <div className="perm-toggle"><Settings size={14} /> Panel</div>
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button className="btn-cancel" onClick={() => setShowAddModal(false)}>Cancel</button>
                <button className="btn-confirm" onClick={handleAddRoommate}>Confirm & Add</button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
};

export default Panel;
