import React, { useState, useEffect } from 'react';
import './ApartmentCreator.css';
import { motion } from 'framer-motion';
import { Building, MapPin, Key, Compass, Save, X, Check, Search, Info } from 'lucide-react';

const ApartmentCreator = ({ onClose, isEdit = false, initialRooms = [] }) => {
    const [rooms, setRooms] = useState(initialRooms || []);
    const [selectedRoom, setSelectedRoom] = useState(null);
    const [searchQuery, setSearchQuery] = useState('');

    const [roomId, setRoomId] = useState('');
    const [zoneData, setZoneData] = useState(null);
    const [doorData, setDoorData] = useState(null);
    const [spawnData, setSpawnData] = useState(null);
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
        } else {
            setRoomId('');
            setZoneData(null);
            setDoorData(null);
            setSpawnData(null);
        }
    }, [selectedRoom]);

    useEffect(() => {
        const handleMessage = (event) => {
            const { action, data } = event.data;
            if (action === 'addApartmentDoor') {
                setDoorData(data);
            }
        };
        window.addEventListener('message', handleMessage);
        return () => window.removeEventListener('message', handleMessage);
    }, []);

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
                    spawn: spawnData
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
                            spawn: spawnData
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
        <motion.div
            className={`apt-creator-modal glass-heavy ${isEdit ? 'edit-mode' : ''}`}
            initial={{ opacity: 0, scale: 0.95, y: 15 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 15 }}
            transition={{ duration: 0.2, ease: 'easeOut' }}
        >
            {isEdit ? (
                <div className="apt-editor-layout">
                    {/* Left Pane: Apartment List */}
                    <div className="apt-list-pane">
                        <div className="apt-creator-header">
                            <div className="apt-header-title">
                                <Building size={20} className="header-icon" />
                                <span>Apartments List</span>
                            </div>
                        </div>
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
                        <div className="apt-rooms-list">
                            {filteredRooms.length > 0 ? (
                                filteredRooms.map((room) => (
                                    <div
                                        key={room.id}
                                        className={`apt-room-item ${selectedRoom?.id === room.id ? 'active' : ''}`}
                                        onClick={() => setSelectedRoom(room)}
                                    >
                                        <Building size={16} className="room-icon" />
                                        <div className="room-details">
                                            <span className="room-title">Apartment Room #{room.id}</span>
                                            <span className="room-subtitle">
                                                {room.isStarter ? 'Starter Apartment' : 'Custom Apartment'}
                                            </span>
                                        </div>
                                    </div>
                                ))
                            ) : (
                                <div className="apt-no-results">
                                    <span>No apartments found</span>
                                </div>
                            )}
                        </div>
                    </div>

                    {/* Right Pane: Form or Empty State */}
                    <div className="apt-form-pane">
                        <div className="apt-creator-header">
                            <div className="apt-header-title">
                                <span>Edit Apartment Details</span>
                            </div>
                            <button className="apt-close-btn" onClick={onClose}>
                                <X size={18} />
                            </button>
                        </div>

                        {selectedRoom ? (
                            <form className="apt-creator-form" onSubmit={handleSubmit}>
                                <div className="apt-input-group">
                                    <label className="apt-input-label">
                                        <Building size={14} /> Room Number / ID
                                    </label>
                                    <input
                                        type="number"
                                        value={roomId}
                                        disabled
                                        className="apt-input disabled"
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
    );
};

export default ApartmentCreator;
