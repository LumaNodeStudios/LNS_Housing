import React, { useState, useEffect } from 'react';
import './index.css';
import Panel from './components/Panel/Panel';
import FurnitureMenu from './components/Furniture/FurnitureMenu';
import RealEstate from './components/RealEstate/RealEstate';
import ContractPaper from './components/RealEstate/ContractPaper';
import ApartmentCreator from './components/ApartmentCreator/ApartmentCreator';
import ScreenshotProgress from './components/ScreenshotProgress/ScreenshotProgress';
import { AnimatePresence } from 'framer-motion';

function App() {
  const [showPanel, setShowPanel] = useState(false);
  const [showFurniture, setShowFurniture] = useState(false);
  const [showRealEstate, setShowRealEstate] = useState(true);
  const [showContractPaper, setShowContractPaper] = useState(false);
  const [contractPaperData, setContractPaperData] = useState(null);
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
    setShowContractPaper(false);
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
          setIsVisible(true);
          setHasPermission(true);
          setInitialTab('creator');
          setOnlyBuyViaContracts(data?.onlyBuyViaContracts || false);
          setShells(data?.shells || []);
          setShowRealEstate(true);
          break;
        case 'openRealEstate':
          closeAll();
          setIsVisible(true);
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
        case 'toggleVisibility':
          setIsVisible(data?.visible ?? (typeof data === 'boolean' ? data : true));
          break;
        case 'openContractPaper':
          closeAll();
          setIsVisible(true);
          setContractPaperData(data);
          setShowContractPaper(true);
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
            setIsVisible(true);
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
      setContractPaperData({
        id: 1,
        agent_name: 'Marcus Vance',
        client_name: 'Jordan Kahaku',
        property_label: '222 7 Eclipse Apartment',
        price: 500,
        type: 'rent',
        garage: 0,
        agency_label: 'Dynasty 8 Real Estate',
        date: new Date().toLocaleDateString('en-US', { day: '2-digit', month: 'short', year: 'numeric' })
      });

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
            { id: 'coffee_table', label: 'Oak Coffee Table', model: 'prop_coffee_table_02', price: 250 }
          ]
        },
        {
          id: 'bedroom',
          label: 'Bedroom',
          icon: 'Bed',
          items: [
            { id: 'bed_king', label: 'King Bed', model: 'v_res_d_bed', price: 1200 },
            { id: 'wardrobe', label: 'Wood Closet', model: 'prop_wardrobe_01', price: 600 }
          ]
        },
        {
          id: 'kitchen',
          label: 'Kitchen',
          icon: 'Utensils',
          items: [
            { id: 'fridge', label: 'Steel Fridge', model: 'prop_fridge_01', price: 800 }
          ]
        },
        {
          id: 'office',
          label: 'Office',
          icon: 'Briefcase',
          items: [
            { id: 'desk', label: 'Executive Desk', model: 'prop_office_desk_01', price: 750 }
          ]
        },
        {
          id: 'lighting',
          label: 'Lighting',
          icon: 'Lamp',
          items: [
            { id: 'floor_lamp', label: 'Tall Lamp', model: 'v_ilev_m_lampstand', price: 150 }
          ]
        },
        {
          id: 'decor',
          label: 'Decor',
          icon: 'Palette',
          items: [
            { id: 'plant', label: 'House Plant', model: 'prop_plant_int_01a', price: 80 }
          ]
        }
      ]);

      setAllProperties({
        1: {
          id: 1,
          label: '222 7 Eclipse Apartment',
          region: 'Vinewood Hills',
          price: 500,
          sale_type: 'rent',
          type: 'Apartment',
          garage: 0,
          size: 40,
          image: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/3671WhispymoundDr-GTAOe.webp',
          owner: null,
          metadata: { shell: 'Eclipse Apartment 22' }
        },
        2: {
          id: 2,
          label: '458 Richman Mansion',
          region: 'Richman',
          price: 1200000,
          sale_type: 'direct',
          type: 'Residential',
          garage: 6,
          size: 6500,
          image: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/3671WhispymoundDr-GTAOe.webp',
          owner: null
        },
        3: {
          id: 3,
          label: '702 Eclipse Penthouse',
          region: 'Vinewood Hills',
          price: 850000,
          sale_type: 'auction',
          type: 'Residential',
          garage: 4,
          size: 3200,
          image: 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/3671WhispymoundDr-GTAOe.webp',
          owner: null,
          auction_data: { current_bid: 920000, status: 'live' }
        }
      });
    }
  }, []);

  return (
    <div className="app-container" style={{ display: isVisible ? 'block' : 'none' }}>
      {screenshotProgress && (
        <ScreenshotProgress
          current={screenshotProgress.current}
          total={screenshotProgress.total}
          model={screenshotProgress.model}
        />
      )}
      <div className="ui-wrapper" style={{ display: isVisible ? 'flex' : 'none' }}>
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
        </AnimatePresence>
      </div>
    </div>
  );
}

export default App;