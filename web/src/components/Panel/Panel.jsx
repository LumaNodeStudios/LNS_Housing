import React, { useState, useEffect, useRef } from 'react';
import {
  Clock, Calendar, MapPin, Settings, Shield, Car, Users, Camera, X, Power, Package,
  UserPlus, Key, Shirt, Trash2, Check, Crown, CreditCard, History, Palette, BellRing,
  ShieldCheck, AlertTriangle, Eye, ArrowRight
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import './Panel.css';
import CustomSelect from '../Common/CustomSelect';

const Panel = ({ data: initialData }) => {
  const [activeTab, setActiveTab] = useState('home');
  const [currentTime, setCurrentTime] = useState(new Date());
  const [showAddModal, setShowAddModal] = useState(false);
  const [newRoommateId, setNewRoommateId] = useState('');
  const [initialPermissions, setInitialPermissions] = useState({
    doors: true,
    storage: true,
    wardrobe: false,
    furniture: false,
    panel: false
  });
  const [propertyData, setPropertyData] = useState(initialData || {
    id: 1,
    name: 'Grove St',
    allowWallColors: true,
  });

  const [selectedWallColor, setSelectedWallColor] = useState(0);
  const [lockNotifications, setLockNotifications] = useState(true);
  const [securityHistory, setSecurityHistory] = useState([]);
  const [roommates, setRoommates] = useState([]);
  const [nearbyPlayers, setNearbyPlayers] = useState([]);
  const [modalError, setModalError] = useState('');
  const [customPayAmount, setCustomPayAmount] = useState('');
  const [autoPay, setAutoPay] = useState(true);
  const [rentHistory, setRentHistory] = useState([]);

  useEffect(() => {
    if (showAddModal && window.GetParentResourceName) {
      setModalError('');
      fetch(`https://${window.GetParentResourceName()}/getNearbyPlayers`, {
        method: 'POST',
        body: JSON.stringify({})
      })
        .then(res => res.json())
        .then(data => setNearbyPlayers(data || []))
        .catch(() => setNearbyPlayers([]));
    }
  }, [showAddModal]);

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

  const isLockedOutTab = propertyData.focusTab === 'rent';
  const tabs = isLockedOutTab ? [
    { id: 'rent', label: 'Rent Due' }
  ] : [
    { id: 'home', label: 'Overview' },
    { id: 'access', label: 'Residents' },
    ...(!propertyData.isApartment ? [{ id: 'security', label: 'Security' }] : []),
    ...(propertyData.sale_type === 'rent' ? [{ id: 'rent', label: 'Rent & Finance' }] : []),
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
        ...(data.permissions.furniture || []),
        ...(data.permissions.manage || [])
      ]);

      const residentList = Array.from(allCids).map(cid => ({
        id: cid,
        name: cid === data.owner ? (data.ownerName || 'Owner') : cid,
        citizenid: cid,
        isOwner: cid === data.owner,
        permissions: {
          doors: (data.permissions.entry || []).includes(cid),
          storage: (data.permissions.storage || []).includes(cid),
          wardrobe: (data.permissions.wardrobe || []).includes(cid),
          furniture: (data.permissions.furniture || []).includes(cid),
          panel: (data.permissions.manage || []).includes(cid)
        }
      }));
      setRoommates(residentList);

      const nonOwnerCids = Array.from(allCids).filter(cid => cid !== data.owner);
      if (nonOwnerCids.length > 0 && window.GetParentResourceName) {
        fetch(`https://${window.GetParentResourceName()}/resolveIdentifiers`, {
          method: 'POST',
          body: JSON.stringify({ citizenids: nonOwnerCids })
        })
          .then(res => res.json())
          .then(resolved => {
            if (!Array.isArray(resolved)) return;
            const nameMap = {};
            resolved.forEach(r => { if (r.citizenid) nameMap[r.citizenid] = r.name; });
            setRoommates(prev => prev.map(r =>
              r.isOwner ? r : { ...r, name: nameMap[r.citizenid] ?? r.name }
            ));
          })
          .catch(() => { });
      }
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

  const propertyDataRef = useRef(propertyData);
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
    if (upgradeId === 'doorbell_camera') {
      handleClose();
    }
    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/upgradeSecurity`, {
      method: 'POST',
      body: JSON.stringify({ propertyId: propertyData.id, upgradeId })
    });
  };

  const handleViewCamera = () => {
    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/viewDoorbellCamera`, {
      method: 'POST',
      body: JSON.stringify({ propertyId: propertyData.id })
    });
  };

  const handleRepositionCamera = () => {
    handleClose();
    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/repositionDoorbellCamera`, {
      method: 'POST',
      body: JSON.stringify({ propertyId: propertyData.id })
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

  const upgrades = [
    {
      id: 'security',
      title: 'Security System',
      desc: 'Upgrade locks and reinforced door frames to deter lockpicking attempts.',
      icon: Shield,
      level: propertyData.metadata?.security_level || 0,
      maxLevel: 5,
      price: propertyData.securityUpgradePrice
        ? (typeof propertyData.securityUpgradePrice === 'object'
          ? (propertyData.securityUpgradePrice[(propertyData.metadata?.security_level || 0) + 1] || 10000)
          : Number(propertyData.securityUpgradePrice) * ((propertyData.metadata?.security_level || 0) + 1))
        : 10000 * ((propertyData.metadata?.security_level || 0) + 1)
    },
    ...(!propertyData.isApartment ? [{
      id: 'doorbell_camera',
      title: 'Doorbell Camera',
      desc: 'Install a live front-door video camera with real-time motion detection feed.',
      icon: Camera,
      level: propertyData.metadata?.doorbell_camera ? 1 : 0,
      maxLevel: 1,
      price: propertyData.doorbellCameraPrice || 15000
    }] : [])
  ];

  const syncPermissions = (updatedRoommates) => {
    const entry = updatedRoommates.filter(r => r.permissions.doors).map(r => r.citizenid);
    const storage = updatedRoommates.filter(r => r.permissions.storage).map(r => r.citizenid);
    const wardrobe = updatedRoommates.filter(r => r.permissions.wardrobe).map(r => r.citizenid);
    const furniture = updatedRoommates.filter(r => r.permissions.furniture).map(r => r.citizenid);
    const manage = updatedRoommates.filter(r => r.permissions.panel).map(r => r.citizenid);

    fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/updateProperty`, {
      method: 'POST',
      body: JSON.stringify({
        id: propertyData.id,
        permissions: { entry, storage, wardrobe, furniture, manage }
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

  const handleAddRoommate = async () => {
    if (!newRoommateId) return;

    let resolved = null;
    if (window.GetParentResourceName) {
      try {
        const res = await fetch(`https://${window.GetParentResourceName()}/resolvePlayerByServerId`, {
          method: 'POST',
          body: JSON.stringify({ serverId: newRoommateId })
        });
        resolved = await res.json();
      } catch (err) {
        console.error("Failed to resolve player:", err);
      }
    } else {
      resolved = { success: true, citizenid: newRoommateId, name: `Player ${newRoommateId}`, serverId: newRoommateId };
    }

    if (!resolved || !resolved.success) {
      setModalError(resolved?.message || 'Failed to find player with that Server ID.');
      return;
    }

    if (resolved.citizenid && propertyData && resolved.citizenid === propertyData.owner) {
      setModalError('You cannot add yourself as a resident.');
      return;
    }

    const cid = resolved.citizenid;
    const displayName = resolved.name;

    const newRoommate = {
      id: cid,
      name: displayName,
      citizenid: cid,
      permissions: {
        doors: initialPermissions.doors,
        storage: initialPermissions.storage,
        wardrobe: initialPermissions.wardrobe,
        furniture: initialPermissions.furniture,
        panel: initialPermissions.panel
      }
    };

    setRoommates(prev => {
      const filtered = prev.filter(r => r.citizenid !== cid);
      const updated = [...filtered, newRoommate];
      syncPermissions(updated);
      return updated;
    });

    setNewRoommateId('');
    setInitialPermissions({
      doors: true,
      storage: true,
      wardrobe: false,
      furniture: false,
      panel: false
    });
    setShowAddModal(false);
  };

  return (
    <motion.div
      className="panel-container"
      initial={{ opacity: 0, scale: 0.98, y: 12 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.98, y: 12 }}
      transition={{ duration: 0.22, ease: 'easeOut' }}
    >
      {/* Top Header Navigation Bar */}
      <header className="panel-header-bar">
        {/* Left Side: Property Info & Title */}
        <div className="hdr-left">
          <div className="hdr-title-box">
            <h2 className="hdr-prop-name">{propertyData.streetName || propertyData.label || 'Property'}</h2>
            <span className="hdr-prop-sub">
              {propertyData.isApartment ? 'Apartment Unit' : 'Residential'} • #{propertyData.id || 1}
            </span>
          </div>

          {propertyData.metadata?.rent_debt > 0 ? (
            <span className="hdr-status-badge danger">Rent Overdue</span>
          ) : (
            <span className="hdr-status-badge success">{propertyData.owner ? 'Owner' : 'Resident'}</span>
          )}
        </div>

        {/* Center: Segmented Pill Tab Switcher */}
        <nav className="hdr-pill-tabs">
          {tabs.map((tab) => {
            const isActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                className={`hdr-tab-btn ${isActive ? 'active' : ''}`}
                onClick={() => setActiveTab(tab.id)}
              >
                <span>{tab.label}</span>
                {isActive && (
                  <motion.div
                    className="hdr-tab-active-bg"
                    layoutId="activeTabPill"
                    transition={{ type: 'spring', stiffness: 450, damping: 35 }}
                  />
                )}
              </button>
            );
          })}
        </nav>

        {/* Right Side: Clock & Exit Button */}
        <div className="hdr-right">
          <div className="hdr-time-display">
            <span>{formatTime(currentTime)}</span>
            <span className="hdr-date-sub">{formatDate(currentTime)}</span>
          </div>

          <button className="hdr-exit-btn" onClick={handleClose} title="Close Panel">
            <X size={16} />
          </button>
        </div>
      </header>

      {/* Main Viewport Content Area */}
      <main className="panel-content-viewport">
        <AnimatePresence mode="wait">
          {activeTab === 'home' && (
            <motion.div
              key="home"
              className="viewport-tab home-tab"
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -6 }}
              transition={{ duration: 0.15 }}
            >
              {/* 4 Stat Metric Tiles Header */}
              <div className="stats-row">
                <div className="stat-tile">
                  <span className="stat-label">Location</span>
                  <span className="stat-value">{propertyData.streetName || propertyData.label || 'Los Santos'}</span>
                </div>

                <div className="stat-tile">
                  <span className="stat-label">Property Type</span>
                  <span className="stat-value">{propertyData.isApartment ? 'Apartment Unit' : 'Residential'}</span>
                </div>

                <div className="stat-tile">
                  <span className="stat-label">Total Keyholders</span>
                  <span className="stat-value">{roommates.length} Residents</span>
                </div>

                {!propertyData.isApartment && (
                  <div className="stat-tile">
                    <span className="stat-label">Parking Spots</span>
                    <span className="stat-value">{propertyData.garage || '2'} Vehicles</span>
                  </div>
                )}
              </div>

              {/* Dual Overview Cards */}
              <div className="home-dual-grid">
                <div className="section-card">
                  <div className="card-header-bar">
                    <h3>Property Access & Keyholders</h3>
                    <button className="card-link-btn" onClick={() => setActiveTab('access')}>Manage</button>
                  </div>
                  <p className="card-desc">
                    {roommates.filter(r => !r.isOwner).length} roommate(s) hold keys to this property with customized door, storage, wardrobe, and furniture permissions.
                  </p>
                  <div className="quick-stats-pills">
                    <span className="q-pill">{roommates.length} Total Keyholders</span>
                    <span className="q-pill">{roommates.filter(r => r.permissions?.storage).length} Storage Access</span>
                  </div>
                </div>

                {!propertyData.isApartment && (
                  <div className="section-card">
                    <div className="card-header-bar">
                      <h3>Protection & Surveillance</h3>
                      <button className="card-link-btn" onClick={() => setActiveTab('security')}>Configure</button>
                    </div>
                    <p className="card-desc">
                      Current Grade: {propertyData.metadata?.security_level || 0}/5. Doorbell camera is {propertyData.metadata?.doorbell_camera ? 'Active' : 'Not Installed'}.
                    </p>
                    <div className="quick-stats-pills">
                      <span className="q-pill">Locks: Grade {propertyData.metadata?.security_level || 0}</span>
                      <span className="q-pill">Camera: {propertyData.metadata?.doorbell_camera ? 'Online' : 'Offline'}</span>
                    </div>
                  </div>
                )}

                {propertyData.sale_type === 'rent' && (
                  <div className="section-card">
                    <div className="card-header-bar">
                      <h3>Rental Payment Status</h3>
                      <button className="card-link-btn" onClick={() => setActiveTab('rent')}>Billing</button>
                    </div>
                    <p className="card-desc">
                      Weekly rent is ${(propertyData.metadata?.rent_amount || propertyData.price || 1000).toLocaleString()}.
                      {propertyData.metadata?.rent_debt > 0 ? ` Outstanding debt of $${propertyData.metadata.rent_debt.toLocaleString()}.` : ' Rent is currently up to date.'}
                    </p>
                    <div className="quick-stats-pills">
                      <span className="q-pill">Auto-Pay: {autoPay ? 'Enabled' : 'Disabled'}</span>
                      <span className={`q-pill ${propertyData.metadata?.rent_debt > 0 ? 'alert' : ''}`}>
                        {propertyData.metadata?.rent_debt > 0 ? 'Debt Overdue' : 'Lease Active'}
                      </span>
                    </div>
                  </div>
                )}
              </div>
            </motion.div>
          )}

          {activeTab === 'access' && (
            <motion.div
              key="access"
              className="viewport-tab access-tab"
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -6 }}
              transition={{ duration: 0.15 }}
            >
              <div className="section-top-bar">
                <div className="sec-titles">
                  <h2>Keyholders & Resident Permissions</h2>
                  <p>Grant or revoke specific door, storage, and furniture controls for residents.</p>
                </div>
                <button className="sec-action-btn primary" onClick={() => setShowAddModal(true)}>
                  <UserPlus size={14} />
                  <span>Add Resident</span>
                </button>
              </div>

              <div className="residents-rows-list">
                {roommates.map((person) => (
                  <div key={person.id} className="resident-row-item">
                    <div className="res-main-info">
                      <div className="res-title-row">
                        <span className="res-display-name">{person.name}</span>
                        {person.isOwner && <span className="res-owner-badge">OWNER</span>}
                      </div>
                      <span className="res-cid-sub">CID: {person.citizenid}</span>
                    </div>

                    <div className="res-perms-bar">
                      <button
                        className={`perm-pill ${person.permissions.doors ? 'active' : ''}`}
                        onClick={() => handleTogglePermission(person.id, 'doors')}
                        disabled={person.isOwner}
                      >
                        Doors
                      </button>
                      <button
                        className={`perm-pill ${person.permissions.storage ? 'active' : ''}`}
                        onClick={() => handleTogglePermission(person.id, 'storage')}
                        disabled={person.isOwner}
                      >
                        Storage
                      </button>
                      <button
                        className={`perm-pill ${person.permissions.wardrobe ? 'active' : ''}`}
                        onClick={() => handleTogglePermission(person.id, 'wardrobe')}
                        disabled={person.isOwner}
                      >
                        Wardrobe
                      </button>
                      <button
                        className={`perm-pill ${person.permissions.furniture ? 'active' : ''}`}
                        onClick={() => handleTogglePermission(person.id, 'furniture')}
                        disabled={person.isOwner}
                      >
                        Furniture
                      </button>
                      <button
                        className={`perm-pill ${person.permissions.panel ? 'active' : ''}`}
                        onClick={() => handleTogglePermission(person.id, 'panel')}
                        disabled={person.isOwner}
                      >
                        Panel
                      </button>
                    </div>

                    {!person.isOwner && (
                      <button
                        className="res-revoke-btn"
                        onClick={() => handleDeleteRoommate(person.id)}
                        title="Revoke Resident Access"
                      >
                        <Trash2 size={14} />
                      </button>
                    )}
                  </div>
                ))}
              </div>
            </motion.div>
          )}

          {activeTab === 'security' && (
            <motion.div
              key="security"
              className="viewport-tab security-tab"
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -6 }}
              transition={{ duration: 0.15 }}
            >
              <div className="security-split-grid">
                {/* Hardware Upgrades */}
                <div className="sec-column">
                  <h3 className="column-title">System Hardware & Upgrades</h3>
                  <div className="upgrades-stack">
                    {upgrades.map((upgrade) => (
                      <div key={upgrade.id} className="upg-item-card">
                        <div className="upg-item-top">
                          <div>
                            <h4>{upgrade.title}</h4>
                            <span className="upg-grade-lbl">Grade {upgrade.level}/{upgrade.maxLevel}</span>
                          </div>
                          <span className="upg-price-val">${upgrade.price.toLocaleString()}</span>
                        </div>
                        <p className="upg-desc-text">{upgrade.desc}</p>
                        <div className="upg-item-actions">
                          {upgrade.id === 'doorbell_camera' && upgrade.level >= upgrade.maxLevel ? (
                            <div className="cam-actions-row">
                              <button className="sec-action-btn secondary" onClick={handleViewCamera}>
                                <Eye size={13} /> View Live Feed
                              </button>
                              <button className="sec-action-btn secondary" onClick={handleRepositionCamera}>
                                Reposition
                              </button>
                            </div>
                          ) : (
                            <button
                              className="sec-action-btn primary"
                              disabled={upgrade.level >= upgrade.maxLevel}
                              onClick={() => handleUpgradeSecurity(upgrade.id)}
                            >
                              {upgrade.level >= upgrade.maxLevel ? 'MAX GRADE' : 'PURCHASE UPGRADE'}
                            </button>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Audit Security Log */}
                <div className="sec-column">
                  <h3 className="column-title">Security Activity Log</h3>
                  <div className="audit-log-container">
                    {securityHistory.length > 0 ? (
                      securityHistory.map((event, idx) => (
                        <div key={event.id || idx} className="audit-log-row">
                          <div className="audit-dot" style={{ backgroundColor: event.color || '#3b82f6' }} />
                          <div className="audit-details">
                            <div className="audit-row-top">
                              <span className="audit-title">{event.title || 'Security Alert'}</span>
                              <span className="audit-date">{event.date}</span>
                            </div>
                            <p className="audit-desc">{event.desc}</p>
                          </div>
                        </div>
                      ))
                    ) : (
                      <div className="audit-empty">
                        <ShieldCheck size={28} />
                        <span>System is secure. No incident history on record.</span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </motion.div>
          )}

          {activeTab === 'rent' && (
            <motion.div
              key="rent"
              className="viewport-tab rent-tab"
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -6 }}
              transition={{ duration: 0.15 }}
            >
              <div className="rent-split-grid">
                {/* Billing Payment Center */}
                <div className="rent-column">
                  {propertyData.metadata?.rent_debt > 0 && (
                    <div className="debt-alert-card">
                      <AlertTriangle size={16} />
                      <div>
                        <h4>Overdue Balance: ${propertyData.metadata.rent_debt.toLocaleString()}</h4>
                        <p>Missed payments: {propertyData.metadata.missed_payments || 0}. Pay immediately to clear lockout.</p>
                      </div>
                    </div>
                  )}

                  <div className="billing-box">
                    <h3>Payment Overview</h3>
                    <div className="b-rows-stack">
                      <div className="b-row">
                        <span>Weekly Lease Rate</span>
                        <strong>${(propertyData.metadata?.rent_amount || propertyData.price || 1000).toLocaleString()}</strong>
                      </div>
                      <div className="b-row highlight">
                        <span>{propertyData.metadata?.rent_debt > 0 ? "Outstanding Debt" : "Next Due Date"}</span>
                        <strong style={{ color: propertyData.metadata?.rent_debt > 0 ? 'var(--danger)' : 'var(--primary)' }}>
                          {propertyData.metadata?.due_by
                            ? new Date(propertyData.metadata.due_by * 1000).toLocaleDateString()
                            : (propertyData.metadata?.last_rent_paid
                              ? new Date((propertyData.metadata.last_rent_paid + 604800) * 1000).toLocaleDateString()
                              : 'Pending'
                            )
                          }
                        </strong>
                      </div>
                      <div className="b-row">
                        <span>Total Rent Paid</span>
                        <strong style={{ color: 'var(--success)' }}>
                          ${rentHistory.filter(h => h.status === 'Paid').reduce((sum, h) => sum + (h.amount || 0), 0).toLocaleString()}
                        </strong>
                      </div>
                    </div>

                    <div className="autopay-line">
                      <div>
                        <h4>Bank Auto-Deduction</h4>
                        <p>Automatically charge weekly rent to bank account</p>
                      </div>
                      <button
                        className={`toggle-switch ${autoPay ? 'active' : ''}`}
                        onClick={handleToggleAutoPay}
                      >
                        <div className="switch-dot" />
                      </button>
                    </div>

                    <button
                      className="pay-full-btn"
                      onClick={() => handlePayRent(propertyData.metadata?.rent_debt > 0 ? propertyData.metadata.rent_debt : (propertyData.metadata?.rent_amount || propertyData.price || 1000))}
                    >
                      {propertyData.metadata?.rent_debt > 0 ? "Pay Total Outstanding Debt" : "Pay Next Weekly Cycle"}
                    </button>

                    <div className="custom-pay-group">
                      <label>Custom Payment</label>
                      <div className="custom-input-row">
                        <div className="symbol-input-wrap">
                          <span>$</span>
                          <input
                            type="number"
                            placeholder="Amount"
                            value={customPayAmount}
                            onChange={(e) => setCustomPayAmount(e.target.value)}
                          />
                        </div>
                        <button
                          onClick={() => handlePayRent(parseFloat(customPayAmount))}
                          disabled={!customPayAmount || isNaN(customPayAmount) || parseFloat(customPayAmount) <= 0}
                          className="custom-submit-btn"
                        >
                          Submit
                        </button>
                      </div>
                    </div>
                  </div>
                </div>

                {/* History Table */}
                <div className="rent-column">
                  <h3 className="column-title">Payment History</h3>
                  <div className="history-table-container">
                    <table className="clean-table">
                      <thead>
                        <tr>
                          <th>Date</th>
                          <th>Type</th>
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
                              <td style={{ fontWeight: 700, color: item.status === 'Paid' ? 'var(--success)' : 'var(--danger)' }}>
                                ${item.amount.toLocaleString()}
                              </td>
                              <td>
                                <span className={`table-status-tag ${item.status === 'Paid' ? 'paid' : 'due'}`}>
                                  {item.status}
                                </span>
                              </td>
                            </tr>
                          ))
                        ) : (
                          <tr>
                            <td colSpan="4" className="empty-cell">No transactions on record.</td>
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
              className="viewport-tab settings-tab"
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -6 }}
              transition={{ duration: 0.15 }}
            >
              <div className="settings-split-grid">
                <div className="sett-column">
                  <div className="sett-card">
                    <h3>Notifications & Alerts</h3>
                    <div className="sett-toggle-item">
                      <div>
                        <h4>Lock & Door Alerts</h4>
                        <p>Receive live alerts whenever doors are locked or unlocked.</p>
                      </div>
                      <button
                        className={`toggle-switch ${lockNotifications ? 'active' : ''}`}
                        onClick={() => setLockNotifications(!lockNotifications)}
                      >
                        <div className="switch-dot" />
                      </button>
                    </div>
                  </div>
                </div>

                {propertyData.allowWallColors && (
                  <div className="sett-column">
                    <div className="sett-card">
                      <div className="palette-header-row">
                        <h3>Interior Wall Tint</h3>
                        <span className="current-color-label">
                          {WALL_COLORS.find(c => c.id === selectedWallColor)?.name || 'White'}
                        </span>
                      </div>

                      <div className="wall-swatches-grid">
                        {WALL_COLORS.map((color) => (
                          <button
                            key={color.id}
                            className={`color-swatch-btn ${selectedWallColor === color.id ? 'active' : ''}`}
                            style={{ backgroundColor: color.hex }}
                            title={color.name}
                            onClick={() => handleWallColorChange(color.id)}
                          >
                            {selectedWallColor === color.id && <Check size={11} />}
                          </button>
                        ))}
                      </div>

                      <button className="reset-tint-btn" onClick={() => handleWallColorChange(0)}>
                        Reset to Default White
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </main>

      {/* Add Resident Modal */}
      <AnimatePresence>
        {showAddModal && (
          <motion.div
            className="modal-overlay-bg"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            <motion.div
              className="modal-card"
              initial={{ scale: 0.96, opacity: 0, y: 10 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.96, opacity: 0, y: 10 }}
              transition={{ duration: 0.18, ease: 'easeOut' }}
            >
              <div className="modal-card-header">
                <h3>Add New Resident</h3>
                <button className="modal-x-btn" onClick={() => { setShowAddModal(false); setModalError(''); }}>
                  <X size={15} />
                </button>
              </div>

              <div className="modal-card-body">
                <p className="modal-info-text">Select an online player nearby or manually enter their Server ID to grant property keys.</p>

                {modalError && (
                  <div className="modal-err-banner">
                    <AlertTriangle size={14} />
                    <span>{modalError}</span>
                  </div>
                )}

                <div className="m-group">
                  <CustomSelect
                    label="Nearby Player"
                    value={newRoommateId}
                    placeholder={nearbyPlayers.length > 0 ? "Select Online Player" : "No Nearby Players Found"}
                    options={nearbyPlayers.map(p => ({
                      value: p.id,
                      label: `${p.name} (Server ID: ${p.id})`
                    }))}
                    onChange={(e) => setNewRoommateId(e.target.value)}
                  />
                </div>

                <div className="m-group">
                  <label className="m-lbl">Server ID (Manual Input)</label>
                  <input
                    type="text"
                    className="m-input"
                    placeholder="e.g. 1"
                    value={newRoommateId}
                    onChange={(e) => setNewRoommateId(e.target.value)}
                  />
                </div>

                <div className="m-group">
                  <label className="m-lbl">Initial Permissions</label>
                  <div className="m-perms-grid">
                    <button
                      className={`m-perm-chip ${initialPermissions.doors ? 'active' : ''}`}
                      onClick={() => setInitialPermissions(prev => ({ ...prev, doors: !prev.doors }))}
                    >
                      Doors
                    </button>
                    <button
                      className={`m-perm-chip ${initialPermissions.storage ? 'active' : ''}`}
                      onClick={() => setInitialPermissions(prev => ({ ...prev, storage: !prev.storage }))}
                    >
                      Storage
                    </button>
                    <button
                      className={`m-perm-chip ${initialPermissions.wardrobe ? 'active' : ''}`}
                      onClick={() => setInitialPermissions(prev => ({ ...prev, wardrobe: !prev.wardrobe }))}
                    >
                      Wardrobe
                    </button>
                    <button
                      className={`m-perm-chip ${initialPermissions.furniture ? 'active' : ''}`}
                      onClick={() => setInitialPermissions(prev => ({ ...prev, furniture: !prev.furniture }))}
                    >
                      Furniture
                    </button>
                    <button
                      className={`m-perm-chip ${initialPermissions.panel ? 'active' : ''}`}
                      onClick={() => setInitialPermissions(prev => ({ ...prev, panel: !prev.panel }))}
                    >
                      Panel
                    </button>
                  </div>
                </div>
              </div>

              <div className="modal-card-footer">
                <button className="m-btn secondary" onClick={() => setShowAddModal(false)}>Cancel</button>
                <button className="m-btn primary" onClick={handleAddRoommate}>Confirm Resident</button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
};

export default Panel;