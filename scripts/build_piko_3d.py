"""Author an articulated, painted 3D relief using Piko's canonical artwork.

Closed curved meshes preserve the authoritative front view, not a turnaround.
Blender --background --python scripts/build_piko_3d.py -- --preview
Omit --preview to render both 90-frame offline animations.
"""
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT, SOURCE = ROOT/'tmp/piko-frames', ROOT/'art_source/piko'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
WIDTH, HEIGHT, UNIT = 1222, 1287, 350
image = bpy.data.images.load(str(ROOT/'assets/art/piko.png'), check_existing=True)
image.pack()


def xyz(x, y, depth=0):
    return Vector(((x-620)/UNIT, -depth, (HEIGHT-y)/UNIT))


def pivot(name, x, y, depth=0, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    world = xyz(x, y, depth)
    obj.location = world if parent is None else world-parent.matrix_world.translation
    bpy.context.view_layer.update()
    return obj


def painted_material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    texture = nodes.new('ShaderNodeTexImage')
    texture.image = image
    texture.interpolation = 'Linear'
    surface = nodes.new('ShaderNodeBsdfPrincipled')
    surface.inputs['Roughness'].default_value = .86
    surface.inputs['Specular IOR Level'].default_value = .12
    links.new(texture.outputs['Color'], surface.inputs['Base Color'])
    # Retain the illustration's painted light while revealing curved depth.
    ink = nodes.new('ShaderNodeEmission')
    links.new(texture.outputs['Color'], ink.inputs['Color'])
    volume = nodes.new('ShaderNodeMixShader')
    volume.inputs[0].default_value = .22
    links.new(ink.outputs[0], volume.inputs[1])
    links.new(surface.outputs[0], volume.inputs[2])
    transparent = nodes.new('ShaderNodeBsdfTransparent')
    cutout = nodes.new('ShaderNodeMixShader')
    links.new(texture.outputs['Alpha'], cutout.inputs[0])
    links.new(transparent.outputs[0], cutout.inputs[1])
    links.new(volume.outputs[0], cutout.inputs[2])
    output = nodes.new('ShaderNodeOutputMaterial')
    links.new(cutout.outputs[0], output.inputs['Surface'])
    return mat, texture, surface, ink


paint, _, _, _ = painted_material('Canonical Piko • painted feathers')
face_mat, face_texture, face_surface, face_ink = painted_material('Canonical face • eyelids')


def math_node(operation, a, b=None):
    nodes, links = face_mat.node_tree.nodes, face_mat.node_tree.links
    node = nodes.new('ShaderNodeMath')
    node.operation = operation
    for slot, value in enumerate((a, b)):
        if value is None:
            continue
        if isinstance(value, (float, int)):
            node.inputs[slot].default_value = value
        else:
            links.new(value, node.inputs[slot])
    return node.outputs[0]


nodes, links = face_mat.node_tree.nodes, face_mat.node_tree.links
uv = nodes.new('ShaderNodeTexCoord')
split = nodes.new('ShaderNodeSeparateXYZ')
links.new(uv.outputs['UV'], split.inputs[0])
blinks = []
color = face_texture.outputs['Color']
for cx, cy, rx, ry, sample_x, sample_y in [(553,528,85,98,450,550), (826,436,64,94,720,390)]:
    blink = nodes.new('ShaderNodeValue')
    blink.name = 'Natural blink left' if not blinks else 'Natural blink right'
    blink.outputs[0].default_value = 0
    blinks.append(blink)
    dx = math_node('DIVIDE', math_node('SUBTRACT', split.outputs['X'], cx/WIDTH), rx/WIDTH)
    dy = math_node('DIVIDE', math_node('SUBTRACT', split.outputs['Y'], 1-cy/HEIGHT), ry/HEIGHT)
    distance = math_node('ADD', math_node('MULTIPLY',dx,dx), math_node('MULTIPLY',dy,dy))
    inside = math_node('MINIMUM',1,math_node('MAXIMUM',0,math_node('MULTIPLY',math_node('SUBTRACT',1,distance),12)))
    edge = math_node('SUBTRACT', 1.02, math_node('MULTIPLY',blink.outputs[0],2.08))
    lid = math_node('MULTIPLY', inside, math_node('GREATER_THAN',dy,edge))
    sample_uv = nodes.new('ShaderNodeVectorMath')
    sample_uv.operation = 'MULTIPLY'
    links.new(uv.outputs['UV'],sample_uv.inputs[0])
    sample_uv.inputs[1].default_value = (.2,.2,0)
    offset = nodes.new('ShaderNodeVectorMath')
    offset.operation = 'ADD'
    links.new(sample_uv.outputs[0], offset.inputs[0])
    offset.inputs[1].default_value = (sample_x/WIDTH-.2*cx/WIDTH,1-sample_y/HEIGHT-.2*(1-cy/HEIGHT),0)
    feather = nodes.new('ShaderNodeTexImage')
    feather.image = image
    links.new(offset.outputs[0], feather.inputs['Vector'])
    mix = nodes.new('ShaderNodeMixRGB')
    links.new(lid, mix.inputs[0])
    links.new(color, mix.inputs[1])
    links.new(feather.outputs['Color'], mix.inputs[2])
    color = mix.outputs[0]
    closed_curve = math_node('ADD', -.12, math_node('MULTIPLY', math_node('MULTIPLY',dx,dx), .18))
    line = math_node('LESS_THAN', math_node('ABSOLUTE',math_node('SUBTRACT',dy,closed_curve)), .035)
    line = math_node('MULTIPLY',line,math_node('LESS_THAN',math_node('ABSOLUTE',dx),.88))
    line = math_node('MULTIPLY',line,math_node('POWER',blink.outputs[0],10))
    lash = nodes.new('ShaderNodeMixRGB')
    links.new(line,lash.inputs[0])
    links.new(color,lash.inputs[1])
    lash.inputs[2].default_value = (.015,.08,.075,1)
    color = lash.outputs[0]
links.new(color, face_surface.inputs['Base Color'])
links.new(color, face_ink.inputs['Color'])


def relief(name, outline, center, depth, bulge, parent, mat=paint, feature=None):
    """Closed front/back shell, curved in depth, with projection UVs."""
    boundary = []
    for i, point in enumerate(outline):
        nxt = outline[(i+1) % len(outline)]
        for j in range(3):
            boundary.append((point[0]+(nxt[0]-point[0])*j/3,
                             point[1]+(nxt[1]-point[1])*j/3))
    count, rings = len(boundary), 18
    vertices, coords, faces = [], [], []
    origin = parent.matrix_world.translation

    def vertex(px, py, amount, back=False):
        d = depth+(bulge*math.sqrt(max(0,1-amount*amount)) if not back else -.14)
        if feature and not back:
            d += feature(px,py)
        vertices.append(tuple(xyz(px,py,d)-origin))
        coords.append((px/WIDTH,1-py/HEIGHT))

    vertex(*center,0)
    for ring in range(1,rings+1):
        radius = math.sin(math.pi*.5*ring/rings)
        for px,py in boundary:
            vertex(center[0]+(px-center[0])*radius,center[1]+(py-center[1])*radius,radius)
    for j in range(count):
        faces.append((0,1+j,1+(j+1) % count))
    for ring in range(rings-1):
        start,nxt = 1+ring*count,1+(ring+1)*count
        for j in range(count):
            k = (j+1) % count
            faces.append((start+j,nxt+j,nxt+k,start+k))
    back_start = len(vertices)
    vertex(*center,0,back=True)
    for px,py in boundary:
        vertex(px,py,1,back=True)
    front_edge = 1+(rings-1)*count
    for j in range(count):
        k = (j+1) % count
        faces.append((back_start,back_start+1+k,back_start+1+j))
        faces.append((front_edge+j,back_start+1+j,back_start+1+k,front_edge+k))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    obj = bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    layer = mesh.uv_layers.new(name='Canonical illustration projection')
    for polygon in mesh.polygons:
        polygon.use_smooth = True
        for loop in polygon.loop_indices:
            layer.data[loop].uv = coords[mesh.loops[loop].vertex_index]
    mesh.materials.append(mat)
    return obj


rig = pivot('Piko • breath and landing',620,1240)
relief('Plump body • feathered yellow belly',
       [(442,744),(593,726),(760,692),(876,716),(923,809),(917,946),
        (865,1063),(783,1116),(635,1133),(521,1143),(435,1084),(384,958),(401,824)],
       (651,925),0,.34,rig)
relief('Tail • layered turquoise feathers',
       [(103,893),(91,799),(109,741),(154,743),(155,697),(186,665),
        (222,677),(272,726),(326,755),(352,848),(285,919)],(225,804),-.04,.17,rig)
head = pivot('Head • soft nod and follow through',640,707,.36,rig)


def facial_depth(x,y):
    beak = .20*math.exp(-((x-729)/100)**2-((y-560)/96)**2)
    eyes = sum(.07*math.exp(-((x-cx)/rx)**2-((y-cy)/ry)**2)
               for cx,cy,rx,ry in [(553,528,73,84),(826,436,51,80)])
    return beak+eyes


face = relief('Large head • original eyes, blush and smiling beak',
       [(589,218),(689,219),(790,248),(852,290),(898,365),(919,434),
        (957,471),(977,529),(966,597),(928,658),(859,718),(769,757),
        (653,776),(523,778),(412,748),(349,712),(308,654),(292,563),
        (300,470),(337,383),(395,310),(469,258)],(640,510),.38,.36,head,face_mat,facial_depth)
face.shape_key_add(name='Original smiling face')
smile_key = face.shape_key_add(name='Happy open smile')
for vertex in smile_key.data:
    world = vertex.co+head.matrix_world.translation
    px,py = world.x*UNIT+620,HEIGHT-world.z*UNIT
    weight = math.exp(-((px-732)/80)**4-((py-600)/72)**4)
    vertex.co.z -= .037*weight

crest = pivot('Swept crest • delayed response',619,238,.40,head)
relief('Three broad swept lilac crest feathers',
       [(385,275),(385,130),(442,130),(442,15),(536,15),(612,76),
        (676,85),(707,150),(696,229),(670,283)],(575,190),.43,.10,crest)
wings = []
for name,origin,outline,center,d in [
    ('Left wing • scalloped feathers and coral tips',(475,785),
     [(522,734),(487,818),(454,900),(399,982),(351,1030),(302,1032),
      (263,1005),(221,1003),(178,976),(178,948),(143,937),(124,904),
      (139,878),(203,846),(261,816),(342,776),(425,735)],(357,866),.29),
    ('Right wing • large crayon and feather grip',(854,780),
     [(869,706),(923,638),(954,570),(994,454),(1042,396),(1083,371),
      (1121,373),(1138,424),(1128,486),(1111,550),(1162,585),
      (1189,636),(1201,709),(1173,794),(1145,841),(1114,863),
      (1087,885),(1052,902),(1013,937),(969,941),(930,914),(897,835)],(1038,690),.31),
]:
    wing = pivot(name+' • shoulder',*origin,d,rig)
    feature = (lambda x,y: .10*math.exp(-((x-1064)/110)**2-((y-640)/220)**2)) if name.startswith('Right') else None
    relief(name,outline,center,d,.15,wing,feature=feature)
    wings.append(wing)
feet = []
for side,outline,center in [
    (-1,[(340,1150),(440,1090),(540,1090),(590,1170),(590,1280),(340,1280)],(468,1173)),
    (1,[(640,1160),(650,1100),(780,1100),(900,1190),(900,1280),(640,1280)],(743,1177)),
]:
    foot = pivot(f'Foot {side} • landing',center[0],1125,.17,rig)
    relief(f'Orange foot {side} • three rounded toes',outline,center,.17,.10,foot)
    feet.append(foot)


def light(name,position,power,size):
    bpy.ops.object.light_add(type='AREA',location=position)
    obj = bpy.context.object
    obj.name = name
    obj.data.energy,obj.data.shape,obj.data.size = power,'DISK',size
    obj.rotation_euler = (Vector((0,0,1.9))-obj.location).to_track_quat('-Z','Y').to_euler()


light('Broad feather light',(-3,-4,6),280,5)
light('Soft fill',(4,-3,3),180,4)
bpy.ops.object.camera_add(location=(0,-12,1.87))
camera = bpy.context.object
camera.rotation_euler = (math.pi/2,0,0)
camera.data.type,camera.data.ortho_scale = 'ORTHO',4.48
scene = bpy.context.scene
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.cycles.transparent_max_bounces = 24
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.fps = 30
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.8,.9,1,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .3
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0


def bump(t,start,end):
    if t <= start or t >= end:
        return 0
    return math.sin(math.pi*(t-start)/(end-start))**2


base_locations = {obj:obj.location.copy() for obj in [rig,head,crest,*wings,*feet]}


REACTIONS = ('wave','wink','nod','bow','wiggle','stretch','crayon','peek','flutter','hop')


def pose(t,clip='idle'):
    period = 3 if clip in ('idle','celebrate') else 2
    breathe = math.sin(2*math.pi*t/period)
    for obj,base in base_locations.items():
        obj.location = base
        obj.rotation_euler = (0,0,0)
        obj.scale = (1,1,1)
    rig.location.z += .008*breathe
    rig.scale = (1-.003*breathe,1,1+.005*breathe)
    rig.rotation_euler.z = .022*math.sin(2*math.pi*t/period)
    head.rotation_euler.y = .013*math.sin(2*math.pi*(t-.12)/period)
    head.rotation_euler.z = .018*math.sin(2*math.pi*(t-.17)/period)
    crest.rotation_euler.y = .025*math.sin(2*math.pi*(t-.26)/period)
    wings[0].rotation_euler.y = .018*breathe
    wings[1].rotation_euler.y = -.013*breathe
    eyelid = max(bump(t,.70,.88),bump(t,2.17,2.35))
    smile_key.value = .12*bump(t,.55,1.65)
    if clip == 'celebrate':
        anticipation,hop = bump(t,.10,.45),bump(t,.40,1.15)
        settle,cheer = bump(t,1.05,1.42),bump(t,.28,2.42)
        rig.location.z += .20*hop-.035*anticipation-.022*settle
        rig.scale.z *= 1-.035*anticipation+.022*hop-.018*settle
        rig.scale.x *= 1+.018*anticipation-.012*hop+.009*settle
        head.rotation_euler.y += -.06*cheer
        head.rotation_euler.z += .045*bump(t,.60,1.70)
        wings[0].rotation_euler.y += .18*cheer+.035*math.sin(11*t)*cheer
        wings[1].rotation_euler.y -= .11*cheer+.021*math.sin(11*t+.8)*cheer
        wings[1].rotation_euler.z -= .08*cheer
        crest.rotation_euler.y += .08*math.sin(8*(t-.16))*cheer
        smile_key.value += .85*cheer
        for side,foot in zip((-1,1),feet):
            foot.rotation_euler.y = side*.07*hop
        eyelid = bump(t,1.60,1.79)
    gesture = bump(t,.18,1.82)
    if clip == 'wave':
        wings[0].rotation_euler.y += (.23+.06*math.sin(15*t))*gesture
        head.rotation_euler.y += .035*gesture
    elif clip == 'nod':
        head.rotation_euler.x += .09*math.sin(10*t)*gesture
        crest.rotation_euler.x += .045*math.sin(10*(t-.10))*gesture
    elif clip == 'bow':
        bow = bump(t,.25,1.65)
        head.rotation_euler.x += .15*bow
        rig.location.z -= .05*bow
        rig.rotation_euler.y += .035*bow
        crest.rotation_euler.x += .055*bump(t,.36,1.75)
    elif clip == 'wiggle':
        rig.rotation_euler.y += .065*math.sin(12*t)*gesture
        head.rotation_euler.y -= .04*math.sin(12*(t-.10))*gesture
        wings[1].rotation_euler.y -= .07*math.sin(12*(t-.15))*gesture
    elif clip == 'stretch':
        wings[0].rotation_euler.y += .25*gesture
        wings[1].rotation_euler.y -= .20*gesture
        rig.scale.z *= 1+.025*gesture
        head.rotation_euler.x -= .075*gesture
    elif clip == 'crayon':
        wings[1].rotation_euler.y -= .17*gesture
        wings[1].rotation_euler.z -= (.12+.045*math.sin(10*t))*gesture
        head.rotation_euler.z -= .055*gesture
    elif clip == 'peek':
        head.rotation_euler.z += .10*math.sin(5*t)*gesture
        head.rotation_euler.y += .07*math.sin(4*t)*gesture
        crest.rotation_euler.y += .035*math.sin(4*(t-.12))*gesture
    elif clip == 'flutter':
        wings[0].rotation_euler.y += (.12+.09*math.sin(18*t))*gesture
        wings[1].rotation_euler.y -= (.11+.075*math.sin(18*t+.6))*gesture
        crest.rotation_euler.y += .035*math.sin(18*(t-.12))*gesture
    elif clip == 'hop':
        hop = max(bump(t,.28,.90),bump(t,1.08,1.70))
        rig.location.z += .14*hop
        rig.scale.z *= 1+.018*hop
        rig.scale.x *= 1-.009*hop
        for side,foot in zip((-1,1),feet):
            foot.rotation_euler.y = side*.07*hop
    elif clip == 'wink':
        head.rotation_euler.y += .055*gesture
        smile_key.value += .6*gesture
    if clip in REACTIONS:
        smile_key.value += .3*gesture
        eyelid = bump(t,1.58,1.76)
    for index,blink in enumerate(blinks):
        value = (bump(t,.58,.92) if index == 0 else 0) if clip == 'wink' else eyelid
        blink.outputs[0].default_value = value
        blink.outputs[0].keyframe_insert('default_value',frame=round(t*30)+1)
    smile_key.keyframe_insert('value',frame=round(t*30)+1)
    for obj in base_locations:
        for prop in ('location','rotation_euler','scale'):
            obj.keyframe_insert(data_path=prop,frame=round(t*30)+1)


for clip in ('idle','celebrate',*REACTIONS):
    for obj in base_locations:
        obj.animation_data_clear()
    face_mat.node_tree.animation_data_clear()
    face.data.shape_keys.animation_data_clear()
    count = 90 if clip in ('idle','celebrate') else 60
    for frame in range(count+1):
        pose(frame/30,clip)
    scene.frame_start,scene.frame_end = 1,count
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/f'piko-{clip}.blend'))
    if '--preview' in sys.argv:
        scene.render.resolution_x = scene.render.resolution_y = 768
        for frame in ([1,25] if clip == 'idle' else [23,42]):
            scene.frame_set(frame)
            scene.render.filepath = str(OUT/f'preview-{clip}-{frame}.png')
            bpy.ops.render.render(write_still=True)
        scene.render.resolution_x = scene.render.resolution_y = 256
    else:
        folder = OUT/clip
        folder.mkdir(exist_ok=True)
        scene.render.filepath = str(folder/'frame-')
        bpy.ops.render.render(animation=True)
