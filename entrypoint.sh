#!/usr/bin/env bash
set -euo pipefail

sub="${INPUT_SUBCOMMAND:-validate}"
case "$sub" in
  validate|convert|"overlay validate"|"overlay convert"|"overlay apply"|"arazzo validate"|"arazzo convert"|"arazzo run"|"arazzo list"|"asyncapi validate"|"asyncapi convert") ;;
  *) echo "roas-action: unknown subcommand: $sub" >&2; exit 2 ;;
esac

if [[ -z "${INPUT_FILE:-}" ]]; then
  echo "roas-action: 'file' input is required" >&2
  exit 2
fi

# Seed argv with the (possibly two-word) subcommand, then append flags.
read -ra args <<< "$sub"

# --format applies to every command (input spec / overlay).
[[ -n "${INPUT_FORMAT:-}" ]] && args+=(--format "$INPUT_FORMAT")

case "$sub" in
  validate)
    [[ -n "${INPUT_FROM:-}" ]] && args+=(--from "$INPUT_FROM")
    for v in ${INPUT_LOAD:-};   do args+=(--load   "$v"); done
    for v in ${INPUT_IGNORE:-}; do args+=(--ignore "$v"); done
    [[ "${INPUT_PRINT:-false}" == "true" ]] && args+=(--print)
    ;;

  convert)
    if [[ -z "${INPUT_TO:-}" ]]; then
      echo "roas-action: 'to' is required when subcommand=convert" >&2
      exit 2
    fi
    args+=(--to "$INPUT_TO")
    [[ -n "${INPUT_FROM:-}" ]] && args+=(--from "$INPUT_FROM")
    [[ -n "${INPUT_OUTPUT_FORMAT:-}" ]] && args+=(--output-format "$INPUT_OUTPUT_FORMAT")
    while IFS= read -r v; do
      [[ -n "$v" ]] && args+=(--merge "$v")
    done <<< "${INPUT_MERGE:-}"
    for v in ${INPUT_MERGE_OPTIONS:-}; do args+=(--merge-option "$v"); done
    while IFS= read -r v; do
      [[ -n "$v" ]] && args+=(--apply "$v")
    done <<< "${INPUT_APPLY:-}"
    for v in ${INPUT_APPLY_OPTIONS:-}; do args+=(--apply-option "$v"); done
    if [[ "${INPUT_COLLAPSE:-false}" == "true" ]]; then
      args+=(--collapse)
      for v in ${INPUT_LOAD:-}; do args+=(--load "$v"); done
    fi
    ;;

  "overlay validate")
    for v in ${INPUT_IGNORE:-}; do args+=(--ignore "$v"); done
    [[ "${INPUT_PRINT:-false}" == "true" ]] && args+=(--print)
    ;;

  "overlay convert")
    if [[ -z "${INPUT_TO:-}" ]]; then
      echo "roas-action: 'to' is required when subcommand='overlay convert'" >&2
      exit 2
    fi
    args+=(--to "$INPUT_TO")
    [[ -n "${INPUT_OUTPUT_FORMAT:-}" ]] && args+=(--output-format "$INPUT_OUTPUT_FORMAT")
    ;;

  "overlay apply")
    if [[ -z "${INPUT_OVERLAY:-}" ]]; then
      echo "roas-action: 'overlay' is required when subcommand='overlay apply'" >&2
      exit 2
    fi
    while IFS= read -r v; do
      [[ -n "$v" ]] && args+=(--overlay "$v")
    done <<< "${INPUT_OVERLAY:-}"
    for v in ${INPUT_APPLY_OPTIONS:-}; do args+=(--apply-option "$v"); done
    [[ -n "${INPUT_OUTPUT_FORMAT:-}" ]] && args+=(--output-format "$INPUT_OUTPUT_FORMAT")
    ;;

  "arazzo validate")
    for v in ${INPUT_IGNORE:-}; do args+=(--ignore "$v"); done
    [[ "${INPUT_PRINT:-false}" == "true" ]] && args+=(--print)
    ;;

  "arazzo convert")
    if [[ -z "${INPUT_TO:-}" ]]; then
      echo "roas-action: 'to' is required when subcommand='arazzo convert'" >&2
      exit 2
    fi
    args+=(--to "$INPUT_TO")
    [[ -n "${INPUT_OUTPUT_FORMAT:-}" ]] && args+=(--output-format "$INPUT_OUTPUT_FORMAT")
    ;;

  # The one command that talks to an API rather than reading a
  # document, so it is the one with somewhere to send the requests.
  "arazzo run")
    [[ -n "${INPUT_WORKFLOW:-}" ]] && args+=(--workflow "$INPUT_WORKFLOW")
    # NAME=VALUE, NAME=PATH, NAME=URL and `Name: value` can all carry
    # spaces, so these are newline-separated rather than whitespace.
    while IFS= read -r v; do
      [[ -n "$v" ]] && args+=(--input "$v")
    done <<< "${INPUT_INPUT:-}"
    [[ -n "${INPUT_INPUTS:-}" ]] && args+=(--inputs "$INPUT_INPUTS")
    while IFS= read -r v; do
      [[ -n "$v" ]] && args+=(--source "$v")
    done <<< "${INPUT_SOURCE:-}"
    while IFS= read -r v; do
      [[ -n "$v" ]] && args+=(--base-url "$v")
    done <<< "${INPUT_BASE_URL:-}"
    while IFS= read -r v; do
      [[ -n "$v" ]] && args+=(--header "$v")
    done <<< "${INPUT_HEADER:-}"
    for v in ${INPUT_LOAD:-};   do args+=(--load   "$v"); done
    for v in ${INPUT_IGNORE:-}; do args+=(--ignore "$v"); done
    [[ -n "${INPUT_MAX_STEPS:-}" ]] && args+=(--max-steps "$INPUT_MAX_STEPS")
    [[ -n "${INPUT_OUTPUT_FORMAT:-}" ]] && args+=(--output-format "$INPUT_OUTPUT_FORMAT")
    [[ "${INPUT_QUIET:-false}" == "true" ]] && args+=(--quiet)
    ;;

  # Reads the description and says what it offers; --format is all it takes.
  "arazzo list")
    ;;

  # AsyncAPI takes --check rather than --ignore: `external-reference`
  # adds a check instead of skipping one.
  "asyncapi validate")
    for v in ${INPUT_CHECK:-}; do args+=(--check "$v"); done
    [[ "${INPUT_PRINT:-false}" == "true" ]] && args+=(--print)
    ;;

  "asyncapi convert")
    if [[ -z "${INPUT_TO:-}" ]]; then
      echo "roas-action: 'to' is required when subcommand='asyncapi convert'" >&2
      exit 2
    fi
    args+=(--to "$INPUT_TO")
    [[ -n "${INPUT_OUTPUT_FORMAT:-}" ]] && args+=(--output-format "$INPUT_OUTPUT_FORMAT")
    # 2.6 -> 3.x is lossy; the report goes to stderr, so output-file is
    # unaffected by either flag.
    [[ "${INPUT_STRICT:-false}" == "true" ]] && args+=(--strict)
    [[ "${INPUT_QUIET:-false}" == "true" ]] && args+=(--quiet)
    ;;
esac

args+=("$INPUT_FILE")

if [[ -n "${INPUT_OUTPUT_FILE:-}" ]]; then
  exec /usr/local/bin/roas "${args[@]}" > "$INPUT_OUTPUT_FILE"
else
  exec /usr/local/bin/roas "${args[@]}"
fi