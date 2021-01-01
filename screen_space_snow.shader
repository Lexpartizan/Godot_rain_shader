// Based on https://blog.theknightsofunity.com/make-it-snow-fast-screen-space-snow-shader/

shader_type spatial;
render_mode unshaded;
uniform sampler2D snow_texture;
uniform sampler2D noise_3d_texture;
uniform lowp float snow_amount: hint_range(0.0,1.0) = 0.0;
uniform lowp float rain_amount: hint_range(0.0,1.0) = 0.0;
uniform lowp float wet_amount: hint_range(0.0,1.0) = 0.0;
uniform lowp float camera_far: hint_range(0.0,1000.0) = 500.0;
uniform lowp float rain_scale: hint_range(0.0,100.0) = 50.0;
//uniform lowp float rain_intensity: hint_range(5.0,20.0) = 50.0;
uniform lowp float rain_speed: hint_range(0,100.0) = 20.0;


lowp float rain_noise( lowp vec3 x, lowp float lod_bias, lowp float time ) //magick code from https://www.shadertoy.com/view/MsXXDf
{   
	x*=rain_scale;
	x.y+=time;
    lowp vec3 p = floor( x );
    lowp vec3 f = fract( x );
    f = f * f * ( 3.0 - 2.0 * f );
    lowp vec2 uv = (p.xy+vec2(37.0,17.0)*p.z) + f.xy;
    //lowp vec2 rg = texture(noise_3d_texture, uv*(1./256.0)).xy;
    //lowp float dens = mix( rg.x, rg.y, f.z );
	lowp float dens =texture(noise_3d_texture, uv/256.0).x;
    dens = pow( dens, 25.0 - rain_amount*15.0);
    //dens*= rain_intensity;
	dens=sin(dens);
    dens *= 0.2;
	
	return dens;
}

lowp float rnd(lowp vec2 uv){return texture(noise_3d_texture,uv).r;}

lowp vec3 saturation(lowp float saturation, lowp vec3 color) 
{
	float oneMinusSat = 1.0 - saturation;
	lowp vec3 luminance = vec3( 0.3086, 0.6094, 0.0820 )*oneMinusSat;
	mat3 saturation_matrix = mat3 (vec3(luminance.x) + vec3(saturation,0.0,0.0),vec3(luminance.y) + vec3(0.0,saturation,0.0),vec3(luminance.z) + vec3(0.0,0.0,saturation));
	return clamp(saturation_matrix*color,0.0,1.0);
}

void fragment() {  
lowp vec3 screen_texture = texture(SCREEN_TEXTURE,SCREEN_UV).rgb;
lowp float depth_buffer = texture(DEPTH_TEXTURE, SCREEN_UV).r;
lowp vec3 ndc = vec3(SCREEN_UV,depth_buffer)*2.0 -1.0;
lowp float depth =VERTEX.z+PROJECTION_MATRIX[3][2]/(ndc.z+PROJECTION_MATRIX[2][2]);
lowp vec4 world = CAMERA_MATRIX*INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
lowp vec3 world_position = world.xyz / world.w;
lowp vec3 normal_from_depth = normalize(cross(dFdx(world_position),dFdy(world_position)));
lowp float camera_far_treshold = step(depth,camera_far - 10.0);
lowp float distribution_snow;

distribution_snow = 0.5*rnd(world_position.xz) + normal_from_depth.y;
distribution_snow =smoothstep(0.75,1.0,distribution_snow);
lowp float snow_amount_offset = snow_amount-0.01*step(snow_amount,0.5)+0.01*step(0.5,snow_amount);//учитываем граничные случаи, чтобы при snow_amount = 0.0 не было точек снега и при snow_amount = 1.0 не было земли.
distribution_snow *= smoothstep(0.0,rnd(world_position.zx),snow_amount_offset);
distribution_snow*=camera_far_treshold;
lowp vec3 snow_color = texture(snow_texture,world_position.xz*1.0).rgb;
lowp vec3 albedo = screen_texture;

lowp float rain_distribution = smoothstep(0.0,1.0,normal_from_depth.y)*camera_far_treshold;
lowp float rain = rain_noise(world_position,0.0,TIME*rain_speed)*rain_distribution*step(0.01,rain_amount);
//rain = smoothstep(0.0,.3,rain);

albedo =mix(albedo,snow_color,distribution_snow);
albedo = mix (albedo,saturation(1.0+wet_amount,albedo)*(1.0-wet_amount*0.5)+rain,rain_distribution);
albedo = clamp(albedo,vec3(0.0),vec3(1.0));
ALBEDO = albedo;
 }