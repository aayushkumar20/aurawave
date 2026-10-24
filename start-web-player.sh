#!/usr/bin/env bash
# Aura Music Web Player Launcher
set -e

PORT=${1:-3000}
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/firebase/public"

echo "🎵 Starting Aura Music Web Player on http://localhost:$PORT ..."
echo "👉 Open http://localhost:$PORT in your browser to test live streaming and chat!"

if command -v python3 &>/dev/null; then
    python3 "$DIR/../../server.py" "$PORT"
elif command -v npx &>/dev/null; then
    npx -y serve -l "$PORT" "$DIR"
else
    echo "Please install python3 or node/npx to serve static files."
    exit 1
fi
