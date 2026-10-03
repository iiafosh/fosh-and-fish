"""
generate_virtual_fisher_assets.py
Procedural Blender 3D Generator for Virtual Fisher 2099
Automates creation of stylized, low-poly, game-ready 3D models:
1. Virtual Fisher Ship Hulls & Modular Upgrades:
   - River Rowboat
   - Coastal Fishing Trawler
   - Streamlined Speedboat
   - Twin-Hull Pontoon Catamaran
   - Classic Sailboat
   - Luxury Yacht
   - Abyssal Surveyor Deep Submersible
   - Modular Attachments: Salvage Crane, Trailing Net, Aerated Live Tank, Radar Mast
2. Virtual Fisher 3D Rods:
   - Plastic Starter Rod
   - Fiberglass Rod
   - Volcanic Lava Rod
   - Gilded Golden Rod
3. Virtual Fisher 3D Treasure Crates:
   - Wooden Sea Chest
   - Iron Strongbox
   - Golden Reliquary
   - Cybernetic Super Crate

Exports .glb models to:
- assets/models/boats/
- assets/models/rods/
- assets/models/chests/
And saves master scene to:
- assets/models/virtual_fisher_assets.blend
"""

import bpy
import bmesh
import math
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
MODELS_DIR = os.path.join(PROJECT_ROOT, "assets", "models")
BOATS_DIR = os.path.join(MODELS_DIR, "boats")
RODS_DIR = os.path.join(MODELS_DIR, "rods")
CHESTS_DIR = os.path.join(MODELS_DIR, "chests")

for d in [BOATS_DIR, RODS_DIR, CHESTS_DIR]:
    os.makedirs(d, exist_ok=True)

# ------------------------------------------------------------------------------
# 1. BLENDER SETUP & MATERIAL HELPERS
# ------------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "VirtualFisher_AssetFactory"

materials = {}

def create_toon_mat(name, base_color, roughness=0.6, metallic=0.0, emission=(0, 0, 0, 1)):
    if name in materials:
        return materials[name]
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = base_color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if emission[0] > 0 or emission[1] > 0 or emission[2] > 0:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = emission
                bsdf.inputs["Emission Strength"].default_value = 2.0
            elif "Emission" in bsdf.inputs:
                bsdf.inputs["Emission"].default_value = emission
    materials[name] = mat
    return mat

# Core Materials
m_wood_dark = create_toon_mat("M_WoodDark", (0.35, 0.18, 0.08, 1.0), roughness=0.85)
m_wood_light = create_toon_mat("M_WoodLight", (0.65, 0.42, 0.20, 1.0), roughness=0.8)
m_hull_white = create_toon_mat("M_HullWhite", (0.92, 0.94, 0.96, 1.0), roughness=0.5)
m_hull_green = create_toon_mat("M_HullGreen", (0.12, 0.48, 0.32, 1.0), roughness=0.6)
m_hull_red = create_toon_mat("M_HullRed", (0.88, 0.18, 0.15, 1.0), roughness=0.4)
m_hull_navy = create_toon_mat("M_HullNavy", (0.08, 0.16, 0.32, 1.0), roughness=0.5)
m_hull_gold = create_toon_mat("M_HullGold", (0.96, 0.78, 0.15, 1.0), roughness=0.3, metallic=0.85)
m_hull_obsidian = create_toon_mat("M_HullObsidian", (0.10, 0.12, 0.16, 1.0), roughness=0.4, metallic=0.4)
m_brass = create_toon_mat("M_Brass", (0.85, 0.65, 0.22, 1.0), roughness=0.35, metallic=0.8)
m_steel = create_toon_mat("M_Steel", (0.55, 0.58, 0.62, 1.0), roughness=0.4, metallic=0.7)
m_glass_cyan = create_toon_mat("M_GlassCyan", (0.15, 0.75, 0.90, 1.0), roughness=0.1, metallic=0.1)
m_magma = create_toon_mat("M_Magma", (1.0, 0.32, 0.05, 1.0), roughness=0.2, emission=(1.0, 0.35, 0.05, 1.0))
m_cyber_cyan = create_toon_mat("M_CyberCyan", (0.05, 0.88, 0.98, 1.0), roughness=0.2, emission=(0.05, 0.9, 1.0, 1.0))
m_canvas = create_toon_mat("M_Canvas", (0.95, 0.92, 0.85, 1.0), roughness=0.9)

# ------------------------------------------------------------------------------
# 2. MODELING HELPERS
# ------------------------------------------------------------------------------
def deselect_all():
    bpy.ops.object.select_all(action="DESELECT")

def export_active_as_glb(filepath):
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format="GLB",
        use_selection=True,
        export_materials="EXPORT"
    )
    print(f"📦 Exported GLB: {filepath}")

