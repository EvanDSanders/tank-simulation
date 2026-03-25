import bpy, json
import mathutils
import os

useLive = False  
# Same path as exporter.gd — in-memory file (Linux /dev/shm)
SHARED_STATE_PATH = "/dev/shm/tank_state.json"
TANK_PATH = "/home/evans/OneDrive/Documents/Blender OneDrive/TankBake.json"
BONE_LENGTH = 0.2  # metres

# Godot Y-up  ->  Blender Z-up
# Blender X =  Godot X
# Blender Y = -Godot Z
# Blender Z =  Godot Y
GODOT_TO_BLENDER = mathutils.Matrix((
    (1,  0,  0),
    (0,  0, -1),
    (0,  1,  0),
))

tank = None
rig = bpy.data.objects["Tank Bones"]
IS_BAKING = False


def load():
    global tank
    with open(TANK_PATH, "r") as file:
        tank = json.load(file)


def godot_to_blender_pos(pos):
    return GODOT_TO_BLENDER @ mathutils.Vector((pos[0], pos[1], pos[2]))


def godot_to_blender_rot(quat):
    """Convert a Godot quaternion [x, y, z, w] to a Blender 3x3 rotation matrix."""
    # Godot: [x, y, z, w]  ->  mathutils.Quaternion: (w, x, y, z)
    godot_mat = mathutils.Quaternion((quat[3], quat[0], quat[1], quat[2])).to_matrix()
    # Change-of-basis: P @ R @ P^T  (P is orthogonal so P^-1 = P^T)
    return GODOT_TO_BLENDER @ godot_mat @ GODOT_TO_BLENDER.transposed()


def ensure_bones_exist(frame_data):
    """Create any missing bones in Edit Mode, then restore the previous editor state."""
    missing = [key for key in frame_data if key not in rig.data.bones]
    if not missing:
        return

    prev_active = bpy.context.view_layer.objects.active
    rig_prev_mode = rig.mode  # read per-object mode before touching anything

    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')

    for key in missing:
        eb = rig.data.edit_bones.new(key)
        # Placeholder geometry so the bone is visible; pose sets the real transform.
        eb.head = (0, 0, 0)
        eb.tail = (0, BONE_LENGTH, 0)

    # Restore the rig's previous mode, then the previously active object.
    restore_mode = rig_prev_mode if rig_prev_mode in ('OBJECT', 'POSE') else 'OBJECT'
    bpy.ops.object.mode_set(mode=restore_mode)
    bpy.context.view_layer.objects.active = prev_active


def set_bones_pose(frame_data):
    """Set each bone's world-space transform directly via pose data (no mode switch needed)."""
    arm_inv = rig.matrix_world.inverted()

    for key, value in frame_data.items():
        if key not in rig.pose.bones:
            continue

        # Support both list format [[x,y,z],[x,y,z,w]]
        # and dict format {"0":[...],"1":[...]} / {"pos":[...],"rot":[...]}.
        pos_data = None
        rot_data = None
        if isinstance(value, (list, tuple)) and len(value) >= 2:
            pos_data = value[0]
            rot_data = value[1]
        elif isinstance(value, dict):
            pos_data = value.get(0, value.get("0", value.get("pos", value.get("position"))))
            rot_data = value.get(1, value.get("1", value.get("rot", value.get("rotation"))))

        if pos_data is None or rot_data is None:
            continue

        try:
            pos = godot_to_blender_pos(pos_data)
            rot = godot_to_blender_rot(rot_data)
            world_m = rot.to_4x4()
            world_m.translation = pos

            # pose_bone.matrix is in armature local space
            rig.pose.bones[key].matrix = arm_inv @ world_m
        except (KeyError, IndexError, TypeError, ValueError) as ex:
            print(f"Skipping malformed transform for bone '{key}': {ex}")


def apply_pose_to_edit_bones():
    """
    Bake the current pose into the armature's rest/edit bones.

    This fixes cases where the visual bone placement doesn't match in Edit Mode.
    """
    ctx = bpy.context

    # Store current editor state (selection, active object, and mode).
    prev_active_obj = ctx.view_layer.objects.active
    prev_active_name = prev_active_obj.name if prev_active_obj else None
    prev_mode = prev_active_obj.mode if prev_active_obj else None
    prev_selected_names = [obj.name for obj in ctx.selected_objects]

    try:
        # Switch to the Tank Bones armature and enter Pose Mode.
        bpy.ops.object.select_all(action='DESELECT')
        rig.select_set(True)
        ctx.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode='POSE')

        # Apply pose into the rest/edit bones.
        bpy.ops.pose.armature_apply(selected=False)
    finally:
        # Restore selection.
        bpy.ops.object.select_all(action='DESELECT')
        for name in prev_selected_names:
            obj = bpy.data.objects.get(name)
            if obj:
                obj.select_set(True)

        # Restore active object and mode.
        if prev_active_name:
            restored = bpy.data.objects.get(prev_active_name)
            if restored:
                ctx.view_layer.objects.active = restored
                if prev_mode:
                    try:
                        bpy.ops.object.mode_set(mode=prev_mode)
                    except RuntimeError:
                        bpy.ops.object.mode_set(mode='OBJECT')
        else:
            try:
                bpy.ops.object.mode_set(mode='OBJECT')
            except RuntimeError:
                pass


