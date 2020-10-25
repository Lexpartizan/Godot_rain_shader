shader_type spatial;  
varying mat4 CAMERA;

void vertex() {
  CAMERA = CAMERA_MATRIX;
}
  
void fragment() {  
float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;  
depth = depth * 2.0 - 1.0;  
depth = PROJECTION_MATRIX[3][2] / (depth + PROJECTION_MATRIX[2][2]);  
depth +=VERTEX.z;
depth *=0.01;
ALBEDO =vec3(depth);

depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
vec4 world = CAMERA * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
vec3 world_position = world.xyz / world.w;
world_position*= 0.05;
ALBEDO = vec3(-world_position.z);
 }  

