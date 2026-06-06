import React, { useState, useEffect } from 'react';
import './ApartmentCreator.css';
import { motion } from 'framer-motion';
import { Building, MapPin, Key, Compass, Save, X, Check } from 'lucide-react';

const ApartmentCreator = ({ onClose }) => {
    const [roomId, setRoomId] = useState('');
    const [zoneData, setZoneData] = useState(null);
    const [doorData, setDoorData] = useState(null);
    const [spawnData, setSpawnData] = useState(null);
    const [errorMsg, setErrorMsg] = useState('');

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
            // Mock zone points for browser
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
            // Mock door for browser
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
            // Mock spawn point for browser
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

    const handleCreateApartment = (e) => {
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
            alert(`Apartment Room #${numericId} created successfully in mock environment!`);
            onClose();
            return;
        }

        // Check if roomId already exists
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

                // Submit to creator NUI callback
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
    };

    const canSubmit = roomId && zoneData && doorData && spawnData;

    return (
        <motion.div
            className="apt-creator-modal glass-heavy"
            initial={{ opacity: 0, scale: 0.95, y: 15 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 15 }}
            transition={{ duration: 0.2, ease: 'easeOut' }}
        >
            <div className="apt-creator-header">
                <div className="apt-header-title">
                    <Building size={20} className="header-icon" />
                    <span>Apartment Creator</span>
                </div>
                <button className="apt-close-btn" onClick={onClose}>
                    <X size={18} />
                </button>
            </div>

            <form className="apt-creator-form" onSubmit={handleCreateApartment}>
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
        </motion.div>
    );
};

export default ApartmentCreator;
