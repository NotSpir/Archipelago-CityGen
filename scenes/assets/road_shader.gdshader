shader_type spatial;
render_mode blend_mix, diffuse_lambert, specular_disabled;

uniform sampler2D road_texture : source_color;
uniform float tile_scale = 4.0;

void fragment() {
    vec2 uv = vec2(UV.x, UV.y*tile_scale);
    ALBEDO = texture(road_texture, uv).rgb;
}