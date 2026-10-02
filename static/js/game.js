/**
 * Virtual Fisher 2099 - Main Game Controller.
 * Manages player state, UI updates, audio triggers, 3D bridge, and Jev AI events.
 */

class VirtualFisherApp {
  constructor() {
    this.state = null;
    this.catalog = null;
    this.world3D = null;
    this.isFishing = false;
    this.isBiting = false;
    this.autoFishActive = false;
    this.autoFishTimer = null;
    this.petTickTimer = null;
    this.activeModal = null;

    // Mini-game tension simulation
    this.tension = 50.0;
    this.tensionDir = 1;
    this.tensionInterval = null;

    this.init();
  }

  async init() {
    // 1. Initialize 3D World
    this.world3D = new window.FishingWorld3D("viewport-container");

    // 2. Fetch Catalog and Initial State
    await this.fetchCatalog();
    await this.fetchState();

    // 3. Bind UI Events
    this.bindEvents();

    // 4. Start Pet Passive Tick
    this.petTickTimer = setInterval(() => this.collectPetTick(), 8000);

    console.log("🐟 Virtual Fisher 2099 initialized successfully.");
  }

  async fetchCatalog() {
    try {
      const res = await fetch("/api/catalog");
      this.catalog = await res.json();
    } catch (e) {
      console.error("Failed to load catalog:", e);
    }
  }

  async fetchState() {
    try {
      const res = await fetch("/api/state");
      const data = await res.json();
      this.state = data.player;

      this.updateHUD(data);
      if (data.equipped.biome) {
        this.world3D.updateBiomeTheme(data.player.current_biome, data.equipped.biome);
      }
      this.world3D.updateEquippedPet(data.player.equipped_pet);
    } catch (e) {
      console.error("Failed to fetch state:", e);
    }
  }

  updateHUD(data) {
    const p = data.player;
    document.getElementById("stat-credits").textContent = p.credits.toLocaleString();
    document.getElementById("stat-gems").textContent = p.gems;
    document.getElementById("stat-level").textContent = p.level;

    // XP Bar
    const xpPercent = Math.min(100, Math.floor((p.xp / p.xp_next) * 100));
    document.getElementById("xp-fill").style.width = `${xpPercent}%`;
    document.getElementById("xp-text").textContent = `${p.xp} / ${p.xp_next} XP`;

    // Biome
    const biome = data.equipped.biome;
    if (biome) {
      const biomeText = document.getElementById("biome-name-display");
      biomeText.textContent = biome.name;
      biomeText.style.color = biome.theme_color;
    }

    // Jev Status
    if (data.jev) {
      document.getElementById("jev-mode-label").textContent = data.jev.mode;
    }

    // Fish Cooler Count in Sell Button
    const fishCount = p.inventory_fish ? p.inventory_fish.length : 0;
    document.getElementById("btn-sell-all").textContent = `💰 SELL ALL (${fishCount})`;
  }

