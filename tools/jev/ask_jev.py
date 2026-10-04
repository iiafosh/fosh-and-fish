#!/usr/bin/env python3
"""
ask_jev.py - Command Line Interface & Evaluator for Jev System One
Directly queries Jev Decision Engine for game design, UI evaluation, and architectural guidance.
"""

import sys
import io
import os
import argparse
import json

# Ensure UTF-8 output encoding on Windows
if sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ai.jev_engine import JevDecisionEngine

def ask_jev(topic: str, options: dict, criteria: str = ""):
    engine = JevDecisionEngine()
    print(f"\n============================================================")
    print(f"⚓ CONSULTING JEV SYSTEM ONE")
    print(f"Topic: {topic}")
    print(f"Mode: {engine.mode_name}")
    print(f"============================================================")
    
    result = engine.evaluate_design_decision(
        topic=topic,
        options=options,
        criteria=criteria
    )
    
    print(f"\n👑 JEV VERDICT: {result['selected_option']}")
    print(f"Confidence: {result.get('confidence_score', 'N/A')}")
    print(f"Reasoning / Directive: {result['description']}")
    print(f"All Option Scores: {result.get('all_scores', {})}")
    print(f"============================================================\n")
    return result

def run_current_audit():
    print("Running Jev System One Audit on Opus's progress & remaining polish...")
    
    # Evaluate Question 1: Deck signs & railing
    ask_jev(
        topic="On-Deck Station Plaques vs Clean Maritime Deck",
        options={
            "keep_plaques": "Keep the 5 floating signboards (Pier, Market, Helm, Tackle, Sanctuary) and bright orange railing",
            "remove_plaques_subtle_railing": "Remove the floating billboard signs completely since bottom dock + hotkeys already handle them. Use a subtle warm timber/brass guard railing at deck_y - 12 to let the pixel fisherman shine"
        },
        criteria="Uncluttered pixel art aesthetic. Let the fisherman sprite and ship silhouette breathe."
    )
    
    # Evaluate Question 2: Discord Embed Left Border Styling
    ask_jev(
        topic="Modal Border Styling",
        options={
            "four_sided_neon": "4-sided bright green border around the whole panel",
            "discord_left_accent": "Authentic Discord embed with 5px vertical left accent bar (#22c55e emerald or #5865F2 blurple) and subtle dark background (#1e1f22)"
        },
        criteria="Must match the user's uploaded Discord screenshots (media_1791005708377.png)."
    )

    # Evaluate Question 3: Shop Hub Layout
    ask_jev(
        topic="Shop Hub Layout Organization",
        options={
            "loose_spaced": "Loose wide buttons with large vertical gap",
            "compact_discord_matrix": "Compact 2-column directory card with authentic 4x2 Discord icon matrix ([🎣][🪱][⬆️][⛵] / [🔥][🐟][🪝][↩])"
        },
        criteria="High density, clear hierarchy, exact match to Discord bot UI screenshot (media_1791005728277.png)."
    )

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] != "--audit":
        parser = argparse.ArgumentParser(description="Query Jev System One")
        parser.add_argument("topic", type=str, help="Decision topic")
        parser.add_argument("--options", type=str, required=True, help="JSON dictionary of options")
        parser.add_argument("--criteria", type=str, default="", help="Evaluation criteria")
        args = parser.parse_args()
        
        opts = json.loads(args.options)
        ask_jev(args.topic, opts, args.criteria)
    else:
        run_current_audit()
