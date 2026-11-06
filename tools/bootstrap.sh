#!/usr/bin/env bash
# Get a fresh checkout ready to work, and pack the local files git does not carry.
#
#   tools/bootstrap.sh [--bundle URL|ZIP] [--player] [--check]
#       Unpack the private local bundle (or BOMBIT5_BUNDLE_URL), install Godot 4.5.1
#       if none is found, optionally build the reference player and run the checks,
#       then report what this session can do.
#   tools/bootstrap.sh pack OUT.zip
#       Write the private bundle from this checkout. Never commit or publish it.
#
# The bundle holds only ignored files: the SWF, the decompiled AS3, the art pack
# (original/) and the reference captures (.scratch/compare/*/reference). FFDec downloads
# itself when needed; the reference player is rebuilt from tools/reference_player.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
godot_version="4.5.1"
godot_url="https://github.com/godotengine/godot/releases/download/${godot_version}-stable/Godot_v${godot_version}-stable_linux.x86_64.zip"
swf=".scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf"
player=".scratch/edition-5-research/ruffle-runtime/target/ci/probe"

if [ "${1:-}" = "pack" ]; then
	out="${2:?usage: tools/bootstrap.sh pack OUT.zip}"
	case "$out" in /*) ;; *) out="$PWD/$out" ;; esac
	[ -f "$swf" ] || { echo "missing $swf" >&2; exit 1; }
	rm -f "$out"
	{
		echo "$swf"
		[ -d .scratch/as3 ] && echo .scratch/as3
		[ -d original ] && echo original
		find .scratch/compare -mindepth 2 -maxdepth 2 -type d -name reference 2>/dev/null || true
	} | zip -qr "$out" -@
	echo "wrote $out ($(du -h "$out" | cut -f1)); keep it private"
	exit 0
fi

bundle="${BOMBIT5_BUNDLE_URL:-}"
build_player=0
run_checks=0
while [ $# -gt 0 ]; do
	case "$1" in
		--bundle) bundle="${2:?--bundle needs a URL or zip path}"; shift ;;
		--player) build_player=1 ;;
		--check) run_checks=1 ;;
		*) echo "unknown option $1" >&2; exit 2 ;;
	esac
	shift
done

if [ -n "$bundle" ]; then
	zip_path="$bundle"
	if [[ "$bundle" == http://* || "$bundle" == https://* ]]; then
		mkdir -p .scratch
		zip_path=".scratch/bundle.zip"
		echo "downloading the bundle..."
		curl -fsSL --retry 3 -o "$zip_path" "$bundle"
	fi
	unzip -qo "$zip_path" -d "$root"
	echo "unpacked $bundle"
fi

godot="${GODOT:-}"
if [ -z "$godot" ] && command -v godot >/dev/null 2>&1; then godot="$(command -v godot)"; fi
if [ -z "$godot" ] || ! "$godot" --version 2>/dev/null | grep -q "^${godot_version}"; then
	local_godot=".scratch/godot/Godot_v${godot_version}-stable_linux.x86_64"
	if [ ! -x "$local_godot" ]; then
		echo "installing Godot ${godot_version} under .scratch/godot..."
		mkdir -p .scratch/godot
		curl -fsSL --retry 3 -o .scratch/godot/godot.zip "$godot_url"
		unzip -qo .scratch/godot/godot.zip -d .scratch/godot
		rm -f .scratch/godot/godot.zip
	fi
	godot="$root/$local_godot"
fi
export GODOT="$godot"

if [ "$build_player" = 1 ]; then
	tools/reference_player/build.sh
fi

# The sound pack (original/audio) is built from the SWF; without it the game is silent.
if [ -f "$swf" ] && [ ! -f original/audio/index.json ]; then
	echo "building the sound pack from the SWF..."
	python3 tools/art_pipeline/original_audio.py || echo "sound pack build failed: the game will be silent" >&2
fi

have() { [ -e "$1" ] && echo yes || echo no; }
captures=$(find .scratch/compare -mindepth 2 -maxdepth 2 -type d -name reference 2>/dev/null | wc -l | tr -d ' ')
echo
echo "GODOT=$GODOT ($("$GODOT" --version 2>/dev/null | head -1))"
echo "SWF:                $(have "$swf")"
echo "decompiled AS3:     $(have .scratch/as3)"
echo "art pack:           $(have original/screens)"
echo "sound pack:         $(have original/audio/index.json)"
echo "reference captures: $captures cases"
echo "reference player:   $(have "$player")"
echo
echo "This session can:"
echo "  - run tools/run_checks.sh and the node comparison (compare.py check)"
[ -d original/screens ] && echo "  - show the original art in Godot"
[ "$captures" -gt 0 ] && [ -d original/screens ] && echo "  - score pixels for the $captures cases with captures"
[ -f "$swf" ] && [ -e "$player" ] && echo "  - record goldens and render art (record_screen.py, compare.py record)"
[ -f "$swf" ] && [ ! -e "$player" ] && echo "  - (record and render after: tools/bootstrap.sh --player)"
echo "Set GODOT in later shells: export GODOT=\"$GODOT\""

if [ "$run_checks" = 1 ]; then
	tools/run_checks.sh
fi
