/**
 * Three.js 3D Aquatic Environment for Virtual Fisher 2099.
 * Renders procedural neon water, cyber boat, dynamic flex rod, bobber,
 * swimming fish silhouettes, particle systems, and the legendary Glitch Sovereign pet!
 */

class FishingWorld3D {
  constructor(containerId) {
    this.container = document.getElementById(containerId);
    this.scene = null;
    this.camera = null;
    this.renderer = null;

    // Game objects
    this.water = null;
    this.waterGeometry = null;
    this.boat = null;
    this.rod = null;
    this.rodTip = null;
    this.bobber = null;
    this.fishingLine = null;
    this.fishSchool = [];
    this.petObject = null;
    this.sovereignSegments = [];
    this.vortexSingularity = null;
    this.particleSystem = null;

    // State
    this.isCasting = false;
    this.isBiting = false;
    this.lineTension = 0.0; // 0 to 1
    this.currentBiome = "neon_waterfront";
    this.activePetId = null;
    this.clock = new THREE.Clock();

    this.init();
  }

  init() {
    if (!window.THREE) {
      console.warn("Three.js not loaded. Retrying in 200ms...");
      setTimeout(() => this.init(), 200);
      return;
    }

    const width = this.container.clientWidth || window.innerWidth;
    const height = this.container.clientHeight || window.innerHeight;

    // 1. Scene & Camera
    this.scene = new THREE.Scene();
    this.scene.fog = new THREE.FogExp2(0x0a0520, 0.015);

    this.camera = new THREE.PerspectiveCamera(55, width / height, 0.1, 1000);
    this.camera.position.set(0, 4.5, 9.5);
    this.camera.lookAt(0, 1.2, -6.0);

    // 2. Renderer
    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
    this.renderer.setSize(width, height);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.2;
    this.container.appendChild(this.renderer.domElement);

    // 3. Lighting
    const ambient = new THREE.AmbientLight(0x1a2639, 1.2);
    this.scene.add(ambient);

    this.dirLight = new THREE.DirectionalLight(0x00f0ff, 1.5);
    this.dirLight.position.set(20, 40, 20);
    this.scene.add(this.dirLight);

    this.pointLight = new THREE.PointLight(0xff00ea, 2.5, 50);
    this.pointLight.position.set(0, 5, 0);
    this.scene.add(this.pointLight);

    // 4. Build Environment
    this.buildWater();
    this.buildBoat();
    this.buildRod();
    this.buildBobber();
    this.buildFishingLine();
    this.buildFishSchool();
    this.buildParticleVortex();
    this.buildCyberCitySkyline();

    // Resize listener
    window.addEventListener("resize", () => this.onWindowResize());

    // Start loop
    this.animate();
  }

  buildWater() {
    const size = 120;
    const segments = 64;
    this.waterGeometry = new THREE.PlaneGeometry(size, size, segments, segments);
    this.waterGeometry.rotateX(-Math.PI / 2);

    const waterMat = new THREE.MeshStandardMaterial({
      color: 0x004466,
      roughness: 0.15,
      metalness: 0.85,
      wireframe: false,
    });

    this.water = new THREE.Mesh(this.waterGeometry, waterMat);
    this.water.position.y = 0;
    this.scene.add(this.water);
  }

