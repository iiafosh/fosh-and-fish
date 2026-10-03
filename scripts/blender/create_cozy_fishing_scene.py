"""
create_cozy_fishing_scene.py
Procedurally generates a complete, stylized low-poly 3D fishing scene in Blender,
inspired by the ForkedPush / Opus 5.5 "I Just Wanted to Fish" Steam demo:
- Straw Hat Kasa Fisherman with Woven Bamboo Creel
- Bamboo Fishing Rod with Floating Red/White Bobber
- Sandy Beach Shoreline & Crystal Turquoise Translucent Ocean
- Smooth Mossy Rocks & Boulders
- Cute Scuttling Red Crab with Stalk Eyes
- Low-Poly Flying Seagull in the Sky
- Swimming Underwater Fish

Exports:
- cozy_fishing_shoreline.blend
- cozy_fishing_shoreline.glb (for Godot 4 / 3D web viewers)
- cozy_fishing_shoreline_render.png (1920x1080 high-res render)
"""

import bpy
import bmesh
import math
import os

# --- Output Paths ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
OUTPUT_DIR = r"C:\Users\user\.gemini\antigravity\brain\6e0b9e30-bb2d-4fba-b300-f31fbe670511"

BLEND_PATH = os.path.join(OUTPUT_DIR, "cozy_fishing_shoreline.blend")
GLB_PATH = os.path.join(OUTPUT_DIR, "cozy_fishing_shoreline.glb")
RENDER_PATH = os.path.join(OUTPUT_DIR, "cozy_fishing_shoreline_render.png")
GODOT_GLB_PATH = os.path.join(PROJECT_ROOT, "assets", "models", "cozy_fishing_shoreline.glb")

os.makedirs(os.path.dirname(GODOT_GLB_PATH), exist_ok=True)

# ==============================================================================
# 1. INITIALIZE BLENDER SCENE
# ==============================================================================
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "CozyFishingScene"

# Setup World & Background
world = bpy.data.worlds.new("CozySkyWorld")
scene.world = world
world.use_nodes = True
bg_node = world.node_tree.nodes.get("Background")
if bg_node:
    bg_node.inputs['Color'].default_value = (0.55, 0.82, 0.95, 1.0) # Bright coastal sky
    bg_node.inputs['Strength'].default_value = 0.9

# ==============================================================================
# 2. MATERIAL CREATOR HELPER
# ==============================================================================
materials = {}

def get_or_create_material(name, base_color, roughness=0.5, metallic=0.0, transmission=0.0, emission=(0,0,0,1)):
    if name in materials:
        return materials[name]
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = base_color
        bsdf.inputs['Roughness'].default_value = roughness
        bsdf.inputs['Metallic'].default_value = metallic
        
        # Transmission for water
        if transmission > 0.0:
            if 'Transmission Weight' in bsdf.inputs:
                bsdf.inputs['Transmission Weight'].default_value = transmission
            elif 'Transmission' in bsdf.inputs:
                bsdf.inputs['Transmission'].default_value = transmission
            bsdf.inputs['IOR'].default_value = 1.333
            mat.blend_method = 'BLEND'
            
        if emission[0] > 0 or emission[1] > 0 or emission[2] > 0:
            if 'Emission Color' in bsdf.inputs:
                bsdf.inputs['Emission Color'].default_value = emission
            elif 'Emission' in bsdf.inputs:
                bsdf.inputs['Emission'].default_value = emission

    materials[name] = mat
    return mat

