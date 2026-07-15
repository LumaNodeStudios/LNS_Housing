import React, { useState, useEffect } from 'react';
import './index.css';
import Panel from './components/Panel/Panel';
import FurnitureMenu from './components/Furniture/FurnitureMenu';
import RealEstate from './components/RealEstate/RealEstate';
import ApartmentCreator from './components/ApartmentCreator/ApartmentCreator';
import ScreenshotProgress from './components/ScreenshotProgress/ScreenshotProgress';
import { AnimatePresence } from 'framer-motion';

function App() {
  const [showPanel, setShowPanel] = useState(false);
  const [showFurniture, setShowFurniture] = useState(false);
  const [showRealEstate, setShowRealEstate] = useState(false);
  const [showApartmentCreator, setShowApartmentCreator] = useState(false);
  const [showApartmentEditor, setShowApartmentEditor] = useState(false);
  const [screenshotProgress, setScreenshotProgress] = useState(null);

  const [isVisible, setIsVisible] = useState(true);
  const [propertyData, setPropertyData] = useState(null);
  const [allProperties, setAllProperties] = useState({});
  const [furnitureData, setFurnitureData] = useState([]);
  const [ownedItems, setOwnedItems] = useState([]);
  const [hasPermission, setHasPermission] = useState(false);
  const [initialTab, setInitialTab] = useState('browse');
  const [onlyBuyViaContracts, setOnlyBuyViaContracts] = useState(false);
  const [apartmentCreatorData, setApartmentCreatorData] = useState({ isEdit: false, rooms: [] });
  const [shells, setShells] = useState([]);

  const closeAll = () => {
    setShowPanel(false);
    setShowFurniture(false);
    setShowRealEstate(false);
    setShowApartmentCreator(false);
    setShowApartmentEditor(false);
  };

  useEffect(() => {
    const handleMessage = (event) => {
      const { action, data } = event.data;

      switch (action) {
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
  }, []);

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
        </AnimatePresence>
      </div>
    </div>
  );
}

export default App;
