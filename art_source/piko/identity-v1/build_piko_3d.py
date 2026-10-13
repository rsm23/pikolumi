"""Author Piko's model and animation in Blender; render transparent RGBA frames.

Run with Blender --background --python scripts/build_piko_3d.py -- --preview
or omit --preview to render both clips. No downloaded meshes or textures.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'tmp/piko-frames'
SOURCE = ROOT / 'art_source/piko'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def material(name, color, roughness=.42):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    return m


teal = material('Turquoise feathers', (.018, .60, .64))
light_teal = material('Wing feathers', (.04, .69, .69))
purple = material('Lilac crest', (.48, .22, .74))
yellow = material('Buttercup belly', (1, .75, .18))
orange = material('Golden beak and feet', (1, .40, .035))
coral = material('Coral flight feathers', (1, .20, .17))
white = material('Warm eye white', (1, .97, .88), .25)
brown = material('Chocolate iris', (.14, .045, .018), .25)
black = material('Pupil', (.012, .008, .012), .18)
mouth = material('Smiling mouth', (.18, .015, .022))
pink = material('Tongue', (1, .27, .35))
cheek = material('Peach cheeks', (1, .39, .32))
stripe = material('Crayon wrapper stripes', (.45, .045, .05))


def pivot(name, location, parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.location = location
    o.parent = parent
    return o


def oval(name, location, scale, mat, parent=None, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20)
    o = bpy.context.object
    o.name = name
    o.parent = parent
    o.location, o.scale, o.rotation_euler = location, scale, rotation
    o.data.materials.append(mat)
    for face in o.data.polygons:
        face.use_smooth = True
    return o


rig = pivot('Piko • body motion', (0, 0, 0))
body = oval('Soft pear shaped body', (0, 0, 1.02), (.70, .58, .88), teal, rig)
oval('Yellow belly', (0, -.515, .99), (.47, .14, .61), yellow, rig)
head = pivot('Head • overlapping follow through', (0, -.01, 2.03), rig)
oval('Round head', (0, 0, 0), (.91, .73, .86), teal, head)
crest = pivot('Crest • secondary motion', (0, .08, .73), head)
for i, (x, lean, height) in enumerate([(-.22, -.40, .43), (0, -.20, .60), (.20, .20, .40)]):
    oval(f'Lilac crest feather {i}', (x, .035, height*.55), (.145, .14, height), purple, crest, (0, lean, 0))

eyes = []
for side in (-1, 1):
    eye = pivot(f'Eye {side} • blink', (side*.35, -.66, .14), head)
    oval('Eye white', (0, -.05, 0), (.275, .12, .335), white, eye)
    oval('Brown iris', (.018, -.155, -.015), (.175, .048, .247), brown, eye)
    oval('Black pupil', (.022, -.196, -.009), (.113, .027, .181), black, eye)
    oval('Eye sparkle', (-.043, -.218, .09), (.048, .018, .054), white, eye)
    oval('Small eye sparkle', (.060, -.218, -.083), (.019, .013, .021), white, eye)
    eyes.append(eye)
    oval('Peach blush', (side*.61, -.565, -.21), (.135, .035, .075), cheek, head)
    curve = bpy.data.curves.new('Friendly arched brow', 'CURVE')
    curve.dimensions, curve.bevel_depth, curve.bevel_resolution = '3D', .026, 4
    spline = curve.splines.new('BEZIER')
    spline.bezier_points.add(2)
    for p, co in zip(spline.bezier_points, [(-.15, 0, 0), (0, -.025, .055), (.15, 0, 0)]):
        p.co, p.handle_left_type, p.handle_right_type = co, 'AUTO', 'AUTO'
    brow = bpy.data.objects.new('Friendly arched brow', curve)
    bpy.context.collection.objects.link(brow)
    brow.parent, brow.location = head, (side*.35, -.58, .50)
    curve.materials.append(brown)

smile = pivot('Smile • opens in celebration', (0, -.735, -.20), head)
oval('Mouth opening', (0, -.075, -.036), (.235, .058, .16), mouth, smile)
oval('Tongue', (0, -.13, -.115), (.132, .018, .065), pink, smile)
oval('Lower smiling beak', (0, -.068, -.19), (.255, .11, .062), orange, smile)
oval('Upper rounded beak', (0, -.79, -.115), (.29, .23, .115), orange, head)
for side in (-1, 1):
    oval('Nostril', (side*.095, -.990, -.091), (.022, .011, .014), brown, head)

wings = []
for side in (-1, 1):
    wing = pivot(f'Wing {side} • shoulder', (side*.60, -.015, 1.47), rig)
    oval('Rounded wing', (side*.25, -.08, -.19), (.30, .20, .52), light_teal, wing, (0, -side*.52, 0))
    for i in range(3):
        oval(f'Coral feather {side} {i}', (side*(.37+i*.11), -.09, -.42+i*.06), (.13, .13, .28), coral, wing, (0, -side*(.5+i*.12), 0))
    wings.append(wing)

crayon = pivot('Red crayon', (.55, -.21, -.04), wings[1])
crayon.rotation_euler[1] = .18
bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=.105, depth=.76)
o = bpy.context.object
o.name = 'Coral crayon wrapper'
o.parent, o.location = crayon, (0, 0, .15)
o.data.materials.append(coral)
bevel = o.modifiers.new('Soft edges', 'BEVEL')
bevel.width, bevel.segments = .025, 3
for face in o.data.polygons:
    face.use_smooth = True
for z in (-.12, .42):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=.107, depth=.053)
    o = bpy.context.object
    o.name, o.parent, o.location = 'Wrapper stripe', crayon, (0, 0, z)
    o.data.materials.append(stripe)
bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=.104, radius2=.018, depth=.22)
o = bpy.context.object
o.name, o.parent, o.location = 'Rounded crayon tip', crayon, (0, 0, .64)
o.data.materials.append(coral)
for face in o.data.polygons:
    face.use_smooth = True
oval('Wing holding crayon', (.55, -.29, -.11), (.16, .10, .17), light_teal, wings[1])

feet = []
for side in (-1, 1):
    foot = pivot(f'Foot {side}', (side*.30, -.05, .13), rig)
    oval('Orange foot', (0, -.055, 0), (.20, .22, .10), orange, foot)
    for i in (-1, 0, 1):
        oval('Rounded toe', (i*.10, -.20, -.01), (.071, .17, .068), orange, foot, (0, 0, -i*.25))
    feet.append(foot)
for i in (-1, 0, 1):
    oval('Tail feather', (i*.14, .50, .70), (.16, .36, .25), teal, rig, (.5, 0, i*.2))


def light(name, position, power, size, color):
    bpy.ops.object.light_add(type='AREA', location=position)
    o = bpy.context.object
    o.name = name
    o.data.energy, o.data.shape, o.data.size, o.data.color = power, 'DISK', size, color
    o.rotation_euler = (Vector((0, 0, 1.6))-o.location).to_track_quat('-Z', 'Y').to_euler()


light('Warm soft key', (-3, -4, 6), 450, 5, (1, .88, .73))
light('Cool soft fill', (4, -2, 3), 280, 4, (.74, .90, 1))
light('Crest rim light', (1, 3, 5), 500, 3, (1, .85, 1))
bpy.ops.object.camera_add(location=(2.4, -10, 3.8))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 1.87))-camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type, camera.data.ortho_scale = 'ORTHO', 4.65
scene = bpy.context.scene
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.fps = 30
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.70, .80, 1, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .35
scene.view_settings.view_transform = 'Standard'
scene.view_settings.exposure = -.5


def bump(t, start, end):
    if t <= start or t >= end:
        return 0
    return math.sin(math.pi*(t-start)/(end-start))**2


def pose(t, celebrate=False):
    # Offset gestures and soft pulses create anticipation, follow-through and rests.
    breathe = math.sin(2*math.pi*t/3)
    rig.location.z = .010*breathe
    rig.scale = (1-.007*breathe, 1-.007*breathe, 1+.010*breathe)
    rig.rotation_euler = (0, .028*math.sin(2*math.pi*t/3), 0)
    head.rotation_euler = (.012*breathe, .04*math.sin(2*math.pi*(t-.16)/3), .035*math.sin(2*math.pi*t/3))
    crest.rotation_euler = (0, .06*math.sin(2*math.pi*(t-.26)/3), 0)
    wings[0].rotation_euler = (0, .045*breathe, 0)
    wings[1].rotation_euler = (0, -.04*breathe, 0)
    smile.scale.z = 1+.10*bump(t, .6, 1.6)
    blink = max(bump(t, .70, .87), bump(t, 2.15, 2.32))
    for eye in eyes:
        eye.scale.z = max(.06, 1-blink)
    for foot in feet:
        foot.rotation_euler = (0, 0, 0)
    if celebrate:
        anticipation = bump(t, .10, .45)
        jump = bump(t, .40, 1.15)
        landing = bump(t, 1.05, 1.38)
        cheer = bump(t, .28, 2.40)
        rig.location.z += .26*jump-.06*anticipation-.045*landing
        rig.scale.z *= 1-.075*anticipation+.05*jump-.04*landing
        rig.scale.x *= 1+.035*anticipation-.025*jump+.022*landing
        rig.rotation_euler.y += -.07*cheer
        head.rotation_euler.y += .08*bump(t, .60, 1.70)
        head.rotation_euler.x -= .07*cheer
        wings[0].rotation_euler.y += .85*cheer+.13*math.sin(13*t)*cheer
        wings[1].rotation_euler.y -= .55*cheer+.08*math.sin(13*t+.8)*cheer
        crest.rotation_euler.y += .12*math.sin(9*(t-.15))*cheer
        smile.scale.z += .23*cheer
        for side, foot in zip((-1, 1), feet):
            foot.rotation_euler.y = side*.18*jump
    for obj in [rig, head, crest, smile, *wings, *eyes, *feet]:
        for prop in ('location', 'rotation_euler', 'scale'):
            obj.keyframe_insert(data_path=prop, frame=round(t*30)+1)


for clip, count in [('idle', 90), ('celebrate', 90)]:
    for obj in [rig, head, crest, smile, *wings, *eyes, *feet]:
        obj.animation_data_clear()
    for frame in range(count+1):
        pose(frame/30, clip == 'celebrate')
    scene.frame_start, scene.frame_end = 1, count
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / f'piko-{clip}.blend'))
    if '--preview' in sys.argv:
        for f in ([1] if clip == 'idle' else [23, 42]):
            scene.frame_set(f)
            scene.render.resolution_x = scene.render.resolution_y = 512
            scene.render.filepath = str(OUT / f'preview-{clip}-{f}.png')
            bpy.ops.render.render(write_still=True)
        scene.render.resolution_x = scene.render.resolution_y = 256
    else:
        folder = OUT / clip
        folder.mkdir(exist_ok=True)
        scene.render.filepath = str(folder / 'frame-')
        bpy.ops.render.render(animation=True)
