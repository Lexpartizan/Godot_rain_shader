//So, this work based on:
//1. drops: https://www.shadertoy.com/view/ldSBWW   Author: Élie Michel License: CC BY 3.0
//2. streaks: https:/deepspacebanana.github.io/blog/shader/art/unreal%20engine/Rainy-Surface-Shader-Part-1
//3. wet albedo: https://seblagarde.wordpress.com/2013/04/14/water-drop-3b-physically-based-wet-surfaces/
//So, license CC BY 3.0, becouse drops.
shader_type spatial;
//render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx, world_vertex_coords;

uniform lowp sampler2D Material_Albedo: hint_albedo;
uniform lowp sampler2D Material_Norm: hint_normal;
uniform lowp sampler2D Material_Rough: hint_white;
uniform lowp sampler2D Material_Metal: hint_black;
uniform lowp float scale_UV_material:hint_range(0.0,10.0);
uniform lowp float scale_UV_rain: hint_range(0.0,100.0);

uniform lowp float rain_amount: hint_range(0.0,1.0);
uniform lowp float wet_level: hint_range(0.0,1.0);
uniform lowp float streaks_length: hint_range(0.0,1.0) = 0.5;
uniform lowp float streaks_angle: hint_range(0.0,1.0) = 0.8;
uniform lowp float snow_amount: hint_range(0.0,1.0);
uniform lowp float without_snow_angle: hint_range(0.0,1.0) = 0.3;
uniform lowp float snow_brightness:hint_range(0.0,1.0);

uniform lowp sampler2D noise_tex;
uniform lowp sampler2D drops_tex; //normal.rg+timeshift+alpha
uniform lowp sampler2D ripples_tex; //normal.rg+timeshift+alpha
uniform lowp sampler2D streaks_tex; //normal.rg+timeshift+alpha
uniform lowp sampler2D Snow_Norm: hint_normal;
//uniform lowp sampler2D Snow_Rough: hint_white;
//varying lowp vec3 world_up;
varying lowp vec3 pos;
varying lowp vec3 world_pos;
varying lowp vec3 weights;
varying lowp vec3 mask;

varying lowp float snow_distribution;
varying lowp float under_rain;
varying lowp float start_streaks_angle;
varying lowp float puddles_plain;
varying lowp float raining;
varying lowp float time;
varying lowp float wetness;
varying lowp float thin_layer_water;
varying lowp float puddles_amount;
//varying lowp mat3 world_matrix;
//varying lowp vec2 triplanar_uv_snow;
void vertex()
{
	//world_up = mat3(WORLD_MATRIX)*vec3(0.0,1.0,0.0);
	pos = VERTEX;//this fits for simple triplanar
	
	world_pos = ((WORLD_MATRIX)*vec4(VERTEX,1.0)).xyz;// for triplanar puddles
	weights = mat3(WORLD_MATRIX)*NORMAL;// weights*=weights;
	mask = abs(weights);
	
	time = TIME*1.5;
	raining = step(0.01,rain_amount);// rain_amount not 0.0;
	under_rain = smoothstep(-0.1,0.0,weights.y);// normal looks down, the rain doesn't flow. 0.0 - under roof,1.0 - under rain 
	snow_distribution = smoothstep(without_snow_angle,1.0,weights.y);
	start_streaks_angle = 1.0-step(streaks_angle,weights.y);
	puddles_plain =step(0.999,weights.y);//puddles only on top;
	wetness = smoothstep(0.0,0.25,wet_level);
	thin_layer_water = smoothstep(0.25,0.5,wet_level);
	puddles_amount = smoothstep(0.0,1.0,wet_level);
	//lowp float snow_height =0.05*smoothstep(0.7,1.0,snow_distribution*snow_amount); //because sometime mesh tears
	//VERTEX+= NORMAL*snow_height;
}

lowp vec4 get_drops_and_streaks(lowp vec2 drops_uv, lowp vec2 streaks_uv)
{
	lowp vec4 drops;
	lowp vec4 drops_tex_color = texture(drops_tex,drops_uv);
	drops.xyz = vec3 (drops_tex_color.rg,1.0);
	lowp float static_drops_mask = 1.0-step(0.1,drops_tex_color.a);
	
	lowp float time_shift = fract((drops_tex_color.b*2.0-1.0)-time*0.25);
	lowp float dyn_drops_mask = step(0.9,drops_tex_color.a)*time_shift;
	lowp vec3 drops_dyn = mix(vec3(0.5,0.5,1.0),drops.xyz,time_shift);
	drops.a = dyn_drops_mask+static_drops_mask;
	drops.xyz =mix(vec3(0.5,0.5,1.0),drops.xyz,static_drops_mask);
	drops.xyz=mix(drops.xyz,drops_dyn,dyn_drops_mask);
	
	lowp vec4 streaks_tex_color = texture(streaks_tex,streaks_uv);
	lowp vec4 streaks;
	streaks.xyz = vec3(streaks_tex_color.rg,1.0);
	streaks.a = streaks_tex_color.a;
	streaks.a*=start_streaks_angle;
	streaks.a*=clamp(texture(streaks_tex, vec2(streaks_uv.x,streaks_uv.y+time*0.2)).b - (0.7-0.3*streaks_length),0.0,1.0);//gradient fall
	streaks.a = smoothstep(0.0,0.2,streaks.a);//Strengthening streaks to 1.0
	drops = mix(drops,streaks,streaks.a);
	drops.xyz = normalize(drops.xyz);
	drops.a*= raining*under_rain;
	return drops;
}

