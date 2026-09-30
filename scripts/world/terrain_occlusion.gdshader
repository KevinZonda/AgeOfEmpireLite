shader_type canvas_item;
render_mode unshaded;

uniform sampler2D visibility_mask : filter_nearest, repeat_disable;
uniform bool fog_enabled = false;

void fragment() {
	if (fog_enabled) {
		vec4 fog = texture(visibility_mask, UV);
		COLOR.rgb = mix(COLOR.rgb, fog.rgb, fog.a);
	}
}
