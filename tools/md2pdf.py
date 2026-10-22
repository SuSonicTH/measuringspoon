#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "markdown-it-py>=3,<5",
#     "weasyprint>=62,<67",
# ]
# ///
"""Render a Markdown document to PDF with print-friendly styling.

Usage:
    uv run tools/md2pdf.py README.md
    uv run tools/md2pdf.py README.md -o build/README.pdf
    uv run tools/md2pdf.py README.md --paper Letter --css print.css

Relative image and link paths are resolved against the Markdown file, so a
document such as README.md can reference render/hero.png and the image is
embedded in the PDF.

The script declares its dependencies inline (PEP 723). ``uv`` installs and
caches them automatically on first use; no project virtualenv is required.
"""

from __future__ import annotations

import argparse
import html
import sys
import traceback
from pathlib import Path
from typing import Sequence

from markdown_it import MarkdownIt
from weasyprint import CSS, HTML

__version__ = "1.0.0"

BASE_CSS = """
@page {
    size: __PAPER__;
    margin: 18mm 16mm 20mm;

    @bottom-center {
        content: counter(page) " / " counter(pages);
        font-family: "Liberation Sans", "DejaVu Sans", sans-serif;
        font-size: 8pt;
        color: #777;
    }
}

html {
    font-size: 10pt;
}

body {
    margin: 0;
    font-family: "Liberation Sans", "DejaVu Sans", sans-serif;
    font-size: 10pt;
    line-height: 1.45;
    color: #222;
}

h1, h2, h3, h4, h5, h6 {
    font-family: "Liberation Sans", "DejaVu Sans", sans-serif;
    line-height: 1.2;
    color: #111;
    break-after: avoid;
}

h1 {
    margin: 0 0 0.5em;
    font-size: 24pt;
    letter-spacing: -0.01em;
}

h2 {
    margin: 1.5em 0 0.55em;
    padding-bottom: 0.15em;
    border-bottom: 0.6pt solid #d8d8d8;
    font-size: 15pt;
}

h3 {
    margin: 1.25em 0 0.45em;
    font-size: 12pt;
}

h4 {
    margin: 1.1em 0 0.4em;
    font-size: 10.5pt;
}

p {
    margin: 0 0 0.65em;
    orphans: 2;
    widows: 2;
}

ul, ol {
    margin: 0.35em 0 0.75em;
    padding-left: 1.45em;
}

li {
    margin: 0.15em 0;
}

li > p {
    margin-bottom: 0.2em;
}

a {
    color: #0b5cad;
    text-decoration: none;
}

strong {
    font-weight: bold;
}

hr {
    margin: 1.4em 0;
    border: none;
    border-top: 0.6pt solid #dcdcdc;
}

blockquote {
    margin: 0.7em 0;
    padding: 0.1em 0 0.1em 0.8em;
    border-left: 2.5pt solid #d0d0d0;
    color: #555;
    break-inside: avoid;
}

code {
    padding: 0 0.18em;
    border-radius: 2px;
    background: #f3f3f3;
    font-family: "Noto Sans Mono", "DejaVu Sans Mono", monospace;
    font-size: 0.9em;
    overflow-wrap: anywhere;
}

pre {
    margin: 0.7em 0 1em;
    padding: 8pt 10pt;
    border: 0.5pt solid #e2e2e2;
    border-radius: 3px;
    background: #f7f7f7;
    font-family: "Noto Sans Mono", "DejaVu Sans Mono", monospace;
    font-size: 8.4pt;
    line-height: 1.4;
    white-space: pre-wrap;
    overflow-wrap: anywhere;
    break-inside: avoid;
}

pre code {
    padding: 0;
    border: none;
    border-radius: 0;
    background: none;
    font-size: inherit;
    overflow-wrap: normal;
}

img {
    max-width: 100%;
    height: auto;
}

p > img {
    display: block;
    margin: 0.6em auto;
}

p[align="center"] {
    text-align: center;
}

table {
    width: 100%;
    margin: 0.6em 0 1em;
    border-collapse: collapse;
    table-layout: auto;
    font-size: 8.5pt;
    line-height: 1.35;
}

thead {
    display: table-header-group;
}

tr {
    break-inside: avoid;
}

th, td {
    padding: 4pt 5pt;
    border: 0.5pt solid #cccccc;
    vertical-align: top;
    text-align: left;
}

th {
    background: #f2f2f2;
    font-weight: bold;
}

td p {
    margin: 0;
}

td code {
    overflow-wrap: anywhere;
}

td img {
    max-width: 100%;
    max-height: 70mm;
}
"""

