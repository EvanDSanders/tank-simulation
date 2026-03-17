"""
Belt-style track curve: path from wheel circles using common tangents + arcs.
- No shrinkwrap → no tilt twitch (tilt set from stable reference).
- Supports inner run (curve inside the wheel loop) via inner tangents.

Configure WHEELS and run on frame_change_post (see bottom). Uses same rig as TankLoader.
"""

import bpy
import math
import mathutils

# -----------------------------------------------------------------------------
# Config: same rig as TankLoader; list of (bone_name, radius_in_metres) or (bone_name, radius, "inner")
# Radii = track contact radius. With USE_EXPLICIT_ORDER, list order = path order (order the track physically runs).
# Typical order: drive -> top run (tension/idler) -> front -> bottom run (road wheels) -> back to drive.
WHEELS = [
    ("Drive Wheel.R", 50 / 200),
    
    ("Wheel.0.R", 40 / 200),
    ("Wheel.1.R", 40 / 200),  # add your wheel bone names and radii
    ("Wheel.2.R", 40 / 200),
    ("Wheel.3.R", 40 / 200),
    ("Wheel.4.R", 40 / 200),
    ("Wheel.5.R", 40 / 200),
    ("Wheel.6.R", 40 / 200),

    ("Tension Wheel.3.R", 30 / 200, "inner"),
    ("Tension Wheel.2.R", 30 / 200, "inner"),
    ("Tension Wheel.1.R", 30 / 200, "inner"),
    ("Tension Wheel.0.R", 30 / 200, "inner"),
    # ("Idler.L", 0.12),
]
# Use inner tangents and inner arcs (curve runs inside the wheel loop).
USE_INNER_RUN = True
# If True, path order = order of WHEELS above (track path order). If False, order by angle around centroid.
# Set True and list wheels in the order the track physically goes (e.g. drive -> top run -> front -> bottom run -> back to drive).
USE_EXPLICIT_ORDER = True
# Curve object name (created if missing).
CURVE_OBJ_NAME = "Track Curve L"
# Track plane:
# - "XZ": track loop lies in XZ (forward = X, up = Z, width = Y)
# - "XY": track loop lies in XY (forward = X, up = Y, width = Z)
# - "YZ": track loop lies in YZ (forward = -Y, up = Z, width = X)
TRACK_PLANE = "YZ"  # XZ, XY or YZ
# Arc resolution: number of points per wheel arc.
ARC_POINTS = 12
# Points along each straight tangent segment (excluding endpoints).
TANGENT_POINTS = 3
# Add a point slightly along each tangent segment (at JUNCTION_EASE) so the curve eases into the line and reduces kinks at arc/line corners.
SMOOTH_JUNCTIONS = True
JUNCTION_EASE = 0.03  # fraction along tangent segment for extra control point (e.g. 0.03 = 3%)
# Tilt mode: "zero" (no twist) or "plane" (tilt from track plane normal).
TILT_MODE = "zero"

# -----------------------------------------------------------------------------
rig = bpy.data.objects.get("Tank Bones")


def _get_axis_indices():
    """Return (axis_plane_0, axis_plane_1, axis_width) for chosen track plane."""
    if TRACK_PLANE == "XZ":
        # Loop lies in XZ, width is Y.
        return 0, 2, 1   # plane: x, z; width: y
    if TRACK_PLANE == "XY":
        # Loop lies in XY, width is Z.
        return 0, 1, 2   # plane: x, y; width: z
    if TRACK_PLANE == "YZ":
        # Loop lies in YZ (your case: track faces -Y, size along X = width).
        return 1, 2, 0   # plane: y, z; width: x
    # Fallback
    return 0, 2, 1


def _to_2d(v, axis0, axis1):
    return (v[axis0], v[axis1])


def _to_3d(p2, y_val, axis0, axis1, vert_axis):
    out = [0.0, 0.0, 0.0]
    out[axis0], out[axis1] = p2[0], p2[1]
    out[vert_axis] = y_val
    return mathutils.Vector(out)


def _cross2(a, b):
    """2D cross product (scalar): a x b = a.x*b.y - a.y*b.x."""
    return a[0] * b[1] - a[1] * b[0]


def _normalize2(p):
    L = (p[0]*p[0] + p[1]*p[1]) ** 0.5
    if L < 1e-9:
        return (1.0, 0.0)
    return (p[0] / L, p[1] / L)


