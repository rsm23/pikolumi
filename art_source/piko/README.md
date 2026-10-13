# Piko 3D source

Identity revision 2 uses the canonical `assets/art/piko.png` as the painted texture on closed, curved Blender meshes. The large tilted head, brown eyes, open smiling beak, broad swept lilac crest, scalloped feathers, yellow belly, feet and large crayon retain the original illustration's shapes and detail. The original icon and splash artwork are unchanged. No third-party meshes, textures, motion capture or paid generation services are used.

`identity-v1/` retains the previous simplified model and authoring-script snapshot for comparison and recovery. To run that archived generator, first copy it back to the workspace's `scripts/` directory; its root resolution assumes that location.

Open `piko-idle.blend` or `piko-celebrate.blend` in Blender 5.2.1 to inspect the packed original texture, model, lighting and animation. Body, head, crest, wing and foot pivots have editable animation curves; a face shape key subtly widens the smile and an animated shader closes the eyes. Idle uses breathing, head tilts and blinks. Celebration includes anticipation, a gentle hop, landing squash, asymmetric wing gestures and delayed crest movement.

This is an articulated painted 3D relief designed for the original front view and small rotations. It has curved depth and closed shells; it is not a complete model for side/back turnaround views. Restricting the camera and gestures preserves the original face and avoids exposing unillustrated surfaces.

The mobile app displays transparent rendered 3D frames rather than a real-time 3D engine. Idle and celebration each have 90 poses at 30 fps. Ten tap reactions (wave, wink, nod, bow, wiggle, stretch, crayon, peek, flutter and hop) each have 60 poses over two seconds, for 780 frames total. Idle/reactions use 128-pixel frames and celebration uses 192-pixel frames. Reaction sheets load on demand; shared textures release when unused. Normal navigation needs at most 23.5 MiB of decoded clip textures rather than loading the whole 59.5 MiB collection. Reduced motion uses a static pose, with optional static library invitations on a deliberate tap.

Rebuild from the workspace root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python scripts/build_piko_3d.py
.venv/bin/python scripts/pack_piko.py
.venv/bin/python scripts/validate_piko.py
```

The authoring script saves the two `.blend` files here and renders intermediate frames under ignored `tmp/piko-frames/`. Packing writes the bundled files under `assets/art/piko_3d/` and records dimensions, crop and source/file hashes in its manifest. Blender may create `.blend1` backups; these are not required for building or shipping the app. Rebuilding intentionally replaces these generated files.