  buildBoat() {
    const boatGroup = new THREE.Group();

    // Catamaran twin hulls
    const hullMat = new THREE.MeshStandardMaterial({
      color: 0x111625,
      metalness: 0.9,
      roughness: 0.2,
    });

    const hullGeom = new THREE.BoxGeometry(0.8, 0.6, 4.2);
    const leftHull = new THREE.Mesh(hullGeom, hullMat);
    leftHull.position.set(-1.4, 0.2, 0);
    const rightHull = new THREE.Mesh(hullGeom, hullMat);
    rightHull.position.set(1.4, 0.2, 0);

    // Deck platform
    const deckGeom = new THREE.BoxGeometry(3.4, 0.2, 3.8);
    const deckMat = new THREE.MeshStandardMaterial({ color: 0x1a2035, metalness: 0.7, roughness: 0.3 });
    const deck = new THREE.Mesh(deckGeom, deckMat);
    deck.position.set(0, 0.45, 0);

    // Neon trim edges
    const trimGeom = new THREE.BoxGeometry(3.45, 0.06, 3.85);
    const trimMat = new THREE.MeshBasicMaterial({ color: 0x00f0ff });
    const trim = new THREE.Mesh(trimGeom, trimMat);
    trim.position.set(0, 0.46, 0);

    // Cyber cockpit / pilot terminal
    const consoleGeom = new THREE.BoxGeometry(1.2, 0.9, 0.5);
    const consoleMat = new THREE.MeshStandardMaterial({ color: 0x090d16, metalness: 0.9 });
    const terminal = new THREE.Mesh(consoleGeom, consoleMat);
    terminal.position.set(0, 0.95, 0.9);

    const screenGeom = new THREE.PlaneGeometry(0.9, 0.45);
    const screenMat = new THREE.MeshBasicMaterial({ color: 0x00f0ff });
    const screen = new THREE.Mesh(screenGeom, screenMat);
    screen.position.set(0, 1.1, 0.64);
    screen.rotation.x = -0.25;

    boatGroup.add(leftHull, rightHull, deck, trim, terminal, screen);
    boatGroup.position.set(0, 0, 3.5);
    this.boat = boatGroup;
    this.scene.add(this.boat);
  }

  buildRod() {
    const rodGroup = new THREE.Group();

    // Rod handle & base
    const handleGeom = new THREE.CylinderGeometry(0.04, 0.05, 0.8, 12);
    const handleMat = new THREE.MeshStandardMaterial({ color: 0x222222, metalness: 0.8 });
    const handle = new THREE.Mesh(handleGeom, handleMat);
    handle.rotation.z = 0.35;
    handle.position.set(1.2, 1.2, 1.8);

    // Flexible rod shaft (segments for bending physics)
    this.rodBones = [];
    const shaftGeom = new THREE.CylinderGeometry(0.015, 0.035, 2.8, 12);
    this.shaftMat = new THREE.MeshStandardMaterial({
      color: 0x00f0ff,
      emissive: 0x00f0ff,
      emissiveIntensity: 0.6,
      metalness: 0.9,
    });
    this.rodShaft = new THREE.Mesh(shaftGeom, this.shaftMat);
    this.rodShaft.position.set(1.6, 2.3, 1.1);
    this.rodShaft.rotation.x = -0.55;
    this.rodShaft.rotation.z = -0.18;

    // Glowing tip
    const tipGeom = new THREE.SphereGeometry(0.06, 12, 12);
    const tipMat = new THREE.MeshBasicMaterial({ color: 0xff00ea });
    this.rodTip = new THREE.Mesh(tipGeom, tipMat);
    this.rodTip.position.set(1.6, 3.4, -0.1);

    rodGroup.add(handle, this.rodShaft, this.rodTip);
    this.rod = rodGroup;
    this.scene.add(this.rod);
  }

  buildBobber() {
    const bobberGroup = new THREE.Group();

    // Spherical floating sensor bobber
    const sphereGeom = new THREE.SphereGeometry(0.22, 16, 16);
    this.bobberMat = new THREE.MeshStandardMaterial({
      color: 0xff00ea,
      emissive: 0xff00ea,
      emissiveIntensity: 0.8,
      roughness: 0.2,
      metalness: 0.8,
    });
    const sphere = new THREE.Mesh(sphereGeom, this.bobberMat);

    // Neon antenna pin
    const pinGeom = new THREE.CylinderGeometry(0.02, 0.02, 0.45, 8);
    const pinMat = new THREE.MeshBasicMaterial({ color: 0x00f0ff });
    const pin = new THREE.Mesh(pinGeom, pinMat);
    pin.position.y = 0.28;

    bobberGroup.add(sphere, pin);
    bobberGroup.position.set(0.5, 0.0, -4.5);
    this.bobber = bobberGroup;
    this.scene.add(this.bobber);
  }

  buildFishingLine() {
    const lineMat = new THREE.LineBasicMaterial({
      color: 0x00f0ff,
      transparent: true,
      opacity: 0.75,
      linewidth: 2,
    });
    const points = [
      new THREE.Vector3(1.6, 3.4, -0.1),
      new THREE.Vector3(1.0, 1.5, -2.2),
      new THREE.Vector3(0.5, 0.0, -4.5),
    ];
    this.lineGeometry = new THREE.BufferGeometry().setFromPoints(points);
    this.fishingLine = new THREE.Line(this.lineGeometry, lineMat);
    this.scene.add(this.fishingLine);
  }

