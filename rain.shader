//So, this work based on:
//1. drops: https://www.shadertoy.com/view/ldSBWW   Author: Élie Michel License: CC BY 3.0
//2. streaks: https:/deepspacebanana.github.io/blog/shader/art/unreal%20engine/Rainy-Surface-Shader-Part-1
//3. wet albedo: https://seblagarde.wordpress.com/2013/04/14/water-drop-3b-physically-based-wet-surfaces/
//So, license CC BY 3.0, becouse drops.


shader_type spatial;
//render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;

uniform lowp sampler2D addition_tex;
uniform lowp sampler2D noise_tex;
uniform lowp sampler2D ripples_tex; //normal+alpha
uniform lowp sampler2D streaks_tex; //normal+alpha
uniform lowp sampler2D Snow_Norm: hint_normal;
//uniform lowp sampler2D Snow_Rough: hint_white;

uniform lowp float rain_amount: hint_range(0.0,1.0);
uniform lowp float wet_level: hint_range(0.0,1.0);
uniform lowp float snow_amount: hint_range(0.0,1.0);
uniform lowp float scale_UV_rain: hint_range(0.0,3.0);
uniform lowp float scale_UV_material:hint_range(0.0,10.0);

uniform lowp sampler2D Material_Albedo: hint_albedo;
uniform lowp sampler2D Material_Norm: hint_normal;
uniform lowp sampler2D Material_Rough: hint_white;
uniform lowp sampler2D Material_Metal: hint_black;

//varying lowp vec3 world_up;
varying lowp vec3 pos;
varying lowp vec3 weights;
varying lowp vec2 triplanar_uv_rain;
varying lowp vec2 triplanar_uv_snow;
varying lowp float snow_distribution;

//varying lowp vec2 triplanar_uv_snow;
void vertex()
{
	//world_up = mat3(WORLD_MATRIX)*vec3(0.0,1.0,0.0);
	pos = mat3(WORLD_MATRIX)*VERTEX;
	weights = mat3(WORLD_MATRIX)*NORMAL;// weights*=weights;
	
	lowp vec3 mask = abs(weights);
	lowp float branchless = step(mask.x,mask.z);triplanar_uv_rain = pos.xy*branchless+pos.zy*(1.0-branchless);//branchless primririve triplanar proj
	lowp float on_top = step(0.9,mask.y);
	branchless = step(mask.x,on_top)*step(mask.z,on_top); triplanar_uv_rain = triplanar_uv_rain*(1.0-branchless)+pos.xz*branchless;//
	triplanar_uv_rain*=scale_UV_rain;
	triplanar_uv_snow = pos.xz*scale_UV_rain*0.5;
	snow_distribution = smoothstep(0.3,0.9,weights.y);
	lowp float snow_height =0.05*smoothstep(0.7,1.0,snow_distribution*snow_amount); //because of the last smoothstep, artifacts appear for some reason
	VERTEX+= NORMAL*snow_height;
}

lowp vec2 noise_drops(lowp vec2 p)
{
	p*=1.5;
	lowp vec2 noise;
	noise.x = texture(noise_tex,p).r;
	noise.y = texture(noise_tex,p.yx).r;
	return noise;
}

lowp vec4 get_drops(lowp float time,)
{
	lowp vec2 displ = noise_drops(triplanar_uv_rain*0.1); // Displacement drop
	lowp vec4 drops = vec4(0.5,0.5,1.0,0.0);
	lowp vec2 x = vec2(200.0) * 0.1;  // Number of potential drops (in a grid)
	lowp vec2 p = 6.28 * triplanar_uv_rain * x + (displ - .5) * 2.;
	lowp vec2 s = sin(p);
// Current drop properties. Coordinates are rounded to ensure a
// consistent value among the fragment of a given drop.
	lowp vec2 v = noise_drops(round(triplanar_uv_rain * x - 0.25) / x);
	lowp vec4 d = vec4(v, v);
	// Drop shape and fading
	lowp float t = (s.x+s.y) * max(0., 1. - fract(time * (d.b + .1) + d.g) * 2.0);
	// d.r -> only x% of drops are kept on, with x depending on the size of drops
	lowp vec3 normal = normalize(vec3(-cos(p), mix(.2, 2., t-.5)));// Drop normal
	normal = normal*0.5+0.5;
	normal.g = 1.0 -normal.g;
	lowp float branchless = step(d.r,0.4)*step(0.5,t);
	drops = drops*(1.0-branchless)+vec4(normal,1.0)*branchless;
		
	lowp vec4 streaks;
	lowp vec2 uv_streaks = triplanar_uv_rain*0.3;
	streaks = texture(streaks_tex, uv_streaks);
	streaks.a*=1.0-step(0.9,weights.y);
	
	streaks.a*= clamp(texture(addition_tex, vec2(uv_streaks.x,uv_streaks.y+time*0.2)).b-0.65,0.0,1.0);//gradient fall
	streaks.a = smoothstep(0.0,0.2,streaks.a);//Strengthening streaks to 1.0
	drops = mix (drops,streaks,streaks.a);
	return drops;
}

lowp vec4 edge_mask(lowp float time,lowp vec2 uv)
{
	time = fract(time);
	lowp vec4 ripples = texture(ripples_tex,uv);
	ripples.a = ripples.a - (1.0 - time);
	ripples.a = 1.0-distance(vec2(ripples.a),vec2(0.01))/0.3;
	ripples.a*=abs(sin(time*3.14));
	ripples.a = clamp(ripples.a,0.0,1.0);
	return ripples;
}

