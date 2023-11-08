#!/bin/sh

ROOT_DIR=${ROOT_DIR:-"$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )"}

set -eu

# Username for the administrator at the router.
TPLINK_USERNAME=${TPLINK_USERNAME:-"admin"}

# Password for the administrator at the router. See command-line option -f to
# minimise password leakage at the host.
TPLINK_PASSWORD=${TPLINK_PASSWORD:-}

# Set this to 1 for more verbosity.
TPLINK_VERBOSE=${TPLINK_VERBOSE:-0}

# Binary/path to curl, empty to discover it
TPLINK_WEBCLI=${TPLINK_WEBCLI:-}

# Number of seconds to sleep before exiting on errors. This can be used to avoid
# ever-restarting Docker containers.
TPLINK_SLEEP=${TPLINK_SLEEP:-0}

# Start page and advanced (frame)
TPLINK_PAGE_REBOOT=userRpm/SysRebootRpm.htm

usage() {
  # This uses the comments behind the options to show the help. Not extremly
  # correct, but effective and simple.
  echo "$0 is a TP-LINK WA860RE automator:" && \
    grep "[[:space:]].)\ #" "$0" |
    sed 's/#//' |
    sed -r 's/([a-z])\)/-\1/'
  exit "${1:-0}"
}

while getopts "u:p:f:s:vh-" opt; do
  case "$opt" in
    u) # Username for administration login
      TPLINK_USERNAME=$OPTARG;;
    p) # Password for administrator user
      TPLINK_PASSWORD=$OPTARG;;
    f) # File containing password for administrator user
      TPLINK_PASSWORD=$(cat "$OPTARG");;
    s) # Number of seconds to sleep before exiting on error
      TPLINK_SLEEP=$OPTARG;;
    v) # Turn on verbosity
      TPLINK_VERBOSE=1;;
    h)
      usage;;
    -)
      break;;
    *)
      usage 1;;
  esac
done
shift $((OPTIND-1))


_verbose() {
  if [ "$TPLINK_VERBOSE" = "1" ]; then
    printf %s\\n "$1" >&2
  fi
}

_error() {
  printf %s\\n "$1" >&2
  if [ "$TPLINK_SLEEP" -gt "0" ]; then
    _verbose "Waiting $TPLINK_SLEEP sec(s). before exiting"
    sleep "$TPLINK_SLEEP"
  fi
  exit 1
}

# Discover web CLI client when none was specified
_init() {
  if [ -z "$TPLINK_WEBCLI" ]; then
    if command -v curl >&2 >/dev/null; then
      TPLINK_WEBCLI=curl
    else
      _error "Cannot find curl for Web operations"
    fi
  fi
}

_web_noauth() {
  _url=$1; shift
  _verbose "Requesting $_url"

  if printf %s\\n "$TPLINK_WEBCLI" | grep -q "curl"; then
    curl -sSL "$@" "$_url"
  else
    _error "Cannot understand type of Web CLI client at $TPLINK_WEBCLI"
  fi
}

_web() {
  _url=$1; shift
  _web_noauth "$_url" -u "${TPLINK_USERNAME}:${TPLINK_PASSWORD}" "$@"
}


reboot() {
  _page="http://${1}/$TPLINK_PAGE_REBOOT"
  _verbose "Rebooting router at $1"
  if _web "$_page?Reboot=Reboot" --header "Referer: $_page" | grep -qi 'restarting'; then
    _verbose "Router at $1 restarting"
  else
    _error "Could not restart"
  fi
}

if [ "$#" -lt "1" ]; then
  cmd=reboot
else
  cmd=$1
  shift
fi

_init
case "$cmd" in
  reboot)
    [ "$#" -lt "1" ] && _error "Need at least the local URL to a rooter"
    for router; do
      if reboot "$router"; then
        _verbose "Router at $router restarted"
      else
        _error "Could not restart router at $router"
      fi
    done
    ;;
  h*)
    usage
    ;;

  *)
    _error "$cmd is an unknown command, should be one of reboot, help"
    ;;
esac