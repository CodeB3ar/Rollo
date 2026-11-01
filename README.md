## Snowpack — web build

A static Godot 4.7.2 web export of the course. `index.html` is the entry point;
there is no build step on the host.

# Play at https://rollo-game.vercel.app/

- No audio yet.
- Web export runs on Godot's Compatibility (WebGL2) renderer, so shaders must
  stay inside that feature set — the outline pass lost its normal-roughness term
  for exactly that reason.
