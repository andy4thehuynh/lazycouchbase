# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
