import React, { useState, useEffect } from 'react';
import { Sofa, Bed, Lamp, Tv, Utensils, Bath, Search, Package, Check, Trash2, Camera, Move, RotateCw, X, ShoppingCart, ShoppingBag, Hammer, Palette, ArrowLeft, Grid } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import Modeler3D from './Modeler3D';
import './FurnitureMenu.css';

const FurnitureMenu = ({ items = [], ownedItems = [] }) => {
  const [activeCategory, setActiveCategory] = useState('all');
  const [activeTab, setActiveTab] = useState('shopping'); // shopping, editor, cart
  const [cart, setCart] = useState([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [isPlacing, setIsPlacing] = useState(false);
  const [placingItem, setPlacingItem] = useState(null);
  const [freecamMode, setFreecamMode] = useState(false);

  useEffect(() => {
    if (items.length > 0 && !activeCategory) {
      setActiveCategory('all');
    }
  }, [items, activeCategory]);

  useEffect(() => {
    const handleMessage = (event) => {
      if (event.data.action === 'freecamMode') {
        setFreecamMode(event.data.data);
      } else if (event.data.action === 'selectFurniture') {
        setIsPlacing(true);
        setPlacingItem(event.data.data);
      }
    };

    const handleKeyDown = (e) => {
      // Ignore key events when the user is typing in inputs or textareas to prevent interface issues
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.isContentEditable) {
        return;
      }

      if (e.key === 'Alt') {
        const next = !freecamMode;
        setFreecamMode(next);
        post('freecamMode', next);
      } else if (e.key === 'Backspace') {
        const newState = !freecamMode;
        setFreecamMode(newState);
        post('freecamMode', newState);
      }
    };

    window.addEventListener('message', handleMessage);
    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.removeEventListener('message', handleMessage);
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [freecamMode]);

  const IconMap = {
    Sofa: Sofa,
    Bed: Bed,
    Lamp: Lamp,
    Tv: Tv,
    Utensils: Utensils,
    Bath: Bath,
    Package: Package
  };

  const categories = Array.isArray(items) ? items.map(cat => ({
    id: cat.id,
    label: cat.label,
    icon: IconMap[cat.icon] || Package
  })) : [];

  const activeCategoryData = Array.isArray(items) ? items.find(cat => cat.id === activeCategory) : null;

  const filteredItems = (() => {
    if (activeCategory === 'all') {
      const all = [];
      items.forEach(cat => {
        if (cat.items) {
          cat.items.forEach(item => {
            all.push({ ...item, categoryId: cat.id });
          });
        }
      });
      return all.filter(item =>
        item.label.toLowerCase().includes(searchQuery.toLowerCase())
      );
    } else {
      return (activeCategoryData?.items || []).filter(item =>
        item.label.toLowerCase().includes(searchQuery.toLowerCase())
      );
    }
  })();

  const getItemIcon = (item) => {
    const catId = item.categoryId || item.category || activeCategory;
    const cat = items.find(c => c.id === catId);
    const iconName = cat ? cat.icon : 'Package';
    return IconMap[iconName] || Package;
  };

  const post = (action, data = {}) => {
    if (window.GetParentResourceName) {
      fetch(`https://${window.GetParentResourceName()}/${action}`, {
        method: 'POST',
        body: JSON.stringify(data)
      });
    }
  };

  const handlePreview = (item) => {
    if (isPlacing) return;
    setIsPlacing(true);
    setPlacingItem(item);
    post('previewFurniture', item);
  };

  const handleAddToCart = (item) => {
    const catId = item.categoryId || activeCategory;
    post('addToCart', { ...item, category: catId });
    setCart([...cart, { ...item, category: catId }]);
    setIsPlacing(false);
    setPlacingItem(null);
  };

  const handleBuy = () => {
    post('buyCartItems', { items: cart });
    setCart([]);
    setActiveTab('shopping');
  };



  const handleClose = () => {
    post('closeUI');
  };

  return (
    <motion.div
      className="furniture-sidebar-container"
      initial={{ x: -400, opacity: 0 }}
      animate={{ x: 0, opacity: 1 }}
      exit={{ x: -400, opacity: 0 }}
    >
      <div className="sidebar-header">
        <button
          className={`main-tab ${activeTab === 'shopping' || activeTab === 'cart' ? 'active' : ''} ${isPlacing ? 'disabled' : ''}`}
          onClick={() => !isPlacing && setActiveTab('shopping')}
          disabled={isPlacing}
        >
          <ShoppingBag size={18} />
          <span>SHOPPING</span>
        </button>
        <button
          className={`main-tab ${activeTab === 'editor' ? 'active' : ''} ${isPlacing ? 'disabled' : ''}`}
          onClick={() => !isPlacing && setActiveTab('editor')}
          disabled={isPlacing}
        >
          <Hammer size={18} />
          <span>EDITOR</span>
        </button>
      </div>

      <AnimatePresence mode="wait">
        <motion.div
          className="sidebar-content"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          key={activeTab}
        >
          {(activeTab === 'shopping' || activeTab === 'cart') && (
            <>
              <div className="categories-section">
                <div className="category-grid">
                  <button
                    className={`cat-icon-btn ${activeCategory === 'all' && activeTab !== 'cart' ? 'active' : ''} ${isPlacing ? 'disabled' : ''}`}
                    onClick={() => {
                      if (isPlacing) return;
                      setActiveCategory('all');
                      setActiveTab('shopping');
                    }}
                    disabled={isPlacing}
                    title="All Categories"
                  >
                    <Grid size={18} />
                  </button>
                  {categories.map((cat) => (
                    <button
                      key={cat.id}
                      className={`cat-icon-btn ${activeCategory === cat.id && activeTab !== 'cart' ? 'active' : ''} ${isPlacing ? 'disabled' : ''}`}
                      onClick={() => {
                        if (isPlacing) return;
                        setActiveCategory(cat.id);
                        setActiveTab('shopping');
                      }}
                      disabled={isPlacing}
                      title={cat.label}
                    >
                      <cat.icon size={18} />
                    </button>
                  ))}
                  <button
                    className={`cat-icon-btn cart-btn ${activeTab === 'cart' ? 'active' : ''} ${isPlacing ? 'disabled' : ''}`}
                    onClick={() => !isPlacing && setActiveTab('cart')}
                    disabled={isPlacing}
                    title="View Cart"
                  >
                    <ShoppingCart size={18} />
                    {cart.length > 0 && <span className="cart-badge">{cart.length}</span>}
                  </button>
                </div>
              </div>

              {activeTab === 'shopping' ? (
                <>
                  <div className={`search-bar ${isPlacing ? 'disabled' : ''}`} style={{ opacity: isPlacing ? 0.5 : 1, pointerEvents: isPlacing ? 'none' : 'auto' }}>
                    <Search size={16} className="search-icon" />
                    <input
                      placeholder="Search furniture..."
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      disabled={isPlacing}
                    />
                  </div>

                  <div className="category-title">
                    {activeCategory === 'all' ? 'ALL FURNITURE' : (activeCategoryData?.label?.toUpperCase() || 'ITEMS')}
                  </div>

                  <div className="items-grid-scroll" key={`${activeTab}-${activeCategory}`}>
                    <div className="items-grid">
                      <AnimatePresence mode="popLayout">
                        {filteredItems.map((item) => {
                          const ItemIcon = getItemIcon(item);
                          const itemKey = `${item.categoryId || activeCategory}-${item.id}`;
                          return (
                            <motion.div
                              key={itemKey}
                              className={`item-card ${isPlacing ? (placingItem?.id === item.id ? 'is-placing' : 'disabled') : ''}`}
                              initial={{ scale: 0.95, opacity: 0 }}
                              animate={{ scale: 1, opacity: 1 }}
                              exit={{ scale: 0.95, opacity: 0 }}
                              onMouseEnter={() => !isPlacing && post('hoverIn', item)}
                              onMouseLeave={() => !isPlacing && post('hoverOut')}
                              onClick={() => handlePreview(item)}
                            >
                              <div className="icon-wrapper">
                                <ItemIcon size={28} className="placeholder" />
                              </div>
                              {isPlacing && placingItem?.id === item.id && (
                                <div className="palette-badge">
                                  <Palette size={12} />
                                </div>
                              )}
                              <span className="item-card-price">${item.price}</span>
                            </motion.div>
                          );
                        })}
                      </AnimatePresence>
                    </div>
                  </div>
                </>
              ) : (
                <div className="cart-view">
                  <div className="category-title">
                    <button className="back-btn" onClick={() => setActiveTab('shopping')}>
                      <ArrowLeft size={16} />
                    </button>
                    SHOPPING CART
                  </div>

                  {cart.length === 0 ? (
                    <div className="empty-state">
                      <ShoppingCart size={40} />
                      <p>Your cart is empty</p>
                    </div>
                  ) : (
                    <>
                      <div className="cart-items-list">
                        {cart.map((item, idx) => (
                          <div key={idx} className="cart-list-item">
                            <span className="cart-item-name">{item.label}</span>
                            <span className="cart-item-price">${item.price}</span>
                            <button className="remove-btn" onClick={() => {
                              const newCart = [...cart];
                              newCart.splice(idx, 1);
                              setCart(newCart);
                            }}><Trash2 size={14} /></button>
                          </div>
                        ))}
                      </div>
                      <div className="cart-footer">
                        <div className="cart-total">Total: ${cart.reduce((acc, item) => acc + item.price, 0)}</div>
                        <button className="checkout-btn" onClick={handleBuy}>CONFIRM PURCHASE</button>
                      </div>
                    </>
                  )}
                </div>
              )}
            </>
          )}

          {activeTab === 'editor' && (
            <div className="editor-view">
              <div className="category-title">OWNED FURNITURE</div>

              {ownedItems.length === 0 ? (
                <div className="empty-state">
                  <Hammer size={40} />
                  <p>No furniture placed.</p>
                </div>
              ) : (
                <div className="items-grid-scroll">
                  <div className="items-grid">
                    {ownedItems.map((item, idx) => {
                      const ItemIcon = getItemIcon(item);
                      return (
                        <div
                          key={idx}
                          className={`item-card ${isPlacing ? (placingItem?.id === item.id ? 'is-placing' : 'disabled') : ''}`}
                          onClick={() => handlePreview(item)}
                        >
                          <div className="icon-wrapper">
                            <ItemIcon size={28} className="placeholder" />
                          </div>
                          <div className="owned-badge">
                            <Check size={12} />
                          </div>
                          <button className="delete-icon-btn" disabled={isPlacing} onClick={(e) => {
                            if (isPlacing) return;
                            e.stopPropagation();
                            post('removeOwnedItem', item);
                          }}>
                            <Trash2 size={14} />
                          </button>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}
            </div>
          )}
        </motion.div>
      </AnimatePresence>

      {freecamMode && (
        <div className={`freecam-hint ${isPlacing ? 'with-placement' : ''}`}>
          <span>[LEFT ALT] Exit Cam | [BACKSPACE] Exit Cam</span>
        </div>
      )}

      <Modeler3D
        active={isPlacing}
        onUpdate={(data) => {
          post('moveObject', data.position);
          post('rotateObject', data.rotation);
        }}
      />

      {isPlacing && (
        <div className="placement-controls">
          <div className="controls-header">
            <span className="controls-title">3D Placement</span>
            <div className="controls-actions">
              <div className="controls-hint">
                <Move size={14} /> <span>Drag arrows | [LALT] Cam</span>
              </div>
            </div>
          </div>

          <div className="controls-footer">
            <button className="confirm-btn" onClick={() => {
              if (activeTab === 'shopping' && placingItem) {
                handleAddToCart(placingItem);
              } else {
                setIsPlacing(false);
                setPlacingItem(null);
                post('stopPlacement', { save: true });
              }
            }}>Confirm</button>
            <button className="stop-btn" onClick={() => {
              setIsPlacing(false);
              setPlacingItem(null);
              post('stopPlacement');
            }}>Cancel</button>
          </div>
        </div>
      )}
    </motion.div>
  );
};

export default FurnitureMenu;
