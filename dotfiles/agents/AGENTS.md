# Global Agent Instructions

These instructions apply to every project. When they conflict with a project's instructions or tooling, such as a Markdown linter's line-length rule, follow the project.

## Prose wrapping in Markdown and Org

- Do not hard-wrap prose in Markdown (`.md`) or Org (`.org`) files. Write each paragraph, list item, and blockquote on a single line; the editor soft-wraps it.
- When you edit a paragraph that is already hard-wrapped, join that paragraph onto one line. Leave other paragraphs as they are.
- Keep the line breaks that Markdown and Org syntax require, such as in code blocks, tables, front matter, headings, and between separate list items.

## Table formatting in Markdown and Org

- After you create or edit a table in a Markdown or Org file, align it with `~/bin/align-tables FILE [FILE ...]`. It uses Emacs to align every table in each file in place. Do not align tables by hand.
- `align-tables` exits with status 3 and prints `FILE:LINE: table is N characters wide (limit 109)` for each aligned table wider than 109 characters. Unless the user specifically asked for a table, rewrite that table's data as prose instead.