lowp vec4 get_puddles_and_ripples(lowp vec3 puddles_normal, lowp vec2 uv)
{
	lowp vec4 puddles;
	puddles.rgb =puddles_normal;
	//puddles.a = texture(noise_tex,world_pos.xz*0.01).r;
	//puddles.a =smoothstep(1.0-puddles_amount,1.0,puddles.a);
	
	puddles.a = 1.0-smoothstep(puddles_amount*0.3,(puddles_amount)*0.4,texture(noise_tex,world_pos.xz*.5).r);
		
	puddles.a*=puddles_amount;
	lowp vec2 ripples_uv = uv*0.3;
	lowp vec4 ripples_tex_color_1 = texture(ripples_tex,ripples_uv);
	lowp vec4 ripples_tex_color_2 = texture(ripples_tex,ripples_uv+0.25);
	lowp vec4 ripples_tex_color_3 = texture(ripples_tex,ripples_uv+0.5);
	lowp vec4 ripples_tex_color_4 = texture(ripples_tex,ripples_uv+0.75);
	
	lowp vec4 ripples1;lowp vec4 ripples2;lowp vec4 ripples3;lowp vec4 ripples4;
	ripples1 = vec4(ripples_tex_color_1.r,ripples_tex_color_1.g,1.0,ripples_tex_color_1.a);
	ripples2 = vec4(ripples_tex_color_2.r,ripples_tex_color_2.g,1.0,ripples_tex_color_2.a);
	ripples3 = vec4(ripples_tex_color_3.r,ripples_tex_color_3.g,1.0,ripples_tex_color_3.a);
	ripples4 = vec4(ripples_tex_color_4.r,ripples_tex_color_4.g,1.0,ripples_tex_color_4.a);
	lowp float time_ripples_1 = fract(time*0.5+(ripples_tex_color_1.b*2.0 - 1.0));
	lowp float time_ripples_2 = fract(time*0.5+0.25+(ripples_tex_color_2.b*2.0 - 1.0));
	lowp float time_ripples_3 = fract(time*0.5+0.5+(ripples_tex_color_3.b*2.0 - 1.0));
	lowp float time_ripples_4 = fract(time*0.5+0.75+(ripples_tex_color_4.b*2.0 - 1.0));
	lowp float nums_of_waves = 3.0;
	ripples1.a = smoothstep(0.0,0.8,sin(clamp((time_ripples_1-1.0+ripples1.a)*10.0,0.0,nums_of_waves)*6.28)*(1.0-time_ripples_1));
	ripples2.a = smoothstep(0.0,0.8,sin(clamp((time_ripples_2-1.0+ripples2.a)*10.0,0.0,nums_of_waves)*6.28)*(1.0-time_ripples_2));
	ripples3.a = smoothstep(0.0,0.8,sin(clamp((time_ripples_3-1.0+ripples3.a)*10.0,0.0,nums_of_waves)*6.28)*(1.0-time_ripples_3));
	ripples4.a = smoothstep(0.0,0.8,sin(clamp((time_ripples_4-1.0+ripples4.a)*10.0,0.0,nums_of_waves)*6.28)*(1.0-time_ripples_4));
	ripples1 = mix(ripples1,ripples2,ripples2.a);
	ripples1 = mix(ripples1,ripples3,ripples3.a);
	ripples1 = mix(ripples1,ripples4,ripples4.a);
	ripples1.rgb =normalize(ripples1.rgb);
	ripples1.a*=raining;
	puddles = mix (puddles,ripples1,step(0.7,ripples1.a*step(0.85,puddles.a)));//puddles+ripples on puddles;
	puddles.a*= puddles_plain*under_rain;
	return puddles;
}

