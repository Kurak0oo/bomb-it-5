#!/usr/bin/env bash
# macOS/Linux counterpart of build.ps1 with all research features
# (-Fixtures -Events -Compact -Focus -Display). Needs Rust, git and python3, plus a
# Vulkan driver on Linux (Mesa lavapipe works headless); macOS uses Metal.
# CHECK_ONLY=1 runs cargo check instead of building the player.
# RESET=1 first returns core/ of this task-owned checkout to the pinned revision; use it
# after a research patch changed, since only exact matching patches can be reversed.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
checkout="${1:-$here/../../.scratch/edition-5-research/ruffle-runtime}"
revision=45366370ed7d1a59c89aa3cf7b765c7a274407cd
patches=(reference-observer reference-fixtures reference-events reference-compact reference-focus
	reference-actors reference-geometry reference-drops reference-session-state reference-class-names
	reference-actor-bombs reference-ai-returns reference-move-step reference-active-pickups reference-platforms reference-rides
	reference-display reference-symbol)
if [[ ! -d "$checkout/.git" ]]; then
	git init -q "$checkout"
	git -C "$checkout" remote add origin https://github.com/ruffle-rs/ruffle
	git -C "$checkout" fetch -q --depth 1 origin "$revision"
	git -C "$checkout" checkout -q --detach FETCH_HEAD
fi
[[ "$(git -C "$checkout" rev-parse HEAD)" == "$revision" ]] || { echo "Unexpected Ruffle revision" >&2; exit 1; }
[[ -z "$(git -C "$checkout" diff --cached --name-only -- core)" ]] || { echo "Staged core changes present" >&2; exit 1; }
mkdir -p "$checkout/probe/src"
cp "$here/Cargo.toml" "$checkout/probe/Cargo.toml"
cp "$here/Cargo.lock" "$checkout/Cargo.lock"
cp "$here/src/main.rs" "$checkout/probe/src/main.rs"
touch "$checkout/probe/Cargo.toml" "$checkout/Cargo.lock" "$checkout/probe/src/main.rs"
# Portable workspace insertion (BSD sed on macOS has no GNU `sed -i`).
python3 - "$checkout/Cargo.toml" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path).read()
if not re.search(r'(?m)^\s*"probe",?\s*$', text):
    text, count = re.subn(r'(?m)^(\s*)"exporter",$', r'\1"exporter",\n\1"probe",', text, count=1)
    if not count:
        sys.exit("Workspace insertion point not found")
    open(path, "w").write(text)
PY
cd "$checkout"
if [[ "${RESET:-0}" == 1 ]]; then
	git checkout -q -- core
	git clean -fdq -- core
fi
for ((i=${#patches[@]}-1; i>=0; i--)); do
	if git apply --reverse --check --ignore-space-change "$here/${patches[$i]}.patch" 2>/dev/null; then
		git apply --reverse --ignore-space-change "$here/${patches[$i]}.patch"
	fi
done
[[ -z "$(git diff HEAD --name-only -- core)$(git ls-files --others --exclude-standard -- core)" ]] || { echo "Unrelated core changes" >&2; exit 1; }
for patch in "${patches[@]}"; do git apply --ignore-space-change "$here/$patch.patch"; done
features=reference-fixtures,reference-events,reference-compact,reference-focus,reference-display
if [[ "${CHECK_ONLY:-0}" == 1 ]]; then
	cargo check --locked -p probe --features "$features"
	exit 0
fi
cargo build --locked -p probe --profile ci --features "$features"
git diff HEAD > reference-changes.patch
python3 - "$revision" "$features" <<'PY'
import hashlib, json, platform, subprocess, sys
probe = "target/ci/probe"
json.dump({"ruffle_revision": sys.argv[1], "features": sys.argv[2].split(","),
           "cargo": subprocess.check_output(["cargo", "-V"], text=True).strip(),
           "platform": platform.platform(),
           "probe_sha256": hashlib.sha256(open(probe, "rb").read()).hexdigest()},
          open("reference-build.json", "w"), indent=2)
PY
cat reference-build.json