# Palette Definition
mat_straw = get_or_create_material("M_StrawHat", (0.95, 0.82, 0.38, 1.0), roughness=0.85)
mat_cyan = get_or_create_material("M_CyanRibbon", (0.02, 0.72, 0.88, 1.0), roughness=0.35)
mat_robe = get_or_create_material("M_Robe", (0.85, 0.48, 0.18, 1.0), roughness=0.75)
mat_skin = get_or_create_material("M_Skin", (0.98, 0.80, 0.65, 1.0), roughness=0.6)
mat_creel = get_or_create_material("M_BambooCreel", (0.68, 0.42, 0.16, 1.0), roughness=0.7)
mat_creel_dark = get_or_create_material("M_CreelDark", (0.45, 0.25, 0.08, 1.0), roughness=0.8)
mat_pants = get_or_create_material("M_Pants", (0.22, 0.38, 0.58, 1.0), roughness=0.7)
mat_boots = get_or_create_material("M_Boots", (0.25, 0.32, 0.28, 1.0), roughness=0.6)
mat_bamboo = get_or_create_material("M_BambooRod", (0.88, 0.75, 0.28, 1.0), roughness=0.45)
mat_bobber_red = get_or_create_material("M_BobberRed", (0.95, 0.15, 0.12, 1.0), roughness=0.2)
mat_bobber_white = get_or_create_material("M_BobberWhite", (0.98, 0.98, 0.98, 1.0), roughness=0.2)
mat_crab_red = get_or_create_material("M_CrabRed", (0.92, 0.22, 0.18, 1.0), roughness=0.35)
mat_eye_white = get_or_create_material("M_EyeWhite", (1.0, 1.0, 1.0, 1.0), roughness=0.1)
mat_eye_black = get_or_create_material("M_EyeBlack", (0.05, 0.05, 0.06, 1.0), roughness=0.1)
mat_seagull_white = get_or_create_material("M_SeagullWhite", (0.96, 0.96, 0.96, 1.0), roughness=0.6)
mat_seagull_gray = get_or_create_material("M_SeagullGray", (0.42, 0.46, 0.52, 1.0), roughness=0.6)
mat_seagull_beak = get_or_create_material("M_SeagullBeak", (0.98, 0.82, 0.10, 1.0), roughness=0.35)
mat_rock = get_or_create_material("M_Rock", (0.52, 0.55, 0.58, 1.0), roughness=0.9)
mat_moss = get_or_create_material("M_Moss", (0.28, 0.58, 0.25, 1.0), roughness=0.95)
mat_sand = get_or_create_material("M_Sand", (0.95, 0.88, 0.62, 1.0), roughness=0.95)
mat_water = get_or_create_material("M_Water", (0.08, 0.82, 0.88, 0.85), roughness=0.05, transmission=0.88)
mat_foam = get_or_create_material("M_Foam", (1.0, 1.0, 1.0, 0.9), roughness=0.4)
mat_fish_blue = get_or_create_material("M_FishBlue", (0.28, 0.68, 0.85, 1.0), metallic=0.2, roughness=0.35)

# ==============================================================================
# 3. ENVIRONMENT: SANDY SHORELINE & WATER
# ==============================================================================
# Sandy Beach
bpy.ops.mesh.primitive_grid_add(x_subdivisions=24, y_subdivisions=24, size=18.0, location=(0, 0, -0.2))
sand_obj = bpy.context.active_object
sand_obj.name = "BeachSand"
sand_obj.data.materials.append(mat_sand)

# Shape beach slope down towards the sea (+Y direction)
mesh = sand_obj.data
for v in mesh.vertices:
    # Slope down along Y from +0.5m on dry sand to -0.8m under sea
    slope = -v.co.y * 0.12
    # Subtle dunes
    dune = math.sin(v.co.x * 0.6) * 0.08 + math.cos(v.co.y * 0.5) * 0.06
    v.co.z = slope + dune
mesh.update()

# Ocean Water Plane
bpy.ops.mesh.primitive_plane_add(size=18.0, location=(0, 4.0, 0.0))
water_obj = bpy.context.active_object
water_obj.name = "OceanWater"
water_obj.scale = (1.0, 0.65, 1.0)
water_obj.data.materials.append(mat_water)

# White Shoreline Foam Ribbon
bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0.4, 0.02))
foam_obj = bpy.context.active_object
foam_obj.name = "ShorelineFoam"
foam_obj.scale = (9.0, 0.18, 1.0)
foam_obj.data.materials.append(mat_foam)

