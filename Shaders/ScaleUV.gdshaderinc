vec2 scaleUV(vec2 iUV, vec2 _size, bool useMin) {
	vec2 uv = iUV * _size;
	// Get the minimum value between size.x and size.y
	float selected_size;
	if (useMin){
		selected_size = max(_size.x, _size.y);
	} else {
		selected_size = min(_size.x, _size.y);
	}
	// Scale both dimensions so that the minimum will be 1.0
	if (selected_size > 0.0) {
		uv /= selected_size;
	}
	// Center the UV coordinates
	uv += (1.0 - (_size / selected_size)) / 2.0;
	uv = clamp(uv, 0, 1);
	
	return uv;
}