import React, { useState, useEffect } from 'react';
import { Sofa, Bed, Lamp, Tv, Utensils, Bath, Search, Package, Check, Trash2, Camera, Move, RotateCw, X, ShoppingCart, ShoppingBag, Hammer, ArrowLeft, Grid, ArrowDown, CreditCard, Banknote } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import Modeler3D from './Modeler3D';
import './FurnitureMenu.css';

const FurnitureImage = ({ item, ItemIcon }) => {
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState(false);
  const imageUrl = item.imageUrl || `assets/furniture/${item.model}.png`;

  return (
    <div className="icon-wrapper">
      {!error && (
        <img
          src={imageUrl}
          alt={item.label}
          className="furniture-img"
          onLoad={() => setLoaded(true)}
          onError={() => setError(true)}
          style={{ display: loaded ? 'block' : 'none' }}
        />
      )}
      {(!loaded || error) && <ItemIcon size={28} className="placeholder" />}
    </div>
  );
};

const FurnitureMenu = ({ items = [], ownedItems = [] }) => {
  const [activeCategory, setActiveCategory] = useState('all');
  const [activeTab, setActiveTab] = useState('shopping');
  const [cart, setCart] = useState([]);
  const [showPaymentModal, setShowPaymentModal] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchQueryOwned, setSearchQueryOwned] = useState('');
  const [isPlacing, setIsPlacing] = useState(false);
  const [placingItem, setPlacingItem] = useState(null);
  const [freecamMode, setFreecamMode] = useState(false);

  useEffect(() => {
    setSearchQuery('');
    setSearchQueryOwned('');
  }, [activeTab]);

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
      } else if (event.data.action === 'addToCart') {
        setCart(prevCart => [...prevCart, event.data.data]);
      } else if (event.data.action === 'clearCart') {
        setCart([]);
      }
    };

    window.addEventListener('message', handleMessage);
    return () => {
      window.removeEventListener('message', handleMessage);
    };
  }, []);

  useEffect(() => {
    const handleKeyDown = (e) => {
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
      } else if ((e.key === 'g' || e.key === 'G') && isPlacing) {
        post('placeOnGround');
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [freecamMode, isPlacing]);

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

  const filteredOwnedItems = Array.isArray(ownedItems)
    ? ownedItems.filter(item =>
        item.label.toLowerCase().includes(searchQueryOwned.toLowerCase())
      )
    : [];

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
    post('unhoverOwnedItem');
    post('previewFurniture', item);
  };

  const handleAddToCart = (item) => {
    const catId = item.categoryId || activeCategory;
    post('addToCart', { ...item, category: catId });
    setIsPlacing(false);
    setPlacingItem(null);
  };

  const handleBuy = (paymentMethod) => {
    post('buyCartItems', { items: cart, paymentMethod });
    setCart([]);
    setActiveTab('shopping');
    setShowPaymentModal(false);
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
                              <FurnitureImage item={item} ItemIcon={ItemIcon} />
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
                  <div className="cart-header">
                    <button className="cart-back-btn" onClick={() => setActiveTab('shopping')} title="Back to Shopping">
                      <ArrowLeft size={16} />
                    </button>
                    <div className="cart-title-info">
                      <h2>SHOPPING CART</h2>
                      <span className="cart-count-badge">
                        {cart.length} {cart.length === 1 ? 'item' : 'items'}
                      </span>
                    </div>
                  </div>

                  {cart.length === 0 ? (
                    <div className="cart-empty-container">
                      <motion.div
                        className="cart-empty-glow"
                        initial={{ opacity: 0.3, scale: 0.9 }}
                        animate={{ opacity: [0.3, 0.6, 0.3], scale: [0.9, 1, 0.9] }}
                        transition={{ repeat: Infinity, duration: 4, ease: "easeInOut" }}
                      >
                        <ShoppingCart size={40} className="cart-empty-icon" />
                      </motion.div>
                      <h3 className="cart-empty-title">Your cart is empty</h3>
                      <p className="cart-empty-subtitle">Choose from our catalog to decorate your home</p>
                      <button className="cart-empty-shop-btn" onClick={() => setActiveTab('shopping')}>
                        Browse Catalog
                      </button>
                    </div>
                  ) : (
                    <>
                      <div className="cart-items-list">
                        <AnimatePresence mode="popLayout">
                          {cart.map((item, idx) => {
                            const ItemIcon = getItemIcon(item);
                            return (
                              <motion.div
                                key={item.entity || idx}
                                className="cart-list-item"
                                initial={{ opacity: 0, y: 10, scale: 0.98 }}
                                animate={{ opacity: 1, y: 0, scale: 1 }}
                                exit={{ opacity: 0, x: -50, scale: 0.95 }}
                                transition={{ duration: 0.2 }}
                              >
                                <div className="cart-item-preview">
                                  <FurnitureImage item={item} ItemIcon={ItemIcon} />
                                </div>
                                <div className="cart-item-details">
                                  <span className="cart-item-name">{item.label}</span>
                                  <span className="cart-item-meta">{item.model || 'Furniture'}</span>
                                </div>
                                <div className="cart-item-actions">
                                  <span className="cart-item-price">${item.price.toLocaleString()}</span>
                                  <button
                                    className="cart-remove-btn"
                                    onClick={() => {
                                      const newCart = [...cart];
                                      newCart.splice(idx, 1);
                                      setCart(newCart);
                                      post('removeCartItem', { entity: item.entity });
                                    }}
                                    title="Remove item"
                                  >
                                    <Trash2 size={14} />
                                  </button>
                                </div>
                              </motion.div>
                            );
                          })}
                        </AnimatePresence>
                      </div>
                      <div className="cart-footer">
                        <div className="cart-summary-details">
                          <div className="summary-row">
                            <span>Subtotal ({cart.length} {cart.length === 1 ? 'item' : 'items'})</span>
                            <span>${cart.reduce((acc, item) => acc + item.price, 0).toLocaleString()}</span>
                          </div>
                        </div>
                        <div className="cart-total-section">
                          <span className="total-label">Total Amount</span>
                          <span className="total-price">${cart.reduce((acc, item) => acc + item.price, 0).toLocaleString()}</span>
                        </div>
                        <button className="checkout-btn" onClick={() => setShowPaymentModal(true)}>CONFIRM PURCHASE</button>
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
                <div className="editor-empty-container">
                  <motion.div
                    className="editor-empty-glow"
                    initial={{ opacity: 0.3, scale: 0.9 }}
                    animate={{ opacity: [0.3, 0.6, 0.3], scale: [0.9, 1, 0.9] }}
                    transition={{ repeat: Infinity, duration: 4, ease: "easeInOut" }}
                  >
                    <Hammer size={40} className="editor-empty-icon" />
                  </motion.div>
                  <h3 className="editor-empty-title">No Furniture Placed</h3>
                  <p className="editor-empty-subtitle">Purchase furniture from the shop and place it in your home to see it here</p>
                </div>
              ) : (
                <>
                  <div className={`search-bar ${isPlacing ? 'disabled' : ''}`} style={{ opacity: isPlacing ? 0.5 : 1, pointerEvents: isPlacing ? 'none' : 'auto' }}>
                    <Search size={16} className="search-icon" />
                    <input
                      placeholder="Search placed furniture..."
                      value={searchQueryOwned}
                      onChange={(e) => setSearchQueryOwned(e.target.value)}
                      disabled={isPlacing}
                    />
                  </div>

                  <div className="editor-items-list-container">
                    <div className="editor-items-list">
                      <AnimatePresence mode="popLayout">
                        {filteredOwnedItems.map((item, idx) => {
                          const ItemIcon = getItemIcon(item);
                          const isPlacingThisItem = placingItem?.id === item.id;
                          return (
                            <motion.div
                              key={item.id || idx}
                              className={`editor-list-item ${isPlacing ? (isPlacingThisItem ? 'is-placing' : 'disabled') : ''}`}
                              initial={{ opacity: 0, y: 10, scale: 0.98 }}
                              animate={{ opacity: 1, y: 0, scale: 1 }}
                              exit={{ opacity: 0, x: -50, scale: 0.95 }}
                              transition={{ duration: 0.2 }}
                              onMouseEnter={() => !isPlacing && post('hoverOwnedItem', { entity: item.entity, id: item.id })}
                              onMouseLeave={() => !isPlacing && post('unhoverOwnedItem')}
                            >
                              <div className="editor-item-preview">
                                <FurnitureImage item={item} ItemIcon={ItemIcon} />
                              </div>
                              <div className="editor-item-details">
                                <span className="editor-item-name">{item.label}</span>
                                <span className="editor-item-meta">{item.model || 'Furniture'}</span>
                                <div className="editor-item-actions">
                                  <button
                                    className="editor-move-btn"
                                    disabled={isPlacing}
                                    onClick={() => handlePreview(item)}
                                    title="Move / Reposition"
                                  >
                                    <Move size={12} />
                                    <span>MOVE</span>
                                  </button>
                                  <button
                                    className="editor-remove-btn"
                                    disabled={isPlacing}
                                    onClick={(e) => {
                                      if (isPlacing) return;
                                      e.stopPropagation();
                                      post('unhoverOwnedItem');
                                      post('removeOwnedItem', item);
                                    }}
                                    title="Pack Up"
                                  >
                                    <Trash2 size={12} />
                                    <span>PACK UP</span>
                                  </button>
                                </div>
                              </div>
                            </motion.div>
                          );
                        })}
                      </AnimatePresence>
                    </div>
                  </div>
                </>
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
                <Move size={14} /> <span>Drag | [LALT] Cam | [G] Ground</span>
              </div>
            </div>
          </div>

          <div className="controls-footer">
            <button className="placeonground-btn" style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }} onClick={() => post('placeOnGround')}>
              <span>Place on Ground</span>
            </button>
          </div>

          <div className="controls-footer" style={{ marginTop: '-5px' }}>
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
      {/* Payment Selection Modal */}
      <AnimatePresence>
        {showPaymentModal && (
          <motion.div
            className="payment-modal-overlay"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            <motion.div
              className="payment-modal"
              initial={{ scale: 0.9, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.9, opacity: 0, y: 20 }}
              transition={{ type: "spring", damping: 25, stiffness: 350 }}
            >
              <div className="payment-modal-header">
                <h3>SELECT PAYMENT</h3>
                <button className="payment-modal-close" onClick={() => setShowPaymentModal(false)}>
                  <X size={16} />
                </button>
              </div>

              <div className="payment-modal-body">
                <p className="payment-modal-subtitle">Choose a payment method to complete purchase</p>
                <div className="payment-modal-total">
                  <span>Total Amount</span>
                  <span className="price">${cart.reduce((acc, item) => acc + item.price, 0).toLocaleString()}</span>
                </div>

                <div className="payment-options">
                  <button className="payment-opt-btn cash" onClick={() => handleBuy('cash')}>
                    <div className="opt-icon-wrapper">
                      <Banknote size={20} />
                    </div>
                    <div className="opt-info">
                      <span className="opt-title">Pay with Cash</span>
                      <span className="opt-desc">Deduct from pocket cash</span>
                    </div>
                  </button>

                  <button className="payment-opt-btn bank" onClick={() => handleBuy('bank')}>
                    <div className="opt-icon-wrapper">
                      <CreditCard size={20} />
                    </div>
                    <div className="opt-info">
                      <span className="opt-title">Pay with Card</span>
                      <span className="opt-desc">Deduct from bank account</span>
                    </div>
                  </button>
                </div>
              </div>

              <button className="payment-modal-cancel" onClick={() => setShowPaymentModal(false)}>
                Cancel
              </button>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
};

export default FurnitureMenu;
