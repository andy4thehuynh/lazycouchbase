# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `i` toggles pane 3 between a collection's documents and its indexes
  (from `system:indexes`, including legacy bucket-level indexes on the
  default collection). Entries show name, keys, partial-index condition,
  and state; `enter` opens the full catalog row in the document view.
- SQL++ snippet library: `tab` in the query editor opens a fuzzy-searchable
  picker of curated examples (basics, filtering, aggregation, arrays,
  joins, subqueries, indexes, functions). The preview shows each snippet
  as a runnable travel-sample statement; `enter` inserts a fill-in
  skeleton with the keyspace prefilled from the sidebar selection and
  concise placeholders (`f1` fields, `"v1"` values, `ks2` join keyspace)
  for everything collection-specific. `ctrl-o` opens the snippet's SQL++
  reference page in the browser, falling back to the clipboard when no
  opener is available.
- Query history: `↑`/`↓` in the query editor recall the last 30 executed
  queries, persisted across sessions in the XDG data directory.
- `ctrl-e` explains the current query: a plain-English plan summary (index
  usage, scans, joins, sorts) with the raw EXPLAIN plan in the document view.
- `/` fuzzy filter for the buckets, collections, and documents panes: type to
  narrow with case-insensitive subsequence matching, `↑`/`↓` to move the
  highlight, `enter` to select, `esc` to cancel.
- Document view cursor with a `bucket › collection › id › path` breadcrumb in
  the status bar.
- `/` line search inside the document view, with `n`/`N` cycling matches.
- `t` keys-only outline of the open document; `enter` jumps to the selected key.
- `y`/`Y` copy the document or the value under the cursor to the clipboard
  (via `wl-copy`, `xclip`, `xsel`, or `pbcopy`).
- Long document lines soft-wrap with a hanging indent instead of being
  clipped at the pane edge.

### Fixed

- Document view preserves the JSON indentation instead of flattening it.
- Selection highlight uses reverse video so it stays readable in any terminal
  palette.
- Document lists no longer crash the documents pane (the Couchbase SDK returns
  lazy enumerators for query rows).

## [0.1.0] - 2026-07-08

### Added

- Keyboard-driven TUI for browsing Couchbase buckets, scopes/collections, and documents.
- Scrollable pretty-printed JSON document view.
- N1QL query editor with inline results.
- Configuration via `$XDG_CONFIG_HOME/lazycouchbase/config.toml`, `LAZYCOUCHBASE_*`
  environment variables, and command-line flags.
- `lazycouchbase` executable with `--host`, `--username`, `--password`, `--bucket`,
  and `--config` options.

[Unreleased]: https://github.com/andy4thehuynh/lazycouchbase/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/andy4thehuynh/lazycouchbase/releases/tag/v0.1.0
