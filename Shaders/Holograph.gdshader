shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, world_vertex_coords;

uniform vec4 color = vec4(0.0, 0.3, 1.0, 1.0);

varying vec3 coords;
void vertex()
{
  coords = VERTEX.xyz;
}

float fresnel(float amount, vec3 normal, vec3 view)
{
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 )), amount);
}


float EaseIQuad(float x)
{
	return x * x * x;
}


void fragment() {
	ALBEDO = color.rgb;

	float f = fresnel(3.0, NORMAL, VIEW);
	float e = f * 0.4;
	if ( f > 0.4 ) { e = 1.; }
	
	ALPHA = e;
	
}

