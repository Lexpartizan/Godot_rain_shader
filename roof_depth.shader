shader_type spatial;
render_mode unshaded, shadows_disabled;
void fragment(){
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	//depth = PROJECTION_MATRIX[3][2]/(depth*2.0-1.0+PROJECTION_MATRIX[2][2]) +VERTEX.z;
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	vec4 view = CAMERA_MATRIX*INV_PROJECTION_MATRIX * vec4(ndc,1.0);
	vec3 world_position =view.xyz/view.w;
	ALBEDO = world_position;
	//ALBEDO = vec3(world_position.y);
}