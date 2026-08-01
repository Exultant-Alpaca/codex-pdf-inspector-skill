---
name: pdf-inspector
description: Classify local PDF files as text-based, scanned, image-based, or mixed; identify pages that need OCR; detect tables, columns, and encoding problems; and extract reliable native text as compact Markdown or positioned-item JSON. Use only when the user explicitly invokes $pdf-inspector for PDF triage, extraction diagnostics, OCR routing, large-PDF inspection, or structured local text extraction.
---

# PDF Inspector

Use Firecrawl's local `pdf-inspector` CLI as a fast structural first pass. Do not send PDF contents to a network service. This tool does not perform OCR.

## Run the inspection

Resolve this skill directory from the loaded `SKILL.md`, then run:

```sh
sh <skill-dir>/scripts/inspect-pdf.sh /absolute/path/document.pdf
```

The wrapper returns one compact JSON object that combines classification and layout analysis. Report:

- `pdf_type`, `confidence`, and `page_count`
- `pages_needing_ocr` and `ocr_reasons_by_page`
- `pages_with_tables`, `pages_with_columns`, and `is_complex`
- `pages_recommended_for_visual_review` and `warnings`
- `has_encoding_issues` when the installed CLI exposes it

Treat page numbers emitted by the CLI as authoritative. Do not infer missing pages or claim that scanned content was read.

## Extract Markdown

Write Markdown only when the user asks for extraction or when it is needed for the requested analysis:

```sh
sh <skill-dir>/scripts/inspect-pdf.sh /absolute/path/document.pdf \
  --markdown-out /absolute/path/document.md
```

Use `--select-pages 1,3,5-10` for a bounded page set. The wrapper enables compact output and page markers by default. It refuses to overwrite an existing output unless `--force` is present.

After extraction, inspect the saved Markdown. Do not treat malformed, empty, or OCR-required pages as reliable text. Preserve the source PDF.

Check `markdown_integrity` in the wrapper result. If `complete` is false, report the named `missing_pages` or `unexpected_pages`. Do not trust page boundaries for those pages. Route missing pages and table pages to visual review. Native text extraction can omit cells that are stored as images or drawing instructions.

## Extract positioned items

Use positioned-item JSON only when coordinates, fonts, emphasis, underlines, links, or region planning are relevant:

```sh
sh <skill-dir>/scripts/inspect-pdf.sh /absolute/path/document.pdf \
  --items-out /absolute/path/items.json \
  --select-pages 1-3
```

Positioned items can be large. Save them to a file and query the needed fields with `jq`; do not print the complete file into chat.

## Route the result

- For reliable native text, use the extracted Markdown.
- For scanned or image-based pages, report that OCR is required and use an OCR-capable or visual PDF workflow only when the user requested the content.
- For mixed PDFs, use native extraction for reliable pages and route only the named pages to OCR.
- For visual layout, forms, rendering, or final appearance verification, use the installed `pdf:pdf` skill.
- For pages in `pages_recommended_for_visual_review`, compare the native extraction with a rendered page before using tables, columns, plots, or exact page citations.
- For password-protected files, do not place a password in logs or chat. The wrapper does not accept passwords; use a separately approved secure workflow.

## Dependency

Require both `detect-pdf` and `pdf2md`. The wrapper checks `PATH`, then `$HOME/.cargo/bin`, or an explicit `PDF_INSPECTOR_BIN_DIR`. If they are missing, stop and report this installation command:

```sh
cargo install --git https://github.com/firecrawl/pdf-inspector.git --rev a15ec2d68d51dbe6a39d1da688ec7a3f642d846c pdf-inspector --locked
```

Do not install or update dependencies during ordinary skill use unless the user asks.