# Smooth Coastal Rocks & Boulders
rock_positions = [
    (0.0, 0.0, 0.0, 0.9, 0.75, 0.45),      # Main Seat Rock for Fisherman
    (-1.4, -0.4, 0.05, 0.55, 0.45, 0.35),  # Side boulder left
    (1.6, -0.6, 0.08, 0.65, 0.55, 0.40),   # Side boulder right
    (-2.2, 1.5, -0.15, 0.8, 0.7, 0.5),     # Half-submerged surf rock left
    (2.4, 1.8, -0.20, 0.9, 0.8, 0.55),     # Half-submerged surf rock right
    (0.8, 2.5, -0.30, 0.5, 0.45, 0.35),    # Distant submerged rock
]

for idx, (rx, ry, rz, sx, sy, sz) in enumerate(rock_positions):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(rx, ry, rz))
    rock = bpy.context.active_object
    rock.name = f"CoastalRock_{idx}"
    rock.scale = (sx, sy, sz)
    rock.rotation_euler = (idx * 0.4, idx * 0.7, idx * 1.1)
    rock.data.materials.append(mat_rock)
    
    # Add moss cap to dry rocks
    if ry <= 0.2:
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=sx * 0.7, depth=0.08, location=(rx, ry, rz + sz * 0.95))
        moss_cap = bpy.context.active_object
        moss_cap.name = f"MossCap_{idx}"
        moss_cap.data.materials.append(mat_moss)

# ==============================================================================
# 4. THE FISHERMAN CHARACTER (SEATED ON SHORELINE BOULDER)
# ==============================================================================
# Seat position: sits on CoastalRock_0 at (0, 0, 0.35)
seat_z = 0.35

# 4.1 Lower Body: Sitting Denim/Navy Pants
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.22, depth=0.32, location=(0.0, -0.05, seat_z + 0.16))
pelvis = bpy.context.active_object
pelvis.name = "Fisherman_Pelvis"
pelvis.data.materials.append(mat_pants)

# Legs extending forward towards water (+Y)
for leg_side in [-0.12, 0.12]:
    # Upper leg (thigh)
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.085, depth=0.35, location=(leg_side, 0.12, seat_z + 0.12))
    thigh = bpy.context.active_object
    thigh.name = f"Fisherman_Thigh_{'L' if leg_side < 0 else 'R'}"
    thigh.rotation_euler = (math.radians(75), 0, 0)
    thigh.data.materials.append(mat_pants)
    
    # Lower leg (shin)
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.075, depth=0.32, location=(leg_side, 0.32, seat_z - 0.04))
    shin = bpy.context.active_object
    shin.name = f"Fisherman_Shin_{'L' if leg_side < 0 else 'R'}"
    shin.rotation_euler = (math.radians(15), 0, 0)
    shin.data.materials.append(mat_pants)
    
    # Boots
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(leg_side, 0.36, seat_z - 0.22))
    boot = bpy.context.active_object
    boot.name = f"Fisherman_Boot_{'L' if leg_side < 0 else 'R'}"
    boot.scale = (0.10, 0.20, 0.10)
    boot.data.materials.append(mat_boots)

# 4.2 Torso: Warm Tunic/Robe
bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.25, depth=0.45, location=(0.0, -0.08, seat_z + 0.48))
torso = bpy.context.active_object
torso.name = "Fisherman_Torso"
torso.rotation_euler = (math.radians(-8), 0, 0) # Leaning slightly forward
torso.data.materials.append(mat_robe)

# 4.3 Head & Neck
bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=0.18, location=(0.0, -0.04, seat_z + 0.82))
head = bpy.context.active_object
head.name = "Fisherman_Head"
head.data.materials.append(mat_skin)

