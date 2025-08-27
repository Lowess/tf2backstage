#!/usr/bin/env bash
set -euo pipefail

# Defaults (mirror tf2backstage.j2 behavior)
OUTPUT_KEY=""
NAME=""
TYPE="terraform-output"
OWNER="devops"
SYSTEM="default"
ANN_PREFIX=""
OUTPUT_EXCLUDE_RE=""
OUTPUT_INCLUDE_RE=""
OUTPUT_OMIT_NULL=""

OUTPUT_SAFE_KEY_LENGTH="yes"
DESCRIPTION=""
COLOR=""
TAGS=""
TEMPLATE=""
CUSTOMIZE=""

INPUT_FILE=""

show_help() {
  cat <<'EOF'
tf2backstage — turn Terraform output JSON into a Backstage Resource YAML

Usage:
  # from a file, process specific output
  tf2backstage -f /work/tf-output.json -k eks -n @cluster_name -t kubernetes-cluster -o devops -s devops-nonprod -p gumgum.com --omit-null -x 'cluster_addons|kms_' > eks.yaml

  # from stdin, process specific output
  terraform -chdir=./infra output -json \
    | tf2backstage -k eks -n @cluster_name -t kubernetes-cluster -o devops -s devops-nonprod -p gumgum.com --omit-null -x 'cluster_addons|kms_' > eks.yaml

  # process all terraform outputs (no output-key specified)
  terraform output -json | tf2backstage -n "all-outputs" -t terraform-summary -o platform-team > all-terraform-outputs.yaml

Options:
  -f, --file PATH              Input Terraform JSON (if omitted, read stdin)
  -k, --output-key KEY         Key in TF output to select (e.g. eks) (if omitted, process all outputs)
      -n, --name NAME              Backstage metadata.name; literal or '@field' to read from output (e.g. @cluster_name)
  -t, --type TYPE              Backstage spec.type (default: terraform-output)
  -o, --owner OWNER            Backstage spec.owner (default: devops)
  -s, --system SYSTEM          Backstage spec.system (default: default)
  -p, --ann-prefix PREFIX      Annotations domain prefix (default: gumgum.com)
  -x, --exclude-re REGEX       Drop flattened annotation keys matching REGEX
  -i, --include-re REGEX       Only include flattened annotation keys matching REGEX
      --omit-null              Omit null values from annotations
      --safe-key-length        Truncate long keys to 63 char limit (default: enabled)
      --no-safe-key-length     Allow long annotation keys (may be rejected)
      --color                  Enable YAML syntax highlighting with yq (default: no colors)
      --tags TAGS              Comma-separated tags; literal or '@field' to read from output (default: output-key)
  -d, --description TEXT       metadata.description (default provided)
      --template PATH          Custom Jinja2 template file path
      --customize PATH         Custom customize.py file path
  -h, --help                   Show this help
EOF
}

# crude long/short flags parser
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--file)               INPUT_FILE="$2"; shift 2 ;;
    -k|--output-key)         OUTPUT_KEY="$2"; shift 2 ;;
    -n|--name)               NAME="$2"; shift 2 ;;
    -t|--type)               TYPE="$2"; shift 2 ;;
    -o|--owner)              OWNER="$2"; shift 2 ;;
    -s|--system)             SYSTEM="$2"; shift 2 ;;
    -p|--ann-prefix)         ANN_PREFIX="$2"; shift 2 ;;
    -x|--exclude-re)         OUTPUT_EXCLUDE_RE="$2"; shift 2 ;;
    -i|--include-re)         OUTPUT_INCLUDE_RE="$2"; shift 2 ;;
        --omit-null)         OUTPUT_OMIT_NULL="yes"; shift 1 ;;
        --safe-key-length)   OUTPUT_SAFE_KEY_LENGTH="yes"; shift 1 ;;
        --no-safe-key-length) OUTPUT_SAFE_KEY_LENGTH="no"; shift 1 ;;
        --color)             COLOR="yes"; shift 1 ;;
        --tags)              TAGS="$2"; shift 2 ;;
    -d|--description)        DESCRIPTION="$2"; shift 2 ;;
        --template)          TEMPLATE="$2"; shift 2 ;;
        --customize)         CUSTOMIZE="$2"; shift 2 ;;
    -h|--help)               show_help; exit 0 ;;
    --) shift; break ;;
    *) echo "Unknown option: $1" >&2; show_help; exit 2 ;;
  esac
done

# OUTPUT_KEY is now optional - if empty, process entire terraform output

# set defaults that depend on OUTPUT_KEY
if [[ -z "${ANN_PREFIX}" ]]; then
  ANN_PREFIX="gumgum.com"
fi

# export as env for the template's env() filter
# Only export DESCRIPTION if it was explicitly set
if [[ -n "${DESCRIPTION}" ]]; then
    export OUTPUT_KEY NAME TYPE OWNER SYSTEM ANN_PREFIX OUTPUT_EXCLUDE_RE OUTPUT_INCLUDE_RE OUTPUT_OMIT_NULL OUTPUT_SAFE_KEY_LENGTH DESCRIPTION TAGS
else
    export OUTPUT_KEY NAME TYPE OWNER SYSTEM ANN_PREFIX OUTPUT_EXCLUDE_RE OUTPUT_INCLUDE_RE OUTPUT_OMIT_NULL OUTPUT_SAFE_KEY_LENGTH TAGS
fi

# Find template and customize files - try script directory first, then current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default template location
if [[ -z "${TEMPLATE}" ]]; then
  if [[ -f "${SCRIPT_DIR}/tf2backstage.j2" ]]; then
    TEMPLATE="${SCRIPT_DIR}/tf2backstage.j2"
  elif [[ -f "./tf2backstage.j2" ]]; then
    TEMPLATE="./tf2backstage.j2"
  elif [[ -f "/app/tf2backstage.j2" ]]; then
    TEMPLATE="/app/tf2backstage.j2"
  else
    echo "Error: tf2backstage.j2 template not found" >&2
    exit 1
  fi
fi

# Default customize location
if [[ -z "${CUSTOMIZE}" ]]; then
  if [[ -f "${SCRIPT_DIR}/customize.py" ]]; then
    CUSTOMIZE="${SCRIPT_DIR}/customize.py"
  elif [[ -f "./customize.py" ]]; then
    CUSTOMIZE="./customize.py"
  elif [[ -f "/app/customize.py" ]]; then
    CUSTOMIZE="/app/customize.py"
  else
    echo "Error: customize.py not found" >&2
    exit 1
  fi
fi

if [[ -n "${INPUT_FILE}" ]]; then
  if [[ "${COLOR}" == "yes" ]]; then
    exec jinjanate --quiet "${TEMPLATE}" "${INPUT_FILE}" --customize "${CUSTOMIZE}" | yq -C
  else
    exec jinjanate --quiet "${TEMPLATE}" "${INPUT_FILE}" --customize "${CUSTOMIZE}"
  fi
else
  if [[ "${COLOR}" == "yes" ]]; then
    exec jinjanate --quiet --format=json "${TEMPLATE}" - --customize "${CUSTOMIZE}" | yq -C
  else
    exec jinjanate --quiet --format=json "${TEMPLATE}" - --customize "${CUSTOMIZE}"
  fi
fi
