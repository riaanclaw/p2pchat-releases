#!/usr/bin/env bash
# p2pchat meeting point: one command on a Linux VPS so friends can join without port forwarding.
#
#   curl -fsSL https://github.com/riaanclaw/p2pchat-releases/raw/main/install-meet.sh | sudo bash
#
# Options (after `bash -s --` when piped):
#   --relay-only          a dedicated relay box: relays traffic, introduces nobody
#   --api-port N          TCP port the app talks to (default 7380)
#   --ports A-B           UDP ports, one per community (default 4243-4342)
#   --max N               most communities this box will serve (default 50)
#   --uninstall           remove the service, the programs and the firewall rules this script added
#
# Running it again upgrades in place and keeps every community and key.
set -euo pipefail

MEET_VERSION="0.1.0"
NEBULA_VERSION="1.12.0"
RELEASES="https://github.com/riaanclaw/p2pchat-releases/releases/download"
# Pinned: a download that does not match is refused.
MEET_SHA_amd64="8cb25dcd5594991a210f0e2cf48faba92aa92413d92529b1bd28cf9ace732f48"
NEBULA_SHA_amd64="44bf6ae565cf7e5391ca49e8c5f9e3b825755c385eacf79a1f0d28a0b7d3fe51"

PREFIX=/opt/p2pchat-meet
DATA=/var/lib/p2pchat-meet
ENVFILE=/etc/p2pchat-meet.env
UNIT=/etc/systemd/system/p2pchat-meet.service
USER_NAME=p2pchat-meet

role=meet api_port=7380 ports=4243-4342 max=50 uninstall=0
while [ $# -gt 0 ]; do
  case "$1" in
    --relay-only) role=relay ;;
    --api-port) api_port="${2:?--api-port needs a number}"; shift ;;
    --ports) ports="${2:?--ports needs a range like 4243-4342}"; shift ;;
    --max) max="${2:?--max needs a number}"; shift ;;
    --uninstall) uninstall=1 ;;
    -h|--help) sed -n '2,14p' "$0" 2>/dev/null || true; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '\033[1m==> %s\033[0m\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run this as root (put sudo in front)."
[[ "$api_port" =~ ^[0-9]+$ ]] || die "--api-port must be a number."
[[ "$ports" =~ ^[0-9]+-[0-9]+$ ]] || die "--ports must look like 4243-4342."
[[ "$max" =~ ^[0-9]+$ ]] || die "--max must be a number."
has() { command -v "$1" >/dev/null 2>&1; }

ufw_on() { has ufw && ufw status 2>/dev/null | grep -q "Status: active"; }
fwd_on() { has firewall-cmd && firewall-cmd --state >/dev/null 2>&1; }

# The ports actually in use, from the installed settings when there are any.
if [ -f "$ENVFILE" ]; then
  # shellcheck disable=SC1090
  . "$ENVFILE"
  cur_api="${MEET_LISTEN##*:}" cur_ports="${MEET_PORTS:-$ports}"
fi

close_firewall() {
  local a="$1" p="$2"
  if ufw_on; then
    ufw --force delete allow "$a/tcp" >/dev/null 2>&1 || true
    ufw --force delete allow "${p/-/:}/udp" >/dev/null 2>&1 || true
  fi
  if fwd_on; then
    firewall-cmd -q --permanent --remove-port="$a/tcp" 2>/dev/null || true
    firewall-cmd -q --permanent --remove-port="$p/udp" 2>/dev/null || true
    firewall-cmd -q --reload || true
  fi
}

if [ "$uninstall" = 1 ]; then
  say "Removing the p2pchat meeting point"
  if has systemctl; then systemctl disable --now p2pchat-meet 2>/dev/null || true; fi
  rm -f "$UNIT"; has systemctl && systemctl daemon-reload || true
  close_firewall "${cur_api:-$api_port}" "${cur_ports:-$ports}"
  rm -rf "$PREFIX" "$ENVFILE"
  say "Removed. Community keys are kept in $DATA; delete that folder yourself if you no longer want them."
  exit 0
fi

case "$(uname -m)" in
  x86_64|amd64) arch=amd64 ;;
  *) die "this installer has a build for x86_64 only so far (this machine is $(uname -m))." ;;
esac
has curl || die "curl is needed."
has tar || die "tar is needed."
has sha256sum || die "sha256sum is needed."

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fetch() { curl -fsSL --retry 3 -o "$2" "$1" || die "could not download $1"; }
check() { echo "$2  $1" | sha256sum -c --quiet - || die "$(basename "$1") does not match its checksum; refusing it."; }

