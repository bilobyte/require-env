#!/usr/bin/env bash

set -Eeuo pipefail

readonly VARIABLE_SPEC="${REQUIRE_ENV_VARIABLES:-}"
readonly SECRET_SPEC="${REQUIRE_ENV_SECRETS:-}"

declare -a variable_names=()
declare -a secret_names=()
declare -a parsed_names=()
declare -a invalid_names=()
declare -a missing_variables=()
declare -a missing_secrets=()

parse_names() {
  local spec="$1"
  local normalized
  local name

  normalized="${spec//,/ }"
  parsed_names=()

  # Input is configuration, not shell code. Word splitting is intentional here
  # and every resulting name is validated before indirect expansion.
  read -r -a parsed_names <<< "${normalized//$'\n'/ }"

  for name in "${parsed_names[@]}"; do
    if [[ ! "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      invalid_names+=("$name")
    fi
  done
}

join_by_comma() {
  local IFS=","
  printf '%s' "$*"
}

is_missing() {
  local name="$1"
  local value

  # An unset value and an empty value are equivalent for this action.
  value="${!name-}"
  [[ -z "${value//[[:space:]]/}" ]]
}

write_outputs() {
  local valid="$1"
  local missing_variable_csv
  local missing_secret_csv

  missing_variable_csv="$(join_by_comma "${missing_variables[@]}")"
  missing_secret_csv="$(join_by_comma "${missing_secrets[@]}")"

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
      printf 'valid=%s\n' "$valid"
      printf 'missing-variables=%s\n' "$missing_variable_csv"
      printf 'missing-secrets=%s\n' "$missing_secret_csv"
    } >> "$GITHUB_OUTPUT"
  fi
}

parse_names "$VARIABLE_SPEC"
variable_names=("${parsed_names[@]}")

parse_names "$SECRET_SPEC"
secret_names=("${parsed_names[@]}")

if (( ${#variable_names[@]} == 0 && ${#secret_names[@]} == 0 )); then
  write_outputs false
  printf '%s\n' \
    "::error title=Require environment values is not configured::Set at least one name in the variables or secrets input."
  exit 2
fi

if (( ${#invalid_names[@]} > 0 )); then
  write_outputs false
  printf '%s\n' \
    "::error title=Invalid environment name::Names must match [A-Za-z_][A-Za-z0-9_]*. Invalid: $(join_by_comma "${invalid_names[@]}")"
  exit 2
fi

for name in "${variable_names[@]}"; do
  if is_missing "$name"; then
    missing_variables+=("$name")
  fi
done

for name in "${secret_names[@]}"; do
  if is_missing "$name"; then
    missing_secrets+=("$name")
  fi
done

if (( ${#missing_variables[@]} > 0 )); then
  printf '%s\n' \
    "::error title=Missing required variables::Missing or empty variables: $(join_by_comma "${missing_variables[@]}")"
fi

if (( ${#missing_secrets[@]} > 0 )); then
  printf '%s\n' \
    "::error title=Missing required secrets::Missing or empty secrets: $(join_by_comma "${missing_secrets[@]}")"
fi

if (( ${#missing_variables[@]} > 0 || ${#missing_secrets[@]} > 0 )); then
  write_outputs false
  exit 1
fi

write_outputs true
printf 'Validated %d variable(s) and %d secret(s).\n' \
  "${#variable_names[@]}" "${#secret_names[@]}"
