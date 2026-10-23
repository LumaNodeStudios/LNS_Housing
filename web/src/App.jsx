import React, { useState, useEffect } from 'react';
import './index.css';
import Panel from './components/Panel/Panel';
import FurnitureMenu from './components/Furniture/FurnitureMenu';
import RealEstate from './components/RealEstate/RealEstate';
import ContractPaper from './components/RealEstate/ContractPaper';
import ApartmentCreator from './components/ApartmentCreator/ApartmentCreator';
import ScreenshotProgress from './components/ScreenshotProgress/ScreenshotProgress';
import BreachMinigame from './components/BreachMinigame/BreachMinigame';
import StorageKeypad from './components/StorageKeypad/StorageKeypad';
import { AnimatePresence } from 'framer-motion';

const isLocalDev = typeof window !== 'undefined' && !window.GetParentResourceName;

const MOCK_ADMIN_PERMISSION = {
  allowed: true,
  job: 'realestate',
  grade: 100,
  citizenid: 'ADMIN001',
  agencyLabel: 'Dynasty 8 Real Estate',
  societyBalance: 2500000,
  defaultCommission: 10,
  permissions: {
    createHouse: true,
    draftContract: true,
    manageListings: true,
    manageEmployees: true,
  }
};

const MOCK_SHELLS = [
  { value: 'Standard Motel', label: 'Standard Motel', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/standardmotel_shell.png', type: 'shell' },
  { value: 'Modern Hotel', label: 'Modern Hotel', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/modernhotel_shell.png', type: 'shell' },
  { value: 'Apartment Furnished', label: 'Apartment Furnished', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/furnitured_midapart.png', type: 'shell' },
  { value: 'Apartment Unfurnished', label: 'Apartment Unfurnished', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_v16mid.png', type: 'shell' },
  { value: 'Apartment 2 Unfurnished', label: 'Apartment 2 Unfurnished', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_v16low.png', type: 'shell' },
  { value: 'Garage', label: 'Garage', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_garagem.png', type: 'shell' },
  { value: 'Office', label: 'Office', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_office1.png', type: 'shell' },
  { value: 'Store', label: 'Store', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_store1.png', type: 'shell' },
  { value: 'Warehouse', label: 'Warehouse', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_warehouse1.png', type: 'shell' },
  { value: 'Container', label: 'Container', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/container_shell.png', type: 'shell' },
  { value: '2 Floor House', label: '2 Floor House', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_michael.png', type: 'shell' },
  { value: 'House 1', label: 'House 1', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_frankaunt.png', type: 'shell' },
  { value: 'House 2', label: 'House 2', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_ranch.png', type: 'shell' },
  { value: 'House 3', label: 'House 3', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_lester.png', type: 'shell' },
  { value: 'House 4', label: 'House 4', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_trevor.png', type: 'shell' },
  { value: 'Trailer', label: 'Trailer', previewUrl: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_trailer.png', type: 'shell' },
  { value: 'Eclipse Penthouse 1', label: 'Eclipse Penthouse 1', previewUrl: '', type: 'ipl' },
  { value: 'Eclipse Penthouse 2', label: 'Eclipse Penthouse 2', previewUrl: '', type: 'ipl' },
  { value: 'Eclipse Penthouse 3', label: 'Eclipse Penthouse 3', previewUrl: '', type: 'ipl' }
];

const MOCK_PROPERTIES = {
  1: {
    id: 1,
    label: "3671 Whispymound Drive",
    type: "Residential",
    price: 850000,
    sale_type: "direct",
    region: "Vinewood Hills",
    slots: 2,
    size: 2400,
    owner: null,
    image: "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/3671WhispymoundDr-GTAOe.webp",
    metadata: {
      shell: "Standard Motel",
      allow_wall_colors: true
    }
  },
  2: {
    id: 2,
    label: "Eclipse Penthouse Suite",
    type: "Residential",
    price: 1500000,
    sale_type: "direct",
    region: "Rockford Hills",
    slots: 4,
    size: 4200,
    owner: null,
    image: "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/eclipse_towers.webp",
    metadata: {
      shell: "Eclipse Penthouse 1",
      allow_wall_colors: true
    }
  },
  3: {
    id: 3,
    label: "Galileo Luxury Villa",
    type: "Residential",
    price: 2200000,
    sale_type: "auction",
    region: "Richman",
    slots: 6,
    size: 5800,
    owner: null,
    image: "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/richman_mansion.webp",
    auction_data: {
      status: "active",
      current_bid: 2450000,
      bid_count: 5,
      highest_bidder: "CID99823",
      highest_bidder_name: "Michael De Santa",
      end_time: Date.now() + 86400000
    },
    metadata: {
      shell: "2 Floor House",
      allow_wall_colors: true
    }
  },
  4: {
    id: 4,
    label: "South Rockford Apartment",
    type: "Apartment",
    price: 15000,
    sale_type: "rent",
    region: "South Los Santos",
    slots: 1,
    size: 1100,
    owner: "CID54321",
    owner_name: "Franklin Clinton",
    image: "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/standardmotel_shell.png",
    metadata: {
      shell: "Apartment Furnished",
      allow_wall_colors: true,
      rent_debt: 0,
      missed_payments: 0,
      rent_history: [
        { date: "2026-10-10", amount: 15000, type: "Weekly Rent", status: "Paid" },
        { date: "2026-10-03", amount: 15000, type: "Weekly Rent", status: "Paid" }
      ]
    }
  }
};

function App() {
  const [showPanel, setShowPanel] = useState(false);
  const [showFurniture, setShowFurniture] = useState(false);
  const [showRealEstate, setShowRealEstate] = useState(false);
  const [showContractPaper, setShowContractPaper] = useState(false);
  const [contractPaperData, setContractPaperData] = useState(null);
  const [showApartmentCreator, setShowApartmentCreator] = useState(false);
  const [showApartmentEditor, setShowApartmentEditor] = useState(false);
  const [showBreachMinigame, setShowBreachMinigame] = useState(false);
  const [showStorageKeypad, setShowStorageKeypad] = useState(false);
  const [storageKeypadData, setStorageKeypadData] = useState(null);
  const [screenshotProgress, setScreenshotProgress] = useState(null);

  const [isVisible, setIsVisible] = useState(true);
  const [propertyData, setPropertyData] = useState(null);
  const [allProperties, setAllProperties] = useState(isLocalDev ? MOCK_PROPERTIES : {});
  const [furnitureData, setFurnitureData] = useState([]);
  const [ownedItems, setOwnedItems] = useState([]);
  const [hasPermission, setHasPermission] = useState(isLocalDev ? MOCK_ADMIN_PERMISSION : false);
  const [initialTab, setInitialTab] = useState('browse');
  const [onlyBuyViaContracts, setOnlyBuyViaContracts] = useState(false);
  const [apartmentCreatorData, setApartmentCreatorData] = useState({ isEdit: false, rooms: [] });
  const [shells, setShells] = useState(isLocalDev ? MOCK_SHELLS : []);
  const [electricityEnabled, setElectricityEnabled] = useState(true);

  const closeAll = () => {
    setShowPanel(false);
    setShowFurniture(false);
    if (!isLocalDev) {
      setShowRealEstate(false);
    }
    setShowContractPaper(false);
    setShowApartmentCreator(false);
    setShowApartmentEditor(false);
    setShowBreachMinigame(false);
    setShowStorageKeypad(false);
  };

  useEffect(() => {
    const handleMessage = (event) => {
      const { action, data } = event.data;

      switch (action) {
        case 'openContractPaper':
          closeAll();
          setIsVisible(true);
          setContractPaperData(data);
          setShowContractPaper(true);
          break;
        case 'openPanel':
          closeAll();
          setPropertyData(data);
          setShowPanel(true);
          break;
        case 'openCreator':
          closeAll();
          setHasPermission(true);
          setInitialTab('creator');
          setOnlyBuyViaContracts(data?.onlyBuyViaContracts || false);
          setShells(data?.shells || []);
          setElectricityEnabled(data?.electricityEnabled ?? true);
          setShowRealEstate(true);
          break;
        case 'openRealEstate':
          closeAll();
          const rawProps = data.properties || data;
          const normalizedProps = Array.isArray(rawProps)
            ? rawProps.reduce((acc, p) => { if (p && p.id !== undefined) acc[p.id] = p; return acc; }, {})
            : rawProps;
          setAllProperties(normalizedProps);
          setHasPermission(data.hasPermission ?? true);
          setInitialTab(data.activeTab || 'browse');
          setOnlyBuyViaContracts(data.onlyBuyViaContracts || false);
          setShells(data.shells || []);
          setElectricityEnabled(data.electricityEnabled ?? true);
          setShowRealEstate(true);
          break;
        case 'updateProperties':
          const normalized = Array.isArray(data)
            ? data.reduce((acc, p) => { if (p && p.id !== undefined) acc[p.id] = p; return acc; }, {})
            : data;
          setAllProperties(normalized);
          break;
        case 'setVisible':
          if (data) {
            closeAll();
            setShowFurniture(true);
          } else {
            closeAll();
          }
          break;
        case 'setFurnituresData':
          setFurnitureData(data);
          break;
        case 'setOwnedItems':
          setOwnedItems(data);
          break;
        case 'openApartmentCreator':
          closeAll();
          setApartmentCreatorData({
            isEdit: false,
            rooms: []
          });
          setShowApartmentCreator(true);
          break;
        case 'openApartmentEditor':
          closeAll();
          setApartmentCreatorData({
            isEdit: true,
            rooms: data || []
          });
          setShowApartmentEditor(true);
          break;
        case 'closeUI':
          closeAll();
          break;
        case 'openStorageKeypad':
          closeAll();
          setIsVisible(true);
          setStorageKeypadData(data);
          setShowStorageKeypad(true);
          break;
        case 'closeStorageKeypad':
          setShowStorageKeypad(false);
          break;
        case 'startBreachMinigame':
          setIsVisible(true);
          setShowBreachMinigame(true);
          break;
        case 'closeBreachMinigame':
          setShowBreachMinigame(false);
          break;
        case 'toggleVisibility':
          setIsVisible(data.visible);
          break;
        case 'startScreenshots':
          setScreenshotProgress({
            current: 0,
            total: data.total || 0,
            model: ''
          });
          setIsVisible(true);
          break;
        case 'updateScreenshotProgress':
          setScreenshotProgress({
            current: data.current || 0,
            total: data.total || 0,
            model: data.model || ''
          });
          setIsVisible(true);
          break;
        case 'endScreenshots':
          setScreenshotProgress(null);
          break;
        default:
          break;
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, []);

  useEffect(() => {
    if (!window.GetParentResourceName) {
      setFurnitureData([
        {
          id: 'living',
          label: 'Living Room',
          icon: 'Sofa',
          items: [
            { id: 'sofa_01', label: 'Modern Sofa', model: 'prop_sofa_01', price: 500 },
            { id: 'tv_unit', label: 'TV Stand', model: 'prop_tv_cabinet_03', price: 450 },
            { id: 'coffee_table', label: 'Oak Coffee Table', model: 'prop_coffee_table_02', price: 250 },
            { id: 'sofa_01', label: 'Modern Sofa', model: 'prop_sofa_01', price: 500 },
            { id: 'tv_unit', label: 'TV Stand', model: 'prop_tv_cabinet_03', price: 450 },
            { id: 'coffee_table', label: 'Oak Coffee Table', model: 'prop_coffee_table_02', price: 250 },
            { id: 'sofa_01', label: 'Modern Sofa', model: 'prop_sofa_01', price: 500 },
            { id: 'tv_unit', label: 'TV Stand', model: 'prop_tv_cabinet_03', price: 450 },
            { id: 'coffee_table', label: 'Oak Coffee Table', model: 'prop_coffee_table_02', price: 250 },
            { id: 'sofa_01', label: 'Modern Sofa', model: 'prop_sofa_01', price: 500 },
            { id: 'tv_unit', label: 'TV Stand', model: 'prop_tv_cabinet_03', price: 450 },
            { id: 'coffee_table', label: 'Oak Coffee Table', model: 'prop_coffee_table_02', price: 250 },
            { id: 'sofa_01', label: 'Modern Sofa', model: 'prop_sofa_01', price: 500 },
            { id: 'tv_unit', label: 'TV Stand', model: 'prop_tv_cabinet_03', price: 450 },
            { id: 'coffee_table', label: 'Oak Coffee Table', model: 'prop_coffee_table_02', price: 250 },
            { id: 'sofa_01', label: 'Modern Sofa', model: 'prop_sofa_01', price: 500 },
            { id: 'tv_unit', label: 'TV Stand', model: 'prop_tv_cabinet_03', price: 450 },
            { id: 'coffee_table', label: 'Oak Coffee Table', model: 'prop_coffee_table_02', price: 250 },
            { id: 'sofa_01', label: 'Modern Sofa', model: 'prop_sofa_01', price: 500 },
            { id: 'tv_unit', label: 'TV Stand', model: 'prop_tv_cabinet_03', price: 450 },
            { id: 'coffee_table', label: 'Oak Coffee Table', model: 'prop_coffee_table_02', price: 250 },
          ]
        },
        {
          id: 'bedroom',
          label: 'Bedroom',
          icon: 'Bed',
          items: [
            { id: 'bed_01', label: 'King Bed', model: 'v_res_d_bed', price: 1200 },
            { id: 'nightstand', label: 'Simple Nightstand', model: 'v_res_mbbedside', price: 150 },
          ]
        }
      ]);
      setAllProperties({
        1: {
          id: 1,
          label: 'Franklin House',
          price: 288200,
          owner: null,
          image: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/3671WhispymoundDr-GTAOe.webp',
          region: 'Strawberry',
          type: 'Residential',
          garage: 1,
          size: 1359,
          sale_type: 'direct',
          auction_data: { current_bid: 0, highest_bidder: null, status: 'none' },
          auctionEnd: '8/1/2025, 6:02:39 AM'
        },
        2: {
          id: 2,
          label: "Michael's Mansion",
          price: 4500000,
          owner: null,
          image: 'https://static.wikia.nocookie.net/gtawiki/images/4/41/Michael%27s_Mansion-GTAV.jpg',
          region: 'Rockford Hills',
          type: 'Luxury',
          garage: 10,
          size: 5200,
          sale_type: 'auction',
          auction_data: { current_bid: 4850000, highest_bidder: 'CID552', status: 'live' },
          auctionEnd: '8/20/2025, 10:00:00 PM'
        },
        3: {
          id: 3,
          label: 'Eclipse Towers, PH 3',
          price: 1500000,
          owner: null,
          image: 'https://static.wikia.nocookie.net/gtawiki/images/f/f6/EclipseTowers-GTAV.jpg',
          region: 'West Vinewood',
          type: 'Apartment',
          garage: 10,
          size: 2800,
          sale_type: 'auction',
          auction_data: { current_bid: 1650000, highest_bidder: 'CID123', status: 'live' },
          auctionEnd: '8/22/2025, 8:00:00 PM'
        },
        4: {
          id: 4,
          label: '4 Hangman Ave',
          price: 1100000,
          owner: null,
          image: 'https://static.wikia.nocookie.net/gtawiki/images/4/41/4HangmanAve-GTAV.jpg',
          region: 'Vinewood Hills',
          type: 'Residential',
          garage: 6,
          size: 3500,
          sale_type: 'auction',
          auction_data: { current_bid: 1200000, highest_bidder: 'CID99', status: 'live' },
          auctionEnd: '8/25/2025, 6:00:00 PM'
        },
        5: {
          id: 5,
          label: '3655 Wild Oats Drive',
          price: 950000,
          owner: null,
          image: 'https://static.wikia.nocookie.net/gtawiki/images/5/52/3655WildOatsDrive-GTAV-front.jpg',
          region: 'Vinewood Hills',
          type: 'Residential',
          garage: 6,
          size: 3100,
          sale_type: 'auction',
          auction_data: { current_bid: 1050000, highest_bidder: 'CID44', status: 'live' },
          auctionEnd: '8/26/2025, 9:00:00 PM'
        },
        6: {
          id: 6,
          label: 'Tinsel Towers, Apt 42',
          price: 650000,
          owner: null,
          image: 'https://static.wikia.nocookie.net/gtawiki/images/2/23/TinselTowers-GTAV.jpg',
          region: 'Rockford Hills',
          type: 'Apartment',
          garage: 10,
          size: 1800,
          sale_type: 'auction',
          auction_data: { current_bid: 700000, highest_bidder: 'CID88', status: 'live' },
          auctionEnd: '8/27/2025, 11:00:00 PM'
        },
        7: {
          id: 7,
          label: 'Del Perro Heights, Apt 7',
          price: 550000,
          owner: null,
          image: 'https://static.wikia.nocookie.net/gtawiki/images/1/12/DelPerroHeights-GTAV.jpg',
          region: 'Del Perro',
          type: 'Apartment',
          garage: 10,
          size: 1600,
          sale_type: 'auction',
          auction_data: { current_bid: 580000, highest_bidder: 'CID77', status: 'live' },
          auctionEnd: '8/28/2025, 10:00:00 PM'
        },
      });

      setPropertyData({
        id: 1,
        label: 'Luxury Villa',
        address: '123 Vinewood Hills',
        price: 2500000,
        owner: 'John Doe',
        is_rent: false,
        garage: 10,
        size: 500,
        type: 'House',
        image: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/3671WhispymoundDr-GTAOe.webp',
        residents: [
          { name: 'John Doe', citizenid: 'CID123', avatar: 'https://i.pravatar.cc/150?u=1' },
          { name: 'Jane Doe', citizenid: 'CID456', avatar: 'https://i.pravatar.cc/150?u=2' }
        ],
        security_log: [
          { action: 'Entry', user: 'John Doe', date: '2024-03-20 14:30' },
          { action: 'Lock Change', user: 'Admin', date: '2024-03-19 10:00' }
        ]
      });

      setApartmentCreatorData({
        isEdit: true,
        rooms: [
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
          },
          {
            id: 103,
            corners: [
              { x: -810.63, y: -724.74, z: 42.07 },
              { x: -810.63, y: -730.64, z: 42.07 },
              { x: -805.17, y: -730.60, z: 42.07 }
            ],
            thickness: 3.5,
            doorModel: -138454175,
            doorCoords: { x: -809.87, y: -724.61, z: 41.67 },
            doorHeading: 359.79,
            spawn: { x: -807.46, y: -727.60, z: 41.57, w: 77.47 },
            isStarter: true
          },
          {
            id: 104,
            corners: [{ x: -826.63, y: -724.74, z: 42.07 }],
            thickness: 3.5,
            doorModel: -138454175,
            doorCoords: { x: -825.87, y: -724.61, z: 41.67 },
            doorHeading: 359.79,
            spawn: { x: -823.46, y: -727.60, z: 41.57, w: 77.47 },
            isStarter: true
          },
          {
            id: 105,
            corners: [{ x: -826.63, y: -724.74, z: 42.07 }],
            thickness: 3.5,
            doorModel: -138454175,
            doorCoords: { x: -825.87, y: -724.61, z: 41.67 },
            doorHeading: 359.79,
            spawn: { x: -823.46, y: -727.60, z: 41.57, w: 77.47 },
            isStarter: true
          },
          {
            id: 106,
            corners: [{ x: -826.63, y: -724.74, z: 42.07 }],
            thickness: 3.5,
            doorModel: -138454175,
            doorCoords: { x: -825.87, y: -724.61, z: 41.67 },
            doorHeading: 359.79,
            spawn: { x: -823.46, y: -727.60, z: 41.57, w: 77.47 },
            isStarter: true
          },
          {
            id: 107,
            corners: [{ x: -826.63, y: -724.74, z: 42.07 }],
            thickness: 3.5,
            doorModel: -138454175,
            doorCoords: { x: -825.87, y: -724.61, z: 41.67 },
            doorHeading: 359.79,
            spawn: { x: -823.46, y: -727.60, z: 41.57, w: 77.47 },
            isStarter: true
          },
          {
            id: 108,
            corners: [{ x: -826.63, y: -724.74, z: 42.07 }],
            thickness: 3.5,
            doorModel: -138454175,
            doorCoords: { x: -825.87, y: -724.61, z: 41.67 },
            doorHeading: 359.79,
            spawn: { x: -823.46, y: -727.60, z: 41.57, w: 77.47 },
            isStarter: true
          },
          {
            id: 109,
            corners: [{ x: -826.63, y: -724.74, z: 42.07 }],
            thickness: 3.5,
            doorModel: -138454175,
            doorCoords: { x: -825.87, y: -724.61, z: 41.67 },
            doorHeading: 359.79,
            spawn: { x: -823.46, y: -727.60, z: 41.57, w: 77.47 },
            isStarter: true
          },
          {
            id: 110,
            corners: [{ x: -826.63, y: -724.74, z: 42.07 }],
            thickness: 3.5,
            doorModel: -138454175,
            doorCoords: { x: -825.87, y: -724.61, z: 41.67 },
            doorHeading: 359.79,
            spawn: { x: -823.46, y: -727.60, z: 41.57, w: 77.47 },
            isStarter: true
          }
        ]
      });
      setShowApartmentEditor(false);
    }

    const handleKeyDown = (e) => {
      if (e.key === 'Escape') {
        if (showBreachMinigame) {
          if (window.GetParentResourceName) {
            fetch(`https://${window.GetParentResourceName()}/breachCancel`, {
              method: 'POST',
              body: JSON.stringify({})
            });
          }
          setShowBreachMinigame(false);
          return;
        }

        if (window.GetParentResourceName) {
          fetch(`https://${window.GetParentResourceName()}/closeUI`, {
            method: 'POST',
            body: JSON.stringify({})
          });
        }
        closeAll();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [showBreachMinigame]);

  return (
    <div className="app-container" style={{ visibility: isVisible ? 'visible' : 'hidden' }}>
      <ScreenshotProgress progress={screenshotProgress} />
      <div className="ui-wrapper">
        <AnimatePresence mode="wait">
          {showPanel && (
            <Panel key="panel" data={propertyData} />
          )}

          {showFurniture && (
            <FurnitureMenu
              key="furniture"
              items={furnitureData}
              ownedItems={ownedItems}
            />
          )}

          {showRealEstate && (
            <RealEstate
              key="realestate"
              properties={allProperties}
              hasPermission={hasPermission}
              initialTab={initialTab}
              onlyBuyViaContracts={onlyBuyViaContracts}
              shells={shells}
              electricityEnabled={electricityEnabled}
              onOpenPaperContract={(contract) => {
                closeAll();
                setContractPaperData(contract);
                setShowContractPaper(true);
              }}
            />
          )}

          {showContractPaper && (
            <ContractPaper
              key="contractpaper"
              contract={contractPaperData}
              onClose={() => {
                closeAll();
              }}
              onRespond={(id, action) => {
                if (window.GetParentResourceName) {
                  fetch(`https://${window.GetParentResourceName()}/respondToContract`, {
                    method: 'POST',
                    body: JSON.stringify({ id, action })
                  });
                }
              }}
            />
          )}

          {showApartmentCreator && (
            <ApartmentCreator
              key="aptcreator"
              isEdit={false}
              initialRooms={[]}
              onClose={() => {
                if (window.GetParentResourceName) {
                  fetch(`https://${window.GetParentResourceName()}/closeUI`, {
                    method: 'POST',
                    body: JSON.stringify({})
                  });
                }
                closeAll();
              }}
            />
          )}

          {showApartmentEditor && (
            <ApartmentCreator
              key="apteditor"
              isEdit={true}
              initialRooms={apartmentCreatorData.rooms}
              onClose={() => {
                if (window.GetParentResourceName) {
                  fetch(`https://${window.GetParentResourceName()}/closeUI`, {
                    method: 'POST',
                    body: JSON.stringify({})
                  });
                }
                closeAll();
              }}
            />
          )}

          {showStorageKeypad && (
            <StorageKeypad
              key="storagekeypad"
              data={storageKeypadData}
              onClose={() => {
                setShowStorageKeypad(false);
                if (window.GetParentResourceName) {
                  fetch(`https://${window.GetParentResourceName()}/closeStorageKeypad`, {
                    method: 'POST',
                    body: JSON.stringify({})
                  });
                }
              }}
            />
          )}
        </AnimatePresence>

        <BreachMinigame active={showBreachMinigame} onClose={() => setShowBreachMinigame(false)} />
      </div>
    </div>
  );
}

export default App;