lowp vec4 get_puddles(lowp float time, lowp vec2 uv,lowp float raining,lowp float under_rain, lowp float puddles_amount)
{
	uv*=0.5;
	lowp vec4 ripples = edge_mask(time,uv);
	lowp vec4 ripples_2 = edge_mask(time+0.5,vec2(-uv.x, uv.y));
	lowp vec4 ripples_3 = edge_mask(time+0.25,vec2(uv.x, -uv.y));
	lowp vec4 ripples_4 = edge_mask(time+0.75,vec2(-uv.x, -uv.y));
	
	lowp float branchless;
	branchless = step(ripples.a,ripples_2.a); ripples = ripples*(1.0-branchless)+ripples_2*branchless; //branchless code if (ripples_2.a > ripples.a) ripples = ripples_2;
	branchless = step(ripples_3.a,ripples_4.a); ripples_3 = ripples_3*(1.0-branchless)+ripples_4*branchless;
	branchless = step(ripples.a,ripples_3.a); ripples = ripples*(1.0-branchless)+ripples_3*branchless;
	
	ripples.a *=raining*under_rain;// if raining
	lowp vec4 puddles;
	puddles.rgb = vec3(0.5,0.5,1.0);
	puddles.a = texture(noise_tex,uv*0.01).r;
	puddles.a = smoothstep(0.0,0.8,puddles.a);
	puddles.a =smoothstep(1.0-puddles_amount,1.0,puddles.a);
	puddles.a*=step(0.999,weights.y);//puddles only on top;
	puddles = mix (puddles,ripples,step(0.7,ripples.a*puddles.a));//puddles+ripples on puddles;
	puddles.a*=puddles_amount;
	return puddles;
}

void fragment()
{
	lowp float wetness = smoothstep(0.0,0.25,wet_level);
	lowp float thin_layer_water = smoothstep(0.25,0.5,wet_level);
	lowp float puddles_amount = smoothstep(0.0,1.0,wet_level);
	lowp vec2 uv_mat = UV*scale_UV_material;
	lowp vec3 mask = abs(weights);
	lowp float under_rain = smoothstep(-0.4,0.0,weights.y);// normal looks down, the rain doesn't flow. 0.0 - under roof,1.0 - under rain 
	lowp float raining = step(0.01,rain_amount);// rain_amount not 0.0;
	lowp float time = TIME*1.5;
	vec4 drops = get_drops(time);
	drops.a*=under_rain*raining;
	lowp vec4 puddles = get_puddles(time,triplanar_uv_rain,raining,under_rain,puddles_amount);
	//drops = mix(streaks,drops,drops.a*(1.0-puddles.a));//streaks+drops
	
	lowp float snow_color = clamp(texture(noise_tex,triplanar_uv_snow*1.0).r+0.3,0.1,0.9);
	lowp float snow_cover = smoothstep(0.0,0.5,snow_amount)*snow_distribution;
	lowp float snow_fill_normals = smoothstep(0.5,0.9,snow_amount)*snow_distribution;
	lowp vec3 norm =texture(Material_Norm,uv_mat).rgb;
	lowp float dry_rough = texture(Material_Rough,uv_mat).r;
	lowp vec3 dry_albedo =texture(Material_Albedo,uv_mat).rgb;
	lowp float dry_metalic = texture(Material_Metal, uv_mat).x;
	dry_metalic= mix(dry_metalic,0.0,snow_cover);
	dry_rough = mix(dry_rough,1.0,smoothstep(0.0,0.1,snow_cover));
	//wet albedo code
	lowp float porosity =clamp((dry_rough-0.5)/0.4,0.0,1.0);
	lowp float factor = mix(1.0,0.2,(1.0-dry_metalic)*porosity);
	lowp float wet_rough = 1.0 - mix(1.0,1.0 - dry_rough,mix(1.0,factor,thin_layer_water*1.0));//wetness*0.5 in original formula
	//wet albedo code ends
	lowp vec3 wet_albedo = dry_albedo*mix(1.0,factor,wetness);
	//wet_albedo = mix(wet_albedo,clamp (wet_albedo*20.0,0.04,0.9),puddles.a);
	//wet_albedo = mix(wet_albedo,texture(Snow_Albedo,triplanar_uv_snow).rgb,snow_cover);
	wet_albedo = mix(wet_albedo,vec3(0.6-thin_layer_water*0.1),snow_cover);
	ALBEDO = mix(dry_albedo,wet_albedo,under_rain);
	
	float metalness = mix(dry_metalic,0.0,drops.a);
	metalness = mix(dry_metalic,1.0,puddles.a);
	METALLIC = metalness;
	norm = mix(norm,texture(Snow_Norm,triplanar_uv_snow).rgb,snow_fill_normals);
	//norm = mix(norm,vec3(0.5,0.5,1.0),snow_fill_normals);
	norm = mix(norm,drops.rgb,drops.a);
	norm = mix(norm,puddles.rgb,puddles.a);
	NORMALMAP = norm;
	
	wet_rough = mix(wet_rough,0.0,drops.a);
	wet_rough = mix(wet_rough,0.0,puddles.a);
	//wet_rough = mix(wet_rough,wet_rough*0.5,smoothstep(0.5,1.0,puddles_amount));
	ROUGHNESS = mix(dry_rough,wet_rough,under_rain);
	
	//ALBEDO = mix(ALBEDO,vec3(snow_color),snow_amount*snow_angle);
	//SPECULAR =mix(SPECULAR,1.0,puddles.a);
	}