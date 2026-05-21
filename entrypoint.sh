#!/usr/bin/env bash
set -euo pipefail

sub="${INPUT_SUBCOMMAND:-validate}"
case "$sub" in
  validate|convert) ;;
  *) echo "roas-action: unknown subcommand: $sub" >&2; exit 2 ;;
esac

if [[ -z "${INPUT_FILE:-}" ]]; then
  echo "roas-action: 'file' input is required" >&2
  exit 2
fi

args=("$sub")

[[ -n "${INPUT_FROM:-}"   ]] && args+=(--from "$INPUT_FROM")
[[ -n "${INPUT_FORMAT:-}" ]] && args+=(--format "$INPUT_FORMAT")

if [[ "$sub" == "convert" ]]; then
  if [[ -z "${INPUT_TO:-}" ]]; then
    echo "roas-action: 'to' is required when subcommand=convert" >&2
    exit 2
  fi
  args+=(--to "$INPUT_TO")
  [[ -n "${INPUT_OUTPUT_FORMAT:-}" ]] && args+=(--output-format "$INPUT_OUTPUT_FORMAT")
  while IFS= read -r v; do
    [[ -n "$v" ]] && args+=(--merge "$v")
  done <<< "${INPUT_MERGE:-}"
  for v in ${INPUT_MERGE_OPTIONS:-}; do args+=(--merge-option "$v"); done
  if [[ "${INPUT_COLLAPSE:-false}" == "true" ]]; then
    args+=(--collapse)
    for v in ${INPUT_LOAD:-}; do args+=(--load "$v"); done
  fi
fi

if [[ "$sub" == "validate" ]]; then
  for v in ${INPUT_LOAD:-};   do args+=(--load   "$v"); done
  for v in ${INPUT_IGNORE:-}; do args+=(--ignore "$v"); done
  [[ "${INPUT_PRINT:-false}" == "true" ]] && args+=(--print)
fi

args+=("$INPUT_FILE")

if [[ -n "${INPUT_OUTPUT_FILE:-}" ]]; then
  exec /usr/local/bin/roas "${args[@]}" > "$INPUT_OUTPUT_FILE"
else
  exec /usr/local/bin/roas "${args[@]}"
fi
