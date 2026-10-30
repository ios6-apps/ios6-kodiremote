#!/bin/bash
# Builds KRClient and KRNotifier as a macOS command-line tool (with a tiny UIKit shim) and runs it against tools/mock_kodi.py.
# Needs Xcode's command line tools and python3. Uses free local ports; port 9090 (hard-wired in the app) is needed for the notification test and is skipped when taken.
set -e
cd "$(dirname "$0")/.."
OUT=build/tests
mkdir -p "$OUT"
xcrun clang -fobjc-arc -Wno-deprecated-declarations -Itests/shim -Isrc -framework Foundation \
    src/KRClient.m src/KRNotifier.m tests/shim/UIKitShim.m tests/kr_tests.m -o "$OUT/kr_tests"

free_port() { python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }
OPEN=$(free_port); AUTH=$(free_port); PLAIN=$(free_port)
NOTIFY=0
python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 9090))' 2>/dev/null && NOTIFY=9090

PIDS=()
trap 'kill "${PIDS[@]}" 2>/dev/null || true' EXIT
python3 tools/mock_kodi.py --port "$OPEN" --notify-port "$NOTIFY" --split > "$OUT/mock_open.log" 2>&1 & PIDS+=($!)
python3 tools/mock_kodi.py --port "$AUTH" --notify-port 0 --user kodi --password secret > "$OUT/mock_auth.log" 2>&1 & PIDS+=($!)
# something that answers HTTP but is not Kodi
mkdir -p "$OUT/www"
python3 -m http.server "$PLAIN" --bind 127.0.0.1 --directory "$OUT/www" > "$OUT/plain.log" 2>&1 & PIDS+=($!)
for p in $OPEN $AUTH $PLAIN; do
    for _ in $(seq 50); do curl -s -o /dev/null "http://127.0.0.1:$p/" && break; sleep 0.1; done
done

"$OUT/kr_tests" "$OPEN" "$AUTH" "$PLAIN" "$([ "$NOTIFY" = 9090 ] && echo 1 || echo 0)"