# 4.4 Iconic Traditional Conical Straw Kasa Hat
# Wide Cone Brim
bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.72, depth=0.28, location=(0.0, -0.04, seat_z + 0.94))
hat_brim = bpy.context.active_object
hat_brim.name = "Fisherman_KasaHat"
hat_brim.rotation_euler = (math.radians(-5), 0, 0) # Tilts back slightly
hat_brim.data.materials.append(mat_straw)

# Crown Dome Button
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.14, location=(0.0, -0.03, seat_z + 1.08))
hat_crown = bpy.context.active_object
hat_crown.name = "Fisherman_HatCrown"
hat_crown.scale = (1.0, 1.0, 0.5)
hat_crown.data.materials.append(mat_straw)

# Cyan/Turquoise Ribbon Ring around crown
bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.26, depth=0.04, location=(0.0, -0.04, seat_z + 0.97))
ribbon = bpy.context.active_object
ribbon.name = "Fisherman_HatRibbon"
ribbon.rotation_euler = (math.radians(-5), 0, 0)
ribbon.data.materials.append(mat_cyan)

# 4.5 Woven Bamboo Backpack Creel (Basket strapped to back)
# Basket Body
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.22, depth=0.52, location=(0.0, -0.32, seat_z + 0.44))
creel_body = bpy.context.active_object
creel_body.name = "Fisherman_BambooCreel"
creel_body.scale = (0.85, 0.70, 1.0)
creel_body.rotation_euler = (math.radians(-12), 0, 0)
creel_body.data.materials.append(mat_creel)

# Creel Lid & Rim
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.23, depth=0.06, location=(0.0, -0.35, seat_z + 0.71))
creel_lid = bpy.context.active_object
creel_lid.name = "Fisherman_CreelLid"
creel_lid.scale = (0.88, 0.72, 1.0)
creel_lid.rotation_euler = (math.radians(-12), 0, 0)
creel_lid.data.materials.append(mat_creel_dark)

# Creel Straps
for sx in [-0.14, 0.14]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.02, depth=0.45, location=(sx, -0.18, seat_z + 0.50))
    strap = bpy.context.active_object
    strap.name = f"CreelStrap_{'L' if sx < 0 else 'R'}"
    strap.rotation_euler = (math.radians(25), 0, 0)
    strap.data.materials.append(mat_creel_dark)

# 4.6 Arms & Hands (Holding Fishing Rod)
# Right Arm (Main holding hand)
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.065, depth=0.34, location=(0.22, 0.08, seat_z + 0.48))
arm_r = bpy.context.active_object
arm_r.name = "Fisherman_Arm_R"
arm_r.rotation_euler = (math.radians(45), math.radians(-25), 0)
arm_r.data.materials.append(mat_robe)

# Left Arm (Guide hand)
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.065, depth=0.34, location=(-0.16, 0.12, seat_z + 0.46))
arm_l = bpy.context.active_object
arm_l.name = "Fisherman_Arm_L"
arm_l.rotation_euler = (math.radians(40), math.radians(20), 0)
arm_l.data.materials.append(mat_robe)

# 4.7 Bamboo Fishing Rod & Cast Line
# Rod Pole: Starts from hands, extends diagonally out over water towards (+X, +Y, +Z)
rod_start = (0.24, 0.22, seat_z + 0.44)
rod_length = 2.4
rod_angle_elev = math.radians(32)
rod_angle_yaw = math.radians(35)

bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.024, depth=rod_length, location=(0, 0, 0))
rod = bpy.context.active_object
rod.name = "BambooFishingRod"
rod.data.materials.append(mat_bamboo)

# Position & Rotate Rod
rod.rotation_mode = 'XYZ'
rod.rotation_euler = (math.radians(90) - rod_angle_elev, 0, -rod_angle_yaw)
# Place rod base at hands
dir_x = math.sin(rod_angle_yaw) * math.cos(rod_angle_elev)
dir_y = math.cos(rod_angle_yaw) * math.cos(rod_angle_elev)
dir_z = math.sin(rod_angle_elev)