  buildFishSchool() {
    const fishMat = new THREE.MeshBasicMaterial({
      color: 0x00ffea,
      transparent: true,
      opacity: 0.55,
    });

    for (let i = 0; i < 7; i++) {
      const fishGroup = new THREE.Group();
      const bodyGeom = new THREE.ConeGeometry(0.18, 0.7, 8);
      bodyGeom.rotateX(Math.PI / 2);
      const body = new THREE.Mesh(bodyGeom, fishMat);

      const tailGeom = new THREE.BufferGeometry();
      const vertices = new Float32Array([0, 0, 0, 0.15, 0.25, 0.35, -0.15, 0.25, 0.35]);
      tailGeom.setAttribute("position", new THREE.BufferAttribute(vertices, 3));
      const tail = new THREE.Mesh(tailGeom, fishMat);
      tail.position.z = 0.35;

      fishGroup.add(body, tail);

      const radius = 4 + Math.random() * 8;
      const angle = Math.random() * Math.PI * 2;
      fishGroup.position.set(Math.cos(angle) * radius, -0.8 - Math.random() * 1.5, Math.sin(angle) * radius - 3);
      fishGroup.userData = {
        angle: angle,
        radius: radius,
        speed: 0.008 + Math.random() * 0.012,
        depth: fishGroup.position.y,
      };

      this.scene.add(fishGroup);
      this.fishSchool.push(fishGroup);
    }
  }

  buildParticleVortex() {
    const particleCount = 200;
    const geometry = new THREE.BufferGeometry();
    const positions = new Float32Array(particleCount * 3);
    const colors = new Float32Array(particleCount * 3);

    for (let i = 0; i < particleCount; i++) {
      const radius = 2 + Math.random() * 12;
      const angle = Math.random() * Math.PI * 2;
      positions[i * 3] = Math.cos(angle) * radius;
      positions[i * 3 + 1] = Math.random() * 6 - 1;
      positions[i * 3 + 2] = Math.sin(angle) * radius - 15;

      colors[i * 3] = 0.8 + Math.random() * 0.2;
      colors[i * 3 + 1] = 0.0;
      colors[i * 3 + 2] = 0.9;
    }

    geometry.setAttribute("position", new THREE.BufferAttribute(positions, 3));
    geometry.setAttribute("color", new THREE.BufferAttribute(colors, 3));

    const material = new THREE.PointsMaterial({
      size: 0.15,
      vertexColors: true,
      transparent: true,
      opacity: 0.7,
      blending: THREE.AdditiveBlending,
    });

    this.particleSystem = new THREE.Points(geometry, material);
    this.particleSystem.visible = false;
    this.scene.add(this.particleSystem);

    // Singularity Ring for Subspace 0x00
    const ringGeom = new THREE.TorusGeometry(5, 0.4, 16, 64);
    const ringMat = new THREE.MeshBasicMaterial({
      color: 0xff00ea,
      wireframe: true,
    });
    this.vortexSingularity = new THREE.Mesh(ringGeom, ringMat);
    this.vortexSingularity.position.set(0, 4, -25);
    this.vortexSingularity.visible = false;
    this.scene.add(this.vortexSingularity);
  }

  buildCyberCitySkyline() {
    const cityGroup = new THREE.Group();
    const count = 30;

    for (let i = 0; i < count; i++) {
      const w = 2 + Math.random() * 4;
      const h = 8 + Math.random() * 22;
      const d = 2 + Math.random() * 4;
      const geom = new THREE.BoxGeometry(w, h, d);
      const color = Math.random() > 0.5 ? 0x090f26 : 0x050714;
      const mat = new THREE.MeshStandardMaterial({
        color: color,
        roughness: 0.3,
        metalness: 0.9,
      });

      const building = new THREE.Mesh(geom, mat);
      const x = (i - count / 2) * 5 + (Math.random() * 2 - 1);
      const z = -45 - Math.random() * 15;
      building.position.set(x, h / 2 - 2, z);

      // Neon window grid lines
      const edge = new THREE.LineSegments(
        new THREE.EdgesGeometry(geom),
        new THREE.LineBasicMaterial({
          color: Math.random() > 0.6 ? 0x00f0ff : 0xff007f,
          transparent: true,
          opacity: 0.25,
        })
      );
      building.add(edge);
      cityGroup.add(building);
    }
    this.scene.add(cityGroup);
  }

