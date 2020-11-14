shader_type spatial;  
varying mat4 camera_matrix;

void vertex() {
  camera_matrix = CAMERA_MATRIX;
}
  
void fragment() {  
float depth  = texture(DEPTH_TEXTURE, SCREEN_UV).x;
vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
vec4 world = camera_matrix * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
vec3 world_position = world.xyz / world.w;
world_position*= 0.05;
ALBEDO = vec3(world_position.y);
 }  

