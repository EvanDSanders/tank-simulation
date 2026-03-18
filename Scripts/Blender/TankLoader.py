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

        pos     = godot_to_blender_pos(value[0])
        rot     = godot_to_blender_rot(value[1])
        world_m = rot.to_4x4()
        world_m.translation = pos

        # pose_bone.matrix is in armature local space
        rig.pose.bones[key].matrix = arm_inv @ world_m


def importer(frame: int, externalLoader: bool = False):
    global tank
    if frame == 0 and not externalLoader:
        load()

    frame_str = str(frame)
    if frame_str not in tank:
        return

    print(f"Importing frame {frame}")

    # On frame 0, create any bones that don't exist yet.
    if frame == 0:
        ensure_bones_exist(tank[frame_str]['bones'])

    # Use the same global-matrix technique for every frame (including 0).
    set_bones_pose(tank[frame_str]['bones'])

    


if not useLive:
    load()


def on_frame_change(scene):
    global tank
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


bpy.app.handlers.frame_change_post.append(on_frame_change)
