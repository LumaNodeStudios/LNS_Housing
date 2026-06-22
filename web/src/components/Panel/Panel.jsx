import React, { useState, useEffect } from 'react';
import {
  Clock, Calendar, MapPin, Building, Zap, Droplets,
  Thermometer, Settings, Flame, Droplet, Shield, Car, Users, DollarSign, X, Power, Package, Wrench, Wind, UserPlus, Key, Shirt, Trash2, Check, MoreVertical, Crown, CreditCard, History, CalendarCheck, Palette, EyeOff, BellRing, ShieldCheck
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import './Panel.css';

const Panel = ({ data: initialData }) => {
  const [activeTab, setActiveTab] = useState('home');
  const [currentTime, setCurrentTime] = useState(new Date());
  const [showAddModal, setShowAddModal] = useState(false);
  const [newRoommateId, setNewRoommateId] = useState('');
  const [initialPermissions, setInitialPermissions] = useState({
    doors: true,
    storage: true,
    wardrobe: false,
    panel: false
  });
  const [propertyData, setPropertyData] = useState(initialData || {
    id: 1,
    name: 'Grove St',
    allowWallColors: true,
  });

  const [selectedWallColor, setSelectedWallColor] = useState(0);
  const [lockNotifications, setLockNotifications] = useState(true);
  const [privacyMode, setPrivacyMode] = useState(false);
  const [securityHistory, setSecurityHistory] = useState([]);
  const [roommates, setRoommates] = useState([]);

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

  const [customPayAmount, setCustomPayAmount] = useState('');
  const [autoPay, setAutoPay] = useState(true);
  const [rentHistory, setRentHistory] = useState([]);

  const isLockedOutTab = propertyData.focusTab === 'rent';
  const tabs = isLockedOutTab ? [
    { id: 'rent', label: 'Rent Due' }
  ] : [
    { id: 'home', label: 'Home' },
    ...(!propertyData.isApartment ? [{ id: 'security', label: 'Security' }] : []),
    { id: 'access', label: 'Access' },
    ...(propertyData.sale_type === 'rent' ? [{ id: 'rent', label: 'Rent' }] : []),
    ...(!propertyData.isApartment ? [{ id: 'settings', label: 'Settings' }] : [])
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

  const handleClose = () => {
    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/closeUI`, {
      method: 'POST',
      body: JSON.stringify({})
    });
  };

  const updateActivePropertyData = (data) => {
    if (!data) return;
    setPropertyData(data);
    if (data.wallColor !== undefined) {
      setSelectedWallColor(data.wallColor);
    }

    if (data.metadata?.security_log) {
      setSecurityHistory(data.metadata.security_log);
    } else if (data.security_log) {
      setSecurityHistory(data.security_log);
    }
    if (data.metadata?.rent_history) {
      setRentHistory(data.metadata.rent_history);
    } else if (data.rent_history) {
      setRentHistory(data.rent_history);
    }

    if (data.metadata?.auto_pay !== undefined) {
      setAutoPay(data.metadata.auto_pay !== false);
    }

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
  };

  const processPropertyData = (data) => {
    if (!data) return;
    updateActivePropertyData(data);

    if (data.focusTab) {
      setActiveTab(data.focusTab);
    } else {
      setActiveTab('home');
    }
  };

  const propertyDataRef = React.useRef(propertyData);
  useEffect(() => {
    propertyDataRef.current = propertyData;
  }, [propertyData]);

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
      } else if (action === 'updateProperties') {
        const currentProp = propertyDataRef.current;
        if (currentProp && currentProp.id) {
          const propList = Array.isArray(data) ? data : (data ? Object.values(data) : []);
          const updated = propList.find(p => p && p.id === currentProp.id);
          if (updated) {
            updateActivePropertyData(updated);
          }
        }
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

  const handlePayRent = (amount) => {
    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/payRent`, {
      method: 'POST',
      body: JSON.stringify({ propertyId: propertyData.id, amount })
    });
    setCustomPayAmount('');
  };

  const handleToggleAutoPay = () => {
    const toggle = !autoPay;
    setAutoPay(toggle);
    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/toggleAutoPay`, {
      method: 'POST',
      body: JSON.stringify({ propertyId: propertyData.id, enabled: toggle })
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

  const infoBoxes = [
    ...(!propertyData.isApartment ? [
      {
        id: 'protection',
        title: 'Protection',
        desc: 'Easily monitor locks and get notified of lockpicking attempts.',
        icon: Shield,
        actionLabel: 'Upgrade',
        targetTab: 'security'
      },
      {
        id: 'parking',
        title: 'Parking Spots',
        number: propertyData.garage ? propertyData.garage.toString() : '2',
        desc: 'This is how many parking spots you have outside of your house.',
        icon: Car
      }
    ] : []),
    {
      id: 'roommates',
      title: 'Manage Residents',
      number: roommates.filter(r => !r.isOwner).length.toString(),
      desc: 'See who has access to your house and manage their permissions.',
      icon: Users,
      actionLabel: 'Manage',
      targetTab: 'access'
    }
  ];

  const upgrades = [
    {
      id: 'security',
      title: 'Security System',
      desc: 'Upgrade locks and reinforced door frames to deter intruders.',
      icon: Shield,
      level: propertyData.metadata?.security_level || 0,
      maxLevel: 5,
      price: propertyData.securityUpgradePrice
        ? (typeof propertyData.securityUpgradePrice === 'object'
            ? (propertyData.securityUpgradePrice[(propertyData.metadata?.security_level || 0) + 1] || 10000)
            : Number(propertyData.securityUpgradePrice) * ((propertyData.metadata?.security_level || 0) + 1))
        : 10000 * ((propertyData.metadata?.security_level || 0) + 1)
    }
  ];

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
        doors: initialPermissions.doors,
        storage: initialPermissions.storage,
        wardrobe: initialPermissions.wardrobe,
        panel: initialPermissions.panel
      }
    };
    setRoommates(prev => {
      const updated = [...prev, newRoommate];
      syncPermissions(updated);
      return updated;
    });
    setNewRoommateId('');
    setInitialPermissions({
      doors: true,
      storage: true,
      wardrobe: false,
      panel: false
    });
    setShowAddModal(false);
  };

  return (
    <motion.div
      className="panel-container"
      initial={{ opacity: 0, scale: 0.97, y: 15 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.97, y: 15 }}
      transition={{ duration: 0.25, ease: 'easeOut' }}
    >
      <div className="panel-header">
        <div className="tabs-container">
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
          <button className="header-icon-btn" onClick={handleClose}>
            <Power size={18} />
          </button>
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
              transition={{ duration: 0.15 }}
            >
              <div className="home-hero-section">
                <div className="hero-content">
                  <div className="location-badge">
                    <MapPin size={12} />
                    <span>{propertyData.streetName || propertyData.label || 'Unknown'}, {propertyData.zoneName || 'Los Santos'}</span>
                  </div>
                  <h1 className="welcome-text">
                    Good evening, <br />
                    <span>{propertyData.playerName || 'Resident'}</span>
                  </h1>
                  <p className="property-type-label">{propertyData.isApartment ? 'Apartment Unit' : 'Residential Property'} • ID #{propertyData.id}</p>
                </div>
                <div className="hero-stats">
                  <div className="hero-stat-item">
                    <Clock size={18} />
                    <div className="stat-details">
                      <span className="s-label">Current Time</span>
                      <span className="s-value">{formatTime(currentTime)}</span>
                    </div>
                  </div>
                  <div className="hero-stat-item">
                    <Calendar size={18} />
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
                    <div key={box.id} className="modern-info-card">
                      <div className="card-icon-wrapper">
                        <box.icon size={20} />
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
              transition={{ duration: 0.15 }}
            >
              <div className="tab-header-block">
                <h1 className="tab-title">Security & Protection</h1>
                <p className="tab-subtitle">Monitor and upgrade your property's security systems.</p>
              </div>

              <div className="security-main-grid">
                <div className="security-upgrades-col">
                  <h3 className="sub-section-title">System Upgrades</h3>
                  <div className="upgrades-list" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                    {upgrades.map((upgrade) => (
                      <div key={upgrade.id} className="upgrade-card-new">
                        <div className="upgrade-icon-box">
                          <upgrade.icon size={20} />
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

                <div className="security-history-col">
                  <div className="history-header">
                    <History size={16} />
                    <h3>Security Log</h3>
                  </div>
                  <div className="history-scroll-list">
                    {securityHistory.length > 0 ? (
                      securityHistory.map((event, idx) => (
                        <div key={event.id || idx} className="history-log-item">
                          <div className="log-icon-box" style={{ backgroundColor: `${event.color || '#3b82f6'}15`, color: event.color || '#3b82f6' }}>
                            {event.icon ? <event.icon size={16} /> : <Shield size={16} />}
                          </div>
                          <div className="log-details">
                            <div className="log-row">
                              <span className="log-title">{event.title || 'Security Event'}</span>
                              <span className="log-date">{event.date}</span>
                            </div>
                            <p className="log-desc">{event.desc}</p>
                            {event.time && <span className="log-time">{event.time}</span>}
                          </div>
                        </div>
                      ))
                    ) : (
                      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', opacity: 0.4, gap: '8px' }}>
                        <ShieldCheck size={32} />
                        <span style={{ fontSize: '11px' }}>System fully secured</span>
                      </div>
                    )}
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
              transition={{ duration: 0.15 }}
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
                  <UserPlus size={14} /> <span>Add Resident</span>
                </button>
              </div>

              <div className="residents-grid">
                {roommates.map((person) => (
                  <div key={person.id} className="resident-card">
                    <div className="resident-top">
                      <div className="resident-avatar">
                        <Users size={16} />
                      </div>
                      <div className="resident-main">
                        <div className="name-row">
                          <span className="resident-name">{person.name}</span>
                          {person.isOwner && <span className="owner-badge"><Crown size={8} /> OWNER</span>}
                        </div>
                        <span className="resident-cid">{person.citizenid}</span>
                      </div>
                      {!person.isOwner && (
                        <button
                          className="remove-resident-btn"
                          onClick={() => handleDeleteRoommate(person.id)}
                        >
                          <Trash2 size={14} />
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
                          <Key size={12} /> Doors
                        </button>
                        <button
                          className={`perm-toggle-btn ${person.permissions.storage ? 'active' : ''}`}
                          onClick={() => handleTogglePermission(person.id, 'storage')}
                          disabled={person.isOwner}
                        >
                          <Package size={12} /> Storage
                        </button>
                        <button
                          className={`perm-toggle-btn ${person.permissions.wardrobe ? 'active' : ''}`}
                          onClick={() => handleTogglePermission(person.id, 'wardrobe')}
                          disabled={person.isOwner}
                        >
                          <Shirt size={12} /> Wardrobe
                        </button>
                        <button
                          className={`perm-toggle-btn ${person.permissions.panel ? 'active' : ''}`}
                          onClick={() => handleTogglePermission(person.id, 'panel')}
                          disabled={person.isOwner}
                        >
                          <Settings size={12} /> Panel
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
              transition={{ duration: 0.15 }}
            >
              <div className="tab-header-block">
                <h1 className="tab-title">Rental & Finance</h1>
                <p className="tab-subtitle">Manage your property payments and lease history.</p>
              </div>

              <div className="rent-content-new">
                <div className="rent-summary-side">
                  {propertyData.metadata?.rent_debt > 0 && (
                    <div className="rent-debt-alert">
                      <h4 style={{ margin: 0, fontWeight: 700, fontSize: '13px' }}>Outstanding Debt: ${propertyData.metadata.rent_debt.toLocaleString()}</h4>
                      <p style={{ margin: '4px 0 0 0', fontSize: '11px', opacity: 0.85 }}>
                        Missed payments: {propertyData.metadata.missed_payments || 0}. Lockout: {propertyData.metadata.due_by ? (Math.floor(Date.now() / 1000) > propertyData.metadata.due_by ? "ACTIVE" : new Date(propertyData.metadata.due_by * 1000).toLocaleDateString()) : "Pending"}.
                      </p>
                    </div>
                  )}

                  <div className="rent-overview-card">
                    <div className="overview-header">
                      <CreditCard size={16} />
                      <h3>Payment Overview</h3>
                    </div>
                    <div className="overview-stats">
                      <div className="o-stat">
                        <span className="o-label">Rent Amount</span>
                        <span className="o-value">${(propertyData.metadata?.rent_amount || propertyData.price || 1000).toLocaleString()}</span>
                      </div>
                      <div className="o-stat highlight">
                        <span className="o-label">{propertyData.metadata?.rent_debt > 0 ? "Debt Due" : "Next Cycle Due"}</span>
                        <span className="o-value" style={{ color: propertyData.metadata?.rent_debt > 0 ? 'var(--danger)' : 'var(--primary)' }}>
                          {propertyData.metadata?.due_by 
                            ? new Date(propertyData.metadata.due_by * 1000).toLocaleDateString()
                            : (propertyData.metadata?.last_rent_paid 
                              ? new Date((propertyData.metadata.last_rent_paid + 604800) * 1000).toLocaleDateString()
                              : 'Pending'
                            )
                          }
                        </span>
                      </div>
                      <div className="o-stat">
                        <span className="o-label">Total Paid to Date</span>
                        <span className="o-value" style={{ color: 'var(--success)' }}>
                          ${rentHistory.filter(h => h.status === 'Paid').reduce((sum, h) => sum + (h.amount || 0), 0).toLocaleString()}
                        </span>
                      </div>
                    </div>
                    <div className="auto-pay-row">
                      <div className="auto-pay-info">
                        <h4>Bank Auto-Pay</h4>
                        <p>Rent auto-deducted weekly</p>
                      </div>
                      <button
                        className={`modern-toggle ${autoPay ? 'active' : ''}`}
                        onClick={handleToggleAutoPay}
                      >
                        <div className="toggle-thumb" />
                      </button>
                    </div>
                    <button 
                      className="pay-now-btn-new" 
                      onClick={() => handlePayRent(propertyData.metadata?.rent_debt > 0 ? propertyData.metadata.rent_debt : (propertyData.metadata?.rent_amount || propertyData.price || 1000))}
                    >
                      {propertyData.metadata?.rent_debt > 0 ? "Pay Total Debt" : "Pay Next Cycle"}
                    </button>

                    <div className="custom-pay-section" style={{ marginTop: '0px', borderTop: '1px solid var(--border-dim)', paddingTop: '8px' }}>
                      <label style={{ fontSize: '10px', fontWeight: '700', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Custom Payment Amount</label>
                      <div style={{ display: 'flex', gap: '6px' }}>
                        <div style={{ position: 'relative', flex: 1 }}>
                          <span style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)', opacity: 0.5, fontSize: '11px', fontWeight: '700' }}>$</span>
                          <input
                            type="number"
                            placeholder="Amount"
                            value={customPayAmount}
                            onChange={(e) => setCustomPayAmount(e.target.value)}
                            style={{ width: '100%', padding: '6px 8px 6px 20px', borderRadius: '6px', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-dim)', color: '#fff', fontSize: '11px', outline: 'none' }}
                          />
                        </div>
                        <button
                          onClick={() => handlePayRent(parseFloat(customPayAmount))}
                          disabled={!customPayAmount || isNaN(customPayAmount) || parseFloat(customPayAmount) <= 0}
                          className="pay-now-btn-new"
                          style={{ margin: 0, padding: '6px 10px', fontSize: '11px', width: 'auto', flexShrink: 0 }}
                        >
                          Pay
                        </button>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="rent-history-side">
                  <div className="history-header-new">
                    <History size={16} />
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
                        {rentHistory.length > 0 ? (
                          rentHistory.map((item, idx) => (
                            <tr key={item.id || idx}>
                              <td>{item.date}</td>
                              <td>{item.type}</td>
                              <td className="amount" style={{ color: item.status === 'Paid' ? 'var(--success)' : 'var(--danger)' }}>
                                ${item.amount.toLocaleString()}
                              </td>
                              <td>
                                <span className={`status-pill ${item.status === 'Paid' ? 'live' : 'ended'}`} style={{ fontSize: '9px', padding: '2px 6px', textTransform: 'uppercase' }}>
                                  {item.status}
                                </span>
                              </td>
                            </tr>
                          ))
                        ) : (
                          <tr>
                            <td colSpan="4" style={{ textAlign: 'center', opacity: 0.4, padding: '24px', fontSize: '11px' }}>
                              No transactions on record.
                            </td>
                          </tr>
                        )}
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
              transition={{ duration: 0.15 }}
            >
              <div className="tab-header-block">
                <h1 className="tab-title">Property Settings</h1>
                <p className="tab-subtitle">Configure your home's systems and appearance.</p>
              </div>

              <div className="settings-grid">
                <div className="settings-left-col">
                  <div className="settings-section">
                    <div className="section-header-row">
                      <Shield size={16} />
                      <h3>Security & Privacy</h3>
                    </div>

                    <div className="settings-list">
                      <div className="setting-item">
                        <div className="setting-info">
                          <BellRing size={14} />
                          <div>
                            <h4>Lock Notifications</h4>
                            <p>Get alerted when someone locks or unlocks your doors.</p>
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


                </div>

                <div className="settings-right-col">
                  {propertyData.allowWallColors && (
                    <div className="settings-section design-section">
                      <div className="section-header-row">
                        <Palette size={16} />
                        <h3>Interior Design</h3>
                      </div>

                      <div className="color-picker-container">
                        <div className="picker-header">
                          <label>Wall Tint Color</label>
                          <span className="selected-color-name">
                            {WALL_COLORS.find(c => c.id === selectedWallColor)?.name || 'Default'}
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
                              {selectedWallColor === color.id && <Check size={10} />}
                            </button>
                          ))}
                        </div>
                      </div>

                      <div className="design-footer">
                        <p>Changes are applied immediately to all interior walls.</p>
                        <button className="apply-btn" onClick={() => handleWallColorChange(0)}>Reset Defaults</button>
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
              className="modal-container"
              initial={{ scale: 0.95, opacity: 0, y: 15 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.95, opacity: 0, y: 15 }}
              transition={{ type: 'spring', duration: 0.35 }}
            >
              <div className="modal-header">
                <h3>Add New Resident</h3>
                <button className="close-modal" onClick={() => setShowAddModal(false)}>
                  <X size={16} />
                </button>
              </div>
              <div className="modal-body">
                <p>Enter the Citizen ID of the resident you wish to grant property permissions to.</p>
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
                  <label>Permissions Profile</label>
                  <div className="perms-grid">
                    <div
                      className={`perm-toggle ${initialPermissions.doors ? 'active' : ''}`}
                      onClick={() => setInitialPermissions(prev => ({ ...prev, doors: !prev.doors }))}
                    >
                      <Key size={12} /> Doors
                    </div>
                    <div
                      className={`perm-toggle ${initialPermissions.storage ? 'active' : ''}`}
                      onClick={() => setInitialPermissions(prev => ({ ...prev, storage: !prev.storage }))}
                    >
                      <Package size={12} /> Storage
                    </div>
                    <div
                      className={`perm-toggle ${initialPermissions.wardrobe ? 'active' : ''}`}
                      onClick={() => setInitialPermissions(prev => ({ ...prev, wardrobe: !prev.wardrobe }))}
                    >
                      <Shirt size={12} /> Wardrobe
                    </div>
                    <div
                      className={`perm-toggle ${initialPermissions.panel ? 'active' : ''}`}
                      onClick={() => setInitialPermissions(prev => ({ ...prev, panel: !prev.panel }))}
                    >
                      <Settings size={12} /> Panel
                    </div>
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button className="btn-cancel" onClick={() => setShowAddModal(false)}>Cancel</button>
                <button className="btn-confirm" onClick={handleAddRoommate}>Add Resident</button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
};

export default Panel;
