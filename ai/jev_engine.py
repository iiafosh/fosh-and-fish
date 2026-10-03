"""
Jev System One AI Engine for Virtual Fisher 2099.
Integrates with TypeSafe AI's Jev model for typed, high-speed, probabilistic decision-making.
Includes a fully compliant high-fidelity local fallback emulator when no API key is configured.
"""

import os
import time
import random
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, field

# Attempt to import typesafe_sdk
try:
    from typesafe_sdk import TypeSafeClient, Choice, Noul, Score
    TYPESAFE_AVAILABLE = True
except ImportError:
    TYPESAFE_AVAILABLE = False
    TypeSafeClient = None
    Choice = None
    Noul = None
    Score = None


@dataclass
class JevDecisionRecord:
    timestamp: float
    mode: str  # "TypeSafe Cloud API" | "Local Jev System One"
    action_type: str
    input_state: Dict[str, Any]
    choices: Dict[str, str] = field(default_factory=dict)
    nouls: Dict[str, float] = field(default_factory=dict)
    scores: Dict[str, Any] = field(default_factory=dict)
    latency_ms: float = 0.0
    summary: str = ""


class JevDecisionEngine:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.environ.get("TYPESAFE_API_KEY") or os.environ.get("JEV_API_KEY")
        self.client = None
        self.history: List[JevDecisionRecord] = []
        
        if self.api_key and TYPESAFE_AVAILABLE:
            try:
                self.client = TypeSafeClient(api_key=self.api_key)
                print(f"[JevEngine] Initialized TypeSafe Jev Client with remote API key.")
            except Exception as e:
                print(f"[JevEngine] Failed to connect to TypeSafe client: {e}. Falling back to Local Jev Engine.")
                self.client = None
        else:
            print("[JevEngine] Running with Local Jev System One Decision Core (high-precision local emulator).")

    @property
    def mode_name(self) -> str:
        return "TypeSafe Cloud API (Jev)" if self.client else "Local Jev System One Core"

    def evaluate_fish_combat(self, state: Dict[str, Any]) -> Dict[str, Any]:
        """
        Uses Jev Choice & Score to determine the fish's combat maneuver and threat rating during reeling.
        """
        start_time = time.time()
        tension = float(state.get("tension", 50.0))
        rarity = state.get("fish_rarity", "Common")
        fish_weight = float(state.get("fish_weight", 5.0))
        rod_tier = int(state.get("rod_tier", 1))

        if self.client and TYPESAFE_AVAILABLE:
            try:
                questions = {
                    "fish_action": Choice(
                        instructions="Determine the fish's reactive combat maneuver based on tension and strength.",
                        criteria={
                            "thrash_furious": "Violent thrash causing sudden tension spikes",
                            "deep_dive": "Sudden plunge downwards dragging the line",
                            "erratic_zigzag": "Unpredictable lateral dash requiring reel release",
                            "exhausted_glide": "Fish is weary, allowing smooth reeling",
                        },
                    ),
                    "threat_level": Score(
                        instructions="Score the risk of line snap on a 4-tier rubric.",
                        criteria=["calm", "moderate", "severe", "critical"],
                    ),
                    "anomaly_burst": Noul(
                        instructions="Is a quantum space-time anomaly triggered during this struggle?",
                    ),
                }
                res = self.client.system_one(state=state, questions=questions, timeout=2.5)
                latency = (time.time() - start_time) * 1000.0

                action_val = res.choices["fish_action"].choice
                threat_val = res.scores["threat_level"].score
                anomaly_prob = float(res.nouls["anomaly_burst"].noul)

                record = JevDecisionRecord(
                    timestamp=time.time(),
                    mode="TypeSafe Cloud API",
                    action_type="fish_combat",
                    input_state=state,
                    choices={"fish_action": action_val},
                    nouls={"anomaly_burst": anomaly_prob},
                    scores={"threat_level": threat_val},
                    latency_ms=round(latency, 2),
                    summary=f"Jev decided maneuver '{action_val}' (Threat: {threat_val})",
                )
                self.history.append(record)
                return {
                    "fish_action": action_val,
                    "threat_level": threat_val,
                    "anomaly_burst": anomaly_prob > 0.65,
                    "mode": record.mode,
                    "latency_ms": record.latency_ms,
                }
            except Exception as e:
                # Fallback to local on connection or timeout issue
                pass

        # Local Jev System One Fallback
        latency = (time.time() - start_time) * 1000.0 + random.uniform(1.2, 5.8)
        
        # High precision rubric
        if tension > 80:
            threat_val = "critical"
            weights = [0.45, 0.35, 0.15, 0.05]
        elif tension > 60:
            threat_val = "severe"
            weights = [0.35, 0.40, 0.20, 0.05]
        elif tension > 30:
            threat_val = "moderate"
            weights = [0.20, 0.30, 0.35, 0.15]
        else:
            threat_val = "calm"
            weights = [0.05, 0.15, 0.30, 0.50]

        actions = ["thrash_furious", "deep_dive", "erratic_zigzag", "exhausted_glide"]
        action_val = random.choices(actions, weights=weights)[0]

        # Anomaly probability
        biome = state.get("biome", "")
        anomaly_base = 0.08
        if biome == "subspace_zero":
            anomaly_base = 0.65
        elif biome in ["abyssal_trench", "orbital_ocean"]:
            anomaly_base = 0.22
        if rarity in ["Mythic", "Cosmic", "Glitch"]:
            anomaly_base += 0.30

        anomaly_prob = min(0.99, anomaly_base + random.uniform(-0.04, 0.04))

        record = JevDecisionRecord(
            timestamp=time.time(),
            mode="Local Jev System One",
            action_type="fish_combat",
            input_state=state,
            choices={"fish_action": action_val},
            nouls={"anomaly_burst": round(anomaly_prob, 3)},
            scores={"threat_level": threat_val},
            latency_ms=round(latency, 2),
            summary=f"Local Jev decided '{action_val}' with threat '{threat_val}'",
        )
        self.history.append(record)
        return {
            "fish_action": action_val,
            "threat_level": threat_val,
            "anomaly_burst": anomaly_prob > 0.65,
            "mode": record.mode,
            "latency_ms": record.latency_ms,
        }

    def evaluate_ai_angler_step(self, state: Dict[str, Any]) -> Dict[str, Any]:
        """
        Autonomous Jev Angler decision: decides whether to pull, release, or pump the rod.
        """
        start_time = time.time()
        tension = float(state.get("tension", 50.0))
        max_tension = float(state.get("max_tension", 100.0))
        ratio = tension / max_tension

        if ratio >= 0.85:
            decision = "RELEASE_LINE"
            confidence = 0.96
            reasoning = "Tension critically close to snap threshold. Relaxing spool."
        elif ratio <= 0.35:
            decision = "PULL_POWER"
            confidence = 0.92
            reasoning = "Low resistance detected. Engaging high-torque tachyon pull."
        else:
            decision = "PUMP_STEADY"
            confidence = 0.88
            reasoning = "Optimal tension window. Maintaining steady rhythmic reel."

        latency = (time.time() - start_time) * 1000.0 + random.uniform(1.0, 3.5)
        return {
            "decision": decision,
            "confidence": confidence,
            "reasoning": reasoning,
            "tension_ratio": round(ratio, 2),
            "latency_ms": round(latency, 2),
            "mode": self.mode_name,
        }

    def consult_oracle(self, player_query: str, player_state: Dict[str, Any]) -> Dict[str, Any]:
        """
        Cyber Oracle powered by Jev: processes player prompts, riddles, secrets, and easter eggs.
        """
        start_time = time.time()
        q = player_query.strip().upper()
        
        # Secret Keys & Easter Eggs detection
        if "TEMPORAL_HOOK" in q or "CHRONOS_ROD" in q or "SECRET ROD" in q:
            verdict = "SECRET_ROD_GRANTED"
            msg = "🌌 [QUANTUM OVERRIDE ACCEPTED] The Chronos Singularity Rod manifests into your inventory! Line strength unlocked."
            score = 100
            unlock = "rod_chronos"
        elif "0XDEADBEEF" in q or "KONAMI" in q or "DEV_ROD" in q:
            verdict = "DEV_ROD_GRANTED"
            msg = "👾 [DEVELOPER ROOT ACCESSED] 0xDEADBEEF Glitch Dev Rod loaded. Matrix physics bypassed."
            score = 100
            unlock = "rod_dev_glitch"
        elif "404-0X00-VOID" in q or "INIT_CHRONO_JUMP" in q or "SECRET BIOME" in q or "SUBSPACE" in q:
            verdict = "PORTAL_COORDINATES_LOCKED"
            msg = "🌀 [SPACETIME FISSURE OPENED] Quantum coordinates 404-0x00-VOID confirmed. Subspace 0x00 portal is now unlocked in your Nav Computer!"
            score = 100
            unlock = "subspace_zero"
        elif "GENESIS" in q or "OUROBOROS" in q or "SOVEREIGN" in q or "AETHELGARD" in q:
            verdict = "GENESIS_CIPHER_REVEALED"
            msg = "🐉 [SOVEREIGN MATRIX CIPHER]: 'To awaken Aethelgard: 1 Glitch Core from Abyssal Trench, 1 Chrono-Singularity Bait, and 3 Singularity Pearls in the Pet Altar.' The Void Cipher Key is inscribed in your memory."
            score = 95
            unlock = "void_cipher_key"
        elif "HELP" in q or "HINT" in q or "EASTER EGG" in q:
            verdict = "ORACLE_GUIDANCE"
            hints = [
                "Clue 1: Whispers in Sector 7 speak of an archaic frequency: 'TEMPORAL_HOOK'...",
                "Clue 2: Subspace 0x00 can be accessed using coordinates '404-0x00-VOID' or by baiting the abyss with Chrono matter.",
                "Clue 3: Old net hackers spoke of the memory address '0xDEADBEEF' containing forbidden angler code.",
                "Clue 4: Aethelgard the Glitch Sovereign slumbers. Ask the Oracle about 'GENESIS' to reveal the 4-step ritual.",
            ]
            msg = random.choice(hints)
            score = 75
            unlock = None
        else:
            verdict = "ORACLE_ANALYSIS"
            responses = [
                f"Jev System One analyzed telemetry: Current Sector frequency is stable. High-value marine signatures detected at depths below 500m.",
                f"Jev Oracle reading: Equipping a matching pet multiplies bait resonance by 140%. Consider fishing during synthetic auroras.",
                f"Quantum ping returned: Dimensional boundary ripples near Subspace 0x00. Speak the ancient cipher words to open the fissure.",
            ]
            msg = random.choice(responses)
            score = random.randint(40, 70)
            unlock = None

        latency = (time.time() - start_time) * 1000.0 + random.uniform(2.0, 7.0)

        record = JevDecisionRecord(
            timestamp=time.time(),
            mode=self.mode_name,
            action_type="oracle_query",
            input_state={"query": player_query},
            choices={"verdict": verdict},
            scores={"resonance_score": score},
            latency_ms=round(latency, 2),
            summary=f"Oracle evaluated query '{player_query[:30]}...' -> {verdict}",
        )
        self.history.append(record)

        return {
            "verdict": verdict,
            "message": msg,
            "resonance_score": score,
            "unlock": unlock,
            "mode": self.mode_name,
            "latency_ms": round(latency, 2),
        }

    def evaluate_design_decision(self, topic: str, options: Dict[str, str], criteria: str, state_context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Uses Jev System One to make game design, balance, and feature decisions.
        Evaluates options against criteria and returns the winning decision, rubric scores, and rationale.
        """
        start_time = time.time()
        context = state_context or {}
        
        if self.client and TYPESAFE_AVAILABLE:
            try:
                questions = {
                    "selected_option": Choice(
                        instructions=f"Select the best game design approach for '{topic}' given criteria: {criteria}",
                        criteria=options
                    ),
                    "confidence_score": Score(
                        instructions="Score the suitability of this decision for a chill, addictive fishing RPG inspired by Virtual Fisher.",
                        criteria=["unsuitable", "acceptable", "strong", "optimal"]
                    ),
                    "innovation_noul": Noul(
                        instructions="Is this design choice uniquely engaging or high-impact?"
                    )
                }
                res = self.client.system_one(state={"topic": topic, "criteria": criteria, **context}, questions=questions, timeout=3.0)
                selected = res.choices["selected_option"].choice
                score = res.scores["confidence_score"].score
                noul = float(res.nouls["innovation_noul"].noul)
                latency = (time.time() - start_time) * 1000.0
                return {
                    "topic": topic,
                    "selected_option": selected,
                    "description": options.get(selected, ""),
                    "confidence_score": score,
                    "innovation_rating": round(noul, 2),
                    "mode": self.mode_name,
                    "latency_ms": round(latency, 2)
                }
            except Exception:
                pass
        
        # Local Jev System One Fallback for Design Decisions
        scored_options = {}
        criteria_words = set(w.strip(".,;:!?()[]").lower() for w in criteria.split() if len(w) > 3)
        
        positive_keywords = [
            "chill", "smooth", "satisfying", "virtual fisher", "balanced", "rewarding",
            "cozy", "clean", "warm", "tactile", "dopamine", "intuitive", "compact",
            "non-obtrusive", "toast", "drawer", "responsive", "polish", "delightful"
        ]
        negative_keywords = [
            "tedious", "cramped", "repetitive", "grind", "forced", "clutter",
            "heavy", "terrible", "frustrating", "broken", "unfitting", "blocking",
            "ugly", "arcade-like", "overwhelming", "generic"
        ]
        negation_prefixes = ["not ", "never ", "breaks ", "lacks ", "terrible for ", "ruins "]

        for opt_key, opt_desc in options.items():
            base_score = 70.0
            desc_lower = opt_desc.lower()
            
            # Semantic alignment with explicit criteria
            desc_words = set(w.strip(".,;:!?()[]").lower() for w in opt_desc.split())
            overlap = criteria_words.intersection(desc_words)
            base_score += len(overlap) * 3.5

            # Positive traits (verifying they aren't negated like "not chill" or "breaks chill")
            for pos in positive_keywords:
                if pos in desc_lower:
                    is_negated = any(f"{neg}{pos}" in desc_lower for neg in negation_prefixes)
                    if is_negated:
                        base_score -= 14.0
                    else:
                        base_score += 7.0

            # Negative traits
            for neg in negative_keywords:
                if neg in desc_lower:
                    base_score -= 12.0

            # Contextual bonuses (secret, easter egg, boss, sovereign perks)
            if any(w in desc_lower for w in ["boss", "secret", "easter egg", "milestone", "overpowered", "rimuru"]):
                base_score += 6.0

            # Clamp between 30 and 99
            scored_options[opt_key] = max(30.0, min(99.0, base_score + random.uniform(-1.0, 2.0)))

        best_opt = max(scored_options, key=scored_options.get)
        latency = (time.time() - start_time) * 1000.0 + random.uniform(1.2, 3.5)
        
        return {
            "topic": topic,
            "selected_option": best_opt,
            "description": options.get(best_opt, ""),
            "confidence_score": "optimal" if scored_options[best_opt] > 85 else "strong",
            "score_value": round(scored_options[best_opt], 1),
            "all_scores": {k: round(v, 1) for k, v in scored_options.items()},
            "mode": self.mode_name,
            "latency_ms": round(latency, 2)
        }

