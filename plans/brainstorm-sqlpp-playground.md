# Brainstorming Summary: SQL++ Learning Playground

## Problem

Andy's working SQL++ knowledge stops at `SELECT ... WHERE`; the language's real
power (joins, `UNNEST`, `GROUP BY`/`LETTING`, subqueries, `MISSING` semantics,
functions) is undiscoverable from inside the current one-line query view.
Learning happens in the Couchbase web workbench and browser docs — outside the
tool he lives in — and `EXPLAIN` output is a wall of JSON that doesn't teach.
As a Couchbase solutions engineer he needs live SQL++ fluency and credible
performance reasoning, which only come from daily, zero-friction reps.

## Solution

Grow the query view into a keyboard-driven workbench with three pillars, all
offline/deterministic (no AI), all reusing existing machinery:

1. **Write** — curated snippet library of SQL++ patterns (fuzzy-picked,
   keyspace-prefilled from the sidebar selection, each with a docs URL the TUI
   can copy/open); shell-style history (`↑`/`↓`, 30 entries, persisted);
   eventually a multi-line editor.
2. **Read** — query results rendered through the document-view machinery
   (cursor, soft-wrap, search, yank) instead of flat JSON strings.
3. **Performance** — `ctrl-e` runs `EXPLAIN` and shows a translated summary
   ("Primary scan — no index used" vs. "Index scan via `def_type`") with the
   raw plan in the document view; later, exports packaged for Fujio Turner's
   browser tools (cb.fuj.io Slow Query Analyzer, cb_index_analyzer).

Success metric is behavioral: preferring lazycouchbase over the web workbench.

## Key Requirements

- `↑`/`↓` recall the last 30 executed queries (shell semantics: edit is
  discarded on further recall; position resets on run/esc; `↓` past newest
  clears the input). Persisted as JSONL in the XDG data dir; missing/corrupt
  file starts fresh, never crashes.
- Snippets ship as data files in the gem: name, category, template with
  `%{keyspace}` placeholder, description, docs URL. Unfilled placeholders stay
  visible. Malformed entries are skipped with a status warning.
- EXPLAIN translation is a deterministic operator-name rule table; unknown
  operators render raw; already-`EXPLAIN`-prefixed queries aren't
  double-prefixed; server errors pass through to the status bar.
- Browser links open via `xdg-open`/`open` (detached); if no opener exists,
  show the URL so `y` can copy it.
- Works against Capella unchanged (full `couchbases://` connection strings
  already supported; untested).
- Decision: no confirm-prompt guardrail for mutating statements for now
  (trust the operator); show mutation counts prominently. Revisit if history
  recall makes accidental re-runs a real problem.
- Cap rendered result rows with a "showing N of M" note (follow-up).

## Phasing

1. **Phase 1**: query history (`↑`/`↓`, persistence) + EXPLAIN summary
2. **Phase 2**: snippet library + docs links
3. **Phase 3**: multi-line editor (`ctrl-j` newline; arrows recall history only
   at first/last line)
4. **Phase 4**: exports for cb.fuj.io / cb_index_analyzer

## Next Steps

This idea is ready for `/create-prd` or `/create-erd` per phase; Phase 1
implementation started on branch `sqlpp-playground`.
