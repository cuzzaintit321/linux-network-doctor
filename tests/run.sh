#!/usr/bin/env bash
# Controlled command fixtures: these tests make no network requests.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/bin"
cat > "$work/bin/timeout" <<'SH'
#!/usr/bin/env bash
shift
"$@"
SH
cat > "$work/bin/ip" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == '-o' ]]; then
    printf '1: lo: <LOOPBACK,UP>\n'
    [[ "${MOCK_LINK:-up}" == up ]] && printf '2: enp2s0: <BROADCAST,UP>\n'
else
    [[ "${MOCK_ROUTE:-yes}" == yes ]] && printf 'default via 192.0.2.1 dev enp2s0\n'
fi
exit 0
SH
cat > "$work/bin/getent" <<'SH'
#!/usr/bin/env bash
if [[ "${MOCK_DNS:-yes}" == yes ]]; then printf '192.0.2.2 STREAM example.com\n'; else exit 2; fi
SH
cat > "$work/bin/curl" <<'SH'
#!/usr/bin/env bash
printf '%s' "${MOCK_HTTP:-200}"
exit "${MOCK_CURL_EXIT:-0}"
SH
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH"
tests=0
run() {
    local expected="$1" pattern="$2" status=0
    shift 2
    bash "$root/netcheck.sh" "$@" > "$work/output" 2>&1 || status=$?
    if [[ "$status" != "$expected" ]] || ! grep -q -- "$pattern" "$work/output"; then
        printf 'FAIL expected exit=%s pattern=%s got exit=%s\n' "$expected" "$pattern" "$status"
        cat "$work/output"; exit 1
    fi
    tests=$((tests + 1))
}
run 0 '3 passed, 0 warnings' --target example.com
run 0 '4 passed, 0 warnings' --https
MOCK_DNS=no run 1 'did not resolve' --target example.com
MOCK_ROUTE=no run 1 'No default route' --target example.com
MOCK_LINK=down run 1 'No non-loopback' --target example.com
MOCK_HTTP=503 run 1 'HTTP 503' --https
MOCK_CURL_EXIT=60 run 1 'TLS verification' --https
run 2 'Target must be' --target 'https://example.com/'
run 2 'Missing value' --target
run 2 'Invalid hostname' --target 'bad..example'
run 0 'Report saved' --report "$work/report.txt"
[[ -s "$work/report.txt" ]]
run 2 'Cannot create report' --report "$work/report.txt"
printf 'PASS: %d scenarios; no network requests made\n' "$tests"
