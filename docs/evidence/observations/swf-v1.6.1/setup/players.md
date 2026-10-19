> Imported Dots record; claims are retained as delivered. See the [integration assessment](../../../edition-5-play-observations.md) for verification, missing files, and authority limits. Original relative paths in code spans refer to the [unaltered bundle](../../../../../.scratch/edition-5-research/observations/swf-v1.6.1/setup/players.md).

# Players / tooling setup (2026-10-16)

## Source SWF
- URL: https://www8.agame.com/games/flash/b/bomb_it_5/bomb-it-5-zh-fix.swf
- File: /workspace/bombit5-evidence/bomb-it-5-zh-fix.swf
- Bytes: 6,942,081 (matches expected)
- SHA-256: 718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2 (MATCH)
- Header (from FFDec dump): ZLIB-compressed, frameRate 30.0, 3 root frames; Root.as metadata SWF(width=700,height=510,frameRate=30); runtime sets stage.frameRate = 35.

## 7k7k alternate
- https://www.7k7k.com/swf/103707.htm fetched (alt/7k7k.htm). It embeds NO .swf. gameInfo.gamePath =
  https://flash.7k7k.com/cms/cms10/20150930/1126478127/10/main.html, and JS rewrites it to
  https://www.7k7k.com/swf/swfh5/103707.htm. Both URLs now return 7k7k's generic "hot games" listing page
  (alt/main.html, alt/swfh5_103707.htm, 199,893 bytes each). There was no SWF to download, so there is no ALTERNATE hash.

## Ruffle
- Desktop: ruffle-nightly-2026_10_16-linux-x86_64.tar.gz (official GitHub release tag nightly-2026-10-16)
  sha256 2e6fb37754ce653e3b640cfc7e946225b934df4ea53df293d1094814ed9e33ff
  `ruffle --version` -> Ruffle 0.8.0-nightly.2026.10.16-nightly (ff5321cd6e98523d9917d9f31ad20841ae50ec9a 2026-10-16)
  Path: setup/ruffle-desktop/ruffle
- Web self-hosted: ruffle-nightly-2026_10_16-web-selfhosted.zip
  sha256 30eb3eeb1be2c553cd15275a2fdf3afaff879651d6f164816dab93c8e1d3d8d0 -> web/ruffle/
- Note: Ruffle publishes only nightlies as GitHub releases; there is no "stable" tag. This is the newest release.

### Headless runs
1. Desktop under xvfb-run, first attempt: PANIC "Library libxkbcommon-x11.so could not be loaded" (exit 134). Fixed by
   apt installing libxkbcommon-x11-0, libgtk-3-0, mesa drivers.
2. Desktop on Xvfb :99 (default backend, and `-g gl`): it opened the SWF and kept running with no AVM errors, but the
   framebuffer capture was all black (setup/ruffle-headless.png, ruffle-desktop-gl.png). Log notes: "Preferred backend(s) of
   Open GL not available; falling back to any", "Unable to create audio device" (no sound card), OpenH264 not on the system
   (Ruffle downloads it), and no unicode device fonts. Desktop is installed but not verified visually on this GPU-less box.
   Logs: setup/ruffle-headless.log, setup/ruffle-desktop-gl.log.
3. Web build in Google Chrome (Xvfb, swiftshader WebGL): WORKS. It renders the title screen at 700x510 (setup/ruffle-web-25s.png).
   Console: "Ruffle WASM module has been initialized", renderer wgpu-webgl, warnings: unknown device fonts SimSun /
   Times New Roman / Noto Sans, stub flash.system.Security.allowDomain(), stub NativeMenuItem constructor, AudioContext
   needs a user gesture. Pure `--headless --screenshot` timed out because wasm does not advance under virtual time.
   Log: setup/ruffle-web-headless.log.

### Launch on localhost
    /workspace/bombit5-evidence/web/serve.sh      # python3 http.server on 127.0.0.1:8765
    open http://localhost:8765/                   # index.html: Ruffle, 700x510, scale=noScale, forceScale (1:1)
(wasm must be served over http, not file://. Click once to unmute audio.)

## JPEXS FFDec
- ffdec_26.3.0.zip from GitHub release version26.3.0, sha256 35f4930eb7c380afe66f2117f90b006deac0631473ad7500bb39c78f68645ecd
  -> setup/ffdec/ffdec.jar (run with `java -jar`)
- Java: OpenJDK 21.0.12.1 (Debian package openjdk-21-jre-headless, installed via apt)
- Export: `java -jar setup/ffdec/ffdec.jar -export script,image,sound,shape,text,binaryData reference-assets-NOT-FOR-RELEASE bomb-it-5-zh-fix.swf`
  -> 1068 scripts, 64 images, 52 sounds, 3655 shapes, 493 texts, 2 binaryData. It finished with OK and no errors (setup/ffdec-export.log).
- `-swf2xml` full dump -> reference-assets-NOT-FOR-RELEASE/swf-dump/swf.xml (used for map layouts).