rod.location = (
    rod_start[0] + dir_x * (rod_length * 0.5),
    rod_start[1] + dir_y * (rod_length * 0.5),
    rod_start[2] + dir_z * (rod_length * 0.5)
)

rod_tip = (
    rod_start[0] + dir_x * rod_length,
    rod_start[1] + dir_y * rod_length,
    rod_start[2] + dir_z * rod_length
)

# Floating Bobber in Water
bobber_loc = (rod_tip[0] + 0.8, rod_tip[1] + 1.2, 0.0)

# Fishing Line (Curve / Cylinder from rod tip to bobber)
line_mid = (
    (rod_tip[0] + bobber_loc[0]) * 0.5,
    (rod_tip[1] + bobber_loc[1]) * 0.5,
    max(rod_tip[2], bobber_loc[2]) * 0.35 # Catenary sag
)

curve_data = bpy.data.curves.new('FishingLineCurve', type='CURVE')
curve_data.dimensions = '3D'
polyline = curve_data.splines.new('BEZIER')
polyline.bezier_points.add(2)
polyline.bezier_points[0].co = rod_tip
polyline.bezier_points[0].handle_left = rod_tip
polyline.bezier_points[0].handle_right = (rod_tip[0] + 0.2, rod_tip[1] + 0.3, rod_tip[2] - 0.2)

polyline.bezier_points[1].co = line_mid
polyline.bezier_points[1].handle_left = (line_mid[0] - 0.3, line_mid[1] - 0.3, line_mid[2])
polyline.bezier_points[1].handle_right = (line_mid[0] + 0.3, line_mid[1] + 0.3, line_mid[2])

polyline.bezier_points[2].co = bobber_loc
polyline.bezier_points[2].handle_left = (bobber_loc[0], bobber_loc[1], bobber_loc[2] + 0.3)
polyline.bezier_points[2].handle_right = bobber_loc

curve_data.bevel_depth = 0.003
curve_obj = bpy.data.objects.new('FishingLine', curve_data)
scene.collection.objects.link(curve_obj)

# Two-Tone Red & White Sphere Bobber
# Top Red Hemisphere
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.055, location=(bobber_loc[0], bobber_loc[1], bobber_loc[2] + 0.025))
bobber_top = bpy.context.active_object
bobber_top.name = "Bobber_RedTop"
bobber_top.data.materials.append(mat_bobber_red)

# Bottom White Hemisphere
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.052, location=(bobber_loc[0], bobber_loc[1], bobber_loc[2] - 0.025))
bobber_bot = bpy.context.active_object
bobber_bot.name = "Bobber_WhiteBot"
bobber_bot.data.materials.append(mat_bobber_white)

# Water Ripple Ring around bobber
bpy.ops.mesh.primitive_torus_add(major_radius=0.18, minor_radius=0.012, major_segments=16, minor_segments=6, location=(bobber_loc[0], bobber_loc[1], 0.01))
ripple = bpy.context.active_object
ripple.name = "WaterRipple"
ripple.data.materials.append(mat_foam)

# ==============================================================================
# 5. CUTE SCUTTLING RED CRAB (BEACH SHORELINE)
# ==============================================================================
crab_pos = (1.5, 0.3, 0.04)

# Shell / Carapace
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.10, location=crab_pos)
crab_body = bpy.context.active_object
crab_body.name = "Crab_Body"
crab_body.scale = (1.2, 0.9, 0.55)
crab_body.data.materials.append(mat_crab_red)

# Stalk Eyes
for eye_x in [-0.045, 0.045]:
    # Stalk
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.012, depth=0.06, location=(crab_pos[0] + eye_x, crab_pos[1] + 0.08, crab_pos[2] + 0.05))
    stalk = bpy.context.active_object
    stalk.data.materials.append(mat_crab_red)
    
    # White Eye Eyeball
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=0.024, location=(crab_pos[0] + eye_x, crab_pos[1] + 0.09, crab_pos[2] + 0.08))
    eyeball = bpy.context.active_object
    eyeball.data.materials.append(mat_eye_white)
    
    # Black Pupil
    bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=4, radius=0.010, location=(crab_pos[0] + eye_x, crab_pos[1] + 0.11, crab_pos[2] + 0.08))
    pupil = bpy.context.active_object
    pupil.data.materials.append(mat_eye_black)

