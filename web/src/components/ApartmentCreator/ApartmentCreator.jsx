import React, { useState, useEffect } from 'react';
import './ApartmentCreator.css';
import { motion } from 'framer-motion';
import { Building, MapPin, Key, Compass, Save, X, Check, Search, Info, Tablet, Move, Layers, Footprints, UserMinus, Trash2, AlertTriangle } from 'lucide-react';
import Modeler3D from '../Furniture/Modeler3D';
import { useLocale } from '../../context/LocaleContext';

const ApartmentCreator = ({ onClose, isEdit = false, initialRooms = [] }) => {
    const { t } = useLocale();
    const [rooms, setRooms] = useState(initialRooms || []);
    const [selectedRoom, setSelectedRoom] = useState(null);
    const [searchQuery, setSearchQuery] = useState('');

    const [roomId, setRoomId] = useState('');
    const [zoneData, setZoneData] = useState(null);
    const [doorData, setDoorData] = useState(null);
    const [spawnData, setSpawnData] = useState(null);
    const [interiorData, setInteriorData] = useState(null);
    const [isCapturingInterior, setIsCapturingInterior] = useState(false);
    const [walkMode, setWalkMode] = useState(false);
    const [tabletData, setTabletData] = useState(null);
    const [isPlacingTablet, setIsPlacingTablet] = useState(false);
    const [freecamMode, setFreecamMode] = useState(false);
    const [errorMsg, setErrorMsg] = useState('');
    const [confirmAction, setConfirmAction] = useState(null); // 'vacate' | 'delete' | null
    const [isProcessing, setIsProcessing] = useState(false);

    useEffect(() => {
        if (!window.GetParentResourceName && isEdit && initialRooms.length === 0) {
            setRooms([
                {
                    id: 101,
                    interiorId: 258561,
                    corners: [
                        { x: -826.63, y: -724.74, z: 42.07 },
                        { x: -826.63, y: -730.64, z: 42.07 },
                        { x: -821.17, y: -730.60, z: 42.07 }
                    ],
                    thickness: 3.5,
                    doorModel: -138454175,
                    doorCoords: { x: -825.87, y: -724.61, z: 41.67 },
                    doorHeading: 359.79,
                    spawn: { x: -823.46, y: -727.60, z: 41.57, w: 77.47 },
                    isStarter: true
                },
                {
                    id: 102,
                    interiorId: 258562,
                    corners: [
                        { x: -820.63, y: -724.74, z: 42.07 },
                        { x: -820.63, y: -730.64, z: 42.07 },
                        { x: -815.17, y: -730.60, z: 42.07 }
                    ],
                    thickness: 3.5,
                    doorModel: -138454175,
                    doorCoords: { x: -819.87, y: -724.61, z: 41.67 },
                    doorHeading: 359.79,
                    spawn: { x: -817.46, y: -727.60, z: 41.57, w: 77.47 },
                    isStarter: true
                }
            ]);
        }
    }, [isEdit, initialRooms]);

    useEffect(() => {
        if (selectedRoom) {
            setRoomId(selectedRoom.id.toString());
            setZoneData(selectedRoom.corners && selectedRoom.corners.length >= 3 ? {
                points: selectedRoom.corners,
                thickness: selectedRoom.thickness
            } : null);
            setDoorData(selectedRoom.doorModel ? {
                model: selectedRoom.doorModel,
                coords: selectedRoom.doorCoords,
                heading: selectedRoom.doorHeading
            } : null);
            setSpawnData(selectedRoom.spawn || null);
            setTabletData(selectedRoom.tabletCoords || null);
            setInteriorData(selectedRoom.interiorId ? {
                interiorId: selectedRoom.interiorId,
                coords: selectedRoom.interiorCoords,
                center: selectedRoom.interiorCenter,
                roomCount: selectedRoom.roomCount,
                roomName: selectedRoom.roomName,
                roomKey: selectedRoom.roomKey
            } : null);
        } else {
            setRoomId('');
            setZoneData(null);
            setDoorData(null);
            setSpawnData(null);
            setTabletData(null);
            setInteriorData(null);
        }
    }, [selectedRoom]);

    useEffect(() => {
        const handleMessage = (event) => {
            const { action, data } = event.data;
            if (action === 'addApartmentDoor') {
                setDoorData(data);
            } else if (action === 'freecamMode' && isPlacingTablet) {
                setFreecamMode(data);
            } else if (action === 'restoreWalkMode') {
                setWalkMode(false);
            }
        };
        window.addEventListener('message', handleMessage);
        return () => window.removeEventListener('message', handleMessage);
    }, [isPlacingTablet]);

    useEffect(() => {
        if (!isPlacingTablet) return;

        const handleKeyDown = (e) => {
            if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.isContentEditable) {
                return;
            }

            if (e.key === 'Alt' || e.key === 'Backspace') {
                const next = !freecamMode;
                setFreecamMode(next);
                if (window.GetParentResourceName) {
                    fetch(`https://${window.GetParentResourceName()}/freecamMode`, {
                        method: 'POST',
                        body: JSON.stringify(next)
                    });
                }
            } else if (e.key.toLowerCase() === 'g') {
                if (window.GetParentResourceName) {
                    fetch(`https://${window.GetParentResourceName()}/placeOnGround`, {
                        method: 'POST',
                        body: JSON.stringify({})
                    });
                }
            }
        };

        window.addEventListener('keydown', handleKeyDown);
        return () => {
            window.removeEventListener('keydown', handleKeyDown);
        };
    }, [isPlacingTablet, freecamMode]);

    const toggleWalkMode = (enable) => {
        const next = enable !== undefined ? enable : !walkMode;
        setWalkMode(next);
        if (window.GetParentResourceName) {
            fetch(`https://${window.GetParentResourceName()}/setWalkMode`, {
                method: 'POST',
                body: JSON.stringify({ enabled: next })
            });
        }
    };

    const handleVacate = async () => {
        if (!selectedRoom) return;
        setIsProcessing(true);
        setConfirmAction(null);
        try {
            if (!window.GetParentResourceName) {
                setRooms(prev => prev.map(r => r.id === selectedRoom.id ? { ...r, _vacated: true } : r));
                setIsProcessing(false);
                return;
            }
            const resp = await fetch(`https://${window.GetParentResourceName()}/vacateApartmentRoom`, {
                method: 'POST',
                body: JSON.stringify({ roomId: selectedRoom.id })
            });
            const result = await resp.json();
            if (result?.success) {
                setRooms(prev => prev.map(r => r.id === selectedRoom.id ? { ...r, _vacated: true } : r));
            }
        } finally {
            setIsProcessing(false);
        }
    };

    const handleDelete = async () => {
        if (!selectedRoom) return;
        setIsProcessing(true);
        setConfirmAction(null);
        try {
            if (!window.GetParentResourceName) {
                setRooms(prev => prev.filter(r => r.id !== selectedRoom.id));
                setSelectedRoom(null);
                setIsProcessing(false);
                return;
            }
            const resp = await fetch(`https://${window.GetParentResourceName()}/deleteApartmentRoom`, {
                method: 'POST',
                body: JSON.stringify({ roomId: selectedRoom.id })
            });
            const result = await resp.json();
            if (result?.success) {
                setRooms(prev => prev.filter(r => r.id !== selectedRoom.id));
                setSelectedRoom(null);
            }
        } finally {
            setIsProcessing(false);
        }
    };

    const handleCaptureInterior = () => {
        setIsCapturingInterior(true);
        if (!window.GetParentResourceName) {
            setTimeout(() => {
                setInteriorData({
                    interiorId: 258561,
                    coords: { x: -823.46, y: -727.60, z: 41.57, h: 77.47 },
                    center: { x: -820.0, y: -725.0, z: 40.0 },
                    roomCount: 4,
                    roomName: 'limbo'
                });
                setIsCapturingInterior(false);
            }, 200);
            return;
        }

        fetch(`https://${window.GetParentResourceName()}/captureApartmentInterior`, {
            method: 'POST',
            body: JSON.stringify({})
        })
            .then(resp => resp.json())
            .then(data => {
                if (data && data.interiorId) {
                    setInteriorData(data);
                }
                setIsCapturingInterior(false);
            })
            .catch(() => setIsCapturingInterior(false));
    };

    const handleDefineZone = () => {
        if (!window.GetParentResourceName) {
            setZoneData({
                points: [
                    { x: -826.63, y: -724.74, z: 42.07 },
                    { x: -826.63, y: -730.64, z: 42.07 },
                    { x: -821.17, y: -730.60, z: 42.07 }
                ],
                thickness: 3.5
            });
            return;
        }

        fetch(`https://${window.GetParentResourceName()}/createApartmentZone`, {
            method: 'POST',
            body: JSON.stringify({})
        })
            .then(resp => resp.json())
            .then(data => {
                if (data) {
                    setZoneData(data);
                }
            });
    };

    const handlePickDoor = () => {
        if (!window.GetParentResourceName) {
            setDoorData({
                coords: { x: -825.87, y: -724.61, z: 41.67 },
                model: -138454175,
                heading: 359.79
            });
            return;
        }

        fetch(`https://${window.GetParentResourceName()}/pickApartmentDoor`, {
            method: 'POST',
            body: JSON.stringify({})
        })
            .then(resp => resp.json())
            .then(data => {
                if (data) {
                    setDoorData(data);
                }
            });
    };

    const handleDefineSpawn = () => {
        if (!window.GetParentResourceName) {
            setSpawnData({
                x: -823.46,
                y: -727.60,
                z: 41.57,
                w: 77.47
            });
            setInteriorData({
                interiorId: 258561,
                roomCount: 4
            });
            return;
        }

        fetch(`https://${window.GetParentResourceName()}/pickApartmentSpawn`, {
            method: 'POST',
            body: JSON.stringify({})
        })
            .then(resp => resp.json())
            .then(data => {
                if (data) {
                    setSpawnData(data);
                    if (data.interior && data.interior.interiorId) {
                        setInteriorData(prev => ({
                            ...(prev || {}),
                            ...data.interior,
                            coords: { x: data.x, y: data.y, z: data.z, h: data.w }
                        }));
                    }
                }
            });
    };

    const handlePickTablet = () => {
        setIsPlacingTablet(true);
        setFreecamMode(false);

        if (!window.GetParentResourceName) {
            setTimeout(() => {
                window.dispatchEvent(new MessageEvent('message', {
                    data: {
                        action: 'setupModel',
                        data: {
                            objectPosition: { x: -823.46, y: -727.60, z: 41.57 },
                            objectRotation: { x: 0.0, y: 0.0, z: 77.47 },
                            cameraPosition: { x: -825.0, y: -730.0, z: 45.0 },
                            cameraLookAt: { x: -823.46, y: -727.60, z: 41.57 },
                            cameraFov: 45.0
                        }
                    }
                }));
            }, 100);
            return;
        }

        fetch(`https://${window.GetParentResourceName()}/pickApartmentTablet`, {
            method: 'POST',
            body: JSON.stringify({})
        })
            .then(resp => resp.json())
            .then(data => {
                if (data) {
                    setTabletData(data);
                }
                setIsPlacingTablet(false);
            });
    };

    const handleSubmit = (e) => {
        e.preventDefault();
        setErrorMsg('');

        const numericId = parseInt(roomId);
        if (!numericId || numericId <= 0) {
            setErrorMsg('Please enter a valid Room Number / ID');
            return;
        }

        if (!doorData) {
            setErrorMsg('Please select a front entrance door');
            return;
        }

        if (!spawnData && !interiorData && !zoneData) {
            setErrorMsg('Please set a spawn / interior location or capture native interior');
            return;
        }

        const payload = {
            id: numericId,
            corners: zoneData ? zoneData.points : null,
            thickness: zoneData ? zoneData.thickness : 3.5,
            door: doorData,
            spawn: spawnData || (interiorData?.coords ? { x: interiorData.coords.x, y: interiorData.coords.y, z: interiorData.coords.z, w: interiorData.coords.h } : (doorData?.coords ? { x: doorData.coords.x, y: doorData.coords.y, z: doorData.coords.z, w: doorData.heading } : null)),
            tabletCoords: tabletData,
            interiorId: interiorData?.interiorId || null,
            interiorCoords: interiorData?.coords || null,
            interiorCenter: interiorData?.center || null,
            roomCount: interiorData?.roomCount || null,
            roomName: interiorData?.roomName || null,
            roomKey: interiorData?.roomKey || null
        };

        if (!window.GetParentResourceName) {
            console.log(`Apartment Room #${numericId} ${isEdit ? 'updated' : 'created'} successfully!`, payload);
            onClose();
            return;
        }

        if (isEdit) {
            fetch(`https://${window.GetParentResourceName()}/updateApartment`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify(payload)
            });
            onClose();
        } else {
            fetch(`https://${window.GetParentResourceName()}/doesApartmentExist`, {
                method: 'POST',
                body: JSON.stringify({ id: numericId })
            })
                .then(resp => resp.json())
                .then(exists => {
                    if (exists) {
                        setErrorMsg(`Apartment Room ID ${numericId} already exists!`);
                        return;
                    }

                    fetch(`https://${window.GetParentResourceName()}/createApartment`, {
                        method: 'POST',
                        body: JSON.stringify(payload)
                    });
                    onClose();
                });
        }
    };

    const canSubmit = roomId && doorData && (interiorData || spawnData || zoneData);
    const filteredRooms = rooms.filter(room =>
        room.id.toString().includes(searchQuery)
    );

    return (
        <>
            <motion.div
                className={`apt-creator-modal glass-heavy ${isEdit ? 'edit-mode' : ''} ${walkMode ? 'walk-mode-active' : ''}`}
                style={{ display: isPlacingTablet ? 'none' : 'block' }}
                initial={{ opacity: 0, scale: 0.95, y: 15 }}
                animate={{ opacity: 1, scale: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.95, y: 15 }}
                transition={{ duration: 0.2, ease: 'easeOut' }}
            >
                {isEdit ? (
                    <div className="apt-editor-layout">
                        <div className="apt-list-pane">
                            <div className="apt-sidebar-header">
                                <h3>{t('ui.apt_rooms', 'Apartment Rooms')}</h3>
                                <div className="apt-search-wrapper">
                                    <Search size={16} className="search-icon" />
                                    <input
                                        type="text"
                                        placeholder={t('ui.search_room_id', 'Search Room ID...')}
                                        value={searchQuery}
                                        onChange={(e) => setSearchQuery(e.target.value)}
                                        className="apt-search-input"
                                    />
                                </div>
                            </div>
                            <div className="apt-rooms-list">
                                {filteredRooms.map((room) => (
                                    <div
                                        key={room.id}
                                        className={`apt-room-item ${selectedRoom?.id === room.id ? 'active' : ''}`}
                                        onClick={() => {
                                            setSelectedRoom(room);
                                            setErrorMsg('');
                                        }}
                                    >
                                        <Building size={16} className="room-icon" />
                                        <div className="room-info">
                                            <span className="room-name">Room #{room.id}</span>
                                            {room.isStarter && <span className="room-badge">{t('ui.starter_room', 'Starter')}</span>}
                                            {room.interiorId && <span className="room-badge interior-badge">MLO</span>}
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>

                        <div className="apt-form-pane">
                            <div className="apt-editor-header">
                                <div>
                                    <h3>{t('ui.edit_room', `Edit Room #${selectedRoom?.id}`, selectedRoom?.id)}</h3>
                                    <p className="subtitle">{t('ui.edit_room_sub', 'Configure native interior, doors, spawn, and tablet')}</p>
                                </div>
                                <div className="apt-header-actions">
                                    {confirmAction === 'vacate' && (
                                        <div className="apt-confirm-inline">
                                            <AlertTriangle size={13} />
                                            <span>{t('ui.vacate_room_q', 'Vacate room?')}</span>
                                            <button className="apt-confirm-yes vacate" onClick={handleVacate} disabled={isProcessing}>{t('yes', 'Yes')}</button>
                                            <button className="apt-confirm-no" onClick={() => setConfirmAction(null)}>{t('no', 'No')}</button>
                                        </div>
                                    )}
                                    {confirmAction === 'delete' && (
                                        <div className="apt-confirm-inline danger">
                                            <AlertTriangle size={13} />
                                            <span>{t('ui.delete_forever_q', 'Delete forever?')}</span>
                                            <button className="apt-confirm-yes delete" onClick={handleDelete} disabled={isProcessing}>{t('yes', 'Yes')}</button>
                                            <button className="apt-confirm-no" onClick={() => setConfirmAction(null)}>{t('no', 'No')}</button>
                                        </div>
                                    )}
                                    {selectedRoom && confirmAction === null && (
                                        <>
                                            <button
                                                type="button"
                                                className="apt-danger-btn vacate"
                                                onClick={() => setConfirmAction('vacate')}
                                                title={t('ui.vacate_tooltip', 'Vacate — evict tenant & clear furniture')}
                                                disabled={isProcessing}
                                            >
                                                <UserMinus size={14} />
                                            </button>
                                            <button
                                                type="button"
                                                className="apt-danger-btn delete"
                                                onClick={() => setConfirmAction('delete')}
                                                title={t('ui.delete_room_tooltip', 'Delete room permanently (removes doorlock)')}
                                                disabled={isProcessing}
                                            >
                                                <Trash2 size={14} />
                                            </button>
                                        </>
                                    )}
                                    <button
                                        type="button"
                                        className={`apt-walk-mode-btn ${walkMode ? 'active' : ''}`}
                                        onClick={() => toggleWalkMode()}
                                        title={t('ui.toggle_walk_mode', 'Toggle Walk Mode / Ghost UI')}
                                    >
                                        <Footprints size={14} />
                                        <span>{walkMode ? t('ui.walking', 'Walking...') : t('ui.walk_mode', 'Walk Mode')}</span>
                                    </button>
                                    <button className="apt-close-btn" onClick={onClose}>
                                        <X size={18} />
                                    </button>
                                </div>
                            </div>

                            {selectedRoom ? (
                                <form className="apt-editor-form" onSubmit={handleSubmit}>
                                    <div className="apt-setup-cards">
                                        {/* Native Interior Card */}
                                        <div className={`apt-setup-card ${interiorData ? 'defined' : ''}`}>
                                            <div className="setup-card-info">
                                                <div className="setup-card-icon-wrapper">
                                                    <Layers size={18} />
                                                </div>
                                                <div className="setup-card-text">
                                                    <span className="setup-title">{t('ui.interior_detection', 'Interior Detection')}</span>
                                                    <span className={`setup-status ${interiorData ? 'defined' : ''}`}>
                                                        {interiorData ? `${t('ui.captured', 'Captured')} (${interiorData.roomName ? `Room: ${interiorData.roomName} | ` : ''}ID: #${interiorData.interiorId})` : t('ui.stand_inside_capture', 'Stand inside & capture')}
                                                    </span>
                                                </div>
                                            </div>
                                            <button
                                                type="button"
                                                className={`setup-btn ${interiorData ? 'defined' : ''}`}
                                                onClick={handleCaptureInterior}
                                                disabled={isCapturingInterior}
                                            >
                                                {isCapturingInterior ? t('ui.capturing', 'Capturing...') : (interiorData ? <Check size={16} /> : t('ui.capture', 'Capture'))}
                                            </button>
                                        </div>

                                        {/* Front Entrance Door */}
                                        <div className={`apt-setup-card ${doorData ? 'defined' : ''}`}>
                                            <div className="setup-card-info">
                                                <div className="setup-card-icon-wrapper">
                                                    <Key size={18} />
                                                </div>
                                                <div className="setup-card-text">
                                                    <span className="setup-title">{t('ui.front_entrance_door', 'Front Entrance Door')}</span>
                                                    <span className={`setup-status ${doorData ? 'defined' : ''}`}>
                                                        {doorData ? t('ui.door_selected', 'Door selected') : t('ui.not_selected', 'Not selected')}
                                                    </span>
                                                </div>
                                            </div>
                                            <button
                                                type="button"
                                                className={`setup-btn ${doorData ? 'defined' : ''}`}
                                                onClick={handlePickDoor}
                                            >
                                                {doorData ? <Check size={16} /> : t('ui.select', 'Select')}
                                            </button>
                                        </div>

                                        {/* Spawn Point */}
                                        <div className={`apt-setup-card ${spawnData ? 'defined' : ''}`}>
                                            <div className="setup-card-info">
                                                <div className="setup-card-icon-wrapper">
                                                    <Compass size={18} />
                                                </div>
                                                <div className="setup-card-text">
                                                    <span className="setup-title">{t('ui.spawn_location', 'Spawn / Interior Location')}</span>
                                                    <span className={`setup-status ${spawnData ? 'defined' : ''}`}>
                                                        {spawnData ? t('ui.spawn_set', 'Spawn set successfully') : t('ui.not_set', 'Not set')}
                                                    </span>
                                                </div>
                                            </div>
                                            <button
                                                type="button"
                                                className={`setup-btn ${spawnData ? 'defined' : ''}`}
                                                onClick={handleDefineSpawn}
                                            >
                                                {spawnData ? <Check size={16} /> : t('ui.capture', 'Capture')}
                                            </button>
                                        </div>

                                        {/* Optional Poly Zone */}
                                        <div className={`apt-setup-card ${zoneData ? 'defined' : ''}`}>
                                            <div className="setup-card-info">
                                                <div className="setup-card-icon-wrapper">
                                                    <MapPin size={18} />
                                                </div>
                                                <div className="setup-card-text">
                                                    <span className="setup-title">{t('ui.poly_zone_opt', 'Custom Poly Zone (Optional)')}</span>
                                                    <span className={`setup-status ${zoneData ? 'defined' : ''}`}>
                                                        {zoneData ? t('ui.defined_points', `Defined (${zoneData.points.length} points)`, zoneData.points.length) : t('ui.not_defined_native', 'Not defined (Native Interior Used)')}
                                                    </span>
                                                </div>
                                            </div>
                                            <button
                                                type="button"
                                                className={`setup-btn ${zoneData ? 'defined' : ''}`}
                                                onClick={handleDefineZone}
                                            >
                                                {zoneData ? <Check size={16} /> : t('ui.define', 'Define')}
                                            </button>
                                        </div>

                                        {/* Tablet */}
                                        <div className={`apt-setup-card ${tabletData ? 'defined' : ''}`}>
                                            <div className="setup-card-info">
                                                <div className="setup-card-icon-wrapper">
                                                    <Tablet size={18} />
                                                </div>
                                                <div className="setup-card-text">
                                                    <span className="setup-title">{t('ui.tablet_opt', 'Default Tablet (Optional)')}</span>
                                                    <span className={`setup-status ${tabletData ? 'defined' : ''}`}>
                                                        {tabletData ? t('ui.tablet_pos_set', 'Tablet position set') : t('ui.not_set', 'Not set')}
                                                    </span>
                                                </div>
                                            </div>
                                            <div className="setup-card-actions">
                                                {tabletData && (
                                                    <button
                                                        type="button"
                                                        className="setup-btn-danger"
                                                        onClick={() => setTabletData(null)}
                                                        style={{ marginRight: '8px' }}
                                                    >
                                                        <X size={16} />
                                                    </button>
                                                )}
                                                <button
                                                    type="button"
                                                    className={`setup-btn ${tabletData ? 'defined' : ''}`}
                                                    onClick={handlePickTablet}
                                                >
                                                    {tabletData ? <Check size={16} /> : t('ui.set_position', 'Set Position')}
                                                </button>
                                            </div>
                                        </div>
                                    </div>

                                    {errorMsg && (
                                        <div className="apt-error-msg">
                                            {errorMsg}
                                        </div>
                                    )}

                                    <button
                                        type="submit"
                                        className="apt-submit-btn"
                                        disabled={!canSubmit}
                                    >
                                        <Save size={16} />
                                        <span>{t('save', 'Save Changes')}</span>
                                    </button>
                                </form>
                            ) : (
                                <div className="apt-empty-state">
                                    <Info size={48} className="empty-icon" />
                                    <h3>{t('ui.no_apt_selected', 'No Apartment Selected')}</h3>
                                    <p>{t('ui.no_apt_selected_desc', 'Choose an apartment from the list on the left to start editing its settings and native interior.')}</p>
                                </div>
                            )}
                        </div>
                    </div>
                ) : (
                    <>
                        <div className="apt-creator-header">
                            <div className="apt-header-title">
                                <Building size={20} className="header-icon" />
                                <span>{t('ui.apartment_creator', 'Apartment Creator')}</span>
                            </div>
                            <div className="apt-header-actions">
                                <button
                                    type="button"
                                    className={`apt-walk-mode-btn ${walkMode ? 'active' : ''}`}
                                    onClick={() => toggleWalkMode()}
                                    title={t('ui.toggle_walk_mode', 'Toggle Walk Mode / Ghost UI')}
                                >
                                    <Footprints size={14} />
                                    <span>{walkMode ? t('ui.walking', 'Walking...') : t('ui.walk_mode', 'Walk Mode')}</span>
                                </button>
                                <button className="apt-close-btn" onClick={onClose}>
                                    <X size={18} />
                                </button>
                            </div>
                        </div>

                        <form className="apt-creator-form" onSubmit={handleSubmit}>
                            <div className="apt-input-group">
                                <label className="apt-input-label">
                                    <Building size={14} /> {t('ui.room_number', 'Room Number / ID')}
                                </label>
                                <input
                                    type="number"
                                    placeholder={t('ui.placeholder_room_example', 'e.g. 105')}
                                    value={roomId}
                                    onChange={(e) => setRoomId(e.target.value)}
                                    required
                                    className="apt-input"
                                />
                            </div>

                            <div className="apt-setup-cards">
                                {/* Native Interior Detection */}
                                <div className={`apt-setup-card ${interiorData ? 'defined' : ''}`}>
                                    <div className="setup-card-info">
                                        <div className="setup-card-icon-wrapper">
                                            <Layers size={18} />
                                        </div>
                                        <div className="setup-card-text">
                                            <span className="setup-title">{t('ui.interior_detection', 'Interior Detection')}</span>
                                            <span className={`setup-status ${interiorData ? 'defined' : ''}`}>
                                                {interiorData ? `${t('ui.captured', 'Captured')} (${interiorData.roomName ? `Room: ${interiorData.roomName} | ` : ''}ID: #${interiorData.interiorId})` : t('ui.stand_inside_capture', 'Stand inside & capture')}
                                            </span>
                                        </div>
                                    </div>
                                    <button
                                        type="button"
                                        className={`setup-btn ${interiorData ? 'defined' : ''}`}
                                        onClick={handleCaptureInterior}
                                        disabled={isCapturingInterior}
                                    >
                                        {isCapturingInterior ? t('ui.capturing', 'Capturing...') : (interiorData ? <Check size={16} /> : t('ui.capture', 'Capture'))}
                                    </button>
                                </div>

                                {/* Front Entrance Door */}
                                <div className={`apt-setup-card ${doorData ? 'defined' : ''}`}>
                                    <div className="setup-card-info">
                                        <div className="setup-card-icon-wrapper">
                                            <Key size={18} />
                                        </div>
                                        <div className="setup-card-text">
                                            <span className="setup-title">{t('ui.front_entrance_door', 'Front Entrance Door')}</span>
                                            <span className={`setup-status ${doorData ? 'defined' : ''}`}>
                                                {doorData ? t('ui.door_selected', 'Door selected') : t('ui.not_selected', 'Not selected')}
                                            </span>
                                        </div>
                                    </div>
                                    <button
                                        type="button"
                                        className={`setup-btn ${doorData ? 'defined' : ''}`}
                                        onClick={handlePickDoor}
                                    >
                                        {doorData ? <Check size={16} /> : t('ui.select', 'Select')}
                                    </button>
                                </div>

                                {/* Spawn Point */}
                                <div className={`apt-setup-card ${spawnData ? 'defined' : ''}`}>
                                    <div className="setup-card-info">
                                        <div className="setup-card-icon-wrapper">
                                            <Compass size={18} />
                                        </div>
                                        <div className="setup-card-text">
                                            <span className="setup-title">{t('ui.spawn_location', 'Spawn / Interior Location')}</span>
                                            <span className={`setup-status ${spawnData ? 'defined' : ''}`}>
                                                {spawnData ? t('ui.spawn_set', 'Spawn set successfully') : t('ui.not_set', 'Not set')}
                                            </span>
                                        </div>
                                    </div>
                                    <button
                                        type="button"
                                        className={`setup-btn ${spawnData ? 'defined' : ''}`}
                                        onClick={handleDefineSpawn}
                                    >
                                        {spawnData ? <Check size={16} /> : t('ui.capture', 'Capture')}
                                    </button>
                                </div>

                                {/* Tablet */}
                                <div className={`apt-setup-card ${tabletData ? 'defined' : ''}`}>
                                    <div className="setup-card-info">
                                        <div className="setup-card-icon-wrapper">
                                            <Tablet size={18} />
                                        </div>
                                        <div className="setup-card-text">
                                            <span className="setup-title">{t('ui.tablet_opt', 'Default Tablet (Optional)')}</span>
                                            <span className={`setup-status ${tabletData ? 'defined' : ''}`}>
                                                {tabletData ? t('ui.tablet_pos_set', 'Tablet position set') : t('ui.not_set', 'Not set')}
                                            </span>
                                        </div>
                                    </div>
                                    <div className="setup-card-actions">
                                        {tabletData && (
                                            <button
                                                type="button"
                                                className="setup-btn-danger"
                                                onClick={() => setTabletData(null)}
                                                style={{ marginRight: '8px' }}
                                            >
                                                <X size={16} />
                                            </button>
                                        )}
                                        <button
                                            type="button"
                                            className={`setup-btn ${tabletData ? 'defined' : ''}`}
                                            onClick={handlePickTablet}
                                        >
                                            {tabletData ? <Check size={16} /> : t('ui.set_position', 'Set Position')}
                                        </button>
                                    </div>
                                </div>
                            </div>

                            {errorMsg && (
                                <div className="apt-error-msg">
                                    {errorMsg}
                                </div>
                            )}

                            <button
                                type="submit"
                                className="apt-submit-btn"
                                disabled={!canSubmit}
                            >
                                <Save size={16} />
                                <span>{t('ui.create_starter_apt', 'Create Starter Apartment')}</span>
                            </button>
                        </form>
                    </>
                )}
            </motion.div>

            {freecamMode && isPlacingTablet && (
                <div className="freecam-hint with-placement apt-creator-placement">
                    <span>{t('ui.exit_cam_hint', '[LEFT ALT] Exit Cam | [BACKSPACE] Exit Cam')}</span>
                </div>
            )}

            <Modeler3D
                active={isPlacingTablet}
                onUpdate={(data) => {
                    if (window.GetParentResourceName) {
                        fetch(`https://${window.GetParentResourceName()}/moveObject`, {
                            method: 'POST',
                            body: JSON.stringify(data.position)
                        });
                        fetch(`https://${window.GetParentResourceName()}/rotateObject`, {
                            method: 'POST',
                            body: JSON.stringify(data.rotation)
                        });
                    }
                }}
            />

            {isPlacingTablet && (
                <div className="placement-controls apt-creator-placement">
                    <div className="controls-header">
                        <span className="controls-title">{t('ui.default_tablet_pos', 'Default Tablet Position')}</span>
                        <div className="controls-actions">
                            <div className="controls-hint">
                                <Move size={14} /> <span>{t('ui.tablet_controls_hint', 'Drag | [LALT] Cam | [G] Ground')}</span>
                            </div>
                        </div>
                    </div>

                    <div className="controls-footer">
                        <button className="placeonground-btn" style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }} onClick={() => {
                            if (window.GetParentResourceName) {
                                fetch(`https://${window.GetParentResourceName()}/placeOnGround`, {
                                    method: 'POST',
                                    body: JSON.stringify({})
                                });
                            }
                        }}>
                            <span>{t('ui.place_on_ground', 'Place on Ground')}</span>
                        </button>
                    </div>

                    <div className="controls-footer" style={{ marginTop: '-5px' }}>
                        <button className="confirm-btn" onClick={() => {
                            if (window.GetParentResourceName) {
                                fetch(`https://${window.GetParentResourceName()}/stopPlacementTablet`, {
                                    method: 'POST',
                                    body: JSON.stringify({ save: true })
                                });
                            } else {
                                setIsPlacingTablet(false);
                            }
                        }}>{t('ui.confirm', 'Confirm')}</button>
                        <button className="stop-btn" onClick={() => {
                            if (window.GetParentResourceName) {
                                fetch(`https://${window.GetParentResourceName()}/stopPlacementTablet`, {
                                    method: 'POST',
                                    body: JSON.stringify({ save: false })
                                });
                            } else {
                                setIsPlacingTablet(false);
                            }
                        }}>{t('ui.cancel', 'Cancel')}</button>
                    </div>
                </div>
            )}
        </>
    );
};

export default ApartmentCreator;
