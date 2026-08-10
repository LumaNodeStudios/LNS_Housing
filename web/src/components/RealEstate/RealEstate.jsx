import React, { useState, useEffect, useRef } from 'react';
import './RealEstate.css';
import { motion, AnimatePresence } from 'framer-motion';
import CustomSelect from '../Common/CustomSelect';
import {
    Search, X, MapPin, Building, DollarSign, Navigation,
    Home, CheckCircle2, Power, Tag, Warehouse,
    Clock, Maximize, Filter, Settings, Gavel, Play, Pause, Square,
    Plus, Database, Save, Trash2, Camera, FileText, Percent,
    Briefcase, UserCheck, History, UserPlus, UserX, ChevronLeft, ChevronRight, Check, ChevronDown, ChevronUp, AlertTriangle, FileCheck, Eye, DoorClosed, Video
} from 'lucide-react';

const RealEstate = ({ properties, hasPermission, initialTab, onlyBuyViaContracts, shells, onOpenPaperContract }) => {
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

    useEffect(() => {
        if (initialTab) {
            setActiveTab(initialTab);
        }
    }, [initialTab]);
    const [contractsTab, setContractsTab] = useState('agent');
    const [selectedProperty, setSelectedProperty] = useState(null);
    const [bidAmount, setBidAmount] = useState(0);
    const [confirmModal, setConfirmModal] = useState(null);
    const [pendingContracts, setPendingContracts] = useState([]);
    const [agencyContracts, setAgencyContracts] = useState([]);
    const [nearbyPlayers, setNearbyPlayers] = useState([]);
    const [selectedNearbyPlayer, setSelectedNearbyPlayer] = useState('');
    const isAgent = hasPermission && (hasPermission.allowed || hasPermission === true);
    const canCreate = hasPermission === true || (hasPermission && hasPermission.permissions?.createHouse);
    const canDraft = hasPermission === true || (hasPermission && hasPermission.permissions?.draftContract);
    const canManageListings = hasPermission === true || (hasPermission && hasPermission.permissions?.manageListings);
    const [editingPropertyId, setEditingPropertyId] = useState(null);
    const [currentStep, setCurrentStep] = useState(1);

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
        if (!newBlacklistCid) return;

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
        garageSpawnCoords: null,
        cameraPosition: null,
        cameraAim: null,
        cameraHeading: null,
        cameraModel: null,
        cameraFov: null
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
                {
                    id: 1,
                    property_id: 1,
                    property_label: '222 7 Eclipse Apartment',
                    property_image: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/3671WhispymoundDr-GTAOe.webp',
                    price: 500,
                    type: 'rent',
                    agent_name: 'Marcus Vance',
                    agency_label: 'Luxury Real Estate',
                    client_name: 'Jordan Kahaku',
                    citizenid: 'Y5412212',
                    shell: 'Eclipse Apartment 22',
                    garage: 0
                }
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
                { id: 1, property_label: '222 7 Eclipse Apartment', client_name: 'Jordan Kahaku', agent_name: 'Marcus Vance', type: 'rent', price: 500, status: 'pending' }
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
                { id: '1', name: 'Jordan Kahaku' },
                { id: '2', name: 'Franklin Clinton' }
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

    const handleOpenPaperContract = (contract) => {
        if (onOpenPaperContract) {
            onOpenPaperContract(contract);
        }
    };

    const handleDraftContract = (e) => {
        e.preventDefault();
        const targetId = selectedNearbyPlayer;
        if (!targetId) return;

        if (!window.GetParentResourceName) {
            console.log(`Contract drafted for Player ID: ${targetId}`);
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
            garageSpawnCoords: p.metadata && p.metadata.garage_data && p.metadata.garage_data.spawn ? p.metadata.garage_data.spawn : null,
            cameraPosition: p.metadata && p.metadata.camera_coords ? p.metadata.camera_coords : null,
            cameraAim: p.metadata && p.metadata.camera_aim ? p.metadata.camera_aim : null,
            cameraHeading: p.metadata && p.metadata.camera_heading != null ? p.metadata.camera_heading : null,
            cameraModel: p.metadata && p.metadata.camera_model ? p.metadata.camera_model : null,
            cameraFov: p.metadata && p.metadata.camera_fov ? p.metadata.camera_fov : null
        });
        setActiveTab('creator');
    };

    const handleUpdateProperty = () => {
        if (!window.GetParentResourceName) {
            console.log(`Listing updated locally: ${formData.name}`);
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
                garageSpawnCoords: formData.garageSpawnCoords,
                cameraPosition: formData.cameraPosition,
                cameraAim: formData.cameraAim,
                cameraHeading: formData.cameraHeading,
                cameraModel: formData.cameraModel,
                cameraFov: formData.cameraFov
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
        if (filter === 'direct') return matchesSearch && (!p.sale_type || p.sale_type === 'direct');
        if (filter === 'auction') return matchesSearch && p.sale_type === 'auction';
        if (filter === 'rent') return matchesSearch && p.sale_type === 'rent';
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

    const handlePickDoor = () => {
        if (!window.GetParentResourceName) {
            setFormData(prev => ({
                ...prev,
                doors: [...prev.doors, { coords: { x: 100.5, y: -200.2, z: 30.1 }, hash: 123456 }]
            }));
            return;
        }
        fetch(`https://${window.GetParentResourceName()}/pickDoor`, {
            method: 'POST',
            body: JSON.stringify({})
        });
    };

    const handleRemoveDoor = (index) => {
        setFormData(prev => ({
            ...prev,
            doors: prev.doors.filter((_, i) => i !== index)
        }));
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

    const handlePickCameraPlacement = () => {
        fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/pickCameraPlacement`, {
            method: 'POST',
            body: JSON.stringify({})
        })
            .then(resp => resp.json())
            .then(result => {
                if (result) {
                    setFormData(prev => ({
                        ...prev,
                        cameraPosition: result.position,
                        cameraAim: result.aim,
                        cameraHeading: result.heading ?? null,
                        cameraModel: result.model ?? null,
                        cameraFov: result.fov ?? null
                    }));
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
            garageSpawnCoords: null,
            cameraPosition: null,
            cameraAim: null,
            cameraHeading: null,
            cameraModel: null,
            cameraFov: null
        });
        setEditingPropertyId(null);
        setCurrentStep(1);
        setActiveTab('browse');
    };

    const isStepValid = (step) => {
        if (step === 1) return formData.name && formData.name.trim() !== '';
        if (step === 2) return formData.mlo ? (formData.zone_data !== null || formData.doors.length > 0) : formData.entranceCoords !== null;
        if (step === 3) return formData.price !== '' && parseFloat(formData.price) >= 0;
        return true;
    };

    const handleCreateProperty = () => {
        fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/createHouse`, {
            method: 'POST',
            body: JSON.stringify(formData)
        });
    };

    const tabsList = [
        { id: 'browse', label: 'Listings' },
        ...(isAgent && canManageListings ? [{ id: 'management', label: 'Management' }] : []),
        ...(isAgent && canCreate ? [{ id: 'creator', label: 'Creator' }] : []),
        ...(isAgent ? [{ id: 'blacklist', label: 'Blacklist' }] : []),
        { id: 'contracts', label: 'Contracts' }
    ];

    return (
        <motion.div
            className="re-container"
            initial={{ opacity: 0, scale: 0.98, y: 12 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.98, y: 12 }}
            transition={{ duration: 0.22, ease: 'easeOut' }}
        >
            <header className="re-header-bar">
                <div className="re-hdr-left">
                    <div className="re-hdr-titles">
                        <h2 className="re-brand-title">Real Estate</h2>
                        <span className="re-brand-sub">
                            {isAgent && hasPermission.agencyLabel ? hasPermission.agencyLabel : 'Property Catalog'}
                        </span>
                    </div>
                </div>

                <nav className="re-hdr-tabs">
                    {tabsList.map((tab) => {
                        const isActive = activeTab === tab.id;
                        return (
                            <button
                                key={tab.id}
                                className={`re-tab-btn ${isActive ? 'active' : ''}`}
                                onClick={() => setActiveTab(tab.id)}
                            >
                                <span>{tab.label}</span>
                                {isActive && (
                                    <motion.div
                                        className="re-tab-active-bg"
                                        layoutId="activeReTabPill"
                                        transition={{ type: 'spring', stiffness: 450, damping: 35 }}
                                    />
                                )}
                            </button>
                        );
                    })}
                </nav>

                <div className="re-hdr-right">
                    <div className="re-search-box">
                        <Search size={13} opacity={0.5} />
                        <input
                            type="text"
                            placeholder="Search properties..."
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                        />
                    </div>

                    <button className="re-exit-btn" onClick={handleClose} title="Close UI">
                        <X size={16} />
                    </button>
                </div>
            </header>

            {activeTab === 'browse' && (
                <div className="re-filter-subbar">
                    <div className="filter-chips-group">
                        <button className={`chip-btn ${filter === 'all' ? 'active' : ''}`} onClick={() => setFilter('all')}>All Properties</button>
                        <button className={`chip-btn ${filter === 'available' ? 'active' : ''}`} onClick={() => setFilter('available')}>Available</button>
                        <button className={`chip-btn ${filter === 'owned' ? 'active' : ''}`} onClick={() => setFilter('owned')}>Owned / Sold</button>
                        <button className={`chip-btn ${filter === 'direct' ? 'active' : ''}`} onClick={() => setFilter('direct')}>Direct Sale</button>
                        <button className={`chip-btn ${filter === 'auction' ? 'active' : ''}`} onClick={() => setFilter('auction')}>Auctions</button>
                        <button className={`chip-btn ${filter === 'rent' ? 'active' : ''}`} onClick={() => setFilter('rent')}>Rentals</button>
                    </div>

                    <div className="sort-group">
                        <span className="sort-lbl">Sort By</span>
                        <button className={`sort-chip ${sortBy === 'none' ? 'active' : ''}`} onClick={() => setSortBy('none')}>Default</button>
                        <button className={`sort-chip ${sortBy === 'price' ? 'active' : ''}`} onClick={() => setSortBy('price')}>Price</button>
                        <button className={`sort-chip ${sortBy === 'garage' ? 'active' : ''}`} onClick={() => setSortBy('garage')}>Garage</button>
                        <button className={`sort-chip ${sortBy === 'size' ? 'active' : ''}`} onClick={() => setSortBy('size')}>Size</button>
                    </div>
                </div>
            )}

            <main className="re-content-viewport">
                <AnimatePresence mode="wait">
                    {activeTab === 'browse' && (
                        <motion.div
                            key="browse"
                            className="re-viewport-tab"
                            initial={{ opacity: 0, y: 6 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0, y: -6 }}
                            transition={{ duration: 0.15 }}
                        >
                            {sortedProperties.length > 0 ? (
                                <div className="re-cards-grid">
                                    {sortedProperties.map(p => (
                                        <div key={p.id} className={`re-property-card ${p.owner ? 'sold' : ''}`}>
                                            <div className="prop-cover-image">
                                                {p.image ? (
                                                    <img src={p.image} alt={p.label} />
                                                ) : (
                                                    <div className="image-placeholder">
                                                        <Building size={40} opacity={0.15} />
                                                    </div>
                                                )}
                                                <div className="prop-id-badge">
                                                    <span>#{p.id}</span>
                                                </div>
                                                <div className="prop-type-badge">
                                                    <span>{p.sale_type === 'rent' ? 'RENTAL' : p.sale_type === 'auction' ? 'AUCTION' : 'DIRECT'}</span>
                                                </div>
                                            </div>

                                            <div className="prop-card-body">
                                                <h3 className="prop-title">{p.label}</h3>
                                                <span className="prop-location">{p.region || 'Los Santos'}</span>

                                                <div className="prop-specs-row">
                                                    <div className="spec-item">
                                                        <span className="s-lbl">Category</span>
                                                        <span className="s-val">{p.type || 'Residential'}</span>
                                                    </div>
                                                    <div className="spec-item">
                                                        <span className="s-lbl">Garage</span>
                                                        <span className="s-val">{p.garage || 0} Slots</span>
                                                    </div>
                                                    <div className="spec-item">
                                                        <span className="s-lbl">Size</span>
                                                        <span className="s-val">{p.size || 0} sq ft</span>
                                                    </div>
                                                </div>

                                                <div className="prop-card-footer">
                                                    <div className="price-block">
                                                        <span className="price-lbl">
                                                            {p.sale_type === 'rent' ? 'Weekly Rate' : p.sale_type === 'auction' ? 'Current Bid' : 'Market Price'}
                                                        </span>
                                                        <span className="price-val">
                                                            ${(p.sale_type === 'auction' ? (p.auction_data?.current_bid || p.price) : (p.price || 0)).toLocaleString()}
                                                        </span>
                                                    </div>

                                                    {!p.owner ? (
                                                        <button className="prop-action-btn" onClick={() => handleAction(p)}>
                                                            {p.sale_type === 'auction' ? 'BID NOW' : p.sale_type === 'rent' ? 'LEASE NOW' : 'VIEW DETAILS'}
                                                        </button>
                                                    ) : (
                                                        <div className="sold-tag">
                                                            <CheckCircle2 size={12} /> {p.sale_type === 'rent' ? 'LEASED' : 'SOLD'}
                                                        </div>
                                                    )}
                                                </div>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            ) : (
                                <div className="re-empty-box">
                                    <Search size={36} opacity={0.3} />
                                    <p>No properties match your filter criteria.</p>
                                </div>
                            )}
                        </motion.div>
                    )}

                    {activeTab === 'management' && (
                        <motion.div
                            key="management"
                            className="re-viewport-tab"
                            initial={{ opacity: 0, y: 6 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0, y: -6 }}
                            transition={{ duration: 0.15 }}
                        >
                            <div className="table-wrapper-card">
                                <table className="re-mgmt-table">
                                    <thead>
                                        <tr>
                                            <th>ID</th>
                                            <th>Property Label</th>
                                            <th>Sale Type</th>
                                            <th>Status</th>
                                            <th>Tenant Info</th>
                                            <th>Price / Bid</th>
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
                                                    <span className={`status-tag ${p.owner ? 'owned' : (p.auction_data?.status || 'available')}`}>
                                                        {p.owner ? (p.sale_type === 'rent' ? 'LEASED' : 'SOLD') : (p.auction_data?.status || 'AVAILABLE').toUpperCase()}
                                                    </span>
                                                </td>
                                                <td>
                                                    {p.owner ? (
                                                        <div className="tenant-info-cell">
                                                            <span>CID: <strong>{p.owner}</strong></span>
                                                            {p.sale_type === 'rent' && p.metadata?.rent_debt > 0 && (
                                                                <span className="debt-text">Debt: ${p.metadata.rent_debt.toLocaleString()}</span>
                                                            )}
                                                        </div>
                                                    ) : (
                                                        <span className="dim-text">None</span>
                                                    )}
                                                </td>
                                                <td className="price-cell">${(p.auction_data?.current_bid || p.price || 0).toLocaleString()}</td>
                                                <td>
                                                    <div className="action-buttons-cell">
                                                        {p.sale_type === 'auction' && !p.owner && canManageListings && (
                                                            <>
                                                                <button className="tbl-btn" onClick={() => handleAuctionControl(p.id, 'start')} title="Start Auction"><Play size={12} /></button>
                                                                <button className="tbl-btn" onClick={() => handleAuctionControl(p.id, 'pause')} title="Pause Auction"><Pause size={12} /></button>
                                                                <button className="tbl-btn" onClick={() => handleAuctionControl(p.id, 'end')} title="End Auction"><Square size={12} /></button>
                                                                {p.auction_data?.status === 'pending' && (
                                                                    <button className="tbl-btn confirm" onClick={() => handleAuctionControl(p.id, 'confirm')} title="Confirm Sale"><CheckCircle2 size={12} /></button>
                                                                )}
                                                            </>
                                                        )}
                                                        {canManageListings && (
                                                            <>
                                                                <button className="tbl-btn edit" onClick={() => handleStartEdit(p)} title="Edit Listing"><Settings size={12} /></button>
                                                                <button className="tbl-btn history" onClick={() => setHistoryProperty(p)} title="View History"><History size={12} /></button>
                                                                {p.owner && (
                                                                    <button className="tbl-btn evict" onClick={() => handleEvictTenant(p.id)} title="Evict Tenant"><X size={12} /></button>
                                                                )}
                                                                <button className="tbl-btn delete" onClick={() => handleDeleteListing(p.id)} title="Delete Listing"><Trash2 size={12} /></button>
                                                            </>
                                                        )}
                                                    </div>
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        </motion.div>
                    )}

                    {activeTab === 'contracts' && (
                        <motion.div
                            key="contracts"
                            className="re-viewport-tab"
                            initial={{ opacity: 0, y: 6 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0, y: -6 }}
                            transition={{ duration: 0.15 }}
                        >
                            {isAgent && (
                                <div className="contracts-sub-nav">
                                    <button
                                        type="button"
                                        className={`sub-nav-btn ${contractsTab === 'agent' ? 'active' : ''}`}
                                        onClick={() => setContractsTab('agent')}
                                    >
                                        Agent Contract Hub
                                    </button>
                                    <button
                                        type="button"
                                        className={`sub-nav-btn ${contractsTab === 'personal' ? 'active' : ''}`}
                                        onClick={() => setContractsTab('personal')}
                                    >
                                        My Active Leases & Offers
                                    </button>
                                </div>
                            )}

                            {(!isAgent || contractsTab === 'personal') ? (
                                <div className="personal-contracts-view">
                                    {(() => {
                                        const myActiveLeases = propertyList.filter(p => p.owner && p.owner === hasPermission?.citizenid && p.sale_type === 'rent');
                                        if (myActiveLeases.length === 0) return null;
                                        return (
                                            <div className="leases-section">
                                                <h3 className="section-hdr-title">ACTIVE LEASES</h3>
                                                <div className="leases-grid">
                                                    {myActiveLeases.map(p => {
                                                        const lastPaid = p.metadata?.last_rent_paid || 0;
                                                        const rentPeriod = 604800;
                                                        const timeRemaining = lastPaid > 0 ? (lastPaid + rentPeriod) - Math.floor(Date.now() / 1000) : 0;
                                                        const hoursRemaining = Math.max(0, Math.ceil(timeRemaining / 3600));
                                                        const daysRemaining = Math.max(0, Math.ceil(hoursRemaining / 24));
                                                        const isDelinquent = timeRemaining < -86400;

                                                        return (
                                                            <div key={p.id} className={`lease-card ${isDelinquent ? 'overdue' : ''}`}>
                                                                <div className="lease-details">
                                                                    <h4>{p.label}</h4>
                                                                    <span className="lease-id">Property ID: #{p.id}</span>
                                                                    <div className="lease-metrics">
                                                                        <div>
                                                                            <span className="lbl">Weekly Rent</span>
                                                                            <span className="val">${(p.price || 0).toLocaleString()}</span>
                                                                        </div>
                                                                        <div>
                                                                            <span className="lbl">Time Remaining</span>
                                                                            <span className="val" style={{ color: isDelinquent ? 'var(--danger)' : 'var(--primary)' }}>
                                                                                {isDelinquent ? 'Overdue' : (lastPaid > 0 ? `${daysRemaining} days` : 'Pending')}
                                                                            </span>
                                                                        </div>
                                                                    </div>
                                                                    <div className="lease-actions">
                                                                        <button className="btn-decline" onClick={() => handleTerminateOwnLease(p.id)}>Terminate Lease</button>
                                                                        <button className="btn-accept" onClick={() => fetch(`https://${window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing'}/payRent`, { method: 'POST', body: JSON.stringify({ propertyId: p.id }) })}>Pay Rent</button>
                                                                    </div>
                                                                </div>
                                                            </div>
                                                        );
                                                    })}
                                                </div>
                                            </div>
                                        );
                                    })()}

                                    <div className="leases-section">
                                        <h3 className="section-hdr-title">PENDING OFFERS</h3>
                                        <div className="pending-offers-list">
                                            {pendingContracts.map(c => (
                                                <div key={c.id} className="offer-card">
                                                    <div className="offer-info">
                                                        <h4>{c.property_label}</h4>
                                                        <span className="offer-meta">Drafted by agent {c.agent_name} • {(c.type === 'rent' || c.sale_type === 'rent') ? 'Lease Agreement' : 'Outright Purchase'}</span>
                                                        <span className="offer-price">${(c.price || 0).toLocaleString()}{(c.type === 'rent' || c.sale_type === 'rent') ? ' / week' : ''}</span>
                                                    </div>
                                                    <div className="offer-actions">
                                                        <button className="btn-accept paper-view-btn" onClick={() => handleOpenPaperContract(c)}>
                                                            <FileCheck size={14} style={{ marginRight: '6px' }} /> View Contract
                                                        </button>
                                                    </div>
                                                </div>
                                            ))}
                                            {pendingContracts.length === 0 && (
                                                <div className="re-empty-box">
                                                    <FileText size={32} opacity={0.3} />
                                                    <p>No pending contract offers.</p>
                                                </div>
                                            )}
                                        </div>
                                    </div>
                                </div>
                            ) : (
                                <div className="agent-contracts-view">
                                    <form className="draft-form-card" onSubmit={handleDraftContract}>
                                        <h3>Draft New Contract</h3>
                                        <div className="form-fields-stack">
                                            <CustomSelect
                                                label="Property"
                                                value={draftData.propertyId}
                                                placeholder="Select Available Property"
                                                options={propertyList.filter(p => !p.owner).map(p => ({
                                                    value: p.id,
                                                    label: `#${p.id} ${p.label} ($${(p.price || 0).toLocaleString()})`
                                                }))}
                                                onChange={(e) => {
                                                    const propId = e.target.value;
                                                    const p = propertyList.find(item => String(item.id) === String(propId));
                                                    setDraftData(prev => ({
                                                        ...prev,
                                                        propertyId: propId,
                                                        price: p ? p.price : '',
                                                        type: p && p.sale_type ? p.sale_type : prev.type
                                                    }));
                                                }}
                                            />

                                            <CustomSelect
                                                label="Contract Type"
                                                value={draftData.type}
                                                options={[
                                                    { value: 'buy', label: 'Outright Purchase Sale' },
                                                    { value: 'rent', label: 'Rental Lease Agreement' }
                                                ]}
                                                onChange={(e) => setDraftData(prev => ({ ...prev, type: e.target.value }))}
                                            />

                                            <CustomSelect
                                                label="Select Client (Nearby)"
                                                value={selectedNearbyPlayer}
                                                placeholder="Select Online Player"
                                                options={nearbyPlayers.map(p => ({
                                                    value: p.id,
                                                    label: `${p.name} (Server ID: ${p.id})`
                                                }))}
                                                onChange={(e) => setSelectedNearbyPlayer(e.target.value)}
                                            />

                                            <div className="re-input-group">
                                                <label>Server ID (Manual Input)</label>
                                                <input
                                                    type="number"
                                                    placeholder="e.g. 1"
                                                    value={selectedNearbyPlayer}
                                                    onChange={(e) => setSelectedNearbyPlayer(e.target.value)}
                                                />
                                            </div>

                                            <div className="re-input-group">
                                                <label>Contract Amount ($) [Fixed Market Price]</label>
                                                <input
                                                    readOnly
                                                    type="number"
                                                    placeholder="Select property to auto-fill fixed price"
                                                    value={draftData.price}
                                                    style={{ opacity: 0.75, cursor: 'not-allowed', background: 'rgba(0, 0, 0, 0.4)' }}
                                                />
                                            </div>

                                            {canDraft && (
                                                <div className="re-input-group">
                                                    <label>Realtor Commission Rate ({draftData.commissionRate}%)</label>
                                                    <input
                                                        type="range"
                                                        min="5"
                                                        max="50"
                                                        value={draftData.commissionRate}
                                                        onChange={(e) => setDraftData(prev => ({ ...prev, commissionRate: parseInt(e.target.value) }))}
                                                    />
                                                </div>
                                            )}

                                            {draftData.propertyId && draftData.price && (
                                                <div className="payout-calc-box">
                                                    <div className="p-row">
                                                        <span>Client Price:</span>
                                                        <strong>${parseInt(draftData.price).toLocaleString()}</strong>
                                                    </div>
                                                    <div className="p-row">
                                                        <span>Agent Commission ({draftData.commissionRate}%):</span>
                                                        <strong style={{ color: 'var(--success)' }}>${Math.floor(parseInt(draftData.price) * (draftData.commissionRate / 100)).toLocaleString()}</strong>
                                                    </div>
                                                </div>
                                            )}

                                            <button
                                                type="button"
                                                className="preview-paper-btn"
                                                disabled={!draftData.propertyId || !draftData.price}
                                                onClick={() => {
                                                    const prop = properties && properties[draftData.propertyId];
                                                    const client = nearbyPlayers.find(p => p.id === selectedNearbyPlayer);
                                                    handleOpenPaperContract({
                                                        id: 'draft_preview',
                                                        property_label: prop ? prop.label : 'Property #' + draftData.propertyId,
                                                        price: parseFloat(draftData.price),
                                                        type: draftData.type,
                                                        agent_name: hasPermission?.name || 'Realtor Agent',
                                                        agency_label: hasPermission?.agencyLabel || 'Real Estate',
                                                        client_name: client ? client.name : 'Target Client',
                                                        citizenid: selectedNearbyPlayer || 'CID_CLIENT',
                                                        shell: prop ? (prop.metadata?.shell || prop.type || 'Standard Interior') : 'Standard Interior',
                                                        garage: prop ? (prop.garage !== undefined ? prop.garage : (prop.slots || 0)) : 0
                                                    });
                                                }}
                                            >
                                                <Eye size={13} style={{ marginRight: '6px' }} /> Preview Legal Contract Paper
                                            </button>

                                            <button type="submit" className="submit-contract-btn" disabled={!canDraft}>
                                                Send Contract Offer
                                            </button>
                                        </div>
                                    </form>

                                    <div className="agency-history-card">
                                        <h3>Agency Contract History</h3>
                                        <div className="table-wrapper-card">
                                            <table className="re-mgmt-table">
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
                                                                <span className={`status-tag ${c.status}`}>{c.status.toUpperCase()}</span>
                                                            </td>
                                                        </tr>
                                                    ))}
                                                    {agencyContracts.length === 0 && (
                                                        <tr>
                                                            <td colSpan="5" className="empty-cell">No contract history recorded.</td>
                                                        </tr>
                                                    )}
                                                </tbody>
                                            </table>
                                        </div>
                                    </div>
                                </div>
                            )}
                        </motion.div>
                    )}

                    {activeTab === 'blacklist' && (
                        <motion.div
                            key="blacklist"
                            className="re-viewport-tab"
                            initial={{ opacity: 0, y: 6 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0, y: -6 }}
                            transition={{ duration: 0.15 }}
                        >
                            <div className="blacklist-split-grid">
                                <form className="blacklist-form-card" onSubmit={handleAddBlacklist}>
                                    <h3>Blacklist Tenant</h3>
                                    <div className="form-fields-stack">
                                        <div className="re-input-group">
                                            <label>Server ID (Source)</label>
                                            <input
                                                required
                                                type="text"
                                                placeholder="e.g. 1"
                                                value={newBlacklistCid}
                                                onChange={(e) => setNewBlacklistCid(e.target.value)}
                                            />
                                        </div>
                                        <div className="re-input-group">
                                            <label>Resident Full Name</label>
                                            <input
                                                type="text"
                                                placeholder="e.g. James Doe"
                                                value={newBlacklistName}
                                                onChange={(e) => setNewBlacklistName(e.target.value)}
                                            />
                                        </div>
                                        <div className="re-input-group">
                                            <label>Reason for Blacklist</label>
                                            <input
                                                required
                                                type="text"
                                                placeholder="e.g. Failure to pay weekly lease rent"
                                                value={newBlacklistReason}
                                                onChange={(e) => setNewBlacklistReason(e.target.value)}
                                            />
                                        </div>
                                        <button type="submit" className="submit-contract-btn">Add to Blacklist</button>
                                    </div>
                                </form>

                                <div className="table-wrapper-card">
                                    <table className="re-mgmt-table">
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
                                                            className="tbl-btn delete"
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
                                                    <td colSpan="4" className="empty-cell">No blacklisted renters.</td>
                                                </tr>
                                            )}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </motion.div>
                    )}

                    {activeTab === 'creator' && (
                        <motion.div
                            key="creator"
                            className="re-viewport-tab"
                            initial={{ opacity: 0, y: 6 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0, y: -6 }}
                            transition={{ duration: 0.15 }}
                        >
                            <div className="creator-wizard-container">
                                {editingPropertyId && (
                                    <div className="editing-banner">
                                        <span>Editing Listing <strong>#{editingPropertyId}</strong></span>
                                        <button onClick={resetCreatorForm}><X size={12} /> Discard Edit</button>
                                    </div>
                                )}

                                <div className="wizard-step-tracker">
                                    <div className={`step-item ${currentStep === 1 ? 'active' : ''} ${currentStep > 1 ? 'done' : ''}`} onClick={() => currentStep > 1 && setCurrentStep(1)}>
                                        <div className="step-num">{currentStep > 1 ? <Check size={12} /> : '1'}</div>
                                        <span>Basic Details</span>
                                    </div>
                                    <div className="step-line" />
                                    <div className={`step-item ${currentStep === 2 ? 'active' : ''} ${currentStep > 2 ? 'done' : ''}`} onClick={() => currentStep > 2 && isStepValid(1) && setCurrentStep(2)}>
                                        <div className="step-num">{currentStep > 2 ? <Check size={12} /> : '2'}</div>
                                        <span>Interior & Doors</span>
                                    </div>
                                    <div className="step-line" />
                                    <div className={`step-item ${currentStep === 3 ? 'active' : ''}`} onClick={() => isStepValid(1) && isStepValid(2) && setCurrentStep(3)}>
                                        <div className="step-num">3</div>
                                        <span>Pricing & Media</span>
                                    </div>
                                </div>

                                <div className="wizard-card-body">
                                    {currentStep === 1 && (
                                        <div className="wizard-step-panel">
                                            <h3>Step 1: Basic Property Information</h3>
                                            <div className="form-fields-stack">
                                                <div className="re-input-group">
                                                    <label>Property Name / Street Label</label>
                                                    <input
                                                        name="name"
                                                        value={formData.name}
                                                        onChange={handleInputChange}
                                                        placeholder="e.g. 124 Vinewood Hills"
                                                    />
                                                </div>
                                                <CustomSelect
                                                    label="Category"
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
                                                <div className="re-input-group">
                                                    <label>Outside Parking Slots</label>
                                                    <input
                                                        name="slots"
                                                        type="number"
                                                        value={formData.slots}
                                                        onChange={handleInputChange}
                                                        min="0"
                                                    />
                                                </div>
                                                <div className="re-checkbox-group">
                                                    <label>
                                                        <input
                                                            type="checkbox"
                                                            name="allowWallColors"
                                                            checked={formData.allowWallColors}
                                                            onChange={handleInputChange}
                                                        />
                                                        <span>Allow Interior Wall Color Customization</span>
                                                    </label>
                                                </div>
                                                <div className="re-checkbox-group">
                                                    <label>
                                                        <input
                                                            type="checkbox"
                                                            name="hasYard"
                                                            checked={formData.hasYard}
                                                            onChange={handleInputChange}
                                                        />
                                                        <span>Property Includes Yard Area</span>
                                                    </label>
                                                </div>
                                            </div>
                                        </div>
                                    )}

                                    {currentStep === 2 && (
                                        <div className="wizard-step-panel">
                                            <h3>Step 2: Interior Setup & Coordinates</h3>
                                            <div className="form-fields-stack">
                                                <CustomSelect
                                                    label="Interior Style Type"
                                                    name="mlo"
                                                    value={formData.mlo ? 'true' : 'false'}
                                                    options={[
                                                        { value: 'true', label: 'Physical MLO Building' },
                                                        { value: 'false', label: 'Instanced Interior Shell' }
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
                                                    <>
                                                        <div className="interactive-coord-box">
                                                            <div className="coord-row">
                                                                <div>
                                                                    <h4>Property Main PolyZone</h4>
                                                                    <p>{formData.zone_data ? 'Zone Configured' : 'Not Configured'}</p>
                                                                </div>
                                                                <button type="button" className="coord-btn" onClick={handleCreateZone}>{formData.zone_data ? 'Redefine Zone' : 'Define Zone'}</button>
                                                            </div>

                                                            {formData.hasYard && (
                                                                <div className="coord-row">
                                                                    <div>
                                                                        <h4>Property Yard PolyZone</h4>
                                                                        <p>{formData.yard_zone_data ? 'Yard Zone Configured' : 'Not Configured'}</p>
                                                                    </div>
                                                                    <button type="button" className="coord-btn" onClick={handleCreateYardZone}>{formData.yard_zone_data ? 'Redefine Yard' : 'Define Yard'}</button>
                                                                </div>
                                                            )}
                                                        </div>

                                                        <div className="mlo-doors-picker-card">
                                                            <div className="doors-hdr-row">
                                                                <div>
                                                                    <h4>MLO Building Doors ({formData.doors.length})</h4>
                                                                    <p>Target and add entrance/exit doors for this building</p>
                                                                </div>
                                                                <button type="button" className="coord-btn door-add-btn" onClick={handlePickDoor}>
                                                                    <DoorClosed size={13} style={{ marginRight: '4px' }} /> Target Door
                                                                </button>
                                                            </div>

                                                            {formData.doors.length > 0 ? (
                                                                <div className="selected-doors-list">
                                                                    {formData.doors.map((door, idx) => (
                                                                        <div key={idx} className="door-item-row">
                                                                            <span>Door #{idx + 1} {door.isDouble ? '(Double Door)' : ''}</span>
                                                                            <button type="button" className="remove-door-btn" onClick={() => handleRemoveDoor(idx)}>
                                                                                <Trash2 size={12} />
                                                                            </button>
                                                                        </div>
                                                                    ))}
                                                                </div>
                                                            ) : (
                                                                <span className="dim-subtext">No doors targeted yet. Click 'Target Door' to add.</span>
                                                            )}
                                                        </div>
                                                    </>
                                                ) : (
                                                    <>
                                                        <CustomSelect
                                                            label="Shell Model"
                                                            name="shell"
                                                            value={formData.shell || 'Standard Motel'}
                                                            options={shellOptions}
                                                            onChange={(e) => setFormData(prev => ({ ...prev, shell: e.target.value }))}
                                                        />

                                                        <div className="interactive-coord-box">
                                                            <div className="coord-row">
                                                                <div>
                                                                    <h4>Entrance Teleport Position</h4>
                                                                    <p>{formData.entranceCoords ? 'Coords Configured' : 'Required for shell'}</p>
                                                                </div>
                                                                <button type="button" className="coord-btn" onClick={handlePickEntranceCoords}>Set Position</button>
                                                            </div>
                                                        </div>
                                                    </>
                                                )}

                                                <div className="interactive-coord-box">
                                                    <div className="coord-row">
                                                        <div>
                                                            <h4>Doorbell Camera Placement</h4>
                                                            <p>{formData.cameraPosition ? 'Camera Positioned' : 'Optional'}</p>
                                                        </div>
                                                        <button type="button" className="coord-btn" onClick={handlePickCameraPlacement}>
                                                            <Video size={13} style={{ marginRight: '4px' }} /> Set Camera
                                                        </button>
                                                    </div>

                                                    <div className="coord-row">
                                                        <div>
                                                            <h4>Garage Menu Position</h4>
                                                            <p>{formData.garageCoords ? 'Coords Configured' : 'Optional'}</p>
                                                        </div>
                                                        <button type="button" className="coord-btn" onClick={handlePickGarageCoords}>Set Menu Coords</button>
                                                    </div>

                                                    <div className="coord-row">
                                                        <div>
                                                            <h4>Garage Vehicle Spawn Coords</h4>
                                                            <p>{formData.garageSpawnCoords ? 'Coords Configured' : 'Optional'}</p>
                                                        </div>
                                                        <button type="button" className="coord-btn" onClick={handlePickGarageSpawnCoords}>Set Spawn Coords</button>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    )}

                                    {currentStep === 3 && (
                                        <div className="wizard-step-panel">
                                            <h3>Step 3: Pricing & Listing Photo</h3>
                                            <div className="form-fields-stack">
                                                <CustomSelect
                                                    label="Sale Method"
                                                    name="saleType"
                                                    value={formData.saleType}
                                                    options={[
                                                        { value: 'direct', label: 'Direct Sale' },
                                                        { value: 'auction', label: 'Live Auction' },
                                                        { value: 'rent', label: 'Rental Lease' }
                                                    ]}
                                                    onChange={handleInputChange}
                                                />

                                                <div className="re-input-group">
                                                    <label>Price Amount ($)</label>
                                                    <input
                                                        name="price"
                                                        type="number"
                                                        value={formData.price}
                                                        onChange={handleInputChange}
                                                    />
                                                </div>

                                                <div className="photo-picker-box">
                                                    {formData.image ? (
                                                        <img src={formData.image} alt="Property" className="photo-preview" />
                                                    ) : (
                                                        <div className="photo-placeholder">
                                                            <Camera size={24} opacity={0.4} />
                                                            <span>No photo captured</span>
                                                        </div>
                                                    )}
                                                    <button type="button" className="photo-take-btn" onClick={handleTakePhoto}>Take Photo</button>
                                                </div>
                                            </div>
                                        </div>
                                    )}

                                    <div className="wizard-nav-footer">
                                        <button type="button" className="w-btn cancel" onClick={resetCreatorForm}>Discard</button>
                                        {currentStep > 1 && (
                                            <button type="button" className="w-btn back" onClick={() => setCurrentStep(prev => prev - 1)}>Back</button>
                                        )}
                                        {currentStep < 3 ? (
                                            <button type="button" className="w-btn next" onClick={() => setCurrentStep(prev => prev + 1)} disabled={!isStepValid(currentStep)}>Next</button>
                                        ) : (
                                            <button type="button" className="w-btn submit" onClick={editingPropertyId ? handleUpdateProperty : handleCreateProperty} disabled={!isStepValid(3)}>
                                                {editingPropertyId ? 'Save Listing' : 'Publish Property'}
                                            </button>
                                        )}
                                    </div>
                                </div>
                            </div>
                        </motion.div>
                    )}
                </AnimatePresence>
            </main>

            <AnimatePresence>
                {selectedProperty && (
                    <div className="re-modal-bg" onClick={() => setSelectedProperty(null)}>
                        <motion.div
                            className="re-modal-card"
                            initial={{ opacity: 0, scale: 0.96 }}
                            animate={{ opacity: 1, scale: 1 }}
                            exit={{ opacity: 0, scale: 0.96 }}
                            onClick={(e) => e.stopPropagation()}
                        >
                            <div className="re-modal-hdr">
                                <div>
                                    <h3>{selectedProperty.label}</h3>
                                    <span>#{selectedProperty.id} - {selectedProperty.region || 'Los Santos'}</span>
                                </div>
                                <button onClick={() => setSelectedProperty(null)}><X size={15} /></button>
                            </div>

                            <div className="re-modal-bdy">
                                {selectedProperty.image && (
                                    <img src={selectedProperty.image} alt={selectedProperty.label} className="modal-hero-img" />
                                )}

                                <div className="modal-specs-grid">
                                    <div className="m-spec">
                                        <span>Market Price</span>
                                        <strong>${selectedProperty.price.toLocaleString()}</strong>
                                    </div>
                                    <div className="m-spec">
                                        <span>Garage Slots</span>
                                        <strong>{selectedProperty.garage} Vehicles</strong>
                                    </div>
                                </div>

                                {selectedProperty.sale_type === 'auction' ? (
                                    <div className="bid-section">
                                        <label>Place Custom Bid ($)</label>
                                        <div className="bid-row">
                                            <input
                                                type="number"
                                                value={bidAmount}
                                                onChange={(e) => setBidAmount(parseInt(e.target.value))}
                                            />
                                            <button onClick={handleBid}>Place Bid</button>
                                        </div>
                                    </div>
                                ) : selectedProperty.sale_type === 'rent' ? (
                                    <div className="modal-notice-banner">
                                        Lease properties must be drafted via an active agent contract.
                                    </div>
                                ) : onlyBuyViaContracts ? (
                                    <div className="modal-notice-banner danger">
                                        This property must be purchased via a real estate agent contract.
                                    </div>
                                ) : (
                                    <button className="buy-now-btn" onClick={handleDirectBuy}>
                                        PURCHASE PROPERTY NOW
                                    </button>
                                )}
                            </div>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>

            <AnimatePresence>
                {confirmModal && (
                    <div className="re-modal-bg" onClick={() => setConfirmModal(null)}>
                        <motion.div
                            className="re-modal-card alert"
                            initial={{ opacity: 0, scale: 0.95 }}
                            animate={{ opacity: 1, scale: 1 }}
                            exit={{ opacity: 0, scale: 0.95 }}
                            onClick={(e) => e.stopPropagation()}
                        >
                            <h3>{confirmModal.title}</h3>
                            <p>{confirmModal.message}</p>
                            <div className="alert-actions">
                                <button className="w-btn cancel" onClick={() => setConfirmModal(null)}>Cancel</button>
                                <button className="w-btn danger" onClick={confirmModal.onConfirm}>{confirmModal.confirmLabel || 'Confirm'}</button>
                            </div>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>
        </motion.div>
    );
};

export default RealEstate;