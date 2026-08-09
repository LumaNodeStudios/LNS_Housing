import React, { useState } from 'react';
import './ContractPaper.css';
import { motion } from 'framer-motion';
import {
    CheckCircle2,
    X,
    Building2,
    Calendar,
    ShieldCheck,
    Check,
    PenTool
} from 'lucide-react';

const AGENCY_MAPPINGS = {
    'realestate': 'Dynasty 8 Real Estate',
    'luxuryestate': 'Luxury Real Estate',
    'dynasty8': 'Dynasty 8 Real Estate',
    'luxury': 'Luxury Real Estate'
};

const resolveAgencyName = (contract) => {
    if (!contract) return 'DYNASTY 8 REAL ESTATE';
    if (contract.agency_label) return contract.agency_label;
    if (contract.agencyLabel) return contract.agencyLabel;
    if (contract.agency_name) return contract.agency_name;
    const raw = String(contract.agency || contract.job || 'realestate').toLowerCase();
    if (AGENCY_MAPPINGS[raw]) return AGENCY_MAPPINGS[raw];
    return raw
        .split('_')
        .map(w => w.charAt(0).toUpperCase() + w.slice(1))
        .join(' ') + ' Real Estate';
};

const ContractPaper = ({ contract, onClose, onRespond }) => {
    const [isSigning, setIsSigning] = useState(false);
    const [isSigned, setIsSigned] = useState(!!contract?.signed);

    if (!contract) return null;

    const handleCloseNui = () => {
        if (window.GetParentResourceName) {
            fetch(`https://${window.GetParentResourceName()}/closeUI`, {
                method: 'POST',
                body: JSON.stringify({})
            });
        }
        if (onClose) onClose();
    };

    const handleSignContract = () => {
        if (isSigning || isSigned) return;
        setIsSigning(true);
        setTimeout(() => {
            setIsSigning(false);
            setIsSigned(true);
            if (onRespond && contract.id && contract.id !== 'draft_preview') {
                onRespond(contract.id, 'accept');
            }
            handleCloseNui();
        }, 900);
    };

    const handleDeclineContract = () => {
        if (onRespond && contract.id && contract.id !== 'draft_preview') {
            onRespond(contract.id, 'decline');
        }
        handleCloseNui();
    };

    // Live In-Game Data Extraction
    let meta = contract.property_metadata || contract.metadata;
    if (typeof meta === 'string') {
        try { meta = JSON.parse(meta); } catch (e) { meta = {}; }
    }
    meta = meta || {};

    const agencyName = resolveAgencyName(contract);
    const agentName = contract.agent_name || contract.realtorName || 'Marcus Vance';
    const clientName = contract.client_name || contract.buyerName || contract.tenantName || 'Jordan Kahaku';
    const propertyLabel = contract.property_label || contract.property_name || contract.label || 'Property Listing';

    // Live Garage Extraction
    const rawGarage = contract.garage !== undefined
        ? contract.garage
        : (contract.garage_slots !== undefined
            ? contract.garage_slots
            : (contract.slots !== undefined
                ? contract.slots
                : (meta.garage !== undefined ? meta.garage : meta.garage_slots)));
    const garageSlots = (rawGarage !== undefined && rawGarage !== null) ? parseInt(rawGarage) : 0;

    const priceAmount = tonumberSafe(contract.price);
    const isRent = contract.type === 'rent' || contract.sale_type === 'rent';
    const depositAmount = contract.deposit !== undefined ? tonumberSafe(contract.deposit) : (isRent ? Math.floor(priceAmount * 0.2) : 0);
    const totalUpfront = isRent ? (priceAmount + depositAmount) : priceAmount;
    const dateFormatted = contract.date || new Date().toLocaleDateString('en-US', { day: '2-digit', month: 'short', year: 'numeric' });
    const contractRef = contract.id ? `REF-#D8-${String(contract.id).toUpperCase().slice(-6)}` : `REF-#D8-CONTRACT`;

    return (
        <div className="re-paper-overlay">
            <motion.div
                className="re-paper-document"
                initial={{ opacity: 0, scale: 0.94, y: 30 }}
                animate={{ opacity: 1, scale: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.94, y: 30 }}
                onClick={(e) => e.stopPropagation()}
                transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
            >
                {/* Crest Header */}
                <div className="doc-crest-header">
                    <div className="doc-crest-logo">
                        <Building2 size={18} />
                    </div>
                    <div className="doc-crest-title">{agencyName.toUpperCase()}</div>
                    <div className="doc-crest-sub">LICENSED REAL ESTATE INSTRUMENT</div>
                    <div className="doc-header-divider">
                        <span className="divider-line" />
                        <span className="divider-badge">OFFICIAL INSTRUMENT</span>
                        <span className="divider-line" />
                    </div>
                </div>

                {/* Metadata Row */}
                <div className="doc-meta-row">
                    <div className="doc-meta-item">
                        <span className="meta-lbl">DOCUMENT ID</span>
                        <span className="meta-val">{contractRef}</span>
                    </div>
                    <div className="doc-meta-item right">
                        <span className="meta-lbl">EXECUTION DATE</span>
                        <span className="meta-val"><Calendar size={9} /> {dateFormatted}</span>
                    </div>
                </div>

                {/* Main Heading & Status Bar */}
                <div className="doc-title-row">
                    <h1 className="doc-main-heading">
                        {isRent ? 'RESIDENTIAL LEASE AGREEMENT' : 'PROPERTY PURCHASE DEED'}
                    </h1>
                    <div className={`doc-status-pill ${isSigned ? 'signed' : 'pending'}`}>
                        {isSigned ? <CheckCircle2 size={11} /> : <ShieldCheck size={11} />}
                        <span>{isSigned ? 'EXECUTED & VALIDATED' : 'AWAITING SIGNATURE'}</span>
                    </div>
                </div>

                {/* Legal Preamble */}
                <p className="doc-paragraph preamble">
                    This Agreement is entered into on <strong>{dateFormatted}</strong> by and between <strong>{agencyName}</strong> (Realtor <strong>{agentName}</strong>), hereinafter the <em>Lessor/Seller</em>, and <strong>{clientName}</strong>, hereinafter the <em>Lessee/Buyer</em>.
                </p>

                {/* Official Deed Summary Table - Single Column Stacked */}
                <div className="doc-summary-table">
                    <div className="table-row">
                        <span className="cell-lbl">Issuing Agency</span>
                        <span className="cell-val">{agencyName}</span>
                    </div>
                    <div className="table-row">
                        <span className="cell-lbl">Property Address</span>
                        <span className="cell-val">{propertyLabel}</span>
                    </div>
                    <div className="table-row">
                        <span className="cell-lbl">Garage Parking</span>
                        <span className="cell-val">{garageSlots > 0 ? `${garageSlots} Slot${garageSlots > 1 ? 's' : ''}` : 'No'}</span>
                    </div>
                    <div className="table-row">
                        <span className="cell-lbl">{isRent ? 'Weekly Lease Rate' : 'Total Purchase Price'}</span>
                        <span className="cell-val">${priceAmount.toLocaleString()}</span>
                    </div>
                    {isRent && (
                        <div className="table-row">
                            <span className="cell-lbl">Security Deposit</span>
                            <span className="cell-val">${depositAmount.toLocaleString()}</span>
                        </div>
                    )}
                    <div className="table-row total">
                        <span className="cell-lbl">Total Upfront Due</span>
                        <span className="cell-val">${totalUpfront.toLocaleString()}</span>
                    </div>
                </div>

                {/* Governing Terms & Covenants Note */}
                <p className="doc-paragraph terms-note">
                    <strong>COVENANTS & GOVERNING LAW:</strong> Occupancy and title conveyance are subject to San Andreas real estate regulations. Lessee/Buyer agrees to maintain payment obligations. Failure to comply may result in automated repossession or legal eviction.
                </p>

                {/* Formal Signature Blocks */}
                <div className="doc-signatures-wrapper">
                    <div className="sig-column">
                        <span className="sig-header">AUTHORIZED REALTOR SIGNATURE</span>
                        <div className="sig-cursive-area">
                            <span className="sig-handwritten agent">{agentName}</span>
                        </div>
                        <div className="sig-underline" />
                        <span className="sig-caption">{agencyName} Agent</span>
                    </div>

                    <div className="sig-column">
                        <span className="sig-header">LESSEE / BUYER SIGNATURE</span>
                        <div className="sig-cursive-area">
                            {isSigned ? (
                                <motion.span
                                    className="sig-handwritten client"
                                    initial={{ opacity: 0, scale: 0.85 }}
                                    animate={{ opacity: 1, scale: 1 }}
                                    transition={{ duration: 0.3 }}
                                >
                                    {clientName}
                                </motion.span>
                            ) : (
                                <button
                                    type="button"
                                    className={`sig-action-btn ${isSigning ? 'signing' : ''}`}
                                    onClick={handleSignContract}
                                >
                                    <span>{isSigning ? 'Signing...' : 'Click Here to Sign Document'}</span>
                                </button>
                            )}
                        </div>
                        <div className="sig-underline" />
                        <span className="sig-caption">Client: {clientName}</span>
                    </div>
                </div>

                {/* Bottom Action Footer */}
                <div className="doc-footer-actions">
                    <button type="button" className="doc-btn decline" onClick={handleDeclineContract}>
                        <span>Decline Contract</span>
                    </button>

                    <div className="footer-right">
                        {contract.id === 'draft_preview' ? (
                            <button type="button" className="doc-btn close" onClick={handleCloseNui}>
                                <span>Close Preview</span>
                            </button>
                        ) : isSigned ? (
                            <button type="button" className="doc-btn close" onClick={handleCloseNui}>
                                <span>Close Document</span>
                            </button>
                        ) : (
                            <button
                                type="button"
                                className="doc-btn sign"
                                onClick={handleSignContract}
                                disabled={isSigning}
                            >
                                <span>{isSigning ? 'Signing...' : 'Sign & Accept Contract'}</span>
                            </button>
                        )}
                    </div>
                </div>
            </motion.div>
        </div>
    );
};

const tonumberSafe = (val) => {
    if (val === undefined || val === null) return 0;
    const n = tonumber(val);
    return isNaN(n) ? 0 : n;
};

function tonumber(val) {
    const parsed = parseFloat(val);
    return isNaN(parsed) ? 0 : parsed;
}

export default ContractPaper;