  bindEvents() {
    // Cast Line Button
    const castBtn = document.getElementById("btn-cast");
    castBtn.addEventListener("click", () => this.handleCastOrReel());

    // Auto-Fish Button
    const autoBtn = document.getElementById("btn-auto-fish");
    autoBtn.addEventListener("click", () => this.toggleAutoFish());

    // Sell All Button
    const sellBtn = document.getElementById("btn-sell-all");
    sellBtn.addEventListener("click", () => this.handleSellAll());

    // Reel In Mini-Game Button
    const reelBtn = document.getElementById("btn-reel-in");
    reelBtn.addEventListener("click", () => this.handleReelSuccess());

    // Navigation Dock Buttons
    document.querySelectorAll(".dock-btn").forEach(btn => {
      btn.addEventListener("click", (e) => {
        const modalId = btn.dataset.modal;
        this.openModal(modalId);
      });
    });

    // Close Modals
    document.querySelectorAll(".modal-close").forEach(btn => {
      btn.addEventListener("click", () => this.closeModals());
    });
    document.querySelectorAll(".modal-overlay").forEach(overlay => {
      overlay.addEventListener("click", (e) => {
        if (e.target === overlay) this.closeModals();
      });
    });

    // Oracle Query
    const oracleBtn = document.getElementById("btn-send-oracle");
    const oracleInput = document.getElementById("oracle-input");
    oracleBtn.addEventListener("click", () => this.sendOracleQuery());
    oracleInput.addEventListener("keydown", (e) => {
      if (e.key === "Enter") this.sendOracleQuery();
    });

    // Keyboard shortcut (Space to cast or reel)
    window.addEventListener("keydown", (e) => {
      if (e.code === "Space" && e.target.tagName !== "INPUT") {
        e.preventDefault();
        this.handleCastOrReel();
      }
      if (e.key === "Escape") {
        this.closeModals();
      }
    });

    // Sound toggle
    document.getElementById("btn-mute-toggle").addEventListener("click", () => {
      const isMuted = window.CyberAudio.toggleMute();
      document.getElementById("btn-mute-toggle").textContent = isMuted ? "🔇" : "🔊";
    });
  }

  async handleCastOrReel() {
    if (this.isBiting) {
      this.handleReelSuccess();
      return;
    }
    if (this.isFishing) return;

    this.startCasting();
  }

  async startCasting() {
    this.isFishing = true;
    this.isBiting = false;

    window.CyberAudio.playCast();

    const castBtn = document.getElementById("btn-cast");
    castBtn.classList.add("waiting");
    castBtn.textContent = "⏳ WAITING FOR BITE...";

    try {
      const res = await fetch("/api/cast", { method: "POST" });
      const data = await res.json();

      setTimeout(() => window.CyberAudio.playSplash(), 400);

      // Wait for bite
      const biteMs = (data.bite_time || 2.5) * 1000;
      setTimeout(() => {
        if (this.isFishing) {
          this.triggerBite();
        }
      }, biteMs);

    } catch (e) {
      console.error("Cast failed:", e);
      this.resetFishingState();
    }
  }

  triggerBite() {
    this.isBiting = true;
    window.CyberAudio.playBite();
    this.world3D.triggerBiteAnimation();

    const castBtn = document.getElementById("btn-cast");
    castBtn.textContent = "💥 BITE! CLICK TO REEL!";
    castBtn.classList.remove("waiting");
    castBtn.classList.add("interactive");

    // Show Reel Widget
    const reelWidget = document.getElementById("reel-widget");
    reelWidget.classList.remove("hidden");

    // Start tension bar oscillating
    this.startTensionSimulation();

    // If Auto-Fish is active or player has Aethelgard (instant catch), reel immediately!
    const hasSovereign = this.state && this.state.equipped_pet === "pet_sovereign";
    if (this.autoFishActive || hasSovereign) {
      setTimeout(() => {
        this.handleReelSuccess();
      }, hasSovereign ? 250 : 600);
    }
  }

  startTensionSimulation() {
    this.tension = 45.0;
    this.tensionInterval = setInterval(() => {
      this.tension += (Math.random() * 8 + 4) * this.tensionDir;
      if (this.tension >= 92) this.tensionDir = -1;
      if (this.tension <= 15) this.tensionDir = 1;

      const fill = document.getElementById("tension-fill");
      if (fill) fill.style.width = `${this.tension}%`;
      this.world3D.lineTension = this.tension / 100.0;
    }, 60);
  }

  stopTensionSimulation() {
    if (this.tensionInterval) {
      clearInterval(this.tensionInterval);
      this.tensionInterval = null;
    }
    this.world3D.lineTension = 0.0;
  }

