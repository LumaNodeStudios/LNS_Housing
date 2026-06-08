import React, { useState, useEffect } from 'react';
import './RealEstate.css';
import { motion, AnimatePresence } from 'framer-motion';
import {
    Search, X, MapPin, Building, DollarSign, Navigation,
    Home, CheckCircle2, MoreVertical, Power, Tag, Warehouse,
    Clock, Maximize, Filter, Settings, Gavel, Play, Pause, Square,
    Plus, Database, Save, Trash2, Camera, FileText, Percent,
    Briefcase, UserCheck, History, UserPlus
} from 'lucide-react';

const RealEstate = ({ properties, hasPermission, initialTab, onlyBuyViaContracts }) => {
    const [filter, setFilter] = useState('all');
    const [search, setSearch] = useState('');
    const [sortBy, setSortBy] = useState('none');
    const [activeTab, setActiveTab] = useState(initialTab || 'browse');
    const [selectedProperty, setSelectedProperty] = useState(null);
    const [bidAmount, setBidAmount] = useState(0);
    const [confirmModal, setConfirmModal] = useState(null);
    const [pendingContracts, setPendingContracts] = useState([]);
    const [agencyContracts, setAgencyContracts] = useState([]);
    const [nearbyPlayers, setNearbyPlayers] = useState([]);
    const [selectedNearbyPlayer, setSelectedNearbyPlayer] = useState('');
    const [manualPlayerId, setManualPlayerId] = useState('');
    const isAgent = hasPermission && (hasPermission.allowed || hasPermission === true);
    const canCreate = hasPermission === true || (hasPermission && hasPermission.permissions?.createHouse);
    const canDraft = hasPermission === true || (hasPermission && hasPermission.permissions?.draftContract);
    const canManageListings = hasPermission === true || (hasPermission && hasPermission.permissions?.manageListings);
    const [editingPropertyId, setEditingPropertyId] = useState(null);

    const [formData, setFormData] = useState({
        name: 'New Property',
        type: 'Residential',
        price: 150000,
        mlo: true,
        slots: 2,
        allowWallColors: true,
        saleType: 'direct',
        doors: [],
        zone_data: null,
        yard_zone_data: null,
        hasYard: false,
        image: null
    });

    const [draftData, setDraftData] = useState({
        propertyId: '',
        price: '',
        type: 'buy',
        commissionRate: 10
    });

    useEffect(() => {
        if (initialTab) {
            setActiveTab(initialTab);
        }
    }, [initialTab]);

    useEffect(() => {
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

    useEffect(() => {
        if (activeTab === 'contracts') {
            fetchPendingContracts();
            if (isAgent) {
                fetchAgencyContracts();
                fetchNearbyPlayers();
            }
        }
    }, [activeTab]);

    const fetchPendingContracts = () => {
        if (!window.GetParentResourceName) {
            setPendingContracts([
                { id: 1, property_id: 1, property_label: 'Franklin House', property_image: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/3671WhispymoundDr-GTAOe.webp', price: 280000, type: 'buy', agent_name: 'John Realtor', agency: 'realestate' }
            ]);
            return;
        }
        fetch(`https://${window.GetParentResourceName()}/getPendingContracts`, {
            method: 'POST',
            body: JSON.stringify({})
        })
            .then(res => res.json())
            .then(data => {
                setPendingContracts(data || []);
            });
    };

    const fetchAgencyContracts = () => {
        if (!hasPermission || !hasPermission.job) return;
        if (!window.GetParentResourceName) {
            setAgencyContracts([
                { id: 1, property_label: 'Franklin House', client_name: 'Franklin Clinton', agent_name: 'John Realtor', type: 'buy', price: 280000, status: 'pending' }
            ]);
            return;
        }
        fetch(`https://${window.GetParentResourceName()}/getAgencyContracts`, {
            method: 'POST',
            body: JSON.stringify({ agency: hasPermission.job })
        })
            .then(res => res.json())
            .then(data => {
                setAgencyContracts(data || []);
            });
    };

    const fetchNearbyPlayers = () => {
        if (!window.GetParentResourceName) {
            setNearbyPlayers([
                { id: '1', name: 'Franklin Clinton' },
                { id: '2', name: 'Lamar Davis' }
            ]);
            return;
        }
        fetch(`https://${window.GetParentResourceName()}/getNearbyPlayers`, {
            method: 'POST',
            body: JSON.stringify({})
        })
            .then(res => res.json())
            .then(data => {
                setNearbyPlayers(data || []);
            });
    };

    const handleContractResponse = (id, action) => {
        if (!window.GetParentResourceName) {
            setPendingContracts(prev => prev.filter(c => c.id !== id));
            return;
        }
        fetch(`https://${window.GetParentResourceName()}/respondToContract`, {
            method: 'POST',
            body: JSON.stringify({ id, action })
        }).then(() => {
            fetchPendingContracts();
        });
    };

    const handleDraftContract = (e) => {
        e.preventDefault();
        const targetId = selectedNearbyPlayer || manualPlayerId;
        if (!targetId) return;

        if (!window.GetParentResourceName) {
            alert(`Contract drafted for Player ID: ${targetId}`);
            setActiveTab('browse');
            return;
        }

        fetch(`https://${window.GetParentResourceName()}/createContract`, {
            method: 'POST',
            body: JSON.stringify({
                propertyId: draftData.propertyId,
                targetId: parseInt(targetId),
                price: parseFloat(draftData.price),
                type: draftData.type,
                commissionRate: draftData.commissionRate
            })
        });

        setDraftData({
            propertyId: '',
            price: '',
            type: 'buy',
            commissionRate: hasPermission?.defaultCommission || 10
        });
        setSelectedNearbyPlayer('');
        setManualPlayerId('');
        setActiveTab('browse');
    };

    const handleStartEdit = (p) => {
        setEditingPropertyId(p.id);
        setFormData({
            name: p.label || 'New Property',
            type: p.type || 'Residential',
            price: p.price || 150000,
            mlo: true,
            slots: p.garage || 2,
            allowWallColors: p.allowWallColors !== false,
            saleType: p.sale_type || 'direct',
            doors: p.doors || [],
            zone_data: p.zone_data || null,
            yard_zone_data: p.yard_zone_data || null,
            hasYard: !!p.hasYard,
            image: p.image || null
        });
        setActiveTab('creator');
    };

    const handleUpdateProperty = () => {
        if (!window.GetParentResourceName) {
            alert(`Listing updated locally: ${formData.name}`);
            setEditingPropertyId(null);
            resetCreatorForm();
            return;
        }
        fetch(`https://${window.GetParentResourceName()}/updateListingDetails`, {
            method: 'POST',
            body: JSON.stringify({
                id: editingPropertyId,
                label: formData.name,
                price: parseFloat(formData.price),
                sale_type: formData.saleType,
                type: formData.type,
                slots: formData.slots,
                allowWallColors: formData.allowWallColors,
                doors: formData.doors,
                zone_data: formData.zone_data,
                yard_zone_data: formData.yard_zone_data,
                hasYard: formData.hasYard,
                image: formData.image
            })
        }).then(() => {
            setEditingPropertyId(null);
            resetCreatorForm();
        });
    };

    const handleDeleteListing = (id) => {
        setConfirmModal({
            title: 'Delete Listing',
            message: 'Are you sure you want to permanently delete this property listing? This action cannot be undone.',
            confirmLabel: 'Delete Listing',
            confirmColor: 'rgba(239, 68, 68, 0.2)',
            confirmBorderColor: 'rgba(239, 68, 68, 0.3)',
            confirmTextColor: '#fda4af',
            onConfirm: () => {
                if (!window.GetParentResourceName) {
                    alert(`Deleted locally: #${id}`);
                    setConfirmModal(null);
                    return;
                }
                fetch(`https://${window.GetParentResourceName()}/deleteListing`, {
                    method: 'POST',
                    body: JSON.stringify({ id })
                }).then(() => {
                    setConfirmModal(null);
                });
            }
        });
    };

    const handleEvictTenant = (id) => {
        setConfirmModal({
            title: 'Evict Tenant',
            message: 'Are you sure you want to evict the tenant and terminate the lease for this property?',
            confirmLabel: 'Evict Tenant',
            confirmColor: 'rgba(239, 68, 68, 0.2)',
            confirmBorderColor: 'rgba(239, 68, 68, 0.3)',
            confirmTextColor: '#fda4af',
            onConfirm: () => {
                if (!window.GetParentResourceName) {
                    alert(`Tenant evicted locally: #${id}`);
                    setConfirmModal(null);
                    return;
                }
                fetch(`https://${window.GetParentResourceName()}/evictTenant`, {
                    method: 'POST',
                    body: JSON.stringify({ id })
                }).then(() => {
                    setConfirmModal(null);
                });
            }
        });
    };

    const handleTerminateOwnLease = (id) => {
        setConfirmModal({
            title: 'Terminate Lease',
            message: 'Are you sure you want to move out and terminate your lease for this property?',
            confirmLabel: 'Terminate Lease',
            confirmColor: 'rgba(239, 68, 68, 0.2)',
            confirmBorderColor: 'rgba(239, 68, 68, 0.3)',
            confirmTextColor: '#fda4af',
            onConfirm: () => {
                if (!window.GetParentResourceName) {
                    alert(`Lease terminated locally: #${id}`);
                    setConfirmModal(null);
                    return;
                }
                fetch(`https://${window.GetParentResourceName()}/terminateOwnLease`, {
                    method: 'POST',
                    body: JSON.stringify({ id })
                }).then(() => {
                    fetchPendingContracts();
                    setConfirmModal(null);
                });
            }
        });
    };

    const propertyList = Object.values(properties || {});

    const filteredProperties = propertyList.filter(p => {
        const matchesSearch = p.label.toLowerCase().includes(search.toLowerCase()) ||
            (p.region && p.region.toLowerCase().includes(search.toLowerCase()));
        const isOwned = !!p.owner;

        if (filter === 'available') return matchesSearch && !isOwned;
        if (filter === 'owned') return matchesSearch && isOwned;
        return matchesSearch;
    });

    const sortedProperties = [...filteredProperties].sort((a, b) => {
        if (sortBy === 'price') return a.price - b.price;
        if (sortBy === 'size') return (b.size || 0) - (a.size || 0);
        if (sortBy === 'garage') return (b.garage || 0) - (a.garage || 0);
        return 0;
    });

    const handleAction = (p) => {
        setSelectedProperty(p);
        setBidAmount((p.auction_data?.current_bid || p.price) + 1000);
    };

    const handleBid = () => {
        if (!window.GetParentResourceName) {
            const updated = { ...properties };
            if (updated[selectedProperty.id]) {
                updated[selectedProperty.id].auction_data.current_bid = bidAmount;
                updated[selectedProperty.id].auction_data.highest_bidder = 'LocalDev';
                window.postMessage({ action: 'updateProperties', data: updated }, '*');
            }
        }

        fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/placeBid`, {
            method: 'POST',
            body: JSON.stringify({ id: selectedProperty.id, amount: bidAmount })
        });
        setSelectedProperty(null);
    };

    const handleDirectBuy = () => {
        if (!window.GetParentResourceName) {
            const updated = { ...properties };
            if (updated[selectedProperty.id]) {
                updated[selectedProperty.id].owner = 'LocalDev';
                window.postMessage({ action: 'updateProperties', data: updated }, '*');
            }
        }

        fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/buyProperty`, {
            method: 'POST',
            body: JSON.stringify({ id: selectedProperty.id, label: selectedProperty.label })
        });
        setSelectedProperty(null);
    };

    const handleAuctionControl = (id, action) => {
        if (!window.GetParentResourceName) {
            const updated = { ...properties };
            if (updated[id]) {
                if (action === 'start') updated[id].auction_data.status = 'live';
                else if (action === 'pause') updated[id].auction_data.status = 'paused';
                else if (action === 'end') updated[id].auction_data.status = 'pending';
                else if (action === 'confirm') {
                    updated[id].auction_data.status = 'ended';
                    updated[id].owner = updated[id].auction_data.highest_bidder || 'LocalDev';
                }
                window.postMessage({ action: 'updateProperties', data: updated }, '*');
            }
        }

        fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/controlAuction`, {
            method: 'POST',
            body: JSON.stringify({ id, action })
        });
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

    const handleCreateZone = () => {
        fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/createZone`, {
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
        fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/createYardZone`, {
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
        fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/takePhoto`, {
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

    const resetCreatorForm = () => {
        setFormData({
            name: 'New Property',
            type: 'Residential',
            price: 150000,
            mlo: true,
            slots: 2,
            allowWallColors: true,
            saleType: 'direct',
            doors: [],
            zone_data: null,
            yard_zone_data: null,
            hasYard: false,
            image: null
        });
        setEditingPropertyId(null);
        setActiveTab('browse');
    };

    const handleCreateProperty = () => {
        fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/createHouse`, {
            method: 'POST',
            body: JSON.stringify(formData)
        });
    };

    const renderTabContent = () => {
        switch (activeTab) {
            case 'browse':
                return sortedProperties.length > 0 ? sortedProperties.map(p => (
                    <motion.div
                        key={p.id}
                        className={`re-card-v2 glass-heavy ${p.owner ? 'owned' : ''}`}
                        initial={{ opacity: 0, y: 10 }}
                        animate={{ opacity: 1, y: 0 }}
                    >
                        <div className="re-card-image-v2">
                            {p.image ? (
                                <img src={p.image} alt={p.label} />
                            ) : (
                                <div className="image-placeholder">
                                    <Building size={48} opacity={0.1} />
                                </div>
                            )}
                            <div className="re-card-id-badge">
                                <Building size={12} />
                                <span>#{p.id} {p.label}</span>
                            </div>
                        </div>

                        <div className="re-card-details">
                            <div className="detail-item">
                                <div className="detail-label"><MapPin size={14} /> Zone</div>
                                <div className="detail-value">{p.region || 'Unknown'}</div>
                            </div>
                            <div className="detail-item">
                                <div className="detail-label"><Tag size={14} /> Type</div>
                                <div className="detail-value">{p.type || 'Residential'}</div>
                            </div>
                            <div className="detail-item">
                                <div className="detail-label"><Warehouse size={14} /> Garage Slots</div>
                                <div className="detail-value">{p.garage || 0}</div>
                            </div>
                            <div className="detail-item">
                                <div className="detail-label"><DollarSign size={14} /> Market Price</div>
                                <div className="detail-value">${(p.price || 0).toLocaleString()}</div>
                            </div>
                            {p.sale_type === 'auction' && (
                                <div className="detail-item auction-highlight">
                                    <div className="detail-label"><Gavel size={14} /> Current Bid</div>
                                    <div className="detail-value price-green">${(p.auction_data?.current_bid || p.price).toLocaleString()}</div>
                                </div>
                            )}
                            {p.sale_type === 'rent' && (
                                <div className="detail-item rent-highlight">
                                    <div className="detail-label"><Clock size={14} /> Lease Term</div>
                                    <div className="detail-value price-blue">${(p.price || 0).toLocaleString()} / period</div>
                                </div>
                            )}
                        </div>

                        <div className="re-card-footer-v2">
                            <div className="stat-box">
                                <span className="stat-label">Size</span>
                                <span className="stat-value">{p.size || 0} ft</span>
                            </div>
                            {!p.owner ? (
                                <button className="view-auction-btn" onClick={() => handleAction(p)}>
                                    {p.sale_type === 'auction' ? 'VIEW AUCTION' : 'VIEW DETAILS'}
                                </button>
                            ) : (
                                <div className="sold-badge-v2">
                                    <CheckCircle2 size={14} /> {p.sale_type === 'rent' ? 'LEASED' : 'SOLD'}
                                </div>
                            )}
                        </div>
                    </motion.div>
                )) : (
                    <div className="re-empty-state">
                        <Search size={48} />
                        <p>No properties match your criteria</p>
                    </div>
                );

            case 'management':
                return (
                    <div className="management-container glass-heavy">
                        <table className="management-table">
                            <thead>
                                <tr>
                                    <th>ID</th>
                                    <th>Label</th>
                                    <th>Sale Type</th>
                                    <th>Status</th>
                                    <th>Price/Bid</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {propertyList.map(p => (
                                    <tr key={p.id}>
                                        <td>#{p.id}</td>
                                        <td>{p.label}</td>
                                        <td>{(p.sale_type || 'direct').toUpperCase()}</td>
                                        <td>
                                            <span className={`status-pill ${p.owner ? 'owned' : (p.auction_data?.status || 'none')}`}>
                                                {p.owner ? (p.sale_type === 'rent' ? 'LEASED' : 'SOLD') : (p.auction_data?.status || 'AVAILABLE').toUpperCase()}
                                            </span>
                                        </td>
                                        <td>${(p.auction_data?.current_bid || p.price || 0).toLocaleString()}</td>
                                        <td>
                                            <div className="action-row" style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                                                {p.sale_type === 'auction' && !p.owner && canManageListings && (
                                                    <>
                                                        <button className="manage-action-btn" onClick={() => handleAuctionControl(p.id, 'start')} title="Start"><Play size={14} /></button>
                                                        <button className="manage-action-btn" onClick={() => handleAuctionControl(p.id, 'pause')} title="Pause"><Pause size={14} /></button>
                                                        <button className="manage-action-btn" onClick={() => handleAuctionControl(p.id, 'end')} title="End/Sell"><Square size={14} /></button>
                                                        {p.auction_data?.status === 'pending' && (
                                                            <button className="manage-action-btn confirm-btn" onClick={() => handleAuctionControl(p.id, 'confirm')} title="Confirm Sale"><CheckCircle2 size={14} /></button>
                                                        )}
                                                    </>
                                                )}
                                                {canManageListings && (
                                                    <>
                                                        <button className="manage-action-btn edit-btn" onClick={() => handleStartEdit(p)} title="Edit Listing"><Settings size={14} /></button>
                                                        {p.owner && (
                                                            <button className="manage-action-btn evict-btn" onClick={() => handleEvictTenant(p.id)} title="Evict/Terminate Lease"><X size={14} style={{ color: '#f43f5e' }} /></button>
                                                        )}
                                                        <button className="manage-action-btn delete-btn" onClick={() => handleDeleteListing(p.id)} title="Delete Listing"><Trash2 size={14} style={{ color: '#ef4444' }} /></button>
                                                    </>
                                                )}
                                            </div>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>


                    </div>
                );



            case 'contracts':
                return (
                    <div className="re-contracts-wrapper">
                        {isAgent ? (
                            <>
                                <div className="re-creator-col">
                                    <form className="re-creator-card" onSubmit={handleDraftContract}>
                                        <div className="re-creator-card-title">
                                            <Briefcase size={16} /> Draft New Contract
                                        </div>
                                        <div className="re-creator-inputs" style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
                                            <div className="re-creator-input-field">
                                                <label><Home size={14} /> Select Property</label>
                                                <select
                                                    required
                                                    value={draftData.propertyId}
                                                    onChange={(e) => {
                                                        const propId = e.target.value;
                                                        const p = properties[propId];
                                                        setDraftData(prev => ({
                                                            ...prev,
                                                            propertyId: propId,
                                                            price: p ? p.price : ''
                                                        }));
                                                    }}
                                                >
                                                    <option value="">-- Choose Available Property --</option>
                                                    {propertyList.filter(p => !p.owner).map(p => (
                                                        <option key={p.id} value={p.id}>
                                                            #{p.id} {p.label} (${(p.price || 0).toLocaleString()})
                                                        </option>
                                                    ))}
                                                </select>
                                            </div>

                                            <div className="re-creator-input-field">
                                                <label><Tag size={14} /> Contract Type</label>
                                                <select
                                                    value={draftData.type}
                                                    onChange={(e) => setDraftData(prev => ({ ...prev, type: e.target.value }))}
                                                >
                                                    <option value="buy">Outright Sale</option>
                                                    <option value="rent">Rental Lease</option>
                                                </select>
                                            </div>

                                            <div className="re-creator-input-field">
                                                <label><UserCheck size={14} /> Select Client (Nearby)</label>
                                                <select
                                                    value={selectedNearbyPlayer}
                                                    onChange={(e) => {
                                                        setSelectedNearbyPlayer(e.target.value);
                                                        if (e.target.value) setManualPlayerId('');
                                                    }}
                                                >
                                                    <option value="">-- Select Online Player --</option>
                                                    {nearbyPlayers.map(p => (
                                                        <option key={p.id} value={p.id}>
                                                            {p.name} (ID: {p.id})
                                                        </option>
                                                    ))}
                                                </select>
                                            </div>

                                            <div className="re-creator-input-field">
                                                <label><UserPlus size={14} /> Or Enter Client Server ID</label>
                                                <input
                                                    type="number"
                                                    placeholder="Manual Player ID"
                                                    value={manualPlayerId}
                                                    onChange={(e) => {
                                                        setManualPlayerId(e.target.value);
                                                        if (e.target.value) setSelectedNearbyPlayer('');
                                                    }}
                                                />
                                            </div>

                                            <div className="re-creator-input-field">
                                                <label><DollarSign size={14} /> Contract Value ($)</label>
                                                <input
                                                    required
                                                    type="number"
                                                    placeholder="Agreed price amount"
                                                    value={draftData.price}
                                                    onChange={(e) => setDraftData(prev => ({ ...prev, price: e.target.value }))}
                                                />
                                            </div>

                                            {canDraft && (
                                                <div className="re-creator-input-field">
                                                    <label><Percent size={14} /> Commission Rate ({draftData.commissionRate}%)</label>
                                                    <div className="slider-wrapper">
                                                        <input
                                                            type="range"
                                                            min="5"
                                                            max="50"
                                                            value={draftData.commissionRate}
                                                            onChange={(e) => setDraftData(prev => ({ ...prev, commissionRate: parseInt(e.target.value) }))}
                                                            style={{ width: '100%' }}
                                                        />
                                                    </div>
                                                </div>
                                            )}
                                        </div>

                                        {draftData.propertyId && draftData.price && (
                                            <div className="contract-payout-breakdown glass-heavy" style={{ marginTop: '15px', padding: '12px', borderRadius: '8px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                                                <div className="breakdown-title" style={{ fontWeight: '600', fontSize: '0.9rem', opacity: 0.8 }}>Payout Breakdown</div>
                                                <div className="breakdown-row" style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                                                    <span>Client Cost:</span>
                                                    <span className="price-val" style={{ fontWeight: '500' }}>${parseInt(draftData.price).toLocaleString()}</span>
                                                </div>
                                                <div className="breakdown-row" style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                                                    <span>Agent Commission ({draftData.commissionRate}%):</span>
                                                    <span className="price-green" style={{ fontWeight: '500', color: '#10b981' }}>${Math.floor(parseInt(draftData.price) * (draftData.commissionRate / 100)).toLocaleString()}</span>
                                                </div>
                                                <div className="breakdown-row total" style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem', borderTop: '1px solid rgba(255,255,255,0.1)', paddingTop: '6px', marginTop: '4px' }}>
                                                    <span>Agency Deposit:</span>
                                                    <span className="price-val" style={{ fontWeight: '600' }}>${(parseInt(draftData.price) - Math.floor(parseInt(draftData.price) * (draftData.commissionRate / 100))).toLocaleString()}</span>
                                                </div>
                                            </div>
                                        )}

                                        <button type="submit" className="re-btn-primary full-width" style={{ marginTop: '15px' }} disabled={!canDraft}>
                                            <Save size={16} /> Draft & Send Contract
                                        </button>
                                    </form>
                                </div>

                                <div className="re-creator-col">
                                    <div className="re-creator-card" style={{ maxHeight: '520px', overflowY: 'auto' }}>
                                        <div className="re-creator-card-title">
                                            <History size={16} /> Agency Contract History
                                        </div>
                                        <table className="management-table">
                                            <thead>
                                                <tr>
                                                    <th>Property</th>
                                                    <th>Client</th>
                                                    <th>Agent</th>
                                                    <th>Type</th>
                                                    <th>Price</th>
                                                    <th>Status</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                {agencyContracts.map(c => (
                                                    <tr key={c.id}>
                                                        <td>{c.property_label}</td>
                                                        <td>{c.client_name}</td>
                                                        <td>{c.agent_name}</td>
                                                        <td>{c.type.toUpperCase()}</td>
                                                        <td>${(c.price || 0).toLocaleString()}</td>
                                                        <td>
                                                            <span className={`status-pill ${c.status}`}>
                                                                {c.status.toUpperCase()}
                                                            </span>
                                                        </td>
                                                    </tr>
                                                ))}
                                                {agencyContracts.length === 0 && (
                                                    <tr>
                                                        <td colSpan="6" style={{ textAlign: 'center', padding: '20px', opacity: 0.5 }}>
                                                            No contracts on record.
                                                        </td>
                                                    </tr>
                                                )}
                                            </tbody>
                                        </table>
                                    </div>
                                </div>
                            </>
                        ) : (
                            <div className="player-contracts-container" style={{ width: '100%', padding: '10px' }}>
                                {(() => {
                                    const myActiveLeases = propertyList.filter(p => p.owner && p.owner === hasPermission?.citizenid && p.sale_type === 'rent');
                                    if (myActiveLeases.length === 0) return null;
                                    return (
                                        <div className="active-leases-section" style={{ marginBottom: '30px' }}>
                                            <div className="section-title" style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '1.1rem', fontWeight: '600', marginBottom: '15px' }}>
                                                <Home size={18} className="price-blue" /> MY ACTIVE LEASES
                                            </div>
                                            <div className="contracts-list" style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
                                                {myActiveLeases.map(p => {
                                                    const lastPaid = p.metadata?.last_rent_paid || 0;
                                                    const rentPeriod = 604800;
                                                    const timeRemaining = lastPaid > 0 ? (lastPaid + rentPeriod) - Math.floor(Date.now() / 1000) : 0;
                                                    const hoursRemaining = Math.max(0, Math.ceil(timeRemaining / 3600));
                                                    const daysRemaining = Math.max(0, Math.ceil(hoursRemaining / 24));
                                                    const isDelinquent = timeRemaining < -86400;

                                                    return (
                                                        <motion.div
                                                            key={p.id}
                                                            className={`contract-card glass-heavy rental-lease-card ${isDelinquent ? 'delinquent' : ''}`}
                                                            style={{ borderLeft: isDelinquent ? '4px solid #ef4444' : '4px solid #3b82f6', display: 'flex', gap: '15px', padding: '15px', borderRadius: '10px', background: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.05)' }}
                                                            initial={{ opacity: 0, scale: 0.98 }}
                                                            animate={{ opacity: 1, scale: 1 }}
                                                        >
                                                            <div className="contract-card-image" style={{ width: '120px', height: '80px', borderRadius: '6px', overflow: 'hidden' }}>
                                                                {p.image ? (
                                                                    <img src={p.image} alt={p.label} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                                                                ) : (
                                                                    <div className="image-placeholder" style={{ width: '100%', height: '100%', background: 'rgba(255,255,255,0.05)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                                                                        <Building size={36} opacity={0.2} />
                                                                    </div>
                                                                )}
                                                            </div>
                                                            <div className="contract-card-details" style={{ flex: 1 }}>
                                                                <div className="contract-title-row" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                                                    <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: '600' }}>{p.label}</h3>
                                                                    <span className={`contract-badge rent ${isDelinquent ? 'delinquent' : ''}`} style={{ background: isDelinquent ? 'rgba(239,68,68,0.2)' : 'rgba(59,130,246,0.2)', color: isDelinquent ? '#fca5a5' : '#93c5fd', padding: '4px 8px', borderRadius: '4px', fontSize: '0.75rem', fontWeight: '500' }}>
                                                                        {isDelinquent ? 'RENT OVERDUE (LOCKOUT)' : 'ACTIVE LEASE'}
                                                                    </span>
                                                                </div>
                                                                <p className="contract-meta" style={{ margin: '5px 0', fontSize: '0.8rem', opacity: 0.6 }}>
                                                                    Property ID: <strong>#{p.id}</strong> | Rent Period: <strong>7 Days</strong>
                                                                </p>
                                                                <div className="contract-financials" style={{ marginTop: '10px', display: 'flex', gap: '20px' }}>
                                                                    <div className="financial-box" style={{ display: 'flex', flexDirection: 'column' }}>
                                                                        <span className="fin-label" style={{ fontSize: '0.75rem', opacity: 0.5 }}>Rent Amount</span>
                                                                        <span className="fin-val" style={{ fontSize: '0.9rem', fontWeight: '600', color: '#10b981' }}>${(p.price || 0).toLocaleString()}</span>
                                                                    </div>
                                                                    <div className="financial-box" style={{ display: 'flex', flexDirection: 'column' }}>
                                                                        <span className="fin-label" style={{ fontSize: '0.75rem', opacity: 0.5 }}>Status / Time Due</span>
                                                                        <span className="fin-val" style={{ fontSize: '0.9rem', fontWeight: '600', color: isDelinquent ? '#ef4444' : (daysRemaining <= 1 ? '#f59e0b' : '#3b82f6') }}>
                                                                            {isDelinquent ? 'Overdue lockout' : (daysRemaining > 1 ? `${daysRemaining} days left` : `${hoursRemaining} hours left`)}
                                                                        </span>
                                                                    </div>
                                                                </div>
                                                                <div className="contract-actions" style={{ marginTop: '15px', display: 'flex', gap: '10px' }}>
                                                                    <button className="decline-btn" style={{ padding: '8px 16px', borderRadius: '4px', cursor: 'pointer', background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.2)', color: '#fda4af', fontSize: '0.8rem' }} onClick={() => handleTerminateOwnLease(p.id)}>
                                                                        TERMINATE LEASE
                                                                    </button>
                                                                    <button className="accept-btn" style={{ padding: '8px 16px', borderRadius: '4px', cursor: 'pointer', background: 'rgba(16, 185, 129, 0.1)', border: '1px solid rgba(16, 185, 129, 0.2)', color: '#a7f3d0', fontSize: '0.8rem' }} onClick={() => {
                                                                        if (!window.GetParentResourceName) {
                                                                            alert('Rent paid locally!');
                                                                            return;
                                                                        }
                                                                        fetch(`https://${window.GetParentResourceName()}/payRent`, {
                                                                            method: 'POST',
                                                                            body: JSON.stringify({ propertyId: p.id })
                                                                        });
                                                                    }}>
                                                                        PAY LEASE RENT
                                                                    </button>
                                                                </div>
                                                            </div>
                                                        </motion.div>
                                                    );
                                                })}
                                            </div>
                                        </div>
                                    );
                                })()}
                                <div className="section-title" style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '1.1rem', fontWeight: '600', marginBottom: '20px' }}>
                                    PENDING PROPERTY OFFERS
                                </div>
                                <div className="contracts-list" style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
                                    {pendingContracts.map(c => (
                                        <motion.div
                                            key={c.id}
                                            className="contract-card glass-heavy"
                                            initial={{ opacity: 0, scale: 0.95 }}
                                            animate={{ opacity: 1, scale: 1 }}
                                        >
                                            <div className="contract-card-image">
                                                {c.property_image ? (
                                                    <img src={c.property_image} alt={c.property_label} />
                                                ) : (
                                                    <div className="image-placeholder">
                                                        <Building size={36} opacity={0.2} />
                                                    </div>
                                                )}
                                            </div>
                                            <div className="contract-card-details">
                                                <div className="contract-title-row">
                                                    <h3>{c.property_label}</h3>
                                                    <span className={`contract-badge ${c.type}`}>
                                                        {c.type === 'rent' ? 'LEASE OFFER' : 'OUTRIGHT SALE'}
                                                    </span>
                                                </div>
                                                <p className="contract-meta">
                                                    Drafted by agent <strong>{c.agent_name}</strong> for <strong>{c.agency === 'luxuryestate' ? 'Luxury Real Estate' : 'Dynasty 8 Real Estate'}</strong>
                                                </p>
                                                <div className="contract-financials">
                                                    <div className="financial-box">
                                                        <span className="fin-label">Agreed Cost</span>
                                                        <span className="fin-val">${(c.price || 0).toLocaleString()}{c.type === 'rent' && '/period'}</span>
                                                    </div>
                                                </div>
                                                <div className="contract-actions">
                                                    <button className="decline-btn" onClick={() => handleContractResponse(c.id, 'decline')}>
                                                        DECLINE
                                                    </button>
                                                    <button className="accept-btn" onClick={() => handleContractResponse(c.id, 'accept')}>
                                                        SIGN & ACCEPT
                                                    </button>
                                                </div>
                                            </div>
                                        </motion.div>
                                    ))}
                                    {pendingContracts.length === 0 && (
                                        <div className="re-empty-state">
                                            <FileText size={48} opacity={0.3} />
                                            <p>You have no pending property contracts</p>
                                            <span style={{ fontSize: '0.85rem', opacity: 0.5 }}>Ask a real estate agent to draft an offer for you.</span>
                                        </div>
                                    )}
                                </div>
                            </div>
                        )}
                    </div>
                );

            case 'creator':
            default:
                return (
                    <div className="re-creator-wrapper">
                        {editingPropertyId && (
                            <div className="re-edit-mode-banner">
                                <span>Editing Property <strong>#{editingPropertyId}</strong></span>
                                <button className="re-edit-cancel-btn" onClick={resetCreatorForm}>
                                    <X size={14} /> Cancel Edit
                                </button>
                            </div>
                        )}
                        <div className="re-creator-col">
                            <div className="re-creator-card">
                                <div className="re-creator-card-title">
                                    {editingPropertyId ? `Editing: ${formData.name}` : 'Basic Information'}
                                </div>
                                <div className="re-creator-inputs">
                                    <div className="re-creator-input-field">
                                        <label><Building size={14} /> Property Name</label>
                                        <input
                                            name="name"
                                            value={formData.name}
                                            onChange={handleInputChange}
                                            placeholder="e.g. 124 Vinewood Hills"
                                        />
                                    </div>
                                    <div className="re-creator-input-field">
                                        <label><Database size={14} /> Property Type</label>
                                        <select name="type" value={formData.type} onChange={handleInputChange}>
                                            <option value="Residential">Residential</option>
                                            <option value="Commerce">Commerce</option>
                                            <option value="Industrial">Industrial</option>
                                            <option value="Apartment">Apartment</option>
                                        </select>
                                    </div>
                                </div>
                            </div>

                            <div className="re-creator-card">
                                <div className="re-creator-card-title">
                                    Financials & Logistics
                                </div>
                                <div className="re-creator-inputs">
                                    <div className="re-creator-input-field">
                                        <label><DollarSign size={14} /> Purchase Price</label>
                                        <input
                                            name="price"
                                            type="number"
                                            value={formData.price}
                                            onChange={handleInputChange}
                                        />
                                    </div>
                                    <div className="re-creator-input-field">
                                        <label><Tag size={14} /> Sale Type</label>
                                        <select name="saleType" value={formData.saleType} onChange={handleInputChange}>
                                            <option value="direct">Direct Sale (Bank)</option>
                                            <option value="auction">Auction (Bidding)</option>
                                        </select>
                                    </div>
                                    <div className="re-creator-input-field full-width">
                                        <label><MapPin size={14} /> Parking Slots</label>
                                        <input
                                            name="slots"
                                            type="number"
                                            value={formData.slots}
                                            onChange={handleInputChange}
                                        />
                                    </div>
                                </div>
                            </div>

                            <div className="re-creator-card">
                                <div className="re-creator-card-title">
                                    Technical Details & Options
                                </div>
                                <div className="re-creator-col" style={{ gap: '15px' }}>
                                    <div className="re-creator-checkbox-field">
                                        <div className="re-creator-checkbox-info">
                                            <span className="re-creator-checkbox-label">Allow Wall Colors</span>
                                            <span className="re-creator-checkbox-desc">Enables the interior tinting system for this property.</span>
                                        </div>
                                        <input
                                            type="checkbox"
                                            name="allowWallColors"
                                            checked={formData.allowWallColors}
                                            onChange={handleInputChange}
                                        />
                                    </div>
                                    <div className="re-creator-checkbox-field">
                                        <div className="re-creator-checkbox-info">
                                            <span className="re-creator-checkbox-label">Has Outside Yard</span>
                                            <span className="re-creator-checkbox-desc">Enables an interactive lawn/yard area that grows grass.</span>
                                        </div>
                                        <input
                                            type="checkbox"
                                            name="hasYard"
                                            checked={formData.hasYard}
                                            onChange={(e) => setFormData(prev => ({ ...prev, hasYard: e.target.checked }))}
                                        />
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div className="re-creator-col">
                            <div className="re-creator-card">
                                <div className="re-creator-card-title">
                                    Property Image
                                </div>
                                <div className="re-photo-card">
                                    <div className={`re-photo-preview-box ${formData.image ? 'has-image' : ''}`}>
                                        {formData.image ? (
                                            <img src={formData.image} alt="Property Preview" />
                                        ) : (
                                            <div className="re-photo-placeholder">
                                                <Camera size={32} opacity={0.3} />
                                                <span>No photo taken yet</span>
                                            </div>
                                        )}
                                    </div>
                                    <button className="re-btn-primary full-width" onClick={handleTakePhoto}>
                                        <Camera size={14} /> {formData.image ? 'Retake Property Photo' : 'Take Property Photo'}
                                    </button>
                                </div>
                            </div>

                            <div className="re-creator-card">
                                <div className="re-creator-card-title">
                                    Interactive Setup
                                </div>
                                <div className="re-creator-col" style={{ gap: '12px' }}>
                                    <div className="re-interactive-row">
                                        <div className="re-interactive-info">
                                            <span className="re-interactive-label">Property Zone</span>
                                            <span className={`re-interactive-status ${formData.zone_data ? 'active' : ''}`}>
                                                {formData.zone_data ? 'Zone Defined' : 'Not Defined'}
                                            </span>
                                        </div>
                                        <button className="re-btn-action" onClick={handleCreateZone}>
                                            {formData.zone_data ? 'Redefine' : 'Define'}
                                        </button>
                                    </div>

                                    {formData.hasYard && (
                                        <div className="re-interactive-row">
                                            <div className="re-interactive-info">
                                                <span className="re-interactive-label">Outside Yard Zone</span>
                                                <span className={`re-interactive-status ${formData.yard_zone_data ? 'active' : ''}`}>
                                                    {formData.yard_zone_data ? 'Yard Zone Defined' : 'Not Defined'}
                                                </span>
                                            </div>
                                            <button className="re-btn-action" onClick={handleCreateYardZone}>
                                                {formData.yard_zone_data ? 'Redefine' : 'Define'}
                                            </button>
                                        </div>
                                    )}

                                    <div className="re-creator-input-field" style={{ marginTop: '5px' }}>
                                        <label><Database size={14} /> Property Doors (ox_doorlock)</label>
                                        <div className="re-doors-list">
                                            {formData.doors.length === 0 ? (
                                                <span className="no-doors" style={{ margin: 'auto' }}>No doors added yet. Use the picker below.</span>
                                            ) : (
                                                formData.doors.map((door, index) => (
                                                    <div key={index} className="door-tag">
                                                        <span>{typeof door === 'object' ? `New Door (${Math.floor(door.coords.x)}, ${Math.floor(door.coords.y)})` : `ID: ${door}`}</span>
                                                        <button
                                                            className="remove-door-btn"
                                                            type="button"
                                                            onClick={() => setFormData(prev => ({ ...prev, doors: prev.doors.filter(d => d !== door) }))}
                                                        >
                                                            <X size={12} />
                                                        </button>
                                                    </div>
                                                ))
                                            )}
                                        </div>
                                        <button
                                            className="re-btn-primary"
                                            style={{ marginTop: '5px' }}
                                            type="button"
                                            onClick={() => fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/pickDoor`)}
                                        >
                                            <Plus size={14} /> Pick Nearby Door
                                        </button>
                                    </div>
                                </div>
                            </div>

                            <div className="re-creator-footer">
                                <button className="re-btn-secondary" type="button" onClick={resetCreatorForm}>
                                    <Trash2 size={16} /> {editingPropertyId ? 'Cancel' : 'Discard'}
                                </button>
                                <button className="re-btn-primary" type="button" onClick={editingPropertyId ? handleUpdateProperty : handleCreateProperty}>
                                    <Save size={16} /> {editingPropertyId ? 'Save Changes' : 'Create Property'}
                                </button>
                            </div>
                        </div>
                    </div>
                );
        }
    };

    return (
        <motion.div
            className="re-container glass"
            initial={{ opacity: 0, scale: 0.98 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.98 }}
        >
            <div className="re-header-v3">
                <div className="re-title-group">
                    <h1>REAL ESTATE</h1>
                    <span className="re-subtitle">{isAgent && hasPermission.agencyLabel ? hasPermission.agencyLabel.toUpperCase() : 'EXPLORE PROPERTIES'}</span>
                </div>

                <div className="re-header-actions">
                    {isAgent && hasPermission.societyBalance > 0 && (
                        <div className="society-balance glass-heavy">
                            <Database size={14} className="price-green" />
                            <span>Agency Funds: <strong className="price-green">$${hasPermission.societyBalance.toLocaleString()}</strong></span>
                        </div>
                    )}
                    <div className="re-search-v3">
                        <Search size={16} opacity={0.4} />
                        <input
                            type="text"
                            placeholder="Search properties..."
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                        />
                    </div>
                    <button className="re-close-v3" onClick={handleClose}>
                        <X size={18} />
                    </button>
                </div>
            </div>

            <div className="re-sub-header">
                <div className="re-tabs-v4">
                    <button className={`tab-v4 $${activeTab === 'browse' ? 'active' : ''}`} onClick={() => setActiveTab('browse')}>
                        <Home size={16} /> BROWSE LISTINGS
                    </button>
                    {isAgent && canManageListings && (
                        <button className={`tab-v4 $${activeTab === 'management' ? 'active' : ''}`} onClick={() => setActiveTab('management')}>
                            <Settings size={16} /> MANAGEMENT
                        </button>
                    )}
                    {isAgent && canCreate && (
                        <button className={`tab-v4 $${activeTab === 'creator' ? 'active' : ''}`} onClick={() => setActiveTab('creator')}>
                            <Plus size={16} /> PROPERTY CREATOR
                        </button>
                    )}
                    <button className={`tab-v4 $${activeTab === 'contracts' ? 'active' : ''}`} onClick={() => setActiveTab('contracts')}>
                        <FileText size={16} /> CONTRACTS
                    </button>
                </div>

                {activeTab === 'browse' && (
                    <div className="re-sort-v2">
                        <span className="sort-label">SORT BY</span>
                        <div className="sort-buttons-v2">
                            <button className={`sort-btn-v2 $${sortBy === 'none' ? 'active' : ''}`} onClick={() => setSortBy('none')}>
                                <Filter size={14} /> NONE
                            </button>
                            <button className={`sort-btn-v2 $${sortBy === 'price' ? 'active' : ''}`} onClick={() => setSortBy('price')}>
                                <Tag size={14} /> PRICE
                            </button>
                            <button className={`sort-btn-v2 $${sortBy === 'garage' ? 'active' : ''}`} onClick={() => setSortBy('garage')}>
                                <Warehouse size={14} /> GARAGE
                            </button>
                            <button className={`sort-btn-v2 $${sortBy === 'size' ? 'active' : ''}`} onClick={() => setSortBy('size')}>
                                <Maximize size={14} /> SIZE
                            </button>
                        </div>
                    </div>
                )}
            </div>
            <div className="re-grid-v2">
                {renderTabContent()}
            </div>

            <AnimatePresence>
                {selectedProperty && (
                    <div className="re-modal-overlay glass-heavy" onClick={() => setSelectedProperty(null)}>
                        <motion.div
                            className="re-detail-modal glass"
                            initial={{ opacity: 0, y: 50 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0, y: 50 }}
                            onClick={(e) => e.stopPropagation()}
                        >
                            <div className="modal-header">
                                <div className="header-text">
                                    <h2>{selectedProperty.label}</h2>
                                    <span>#{selectedProperty.id} - {selectedProperty.region}</span>
                                </div>
                                <button className="modal-close" onClick={() => setSelectedProperty(null)}><X size={20} /></button>
                            </div>

                            <div className="modal-content">
                                <div className="modal-image">
                                    {selectedProperty.image ? (
                                        <img src={selectedProperty.image} alt={selectedProperty.label} />
                                    ) : (
                                        <div className="image-placeholder" style={{ height: '180px', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(255,255,255,0.05)', borderRadius: '8px' }}>
                                            <Building size={48} opacity={0.1} />
                                        </div>
                                    )}
                                </div>

                                <div className="modal-info-grid">
                                    <div className="info-box">
                                        <span className="info-label">{selectedProperty.sale_type === 'rent' ? 'Rent Price' : 'Base Price'}</span>
                                        <span className="info-value">${selectedProperty.price.toLocaleString()}</span>
                                    </div>
                                    <div className="info-box">
                                        <span className="info-label">Parking</span>
                                        <span className="info-value">{selectedProperty.garage} Slots</span>
                                    </div>
                                    {selectedProperty.sale_type === 'auction' && (
                                        <div className="info-box highlight">
                                            <span className="info-label">Current Bid</span>
                                            <span className="info-value">${(selectedProperty.auction_data?.current_bid || selectedProperty.price).toLocaleString()}</span>
                                        </div>
                                    )}
                                </div>

                                <div className="modal-actions">
                                    {selectedProperty.sale_type === 'auction' ? (
                                        <div className="bid-controls">
                                            <div className="bid-input-group">
                                                <span>$</span>
                                                <input
                                                    type="number"
                                                    value={bidAmount}
                                                    onChange={(e) => setBidAmount(parseInt(e.target.value))}
                                                    min={(selectedProperty.auction_data?.current_bid || selectedProperty.price) + 1}
                                                />
                                            </div>
                                            <button className="primary-btn-v2" onClick={handleBid}>
                                                PLACE BID
                                            </button>
                                        </div>
                                    ) : selectedProperty.sale_type === 'rent' ? (
                                        <div style={{ textAlign: 'center', width: '100%', opacity: 0.8, fontSize: '0.9rem', padding: '10px' }}>
                                            Lease properties must be drafted via an active agent contract.
                                        </div>
                                    ) : onlyBuyViaContracts ? (
                                        <div style={{ textAlign: 'center', width: '100%', opacity: 0.8, fontSize: '0.9rem', padding: '10px', color: '#fda4af', border: '1px dashed rgba(239, 68, 68, 0.2)', borderRadius: '6px', background: 'rgba(239, 68, 68, 0.05)' }}>
                                            This property must be purchased via a real estate agent contract.
                                        </div>
                                    ) : (
                                        <button className="primary-btn-v2 full-width" onClick={handleDirectBuy}>
                                            PURCHASE
                                        </button>
                                    )}
                                </div>
                            </div>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>

            <AnimatePresence>
                {confirmModal && (
                    <div className="re-modal-overlay glass-heavy" onClick={() => setConfirmModal(null)}>
                        <motion.div
                            className="re-detail-modal glass"
                            initial={{ opacity: 0, y: 40 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0, y: 40 }}
                            onClick={(e) => e.stopPropagation()}
                            style={{ width: '420px' }}
                        >
                            <div className="modal-header">
                                <div className="header-text">
                                    <h2>{confirmModal.title}</h2>
                                </div>
                                <button className="modal-close" onClick={() => setConfirmModal(null)}><X size={18} /></button>
                            </div>
                            <div className="modal-content">
                                <p className="modal-message">{confirmModal.message}</p>
                                <div className="modal-actions modal-actions-row">
                                    <button
                                        className="decline-btn modal-action-btn"
                                        onClick={() => setConfirmModal(null)}
                                    >
                                        Cancel
                                    </button>
                                    <button
                                        className="modal-action-btn modal-confirm-btn"
                                        style={{
                                            background: confirmModal.confirmColor || 'rgba(16, 185, 129, 0.2)',
                                            borderColor: confirmModal.confirmBorderColor || 'rgba(16, 185, 129, 0.3)',
                                            color: confirmModal.confirmTextColor || '#a7f3d0',
                                        }}
                                        onClick={confirmModal.onConfirm}
                                    >
                                        {confirmModal.confirmLabel || 'Confirm'}
                                    </button>
                                </div>
                            </div>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>
        </motion.div>
    );
};

export default RealEstate;
