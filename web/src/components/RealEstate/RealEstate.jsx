import React, { useState, useEffect, useRef } from 'react';
import './RealEstate.css';
import { motion, AnimatePresence } from 'framer-motion';
import {
    Search, X, MapPin, Building, DollarSign, Navigation,
    Home, CheckCircle2, Power, Tag, Warehouse,
    Clock, Maximize, Filter, Settings, Gavel, Play, Pause, Square,
    Plus, Database, Save, Trash2, Camera, FileText, Percent,
    Briefcase, UserCheck, History, UserPlus, UserX, ChevronLeft, ChevronRight, Check, ChevronDown, ChevronUp
} from 'lucide-react';

const CustomSelect = ({ label, icon: Icon, value, options, onChange, name, placeholder = "Select option..." }) => {
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
        onChange({
            target: {
                name,
                value: val
            }
        });
        setIsOpen(false);
    };

    return (
        <div className="re-custom-select-container" ref={containerRef}>
            {label && (
                <label className="re-custom-select-label">
                    {Icon && <Icon size={12} />} {label}
                </label>
            )}
            <div 
                className={`re-custom-select-trigger ${isOpen ? 'active' : ''}`}
                onClick={() => setIsOpen(!isOpen)}
            >
                <span className="re-custom-select-value">
                    {selectedOption ? selectedOption.label : placeholder}
                </span>
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
                        {options.map((option) => (
                            <div
                                key={option.value}
                                className={`re-custom-select-option ${String(value) === String(option.value) ? 'selected' : ''}`}
                                onClick={() => handleSelect(option.value)}
                            >
                                <span className="option-text">{option.label}</span>
                                {String(value) === String(option.value) && <Check size={12} className="option-check" />}
                            </div>
                        ))}
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
};

