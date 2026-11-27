#!/usr/bin/env bash
# Monitoring platform health check for NSSA 320 Group 3.
#
# Run from the RHEL control node as an authorized operator whose SSH config
# defines the g3-monitor and g3-client aliases (see handoff Section 5.2).
#
#   ./tests/health_check.sh
#   ./tests/health_check.sh | tee docs/evidence/health-check-$(date -u +%Y%m%dT%H%M%SZ).txt
#
# Exit status: 0 if every check passes, 1 if any check fails.
# Override hosts or expectations with environment variables if needed:
#   MONITOR_HOST, CLIENT_HOST, EXPECTED_TARGETS, ALERT_NAME

set -uo pipefail

MONITOR_HOST="${MONITOR_HOST:-g3-monitor}"
CLIENT_HOST="${CLIENT_HOST:-g3-client}"
EXPECTED_TARGETS="${EXPECTED_TARGETS:-3}"
ALERT_NAME="${ALERT_NAME:-NodeExporterDown}"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10)

failures=0

pass() { printf '[PASS] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1"; failures=$((failures + 1)); }
warn() { printf '[WARN] %s\n' "$1"; }

remote() {
    local host="$1"; shift
    ssh "${SSH_OPTS[@]}" "$host" "$@"
}

echo "NSSA320 Group 3 health check - $(date -u +%FT%TZ)"
echo "Monitor: $MONITOR_HOST   Client: $CLIENT_HOST"
echo

# 1. SSH reachability
for host in "$MONITOR_HOST" "$CLIENT_HOST"; do
    if remote "$host" true >/dev/null 2>&1; then
        pass "SSH reachable: $host"
    else
        fail "SSH unreachable: $host (remaining checks for it will fail)"
    fi
done

# 2. systemd services
check_service() {
    local host="$1" svc="$2" state
    state="$(remote "$host" systemctl is-active "$svc" 2>/dev/null)"
    if [[ "$state" == "active" ]]; then
        pass "$host: $svc is active"
    else
        fail "$host: $svc is '${state:-unknown}'"
    fi
}

for svc in prometheus prometheus-node-exporter grafana-server; do
    check_service "$MONITOR_HOST" "$svc"
done
check_service "$CLIENT_HOST" prometheus-node-exporter

# 3. Prometheus and Grafana health endpoints (loopback-only on the monitor)
if remote "$MONITOR_HOST" curl -fsS --max-time 10 http://127.0.0.1:9090/-/healthy >/dev/null 2>&1; then
    pass "Prometheus /-/healthy responded"
else
    fail "Prometheus /-/healthy did not respond"
fi

grafana_db="$(remote "$MONITOR_HOST" curl -fsS --max-time 10 http://127.0.0.1:3000/api/health 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("database",""))' 2>/dev/null)"
if [[ "$grafana_db" == "ok" ]]; then
    pass "Grafana /api/health database=ok"
else
    fail "Grafana /api/health database='${grafana_db:-no response}'"
fi

# 4. Prometheus scrape targets: all must be up, and count must match
targets_json="$(remote "$MONITOR_HOST" curl -fsS --max-time 10 http://127.0.0.1:9090/api/v1/targets 2>/dev/null)"
if [[ -z "$targets_json" ]]; then
    fail "Could not read Prometheus targets API"
else
    target_report="$(python3 -c '
import json, sys
data = json.load(sys.stdin)["data"]["activeTargets"]
up = 0
for t in data:
    health = t.get("health", "unknown")
    if health == "up":
        up += 1
    print("TARGET {} {} {}".format(t["labels"].get("job", "?"), t["labels"].get("instance", "?"), health))
print("SUMMARY {} {}".format(len(data), up))
' <<<"$targets_json" 2>/dev/null)"

    if [[ -z "$target_report" ]]; then
        fail "Could not parse Prometheus targets API response"
    else
        while read -r _ job instance health; do
            if [[ "$health" == "up" ]]; then
                pass "Target up: job=$job instance=$instance"
            else
                fail "Target $health: job=$job instance=$instance"
            fi
        done < <(grep '^TARGET ' <<<"$target_report")

        read -r _ total up < <(grep '^SUMMARY ' <<<"$target_report")
        if [[ "$total" -eq "$EXPECTED_TARGETS" ]]; then
            pass "Target count: $total (expected $EXPECTED_TARGETS)"
        else
            fail "Target count: $total (expected $EXPECTED_TARGETS)"
        fi
    fi
fi

# 5. Alert rule loaded, healthy, and not firing under normal conditions
rules_json="$(remote "$MONITOR_HOST" curl -fsS --max-time 10 http://127.0.0.1:9090/api/v1/rules 2>/dev/null)"
rule_info="$(ALERT_NAME="$ALERT_NAME" python3 -c '
import json, os, sys
name = os.environ["ALERT_NAME"]
for group in json.load(sys.stdin)["data"]["groups"]:
    for rule in group.get("rules", []):
        if rule.get("type") == "alerting" and rule.get("name") == name:
            print(rule.get("health", "unknown"), rule.get("state", "unknown"))
            sys.exit(0)
print("missing missing")
' <<<"$rules_json" 2>/dev/null)"

read -r rule_health rule_state <<<"${rule_info:-missing missing}"
if [[ "$rule_health" == "missing" ]]; then
    fail "Alert rule $ALERT_NAME is not loaded"
elif [[ "$rule_health" != "ok" ]]; then
    fail "Alert rule $ALERT_NAME health=$rule_health"
else
    pass "Alert rule $ALERT_NAME loaded (health=ok)"
    if [[ "$rule_state" == "inactive" ]]; then
        pass "Alert $ALERT_NAME is inactive"
    else
        warn "Alert $ALERT_NAME is $rule_state (expected inactive outside an outage test)"
    fi
fi

echo
if [[ "$failures" -eq 0 ]]; then
    echo "RESULT: HEALTHY - all checks passed"
    exit 0
else
    echo "RESULT: UNHEALTHY - $failures check(s) failed"
    exit 1
fi