  updateEquippedPet(petId) {
    this.activePetId = petId;

    // Remove old pet
    if (this.petObject) {
      this.scene.remove(this.petObject);
      this.petObject = null;
    }
    this.sovereignSegments.forEach(seg => this.scene.remove(seg));
    this.sovereignSegments = [];

    if (!petId) return;

    if (petId === "pet_sovereign") {
      // BUILD AETHELGARD: THE OVERPOWERED GLITCH SOVEREIGN LEVIATHAN
      const segCount = 14;
      for (let i = 0; i < segCount; i++) {
        const radius = i === 0 ? 0.65 : Math.max(0.18, 0.55 - (i * 0.035));
        const geom = new THREE.SphereGeometry(radius, 12, 12);
        const mat = new THREE.MeshBasicMaterial({
          color: i === 0 ? 0xff00ea : (i % 2 === 0 ? 0x7928ca : 0x00f0ff),
          wireframe: i % 2 === 1,
        });
        const seg = new THREE.Mesh(geom, mat);
        seg.position.set(-3.5, 2.5 + i * 0.2, 0);
        this.scene.add(seg);
        this.sovereignSegments.push(seg);
      }
    } else {
      // Standard Pets (Axolotl, Penguin, Otter, Jelly)
      const group = new THREE.Group();
      let geom, mat;

      if (petId === "pet_axolotl") {
        geom = new THREE.SphereGeometry(0.35, 12, 12);
        mat = new THREE.MeshStandardMaterial({ color: 0x00f0ff, emissive: 0x00aacc, emissiveIntensity: 0.5 });
      } else if (petId === "pet_penguin") {
        geom = new THREE.ConeGeometry(0.3, 0.8, 10);
        mat = new THREE.MeshStandardMaterial({ color: 0x39ff14, emissive: 0x22aa00, emissiveIntensity: 0.4 });
      } else if (petId === "pet_otter") {
        geom = new THREE.CylinderGeometry(0.2, 0.2, 0.7, 10);
        mat = new THREE.MeshStandardMaterial({ color: 0xff007f, emissive: 0xcc0055, emissiveIntensity: 0.5 });
      } else {
        // Jelly
        geom = new THREE.SphereGeometry(0.4, 10, 10);
        mat = new THREE.MeshBasicMaterial({ color: 0x9d00ff, wireframe: true });
      }

      const core = new THREE.Mesh(geom, mat);
      group.add(core);
      group.position.set(-2.4, 1.2, 3.2);
      this.petObject = group;
      this.scene.add(this.petObject);
    }
  }

  updateBiomeTheme(biomeId, biomeData) {
    this.currentBiome = biomeId;
    const isSubspace = biomeId === "subspace_zero";

    if (this.vortexSingularity) this.vortexSingularity.visible = isSubspace;
    if (this.particleSystem) this.particleSystem.visible = isSubspace;

    if (isSubspace) {
      this.scene.fog.color.setHex(0x120024);
      this.scene.fog.density = 0.022;
      this.water.material.color.setHex(0x2b0054);
      this.dirLight.color.setHex(0xff00ea);
      this.pointLight.color.setHex(0x00f0ff);
    } else {
      const hexColor = parseInt((biomeData.bg_sky_color || "#0a0520").replace("#", "0x"));
      const waterHex = parseInt((biomeData.water_color || "#004466").replace("#", "0x"));
      this.scene.fog.color.setHex(hexColor);
      this.scene.fog.density = 0.015;
      this.water.material.color.setHex(waterHex);
      this.dirLight.color.setHex(0x00f0ff);
      this.pointLight.color.setHex(0xff007f);
    }
  }

  triggerBiteAnimation() {
    this.isBiting = true;
    this.bobberMat.color.setHex(0xff003c);
    this.bobberMat.emissive.setHex(0xff003c);
  }

  clearBiteAnimation() {
    this.isBiting = false;
    this.bobberMat.color.setHex(0xff00ea);
    this.bobberMat.emissive.setHex(0xff00ea);
  }