  async handleReelSuccess() {
    if (!this.isBiting) return;

    window.CyberAudio.playReelClick();
    this.stopTensionSimulation();
    this.world3D.clearBiteAnimation();

    document.getElementById("reel-widget").classList.add("hidden");

    try {
      const res = await fetch("/api/catch", { method: "POST" });
      const data = await res.json();

      if (data.success) {
        const f = data.fish;
        const isRare = ["Epic", "Legendary", "Mythic", "Cosmic", "Glitch"].includes(f.rarity);
        window.CyberAudio.playCatchSuccess(isRare);

        this.showToast(`🎉 Caught ${f.rarity} ${f.name}! (${f.weight} kg - 💵 ${f.value.toLocaleString()})`, f.is_anomaly ? "anomaly" : "");

        if (data.double_caught && data.second_fish) {
          const sf = data.second_fish;
          this.showToast(`✨ [DOUBLE HOOK!] Caught bonus ${sf.name} (${sf.weight} kg)!`, "level");
        }

        if (data.leveled_up) {
          this.showToast(`🆙 LEVEL UP! Reached Level ${data.new_level}! +3 💎 Gems`, "level");
        }

        for (const drop of (data.dropped_items || [])) {
          this.showToast(`🌟 [RARE RELIC FOUND] ${drop.name} ${drop.icon}!`, "anomaly");
        }

        // Update Jev telemetry display
        if (data.jev_telemetry) {
          const jt = data.jev_telemetry;
          this.appendTerminalLog(`[JEV DECISION] Maneuver: ${jt.fish_action} | Threat: ${jt.threat_level} | Latency: ${jt.latency_ms}ms`, "term-system");
        }
      }

      await this.fetchState();
    } catch (e) {
      console.error("Catch resolution failed:", e);
    } finally {
      this.resetFishingState();

      // If Auto-Fish is on, schedule next cast
      if (this.autoFishActive) {
        this.autoFishTimer = setTimeout(() => {
          if (this.autoFishActive) this.startCasting();
        }, 1200);
      }
    }
  }

  resetFishingState() {
    this.isFishing = false;
    this.isBiting = false;
    this.stopTensionSimulation();
    this.world3D.clearBiteAnimation();

    const castBtn = document.getElementById("btn-cast");
    castBtn.classList.remove("waiting");
    castBtn.textContent = "🎣 CAST LINE (SPACE)";
  }

  toggleAutoFish() {
    this.autoFishActive = !this.autoFishActive;
    const btn = document.getElementById("btn-auto-fish");

    if (this.autoFishActive) {
      btn.classList.add("active");
      btn.textContent = "🤖 AUTO-FISH: ON (JEV AI)";
      this.showToast("🤖 Jev AI Auto-Angler Engaged!");
      if (!this.isFishing) {
        this.startCasting();
      }
    } else {
      btn.classList.remove("active");
      btn.textContent = "🤖 AUTO-FISH (JEV AI)";
      if (this.autoFishTimer) clearTimeout(this.autoFishTimer);
      this.showToast("Jev Auto-Angler disengaged.");
    }
  }

  async handleSellAll() {
    try {
      const res = await fetch("/api/sell_all", { method: "POST" });
      const data = await res.json();

      if (data.count === 0) {
        this.showToast("Your cooler is empty. Cast a line first!");
      } else {
        window.CyberAudio.playCatchSuccess(true);
        this.showToast(`💰 Sold ${data.count} fish for 💵 ${data.final_value.toLocaleString()} credits! (x${data.multiplier} Pet Boost)`);
        await this.fetchState();
      }
    } catch (e) {
      console.error("Sell all failed:", e);
    }
  }

  async collectPetTick() {
    try {
      const res = await fetch("/api/pets/tick", { method: "POST" });
      const data = await res.json();
      if (data.awarded) {
        this.showToast(`🐾 ${data.pet_name} harvested +💵 ${data.credits} & +💎 ${data.gems}!`);
        await this.fetchState();
      }
    } catch (e) {
      // quiet poll
    }
  }

