shader_type spatial;
render_mode unshaded;

uniform sampler2D	texture_ : source_color;
uniform vec2		size;
uniform float		scale = 0.2;


#include "res://Shaders/Border.gdshaderinc"
#include "res://Shaders/ScaleUV.gdshaderinc"


float circle(vec2 position, float radius, float feather)
{
	return smoothstep(radius, radius + feather, length(position - vec2(0.5)));
}

float cursor_draw(vec2 iUV, float str)
{
	float inner = 1.5 - str * 0.8;
	float outer = 2.0 - str * 0.8;
	float feather = 0.5;
	float scaler = 0.005;
	return ( circle(iUV, inner*scaler, feather*scaler) - circle(iUV, outer*scaler, feather*scaler) ) * 0.5;
}

void fragment() {
	vec2 uv = scaleUV(UV, size, true);

	vec4 tex = texture(texture_, uv);

	ALBEDO = tex.rgb;
	// ADD_BEVEL(size, 0.025);
	if ( bevel(UV, size, 0.025) > 0.5 )
	{
		discard;
	}
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