def get_wheel_centers_2d():
    """Get list of (name, radius, (x,z)) in world space, projected to track plane."""
    if not rig or rig.type != 'ARMATURE':
        return []
    axis0, axis1, vert_axis = _get_axis_indices()
    world = rig.matrix_world
    out = []
    for item in WHEELS:
        if len(item) == 2:
            bone_name, radius = item
            inner = False
        else:
            bone_name, radius, mode = item
            inner = (mode == "inner")
        if bone_name not in rig.pose.bones:
            continue
        loc = world @ mathutils.Vector(rig.pose.bones[bone_name].matrix.translation)
        p2 = _to_2d(loc, axis0, axis1)
        out.append((bone_name, radius, p2, inner))
    return out


def order_wheels_by_angle(wheels):
    """Order wheels by angle around centroid (counterclockwise in 2D)."""
    if not wheels:
        return []
    cx = sum(w[2][0] for w in wheels) / len(wheels)
    cy = sum(w[2][1] for w in wheels) / len(wheels)
    def angle(w):
        x, y = w[2][0] - cx, w[2][1] - cy
        return math.atan2(y, x)
    return sorted(wheels, key=angle)


def outer_tangent_points(c1, r1, c2, r2):
    """
    Common outer tangent between two circles in 2D.
    Returns (t1, t2) or None. t1 on circle 1, t2 on circle 2.
    """
    dx = c2[0] - c1[0]
    dy = c2[1] - c1[1]
    d = (dx*dx + dy*dy) ** 0.5
    if d < 1e-9:
        return None
    # In local frame: C1 at (0,0), C2 at (d,0). u = (cos(phi), sin(phi)) from C1 to tangent point.
    # Outer: cos(phi) = (r2 - r1) / d (or r1-r2 depending on which tangent).
    diff = abs(r2 - r1)
    if d < diff - 1e-9:
        return None
    cos_phi = (r2 - r1) / d
    cos_phi = max(-1, min(1, cos_phi))
    sin_phi = math.sqrt(1 - cos_phi * cos_phi)
    # Two tangents: sin_phi and -sin_phi. We'll return both and let caller choose.
    u1 = (cos_phi, sin_phi)
    u2 = (cos_phi, -sin_phi)
    # Rotate from (d,0) frame to world: dir from C1 to C2 is (dx/d, dy/d).
    cos_a = dx / d
    sin_a = dy / d
    def rot(u):
        x, y = u[0] * cos_a - u[1] * sin_a, u[0] * sin_a + u[1] * cos_a
        return (c1[0] + r1 * x, c1[1] + r1 * y)
    def rot2(u):
        x, y = u[0] * cos_a - u[1] * sin_a, u[0] * sin_a + u[1] * cos_a
        return (c2[0] + r2 * x, c2[1] + r2 * y)
    return [(rot(u1), rot2(u1)), (rot(u2), rot2(u2))]


def inner_tangent_points(c1, r1, c2, r2):
    """Common inner tangent. Returns list of two options [(t1,t2), (t1',t2')] or None."""
    dx = c2[0] - c1[0]
    dy = c2[1] - c1[1]
    d = (dx*dx + dy*dy) ** 0.5
    if d < 1e-9:
        return None
    if d < r1 + r2 - 1e-9:
        return None
    cos_phi = (r1 + r2) / d
    cos_phi = max(-1, min(1, cos_phi))
    sin_phi = math.sqrt(1 - cos_phi * cos_phi)
    u1 = (cos_phi, sin_phi)
    u2 = (cos_phi, -sin_phi)
    cos_a = dx / d
    sin_a = dy / d
    def rot(u, sign=1):
        x, y = (u[0] * cos_a - u[1] * sin_a), (u[0] * sin_a + u[1] * cos_a)
        return (c1[0] + sign * r1 * x, c1[1] + sign * r1 * y)
    def rot2(u, sign=1):
        x, y = (u[0] * cos_a - u[1] * sin_a), (u[0] * sin_a + u[1] * cos_a)
        return (c2[0] - sign * r2 * x, c2[1] - sign * r2 * y)
    return [(rot(u1), rot2(u1)), (rot(u2), rot2(u2))]


def choose_tangent(options, c1, c2, centroid, use_inner):
    """Pick the tangent that keeps the path on the correct side (outer = away from centroid)."""
    if not options:
        return None
    ax, ay = c2[0] - c1[0], c2[1] - c1[1]
    gx = centroid[0] - c1[0]
    gy = centroid[1] - c1[1]
    side_centroid = _cross2((ax, ay), (gx, gy))
    for (t1, t2) in options:
        tx, ty = t1[0] - c1[0], t1[1] - c1[1]
        side_t = _cross2((ax, ay), (tx, ty))
        # Outer run: tangent point on opposite side from centroid. Inner: same side.
        if not use_inner and side_centroid * side_t < 0:
            return (t1, t2)
        if use_inner and side_centroid * side_t > 0:
            return (t1, t2)
    return options[0]