  // Modals Management
  openModal(modalId) {
    this.closeModals();
    const overlay = document.getElementById(`modal-${modalId}`);
    if (overlay) {
      overlay.classList.remove("hidden");
      this.activeModal = modalId;
      this.renderModalContent(modalId);
    }
  }

  closeModals() {
    document.querySelectorAll(".modal-overlay").forEach(m => m.classList.add("hidden"));
    this.activeModal = null;
  }

  renderModalContent(modalId) {
    if (modalId === "shop") this.renderShop();
    else if (modalId === "pets") this.renderPets();
    else if (modalId === "biomes") this.renderBiomes();
    else if (modalId === "aquarium") this.renderAquarium();
    else if (modalId === "secrets") this.renderSecrets();
  }

  renderShop() {
    const rodsContainer = document.getElementById("shop-rods-grid");
    const baitsContainer = document.getElementById("shop-baits-grid");

    // Rods
    rodsContainer.innerHTML = "";
    (this.catalog.rods || []).forEach(r => {
      const owned = this.state.inventory_rods.includes(r.id);
      const isEquipped = this.state.equipped_rod === r.id;

      const card = document.createElement("div");
      card.className = `cyber-card ${isEquipped ? "equipped" : ""} ${r.is_secret ? "secret-card" : ""}`;
      card.innerHTML = `
        <div>
          <div class="card-title" style="color: ${r.glow_color}">
            <span>🎣</span> ${r.name}
            ${r.is_secret ? '<span style="color:#ff00ea;font-size:0.75rem;">[SECRET]</span>' : ''}
          </div>
          <div class="card-desc" style="margin-top:6px;">${r.description}</div>
          <div class="card-perk" style="margin-top:8px;">
            Luck: x${r.luck_multiplier} | Reel Boost: +${Math.round(r.reel_speed_boost * 100)}%
          </div>
        </div>
        <div class="card-footer">
          <div class="price-tag" style="color:var(--neon-green)">
            ${owned ? "OWNED" : (r.is_secret ? "RITUAL / SECRET" : `💵 ${r.cost.toLocaleString()}${r.gem_cost > 0 ? ` + 💎 ${r.gem_cost}` : ""}`)}
          </div>
          ${owned ? `
            <button class="btn-equip" ${isEquipped ? 'disabled style="opacity:0.5"' : ''} onclick="app.equipItem('rod', '${r.id}')">
              ${isEquipped ? "EQUIPPED" : "EQUIP"}
            </button>
          ` : (r.is_secret ? `
            <span style="font-size:0.75rem;color:var(--text-dim);">Oracle/Altar Only</span>
          ` : `
            <button class="btn-buy" onclick="app.buyRod('${r.id}')">BUY</button>
          `)}
        </div>
      `;
      rodsContainer.appendChild(card);
    });

    // Baits
    baitsContainer.innerHTML = "";
    (this.catalog.baits || []).forEach(b => {
      const count = this.state.inventory_baits[b.id] || 0;
      const isEquipped = this.state.equipped_bait === b.id;

      const card = document.createElement("div");
      card.className = `cyber-card ${isEquipped ? "equipped" : ""}`;
      card.innerHTML = `
        <div>
          <div class="card-title">
            <span>${b.icon}</span> ${b.name}
            ${b.is_secret ? '<span style="color:#ff00ea;font-size:0.75rem;">[SECRET]</span>' : ''}
          </div>
          <div class="card-desc" style="margin-top:6px;">${b.description}</div>
          <div class="card-perk" style="margin-top:8px;">
            Bonus Luck: +${Math.round(b.luck_bonus * 100)}% | Owned: ${count}
          </div>
        </div>
        <div class="card-footer">
          <div class="price-tag" style="color:var(--neon-green)">
            💵 ${b.cost.toLocaleString()} (x10)
          </div>
          <div style="display:flex;gap:6px;">
            <button class="btn-buy" onclick="app.buyBait('${b.id}', 10)">BUY x10</button>
            <button class="btn-equip" ${isEquipped ? 'disabled style="opacity:0.5"' : ''} onclick="app.equipItem('bait', '${b.id}')">
              ${isEquipped ? "ACTIVE" : "EQUIP"}
            </button>
          </div>
        </div>
      `;
      baitsContainer.appendChild(card);
    });
  }