lowp vec3 saturation(lowp float saturation, lowp vec3 color) 
{
	float oneMinusSat = 1.0 - saturation;
	lowp vec3 luminance = vec3( 0.3086, 0.6094, 0.0820 )*oneMinusSat;
	mat3 saturation_matrix = mat3 (vec3(luminance.x) + vec3(saturation,0.0,0.0),vec3(luminance.y) + vec3(0.0,saturation,0.0),vec3(luminance.z) + vec3(0.0,0.0,saturation));
	return clamp(saturation_matrix*color,0.0,1.0);
}

void fragment()
{
	lowp vec2 triplanar_uv_rain; 
	lowp vec2 triplanar_uv_streaks;
	lowp vec2 triplanar_uv_snow;
	
	lowp float branchless = step(mask.x,mask.z);
	triplanar_uv_rain = pos.xy*branchless+pos.zy*(1.0-branchless);//branchless primitive triplanar proj
	triplanar_uv_streaks = triplanar_uv_rain; //streaks projected only by sides
	branchless = step(mask.x,mask.y)*step(mask.z,mask.y);
	triplanar_uv_rain = triplanar_uv_rain*(1.0-branchless)+pos.xz*branchless;//
	
	triplanar_uv_rain*=scale_UV_rain;
	triplanar_uv_streaks*=scale_UV_rain*0.3;
	triplanar_uv_snow = pos.xz*scale_UV_rain*0.5;
	//uv calculating is done. i want do this in vertex, but get some artefacts on the borders of projections. Sad.
	
	lowp vec2 uv_mat = UV*scale_UV_material;
	lowp vec4 drops = get_drops_and_streaks(triplanar_uv_rain, triplanar_uv_streaks);
	lowp vec4 puddles = get_puddles_and_ripples(vec3(0.5,0.5,1.0),triplanar_uv_rain);
	//ALBEDO = vec3(puddles.a);
	lowp vec3 dry_albedo =texture(Material_Albedo,uv_mat).rgb;
	lowp float snow_mask =clamp(smoothstep(-0.1,1.0,texture(Material_Albedo,uv_mat,10.0).r)*5.0,0.0,1.0);//there is magical code 
	/*Initially, the snow distribution is taken from the R component of the albedo texture. 
	But since the textures are generally light and dark, the snow level is different on different materials.
	If we take a large-level mipmap (the farthest one), it will be a pixel with the brightness of the texture.
	Knowing the brightness of the texture, we somehow, very incorrectly, but still equalize the level of snow on the materials.*/
		
	snow_mask *= snow_distribution*snow_amount;
	snow_mask = 1.0-smoothstep(0.0,snow_mask,dry_albedo.r);
	snow_mask = smoothstep(0.0,0.9,snow_mask);
	dry_albedo = mix(dry_albedo,vec3(snow_brightness),snow_mask);//add snow
	dry_albedo = mix(dry_albedo,vec3(snow_brightness),smoothstep(0.8,0.9,snow_distribution*snow_amount));//add snow
		
	lowp float dry_rough = texture(Material_Rough,uv_mat).r;
	dry_rough = mix(dry_rough,1.0,smoothstep(0.0,0.2,snow_mask));//add snow
	
	lowp vec3 norm =texture(Material_Norm,uv_mat).rgb;
	norm = mix(norm,texture(Snow_Norm,triplanar_uv_snow).rgb,snow_mask);//add snow
		
	lowp float dry_metalic = texture(Material_Metal, uv_mat).x;
	dry_metalic= mix(dry_metalic,0.0,snow_mask);//add snow
		//wet albedo code
	lowp float porosity =clamp((dry_rough-0.5)/0.4,0.0,1.0);
	lowp float factor = mix(1.0,0.2,(1.0-dry_metalic)*porosity);
	lowp float wet_rough = 1.0 - mix(1.0,1.0 - dry_rough,mix(1.0,factor,wetness*0.5));//wetness*0.5 in original formula
	//wet albedo code ends
	lowp vec3 wet_albedo =saturation(1.0+wetness,dry_albedo);
	wet_albedo = wet_albedo*mix(1.0,factor,wetness);
	ALBEDO = mix(dry_albedo,wet_albedo,wetness);

	float metalness = mix(dry_metalic,0.0,drops.a);
	metalness = mix(dry_metalic,0.0,puddles.a);
	METALLIC = metalness;
	
	norm = mix(norm,drops.rgb,drops.a);
	norm = mix(norm,puddles.rgb,puddles.a);
	//NORMALMAP = normalize(norm);
	NORMALMAP = norm;
	wet_rough = mix(wet_rough,0.07,drops.a);
	wet_rough = mix(wet_rough,0.3,puddles.a);
	wet_rough = mix(wet_rough,wet_rough*0.5,thin_layer_water);
	ROUGHNESS = mix(dry_rough,wet_rough,under_rain);
	}