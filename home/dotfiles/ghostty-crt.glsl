// Subtle CRT pass for Ghostty (custom-shader, Shadertoy-style API).
// Deliberately restrained: faint scanlines + gentle vignette + a whisper of
// bloom. The acrylic blur + neon palette do the heavy lifting; this just
// makes the glass feel like a tube. Delete the custom-shader line in
// ghostty.nix to turn it off.

float scanline(vec2 uv, float res) {
  // 2.5% dip on alternating lines, softened so retina doesn't moiré
  return 1.0 - 0.025 * (0.5 + 0.5 * sin(uv.y * res * 3.14159));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = fragCoord / iResolution.xy;
  vec3 col = texture(iChannel0, uv).rgb;

  // whisper of bloom: two cheap taps, additive
  vec2 px = 1.0 / iResolution.xy;
  vec3 glow = texture(iChannel0, uv + vec2(px.x, 0.0)).rgb
            + texture(iChannel0, uv - vec2(px.x, 0.0)).rgb;
  col += glow * 0.04;

  // scanlines
  col *= scanline(uv, iResolution.y * 0.5);

  // gentle vignette — corners fall off ~6%
  vec2 v = uv * (1.0 - uv);
  col *= 0.94 + 0.06 * pow(v.x * v.y * 15.0, 0.25);

  fragColor = vec4(col, 1.0);
}
