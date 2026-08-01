# PDF Inspector Skill for Codex

This repository contains an explicit-use Codex skill. It uses the local `pdf-inspector` command-line tools from Firecrawl.

The skill can:

- classify a PDF as text-based, scanned, image-based, or mixed;
- find pages that need OCR;
- detect tables and columns;
- extract compact Markdown from native PDF text;
- extract positioned text items as JSON; and
- refuse unsafe output replacement by default.

The skill does not perform OCR. It does not send PDF data to a network service.

## Install the dependency

Install the current Firecrawl command-line tools:

```sh
cargo install \
  --git https://github.com/firecrawl/pdf-inspector.git \
  --rev a15ec2d68d51dbe6a39d1da688ec7a3f642d846c \
  pdf-inspector \
  --locked
```

This command installs `detect-pdf` and `pdf2md` in `$HOME/.cargo/bin`.
The revision above is the version tested with this release.

## Install the skill

Clone this repository. Then copy the skill folder to your Codex skills folder:

```sh
git clone https://github.com/Exultant-Alpaca/codex-pdf-inspector-skill.git
cd codex-pdf-inspector-skill
cp -R skill/pdf-inspector "${CODEX_HOME:-$HOME/.codex}/skills/pdf-inspector"
```

Start a new Codex task after installation.

## Use the skill

The skill does not start by itself. Invoke it by name:

> Use `$pdf-inspector` to inspect this PDF, find pages that need OCR, and extract reliable native text.

## Scope

This repository contains the Codex skill instructions and a shell wrapper. It does not contain the Firecrawl parser source or binary.

Firecrawl's `pdf-inspector` project is an external dependency. It uses the MIT License. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

This project is not an official Firecrawl project.

## License

The original files in this repository use the 0BSD License. See [LICENSE](LICENSE).

The external `pdf-inspector` dependency keeps its own MIT License.
