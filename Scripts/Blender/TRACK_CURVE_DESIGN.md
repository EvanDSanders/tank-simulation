# Track curve: belt-style path (like a real track)

## Why the new system

- **Tilt twitch**: Shrinkwrapping to a hull makes the curve’s tilt follow surface normals; when wheels jitter, normals jump and the curve tilts. Fix: **don’t derive tilt from geometry** — build the path from **math only** (tangents + arcs) and set tilt from a **stable reference** (e.g. world up or fixed “track plane” normal).
- **Inside wheels**: A hull is always “outside” the wheels, so you can’t have the track sit on the **inside** of wheels (inward tension, compact layouts). Fix: use **inner common tangents** and **arcs on the inner side** of the wheel circles so the curve can run inside the wheel loop.

## How a real track behaves

- The track is **tangent** to each wheel at the contact points.
- Between wheels it runs in **straight** segments (no bend except at the wheels).
- Around each wheel it follows a **circular arc** (the wheel’s radius).
- So the path is: **arc → straight → arc → straight → …** (closed loop).

That is exactly the **belt around pulleys** problem: given circles (wheel centers + radii), the belt path is:

1. **Straight (tangent) segments** between consecutive wheels — the common tangent lines.
2. **Arc segments** on each wheel between the two tangent points that touch that wheel.

No shrinkwrap, no hull — only circles and their common tangents.

## Two runs: outer and inner

- **Outer run (normal)**: Belt wraps the **outside** of the wheels. Use **outer** common tangents and arcs on the **outside** of each circle (the side away from the vehicle).
- **Inner run (inward tension)**: Belt runs **inside** the wheel loop. Use **inner** common tangents and arcs on the **inside** of each circle. Good for a second, “return” curve or compact designs.

You can have one curve for the outer run and one for the inner run, or a single curve that switches (e.g. via topology) if you model both sides.

## Stable tilt (no twitch)

- **Don’t** use shrinkwrap or surface normals for tilt.
- **Do** define tilt from a fixed reference, e.g.:
  - **Tilt = 0** (simplest): curve twist is zero in the curve’s native space.
  - **Track plane**: e.g. “track runs in XZ”; use the same “up” (e.g. Y) for the whole curve and compute a consistent normal in that plane for each point. Then set curve point tilt from that normal.

So: **path from tangent/arc math, tilt from a stable rule** → no dependence on wheel jitter.

## Implementation options

1. **Python script (recommended to start)**  
   Each frame (or on demand):
   - Read wheel positions (and radii) from armature bones or from your JSON.
   - Order wheels around the track (e.g. by angle in the track plane).
   - For each consecutive pair, compute outer (or inner) common tangent points.
   - Build arc points on each wheel between its two tangent points.
   - Assemble: arc → line → arc → line → … into a closed spline.
   - Write points (and optionally tilt) to a Blender curve object.  
   No shrinkwrap, no convex hull — so no tilt twitch, and you can do inner run by using inner tangents and inner arcs.

2. **Geometry nodes**  
   Geo nodes don’t have “solve common tangent between two circles” built in. You can:
   - **Hybrid**: Python (or a driver) computes the **control points** (tangent points + arc samples) each frame; Geometry Nodes only **interpolate** (e.g. “Curve from Points” or resample). Tilt can be set in Python or via a stable attribute in geo nodes.
   - **Full geo**: Possible only if you feed wheel positions in and implement the tangent math with math nodes (complex and heavy). Usually not worth it; Python is simpler and more flexible.

## Suggested workflow

1. **Python script** that:
   - Takes a list of wheel sources (bone names or object names) and radii (and per-wheel or global “inner” flag if you want inner run).
   - Runs on `frame_change_post` (like `TankLoader.py`) so the curve updates when the rig moves.
   - Creates/updates a single Curve object: **spline from tangent + arc points, tilt from stable reference** (e.g. 0 or track-plane up).
2. **Optional**: Second curve object for the inner run (same script, “inner” mode).
3. **Later**: If you want, move only the “smooth/resample” part into Geometry Nodes and keep the tangent/arc solver in Python.

## Math summary

- **Outer tangents**: both tangent points on the same side of the line joining the two centers; belt wraps the “outside” of both circles. Requires distance ≥ |r₁ − r₂|.
- **Inner tangents**: tangent points on opposite sides; belt crosses between the two circles. Requires distance ≥ r₁ + r₂.
- **Arc on a wheel**: from one tangent angle to the other on that wheel’s circle; choose the arc that goes the “right” way around the loop (no full wrap the wrong way).

All of this is 2D in the plane of the track (e.g. XZ); the same Y (or constant offset) is used for all points so the curve stays in the track plane.