# Pincers
for px in [-0.14, 0.14]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=0.05, location=(crab_pos[0] + px, crab_pos[1] + 0.10, crab_pos[2] + 0.04))
    claw = bpy.context.active_object
    claw.name = f"Crab_Claw_{'L' if px < 0 else 'R'}"
    claw.scale = (0.6, 1.2, 0.6)
    claw.data.materials.append(mat_crab_red)

# ==============================================================================
# 6. LOW-POLY FLYING SEAGULL (COASTAL SKY)
# ==============================================================================
gull_pos = (1.4, 2.8, 2.6)

# Body Torso
bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, radius=0.14, location=gull_pos)
gull_body = bpy.context.active_object
gull_body.name = "Seagull_Body"
gull_body.scale = (0.7, 1.4, 0.65)
gull_body.rotation_euler = (math.radians(-15), 0, math.radians(-25))
gull_body.data.materials.append(mat_seagull_white)

# Head
bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=0.075, location=(gull_pos[0] - 0.06, gull_pos[1] + 0.18, gull_pos[2] + 0.05))
gull_head = bpy.context.active_object
gull_head.name = "Seagull_Head"
gull_head.data.materials.append(mat_seagull_white)

# Yellow Beak
bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.03, depth=0.10, location=(gull_pos[0] - 0.08, gull_pos[1] + 0.28, gull_pos[2] + 0.03))
gull_beak = bpy.context.active_object
gull_beak.name = "Seagull_Beak"
gull_beak.rotation_euler = (math.radians(90), 0, math.radians(-25))
gull_beak.data.materials.append(mat_seagull_beak)

# Wings (Left & Right Soaring)
for wx in [-1, 1]:
    # Inner Wing (White)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(gull_pos[0] + wx * 0.45, gull_pos[1], gull_pos[2] + 0.04))
    inner_wing = bpy.context.active_object
    inner_wing.name = f"Seagull_WingInner_{'R' if wx > 0 else 'L'}"
    inner_wing.scale = (0.40, 0.18, 0.02)
    inner_wing.rotation_euler = (0, math.radians(wx * 10), math.radians(-25))
    inner_wing.data.materials.append(mat_seagull_white)
    
    # Outer Wingtip (Dark Gray)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(gull_pos[0] + wx * 0.85, gull_pos[1] - 0.05, gull_pos[2] + 0.12))
    outer_wing = bpy.context.active_object
    outer_wing.name = f"Seagull_WingTip_{'R' if wx > 0 else 'L'}"
    outer_wing.scale = (0.42, 0.14, 0.018)
    outer_wing.rotation_euler = (0, math.radians(wx * 22), math.radians(-25))
    outer_wing.data.materials.append(mat_seagull_gray)

# ==============================================================================
# 7. UNDERWATER FISH SWIMMING
# ==============================================================================
fish_positions = [
    (bobber_loc[0] - 0.6, bobber_loc[1] + 0.4, -0.35, math.radians(65)),
    (bobber_loc[0] + 0.7, bobber_loc[1] - 0.3, -0.42, math.radians(-120)),
    (bobber_loc[0] + 0.2, bobber_loc[1] + 1.1, -0.50, math.radians(10)),
]