const RealEstate = ({ properties, hasPermission, initialTab, onlyBuyViaContracts, shells }) => {
    const shellOptions = (shells && shells.length > 0) ? shells : [
        { value: 'Standard Motel', label: 'Standard Motel' },
        { value: 'Modern Hotel', label: 'Modern Hotel' },
        { value: 'Apartment Furnished', label: 'Apartment Furnished' },
        { value: 'Apartment Unfurnished', label: 'Apartment Unfurnished' },
        { value: 'Apartment 2 Unfurnished', label: 'Apartment 2 Unfurnished' },
        { value: 'Garage', label: 'Garage' },
        { value: 'Office', label: 'Office' },
        { value: 'Store', label: 'Store' },
        { value: 'Warehouse', label: 'Warehouse' },
        { value: 'Container', label: 'Container' },
        { value: '2 Floor House', label: '2 Floor House' },
        { value: 'House 1', label: 'House 1' },
        { value: 'House 2', label: 'House 2' },
        { value: 'House 3', label: 'House 3' },
        { value: 'House 4', label: 'House 4' },
        { value: 'Trailer', label: 'Trailer' }
    ];

    const [filter, setFilter] = useState('all');
    const [search, setSearch] = useState('');
    const [sortBy, setSortBy] = useState('none');
    const [activeTab, setActiveTab] = useState(initialTab || 'browse');
    const [contractsTab, setContractsTab] = useState('agent');
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
    const [currentStep, setCurrentStep] = useState(1);

    // Rent improvements & blacklist states
    const [blacklist, setBlacklist] = useState([]);
    const [newBlacklistCid, setNewBlacklistCid] = useState('');
    const [newBlacklistName, setNewBlacklistName] = useState('');
    const [newBlacklistReason, setNewBlacklistReason] = useState('');
    const [historyProperty, setHistoryProperty] = useState(null);

    const fetchBlacklist = () => {
        if (!window.GetParentResourceName) {
            setBlacklist([
                { citizenid: 'ABC12345', name: 'James Doe', reason: 'Repeated non-payment of rent', blacklisted_by: 'John Realtor', created_at: '2026-06-13T10:00:00Z' }
            ]);
            return;
        }
        fetch(`https://${window.GetParentResourceName()}/getBlacklist`, {
            method: 'POST',
            body: JSON.stringify({})
        })
            .then(res => res.json())
            .then(data => {
                setBlacklist(data || []);
            });
    };

    const handleAddBlacklist = (e) => {
        e.preventDefault();
        if (!newBlacklistCid || !newBlacklistName) return;

        if (!window.GetParentResourceName) {
            setBlacklist(prev => [...prev, {
                citizenid: newBlacklistCid,
                name: newBlacklistName,
                reason: newBlacklistReason,
                blacklisted_by: 'LocalDev',
                created_at: new Date().toISOString()
            }]);
            setNewBlacklistCid('');
            setNewBlacklistName('');
            setNewBlacklistReason('');
            return;
        }

        fetch(`https://${window.GetParentResourceName()}/addBlacklist`, {
            method: 'POST',
            body: JSON.stringify({
                citizenid: newBlacklistCid,
                name: newBlacklistName,
                reason: newBlacklistReason
            })
        }).then(() => {
            fetchBlacklist();
            setNewBlacklistCid('');
            setNewBlacklistName('');
            setNewBlacklistReason('');
        });
    };

    const handleRemoveBlacklist = (citizenid) => {
        if (!window.GetParentResourceName) {
            setBlacklist(prev => prev.filter(item => item.citizenid !== citizenid));
            return;
        }
        fetch(`https://${window.GetParentResourceName()}/removeBlacklist`, {
            method: 'POST',
            body: JSON.stringify({ citizenid })
        }).then(() => {
            fetchBlacklist();
        });
    };

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
        yard_zone_data: null,
        hasYard: false,
        image: null,
        entranceType: 'door',
        entranceCoords: null,
        garageCoords: null,
        garageSpawnCoords: null
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
            if (initialTab === 'contracts') {
                setContractsTab('personal');
            } else {
                setContractsTab('agent');
            }
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
        } else if (activeTab === 'blacklist') {
            fetchBlacklist();
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
        setCurrentStep(1);
        const hasEntranceCoords = !!(p.metadata && p.metadata.entrance);
        setFormData({
            name: p.label || 'New Property',
            type: p.type || 'Residential',
            price: p.price || 150000,
            mlo: !p.metadata || !p.metadata.shell || p.metadata.shell === 'mlo',
            shell: p.metadata && p.metadata.shell ? p.metadata.shell : 'mlo',
            slots: p.garage || 2,
            allowWallColors: p.allowWallColors !== false,
            saleType: p.sale_type || 'direct',
            doors: p.doors || [],
            zone_data: p.zone_data || null,
            yard_zone_data: p.yard_zone_data || null,
            hasYard: !!p.hasYard,
            image: p.image || null,
            entranceType: hasEntranceCoords ? 'coords' : 'door',
            entranceCoords: p.metadata && p.metadata.entrance ? p.metadata.entrance : null,
            garageCoords: p.metadata && p.metadata.garage_data ? { x: p.metadata.garage_data.x, y: p.metadata.garage_data.y, z: p.metadata.garage_data.z, h: p.metadata.garage_data.h } : null,
            garageSpawnCoords: p.metadata && p.metadata.garage_data && p.metadata.garage_data.spawn ? p.metadata.garage_data.spawn : null
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
                slots: parseInt(formData.slots),
                allowWallColors: formData.allowWallColors,
                mlo: formData.mlo,
                shell: formData.shell,
                doors: formData.doors,
                zone_data: formData.zone_data,
                yard_zone_data: formData.yard_zone_data,
                hasYard: formData.hasYard,
                image: formData.image,
                entranceType: formData.entranceType,
                entranceCoords: formData.entranceCoords,
                garageCoords: formData.garageCoords,
                garageSpawnCoords: formData.garageSpawnCoords
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

    const propertyList = Object.values(properties || {}).filter(p => p !== null && p !== undefined);

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

    const handlePickGarageCoords = () => {
        fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/pickGarageCoords`, {
            method: 'POST',
            body: JSON.stringify({})
        })
            .then(resp => resp.json())
            .then(coords => {
                if (coords) {
                    setFormData(prev => ({ ...prev, garageCoords: coords }));
                }
            });
    };

    const handlePickGarageSpawnCoords = () => {
        fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/pickGarageSpawnCoords`, {
            method: 'POST',
            body: JSON.stringify({})
        })
            .then(resp => resp.json())
            .then(coords => {
                if (coords) {
                    setFormData(prev => ({ ...prev, garageSpawnCoords: coords }));
                }
            });
    };

    const resetCreatorForm = () => {
        setFormData({
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
            yard_zone_data: null,
            hasYard: false,
            image: null,
            entranceType: 'door',
            entranceCoords: null,
            garageCoords: null,
            garageSpawnCoords: null
        });
        setEditingPropertyId(null);
        setCurrentStep(1);
        setActiveTab('browse');
    };

    const isStepValid = (step) => {
        if (step === 1) {
            return formData.name && formData.name.trim() !== '';
        }
        if (step === 2) {
            if (!formData.mlo) {
                return formData.entranceCoords !== null;
            }
            return true;
        }
        if (step === 3) {
            return formData.price !== '' && parseFloat(formData.price) >= 0;
        }
        return true;
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
                        className={`re-card-v2 ${p.owner ? 'owned' : ''}`}
                        initial={{ opacity: 0, y: 10 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ duration: 0.2 }}
                    >
                        <div className="re-card-image-v2">
                            {p.image ? (
                                <img src={p.image} alt={p.label} />
                            ) : (
                                <div className="re-photo-placeholder" style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                                    <Building size={48} opacity={0.15} />
                                </div>
                            )}
                            <div className="re-card-id-badge">
                                <Building size={12} />
                                <span>#{p.id} {p.label}</span>
                            </div>
                        </div>

                        <div className="re-card-details">
                            <div className="detail-item">
                                <div className="detail-label"><MapPin size={12} /> Zone</div>
                                <div className="detail-value">{p.region || 'Unknown'}</div>
                            </div>
                            <div className="detail-item">
                                <div className="detail-label"><Tag size={12} /> Type</div>
                                <div className="detail-value">{p.type || 'Residential'}</div>
                            </div>
                            <div className="detail-item">
                                <div className="detail-label"><Warehouse size={12} /> Garage Slots</div>
                                <div className="detail-value">{p.garage || 0}</div>
                            </div>
                            <div className="detail-item">
                                <div className="detail-label"><DollarSign size={12} /> Market Price</div>
                                <div className="detail-value">${(p.price || 0).toLocaleString()}</div>
                            </div>
                            {p.sale_type === 'auction' && (
                                <div className="detail-item auction-highlight">
                                    <div className="detail-label"><Gavel size={12} /> Current Bid</div>
                                    <div className="detail-value price-green">${(p.auction_data?.current_bid || p.price).toLocaleString()}</div>
                                </div>
                            )}
                            {p.sale_type === 'rent' && (
                                <div className="detail-item rent-highlight">
                                    <div className="detail-label"><Clock size={12} /> Lease Term</div>
                                    <div className="detail-value price-blue">${(p.price || 0).toLocaleString()} / period</div>
                                </div>
                            )}
                        </div>

                        <div className="re-card-footer-v2">
                            <div className="stat-box">
                                <span className="stat-label">Size</span>
                                <span className="stat-value">{p.size || 0} sq ft</span>
                            </div>
                            {!p.owner ? (
                                <button className="view-auction-btn" onClick={() => handleAction(p)}>
                                    {p.sale_type === 'auction' ? 'VIEW AUCTION' : 'VIEW DETAILS'}
                                </button>
                            ) : (
                                <div className="sold-badge-v2">
                                    <CheckCircle2 size={12} /> {p.sale_type === 'rent' ? 'LEASED' : 'SOLD'}
                                </div>
                            )}
                        </div>
                    </motion.div>
                )) : (
                    <div className="re-empty-state">
                        <Search size={40} opacity={0.3} />
                        <p>No properties match your criteria</p>
                    </div>
                );

            case 'management':
                return (
                    <div className="management-container">
                        <table className="management-table">
                            <thead>
                                <tr>
                                    <th>ID</th>
                                    <th>Label</th>
                                    <th>Sale Type</th>
                                    <th>Status</th>
                                    <th>Tenant Info</th>
                                    <th>Price/Bid</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {propertyList.map(p => (
                                    <tr key={p.id}>
                                        <td><strong>#{p.id}</strong></td>
                                        <td>{p.label}</td>
                                        <td>{(p.sale_type || 'direct').toUpperCase()}</td>
                                        <td>
                                            <span className={`status-pill ${p.owner ? 'owned' : (p.auction_data?.status || 'none')}`}>
                                                {p.owner ? (p.sale_type === 'rent' ? 'LEASED' : 'SOLD') : (p.auction_data?.status || 'AVAILABLE').toUpperCase()}
                                            </span>
                                        </td>
                                        <td>
                                            {p.owner ? (
                                                <div style={{ display: 'flex', flexDirection: 'column', gap: '2px', fontSize: '11px' }}>
                                                    <span>CID: <strong>{p.owner}</strong></span>
                                                    {p.sale_type === 'rent' && p.metadata?.rent_debt > 0 && (
                                                        <span style={{ color: 'var(--danger)', fontWeight: '600' }}>Debt: ${p.metadata.rent_debt.toLocaleString()}</span>
                                                    )}
                                                    {p.sale_type === 'rent' && p.metadata?.missed_payments > 0 && (
                                                        <span style={{ color: 'var(--warning)', fontWeight: '600' }}>Missed: {p.metadata.missed_payments}</span>
                                                    )}
                                                </div>
                                            ) : (
                                                <span style={{ opacity: 0.4 }}>None</span>
                                            )}
                                        </td>
                                        <td>${(p.auction_data?.current_bid || p.price || 0).toLocaleString()}</td>
                                        <td>
                                            <div style={{ display: 'flex', gap: '6px', alignItems: 'center' }}>
                                                {p.sale_type === 'auction' && !p.owner && canManageListings && (
                                                    <>
                                                        <button className="manage-action-btn" onClick={() => handleAuctionControl(p.id, 'start')} title="Start"><Play size={12} /></button>
                                                        <button className="manage-action-btn" onClick={() => handleAuctionControl(p.id, 'pause')} title="Pause"><Pause size={12} /></button>
                                                        <button className="manage-action-btn" onClick={() => handleAuctionControl(p.id, 'end')} title="End/Sell"><Square size={12} /></button>
                                                        {p.auction_data?.status === 'pending' && (
                                                            <button className="manage-action-btn confirm-btn" onClick={() => handleAuctionControl(p.id, 'confirm')} title="Confirm Sale"><CheckCircle2 size={12} /></button>
                                                        )}
                                                    </>
                                                )}
                                                {canManageListings && (
                                                    <>
                                                        <button className="manage-action-btn edit-btn" onClick={() => handleStartEdit(p)} title="Edit Listing"><Settings size={12} /></button>
                                                        <button className="manage-action-btn" onClick={() => setHistoryProperty(p)} title="View History" style={{ background: 'rgba(110, 211, 243, 0.08)', color: 'var(--primary)' }}><History size={12} /></button>
                                                        {p.owner && (
                                                            <button className="manage-action-btn evict-btn" onClick={() => handleEvictTenant(p.id)} title="Evict Tenant"><X size={12} /></button>
                                                        )}
                                                        <button className="manage-action-btn delete-btn" onClick={() => handleDeleteListing(p.id)} title="Delete Listing"><Trash2 size={12} /></button>
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
                    <div className="contracts-tab-container">
                        {isAgent && (
                            <div className="re-sub-tabs-v4">
                                <button
                                    type="button"
                                    className={`sub-tab-v4 ${contractsTab === 'agent' ? 'active' : ''}`}
                                    onClick={() => setContractsTab('agent')}
                                >
                                    <Briefcase size={12} /> Agent Panel
                                </button>
                                <button
                                    type="button"
                                    className={`sub-tab-v4 ${contractsTab === 'personal' ? 'active' : ''}`}
                                    onClick={() => setContractsTab('personal')}
                                >
                                    <UserCheck size={12} /> My Contracts & Leases
                                </button>
                            </div>
                        )}
                        <div className="contracts-tab-content">
                            {(!isAgent || contractsTab === 'personal') ? (
                                <div className="player-contracts-container">
                                    {(() => {
                                        const myActiveLeases = propertyList.filter(p => p.owner && p.owner === hasPermission?.citizenid && p.sale_type === 'rent');
                                        if (myActiveLeases.length === 0) return null;
                                        return (
                                            <div style={{ marginBottom: '24px' }}>
                                                <div className="section-title">
                                                    <Home size={14} style={{ marginRight: '6px', verticalAlign: 'middle' }} /> ACTIVE LEASES
                                                </div>
                                                <div className="contracts-list">
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
                                                                className={`contract-card rental-lease-card ${isDelinquent ? 'delinquent' : ''}`}
                                                                initial={{ opacity: 0, scale: 0.98 }}
                                                                animate={{ opacity: 1, scale: 1 }}
                                                            >
                                                                <div className="contract-card-image">
                                                                    {p.image ? (
                                                                        <img src={p.image} alt={p.label} />
                                                                    ) : (
                                                                        <div style={{ width: '100%', height: '100%', background: 'rgba(255,255,255,0.02)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                                                                            <Building size={32} opacity={0.15} />
                                                                        </div>
                                                                    )}
                                                                </div>
                                                                <div className="contract-card-details">
                                                                    <div className="contract-title-row">
                                                                        <h3>{p.label}</h3>
                                                                        <span className={`contract-badge rent ${isDelinquent ? 'delinquent' : ''}`}>
                                                                            {isDelinquent ? 'RENT OVERDUE' : 'ACTIVE LEASE'}
                                                                        </span>
                                                                    </div>
                                                                    <p className="contract-meta">
                                                                        Property ID: <strong>#{p.id}</strong> | Cycle: <strong>7 Days</strong>
                                                                    </p>
                                                                    <div style={{ display: 'flex', gap: '16px', marginTop: '6px' }}>
                                                                        <div className="financial-box">
                                                                            <span className="fin-label">Rent Amount</span>
                                                                            <span className="fin-val" style={{ fontSize: '13.5px' }}>${(p.price || 0).toLocaleString()}</span>
                                                                        </div>
                                                                        <div className="financial-box">
                                                                            <span className="fin-label">Time Remaining</span>
                                                                            <span className="fin-val" style={{ fontSize: '13.5px', color: isDelinquent ? 'var(--danger)' : (daysRemaining <= 1 ? 'var(--warning)' : 'var(--primary)') }}>
                                                                                {isDelinquent ? 'Overdue lockout' : (lastPaid > 0 ? (daysRemaining > 1 ? `${daysRemaining} days` : `${hoursRemaining} hours`) : 'Pending')}
                                                                            </span>
                                                                        </div>
                                                                    </div>
                                                                    <div className="contract-actions">
                                                                        <button className="decline-btn" onClick={() => handleTerminateOwnLease(p.id)}>
                                                                            TERMINATE LEASE
                                                                        </button>
                                                                        <button className="accept-btn" onClick={() => {
                                                                            if (!window.GetParentResourceName) {
                                                                                alert('Rent paid locally!');
                                                                                return;
                                                                            }
                                                                            fetch(`https://${window.GetParentResourceName()}/payRent`, {
                                                                                method: 'POST',
                                                                                body: JSON.stringify({ propertyId: p.id })
                                                                            });
                                                                        }}>
                                                                            PAY RENT
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

                                    <div className="section-title">
                                        <FileText size={14} style={{ marginRight: '6px', verticalAlign: 'middle' }} /> PENDING LEASES & OFFERS
                                    </div>
                                    <div className="contracts-list">
                                        {pendingContracts.map(c => (
                                            <motion.div
                                                key={c.id}
                                                className="contract-card"
                                                initial={{ opacity: 0, scale: 0.95 }}
                                                animate={{ opacity: 1, scale: 1 }}
                                            >
                                                <div className="contract-card-image">
                                                    {c.property_image ? (
                                                        <img src={c.property_image} alt={c.property_label} />
                                                    ) : (
                                                        <div style={{ width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                                                            <Building size={32} opacity={0.15} />
                                                        </div>
                                                    )}
                                                </div>
                                                <div className="contract-card-details">
                                                    <div className="contract-title-row">
                                                        <h3>{c.property_label}</h3>
                                                        <span className={`contract-badge ${c.type}`}>
                                                            {c.type === 'rent' ? 'LEASE OFFER' : 'DIRECT PURCHASE'}
                                                        </span>
                                                    </div>
                                                    <p className="contract-meta">
                                                        Drafted by agent <strong>{c.agent_name}</strong>
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
                                                            ACCEPT & SIGN
                                                        </button>
                                                    </div>
                                                </div>
                                            </motion.div>
                                        ))}
                                        {pendingContracts.length === 0 && (
                                            <div className="re-empty-state">
                                                <FileText size={32} opacity={0.25} />
                                                <p>No pending contract offers</p>
                                                <span style={{ fontSize: '11px', opacity: 0.5 }}>Ask a realtor to draft a property offer for you.</span>
                                            </div>
                                        )}
                                    </div>
                                </div>
                            ) : (
                                <div className="re-contracts-wrapper">
                                    <div className="re-creator-col">
                                        <form className="re-creator-card" onSubmit={handleDraftContract}>
                                            <div className="re-creator-card-title">
                                                <Briefcase size={14} /> Draft New Contract
                                            </div>
                                            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                                                <CustomSelect
                                                    icon={Home}
                                                    label="Select Property"
                                                    value={draftData.propertyId}
                                                    placeholder="-- Choose Available Property --"
                                                    options={propertyList.filter(p => !p.owner).map(p => ({
                                                        value: p.id,
                                                        label: `#${p.id} ${p.label} ($${(p.price || 0).toLocaleString()})`
                                                    }))}
                                                    onChange={(e) => {
                                                        const propId = e.target.value;
                                                        const p = properties && properties[propId];
                                                        setDraftData(prev => ({
                                                            ...prev,
                                                            propertyId: propId,
                                                            price: p ? p.price : ''
                                                        }));
                                                    }}
                                                />

                                                <CustomSelect
                                                    icon={Tag}
                                                    label="Contract Type"
                                                    value={draftData.type}
                                                    options={[
                                                        { value: 'buy', label: 'Outright Sale' },
                                                        { value: 'rent', label: 'Rental Lease' }
                                                    ]}
                                                    onChange={(e) => setDraftData(prev => ({ ...prev, type: e.target.value }))}
                                                />

                                                <CustomSelect
                                                    icon={UserCheck}
                                                    label="Select Client (Nearby)"
                                                    value={selectedNearbyPlayer}
                                                    placeholder="-- Select Online Player --"
                                                    options={nearbyPlayers.map(p => ({
                                                        value: p.id,
                                                        label: `${p.name} (ID: ${p.id})`
                                                    }))}
                                                    onChange={(e) => {
                                                        setSelectedNearbyPlayer(e.target.value);
                                                        if (e.target.value) setManualPlayerId('');
                                                    }}
                                                />

                                                <div className="re-creator-input-field">
                                                    <label><UserPlus size={12} /> Or Enter Client Server ID</label>
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
                                                    <label><DollarSign size={12} /> Contract Value ($)</label>
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
                                                        <label><Percent size={12} /> Commission Rate ({draftData.commissionRate}%)</label>
                                                        <div className="slider-wrapper">
                                                            <input
                                                                type="range"
                                                                min="5"
                                                                max="50"
                                                                value={draftData.commissionRate}
                                                                onChange={(e) => setDraftData(prev => ({ ...prev, commissionRate: parseInt(e.target.value) }))}
                                                            />
                                                        </div>
                                                    </div>
                                                )}
                                            </div>

                                            {draftData.propertyId && draftData.price && (
                                                <div className="re-creator-card" style={{ marginTop: '12px', padding: '12px', background: 'rgba(0,0,0,0.2)' }}>
                                                    <div style={{ fontWeight: '700', fontSize: '11.5px', marginBottom: '8px', opacity: 0.85 }}>Payout Breakdown</div>
                                                    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', fontSize: '11px' }}>
                                                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                                            <span>Client Cost:</span>
                                                            <span style={{ fontWeight: '700' }}>${parseInt(draftData.price).toLocaleString()}</span>
                                                        </div>
                                                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                                            <span>Agent Commission ({draftData.commissionRate}%):</span>
                                                            <span className="price-green" style={{ fontWeight: '700' }}>${Math.floor(parseInt(draftData.price) * (draftData.commissionRate / 100)).toLocaleString()}</span>
                                                        </div>
                                                        <div style={{ display: 'flex', justifyContent: 'space-between', borderTop: '1px solid var(--border-dim)', paddingTop: '6px', marginTop: '2px' }}>
                                                            <span>Agency Deposit:</span>
                                                            <span style={{ fontWeight: '700' }}>${(parseInt(draftData.price) - Math.floor(parseInt(draftData.price) * (draftData.commissionRate / 100))).toLocaleString()}</span>
                                                        </div>
                                                    </div>
                                                </div>
                                            )}

                                            <button type="submit" className="re-btn-primary" style={{ marginTop: '12px', width: '100%' }} disabled={!canDraft}>
                                                <Save size={14} /> Send Contract
                                            </button>
                                        </form>
                                    </div>

                                    <div className="re-creator-col">
                                        <div className="re-creator-card" style={{ maxHeight: '520px', overflowY: 'auto' }}>
                                            <div className="re-creator-card-title">
                                                <History size={14} /> Agency Contract History
                                            </div>
                                            <table className="management-table" style={{ fontSize: '11px' }}>
                                                <thead>
                                                    <tr>
                                                        <th>Property</th>
                                                        <th>Client</th>
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
                                                            <td colSpan="5" style={{ textAlign: 'center', padding: '16px', opacity: 0.4 }}>
                                                                No contract history
                                                            </td>
                                                        </tr>
                                                    )}
                                                </tbody>
                                            </table>
                                        </div>
                                    </div>
                                </div>
                            )}
                        </div>
                    </div>
                );

            case 'blacklist':
                return (
                    <div className="re-contracts-wrapper">
                        <div className="re-creator-col">
                            <form className="re-creator-card" onSubmit={handleAddBlacklist}>
                                <div className="re-creator-card-title">
                                    <UserX size={14} /> Blacklist Renter
                                </div>
                                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                                    <div className="re-creator-input-field">
                                        <label>Citizen ID</label>
                                        <input
                                            required
                                            type="text"
                                            placeholder="e.g. ABC12345"
                                            value={newBlacklistCid}
                                            onChange={(e) => setNewBlacklistCid(e.target.value.toUpperCase())}
                                        />
                                    </div>
                                    <div className="re-creator-input-field">
                                        <label>Resident Full Name</label>
                                        <input
                                            required
                                            type="text"
                                            placeholder="e.g. James Doe"
                                            value={newBlacklistName}
                                            onChange={(e) => setNewBlacklistName(e.target.value)}
                                        />
                                    </div>
                                    <div className="re-creator-input-field">
                                        <label>Reason for Blacklist</label>
                                        <input
                                            required
                                            type="text"
                                            placeholder="e.g. Failure to pay weekly lease rent"
                                            value={newBlacklistReason}
                                            onChange={(e) => setNewBlacklistReason(e.target.value)}
                                        />
                                    </div>
                                </div>
                                <button type="submit" className="re-btn-primary" style={{ marginTop: '16px', width: '100%' }}>
                                    <UserPlus size={14} /> Add to Blacklist
                                </button>
                            </form>
                        </div>

                        <div className="re-creator-col" style={{ flex: 1.4 }}>
                            <div className="re-creator-card" style={{ maxHeight: '520px', overflowY: 'auto' }}>
                                <div className="re-creator-card-title">
                                    <UserX size={14} /> Blacklisted Renters
                                </div>
                                <table className="management-table" style={{ fontSize: '11.5px' }}>
                                    <thead>
                                        <tr>
                                            <th>Citizen ID</th>
                                            <th>Name</th>
                                            <th>Reason</th>
                                            <th>Action</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {blacklist.map(item => (
                                            <tr key={item.citizenid}>
                                                <td><strong>{item.citizenid}</strong></td>
                                                <td>{item.name}</td>
                                                <td>{item.reason}</td>
                                                <td>
                                                    <button
                                                        type="button"
                                                        className="manage-action-btn delete-btn"
                                                        title="Remove Blacklist"
                                                        onClick={() => handleRemoveBlacklist(item.citizenid)}
                                                    >
                                                        <Trash2 size={12} />
                                                    </button>
                                                </td>
                                            </tr>
                                        ))}
                                        {blacklist.length === 0 && (
                                            <tr>
                                                <td colSpan="4" style={{ textAlign: 'center', padding: '16px', opacity: 0.4 }}>
                                                    No blacklisted renters
                                                </td>
                                            </tr>
                                        )}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                );

            case 'creator':
            default:
                return (
                    <div className="re-creator-wrapper">
                        {editingPropertyId && (
                            <div className="re-edit-mode-banner">
                                <span>Editing Listing: <strong>#{editingPropertyId}</strong></span>
                                <button className="re-edit-cancel-btn" onClick={resetCreatorForm}>
                                    <X size={12} /> Cancel Edit
                                </button>
                            </div>
                        )}

                        {/* Step Progress Indicators */}
                        <div className="re-wizard-steps">
                            <div className={`re-wizard-step ${currentStep === 1 ? 'active' : ''} ${currentStep > 1 ? 'completed' : ''}`} onClick={() => currentStep > 1 && setCurrentStep(1)}>
                                <div className="step-circle">{currentStep > 1 ? <Check size={12} /> : '1'}</div>
                                <span className="step-label">Basic Info</span>
                            </div>
                            <div className={`re-wizard-line ${currentStep > 1 ? 'active' : ''}`}></div>
                            <div className={`re-wizard-step ${currentStep === 2 ? 'active' : ''} ${currentStep > 2 ? 'completed' : ''}`} onClick={() => currentStep > 2 && isStepValid(1) && setCurrentStep(2)}>
                                <div className="step-circle">{currentStep > 2 ? <Check size={12} /> : '2'}</div>
                                <span className="step-label">Interior Setup</span>
                            </div>
                            <div className={`re-wizard-line ${currentStep > 2 ? 'active' : ''}`}></div>
                            <div className={`re-wizard-step ${currentStep === 3 ? 'active' : ''}`} onClick={() => isStepValid(1) && isStepValid(2) && setCurrentStep(3)}>
                                <div className="step-circle">3</div>
                                <span className="step-label">Pricing & Photo</span>
                            </div>
                        </div>

                        {/* Wizard Content Cards */}
                        <div className="re-creator-card wizard-card">
                            {currentStep === 1 && (
                                <div className="re-wizard-panel">
                                    <div className="re-creator-card-title">
                                        <Building size={14} /> Basic Information
                                    </div>
                                    <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                                        <div className="re-creator-input-field">
                                            <label><Building size={12} /> Property Label / Name</label>
                                            <input
                                                name="name"
                                                value={formData.name}
                                                onChange={handleInputChange}
                                                placeholder="e.g. 124 Vinewood Hills"
                                                autoFocus
                                            />
                                        </div>
                                        <CustomSelect
                                            icon={Database}
                                            label="Property Category"
                                            name="type"
                                            value={formData.type}
                                            options={[
                                                { value: 'Residential', label: 'Residential' },
                                                { value: 'Commerce', label: 'Commerce' },
                                                { value: 'Industrial', label: 'Industrial' },
                                                { value: 'Apartment', label: 'Apartment' }
                                            ]}
                                            onChange={handleInputChange}
                                        />
                                        <div className="re-creator-input-field">
                                            <label><Warehouse size={12} /> Outside Parking Slots</label>
                                            <div className="re-number-input-wrapper">
                                                <input
                                                    name="slots"
                                                    type="number"
                                                    value={formData.slots}
                                                    onChange={handleInputChange}
                                                    placeholder="0"
                                                    min="0"
                                                    className="re-number-input-spinless"
                                                />
                                                <div className="re-number-spinners">
                                                    <button 
                                                        type="button" 
                                                        className="spinner-arrow up"
                                                        onClick={() => handleInputChange({ target: { name: 'slots', value: (parseInt(formData.slots) || 0) + 1 } })}
                                                    >
                                                        <ChevronUp size={10} />
                                                    </button>
                                                    <button 
                                                        type="button" 
                                                        className="spinner-arrow down"
                                                        onClick={() => handleInputChange({ target: { name: 'slots', value: Math.max(0, (parseInt(formData.slots) || 0) - 1) } })}
                                                    >
                                                        <ChevronDown size={10} />
                                                    </button>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            )}

                            {currentStep === 2 && (
                                <div className="re-wizard-panel">
                                    <div className="re-creator-card-title">
                                        <Database size={14} /> Interior & Bounds Setup
                                    </div>
                                    <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                                        <CustomSelect
                                            icon={Database}
                                            label="Interior Type"
                                            name="mlo"
                                            value={formData.mlo ? 'true' : 'false'}
                                            options={[
                                                { value: 'true', label: 'Physical Map (MLO)' },
                                                { value: 'false', label: 'Instanced Shell' }
                                            ]}
                                            onChange={(e) => {
                                                const isMlo = e.target.value === 'true';
                                                setFormData(prev => ({
                                                    ...prev,
                                                    mlo: isMlo,
                                                    shell: isMlo ? 'mlo' : 'Standard Motel',
                                                    entranceType: isMlo ? 'door' : 'coords',
                                                    doors: [],
                                                    entranceCoords: null
                                                }));
                                            }}
                                        />

                                        {formData.mlo ? (
                                            /* MLO Options */
                                            <>
                                                <div className="re-creator-checkbox-field">
                                                    <div className="re-creator-checkbox-info">
                                                        <span className="re-creator-checkbox-label">Has Outdoor Yard Area</span>
                                                        <span className="re-creator-checkbox-desc">Adds interactive lawn & grass.</span>
                                                    </div>
                                                    <input
                                                        type="checkbox"
                                                        name="hasYard"
                                                        checked={formData.hasYard}
                                                        onChange={(e) => setFormData(prev => ({ ...prev, hasYard: e.target.checked }))}
                                                    />
                                                </div>

                                                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                                                    <div className="re-interactive-row">
                                                        <div className="re-interactive-info">
                                                            <span className="re-interactive-label">Property Poly Zone</span>
                                                            <span className={`re-interactive-status ${formData.zone_data ? 'active' : ''}`}>
                                                                {formData.zone_data ? 'Zone Defined' : 'Not Defined'}
                                                            </span>
                                                        </div>
                                                        <button type="button" className="re-btn-action" onClick={handleCreateZone}>
                                                            {formData.zone_data ? 'Redefine' : 'Define'}
                                                        </button>
                                                    </div>

                                                    {formData.hasYard && (
                                                        <div className="re-interactive-row">
                                                            <div className="re-interactive-info">
                                                                <span className="re-interactive-label">Outside Yard Zone</span>
                                                                <span className={`re-interactive-status ${formData.yard_zone_data ? 'active' : ''}`}>
                                                                    {formData.yard_zone_data ? 'Yard Defined' : 'Not Defined'}
                                                                </span>
                                                            </div>
                                                            <button type="button" className="re-btn-action" onClick={handleCreateYardZone}>
                                                                {formData.yard_zone_data ? 'Redefine' : 'Define'}
                                                            </button>
                                                        </div>
                                                    )}
                                                </div>

                                                <div className="re-creator-input-field">
                                                    <label><Database size={12} /> Door References (ox_doorlock)</label>
                                                    <div className="re-doors-list">
                                                        {formData.doors.length === 0 ? (
                                                            <span style={{ fontSize: '10px', opacity: 0.4, margin: 'auto' }}>No doors added.</span>
                                                        ) : (
                                                            formData.doors.map((door, index) => (
                                                                <div key={index} className="door-tag">
                                                                    <span>{typeof door === 'object' ? `New Door (${Math.floor(door.coords.x)}, ${Math.floor(door.coords.y)})` : `ID: ${door}`}</span>
                                                                    <button
                                                                        className="remove-door-btn"
                                                                        type="button"
                                                                        onClick={() => setFormData(prev => ({ ...prev, doors: prev.doors.filter(d => d !== door) }))}
                                                                    >
                                                                        <X size={10} />
                                                                    </button>
                                                                </div>
                                                            ))
                                                        )}
                                                    </div>
                                                    <button
                                                        className="re-btn-primary"
                                                        style={{ marginTop: '6px', width: '100%' }}
                                                        type="button"
                                                        onClick={() => fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/pickDoor`)}
                                                    >
                                                        <Plus size={12} /> Pick Nearby Door
                                                    </button>
                                                </div>
                                            </>
                                        ) : (
                                            /* Shell Options - Cleaned up to never show doorlock/ox_doorlock */
                                            <>
                                                <CustomSelect
                                                    icon={Database}
                                                    label="Instanced Shell Model"
                                                    name="shell"
                                                    value={formData.shell || 'Standard Motel'}
                                                    options={shellOptions}
                                                    onChange={(e) => setFormData(prev => ({ ...prev, shell: e.target.value }))}
                                                />

                                                <div className="re-interactive-row">
                                                    <div className="re-interactive-info">
                                                        <span className="re-interactive-label">Entrance Position (Teleport Target)</span>
                                                        <span className={`re-interactive-status ${formData.entranceCoords ? 'active' : ''}`}>
                                                            {formData.entranceCoords ? 'Coordinates Configured' : 'Not Configured (Required)'}
                                                        </span>
                                                    </div>
                                                    <button className="re-btn-action" type="button" onClick={handlePickEntranceCoords}>
                                                        {formData.entranceCoords ? 'Reselect' : 'Set Current Position'}
                                                    </button>
                                                </div>

                                                <div className="re-creator-checkbox-field">
                                                    <div className="re-creator-checkbox-info">
                                                        <span className="re-creator-checkbox-label">Allow Wall Tint Colors</span>
                                                        <span className="re-creator-checkbox-desc">Allows tinting inside custom shells.</span>
                                                    </div>
                                                    <input
                                                        type="checkbox"
                                                        name="allowWallColors"
                                                        checked={formData.allowWallColors}
                                                        onChange={handleInputChange}
                                                    />
                                                </div>
                                            </>
                                        )}

                                        <div className="re-interactive-row" style={{ marginTop: '10px', borderTop: '1px solid var(--border-dim)', paddingTop: '10px' }}>
                                            <div className="re-interactive-info">
                                                <span className="re-interactive-label">Garage Menu Location</span>
                                                <span className={`re-interactive-status ${formData.garageCoords ? 'active' : ''}`}>
                                                    {formData.garageCoords ? 'Coordinates Configured' : 'Not Configured (Optional)'}
                                                </span>
                                            </div>
                                            <button className="re-btn-action" type="button" onClick={handlePickGarageCoords}>
                                                {formData.garageCoords ? 'Reselect' : 'Set Current Position'}
                                            </button>
                                        </div>

                                        <div className="re-interactive-row">
                                            <div className="re-interactive-info">
                                                <span className="re-interactive-label">Vehicle Spawn Location</span>
                                                <span className={`re-interactive-status ${formData.garageSpawnCoords ? 'active' : ''}`}>
                                                    {formData.garageSpawnCoords ? 'Coordinates Configured' : 'Not Configured (Optional)'}
                                                </span>
                                            </div>
                                            <button className="re-btn-action" type="button" onClick={handlePickGarageSpawnCoords}>
                                                {formData.garageSpawnCoords ? 'Reselect' : 'Set Current Position'}
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            )}

                            {currentStep === 3 && (
                                <div className="re-wizard-panel">
                                    <div className="re-creator-card-title">
                                        <Tag size={14} /> Pricing & Media Details
                                    </div>
                                    <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                                        <div className="re-creator-inputs">
                                            <div className="re-creator-input-field">
                                                <CustomSelect
                                                    icon={Tag}
                                                    label="Sale Type"
                                                    name="saleType"
                                                    value={formData.saleType}
                                                    options={[
                                                        { value: 'direct', label: 'Direct Sale (Bank)' },
                                                        { value: 'auction', label: 'Auction (Bidding)' },
                                                        { value: 'rent', label: 'Rental Lease (Contracts)' }
                                                    ]}
                                                    onChange={handleInputChange}
                                                />
                                            </div>
                                            <div className="re-creator-input-field">
                                                <label>
                                                    <DollarSign size={12} />{' '}
                                                    {formData.saleType === 'rent'
                                                        ? 'Weekly Rent ($)'
                                                        : formData.saleType === 'auction'
                                                        ? 'Starting Bid ($)'
                                                        : 'Purchase Price ($)'}
                                                </label>
                                                <input
                                                    name="price"
                                                    type="number"
                                                    value={formData.price}
                                                    onChange={handleInputChange}
                                                    placeholder="150000"
                                                />
                                            </div>
                                        </div>

                                        <div className="re-creator-input-field">
                                            <label><Camera size={12} /> Property Photo</label>
                                            <div className="re-photo-card">
                                                <div className="re-photo-preview-box">
                                                    {formData.image ? (
                                                        <img src={formData.image} alt="Preview" />
                                                    ) : (
                                                        <div className="re-photo-placeholder">
                                                            <Camera size={24} opacity={0.4} />
                                                            <span>No photo taken yet</span>
                                                        </div>
                                                    )}
                                                </div>
                                                <button type="button" className="re-btn-primary" style={{ width: '100%' }} onClick={handleTakePhoto}>
                                                    <Camera size={12} /> {formData.image ? 'Retake Photo' : 'Take Property Photo'}
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            )}

                            {/* Wizard Navigation Footer */}
                            <div className="re-creator-footer wizard-footer">
                                <button className="re-btn-secondary" type="button" onClick={resetCreatorForm}>
                                    <Trash2 size={12} /> {editingPropertyId ? 'Cancel' : 'Discard'}
                                </button>
                                
                                {currentStep > 1 && (
                                    <button className="re-btn-secondary" type="button" onClick={() => setCurrentStep(prev => prev - 1)}>
                                        <ChevronLeft size={14} /> Back
                                    </button>
                                )}

                                {currentStep < 3 ? (
                                    <button 
                                        className="re-btn-primary" 
                                        type="button" 
                                        onClick={() => setCurrentStep(prev => prev + 1)}
                                        disabled={!isStepValid(currentStep)}
                                    >
                                        Next <ChevronRight size={14} />
                                    </button>
                                ) : (
                                    <button 
                                        className="re-btn-primary" 
                                        type="button" 
                                        onClick={editingPropertyId ? handleUpdateProperty : handleCreateProperty}
                                        disabled={!isStepValid(3)}
                                    >
                                        <Save size={12} /> {editingPropertyId ? 'Save Changes' : 'Create Listing'}
                                    </button>
                                )}
                            </div>
                        </div>
                    </div>
                );
        }
    };

    return (
        <motion.div
            className="re-container"
            initial={{ opacity: 0, scale: 0.97, y: 15 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.97, y: 15 }}
            transition={{ duration: 0.25, ease: 'easeOut' }}
        >
            <div className="re-header-v3">
                <div className="re-title-group">
                    <h1>REAL ESTATE</h1>
                    <span className="re-subtitle">{isAgent && hasPermission.agencyLabel ? hasPermission.agencyLabel : 'EXPLORE PROPERTIES'}</span>
                </div>

                <div className="re-header-actions">
                    {isAgent && hasPermission.societyBalance > 0 && (
                        <div className="society-balance">
                            <Database size={12} className="price-green" />
                            <span>Agency Funds: <strong className="price-green">${hasPermission.societyBalance.toLocaleString()}</strong></span>
                        </div>
                    )}
                    <div className="re-search-v3">
                        <Search size={14} opacity={0.4} />
                        <input
                            type="text"
                            placeholder="Search properties..."
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                        />
                    </div>
                    <button className="re-close-v3" onClick={handleClose}>
                        <X size={16} />
                    </button>
                </div>
            </div>

            <div className="re-sub-header">
                <div className="re-tabs-v4">
                    <button className={`tab-v4 ${activeTab === 'browse' ? 'active' : ''}`} onClick={() => setActiveTab('browse')}>
                        <Home size={12} /> Listings
                    </button>
                    {isAgent && canManageListings && (
                        <button className={`tab-v4 ${activeTab === 'management' ? 'active' : ''}`} onClick={() => setActiveTab('management')}>
                            <Settings size={12} /> Management
                        </button>
                    )}
                    {isAgent && canCreate && (
                        <button className={`tab-v4 ${activeTab === 'creator' ? 'active' : ''}`} onClick={() => setActiveTab('creator')}>
                            <Plus size={12} /> Creator
                        </button>
                    )}
                    {isAgent && (
                        <button className={`tab-v4 ${activeTab === 'blacklist' ? 'active' : ''}`} onClick={() => setActiveTab('blacklist')}>
                            <UserX size={12} /> Blacklist
                        </button>
                    )}
                    <button className={`tab-v4 ${activeTab === 'contracts' ? 'active' : ''}`} onClick={() => setActiveTab('contracts')}>
                        <FileText size={12} /> Contracts
                    </button>
                </div>

                {activeTab === 'browse' && (
                    <div className="re-sort-v2">
                        <span className="sort-label">Sort By</span>
                        <div className="sort-buttons-v2">
                            <button className={`sort-btn-v2 ${sortBy === 'none' ? 'active' : ''}`} onClick={() => setSortBy('none')}>
                                <Filter size={10} /> None
                            </button>
                            <button className={`sort-btn-v2 ${sortBy === 'price' ? 'active' : ''}`} onClick={() => setSortBy('price')}>
                                <Tag size={10} /> Price
                            </button>
                            <button className={`sort-btn-v2 ${sortBy === 'garage' ? 'active' : ''}`} onClick={() => setSortBy('garage')}>
                                <Warehouse size={10} /> Garage
                            </button>
                            <button className={`sort-btn-v2 ${sortBy === 'size' ? 'active' : ''}`} onClick={() => setSortBy('size')}>
                                <Maximize size={10} /> Size
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
                    <div className="re-modal-overlay" onClick={() => setSelectedProperty(null)}>
                        <motion.div
                            className="re-detail-modal"
                            initial={{ opacity: 0, y: 30 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0, y: 30 }}
                            onClick={(e) => e.stopPropagation()}
                            transition={{ duration: 0.25 }}
                        >
                            <div className="modal-header">
                                <div className="header-text">
                                    <h2>{selectedProperty.label}</h2>
                                    <span>#{selectedProperty.id} - {selectedProperty.region || 'Los Santos'}</span>
                                </div>
                                <button className="modal-close" onClick={() => setSelectedProperty(null)}><X size={16} /></button>
                            </div>

                            <div className="modal-content">
                                <div className="modal-image">
                                    {selectedProperty.image ? (
                                        <img src={selectedProperty.image} alt={selectedProperty.label} />
                                    ) : (
                                        <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(0,0,0,0.2)' }}>
                                            <Building size={40} opacity={0.15} />
                                        </div>
                                    )}
                                </div>

                                <div className="modal-info-grid">
                                    <div className="info-box">
                                        <span className="info-label">{selectedProperty.sale_type === 'rent' ? 'Rent Term' : 'Purchase Price'}</span>
                                        <span className="info-value">${selectedProperty.price.toLocaleString()}</span>
                                    </div>
                                    <div className="info-box">
                                        <span className="info-label">Parking Slots</span>
                                        <span className="info-value">{selectedProperty.garage} slots</span>
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
                                        <div style={{ textAlign: 'center', width: '100%', opacity: 0.7, fontSize: '11px', padding: '10px', border: '1px dashed var(--border-dim)', borderRadius: '6px' }}>
                                            Lease properties must be drafted via an active agent contract.
                                        </div>
                                    ) : onlyBuyViaContracts ? (
                                        <div style={{ textAlign: 'center', width: '100%', opacity: 0.7, fontSize: '11px', padding: '10px', color: 'var(--danger)', border: '1px dashed var(--danger)', borderRadius: '6px', background: 'rgba(244, 63, 94, 0.02)' }}>
                                            This property must be purchased via a real estate agent contract.
                                        </div>
                                    ) : (
                                        <button className="primary-btn-v2 full-width" onClick={handleDirectBuy}>
                                            PURCHASE PROPERTY
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
                    <div className="re-modal-overlay" onClick={() => setConfirmModal(null)}>
                        <motion.div
                            className="re-detail-modal"
                            initial={{ opacity: 0, scale: 0.95 }}
                            animate={{ opacity: 1, scale: 1 }}
                            exit={{ opacity: 0, scale: 0.95 }}
                            onClick={(e) => e.stopPropagation()}
                            style={{ width: '400px' }}
                            transition={{ duration: 0.2 }}
                        >
                            <div className="modal-header">
                                <div className="header-text">
                                    <h2>{confirmModal.title}</h2>
                                </div>
                                <button className="modal-close" onClick={() => setConfirmModal(null)}><X size={16} /></button>
                            </div>
                            <div className="modal-content">
                                <p style={{ fontSize: '12px', lineHeight: '1.5', opacity: 0.85 }}>{confirmModal.message}</p>
                                <div className="modal-actions-row">
                                    <button
                                        className="btn-cancel"
                                        onClick={() => setConfirmModal(null)}
                                        style={{ padding: '10px' }}
                                    >
                                        Cancel
                                    </button>
                                    <button
                                        className="modal-action-btn modal-confirm-btn"
                                        style={{
                                            background: confirmModal.confirmColor || 'var(--success-glow)',
                                            borderColor: confirmModal.confirmBorderColor || 'var(--success)',
                                            color: confirmModal.confirmTextColor || '#fff',
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

            <AnimatePresence>
                {historyProperty && (
                    <div className="re-modal-overlay" onClick={() => setHistoryProperty(null)}>
                        <motion.div
                            className="re-detail-modal"
                            initial={{ opacity: 0, y: 30 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0, y: 30 }}
                            onClick={(e) => e.stopPropagation()}
                            style={{ width: '560px', maxHeight: '85vh' }}
                            transition={{ duration: 0.25 }}
                        >
                            <div className="modal-header">
                                <div className="header-text">
                                    <h2>Property History</h2>
                                    <span>#{historyProperty.id} - {historyProperty.label}</span>
                                </div>
                                <button className="modal-close" onClick={() => setHistoryProperty(null)}><X size={16} /></button>
                            </div>
                            <div className="modal-content" style={{ display: 'flex', flexDirection: 'column', gap: '16px', overflowY: 'auto', maxHeight: 'calc(85vh - 80px)' }}>
                                <div>
                                    <h3 style={{ fontSize: '11px', fontWeight: '800', color: 'var(--primary)', marginBottom: '8px', textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: '6px' }}><History size={12} /> Lease Activity History</h3>
                                    <div style={{ background: 'rgba(0,0,0,0.2)', border: '1px solid var(--border-dim)', borderRadius: '8px', padding: '10px', maxHeight: '200px', overflowY: 'auto' }}>
                                        <table className="management-table" style={{ fontSize: '11px' }}>
                                            <thead>
                                                <tr>
                                                    <th>Date</th>
                                                    <th>Action</th>
                                                    <th>Details</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                {(historyProperty.metadata?.tenant_history || []).map((log, idx) => {
                                                    const isNegative = log.type === 'Evicted' || log.type === 'Terminated';
                                                    return (
                                                        <tr key={idx}>
                                                            <td style={{ opacity: 0.7 }}>{log.date || 'N/A'}</td>
                                                            <td>
                                                                <span className={`status-pill ${isNegative ? 'ended' : 'live'}`} style={{ fontSize: '8.5px', padding: '2px 6px' }}>
                                                                    {(log.type || 'UNKNOWN').toUpperCase()}
                                                                </span>
                                                            </td>
                                                            <td style={{ opacity: 0.9 }}>
                                                                {log.tenant ? `${log.tenant} (${log.citizenid})` : log.citizenid}
                                                                {log.reason && ` - ${log.reason}`}
                                                                {(log.price || log.amount) && ` ($${(log.price || log.amount).toLocaleString()})`}
                                                            </td>
                                                        </tr>
                                                    );
                                                })}
                                                {(!historyProperty.metadata?.tenant_history || historyProperty.metadata.tenant_history.length === 0) && (
                                                    <tr>
                                                        <td colSpan="3" style={{ textAlign: 'center', padding: '12px', opacity: 0.4 }}>No lease activities recorded.</td>
                                                    </tr>
                                                )}
                                            </tbody>
                                        </table>
                                    </div>
                                </div>

                                <div>
                                    <h3 style={{ fontSize: '11px', fontWeight: '800', color: 'var(--primary)', marginBottom: '8px', textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: '6px' }}><DollarSign size={12} /> Rent Payment History</h3>
                                    <div style={{ background: 'rgba(0,0,0,0.2)', border: '1px solid var(--border-dim)', borderRadius: '8px', padding: '10px', maxHeight: '200px', overflowY: 'auto' }}>
                                        <table className="management-table" style={{ fontSize: '11px' }}>
                                            <thead>
                                                <tr>
                                                    <th>Date</th>
                                                    <th>Amount</th>
                                                    <th>Type</th>
                                                    <th>Status</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                {(historyProperty.metadata?.rent_history || []).map((log, idx) => {
                                                    const isPaid = log.status && log.status.toLowerCase() === 'paid';
                                                    return (
                                                        <tr key={idx}>
                                                            <td style={{ opacity: 0.7 }}>{log.date || 'N/A'}</td>
                                                            <td style={{ fontWeight: '700', color: isPaid ? 'var(--success)' : 'var(--danger)' }}>
                                                                {log.amount ? `$${log.amount.toLocaleString()}` : '$0'}
                                                            </td>
                                                            <td>
                                                                {log.type || 'Payment'}
                                                            </td>
                                                            <td>
                                                                <span className={`status-pill ${isPaid ? 'live' : 'ended'}`} style={{ fontSize: '8.5px', padding: '2px 6px' }}>
                                                                    {(log.status || 'UNPAID').toUpperCase()}
                                                                </span>
                                                            </td>
                                                        </tr>
                                                    );
                                                })}
                                                {(!historyProperty.metadata?.rent_history || historyProperty.metadata.rent_history.length === 0) && (
                                                    <tr>
                                                        <td colSpan="4" style={{ textAlign: 'center', padding: '12px', opacity: 0.4 }}>No financial transactions recorded.</td>
                                                    </tr>
                                                )}
                                            </tbody>
                                        </table>
                                    </div>
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
