import React, { useState, useEffect } from 'react';
import './ApartmentCreator.css';
import { motion } from 'framer-motion';
import { Building, MapPin, Key, Compass, Save, X, Check, Search, Info, Tablet, Move } from 'lucide-react';
import Modeler3D from '../Furniture/Modeler3D';

const ApartmentCreator = ({ onClose, isEdit = false, initialRooms = [] }) => {
    const [rooms, setRooms] = useState(initialRooms || []);
    const [selectedRoom, setSelectedRoom] = useState(null);
    const [searchQuery, setSearchQuery] = useState('');

    const [roomId, setRoomId] = useState('');
    const [zoneData, setZoneData] = useState(null);
    const [doorData, setDoorData] = useState(null);
    const [spawnData, setSpawnData] = useState(null);
    const [tabletData, setTabletData] = useState(null);
    const [isPlacingTablet, setIsPlacingTablet] = useState(false);
    const [freecamMode, setFreecamMode] = useState(false);
    const [errorMsg, setErrorMsg] = useState('');

    useEffect(() => {
        if (!window.GetParentResourceName && isEdit && initialRooms.length === 0) {
            setRooms([
                {
                    id: 101,
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
            setZoneData(selectedRoom.corners ? {
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
        } else {
            setRoomId('');
            setZoneData(null);
            setDoorData(null);
            setSpawnData(null);
            setTabletData(null);
        }
    }, [selectedRoom]);

    useEffect(() => {
        const handleMessage = (event) => {
            const { action, data } = event.data;
            if (action === 'addApartmentDoor') {
                setDoorData(data);
            } else if (action === 'freecamMode' && isPlacingTablet) {
                setFreecamMode(data);
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

            if (e.key === 'Alt') {
                const next = !freecamMode;
                setFreecamMode(next);
                if (window.GetParentResourceName) {
                    fetch(`https://${window.GetParentResourceName()}/freecamMode`, {
                        method: 'POST',
                        body: JSON.stringify(next)
                    });
                }
            } else if (e.key === 'Backspace') {
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

        if (!zoneData) {
            setErrorMsg('Please define the apartment zone');
            return;
        }

        if (!doorData) {
            setErrorMsg('Please select a front entrance door');
            return;
        }

        if (!spawnData) {
            setErrorMsg('Please set a spawn / interior point');
            return;
        }

        if (!window.GetParentResourceName) {
            alert(`Apartment Room #${numericId} ${isEdit ? 'updated' : 'created'} successfully in mock environment!`);
            onClose();
            return;
        }

        if (isEdit) {
            fetch(`https://${window.GetParentResourceName()}/updateApartment`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify({
                    id: numericId,
                    corners: zoneData.points,
                    thickness: zoneData.thickness,
                    door: doorData,
                    spawn: spawnData,
                    tabletCoords: tabletData
                })
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
                        body: JSON.stringify({
                            id: numericId,
                            corners: zoneData.points,
                            thickness: zoneData.thickness,
                            door: doorData,
                            spawn: spawnData,
                            tabletCoords: tabletData
                        })
                    });
                    onClose();
                });
        }
    };

    const canSubmit = roomId && zoneData && doorData && spawnData;
    const filteredRooms = rooms.filter(room =>
        room.id.toString().includes(searchQuery)
    );

    return (
        <>
            <motion.div
                className={`apt-creator-modal glass-heavy ${isEdit ? 'edit-mode' : ''}`}
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
                                <h3>Apartment Rooms</h3>
                                <div className="apt-search-wrapper">
                                    <Search size={16} className="search-icon" />
                                    <input
                                        type="text"
                                        placeholder="Search Room ID..."
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
                                            {room.isStarter && <span className="room-badge">Starter</span>}
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>

                        <div className="apt-form-pane">
                            <div className="apt-editor-header">
                                <div>
                                    <h3>Edit Room #{selectedRoom?.id}</h3>
                                    <p className="subtitle">Configure zones, doors and tablet location</p>
                                </div>
                                <button className="apt-close-btn" onClick={onClose}>
                                    <X size={18} />
                                </button>
                            </div>

                            {selectedRoom ? (
                                <form className="apt-editor-form" onSubmit={handleSubmit}>
                                    <div className="apt-setup-cards">
                                        <div className={`apt-setup-card ${zoneData ? 'defined' : ''}`}>
                                            <div className="setup-card-info">
                                                <div className="setup-card-icon-wrapper">
                                                    <MapPin size={18} />
                                                </div>
                                                <div className="setup-card-text">
                                                    <span className="setup-title">Apartment Zone</span>
                                                    <span className={`setup-status ${zoneData ? 'defined' : ''}`}>
                                                        {zoneData ? 'Defined successfully' : 'Not defined'}
                                                    </span>
                                                </div>
                                            </div>
                                            <button
                                                type="button"
                                                className={`setup-btn ${zoneData ? 'defined' : ''}`}
                                                onClick={handleDefineZone}
                                            >
                                                {zoneData ? <Check size={16} /> : 'Define'}
                                            </button>
                                        </div>

                                        <div className={`apt-setup-card ${doorData ? 'defined' : ''}`}>
                                            <div className="setup-card-info">
                                                <div className="setup-card-icon-wrapper">
                                                    <Key size={18} />
                                                </div>
                                                <div className="setup-card-text">
                                                    <span className="setup-title">Front Entrance Door</span>
                                                    <span className={`setup-status ${doorData ? 'defined' : ''}`}>
                                                        {doorData ? 'Door selected' : 'Not selected'}
                                                    </span>
                                                </div>
                                            </div>
                                            <button
                                                type="button"
                                                className={`setup-btn ${doorData ? 'defined' : ''}`}
                                                onClick={handlePickDoor}
                                            >
                                                {doorData ? <Check size={16} /> : 'Select'}
                                            </button>
                                        </div>

                                        <div className={`apt-setup-card ${spawnData ? 'defined' : ''}`}>
                                            <div className="setup-card-info">
                                                <div className="setup-card-icon-wrapper">
                                                    <Compass size={18} />
                                                </div>
                                                <div className="setup-card-text">
                                                    <span className="setup-title">Spawn / Interior Location</span>
                                                    <span className={`setup-status ${spawnData ? 'defined' : ''}`}>
                                                        {spawnData ? 'Spawn set successfully' : 'Not set'}
                                                    </span>
                                                </div>
                                            </div>
                                            <button
                                                type="button"
                                                className={`setup-btn ${spawnData ? 'defined' : ''}`}
                                                onClick={handleDefineSpawn}
                                            >
                                                {spawnData ? <Check size={16} /> : 'Capture'}
                                            </button>
                                        </div>

                                        <div className={`apt-setup-card ${tabletData ? 'defined' : ''}`}>
                                            <div className="setup-card-info">
                                                <div className="setup-card-icon-wrapper">
                                                    <Tablet size={18} />
                                                </div>
                                                <div className="setup-card-text">
                                                    <span className="setup-title">Default Tablet (Optional)</span>
                                                    <span className={`setup-status ${tabletData ? 'defined' : ''}`}>
                                                        {tabletData ? 'Tablet position set' : 'Not set'}
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
                                                    {tabletData ? <Check size={16} /> : 'Set Position'}
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
                                        <span>Save Changes</span>
                                    </button>
                                </form>
                            ) : (
                                <div className="apt-empty-state">
                                    <Info size={48} className="empty-icon" />
                                    <h3>No Apartment Selected</h3>
                                    <p>Choose an apartment from the list on the left to start editing its zones and locations.</p>
                                </div>
                            )}
                        </div>
                    </div>
                ) : (
                    <>
                        <div className="apt-creator-header">
                            <div className="apt-header-title">
                                <Building size={20} className="header-icon" />
                                <span>Apartment Creator</span>
                            </div>
                            <button className="apt-close-btn" onClick={onClose}>
                                <X size={18} />
                            </button>
                        </div>

                        <form className="apt-creator-form" onSubmit={handleSubmit}>
                            <div className="apt-input-group">
                                <label className="apt-input-label">
                                    <Building size={14} /> Room Number / ID
                                </label>
                                <input
                                    type="number"
                                    placeholder="e.g. 105"
                                    value={roomId}
                                    onChange={(e) => setRoomId(e.target.value)}
                                    required
                                    className="apt-input"
                                />
                            </div>

                            <div className="apt-setup-cards">
                                <div className={`apt-setup-card ${zoneData ? 'defined' : ''}`}>
                                    <div className="setup-card-info">
                                        <div className="setup-card-icon-wrapper">
                                            <MapPin size={18} />
                                        </div>
                                        <div className="setup-card-text">
                                            <span className="setup-title">Apartment Zone</span>
                                            <span className={`setup-status ${zoneData ? 'defined' : ''}`}>
                                                {zoneData ? 'Defined successfully' : 'Not defined'}
                                            </span>
                                        </div>
                                    </div>
                                    <button
                                        type="button"
                                        className={`setup-btn ${zoneData ? 'defined' : ''}`}
                                        onClick={handleDefineZone}
                                    >
                                        {zoneData ? <Check size={16} /> : 'Define'}
                                    </button>
                                </div>

                                <div className={`apt-setup-card ${doorData ? 'defined' : ''}`}>
                                    <div className="setup-card-info">
                                        <div className="setup-card-icon-wrapper">
                                            <Key size={18} />
                                        </div>
                                        <div className="setup-card-text">
                                            <span className="setup-title">Front Entrance Door</span>
                                            <span className={`setup-status ${doorData ? 'defined' : ''}`}>
                                                {doorData ? 'Door selected' : 'Not selected'}
                                            </span>
                                        </div>
                                    </div>
                                    <button
                                        type="button"
                                        className={`setup-btn ${doorData ? 'defined' : ''}`}
                                        onClick={handlePickDoor}
                                    >
                                        {doorData ? <Check size={16} /> : 'Select'}
                                    </button>
                                </div>

                                <div className={`apt-setup-card ${spawnData ? 'defined' : ''}`}>
                                    <div className="setup-card-info">
                                        <div className="setup-card-icon-wrapper">
                                            <Compass size={18} />
                                        </div>
                                        <div className="setup-card-text">
                                            <span className="setup-title">Spawn / Interior Location</span>
                                            <span className={`setup-status ${spawnData ? 'defined' : ''}`}>
                                                {spawnData ? 'Spawn set successfully' : 'Not set'}
                                            </span>
                                        </div>
                                    </div>
                                    <button
                                        type="button"
                                        className={`setup-btn ${spawnData ? 'defined' : ''}`}
                                        onClick={handleDefineSpawn}
                                    >
                                        {spawnData ? <Check size={16} /> : 'Capture'}
                                    </button>
                                </div>

                                <div className={`apt-setup-card ${tabletData ? 'defined' : ''}`}>
                                    <div className="setup-card-info">
                                        <div className="setup-card-icon-wrapper">
                                            <Tablet size={18} />
                                        </div>
                                        <div className="setup-card-text">
                                            <span className="setup-title">Default Tablet (Optional)</span>
                                            <span className={`setup-status ${tabletData ? 'defined' : ''}`}>
                                                {tabletData ? 'Tablet position set' : 'Not set'}
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
                                            {tabletData ? <Check size={16} /> : 'Set Position'}
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
                                <span>Create Starter Apartment</span>
                            </button>
                        </form>
                    </>
                )}
            </motion.div>

            {freecamMode && isPlacingTablet && (
                <div className="freecam-hint with-placement apt-creator-placement">
                    <span>[LEFT ALT] Exit Cam | [BACKSPACE] Exit Cam</span>
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
                        <span className="controls-title">Default Tablet Position</span>
                        <div className="controls-actions">
                            <div className="controls-hint">
                                <Move size={14} /> <span>Drag | [LALT] Cam | [G] Ground</span>
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
                            <span>Place on Ground</span>
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
                        }}>Confirm</button>
                        <button className="stop-btn" onClick={() => {
                            if (window.GetParentResourceName) {
                                fetch(`https://${window.GetParentResourceName()}/stopPlacementTablet`, {
                                    method: 'POST',
                                    body: JSON.stringify({ save: false })
                                });
                            } else {
                                setIsPlacingTablet(false);
                            }
                        }}>Cancel</button>
                    </div>
                </div>
            )}
        </>
    );
};

export default ApartmentCreator;
