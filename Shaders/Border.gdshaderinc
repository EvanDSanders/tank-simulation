#include "res://Shaders/Remap.gdshaderinc"

float cmp(float num) { return clamp(num, 0, 1); }

float border(vec2 iUV, vec2 _size, float _scale)
{
	float bW = remap(0, _scale/_size.x, 1, 0., iUV.x);
	float bN = remap(0, _scale/_size.y, 1, 0., iUV.y);

	float bE = remap(1, 0, 0, 1, iUV.x);
	bE = remap(0, _scale/_size.x, 1, 0., bE);
	float bS = remap(1, 0, 0, 1, iUV.y);
	bS = remap(0, _scale/_size.y, 1, 0., bS);

	//float border = max( max(bN, bS), max(bE, bW) );
	float border = cmp(bN) + cmp(bE) + cmp(bS) + cmp(bW);
	return border;
}

float bevel(vec2 iUV, vec2 _size, float _scale)
{
	// Calculate distance from each edge in normalized space
	vec2 scaledSize = vec2(_scale / _size.x, _scale / _size.y);
	
	// Distance from left/right edges
	float distX = min(iUV.x, 1.0 - iUV.x);
	// Distance from top/bottom edges
	float distY = min(iUV.y, 1.0 - iUV.y);
	
	// Convert to pixel space
	vec2 dist = vec2(distX / scaledSize.x, distY / scaledSize.y);
	
	// Calculate corner bevel using distance field
	// Only affect corners where both x and y are within the bevel radius
	float cornerDist = length(max(vec2(1.0) - dist, vec2(0.0)));
	float bevel = smoothstep(1.0, 0.0, cornerDist);
	
	return float(bevel < 0.00001);
}

#define ADD_BORDER(size, scale) ALPHA = 1. - border(UV, size, scale)
#define ADD_BEVEL(size, scale) ALPHA = 1. - bevel(UV, size, scale)