#!/bin/sh
# SPDX-License-Identifier: 0BSD

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/pdf-inspector-test.XXXXXX")

cleanup() {
  case "$test_dir" in
    "${TMPDIR:-/tmp}"/pdf-inspector-test.*) rm -rf "$test_dir" ;;
    *) printf '%s\n' 'ERROR: refusing cleanup of an unexpected test directory.' >&2 ;;
  esac
}
trap cleanup 0 HUP INT TERM

mkdir -p "$test_dir/bin" "$test_dir/out"
touch "$test_dir/sample.pdf"

printf '%s\n' \
  '#!/bin/sh' \
  'case " $* " in' \
  "  *' --analyze '*)" \
  "    printf '%s\\n' '{\"is_complex\":true,\"pages_with_tables\":[2],\"pages_with_columns\":[3]}'" \
  '    ;;' \
  '  *)' \
  "    printf '%s\\n' '{\"pdf_type\":\"text_based\",\"page_count\":3,\"pages_needing_ocr\":[]}'" \
  '    ;;' \
  'esac' > "$test_dir/bin/detect-pdf"

printf '%s\n' \
  '#!/bin/sh' \
  "if [ \"\$2\" = '--items-json' ]; then" \
  "  printf '%s\\n' '{\"items\":[]}'" \
  '  exit 0' \
  'fi' \
  'output_path=$2' \
  "printf '%s\\n' '<!-- Page 1 -->' '' '# First page' '' '<!-- Page 3 -->' '' 'Third page' > \"\$output_path\"" > "$test_dir/bin/pdf2md"

chmod +x "$test_dir/bin/detect-pdf" "$test_dir/bin/pdf2md"

result=$(PDF_INSPECTOR_BIN_DIR="$test_dir/bin" \
  sh "$repo_dir/skill/pdf-inspector/scripts/inspect-pdf.sh" \
  "$test_dir/sample.pdf" \
  --markdown-out "$test_dir/out/sample.md")

printf '%s\n' "$result" | jq -e '
  .markdown_integrity == {
    expected_page_markers: 3,
    found_page_markers: 2,
    missing_pages: [2],
    unexpected_pages: [],
    complete: false
  }
  and .pages_recommended_for_visual_review == [2, 3]
  and (.warnings | length) == 3
' >/dev/null

selected_result=$(PDF_INSPECTOR_BIN_DIR="$test_dir/bin" \
  sh "$repo_dir/skill/pdf-inspector/scripts/inspect-pdf.sh" \
  "$test_dir/sample.pdf" \
  --markdown-out "$test_dir/out/selected.md" \
  --select-pages '1,3')

printf '%s\n' "$selected_result" | jq -e '
  .markdown_integrity == {
    expected_page_markers: 2,
    found_page_markers: 2,
    missing_pages: [],
    unexpected_pages: [],
    complete: true
  }
' >/dev/null

printf '%s\n' 'PASS: extraction integrity and visual-review routing'
