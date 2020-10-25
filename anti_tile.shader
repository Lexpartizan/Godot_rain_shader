// A random offset is applied to the texture UVs per Voronoi cell. Distance to the cell is used to smooth the transitions between cells.
// https://www.iquilezles.org/www/articles/texturerepetition/texturerepetition.htm

shader_type canvas_item;

vec4 hash4(vec2 p){
	return fract(sin(vec4(1.0 + dot(p, vec2(37.0,17.0)), 2.0 + dot(p, vec2(11.0,47.0)), 3.0 + dot(p, vec2(41.0,29.0)), 4.0 + dot(p, vec2(23.0,31.0)))) * 103.0);
	}

void fragment(){
	float v = 0.6;
	vec2 p = floor(UV);
	vec2 f = fract(UV);
	vec2 ddx = dFdx(UV);
	vec2 ddy = dFdy(UV);
	vec3 va;
	float w1;
	float w2;
	for(int j=-1; j<=1; j++){
		for(int i=-1; i<=1; i++){
			vec2 g = vec2(float(i), float(j));
			vec4 o = hash4(p + g);
			vec2 r = g - f + o.xy;
			float d = dot(r, r);
			float w = exp(-5.0 * d);
			vec3 c = textureGrad(TEXTURE, UV + v * o.zw, ddx, ddy ).xyz;
			va += w * c;
			w1 += w;
			w2 += w * w;
		}
	}
	
	float mean = textureGrad(TEXTURE, UV, ddx * 16.0, ddy * 16.0 ).x;
	vec3 res = mean + (va - w1 * mean) / sqrt(w2);
	
	COLOR = vec4(mix( va/w1, res, v ), 1.0);
}