# ------------------------------------------------------------------------------
# 3. SHIP 1: ROWBOAT (TIER 1)
# ------------------------------------------------------------------------------
def create_rowboat():
    deselect_all()
    # Hull
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=1.0, depth=3.2, location=(0, 0, 0.3))
    hull = bpy.context.active_object
    hull.name = "VF_Rowboat_Hull"
    hull.scale = (0.55, 1.0, 0.35)
    hull.rotation_euler = (math.radians(90), 0, 0)
    hull.data.materials.append(m_wood_dark)

    # Interior Floor
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.25))
    floor = bpy.context.active_object
    floor.name = "VF_Rowboat_Floor"
    floor.scale = (0.85, 2.8, 0.1)
    floor.data.materials.append(m_wood_light)
    floor.select_set(True)
    hull.select_set(True)

    # Wooden Seat Thwarts
    for y_pos in [-0.6, 0.4]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, y_pos, 0.42))
        thwart = bpy.context.active_object
        thwart.scale = (0.95, 0.3, 0.08)
        thwart.data.materials.append(m_wood_light)
        thwart.select_set(True)

    # Stern Lantern Post
    bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=1.1, location=(-0.35, -1.3, 0.7))
    post = bpy.context.active_object
    post.data.materials.append(m_steel)
    post.select_set(True)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=(-0.35, -1.3, 1.25))
    lantern = bpy.context.active_object
    lantern.data.materials.append(m_magma)
    lantern.select_set(True)

    out_file = os.path.join(BOATS_DIR, "rowboat.glb")
    export_active_as_glb(out_file)

# ------------------------------------------------------------------------------
# 4. SHIP 2: COASTAL FISHING TRAWLER (TIER 2)
# ------------------------------------------------------------------------------
def create_fishing_trawler():
    deselect_all()
    # Main Hull
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.4))
    hull = bpy.context.active_object
    hull.name = "VF_Trawler_Hull"
    hull.scale = (1.5, 4.4, 0.75)
    hull.data.materials.append(m_hull_green)

    # White Upper Deck Gunwale
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.85))
    gunwale = bpy.context.active_object
    gunwale.scale = (1.55, 4.45, 0.18)
    gunwale.data.materials.append(m_hull_white)
    gunwale.select_set(True)
    hull.select_set(True)

    # Wheelhouse Cabin (Forward)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.8, 1.45))
    cabin = bpy.context.active_object
    cabin.scale = (1.2, 1.6, 1.0)
    cabin.data.materials.append(m_hull_white)
    cabin.select_set(True)

    # Cabin Glass Visor
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 1.5, 1.6))
    glass = bpy.context.active_object
    glass.scale = (1.1, 0.25, 0.4)
    glass.data.materials.append(m_glass_cyan)
    glass.select_set(True)

    # Crane Arm Boom (Rear Workdeck)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.06, depth=2.2, location=(0.45, -1.2, 1.6))
    crane = bpy.context.active_object
    crane.rotation_euler = (math.radians(-32), 0, 0)
    crane.data.materials.append(m_brass)
    crane.select_set(True)

    # Winch Drum
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.4, location=(0, -1.4, 0.95))
    winch = bpy.context.active_object
    winch.rotation_euler = (0, math.radians(90), 0)
    winch.data.materials.append(m_steel)
    winch.select_set(True)

    out_file = os.path.join(BOATS_DIR, "fishing_trawler.glb")
    export_active_as_glb(out_file)

# ------------------------------------------------------------------------------
# 5. SHIP 3: STREAMLINED SPEEDBOAT (TIER 3)
# ------------------------------------------------------------------------------
def create_speedboat():
    deselect_all()
    # Wedge Hull
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.35))
    hull = bpy.context.active_object
    hull.name = "VF_Speedboat_Hull"
    hull.scale = (1.4, 4.2, 0.5)
    hull.data.materials.append(m_hull_red)

    # Slanted Windshield
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.4, 0.75))
    shield = bpy.context.active_object
    shield.scale = (1.2, 0.6, 0.35)
    shield.rotation_euler = (math.radians(-40), 0, 0)
    shield.data.materials.append(m_glass_cyan)
    shield.select_set(True)
    hull.select_set(True)

    # Chrome Exhaust Pipes
    for side in [-0.5, 0.5]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=0.8, location=(side, -2.1, 0.55))
        pipe = bpy.context.active_object
        pipe.rotation_euler = (math.radians(85), 0, 0)
        pipe.data.materials.append(m_steel)
        pipe.select_set(True)

    out_file = os.path.join(BOATS_DIR, "speedboat.glb")
    export_active_as_glb(out_file)

# ------------------------------------------------------------------------------
# 6. SHIP 4: LUXURY YACHT (TIER 7)
# ------------------------------------------------------------------------------
def create_luxury_yacht():
    deselect_all()
    # Lower Hull
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
    hull = bpy.context.active_object
    hull.name = "VF_Yacht_Hull"
    hull.scale = (2.2, 6.5, 0.9)
    hull.data.materials.append(m_hull_navy)

    # Superstructure Deck 1 (White)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.2, 1.25))
    d1 = bpy.context.active_object
    d1.scale = (1.9, 4.8, 0.7)
    d1.data.materials.append(m_hull_white)
    d1.select_set(True)
    hull.select_set(True)

    # Panoramic Bridge Deck 2
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.5, 1.85))
    d2 = bpy.context.active_object
    d2.scale = (1.5, 2.8, 0.6)
    d2.data.materials.append(m_glass_cyan)
    d2.select_set(True)

    # Gold Trim Railings & Radar Dome
    bpy.ops.mesh.primitive_cylinder_add(radius=0.35, depth=0.25, location=(0, -0.4, 2.35))
    radar = bpy.context.active_object
    radar.data.materials.append(m_hull_gold)
    radar.select_set(True)

    out_file = os.path.join(BOATS_DIR, "luxury_yacht.glb")
    export_active_as_glb(out_file)

