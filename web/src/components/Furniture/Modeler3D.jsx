import React, { useState, useEffect, useRef } from 'react';
import { Canvas, useThree } from '@react-three/fiber';
import { TransformControls } from '@react-three/drei';
import * as THREE from 'three';

const convertToThree = (pos) => ({ x: pos.x, y: pos.z, z: -pos.y });
const convertToGTA = (pos) => ({ x: pos.x, y: -pos.z, z: pos.y });

const Scene = ({ cameraData, objectPos, objectRot, mode, onUpdate, onModeChange }) => {
  const { camera } = useThree();
  const controlsRef = useRef();
  const meshRef = useRef();

  useEffect(() => {
    if (cameraData) {
      const threeCamPos = convertToThree(cameraData.position);
      const threeCamLookAt = convertToThree(cameraData.lookAt);

      camera.position.set(threeCamPos.x, threeCamPos.y, threeCamPos.z);
      camera.lookAt(threeCamLookAt.x, threeCamLookAt.y, threeCamLookAt.z);

      const desiredFov = cameraData.fov || 45.0;
      if (camera.fov !== desiredFov) {
        camera.fov = desiredFov;
        camera.updateProjectionMatrix();
      }
    }
  }, [cameraData, camera]);

  useEffect(() => {
    const handleContextMenu = (e) => {
      e.preventDefault();
      onModeChange(mode === 'translate' ? 'rotate' : 'translate');
    };
    window.addEventListener('contextmenu', handleContextMenu);
    return () => window.removeEventListener('contextmenu', handleContextMenu);
  }, [mode, onModeChange]);

  const handleObjectChange = () => {
    if (meshRef.current) {
      const position = convertToGTA(meshRef.current.position);
      const rotation = meshRef.current.rotation;
      const rotation2 = {
        x: THREE.MathUtils.radToDeg(rotation.x),
        y: -THREE.MathUtils.radToDeg(rotation.z),
        z: THREE.MathUtils.radToDeg(rotation.y)
      };

      onUpdate({ position: position, rotation: rotation2 });
    }
  };

  return (
    <>
      <ambientLight intensity={0.5} />
      <pointLight position={[10, 10, 10]} />

      <mesh
        ref={meshRef}
        position={[
          convertToThree(objectPos).x,
          convertToThree(objectPos).y,
          convertToThree(objectPos).z
        ]}
        rotation={new THREE.Euler(
          THREE.MathUtils.degToRad(objectRot?.x || 0),
          THREE.MathUtils.degToRad(objectRot?.z || 0),
          -THREE.MathUtils.degToRad(objectRot?.y || 0),
          'YXZ'
        )}
      >
        <boxGeometry args={[0.01, 0.01, 0.01]} />
        <meshStandardMaterial color="orange" transparent opacity={0} />
      </mesh>

      <TransformControls
        ref={controlsRef}
        object={meshRef.current}
        mode={mode}
        onObjectChange={handleObjectChange}
        size={0.6}
      />
    </>
  );
};

const Modeler3D = ({ active, onUpdate }) => {
  const [cameraData, setCameraData] = useState(null);
  const [position, setPosition] = useState({ x: 0, y: 0, z: 0 });
  const [rotation, setRotation] = useState({ x: 0, y: 0, z: 0 });
  const [mode, setMode] = useState('translate');
  const [isInitialized, setIsInitialized] = useState(false);
  useEffect(() => {
    const handleMessage = (event) => {
      if (event.data.action === 'setupModel') {
        setPosition(event.data.data.objectPosition);
        setRotation(event.data.data.objectRotation);
        setCameraData({
          position: event.data.data.cameraPosition,
          lookAt: event.data.data.cameraLookAt,
          fov: event.data.data.cameraFov
        });
        setIsInitialized(true);
      } else if (event.data.action === 'updateCamera') {
        setCameraData({
          position: event.data.data.cameraPosition,
          lookAt: event.data.data.cameraLookAt,
          fov: event.data.data.cameraFov
        });
      } else if (event.data.action === 'setPlacementMode') {
        setMode(event.data.data);
      } else if (event.data.action === 'syncObjectState') {
        if (event.data.data.position) setPosition(event.data.data.position);
        if (event.data.data.rotation) setRotation(event.data.data.rotation);
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, []); useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.isContentEditable) {
        return;
      }

      const key = e.key.toLowerCase();
      if (key === 'e') {
        setMode('translate');
      } else if (key === 'r') {
        setMode('rotate');
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const handleGizmoUpdate = (data) => {
    setPosition(data.position);
    setRotation(data.rotation);
    onUpdate(data);
  };

  const isVisible = active && isInitialized;

  return (
    <div className="modeler-3d-container" style={{ display: isVisible ? 'block' : 'none' }}>
      <Canvas
        camera={{ fov: 45.0, near: 0.1, far: 1000 }}
        style={{ position: 'fixed', top: 0, left: 0, width: '100vw', height: '100vh', pointerEvents: isVisible ? 'auto' : 'none' }}
        gl={{ alpha: true, antialias: true }}
        frameloop={isVisible ? 'always' : 'never'}
        onPointerDown={(e) => {
          if (isVisible && e.target.tagName === 'CANVAS') {
            fetch(`https://${window.GetParentResourceName()}/clickWorld`, {
              method: 'POST',
              body: JSON.stringify({})
            });
          }
        }}
      >
        {isVisible && (
          <Scene
            cameraData={cameraData}
            objectPos={position}
            objectRot={rotation}
            mode={mode}
            onUpdate={handleGizmoUpdate}
            onModeChange={setMode}
          />
        )}
      </Canvas>

      {isVisible && (
        <div className="placement-mode-controls">
          <div className={`mode-pill ${mode === 'translate' ? 'active' : ''}`} onClick={() => setMode('translate')}>
            <kbd>E</kbd>
            <span>Position (Arrows)</span>
          </div>
          <div className="mode-divider" />
          <div className={`mode-pill ${mode === 'rotate' ? 'active' : ''}`} onClick={() => setMode('rotate')}>
            <kbd>R</kbd>
            <span>Rotate (Sphere)</span>
          </div>
        </div>
      )}
    </div>
  );
};

export default Modeler3D;
