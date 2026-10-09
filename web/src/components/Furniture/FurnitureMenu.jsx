import React, { useState, useEffect, useRef } from 'react';
import {
  Sofa, Bed, Lamp, Tv, Utensils, Bath, Search, Package, Check, Trash2,
  Camera, Move, RotateCw, X, ShoppingCart, ShoppingBag, Hammer, ArrowLeft,
  Grid, ArrowDown, CreditCard, Banknote, Keyboard, SlidersHorizontal,
  Plus, Minus, RotateCcw, Copy, CheckCheck
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import Modeler3D from './Modeler3D';
import './FurnitureMenu.css';

const CONTROLS = [
  {
    section: 'Selecting', rows: [
      { keys: ['Left Click'], desc: 'Click any placed prop (bought or in basket) to move it' },
    ]
  },
  {
    section: 'Placement', rows: [
      { keys: ['Drag'], desc: 'Drag the gizmo arrows or sphere' },
      { keys: ['Right Click'], desc: 'Switch between move and rotate' },
      { keys: ['E'], desc: 'Position mode' },
      { keys: ['R'], desc: 'Rotate mode' },
      { keys: ['G'], desc: 'Place on ground' },
      { keys: ['Manual Pos'], desc: 'Click the adjustment button on top right to fine-tune exact coordinates' },
      { keys: ['Del'], desc: 'Delete the selected item (bought or in basket)' },
    ]
  },
  {
    section: 'Copy and Paste', rows: [
      { keys: ['Ctrl', 'C'], desc: 'Copy the selected item' },
      { keys: ['Ctrl', 'V'], desc: 'Paste a copy in that spot, then drag it away. Paste again to chain copies' },
    ]
  },
  {
    section: 'Camera', rows: [
      { keys: ['Left Alt'], desc: 'Toggle free camera' },
      { keys: ['Backspace'], desc: 'Toggle free camera' },
    ]
  },
];

const CoordInput = ({ value, onChange, precision = 4, disabled }) => {
  const [localVal, setLocalVal] = useState('');
  const [isFocused, setIsFocused] = useState(false);

  useEffect(() => {
    if (!isFocused) {
      setLocalVal(value !== undefined && !isNaN(value) ? Number(value).toFixed(precision) : '0.0000');
    }
  }, [value, isFocused, precision]);

  const commit = (val) => {
    const parsed = parseFloat(val);
    if (!isNaN(parsed)) {
      onChange(parseFloat(parsed.toFixed(precision)));
    } else {
      setLocalVal(Number(value || 0).toFixed(precision));
    }
  };

  return (
    <input
      type="number"
      step="any"
      disabled={disabled}
      className="manual-pos-input"
      value={isFocused ? localVal : (value !== undefined && !isNaN(value) ? Number(value).toFixed(precision) : '0.0000')}
      onFocus={(e) => {
        setIsFocused(true);
        setLocalVal(e.target.value);
        e.target.select();
      }}
      onChange={(e) => {
        setLocalVal(e.target.value);
        const parsed = parseFloat(e.target.value);
        if (!isNaN(parsed)) {
          onChange(parseFloat(parsed.toFixed(precision)));
        }
      }}
      onBlur={(e) => {
        setIsFocused(false);
        commit(e.target.value);
      }}
      onKeyDown={(e) => {
        if (e.key === 'Enter') {
          commit(e.target.value);
          e.currentTarget.blur();
        }
        e.stopPropagation();
      }}
    />
  );
};

const NudgeBtn = ({ onClick, children, title, className = '', disabled }) => {
  const timeoutRef = useRef(null);
  const intervalRef = useRef(null);
  const onClickRef = useRef(onClick);
  onClickRef.current = onClick;

  const startHold = (e) => {
    if (disabled || e.button !== 0) return;
    e.preventDefault();
    if (onClickRef.current) onClickRef.current();
    timeoutRef.current = setTimeout(() => {
      intervalRef.current = setInterval(() => {
        if (onClickRef.current) onClickRef.current();
      }, 70);
    }, 280);
  };

  const endHold = () => {
    if (timeoutRef.current) clearTimeout(timeoutRef.current);
    if (intervalRef.current) clearInterval(intervalRef.current);
    timeoutRef.current = null;
    intervalRef.current = null;
  };

  return (
    <button
      type="button"
      className={`manual-pos-nudge-btn ${className}`}
      disabled={disabled}
      onMouseDown={startHold}
      onMouseUp={endHold}
      onMouseLeave={endHold}
      tabIndex={-1}
      title={title}
    >
      {children}
    </button>
  );
};

const FurnitureImage = React.memo(function FurnitureImage({ item, ItemIcon }) {
  const [loaded, setLoaded] = useState(false);
  const [contentReady, setContentReady] = useState(false);
  const [error, setError] = useState(false);
  const imageUrl = item.imageUrl || `assets/furniture/${item.model}.png`;

  useEffect(() => {
    const id = requestAnimationFrame(() => setContentReady(true));
    return () => cancelAnimationFrame(id);
  }, []);

  return (
    <div className="icon-wrapper">
      {!error && (
        <img
          src={imageUrl}
          alt={item.label}
          className="furniture-img"
          decoding="async"
          onLoad={() => setLoaded(true)}
          onError={() => setError(true)}
          style={{
            opacity: loaded ? 1 : 0,
            position: loaded ? 'static' : 'absolute',
          }}
        />
      )}
      {!loaded && !error && (
        <div className="furniture-img-spinner" aria-hidden="true" />
      )}
      {error && <ItemIcon size={28} className="placeholder" />}
    </div>
  );
});

const ItemCard = React.memo(function ItemCard({ item, ItemIcon, isPlacing, isThisPlacing, onHoverIn, onHoverOut, onClick }) {
  return (
    <div
      className={`item-card ${isPlacing ? (isThisPlacing ? 'is-placing' : 'disabled') : ''} item-card-anim`}
      onMouseEnter={onHoverIn}
      onMouseLeave={onHoverOut}
      onClick={onClick}
    >
      <FurnitureImage item={item} ItemIcon={ItemIcon} />
      <span className="item-card-price">${item.price}</span>
    </div>
  );
});

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
  const [placingKind, setPlacingKind] = useState(null); // 'new' | 'cart' | 'owned'
  const [showControls, setShowControls] = useState(false);
  const [showManualPos, setShowManualPos] = useState(false);
  const [objectCoords, setObjectCoords] = useState({ x: 0, y: 0, z: 0 });
  const [objectRotation, setObjectRotation] = useState({ x: 0, y: 0, z: 0 });
  const [posStep, setPosStep] = useState(0.01);
  const [rotStep, setRotStep] = useState(1);
  const [copiedTransform, setCopiedTransform] = useState(null);
  const [toast, setToast] = useState(null);

  const showToast = (msg) => {
    setToast(msg);
    setTimeout(() => setToast(null), 1200);
  };

  const clearPlacing = () => {
    setIsPlacing(false);
    setPlacingItem(null);
    setPlacingKind(null);
  };

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
    // Fetch active cart on mount if any
    if (window.GetParentResourceName) {
      fetch(`https://${window.GetParentResourceName()}/getCart`, {
        method: 'POST',
        body: JSON.stringify({})
      })
        .then((res) => res.json())
        .then((data) => {
          if (Array.isArray(data)) {
            setCart(data);
          }
        })
        .catch(() => { });
    }

    const handleMessage = (event) => {
      if (event.data.action === 'freecamMode') {
        setFreecamMode(event.data.data);
      } else if (event.data.action === 'selectFurniture') {
        setIsPlacing(true);
        setPlacingItem(event.data.data);
        setPlacingKind(event.data.data.kind || 'owned');
      } else if (event.data.action === 'setupModel') {
        if (event.data.data) {
          if (event.data.data.objectPosition) {
            setObjectCoords({
              x: parseFloat(Number(event.data.data.objectPosition.x || 0).toFixed(4)),
              y: parseFloat(Number(event.data.data.objectPosition.y || 0).toFixed(4)),
              z: parseFloat(Number(event.data.data.objectPosition.z || 0).toFixed(4)),
            });
          }
          if (event.data.data.objectRotation) {
            setObjectRotation({
              x: parseFloat(Number(event.data.data.objectRotation.x || 0).toFixed(2)),
              y: parseFloat(Number(event.data.data.objectRotation.y || 0).toFixed(2)),
              z: parseFloat(Number(event.data.data.objectRotation.z || 0).toFixed(2)),
            });
          }
        }
      } else if (event.data.action === 'syncObjectState') {
        if (event.data.data) {
          if (event.data.data.position) {
            setObjectCoords({
              x: parseFloat(Number(event.data.data.position.x || 0).toFixed(4)),
              y: parseFloat(Number(event.data.data.position.y || 0).toFixed(4)),
              z: parseFloat(Number(event.data.data.position.z || 0).toFixed(4)),
            });
          }
          if (event.data.data.rotation) {
            setObjectRotation({
              x: parseFloat(Number(event.data.data.rotation.x || 0).toFixed(2)),
              y: parseFloat(Number(event.data.data.rotation.y || 0).toFixed(2)),
              z: parseFloat(Number(event.data.data.rotation.z || 0).toFixed(2)),
            });
          }
        }
      } else if (event.data.action === 'addToCart') {
        setCart(prevCart => [...prevCart, event.data.data]);
      } else if (event.data.action === 'setCart') {
        setCart(event.data.data || []);
      } else if (event.data.action === 'clearCart') {
        setCart([]);
      } else if (event.data.action === 'removeCartItem') {
        const removedId = event.data.data && event.data.data.cartId;
        setCart(prevCart => prevCart.filter(i => i.cartId !== removedId));
      } else if (event.data.action === 'placementEnded') {
        setIsPlacing(false);
        setPlacingItem(null);
        setPlacingKind(null);
        setToast('Deleted');
        setTimeout(() => setToast(null), 1200);
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

      if (e.ctrlKey || e.metaKey) {
        const k = e.key.toLowerCase();
        if (k === 'c' && isPlacing) {
          e.preventDefault();
          if (!e.repeat) { post('copyFurniture'); showToast('Copied'); }
        } else if (k === 'v') {
          e.preventDefault();
          if (!e.repeat) post('pasteFurniture');
        }
        return;
      }

      if (e.key === 'Delete' && isPlacing) {
        e.preventDefault();
        if (!e.repeat) post('deleteFurniture');
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

  useEffect(() => {
    const handleWorldClick = (e) => {
      if (e.button !== 0) return;
      if (isPlacing || freecamMode || showPaymentModal) return;
      if (e.target.closest && e.target.closest(
        '.furniture-sidebar-container, .placement-controls, .placement-mode-controls, .controls-help-btn, .manual-pos-btn, .controls-popup, .manual-pos-popup, .payment-modal-overlay'
      )) return;

      post('clickWorld', {
        x: e.clientX / window.innerWidth,
        y: e.clientY / window.innerHeight,
      });
    };

    window.addEventListener('mousedown', handleWorldClick);
    return () => window.removeEventListener('mousedown', handleWorldClick);
  }, [isPlacing, freecamMode, showPaymentModal]);

  const IconMap = {
    Sofa: Sofa,
    Bed: Bed,
    Lamp: Lamp,
    Tv: Tv,
    Utensils: Utensils,
    Bath: Bath,
    Package: Package
  };

  const categories = React.useMemo(() =>
    Array.isArray(items) ? items.map(cat => ({
      id: cat.id,
      label: cat.label,
      icon: IconMap[cat.icon] || Package
    })) : [],
    [items]
  );

  const activeCategoryData = React.useMemo(() =>
    Array.isArray(items) ? items.find(cat => cat.id === activeCategory) : null,
    [items, activeCategory]
  );

  const filteredItems = React.useMemo(() => {
    if (activeCategory === 'all') {
      const all = [];
      items.forEach(cat => {
        if (cat.items) {
          cat.items.forEach(item => all.push({ ...item, categoryId: cat.id }));
        }
      });
      return all.filter(item => item.label.toLowerCase().includes(searchQuery.toLowerCase()));
    }
    return (activeCategoryData?.items || []).filter(item =>
      item.label.toLowerCase().includes(searchQuery.toLowerCase())
    );
  }, [items, activeCategory, activeCategoryData, searchQuery]);

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

  const hoverTimeoutRef = useRef(null);
  const activeHoverItemRef = useRef(null);
  const activeHoverOwnedRef = useRef(null);

  const handleHoverIn = (item) => {
    if (isPlacing) return;
    if (hoverTimeoutRef.current) clearTimeout(hoverTimeoutRef.current);

    hoverTimeoutRef.current = setTimeout(() => {
      activeHoverItemRef.current = item;
      post('hoverIn', item);
    }, 150);
  };

  const handleHoverOut = () => {
    if (isPlacing) return;
    if (hoverTimeoutRef.current) {
      clearTimeout(hoverTimeoutRef.current);
      hoverTimeoutRef.current = null;
    }
    if (activeHoverItemRef.current) {
      activeHoverItemRef.current = null;
      post('hoverOut');
    }
  };

  const handleHoverOwnedIn = (item) => {
    if (isPlacing) return;
    if (hoverTimeoutRef.current) clearTimeout(hoverTimeoutRef.current);

    hoverTimeoutRef.current = setTimeout(() => {
      activeHoverOwnedRef.current = item;
      post('hoverOwnedItem', { entity: item.entity, id: item.id });
    }, 150);
  };

  const handleHoverOwnedOut = () => {
    if (isPlacing) return;
    if (hoverTimeoutRef.current) {
      clearTimeout(hoverTimeoutRef.current);
      hoverTimeoutRef.current = null;
    }
    if (activeHoverOwnedRef.current) {
      activeHoverOwnedRef.current = null;
      post('unhoverOwnedItem');
    }
  };

  const handlePreview = (item) => {
    if (isPlacing) return;
    setIsPlacing(true);
    setPlacingItem(item);
    setPlacingKind(activeTab === 'editor' ? 'owned' : 'new');
    post('unhoverOwnedItem');
    post('previewFurniture', item);
  };

  const handleAddToCart = (item) => {
    const catId = item.categoryId || item.category || activeCategory;
    post('addToCart', { ...item, category: catId });
    clearPlacing();
  };

  const handleBuy = async (paymentMethod) => {
    setShowPaymentModal(false);
    if (window.GetParentResourceName) {
      try {
        const response = await fetch(`https://${window.GetParentResourceName()}/buyCartItems`, {
          method: 'POST',
          body: JSON.stringify({ items: cart, paymentMethod })
        });
        const result = await response.json();
        if (result && result.success) {
          setCart([]);
          setActiveTab('shopping');
        }
        // If not successful (e.g. no money), the basket is not cleared and remains fully intact!
      } catch (err) {
        console.error('Error buying cart items:', err);
      }
    }
  };

  const updateCoord = (axis, val) => {
    if (!isPlacing) return;
    const num = parseFloat(Number(val).toFixed(4));
    setObjectCoords(prev => {
      const nextPos = { ...prev, [axis]: num };
      post('moveObject', nextPos);
      return nextPos;
    });
  };

  const nudgeCoord = (axis, delta) => {
    if (!isPlacing) return;
    setObjectCoords(prev => {
      const currentVal = Number(prev[axis] || 0);
      const nextVal = parseFloat((currentVal + delta).toFixed(4));
      const nextPos = { ...prev, [axis]: nextVal };
      post('moveObject', nextPos);
      return nextPos;
    });
  };

  const updateRotation = (axis, val) => {
    if (!isPlacing) return;
    const num = parseFloat(Number(val).toFixed(2));
    setObjectRotation(prev => {
      const nextRot = { ...prev, [axis]: num };
      post('rotateObject', nextRot);
      return nextRot;
    });
  };

  const nudgeRotation = (axis, delta) => {
    if (!isPlacing) return;
    setObjectRotation(prev => {
      const currentVal = Number(prev[axis] || 0);
      let nextVal = parseFloat((currentVal + delta).toFixed(2));
      if (axis === 'z') {
        if (nextVal >= 360) nextVal = nextVal % 360;
        if (nextVal < 0) nextVal = (nextVal % 360 + 360) % 360;
      }
      const nextRot = { ...prev, [axis]: nextVal };
      post('rotateObject', nextRot);
      return nextRot;
    });
  };

  const handleResetRotation = () => {
    if (!isPlacing) return;
    const zeroRot = { x: 0, y: 0, z: 0 };
    setObjectRotation(zeroRot);
    post('rotateObject', zeroRot);
    showToast('Rotation Reset');
  };

  const handleSnapHeading = (angle) => {
    if (!isPlacing) return;
    setObjectRotation(prev => {
      let nextZ = parseFloat(((Number(prev.z || 0) + angle) % 360).toFixed(2));
      if (nextZ < 0) nextZ = (nextZ + 360) % 360;
      const nextRot = { ...prev, z: nextZ };
      post('rotateObject', nextRot);
      return nextRot;
    });
  };

  const handleCopyTransform = () => {
    if (!isPlacing) return;
    setCopiedTransform({
      position: { ...objectCoords },
      rotation: { ...objectRotation }
    });
    showToast('Transform Copied');
  };

  const handlePasteTransform = () => {
    if (!isPlacing || !copiedTransform) return;
    const nextPos = { ...copiedTransform.position };
    const nextRot = { ...copiedTransform.rotation };
    setObjectCoords(nextPos);
    setObjectRotation(nextRot);
    post('moveObject', nextPos);
    post('rotateObject', nextRot);
    showToast('Transform Pasted');
  };

  const handleClose = () => {
    post('closeUI');
  };

  return (
    <>
      <motion.div
        className="furniture-sidebar-container"
        initial={{ x: -400, opacity: 0 }}
        animate={{ x: 0, opacity: 1 }}
        exit={{ x: -400, opacity: 0 }}
        transition={{ type: 'tween', duration: 0.22, ease: [0.25, 0.1, 0.25, 1] }}
        style={{ willChange: 'transform, opacity' }}
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

        <AnimatePresence initial={false}>
          <motion.div
            className="sidebar-content"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.15 }}
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
                        {filteredItems.map((item) => {
                          const ItemIcon = getItemIcon(item);
                          const itemKey = `${item.categoryId || activeCategory}-${item.id}`;
                          return (
                            <ItemCard
                              key={itemKey}
                              item={item}
                              ItemIcon={ItemIcon}
                              isPlacing={isPlacing}
                              isThisPlacing={placingItem?.id === item.id}
                              onHoverIn={() => handleHoverIn(item)}
                              onHoverOut={handleHoverOut}
                              onClick={() => handlePreview(item)}
                            />
                          );
                        })}
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
                      {cart.length > 0 && (
                        <button
                          className="cart-clear-btn"
                          onClick={() => {
                            setCart([]);
                            post('clearCart');
                          }}
                          title="Clear all items in basket"
                        >
                          <Trash2 size={13} />
                          <span>Clear Basket</span>
                        </button>
                      )}
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
                                  key={item.cartId || item.entity || idx}
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
                                        post('removeCartItem', { cartId: item.cartId, entity: item.entity, model: item.model, position: item.position });
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
                                onMouseEnter={() => handleHoverOwnedIn(item)}
                                onMouseLeave={handleHoverOwnedOut}
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

        {/* Payment Selection Modal — stays nested so it overlays just the sidebar */}
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

      {/*
        Everything below is rendered OUTSIDE .furniture-sidebar-container on purpose.
        The sidebar is `overflow: hidden` and locked to a 350px box on the left —
        anything positioned relative to it (or clipped by it) was either getting cut off
        (placement-controls) or centering itself against the sidebar box instead of the
        viewport (Modeler3D's gizmo). Rendering them as siblings fixes both.
      */}

      {/* Top Right Buttons */}
      <button
        className={`controls-help-btn ${showControls ? 'active' : ''}`}
        onMouseDown={(e) => e.preventDefault()}
        onClick={() => {
          setShowControls(v => !v);
          if (!showControls) setShowManualPos(false);
        }}
        tabIndex={-1}
        title="Controls"
      >
        <Keyboard size={18} />
      </button>

      <button
        className={`manual-pos-btn ${showManualPos ? 'active' : ''}`}
        onMouseDown={(e) => e.preventDefault()}
        onClick={() => {
          setShowManualPos(v => !v);
          if (!showManualPos) setShowControls(false);
        }}
        tabIndex={-1}
        title="Manual Transform (Position & Rotation)"
      >
        <SlidersHorizontal size={18} />
      </button>

      {/* Controls Popup */}
      <AnimatePresence>
        {showControls && (
          <motion.div
            className="controls-popup"
            initial={{ opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.15 }}
          >
            <div className="controls-popup-header">
              <span>CONTROLS</span>
              <button className="payment-modal-close" onClick={() => setShowControls(false)}>
                <X size={16} />
              </button>
            </div>
            {CONTROLS.map((group) => (
              <div key={group.section} className="controls-group">
                <div className="controls-section-title">{group.section}</div>
                {group.rows.map((row, i) => (
                  <div key={i} className="controls-row">
                    <div className="controls-keys">
                      {row.keys.map((k) => <kbd key={k}>{k}</kbd>)}
                    </div>
                    <span className="controls-desc">{row.desc}</span>
                  </div>
                ))}
              </div>
            ))}
          </motion.div>
        )}
      </AnimatePresence>

      {/* Manual Position / Transform Popup */}
      <AnimatePresence>
        {showManualPos && (
          <motion.div
            className="manual-pos-popup"
            initial={{ opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.15 }}
          >
            <div className="controls-popup-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span>MANUAL ROTATION</span>
              </div>
              <button className="payment-modal-close" onClick={() => setShowManualPos(false)}>
                <X size={16} />
              </button>
            </div>

            {isPlacing ? (
              <>
                <div className="manual-pos-item-info">
                  <span className="manual-pos-item-label">{placingItem?.label || 'Selected Object'}</span>
                  <span className="manual-pos-item-meta">{placingItem?.model || 'Position & Rotation'}</span>
                </div>

                {/* Position Step Selector */}
                <div className="manual-pos-step-section">
                  <div className="manual-pos-section-label">
                    <span>Position Step</span>
                    <span className="badge">{posStep}m</span>
                  </div>
                  <div className="manual-pos-step-pills">
                    {[0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0].map((step) => (
                      <button
                        key={step}
                        type="button"
                        className={`manual-pos-step-pill ${posStep === step ? 'active' : ''}`}
                        onClick={() => setPosStep(step)}
                      >
                        {step}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Position (Coordinates) */}
                <div className="manual-pos-step-section">
                  <div className="manual-pos-section-label">
                    <span>Coordinates (X, Y, Z)</span>
                  </div>
                  <div className="manual-pos-axis-grid">
                    <div className="manual-pos-axis-row">
                      <div className="manual-pos-axis-badge axis-x" title="X Axis (East / West)">X</div>
                      <NudgeBtn title={`Subtract ${posStep}m`} onClick={() => nudgeCoord('x', -posStep)}>
                        <Minus size={12} />
                      </NudgeBtn>
                      <CoordInput
                        value={objectCoords.x}
                        onChange={(val) => updateCoord('x', val)}
                        precision={4}
                      />
                      <NudgeBtn title={`Add ${posStep}m`} onClick={() => nudgeCoord('x', posStep)}>
                        <Plus size={12} />
                      </NudgeBtn>
                    </div>

                    <div className="manual-pos-axis-row">
                      <div className="manual-pos-axis-badge axis-y" title="Y Axis (North / South)">Y</div>
                      <NudgeBtn title={`Subtract ${posStep}m`} onClick={() => nudgeCoord('y', -posStep)}>
                        <Minus size={12} />
                      </NudgeBtn>
                      <CoordInput
                        value={objectCoords.y}
                        onChange={(val) => updateCoord('y', val)}
                        precision={4}
                      />
                      <NudgeBtn title={`Add ${posStep}m`} onClick={() => nudgeCoord('y', posStep)}>
                        <Plus size={12} />
                      </NudgeBtn>
                    </div>

                    <div className="manual-pos-axis-row">
                      <div className="manual-pos-axis-badge axis-z" title="Z Axis (Height / Elevation)">Z</div>
                      <NudgeBtn title={`Subtract ${posStep}m`} onClick={() => nudgeCoord('z', -posStep)}>
                        <Minus size={12} />
                      </NudgeBtn>
                      <CoordInput
                        value={objectCoords.z}
                        onChange={(val) => updateCoord('z', val)}
                        precision={4}
                      />
                      <NudgeBtn title={`Add ${posStep}m`} onClick={() => nudgeCoord('z', posStep)}>
                        <Plus size={12} />
                      </NudgeBtn>
                    </div>
                  </div>
                </div>

                {/* Rotation Step Selector */}
                <div className="manual-pos-step-section">
                  <div className="manual-pos-section-label">
                    <span>Rotation Step</span>
                    <span className="badge">{rotStep}°</span>
                  </div>
                  <div className="manual-pos-step-pills">
                    {[0.5, 1, 5, 15, 45, 90].map((step) => (
                      <button
                        key={step}
                        type="button"
                        className={`manual-pos-step-pill ${rotStep === step ? 'active' : ''}`}
                        onClick={() => setRotStep(step)}
                      >
                        {step}°
                      </button>
                    ))}
                  </div>
                </div>

                {/* Rotation (Angles) */}
                <div className="manual-pos-step-section">
                  <div className="manual-pos-section-label">
                    <span>Orientation (Degrees)</span>
                  </div>
                  <div className="manual-pos-axis-grid">
                    <div className="manual-pos-axis-row">
                      <div className="manual-pos-axis-badge axis-yaw" title="Heading / Yaw (Rotation around vertical axis)">Yaw</div>
                      <NudgeBtn title={`Rotate -${rotStep}°`} onClick={() => nudgeRotation('z', -rotStep)}>
                        <Minus size={12} />
                      </NudgeBtn>
                      <CoordInput
                        value={objectRotation.z}
                        onChange={(val) => updateRotation('z', val)}
                        precision={2}
                      />
                      <NudgeBtn title={`Rotate +${rotStep}°`} onClick={() => nudgeRotation('z', rotStep)}>
                        <Plus size={12} />
                      </NudgeBtn>
                    </div>

                    <div className="manual-pos-axis-row">
                      <div className="manual-pos-axis-badge axis-pitch" title="Pitch (Tilt forward/back)">Pitch</div>
                      <NudgeBtn title={`Tilt -${rotStep}°`} onClick={() => nudgeRotation('x', -rotStep)}>
                        <Minus size={12} />
                      </NudgeBtn>
                      <CoordInput
                        value={objectRotation.x}
                        onChange={(val) => updateRotation('x', val)}
                        precision={2}
                      />
                      <NudgeBtn title={`Tilt +${rotStep}°`} onClick={() => nudgeRotation('x', rotStep)}>
                        <Plus size={12} />
                      </NudgeBtn>
                    </div>

                    <div className="manual-pos-axis-row">
                      <div className="manual-pos-axis-badge axis-roll" title="Roll (Tilt left/right)">Roll</div>
                      <NudgeBtn title={`Roll -${rotStep}°`} onClick={() => nudgeRotation('y', -rotStep)}>
                        <Minus size={12} />
                      </NudgeBtn>
                      <CoordInput
                        value={objectRotation.y}
                        onChange={(val) => updateRotation('y', val)}
                        precision={2}
                      />
                      <NudgeBtn title={`Roll +${rotStep}°`} onClick={() => nudgeRotation('y', rotStep)}>
                        <Plus size={12} />
                      </NudgeBtn>
                    </div>
                  </div>
                </div>

                {/* Quick Action Helpers */}
                <div className="manual-pos-actions">
                  <button
                    type="button"
                    className="manual-pos-action-btn"
                    onClick={() => post('placeOnGround')}
                    title="Snap to floor/surface"
                  >
                    <ArrowDown size={13} />
                    <span>On Ground</span>
                  </button>
                  <button
                    type="button"
                    className="manual-pos-action-btn"
                    onClick={handleResetRotation}
                    title="Reset rotation to 0,0,0"
                  >
                    <RotateCcw size={13} />
                    <span>Reset Rot</span>
                  </button>
                  <button
                    type="button"
                    className="manual-pos-action-btn"
                    onClick={() => handleSnapHeading(90)}
                    title="Turn 90 degrees clockwise"
                  >
                    <RotateCw size={13} />
                    <span>Yaw +90°</span>
                  </button>
                  <button
                    type="button"
                    className="manual-pos-action-btn"
                    onClick={handleCopyTransform}
                    title="Copy current position and rotation"
                  >
                    <Copy size={13} />
                    <span>Copy Pos</span>
                  </button>
                  {copiedTransform && (
                    <button
                      type="button"
                      className="manual-pos-action-btn full-width"
                      onClick={handlePasteTransform}
                      title="Paste copied position and rotation"
                    >
                      <CheckCheck size={13} />
                      <span>Paste Copied Transform</span>
                    </button>
                  )}
                </div>
              </>
            ) : (
              <div className="manual-pos-empty">
                <Move size={32} className="manual-pos-empty-icon" />
                <span className="manual-pos-empty-title">No Furniture Selected</span>
                <p className="manual-pos-empty-desc">
                  Click any placed prop in your room or select an item from the catalog to adjust its exact coordinates and rotation.
                </p>
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>

      {toast && <div className="controls-toast">{toast}</div>}

      {freecamMode && (
        <div className={`freecam-hint ${isPlacing ? 'with-placement' : ''}`}>
          <span>[LEFT ALT] Exit Cam | [BACKSPACE] Exit Cam</span>
        </div>
      )}

      <Modeler3D
        active={isPlacing}
        currentPosition={objectCoords}
        currentRotation={objectRotation}
        onDragEnd={(data) => {
          if (data && data.position) {
            setObjectCoords({
              x: parseFloat(Number(data.position.x || 0).toFixed(4)),
              y: parseFloat(Number(data.position.y || 0).toFixed(4)),
              z: parseFloat(Number(data.position.z || 0).toFixed(4)),
            });
          }
          if (data && data.rotation) {
            setObjectRotation({
              x: parseFloat(Number(data.rotation.x || 0).toFixed(2)),
              y: parseFloat(Number(data.rotation.y || 0).toFixed(2)),
              z: parseFloat(Number(data.rotation.z || 0).toFixed(2)),
            });
          }
        }}
        onUpdate={(data) => {
          if (data.position) {
            post('moveObject', data.position);
          }
          if (data.rotation) {
            post('rotateObject', data.rotation);
          }
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
              if (placingKind === 'new' && placingItem) {
                handleAddToCart(placingItem);
              } else {
                clearPlacing();
                post('stopPlacement', { save: true });
              }
            }}>Confirm</button>
            <button className="stop-btn" onClick={() => {
              clearPlacing();
              post('stopPlacement');
            }}>Cancel</button>
          </div>
        </div>
      )}
    </>
  );
};

export default FurnitureMenu;