def _angle_in_short_arc(angle, a_start, a_end):
    """True if angle lies in the short arc from a_start to a_end (radians)."""
    da = a_end - a_start
    while da > math.pi:
        da -= 2 * math.pi
    while da < -math.pi:
        da += 2 * math.pi
    rel = angle - a_start
    while rel > math.pi:
        rel -= 2 * math.pi
    while rel < -math.pi:
        rel += 2 * math.pi
    if da > 0:
        return 0 < rel <= da
    if da < 0:
        return da <= rel < 0
    return False


def arc_points(center, radius, angle_start, angle_end, n_points, use_long_arc=False, arc_contain_angle=None):
    """Sample arc from angle_start to angle_end (radians), n_points inclusive of ends.
    If use_long_arc is True, take the reflex (long) arc (for inner run).
    If arc_contain_angle is set (e.g. centroid angle), use the arc that contains that angle (belly side)."""
    out = []
    da = angle_end - angle_start
    while da > math.pi:
        da -= 2 * math.pi
    while da < -math.pi:
        da += 2 * math.pi
    if arc_contain_angle is not None:
        use_long_arc = not _angle_in_short_arc(arc_contain_angle, angle_start, angle_end)
    if use_long_arc:
        da = da - 2 * math.pi if da > 0 else da + 2 * math.pi
    for i in range(n_points):
        t = i / (n_points - 1) if n_points > 1 else 1
        a = angle_start + t * da
        x = center[0] + radius * math.cos(a)
        y = center[1] + radius * math.sin(a)
        out.append((x, y))
    return out


def build_path_points(wheels_ordered, use_inner, y_val):
    """Build list of 3D points: arc on wheel 0, tangent to 1, arc on 1, ... (closed)."""
    axis0, axis1, vert_axis = _get_axis_indices()
    n = len(wheels_ordered)
    if n < 2:
        return []

    centroid = (
        sum(w[2][0] for w in wheels_ordered) / n,
        sum(w[2][1] for w in wheels_ordered) / n,
    )

    # Tangent points: between wheel i and i+1 we get (t_out_i, t_in_{i+1}).
    tangents = []  # [(t_out_i, t_in_{i+1}), ...]
    for i in range(n):
        j = (i + 1) % n
        c1, r1 = wheels_ordered[i][2], wheels_ordered[i][1]
        c2, r2 = wheels_ordered[j][2], wheels_ordered[j][1]
        inner_i = wheels_ordered[i][3] if len(wheels_ordered[i]) > 3 else use_inner
        opts = inner_tangent_points(c1, r1, c2, r2) if inner_i else outer_tangent_points(c1, r1, c2, r2)
        if opts is None:
            # Fallback: direct connection when no proper tangent (e.g. one circle much larger)
            u = _normalize2((c2[0] - c1[0], c2[1] - c1[1]))
            t1 = (c1[0] + r1 * u[0], c1[1] + r1 * u[1])
            t2 = (c2[0] - r2 * u[0], c2[1] - r2 * u[1])
            tangents.append((t1, t2))
        else:
            chosen = choose_tangent(opts, c1, c2, centroid, inner_i)
            # When one circle is much larger, avoid tangent on the "far" side of the big wheel (would cut across).
            if not inner_i and chosen is not None:
                t1, t2 = chosen
                # Vector from c2 to c1; tangent point t2 should be on the side of c2 facing c1 (near side).
                dx, dy = c1[0] - c2[0], c1[1] - c2[1]
                tx, ty = t2[0] - c2[0], t2[1] - c2[1]
                if dx * tx + dy * ty < 0 and (r2 > r1 * 1.4 or r1 > r2 * 1.4):
                    # Tangent is on far side of the larger wheel; use direct connection instead
                    u = _normalize2((c2[0] - c1[0], c2[1] - c1[1]))
                    t1 = (c1[0] + r1 * u[0], c1[1] + r1 * u[1])
                    t2 = (c2[0] - r2 * u[0], c2[1] - r2 * u[1])
                    chosen = (t1, t2)
            tangents.append(chosen)

    points_3d = []
    for i in range(n):
        t_in = tangents[(i - 1) % n][1]   # incoming tangent point on wheel i
        t_out = tangents[i][0]            # outgoing tangent point on wheel i
        c = wheels_ordered[i][2]
        r = wheels_ordered[i][1]
        inner_i = wheels_ordered[i][3] if len(wheels_ordered[i]) > 3 else use_inner
        a_in = math.atan2(t_in[1] - c[1], t_in[0] - c[0])
        a_out = math.atan2(t_out[1] - c[1], t_out[0] - c[0])
        # Inner run: use the arc that contains the centroid (belly side) so we don't get wrong-way dips.
        centroid_angle = math.atan2(centroid[1] - c[1], centroid[0] - c[0]) if inner_i else None
        arc = arc_points(c, r, a_in, a_out, ARC_POINTS, use_long_arc=inner_i, arc_contain_angle=centroid_angle)
        for p in arc[:-1]:
            points_3d.append(_to_3d(p, y_val, axis0, axis1, vert_axis))
        junction_pt = _to_3d(arc[-1], y_val, axis0, axis1, vert_axis)
        points_3d.append(junction_pt)

        # Straight segment from t_out to next wheel's t_in
        p_start, p_end = tangents[i][0], tangents[i][1]
        if SMOOTH_JUNCTIONS and JUNCTION_EASE > 0:
            # Ease point just along the line so NURBS doesn't overshoot at the corner
            te = JUNCTION_EASE
            pe = (p_start[0] + te * (p_end[0] - p_start[0]), p_start[1] + te * (p_end[1] - p_start[1]))
            points_3d.append(_to_3d(pe, y_val, axis0, axis1, vert_axis))
        for k in range(1, TANGENT_POINTS + 1):
            t = k / (TANGENT_POINTS + 1)
            px = p_start[0] + t * (p_end[0] - p_start[0])
            py = p_start[1] + t * (p_end[1] - p_start[1])
            points_3d.append(_to_3d((px, py), y_val, axis0, axis1, vert_axis))

    return points_3d


