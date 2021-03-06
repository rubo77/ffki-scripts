#!/usr/bin/env bash

set -e -o pipefail

SSH_KEYFILE="$HOME/.ssh/privkey"

error() {
  ( >&2 echo $@ )
  exit 1
}

cleanup() {
  rm -f "$SSH_KEYFILE"
}

trap cleanup EXIT INT TERM

if [ -z "$HOME" ]; then
    error "HOME environment variable must be set"
fi

if [ -z "$SSH_KEY" ]; then
    error "SSH_KEY environment variable must be set"
fi

if [ -z "$GATEWAYS" ]; then
    error "GATEWAYS environment variable must be set"
fi

if [ -z "$GATEWAY_DEPLOY_USER" ]; then
    error "GATEWAY_DEPLOY_USER environment variable must be set"
fi

mkdir -p "$(dirname "$SSH_KEYFILE")"
echo "$SSH_KEY" > "$SSH_KEYFILE"
chmod 600 "$SSH_KEYFILE"

for gw in $GATEWAYS; do
  gw_host_var="GATEWAY_HOST_$gw"
  gw_host="${!gw_host_var}"
  [ -z "$gw_host" ] && gw_host="$gw"
  gw_user_var="GATEWAY_USER_$gw"
  gw_user="${!gw_user_var}"
  [ -z "$gw_user" ] && gw_user="$GATEWAY_DEPLOY_USER"
  gw_port_var="GATEWAY_PORT_$gw"
  gw_port="${!gw_port_var}"
  [ -z "$gw_port" ] && gw_port=22
  connected=''
  # Retry up to five times in case of network fuckup
  for _ in `seq 5`; do
    set +e
    # using StrictHostKeyChecking=no is fine here since we don't reveal any data to the remote host
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEYFILE" -p "$gw_port" "${gw_user}@${gw_host}" exit 1
    SSH_EXIT=$?
    set -e
    [ $SSH_EXIT -eq 0 ] && break
  done
  [ $SSH_EXIT -eq 0 ] || exit $SSH_EXIT
done
