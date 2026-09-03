import React, { useState, useEffect, useRef } from 'react';

const fetchNui = async (eventName, data = {}) => {
  const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'LNS_Housing';
  try {
    const resp = await fetch(`https://${resourceName}/${eventName}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    });
    return await resp.json();
  } catch (err) {
    return null;
  }
};

export default function BreachMinigame({ active, onClose }) {
  const isDraggingRef = useRef(false);
  const lastXRef = useRef(0);
  const currentProgressRef = useRef(0.0);
  const hitRegisteredRef = useRef(false);
  const [, forceRender] = useState({});

  useEffect(() => {
    if (!active) {
      isDraggingRef.current = false;
      currentProgressRef.current = 0.0;
      hitRegisteredRef.current = false;
      return;
    }

    // Sync initial start position immediately on mount so no height jump occurs
    fetchNui('breachDragUpdate', { progress: 0.0 });

    const handleKeyDown = (e) => {
      if (e.key === 'Escape' || e.keyCode === 27) {
        e.preventDefault();
        fetchNui('breachCancel');
        if (onClose) onClose();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [active, onClose]);

  if (!active) return null;

  const handleMouseDown = (e) => {
    if (e.button !== 0) return;
    isDraggingRef.current = true;
    lastXRef.current = e.clientX;
    forceRender({});
  };

  const handleMouseMove = (e) => {
    if (!isDraggingRef.current) return;

    // Mouse movement RIGHT (dx > 0) pushes ram forward into door
    // Mouse movement LEFT (dx < 0) pulls ram back away from door
    const dx = e.clientX - lastXRef.current;
    lastXRef.current = e.clientX;

    const dragRangePixels = 260; // Smooth 260px horizontal travel
    let newProgress = currentProgressRef.current + (dx / dragRangePixels);
    newProgress = Math.min(Math.max(newProgress, 0.0), 1.0);

    currentProgressRef.current = newProgress;
    fetchNui('breachDragUpdate', { progress: newProgress });

    // When pulled back left (progress <= 0.25), reset hit flag for next strike
    if (newProgress <= 0.25 && hitRegisteredRef.current) {
      hitRegisteredRef.current = false;
    }

    // When pushed all the way right into door (progress >= 0.95), register hit
    if (newProgress >= 0.95 && !hitRegisteredRef.current) {
      hitRegisteredRef.current = true;
      fetchNui('breachHit');
    }
  };

  const handleMouseUp = () => {
    isDraggingRef.current = false;
    forceRender({});
  };

  return (
    <div
      onMouseDown={handleMouseDown}
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        width: '100vw',
        height: '100vh',
        zIndex: 9999999,
        background: 'transparent',
        cursor: isDraggingRef.current ? 'grabbing' : 'grab',
        userSelect: 'none',
        pointerEvents: 'auto',
        visibility: 'visible',
      }}
    />
  );
}
