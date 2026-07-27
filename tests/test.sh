#!/usr/bin/env bash

set -u

readonly TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly VALIDATOR="${TEST_ROOT}/src/validate.sh"

pass_count=0
fail_count=0

run_validator() {
  local output_file="$1"
  shift

  env -i \
    PATH="$PATH" \
    GITHUB_OUTPUT="$output_file" \
    "$@" \
    bash "$VALIDATOR"
}

pass() {
  pass_count=$((pass_count + 1))
  printf 'ok - %s\n' "$1"
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'not ok - %s\n' "$1"
}

assert_case() {
  local description="$1"
  local expected_status="$2"
  local expected_output="$3"
  shift 3

  local github_output
  local log_output
  local status

  github_output="$(mktemp)"
  log_output="$(mktemp)"

  run_validator "$github_output" "$@" >"$log_output" 2>&1
  status=$?

  if [[ "$status" -eq "$expected_status" ]] &&
    grep -Fq "$expected_output" "$github_output"; then
    pass "$description"
  else
    fail "$description"
    printf '  expected status: %s\n' "$expected_status"
    printf '  actual status:   %s\n' "$status"
    printf '  outputs:\n'
    sed 's/^/    /' "$github_output"
    printf '  logs:\n'
    sed 's/^/    /' "$log_output"
  fi

  rm -f "$github_output" "$log_output"
}

assert_secret_not_logged() {
  local github_output
  local log_output
  local status
  local secret_value="do-not-print-this-secret"

  github_output="$(mktemp)"
  log_output="$(mktemp)"

  run_validator "$github_output" \
    REQUIRE_ENV_VARIABLES="APP_ENV" \
    REQUIRE_ENV_SECRETS="API_TOKEN" \
    APP_ENV="production" \
    API_TOKEN="$secret_value" >"$log_output" 2>&1
  status=$?

  if [[ "$status" -eq 0 ]] &&
    ! grep -Fq "$secret_value" "$log_output" &&
    ! grep -Fq "$secret_value" "$github_output"; then
    pass "secret values are never logged or emitted"
  else
    fail "secret values are never logged or emitted"
  fi

  rm -f "$github_output" "$log_output"
}

assert_case \
  "accepts present variables and secrets" \
  0 \
  "valid=true" \
  REQUIRE_ENV_VARIABLES="APP_ENV API_URL" \
  REQUIRE_ENV_SECRETS="API_TOKEN" \
  APP_ENV="production" \
  API_URL="https://example.test" \
  API_TOKEN="token"

assert_case \
  "accepts comma and newline-separated names" \
  0 \
  "valid=true" \
  REQUIRE_ENV_VARIABLES=$'APP_ENV,API_URL\nREGION' \
  APP_ENV="production" \
  API_URL="https://example.test" \
  REGION="eu-central-1"

assert_case \
  "reports a missing variable" \
  1 \
  "missing-variables=API_URL" \
  REQUIRE_ENV_VARIABLES="APP_ENV API_URL" \
  APP_ENV="production"

assert_case \
  "reports a missing secret" \
  1 \
  "missing-secrets=API_TOKEN" \
  REQUIRE_ENV_SECRETS="API_TOKEN"

assert_case \
  "treats whitespace-only values as empty" \
  1 \
  "missing-variables=APP_ENV" \
  REQUIRE_ENV_VARIABLES="APP_ENV" \
  APP_ENV="   "

assert_case \
  "rejects invalid environment names" \
  2 \
  "valid=false" \
  REQUIRE_ENV_VARIABLES='SAFE;echo-pwned'

assert_case \
  "rejects an empty configuration" \
  2 \
  "valid=false"

assert_secret_not_logged

printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"
(( fail_count == 0 ))
