shader_type canvas_item;

uniform float whiten : hint_range(0.0, 1.0) = 0.48;
uniform float brightness : hint_range(1.0, 2.0) = 1.18;


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 lightened = mix(source.rgb, vec3(1.0), whiten);
	COLOR = vec4(min(lightened * brightness, vec3(1.0)), source.a);
}