say "Downloading Nebula $NEBULA_VERSION and the meeting point $MEET_VERSION"
fetch "https://github.com/slackhq/nebula/releases/download/v$NEBULA_VERSION/nebula-linux-$arch.tar.gz" "$tmp/nebula.tgz"
check "$tmp/nebula.tgz" "$NEBULA_SHA_amd64"
if [ -n "${MEET_BINARY:-}" ]; then
  cp "$MEET_BINARY" "$tmp/p2pchat-meet"   # a local build, for testing this script before a release
else
  fetch "$RELEASES/meet-v$MEET_VERSION/p2pchat-meet-linux-$arch" "$tmp/p2pchat-meet"
  check "$tmp/p2pchat-meet" "$MEET_SHA_amd64"
fi
tar xzf "$tmp/nebula.tgz" -C "$tmp" nebula nebula-cert

was_running=0
if has systemctl && systemctl is-active -q p2pchat-meet 2>/dev/null; then was_running=1; systemctl stop p2pchat-meet; fi

say "Installing to $PREFIX"
id "$USER_NAME" >/dev/null 2>&1 || useradd --system --home-dir "$DATA" --shell /usr/sbin/nologin "$USER_NAME"
install -d -m 0755 "$PREFIX/bin"
install -m 0755 "$tmp/p2pchat-meet" "$tmp/nebula" "$tmp/nebula-cert" "$PREFIX/bin/"
install -d -m 0700 -o "$USER_NAME" -g "$USER_NAME" "$DATA"

# Settings: written once, so an upgrade keeps whatever was chosen the first time. Options given on a
# re-run do change them.
if [ ! -f "$ENVFILE" ] || [ "$role" != "meet" ] || [ "$api_port" != 7380 ] || [ "$ports" != 4243-4342 ] || [ "$max" != 50 ]; then
  [ -n "${cur_api:-}" ] && { [ "$cur_api" != "$api_port" ] || [ "$cur_ports" != "$ports" ]; } && close_firewall "$cur_api" "$cur_ports"
  cat > "$ENVFILE" <<EOF
MEET_LISTEN=0.0.0.0:$api_port
MEET_DATA=$DATA
MEET_NEBULA=$PREFIX/bin/nebula
MEET_NEBULA_CERT=$PREFIX/bin/nebula-cert
MEET_PORTS=$ports
MEET_MAX=$max
MEET_ROLE=$role
EOF
fi
# shellcheck disable=SC1090
. "$ENVFILE"
api_port="${MEET_LISTEN##*:}" ports="$MEET_PORTS" role="$MEET_ROLE"

cat > "$UNIT" <<EOF
[Unit]
Description=p2pchat meeting point ($role)
After=network-online.target
Wants=network-online.target

[Service]
EnvironmentFile=$ENVFILE
ExecStart=$PREFIX/bin/p2pchat-meet
User=$USER_NAME
Restart=always
RestartSec=3
# Lighthouses run without a tunnel, so nothing here needs privileges.
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=$DATA
KillMode=control-group

[Install]
WantedBy=multi-user.target
EOF

say "Opening TCP $api_port and UDP $ports"
if ufw_on; then
  ufw allow "$api_port/tcp" comment "p2pchat meeting point API" >/dev/null
  ufw allow "${ports/-/:}/udp" comment "p2pchat meeting point communities" >/dev/null
elif fwd_on; then
  firewall-cmd -q --permanent --add-port="$api_port/tcp"
  firewall-cmd -q --permanent --add-port="$ports/udp"
  firewall-cmd -q --reload
else
  echo "    No ufw or firewalld found. If this VPS has another firewall, open TCP $api_port and UDP $ports."
fi

if has systemctl && [ -d /run/systemd/system ]; then
  systemctl daemon-reload
  systemctl enable -q p2pchat-meet
  systemctl restart p2pchat-meet
  for _ in $(seq 1 20); do curl -fs "http://127.0.0.1:$api_port/v1/health" >/dev/null 2>&1 && break; sleep 0.5; done
  curl -fs "http://127.0.0.1:$api_port/v1/health" >/dev/null || die "the service did not start; see: journalctl -u p2pchat-meet"
else
  echo "    This machine has no systemd; start it with: env \$(cat $ENVFILE | xargs) $PREFIX/bin/p2pchat-meet"
fi
[ "$was_running" = 1 ] && say "Upgraded; every community was kept."

ip="$(curl -fs --max-time 5 https://api.ipify.org || hostname -I | awk '{print $1}')"
echo
if [ "$role" = relay ]; then
  say "Relay ready. In p2pchat, add this as a relay:"
else
  say "Meeting point ready. In p2pchat, paste this as the meeting point:"
fi
echo
echo "    http://$ip:$api_port"
echo
