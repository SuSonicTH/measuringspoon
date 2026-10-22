# Tools

Standalone helper scripts for this project. They are plain Python/shell files
with no project virtualenv: Python dependencies are declared inline (PEP 723)
and installed in `uv`'s cache on first use.

## Requirements

- Python 3.10 or newer (provided by `uv` if needed)
- [`uv`](https://docs.astral.sh/uv/) on `PATH`
- Network access on first run, while `uv` downloads the dependencies
- The fonts used by the stylesheet: Liberation Sans for body text and a
  monospace font such as Noto Sans Mono or DejaVu Sans Mono. Fontconfig
  substitutes equivalents if they are missing.

## Markdown → PDF: `md2pdf.py`

Renders a Markdown document to a print-friendly PDF. It supports CommonMark
plus GitHub-style tables and strikethrough, passes through raw HTML, and
resolves relative image paths against the Markdown file's directory. That
means a document such as the repository `README.md` can reference
`render/*.png` from any working directory.

### Usage

```bash
./tools/md2pdf.py README.md
./tools/md2pdf.py README.md -o build/README.pdf
./tools/md2pdf.py README.md --paper Letter --css print.css
cat README.md | ./tools/md2pdf.py - -o README.pdf
```

The equivalent explicit form, if the executable bit is not set:

```bash
uv run tools/md2pdf.py README.md
```

### Options

| Option | Description |
|---|---|
| `input` | Markdown file to render, or `-` to read from standard input |
| `-o`, `--output FILE` | Output PDF path. Defaults to the input name with a `.pdf` extension (required with `-`) |
| `--title TEXT` | Document title. Defaults to the first `#` heading, then the input filename |
| `--paper a4\|letter` | Paper size. Defaults to A4 |
| `--css FILE` | Extra CSS appended after the built-in print styles. May be repeated |
| `--debug` | Print a traceback if rendering fails |
| `--version` | Print the script version |
| `-h`, `--help` | Show full help |

### Output and styling

- A4 by default, with page numbers in the footer and room for binding.
- Liberation Sans body text, monospace code, bordered tables with repeating
  headers, and page-break rules that keep headings with their content and
  avoid splitting images, tables and code blocks.
- Relative images are embedded in the PDF; images are scaled to the page or
  table cell without distortion.
- The PDF title is taken from the document heading.
- Output directories are created automatically.

Use `--css` for project-specific changes, for example:

```css
body { font-size: 11pt; }
h2 { color: #7a1f1f; }
```

First run downloads `weasyprint` and `markdown-it-py` into the `uv` cache;
later runs start immediately and work offline.

## Build the manual: `build-manual.sh`

Renders the repository's top-level `README.md` to `Manual.pdf` in the repository
root, regardless of the current working directory:

```bash
./tools/build-manual.sh
```

Extra arguments are passed through to `md2pdf.py`:

```bash
./tools/build-manual.sh --paper Letter
./tools/build-manual.sh --css tools/manual.css
```

Output:

```
<repository root>/Manual.pdf
```

To inspect the generated PDF, open it in any PDF viewer. Remove it or add it to
`.gitignore` if generated artifacts should not be committed.