PAPER_SIZES = {
    "a4": "A4",
    "letter": "Letter",
}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="md2pdf",
        description="Render a Markdown file to a styled PDF.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "examples:\n"
            "  uv run tools/md2pdf.py README.md\n"
            "  uv run tools/md2pdf.py README.md -o docs/README.pdf\n"
            "  uv run tools/md2pdf.py README.md --paper Letter --css print.css\n"
            "  cat README.md | uv run tools/md2pdf.py - -o README.pdf\n"
        ),
    )
    parser.add_argument(
        "input",
        type=str,
        help="Markdown file to render, or '-' to read from stdin",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="output PDF path (default: input filename with .pdf extension)",
    )
    parser.add_argument(
        "--title",
        help="PDF/document title (default: first level-1 heading, then filename)",
    )
    parser.add_argument(
        "--paper",
        type=str.lower,
        choices=sorted(PAPER_SIZES),
        default="a4",
        help="paper size (default: a4)",
    )
    parser.add_argument(
        "--css",
        action="append",
        default=[],
        metavar="FILE",
        help="extra CSS file appended after the built-in styles (repeatable)",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="show a traceback if rendering fails",
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {__version__}",
    )
    return parser


def find_title(tokens: Sequence[object], fallback: str) -> str:
    """Return the first H1 text from parsed Markdown, or the fallback."""
    for index, token in enumerate(tokens):
        if token.type == "heading_open" and token.tag == "h1":
            if index + 1 < len(tokens):
                inline = tokens[index + 1]
                if inline.type == "inline" and inline.content.strip():
                    return inline.content.strip()
    return fallback


def read_markdown(source: str) -> tuple[str, Path, str]:
    """Return (markdown, base directory, display name)."""
    if source == "-":
        return sys.stdin.read(), Path.cwd(), "stdin"

    path = Path(source).expanduser()
    if not path.exists():
        raise FileNotFoundError(f"input file not found: {path}")
    if not path.is_file():
        raise IsADirectoryError(f"input is not a file: {path}")
    return path.read_text(encoding="utf-8"), path.resolve().parent, str(path)


def default_output(source: str) -> Path:
    if source == "-":
        raise ValueError("an output path (-o/--output) is required when reading stdin")
    path = Path(source).expanduser()
    return path.with_suffix(".pdf") if path.suffix else path.with_name(path.name + ".pdf")


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    try:
        text, base_dir, display_name = read_markdown(args.input)
        output = args.output.expanduser() if args.output else default_output(args.input)
        output = output.resolve()

        if output.suffix.lower() != ".pdf":
            raise ValueError(f"output must end in .pdf: {output}")

        output.parent.mkdir(parents=True, exist_ok=True)

        parser = MarkdownIt("commonmark", {"html": True})
        parser.enable(["table", "strikethrough"])
        tokens = parser.parse(text)
        body = parser.renderer.render(tokens, parser.options, {})

        title = args.title or find_title(tokens, Path(display_name).stem or "Document")
        document = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="generator" content="md2pdf {__version__}">
<title>{html.escape(title)}</title>
</head>
<body>
{body}
</body>
</html>
"""

        css = BASE_CSS.replace("__PAPER__", PAPER_SIZES[args.paper])
        for css_file_arg in args.css:
            css_path = Path(css_file_arg).expanduser()
            if not css_path.is_file():
                raise FileNotFoundError(f"CSS file not found: {css_path}")
            css += f"\n/* Custom styles from {css_path.name} */\n"
            css += css_path.read_text(encoding="utf-8")

        base_url = base_dir.as_uri() + "/"
        rendered = HTML(string=document, base_url=base_url).render(
            stylesheets=[CSS(string=css)]
        )
        rendered.write_pdf(str(output))

        size_kb = output.stat().st_size / 1024
        print(
            f"Rendered {display_name} -> {output} "
            f"({len(rendered.pages)} page{'s' if len(rendered.pages) != 1 else ''}, "
            f"{size_kb:.0f} KB)"
        )
        return 0

    except KeyboardInterrupt:
        return 130
    except Exception as exc:  # pragma: no cover - CLI error path
        if args.debug:
            traceback.print_exc()
        else:
            print(f"md2pdf: error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