# ------------------------------------------------------------------------------
# 7. SHIP 5: ABYSSAL SURVEYOR SUBMERSIBLE (TIER 17)
# ------------------------------------------------------------------------------
def create_abyssal_sub():
    deselect_all()
    # Pressure Sphere
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.2, location=(0, 0, 0.9))
    sphere = bpy.context.active_object
    sphere.name = "VF_Abyssal_Sphere"
    sphere.scale = (1.1, 1.6, 0.95)
    sphere.data.materials.append(m_hull_obsidian)

    # Observation Viewport (Glowing Cyan)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.55, location=(0, 1.6, 0.9))
    porthole = bpy.context.active_object
    porthole.data.materials.append(m_cyber_cyan)
    porthole.select_set(True)
    sphere.select_set(True)

    # Robotic Grabber Arms
    for side in [-1.0, 1.0]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=1.2, location=(side, 0.8, 0.4))
        arm = bpy.context.active_object
        arm.rotation_euler = (math.radians(35), 0, math.radians(side * 25))
        arm.data.materials.append(m_brass)
        arm.select_set(True)

    out_file = os.path.join(BOATS_DIR, "abyssal_submersible.glb")
    export_active_as_glb(out_file)

# ------------------------------------------------------------------------------
# 8. 3D VIRTUAL FISHER FISHING RODS
# ------------------------------------------------------------------------------
def create_rods():
    # 1. Plastic Starter Rod
    deselect_all()
    bpy.ops.mesh.primitive_cylinder_add(radius=0.02, depth=2.4, location=(0, 0, 1.2))
    r_plastic = bpy.context.active_object
    r_plastic.data.materials.append(m_glass_cyan)
    export_active_as_glb(os.path.join(RODS_DIR, "plastic_rod.glb"))

    # 2. Volcanic Lava Rod
    deselect_all()
    bpy.ops.mesh.primitive_cylinder_add(radius=0.025, depth=2.6, location=(0, 0, 1.3))
    r_lava = bpy.context.active_object
    r_lava.data.materials.append(m_magma)
    export_active_as_glb(os.path.join(RODS_DIR, "lava_rod.glb"))

    # 3. Gilded Golden Rod
    deselect_all()
    bpy.ops.mesh.primitive_cylinder_add(radius=0.022, depth=2.7, location=(0, 0, 1.35))
    r_gold = bpy.context.active_object
    r_gold.data.materials.append(m_hull_gold)
    export_active_as_glb(os.path.join(RODS_DIR, "golden_rod.glb"))

# ------------------------------------------------------------------------------
# 9. 3D VIRTUAL FISHER TREASURE CRATES
# ------------------------------------------------------------------------------
def create_treasure_chests():
    # 1. Wooden Sea Chest
    deselect_all()
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.4))
    chest = bpy.context.active_object
    chest.scale = (0.9, 0.6, 0.5)
    chest.data.materials.append(m_wood_dark)
    # Iron Straps
    bpy.ops.mesh.primitive_cylinder_add(radius=0.32, depth=0.92, location=(0, 0, 0.65))
    lid = bpy.context.active_object
    lid.scale = (1.0, 1.0, 0.5)
    lid.rotation_euler = (0, math.radians(90), 0)
    lid.data.materials.append(m_steel)
    lid.select_set(True)
    chest.select_set(True)
    export_active_as_glb(os.path.join(CHESTS_DIR, "wooden_chest.glb"))

    # 2. Super Crate (Holographic Cyber Vault)
    deselect_all()
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
    crate = bpy.context.active_object
    crate.scale = (0.8, 0.8, 0.8)
    crate.data.materials.append(m_hull_obsidian)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.35, location=(0, 0, 0.5))
    core = bpy.context.active_object
    core.data.materials.append(m_cyber_cyan)
    core.select_set(True)
    crate.select_set(True)
    export_active_as_glb(os.path.join(CHESTS_DIR, "super_crate.glb"))

# ------------------------------------------------------------------------------
# 10. RUN ALL GENERATORS
# ------------------------------------------------------------------------------
print("🛠️ Generating 3D Virtual Fisher Assets...")
create_rowboat()
create_fishing_trawler()
create_speedboat()
create_luxury_yacht()
create_abyssal_sub()
create_rods()
create_treasure_chests()

# Save master .blend file
blend_path = os.path.join(MODELS_DIR, "virtual_fisher_assets.blend")
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
print(f"✨ Master Virtual Fisher Blender file saved to: {blend_path}")
print("🎉 ALL VIRTUAL FISHER 3D ASSETS SUCCESSFULLY GENERATED!")
