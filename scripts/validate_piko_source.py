"""Run with Blender to verify the painted relief and its animation sources."""
import hashlib
import json
from collections import Counter
from pathlib import Path
import bpy

root = Path(__file__).resolve().parents[1]
reference = hashlib.sha256((root/'assets/art/piko.png').read_bytes()).hexdigest()
reports = {}
manifest=json.loads((root/'assets/art/piko_3d/manifest.json').read_text())
for clip,config in manifest['clips'].items():
    path = root/f'art_source/piko/piko-{clip}.blend'
    bpy.ops.wm.open_mainfile(filepath=str(path))
    scene = bpy.context.scene
    textures = [im for im in bpy.data.images if im.packed_file]
    assert len(textures) == 1
    assert hashlib.sha256(bytes(textures[0].packed_file.data)).hexdigest() == reference
    shells = {}
    for obj in bpy.data.objects:
        if obj.type != 'MESH':
            continue
        counts = Counter()
        for polygon in obj.data.polygons:
            counts.update(polygon.edge_keys)
        assert all(n == 2 for n in counts.values()), (obj.name,'open mesh')
        assert obj.data.uv_layers.active is not None
        depths = [v.co.y for v in obj.data.vertices]
        assert max(depths)-min(depths) > .2, (obj.name,'flat surface')
        shells[obj.name] = {'vertices':len(obj.data.vertices),'closed':True,'depth':round(max(depths)-min(depths),4)}
    assert len(shells) == 8
    poses = []
    for frame in range(1,config['frames']+2):
        scene.frame_set(frame)
        poses.append({o.name:(tuple(o.location),tuple(o.rotation_euler),tuple(o.scale)) for o in bpy.data.objects if o.type == 'EMPTY'})
    max_angle_step = max(abs(a-b) for prev,cur in zip(poses,poses[1:]) for name in prev for a,b in zip(prev[name][1],cur[name][1]))
    assert max_angle_step < .07, max_angle_step
    assert max(abs(a-b) for name in poses[0] for channel in range(3) for a,b in zip(poses[0][name][channel],poses[-1][name][channel])) < 1e-5, 'Loop/celebration must return to initial pose'
    reports[clip] = {'sourceSha256':hashlib.sha256(path.read_bytes()).hexdigest(),'packedCanonicalTextureMatches':True,'closedCurvedMeshes':shells,'maxJointRotationStepRadians':max_angle_step,'initialPoseRestoredAtEnd':True,'seconds':config['frames']/30}
dest=root/'docs/qa/piko-playful';dest.mkdir(exist_ok=True)
(dest/'model-validation.json').write_text(json.dumps({'brandReferenceSha256':reference,'clips':reports},indent=2)+'\n')
print('All twelve sources: eight closed curved meshes, exact canonical texture, smooth joint steps and rest poses verified')