def ensure_curve_object():
    curve_obj = bpy.data.objects.get(CURVE_OBJ_NAME)
    if curve_obj and curve_obj.type == 'CURVE':
        return curve_obj
    curve_data = bpy.data.curves.new(CURVE_OBJ_NAME, type='CURVE')
    curve_data.dimensions = '3D'
    curve_obj = bpy.data.objects.new(CURVE_OBJ_NAME, curve_data)
    bpy.context.collection.objects.link(curve_obj)
    return curve_obj


def update_curve():
    wheels = get_wheel_centers_2d()
    if len(wheels) < 2:
        return
    wheels_ordered = wheels if USE_EXPLICIT_ORDER else order_wheels_by_angle(wheels)
    axis0, axis1, vert_axis = _get_axis_indices()
    y_val = sum(w[2][vert_axis] for w in wheels_ordered) / len(wheels_ordered)
    # Get y from first wheel in world (we stored 2D only; get vertical from rig)
    if rig:
        first_bone = next((w[0] for w in WHEELS if w[0] in rig.pose.bones), None)
        if first_bone:
            loc = rig.matrix_world @ mathutils.Vector(rig.pose.bones[first_bone].matrix.translation)
            y_val = loc[vert_axis]
    points_3d = build_path_points(wheels_ordered, USE_INNER_RUN, y_val)
    if not points_3d:
        return

    curve_obj = ensure_curve_object()
    curve_data = curve_obj.data
    curve_data.splines.clear()
    spline = curve_data.splines.new(type='NURBS')
    spline.use_cyclic_u = True
    spline.points.add(len(points_3d) - 1)
    for i, p in enumerate(points_3d):
        spline.points[i].co = (p.x, p.y, p.z, 1.0)
        if TILT_MODE == "zero":
            spline.points[i].tilt = 0.0
    curve_obj.data.bevel_depth = 0.0  # optional; set in viewport if you want thickness


def on_frame_change_track_curve(scene):
    if rig and rig.name in bpy.data.objects:
        update_curve()


# Register: run after TankLoader so bones are already posed.
def register():
    bpy.app.handlers.frame_change_post.append(on_frame_change_track_curve)
    update_curve()


def unregister():
    if on_frame_change_track_curve in bpy.app.handlers.frame_change_post:
        bpy.app.handlers.frame_change_post.remove(on_frame_change_track_curve)


# Run once when script is executed (e.g. in Blender's "Run Script" or as a module).
if __name__ == "__main__" or "track_curve" in dir():
    register()