  onWindowResize() {
    if (!this.camera || !this.renderer) return;
    const width = this.container.clientWidth;
    const height = this.container.clientHeight;
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(width, height);
  }

  animate() {
    requestAnimationFrame(() => this.animate());

    const t = this.clock.getElapsedTime();

    // 1. Dynamic Water Surface Waves
    if (this.waterGeometry) {
      const pos = this.waterGeometry.attributes.position;
      for (let i = 0; i < pos.count; i++) {
        const u = pos.getX(i);
        const v = pos.getZ(i);
        const zWave = Math.sin(u * 0.4 + t * 2.2) * 0.15 + Math.cos(v * 0.35 + t * 1.8) * 0.12;
        pos.setY(i, zWave);
      }
      pos.needsUpdate = true;
    }

    // 2. Boat Floating Sway
    if (this.boat) {
      this.boat.position.y = Math.sin(t * 1.8) * 0.06;
      this.boat.rotation.z = Math.cos(t * 1.4) * 0.025;
      this.boat.rotation.x = Math.sin(t * 1.2) * 0.02;
    }

    // 3. Bobber Dynamics
    if (this.bobber) {
      let bobY = Math.sin(t * 3.5) * 0.08;
      if (this.isBiting) {
        bobY -= 0.35 + Math.sin(t * 25.0) * 0.15; // Thrashing dip!
      }
      this.bobber.position.y = bobY;

      // Update Fishing Line connection
      const tipPos = new THREE.Vector3();
      this.rodTip.getWorldPosition(tipPos);
      const bobPos = this.bobber.position;

      // Arc through tension
      const mid = new THREE.Vector3().lerpVectors(tipPos, bobPos, 0.5);
      mid.y -= 0.6 - (this.lineTension * 0.5);

      const curve = new THREE.QuadraticBezierCurve3(tipPos, mid, bobPos);
      const pts = curve.getPoints(12);
      this.lineGeometry.setFromPoints(pts);
    }

    // 4. Rod Bending under Tension
    if (this.rodShaft) {
      const baseAngle = -0.55;
      const flex = this.isBiting ? -0.25 - (this.lineTension * 0.35) : Math.sin(t * 1.8) * 0.02;
      this.rodShaft.rotation.x = baseAngle + flex;
    }

    // 5. Fish Schooling Motion
    this.fishSchool.forEach(fish => {
      const u = fish.userData;
      u.angle += u.speed;
      fish.position.x = Math.cos(u.angle) * u.radius;
      fish.position.z = Math.sin(u.angle) * u.radius - 3;
      fish.position.y = u.depth + Math.sin(t * 3.0 + u.angle) * 0.1;
      fish.rotation.y = -u.angle;
    });

    // 6. Active Pet Animations
    if (this.petObject) {
      this.petObject.position.y = 1.2 + Math.sin(t * 2.5) * 0.15;
      this.petObject.rotation.y = t * 1.2;
    }

    // 7. AETHELGARD LEVIATHAN ORBITAL DYNAMICS
    if (this.sovereignSegments.length > 0) {
      const radius = 5.5;
      const leadAngle = t * 0.9;

      this.sovereignSegments.forEach((seg, idx) => {
        const segAngle = leadAngle - idx * 0.22;
        const x = Math.cos(segAngle) * (radius + Math.sin(t + idx * 0.1) * 0.4);
        const z = Math.sin(segAngle) * (radius + Math.cos(t + idx * 0.1) * 0.4) + 1.0;
        const y = 2.8 + Math.sin(t * 2.0 + idx * 0.35) * 0.6;
        seg.position.set(x, y, z);
      });
    }

    // 8. Singularity Vortex Rotation
    if (this.vortexSingularity && this.vortexSingularity.visible) {
      this.vortexSingularity.rotation.z += 0.015;
      this.vortexSingularity.rotation.x = Math.sin(t * 0.5) * 0.2;
    }
    if (this.particleSystem && this.particleSystem.visible) {
      this.particleSystem.rotation.y += 0.005;
    }

    // 9. Camera Sway
    this.camera.position.x = Math.sin(t * 0.4) * 0.2;
    this.camera.position.y = 4.5 + Math.cos(t * 0.5) * 0.08;

    this.renderer.render(this.scene, this.camera);
  }
}

window.FishingWorld3D = FishingWorld3D;