for f_idx, (fx, fy, fz, f_rot) in enumerate(fish_positions):
    # Torpedo Body
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=0.12, location=(fx, fy, fz))
    fish = bpy.context.active_object
    fish.name = f"UnderwaterFish_{f_idx}"
    fish.scale = (0.35, 1.0, 0.5)
    fish.rotation_euler = (0, 0, f_rot)
    fish.data.materials.append(mat_fish_blue)
    
    # Tail Fin
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.07, depth=0.12, location=(fx, fy - 0.14, fz))
    fish_tail = bpy.context.active_object
    fish_tail.name = f"FishTail_{f_idx}"
    fish_tail.scale = (0.2, 1.0, 1.0)
    fish_tail.rotation_euler = (math.radians(-90), 0, f_rot)
    fish_tail.data.materials.append(mat_fish_blue)

# ==============================================================================
# 8. LIGHTING SETUP (WARM GOLDEN HOUR SUN & BLUE SKY FILL)
# ==============================================================================
# Key Sun Light
sun_data = bpy.data.lights.new(name="Sun_KeyLight", type='SUN')
sun_data.color = (1.0, 0.95, 0.82)
sun_data.energy = 4.2
sun_obj = bpy.data.objects.new(name="Sun_KeyLight", object_data=sun_data)
sun_obj.rotation_euler = (math.radians(48), math.radians(22), math.radians(-42))
scene.collection.objects.link(sun_obj)

# Ocean Cyan Bounce Light
bounce_data = bpy.data.lights.new(name="Ocean_BounceLight", type='SUN')
bounce_data.color = (0.15, 0.75, 0.95)
bounce_data.energy = 1.4
bounce_obj = bpy.data.objects.new(name="Ocean_BounceLight", object_data=bounce_data)
bounce_obj.rotation_euler = (math.radians(-65), 0, math.radians(110))
scene.collection.objects.link(bounce_obj)

# Soft Rim/Fill Light
fill_data = bpy.data.lights.new(name="Character_FillLight", type='POINT')
fill_data.color = (1.0, 0.88, 0.75)
fill_data.energy = 60.0
fill_obj = bpy.data.objects.new(name="Character_FillLight", object_data=fill_data)
fill_obj.location = (-1.5, 0.5, 1.8)
scene.collection.objects.link(fill_obj)

# ==============================================================================
# 9. CAMERA SETUP (MATCHING STEAM CAPSULE ELEVATED THREE-QUARTERS VIEW)
# ==============================================================================
cam_data = bpy.data.cameras.new("MainCamera")
cam_data.lens = 42.0 # 42mm focal length for crisp low-poly perspective
cam_obj = bpy.data.objects.new("MainCamera", cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj

# Camera coordinates looking down onto the fisherman and ocean
cam_obj.location = (-2.8, -3.2, 2.9)
cam_obj.rotation_euler = (math.radians(62), 0, math.radians(-42))

# ==============================================================================
# 10. RENDER SETTINGS & EXPORTS
# ==============================================================================
scene.render.resolution_x = 1920
scene.render.resolution_y = 1080
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = RENDER_PATH

# Render Engine setup (Eevee or Cycles)
if hasattr(scene.render, "engine"):
    # Blender 4.2+ / 5.x uses BLENDER_EEVEE_NEXT or CYCLES
    available_engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    if "BLENDER_EEVEE_NEXT" in available_engines:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    elif "BLENDER_EEVEE" in available_engines:
        scene.render.engine = "BLENDER_EEVEE"
    else:
        scene.render.engine = "CYCLES"

print(f"[Blender] Saving .blend to {BLEND_PATH}...")
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

print(f"[Blender] Exporting .glb to {GLB_PATH}...")
bpy.ops.export_scene.gltf(filepath=GLB_PATH, export_format='GLB', export_materials='EXPORT')

print(f"[Blender] Exporting .glb to Godot assets {GODOT_GLB_PATH}...")
bpy.ops.export_scene.gltf(filepath=GODOT_GLB_PATH, export_format='GLB', export_materials='EXPORT')

print(f"[Blender] Rendering high-res still image to {RENDER_PATH}...")
bpy.ops.render.render(write_still=True)

print("✨ ALL 3D BLENDER ASSETS & RENDERS COMPLETED SUCCESSFULLY!")