def importer(frame: int, externalLoader: bool = False):
    global tank
    if tank is None:
        return

    if frame == 0 and not externalLoader:
        load()

    frame_str = str(frame)
    if frame_str not in tank:
        return

    print(f"Importing frame {frame}")

    frame_payload = tank.get(frame_str, {})
    if not isinstance(frame_payload, dict):
        print(f"Skipping frame {frame}: payload is not a dict")
        return

    bones = frame_payload.get('bones')
    stats = frame_payload.get('stats')
    if not isinstance(bones, dict):
        print(f"Skipping frame {frame}: missing/invalid 'bones'")
        return
    if not isinstance(stats, dict):
        print(f"Skipping frame {frame}: missing/invalid 'stats'")
        return

    # On frame 0, create any bones that don't exist yet.
    if frame == 0:
        ensure_bones_exist(bones)

    # Use the same global-matrix technique for every frame (including 0).
    set_bones_pose(bones)

    angle_l = stats.get('angle L')
    angle_r = stats.get('angle R')
    if angle_l is not None:
        bpy.data.node_groups["TankAngleProvider"].nodes["Switch.004"].inputs[1].default_value = angle_l
    if angle_r is not None:
        bpy.data.node_groups["TankAngleProvider"].nodes["Switch.004"].inputs[2].default_value = angle_r

    # Frame 0: bake pose into edit bones so placement matches in Edit Mode.
    # if frame == 0:
        # apply_pose_to_edit_bones()

def _keyframe_current_pose_and_stats(frame: int):
    """Insert keyframes for current rig pose and tank stat-driven node values."""
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = 'QUATERNION'
        pose_bone.keyframe_insert(data_path="location", frame=frame)
        pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame)
        pose_bone.keyframe_insert(data_path="scale", frame=frame)

    switch = bpy.data.node_groups["TankAngleProvider"].nodes["Switch.004"]
    switch.inputs[1].keyframe_insert(data_path="default_value", frame=frame)
    switch.inputs[2].keyframe_insert(data_path="default_value", frame=frame)


def bake_animation():
    """Bake all frames from JSON onto the rig and node input sockets."""
    global tank, IS_BAKING
    if tank is None:
        return

    frame_numbers = sorted(int(k) for k in tank.keys() if str(k).isdigit())
    if not frame_numbers:
        return

    ensure_bones_exist(tank[str(frame_numbers[0])]['bones'])

    scene = bpy.context.scene
    prev_frame = scene.frame_current
    scene.frame_start = frame_numbers[0]
    scene.frame_end = frame_numbers[-1]

    IS_BAKING = True
    try:
        # Avoid frame_set() in the main loop. It can trigger handlers/depsgraph work
        # repeatedly and appear to hang on long bakes.
        for frame in frame_numbers:
            importer(frame, True)
            _keyframe_current_pose_and_stats(frame)
    finally:
        IS_BAKING = False
        scene.frame_set(prev_frame)


if not useLive:
    load()
    bake_animation()
import time

def on_frame_change(scene):
    start_time = time.time()
    global tank, IS_BAKING
    if IS_BAKING:
        return
    try:
        if useLive:
            if os.path.isfile(SHARED_STATE_PATH):
                try:
                    with open(SHARED_STATE_PATH, "r") as f:
                        tank = json.load(f)
                    importer(0, True)
                except (json.JSONDecodeError, OSError):
                    pass
        else:
            importer(scene.frame_current)
    except Exception as ex:
        # Never allow frame handler exceptions to wedge playback/export workflow.
        print(f"TankLoader handler error (frame {scene.frame_current}): {ex}")
        
    end_time = time.time()
    print(f"Frame change took {end_time - start_time} seconds")

# Register the frame-change handler without accumulating duplicates on reload.
_handlers = bpy.app.handlers.frame_change_post
_this_module = __name__
for _h in list(_handlers):
    if getattr(_h, "__name__", None) == "on_frame_change" and getattr(_h, "__module__", None) == _this_module:
        try:
            _handlers.remove(_h)
        except ValueError:
            pass

# Offline mode bakes immediately; only add handler in live mode.
if useLive and not any(
    getattr(_h, "__name__", None) == "on_frame_change" and getattr(_h, "__module__", None) == _this_module
    for _h in _handlers
):
    _handlers.append(on_frame_change)
