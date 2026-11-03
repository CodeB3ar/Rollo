# Rollo — web build

A static Godot 4.7.2 web export of the course. `index.html` is the entry point;
there is no build step on the host. It opens on the title card — any key or
click starts the run; crossing the arch finishes it and any key starts over.

## Publish on Vercel

```bash
cd ~/Desktop/rollo-web
npx vercel --prod
```

Or drag this whole folder onto <https://vercel.com/new>. No framework preset, no
build command, no output directory — it is served as-is.

`vercel.json` sets the two cross-origin headers Godot's web runtime wants and the
`application/wasm` type for `index.wasm` (38 MB, the engine itself; `index.pck`
is the game, 86 KB, because the course is built in code).

## Rebuild after changing the game

The game lives in the Godot project, not here. From the project folder:

```bash
./tools/export_web.sh            # writes this folder
./tools/export_web.sh /some/dir  # or anywhere else
```

It needs the Web export templates for 4.7.2 installed. The script also strips the
project's `godot_ai` autoload before exporting — that autoload starts a TCP server
for the editor's AI plugin, so a shipped build must not include it — and it never
touches the working tree.

## Known limits

- No audio yet.
- Web export runs on Godot's Compatibility (WebGL2) renderer, so shaders must
  stay inside that feature set. Two things have been lost to it already: the
  outline pass's normal-roughness term, and `instance uniform` in the toon
  shader (unsupported there; it read as 0 and dithered the whole course away).
