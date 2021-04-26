#!/bin/bash

usage() {
    echo "Usage:"
    echo "   ./enrich.sh IP [BLUEPRINT_PROCESSOR_PORT] [CBA_PATH] [DD_PATH]"
    echo
    echo "Parameters:"
    echo "IP - ip of the k8s instance"
    echo "BLUEPRINT_PROCESSOR_PORT (default 30499) - exposed cds-blueprints-processor-http service port"
    echo "CBA_PATH (default ./oran-sim-cba) - path for folder with CBA"
    echo "DD_PATH (default ./oran-sim-cba-data-dictionary) - path for folder with DD required to execute the enrichment"
    echo
    echo "Environment variables respected:"
    echo "ENABLE_PUBLISHING - if set to 1, script will also try to upload CBA to CDS after successful enrichment."
    echo "  Use only if you're sure what you're doing"
    echo "SKIP_BOOTSTRAP - if set to 1, script won't try to 'bootstrap' CDS for enrichment (operation needed just once per lifecycle of CDS instance)."
    echo "SKIP_DD_UPLOAD - if set to 1, script won't try to upload DataDictionary files."
    echo "  This can be used to speed up a bit subsequent attempts to enrich when there were no changes to Data Dictionary files in the meantime."
    exit 1
}

# Wrapper function log messages
log() {
  echo -e "$L_GREEN$*$L_RESET" >&2
}


# Curl wrapper with improved error handling and embed generic flags
# Safe to use with -o and -f (muted)
cds_curl() {
  local res code preserve_res
  declare -a cmd=(curl -sS -H 'Authorization: Basic Y2NzZGthcHBzOmNjc2RrYXBwcw==' -w "%{http_code}")
  res=$(mktemp)
  cmd+=(-o "${res}")

  while test $# -gt 0; do
    case "$1" in
      -f|--fail)
        shift
        ;;
      -o)
        preserve_res="$2"
        shift 2
        ;;
      --output)
        preserve_res="${1##*=}"
        shift
        ;;
      *)
        cmd+=("$1")
        shift
        ;;
    esac
  done


  log "Running: $L_BOLD'${cmd[*]}'"
  if ! code="$("${cmd[@]}")"; then
    log "Curl Failure: '$code'; body:"
    cat "$res"
    rm -f "$res"
    return 1
  fi
  if ! [[ "${code}" =~ 20* ]]; then
    log "Remote responded with code $code; body:"
    cat "$res"
    rm -f "$res"
    return 1
  fi
  if test -n "${preserve_res:-}"; then
    mv "$res" "$preserve_res"
  else
    cat "$res"
    rm -f "$res"
  fi
}

if test -t 1 && test -t 2; then
  L_BOLD=$(tput bold)
  L_GREEN=$(tput setaf 2)
  L_RESET=$(tput sgr0)
else
  L_BOLD=
  L_GREEN=
  L_RESET=
fi

IP=$1
if [ -z "${IP}" ]; then
  usage
fi

set -euo pipefail

# SINCE FRANKFURT RELEASE THE BLUEPRINT_PROCESSOR POD SERVICE MUST BE EXPOSED
DEFAULT_PROCESSOR_PORT=30499
BLUEPRINT_PROCESSOR_PORT="${2:-$DEFAULT_PROCESSOR_PORT}"
BLUEPRINT_PROCESSOR_URI=http://${IP}:${BLUEPRINT_PROCESSOR_PORT}

URL_BOOTSTRAP=${BLUEPRINT_PROCESSOR_URI}/api/v1/blueprint-model/bootstrap
URL_ENRICH=${BLUEPRINT_PROCESSOR_URI}/api/v1/blueprint-model/enrich
URL_PUBLISH=${BLUEPRINT_PROCESSOR_URI}/api/v1/blueprint-model/publish
URL_DD=${BLUEPRINT_PROCESSOR_URI}/api/v1/dictionary

CBA_PATH="${3:-./oran-sim-cba}"
DD_PATH="${4:-./oran-sim-cba-data-dictionary}"

CBA_FILE=tmp/cba.zip
CBA_ENRICHED_FILE=tmp/cba_enriched.zip

CBA_ZIP=${CBA_PATH}/${CBA_FILE}
CBA_ZIP_ENRICHED=${CBA_PATH}/${CBA_ENRICHED_FILE}

if [ "${SKIP_BOOTSTRAP:-0}" == "1" ]; then
  log "Skipping Bootstrap."
else
  log "Bootstraping CDS..."
  cds_curl -X POST "$URL_BOOTSTRAP" -H 'Content-Type: application/json' \
    -d '{ "loadModelType": true, "loadResourceDictionary": true, "loadCBA": false }'
  log "Success"
fi
log "\n"

if [ "${SKIP_DD_UPLOAD:-0}" == "1" ]; then
  log "Skipping Data Dictionary upload."
else
  for f in "$DD_PATH"/*.json; do
    log "Pushing data dictionary '$f'"
    cds_curl -X POST "$URL_DD" -H 'Content-Type: application/json' -d "@$f"
    log
  done
fi
log "\n"


[ ! -d "$(dirname "$CBA_ZIP")" ] && mkdir -p "$(dirname "$CBA_ZIP")"
[ -f "$CBA_ZIP" ] && rm "$CBA_ZIP"
[ -f "$CBA_ZIP_ENRICHED" ] && rm "$CBA_ZIP_ENRICHED"

pushd "$CBA_PATH" || exit
zip -uqr $CBA_FILE . --exclude=*.git*
popd || exit

log "Doing enrichment..."
file "$CBA_ZIP"
cds_curl -X POST "$URL_ENRICH" -H 'Content-Type: multipart/form-data' -F file=@"$CBA_ZIP" -o "$CBA_ZIP_ENRICHED"
file "$CBA_ZIP_ENRICHED"
log "Success"
log "\n"

if [ "${ENABLE_PUBLISHING:-0}" == "1" ]; then
  log "Publishing..."
  cds_curl -X POST "$URL_PUBLISH" -H 'Content-Type: multipart/form-data' -F file=@"$CBA_ZIP_ENRICHED"
  log
  log "Success"
else
  log "Publishing skipped. Enable by calling script with environment variable ENABLE_PUBLISHING=1"
fi