  async buyRod(rodId) {
    try {
      const res = await fetch("/api/shop/buy_rod", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ rod_id: rodId }),
      });
      const data = await res.json();
      this.showToast(data.message);
      await this.fetchState();
      this.renderShop();
    } catch (e) {
      console.error(e);
    }
  }

  async buyBait(baitId, count = 10) {
    try {
      const res = await fetch("/api/shop/buy_bait", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ bait_id: baitId, count }),
      });
      const data = await res.json();
      this.showToast(data.message);
      await this.fetchState();
      this.renderShop();
    } catch (e) {
      console.error(e);
    }
  }

  async equipItem(type, id) {
    try {
      const res = await fetch("/api/equip", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ type, id }),
      });
      const data = await res.json();
      this.showToast(data.message);
      await this.fetchState();
      this.renderModalContent(this.activeModal);
    } catch (e) {
      console.error(e);
    }
  }

  renderPets() {
    const petsContainer = document.getElementById("pets-grid");
    petsContainer.innerHTML = "";

    (this.catalog.pets || []).forEach(p => {
      const unlocked = this.state.unlocked_pets.includes(p.id);
      const isEquipped = this.state.equipped_pet === p.id;

      const card = document.createElement("div");
      card.className = `cyber-card ${isEquipped ? "equipped" : ""} ${p.is_overpowered ? "godlike-card" : ""}`;
      card.innerHTML = `
        <div>
          <div class="card-title" style="color: ${p.glow_color}">
            <span style="font-size:1.4rem;">${p.icon}</span> ${p.name}
            ${p.is_overpowered ? '<span style="color:#ff00ea;font-size:0.75rem;">[TRANSCENDENT]</span>' : ''}
          </div>
          <div style="font-size:0.75rem;color:var(--neon-cyan);margin-top:2px;">${p.title}</div>
          <div class="card-desc" style="margin-top:6px;">${p.description}</div>
          <div class="card-perk" style="margin-top:8px;">
            ⚡ ${p.passive_description}
          </div>
        </div>
        <div class="card-footer" style="margin-top:10px;">
          <div class="price-tag" style="color:${unlocked ? 'var(--neon-green)' : 'var(--text-dim)'}">
            ${unlocked ? "UNLOCKED" : (p.is_overpowered ? "GENESIS RITUAL" : "LOCKED")}
          </div>
          ${unlocked ? `
            <button class="btn-equip" ${isEquipped ? 'disabled style="opacity:0.5"' : ''} onclick="app.equipItem('pet', '${p.id}')">
              ${isEquipped ? "ACTIVE COMPANION" : "SUMMON"}
            </button>
          ` : `
            <span style="font-size:0.75rem;color:var(--text-dim);">${p.is_overpowered ? "Synthesize in Altar" : "Level Unlock"}</span>
          `}
        </div>
      `;
      petsContainer.appendChild(card);
    });

    // Update Genesis Altar Requirement counters
    const cores = this.state.special_items.glitch_core || 0;
    const ciphers = this.state.special_items.void_cipher_key || 0;
    const pearls = this.state.special_items.singularity_pearl || 0;

    const coreSlot = document.getElementById("altar-slot-core");
    const cipherSlot = document.getElementById("altar-slot-cipher");
    const pearlSlot = document.getElementById("altar-slot-pearl");

    if (coreSlot) {
      coreSlot.className = `req-slot ${cores >= 1 ? 'fulfilled' : ''}`;
      document.getElementById("slot-core-count").textContent = `${cores} / 1`;
    }
    if (cipherSlot) {
      cipherSlot.className = `req-slot ${ciphers >= 1 ? 'fulfilled' : ''}`;
      document.getElementById("slot-cipher-count").textContent = `${ciphers} / 1`;
    }
    if (pearlSlot) {
      pearlSlot.className = `req-slot ${pearls >= 3 ? 'fulfilled' : ''}`;
      document.getElementById("slot-pearl-count").textContent = `${pearls} / 3`;
    }
  }

  async triggerGenesisRitual() {
    try {
      const res = await fetch("/api/secrets/genesis", { method: "POST" });
      const data = await res.json();

      if (data.success) {
        window.CyberAudio.playGenesisAwakening();
        this.showToast("🐉 AETHELGARD HAS AWAKENED!", "anomaly");
        this.appendTerminalLog("[GENESIS RITUAL ACCOMPLISHED] Aethelgard the Glitch Sovereign now circles your vessel.", "term-secret");
        await this.fetchState();
        this.renderPets();
      } else {
        this.showToast(data.message);
      }
    } catch (e) {
      console.error(e);
    }
  }

  renderBiomes() {
    const biomesContainer = document.getElementById("biomes-grid");
    biomesContainer.innerHTML = "";

    (this.catalog.biomes || []).forEach(b => {
      const unlocked = this.state.unlocked_biomes.includes(b.id);
      const isCurrent = this.state.current_biome === b.id;

      const card = document.createElement("div");
      card.className = `cyber-card ${isCurrent ? "equipped" : ""} ${b.is_secret ? "secret-card" : ""}`;
      card.innerHTML = `
        <div>
          <div class="card-title" style="color: ${b.theme_color}">
            <span>🌊</span> ${b.name}
            ${b.is_secret ? '<span style="color:#ff00ea;font-size:0.75rem;">[SECRET DIMENSION]</span>' : ''}
          </div>
          <div class="card-desc" style="margin-top:6px;">${b.description}</div>
          <div class="card-perk" style="margin-top:8px;">
            Required Clearance: Level ${b.required_level} | Warp Cost: 💵 ${b.travel_cost.toLocaleString()}
          </div>
        </div>
        <div class="card-footer" style="margin-top:10px;">
          <div class="price-tag" style="color:${unlocked ? 'var(--neon-cyan)' : 'var(--neon-magenta)'}">
            ${isCurrent ? "CURRENT SECTOR" : (unlocked ? "CLEARANCE GRANTED" : "LOCKED")}
          </div>
          ${unlocked ? `
            <button class="btn-equip" ${isCurrent ? 'disabled style="opacity:0.5"' : ''} onclick="app.travelToBiome('${b.id}')">
              ${isCurrent ? "DOCKED" : "WARP JUMP"}
            </button>
          ` : `
            <span style="font-size:0.75rem;color:var(--text-dim);">${b.is_secret ? "Subspace Coordinates Required" : `Reach Level ${b.required_level}`}</span>
          `}
        </div>
      `;
      biomesContainer.appendChild(card);
    });
  }

  async travelToBiome(biomeId) {
    try {
      window.CyberAudio.playPortalWarp();
      const res = await fetch("/api/biomes/travel", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ biome_id: biomeId }),
      });
      const data = await res.json();
      this.showToast(data.message, biomeId === "subspace_zero" ? "anomaly" : "");
      await this.fetchState();
      this.renderBiomes();
    } catch (e) {
      console.error(e);
    }
  }

  renderAquarium() {
    const catalogContainer = document.getElementById("aquarium-grid");
    catalogContainer.innerHTML = "";

    const counts = this.state.fish_catalog_counts || {};

    (this.catalog.species || []).forEach(f => {
      const caughtCount = counts[f.id] || 0;
      const discovered = caughtCount > 0;

      const card = document.createElement("div");
      card.className = `cyber-card ${f.is_anomaly ? "secret-card" : ""}`;
      card.style.opacity = discovered ? "1.0" : "0.5";

      card.innerHTML = `
        <div>
          <div class="card-title" style="color: ${f.color}">
            <span style="font-size:1.4rem;">${discovered ? f.emoji : "❓"}</span>
            ${discovered ? f.name : "UNKNOWN SIGNAL"}
            <span style="font-size:0.72rem;background:rgba(255,255,255,0.1);padding:2px 6px;border-radius:4px;">${f.rarity}</span>
          </div>
          <div class="card-desc" style="margin-top:6px;">
            ${discovered ? f.description : "Undiscovered bio-signal. Cast lines in corresponding sectors."}
          </div>
          <div class="card-perk" style="margin-top:8px;">
            Base: 💵 ${f.base_value} | Range: ${f.min_weight} - ${f.max_weight} kg
          </div>
        </div>
        <div class="card-footer" style="margin-top:6px;">
          <span style="font-family:var(--font-mono);font-size:0.8rem;color:var(--neon-green)">
            Times Caught: ${caughtCount}
          </span>
        </div>
      `;
      catalogContainer.appendChild(card);
    });
  }

  renderSecrets() {
    const relics = this.state.special_items || {};
    document.getElementById("relic-count-core").textContent = relics.glitch_core || 0;
    document.getElementById("relic-count-pearl").textContent = relics.singularity_pearl || 0;
    document.getElementById("relic-count-cipher").textContent = relics.void_cipher_key || 0;
    document.getElementById("relic-count-fragment").textContent = relics.chrono_fragment || 0;

    const frags = relics.chrono_fragment || 0;
    const craftBtn = document.getElementById("btn-craft-chronos");
    if (craftBtn) {
      craftBtn.disabled = frags < 3;
    }
  }

  async craftChronosRod() {
    try {
      const res = await fetch("/api/secrets/craft_chronos", { method: "POST" });
      const data = await res.json();
      this.showToast(data.message, "anomaly");
      await this.fetchState();
      this.renderSecrets();
    } catch (e) {
      console.error(e);
    }
  }

  // Jev Cyber Oracle Interaction
  async sendOracleQuery() {
    const input = document.getElementById("oracle-input");
    const query = input.value.trim();
    if (!query) return;

    this.appendTerminalLog(`> ${query}`, "term-player");
    input.value = "";

    try {
      const res = await fetch("/api/oracle", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ query }),
      });
      const data = await res.json();

      this.appendTerminalLog(`[Jev System One (Resonance: ${data.resonance_score}/100)]:`, "term-oracle");
      this.appendTerminalLog(data.message, data.unlock ? "term-secret" : "term-system");

      if (data.unlock) {
        window.CyberAudio.playCatchSuccess(true);
        this.showToast(`✨ UNLOCKED: ${data.unlock}!`, "anomaly");
        await this.fetchState();
      }
    } catch (e) {
      this.appendTerminalLog(`[Error] Terminal connection to Jev failed: ${e}`, "term-secret");
    }
  }

  appendTerminalLog(msg, cssClass = "term-system") {
    const logs = document.getElementById("terminal-logs");
    if (!logs) return;

    const div = document.createElement("div");
    div.className = `term-line ${cssClass}`;
    div.textContent = msg;
    logs.appendChild(div);
    logs.scrollTop = logs.scrollHeight;
  }

  showToast(message, type = "") {
    const container = document.getElementById("toast-container");
    if (!container) return;

    const toast = document.createElement("div");
    toast.className = `toast ${type}`;
    toast.textContent = message;
    container.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = "0";
      toast.style.transform = "translateX(20px)";
      setTimeout(() => toast.remove(), 300);
    }, 4000);
  }
}

window.addEventListener("DOMContentLoaded", () => {
  window.app = new VirtualFisherApp();
});
