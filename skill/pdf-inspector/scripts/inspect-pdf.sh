#!/bin/sh
# SPDX-License-Identifier: 0BSD

set -eu

usage() {
  printf '%s\n' 'Usage: inspect-pdf.sh PDF [--markdown-out FILE] [--items-out FILE] [--select-pages SPEC] [--force]'
}

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

find_tool() {
  tool_name=$1
  if [ -n "${PDF_INSPECTOR_BIN_DIR-}" ] && [ -x "$PDF_INSPECTOR_BIN_DIR/$tool_name" ]; then
    printf '%s\n' "$PDF_INSPECTOR_BIN_DIR/$tool_name"
  elif command -v "$tool_name" >/dev/null 2>&1; then
    command -v "$tool_name"
  elif [ -n "${HOME-}" ] && [ -x "$HOME/.cargo/bin/$tool_name" ]; then
    printf '%s\n' "$HOME/.cargo/bin/$tool_name"
  else
    fail "$tool_name is unavailable. Install with: cargo install --git https://github.com/firecrawl/pdf-inspector.git --rev a15ec2d68d51dbe6a39d1da688ec7a3f642d846c pdf-inspector --locked"
  fi
}

require_output_path() {
  output_path=$1
  output_label=$2
  output_parent=$(dirname "$output_path")
  [ -d "$output_parent" ] || fail "$output_label parent directory does not exist: $output_parent"
  if [ -e "$output_path" ] && [ "$force" -ne 1 ]; then
    fail "$output_label already exists; pass --force to replace it: $output_path"
  fi
}

[ "$#" -ge 1 ] || {
  usage >&2
  exit 2
}

pdf_path=$1
shift
markdown_out=''
items_out=''
page_spec=''
force=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --markdown-out)
      [ "$#" -ge 2 ] || fail '--markdown-out requires a file path.'
      markdown_out=$2
      shift 2
      ;;
    --items-out)
      [ "$#" -ge 2 ] || fail '--items-out requires a file path.'
      items_out=$2
      shift 2
      ;;
    --select-pages)
      [ "$#" -ge 2 ] || fail '--select-pages requires a page specification.'
      page_spec=$2
      shift 2
      ;;
    --force)
      force=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

[ -f "$pdf_path" ] || fail "PDF is not a regular file: $pdf_path"
case "$pdf_path" in
  *.pdf|*.PDF) ;;
  *) fail "input must have a .pdf extension: $pdf_path" ;;
esac

detect_pdf=$(find_tool detect-pdf)
pdf2md=$(find_tool pdf2md)
command -v jq >/dev/null 2>&1 || fail 'jq is required.'

tmp_base=${TMPDIR:-/tmp}
case "$tmp_base" in
  /*) ;;
  *) tmp_base=/tmp ;;
esac
tmp_dir=$(mktemp -d "$tmp_base/pdf-inspector-skill.XXXXXX") || fail 'could not create a temporary directory.'

cleanup() {
  case "$tmp_dir" in
    "$tmp_base"/pdf-inspector-skill.*) rm -rf "$tmp_dir" ;;
    *) printf '%s\n' 'ERROR: refusing cleanup of an unexpected temporary directory.' >&2 ;;
  esac
}
trap cleanup 0 HUP INT TERM

classification_file=$tmp_dir/classification.json
analysis_file=$tmp_dir/analysis.json

"$detect_pdf" "$pdf_path" --json > "$classification_file"
"$detect_pdf" "$pdf_path" --analyze --json > "$analysis_file"
jq -e 'type == "object" and (.error | not)' "$classification_file" >/dev/null || fail 'classification did not return valid JSON.'
jq -e 'type == "object" and (.error | not)' "$analysis_file" >/dev/null || fail 'layout analysis did not return valid JSON.'

if [ -n "$markdown_out" ]; then
  require_output_path "$markdown_out" 'Markdown output'
  pdf_type=$(jq -r '.pdf_type' "$classification_file")
  if [ -z "$page_spec" ] && { [ "$pdf_type" = 'scanned' ] || [ "$pdf_type" = 'image_based' ]; }; then
    fail "native Markdown is unavailable for a $pdf_type PDF; route the reported pages to OCR."
  fi
  set -- "$pdf_path" "$markdown_out" --compact --pages
  if [ -n "$page_spec" ]; then
    set -- "$@" --select-pages "$page_spec"
  fi
  markdown_stderr=$tmp_dir/markdown.stderr
  if ! "$pdf2md" "$@" >/dev/null 2> "$markdown_stderr"; then
    sed -n '1,20p' "$markdown_stderr" >&2
    fail 'native Markdown extraction failed.'
  fi
  [ -s "$markdown_out" ] || fail 'native Markdown extraction produced no output.'
fi

if [ -n "$items_out" ]; then
  require_output_path "$items_out" 'Items output'
  set -- "$pdf_path" --items-json
  if [ -n "$page_spec" ]; then
    set -- "$@" --select-pages "$page_spec"
  fi
  items_stderr=$tmp_dir/items.stderr
  if ! "$pdf2md" "$@" > "$items_out" 2> "$items_stderr"; then
    sed -n '1,20p' "$items_stderr" >&2
    fail 'positioned-item extraction failed.'
  fi
  jq -e 'type == "object" and has("items")' "$items_out" >/dev/null || fail 'positioned-item extraction did not return valid JSON.'
fi

jq -cs \
  --arg source "$pdf_path" \
  --arg markdown "$markdown_out" \
  --arg items "$items_out" \
  '.[0] * .[1] + {
    source: $source,
    markdown_output: (if $markdown == "" then null else $markdown end),
    items_output: (if $items == "" then null else $items end)
  }' \
  "$classification_file" "$analysis_file"
