#!/usr/bin/env bash
# Read-only network diagnostics. Bash 4.2+, Linux, coreutils timeout.
set -u
set -o pipefail

target='example.com'
https=0
report=''
warns=0
skips=0
passes=0

usage() {
    printf '%s\n' 'Linux Network Doctor' \
        'Usage: bash netcheck.sh [--target HOST] [--https] [--report NEW_FILE]' \
        'Checks: active interfaces, IPv4 default route, and system name resolution.' \
        '--https adds a verified HTTPS GET to the single selected host.' \
        'No settings are changed. The default target is example.com.' \
        'Exit: 0 checks passed; 1 issue detected; 2 invalid input/incomplete checks.'
}

while (($#)); do
    case "$1" in
        --target|--report)
            if (($# < 2)) || [[ "$2" == --* ]]; then
                printf 'Missing value for %s\n' "$1" >&2; exit 2
            fi
            if [[ "$1" == '--target' ]]; then target="$2"; else report="$2"; fi
            shift 2 ;;
        --https) https=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

# Accept ASCII DNS names and IPv4-shaped targets; reject URLs, ports and options.
if ((${#target} > 253)) || [[ ! "$target" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
    printf 'Target must be an ASCII hostname or IPv4 address, without URL or port.\n' >&2
    exit 2
fi
IFS='.' read -r -a labels <<< "$target"
for label in "${labels[@]}"; do
    if [[ -z "$label" || ${#label} -gt 63 || "$label" == -* || "$label" == *- ]]; then
        printf 'Invalid hostname label.\n' >&2; exit 2
    fi
done
if ! command -v timeout >/dev/null 2>&1; then
    printf 'Missing coreutils timeout; checks cannot run with bounded waits.\n' >&2
    exit 2
fi

result() {
    local state="$1" name="$2" detail="$3"
    printf '[%-4s] %-20s %s\n' "$state" "$name" "$detail"
    case "$state" in
        PASS) passes=$((passes + 1)) ;;
        WARN) warns=$((warns + 1)) ;;
        SKIP) skips=$((skips + 1)) ;;
    esac
}

check_interfaces() {
    local output code line found=0
    if ! command -v ip >/dev/null 2>&1; then
        result SKIP 'Interfaces' 'ip command missing (iproute2/iproute).'; return
    fi
    output=$(timeout 5s ip -o link show up 2>/dev/null); code=$?
    if ((code != 0)); then
        result WARN 'Interfaces' "Inspection failed or timed out (exit $code)."; return
    fi
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[0-9]+:[[:space:]]+lo: ]] && continue
        found=$((found + 1))
    done <<< "$output"
    if ((found)); then
        result PASS 'Interfaces' "$found non-loopback interface(s) administratively up; this does not prove carrier or connectivity."
    else
        result WARN 'Interfaces' 'No non-loopback interfaces are administratively up.'
    fi
}

check_route() {
    local output code
    if ! command -v ip >/dev/null 2>&1; then
        result SKIP 'IPv4 default route' 'ip command missing.'; return
    fi
    output=$(timeout 5s ip -4 route show default 2>/dev/null); code=$?
    if ((code != 0)); then
        result WARN 'IPv4 default route' "Inspection failed or timed out (exit $code)."
    elif [[ -n "$output" ]]; then
        result PASS 'IPv4 default route' 'A default route exists in the main table; reachability is not proven.'
    else
        result WARN 'IPv4 default route' 'No default route in the main IPv4 table. IPv6-only or policy-routed hosts may still work.'
    fi
}

check_resolution() {
    local output code
    if ! command -v getent >/dev/null 2>&1; then
        result SKIP 'Name resolution' 'getent command missing.'; return
    fi
    output=$(timeout 8s getent ahostsv4 "$target" 2>/dev/null); code=$?
    if ((code == 0)) && [[ -n "$output" ]]; then
        result PASS 'Name resolution' "$target resolved to IPv4 using the system resolver."
    else
        result WARN 'Name resolution' "$target did not resolve to IPv4 (exit $code). Check resolver settings; numeric targets do not test DNS."
    fi
}

check_https() {
    local output code
    if ! command -v curl >/dev/null 2>&1; then
        result SKIP 'HTTPS' 'curl command missing.'; return
    fi
    # --disable ignores .curlrc. No redirects, no TLS bypass, no user credentials.
    output=$(timeout 12s curl --disable --silent --output /dev/null \
        --write-out '%{http_code}' --connect-timeout 4 --max-time 10 \
        --proto '=https' --noproxy '*' -- "https://$target/" 2>/dev/null); code=$?
    if ((code != 0)); then
        result WARN 'HTTPS' "Connection, TLS verification, or transfer failed (exit $code). Direct access may be blocked on proxy-only networks."
    elif [[ "$output" =~ ^[23][0-9][0-9]$ ]]; then
        result PASS 'HTTPS' "Verified TLS and received HTTP $output; redirects were not followed."
    else
        result WARN 'HTTPS' "Server returned HTTP $output. An HTTP error is not proof of a network failure."
    fi
}

run_report() {
    printf 'LINUX NETWORK DOCTOR\n'
    printf 'Captured: %(%Y-%m-%dT%H:%M:%S%z)T\n' -1
    printf 'Target: %s | HTTPS: %s\n\n' "$target" "$https"
    check_interfaces
    check_route
    check_resolution
    if ((https)); then check_https; fi
    printf '\nSummary: %d passed, %d warnings, %d skipped.\n' "$passes" "$warns" "$skips"
    printf 'Read-only checks; no configuration was changed.\n'
    if ((warns)); then return 1; fi
    if ((skips)); then return 2; fi
    return 0
}

if [[ -n "$report" ]]; then
    # Refuse existing files/symlinks; only create new files with private permissions.
    umask 077
    set -o noclobber
    if ! { exec 3> "$report"; }; then
        printf 'Cannot create report; choose a new writable filename.\n' >&2; exit 2
    fi
    run_report >&3; status=$?
    exec 3>&-
    printf 'Report saved: %s\n' "$report"
    exit "$status"
fi
run_report
