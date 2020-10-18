shader_type spatial;
//render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;
uniform lowp sampler2D addition_tex: hint_albedo;
uniform lowp sampler2D puddles_normal_tex;
uniform lowp sampler2D streaks_normal_tex;
uniform lowp float Rain_amount: hint_range(0.0,1.0);
uniform lowp float scale_UV_rain: hint_range(0.0,10.0);
uniform lowp float scale_UV_material:hint_range(0.0,10.0);

uniform lowp sampler2D Material_Albedo: hint_albedo;
uniform lowp sampler2D Material_Norm: hint_normal;
uniform lowp sampler2D Material_Rough: hint_white;
uniform lowp sampler2D Material_Metal: hint_white;

//varying lowp vec3 world_up;
varying lowp vec3 pos;
varying lowp vec3 weights;
void vertex()
{
	//world_up = mat3(WORLD_MATRIX)*vec3(0.0,1.0,0.0);
	pos = mat3(WORLD_MATRIX)*VERTEX;
	weights = mat3(WORLD_MATRIX)*NORMAL;// weights*=weights;
}

float edge_mask(float time,vec2 uv)
{
	time = fract(time);
	lowp float puddles = texture(addition_tex,uv).r-(1.0 - time);
	puddles =1.0-distance(vec2(puddles),vec2(0.1))/0.1;
	puddles*=abs(sin(time*3.14));
	puddles = clamp(puddles,0.0,1.0);
	return puddles;
}

lowp vec4 calc_puddles(lowp float puddles1,lowp float puddles2, lowp vec2 uv_temp)
{
	if (puddles1<puddles2) uv_temp = uv_temp.yx;
	
	lowp vec4 puddles;
	puddles.a = max(puddles1,puddles2);
	puddles.rgb = mix(vec3(0.5,0.5,1.0),texture (puddles_normal_tex,uv_temp).rgb,puddles.a);
	return puddles;
}
void fragment()
{
	
	lowp vec2 uv_rain = UV*scale_UV_rain;
	lowp vec2 uv_mat = UV*scale_UV_material;
	lowp vec2 uv_streaks;
	lowp vec3 mask = abs(weights);

	uv_streaks=pos.zy;
	if (mask.z >=mask.x) uv_streaks=pos.xy;
		
	uv_streaks*=scale_UV_rain*0.75;
	lowp float Rain_speed = 0.5+Rain_amount;
	lowp float time = TIME*Rain_speed;
	lowp float is_it_raining = smoothstep(0.01,0.01,Rain_amount); //if no rain - no paddles
	lowp vec4 puddles = calc_puddles(edge_mask(time,uv_rain),edge_mask(time+0.5,uv_rain.yx),uv_rain);
	puddles*=smoothstep(0.7,.9,smoothstep(0.0,1.0,weights.y));//puddles only on top 
	puddles*= is_it_raining;//if no rain - no paddles
	lowp float metalic = texture(Material_Metal, uv_mat).x;
	lowp float streaks = (texture(addition_tex, uv_streaks).g);
	streaks*=is_it_raining;//if no rain - no streaks
	streaks*= clamp(texture(addition_tex, vec2(uv_streaks.x,uv_streaks.y+time*Rain_speed*0.15)).b-0.5,0.0,1.0);//gradient fall
	streaks = smoothstep(0.0,0.1,streaks);
	lowp float under_roof = smoothstep(-0.3,0.0,weights.y);// normal looks down, the rain doesn't flow.
	streaks*= under_roof;
	
	lowp float wet = 1.0-Rain_amount*0.66;
	lowp vec3 norm =texture(Material_Norm,uv_mat).rgb;
	norm = mix(norm,puddles.rgb,puddles.a);
	norm = mix(norm,texture(streaks_normal_tex,uv_streaks).rgb,streaks);
	//NORMALMAP = normalize(norm);
	lowp float rain = clamp (puddles.a+streaks,0.0,1.0);
	lowp float rough = texture(Material_Rough,uv_mat).r;
	rough = mix(rough*wet,0.0,rain);
	
	lowp vec3 dry_color =texture(Material_Albedo,uv_mat).rgb;
	lowp vec3 wet_color = mix(dry_color*wet, dry_color, metalic); //darken albedo, if not metal
	wet_color = mix(dry_color,wet_color,under_roof);
	
	ALBEDO = wet_color;
	METALLIC = mix(metalic,0.0,rain);
	NORMALMAP = norm;
	ROUGHNESS = rough;
}