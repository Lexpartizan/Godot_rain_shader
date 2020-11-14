shader_type spatial;
render_mode cull_back,unshaded,depth_draw_always, depth_draw_alpha_prepass, specular_disabled,shadows_disabled,diffuse_lambert; 
varying lowp mat4 camera_matrix;
varying lowp float height;

void vertex() { 
	camera_matrix = CAMERA_MATRIX;
	height = ((WORLD_MATRIX)*vec4(VERTEX,1.0)).y;
}
void fragment() {  
	float depth  = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	vec4 world = camera_matrix * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 world_position_pixel = world.xyz / world.w;
	lowp float heightmap = 1.0-smoothstep(0.0,30.0,height-world_position_pixel.y);
	ALBEDO = vec3(heightmap,0.0,0.0);
 }  