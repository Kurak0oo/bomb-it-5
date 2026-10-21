#!/usr/bin/env bash
# Replays every case in this folder matching a glob into .scratch reference runs.
set -u
root="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$root"
player="${PLAYER:-.scratch/edition-5-research/ruffle-runtime/target/ci/probe}"
for case in tools/reference_player/cases/stages/${1:-*}.json; do
	name="$(basename "$case" .json)"
	out=".scratch/edition-5-research/reference-runs/stages/$name"
	[[ -d "$out" ]] && continue
	timeout 900 python3 tools/replay_reference.py --player "$player" --observe --focus --case "$case" --output "$out" >/dev/null 2>&1 \
		&& echo "ok $name" || echo "FAILED $name"
done
