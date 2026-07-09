# lazycouchbase

A keyboard-driven terminal UI for [Couchbase](https://www.couchbase.com/), in the spirit of
[lazygit](https://github.com/jesseduffield/lazygit) and
[lazydocker](https://github.com/jesseduffield/lazydocker). Browse buckets, scopes, and
collections, peek at documents, and run ad-hoc N1QL queries without leaving your terminal.

Built on [ratatui_ruby](https://rubygems.org/gems/ratatui_ruby) and the official
[couchbase](https://rubygems.org/gems/couchbase) Ruby SDK.

```text
┌ [1] Buckets (2) ─────┐┌ [3] Documents (50) ──────────────────────────────┐
│❯ beer-sample         ││❯ 21st_amendment_brewery_cafe                     │
│  travel-sample       ││  21st_amendment_brewery_cafe-21a_ipa             │
│                      ││  357                                             │
└──────────────────────┘│  512_brewing_company                             │
┌ [2] Collections (1) ─┐│  512_brewing_company-512_alt                     │
│❯ _default._default   ││  512_brewing_company-512_bruin                   │
│                      ││  ...                                             │
└──────────────────────┘└──────────────────────────────────────────────────┘
 localhost │ Connected      j/k: move │ enter: open │ :: query │ q: quit
```

## Installation

Install the gem by executing:

```bash
gem install lazycouchbase
```

Or add it to your application's Gemfile:

```bash
bundle add lazycouchbase
```

The `couchbase` and `ratatui_ruby` dependencies ship native extensions; prebuilt binaries
exist for common platforms, and building from source requires a C++ toolchain (couchbase)
and a Rust toolchain (ratatui_ruby).

## Usage

```bash
lazycouchbase                                  # connect to couchbase://localhost
lazycouchbase --host db.example.com            # another host (or a full connection string)
lazycouchbase -u admin -p secret -b beer-sample
lazycouchbase --help
```

### Keybindings

| Key                 | Action                                        |
| ------------------- | --------------------------------------------- |
| `tab` / `shift-tab` | Cycle panes                                   |
| `1` / `2` / `3`     | Focus buckets / collections / documents       |
| `j` / `k`, arrows   | Move selection (loads the panes to the right) |
| `g` / `G`           | Jump to first / last entry                    |
| `enter`             | Drill in; open the selected document          |
| `/`                 | Fuzzy filter the focused pane                 |
| `:`                 | Open the N1QL query editor                    |
| `r`                 | Refresh the focused pane                      |
| `esc`               | Back                                          |
| `?`                 | Help                                          |
| `q` / `ctrl-c`      | Quit                                          |

In the query editor, type a N1QL statement and press `enter` to run it; results are shown
below the input. `↑`/`↓` recall the last 30 executed queries (persisted in
`$XDG_DATA_HOME/lazycouchbase/history.jsonl`), and `ctrl-e` runs `EXPLAIN` on the current
statement — a plain-English summary of the plan (index usage, scans, joins, sorts) opens
in the document view with the raw plan below it.

In the document view, `j`/`k` and `page up`/`page down` move a cursor line, and the status
bar shows a breadcrumb of where that cursor is (`bucket › collection › id › path`). Long
values soft-wrap with a hanging indent instead of being clipped. `/` searches lines
(fuzzy, like the pane filter) with `n`/`N` cycling matches, `t` toggles a keys-only
outline (`enter` jumps to the selected key), and `y`/`Y` copy the whole document or the
value under the cursor to the clipboard (needs `wl-copy`, `xclip`, `xsel`, or `pbcopy`).

The `/` filter is a transient fuzzy picker in the style of fzf: type to narrow the focused
pane (case-insensitive subsequence match, so `ta2` finds `tenant_agent_02.users`), move the
highlight with `↑`/`↓`, then press `enter` to jump to that entry — or `esc` to leave the
pane exactly as it was.

### Configuration

lazycouchbase reads `$XDG_CONFIG_HOME/lazycouchbase/config.toml`
(`~/.config/lazycouchbase/config.toml` by default):

```toml
[connection]
host = "localhost"          # or a full connection string like "couchbases://db.example.com"
username = "Administrator"
password = "password"
bucket = "beer-sample"      # optional: bucket to select at startup

[ui]
document_limit = 50         # documents listed per collection
```

Every `[connection]` value can also be set through `LAZYCOUCHBASE_HOST`,
`LAZYCOUCHBASE_USERNAME`, `LAZYCOUCHBASE_PASSWORD`, and `LAZYCOUCHBASE_BUCKET` environment
variables, and `document_limit` through `LAZYCOUCHBASE_DOCUMENT_LIMIT`. Precedence, lowest
to highest: defaults, config file, environment variables, command-line flags.

Listing documents uses a `SELECT META().id` query, so collections you browse need a
[primary index](https://docs.couchbase.com/server/current/n1ql/n1ql-language-reference/createprimaryindex.html)
(`CREATE PRIMARY INDEX ON \`bucket\`.\`scope\`.\`collection\``). Without one, the documents
pane shows the index error in the status bar — queries by `META().id` from the query editor
still work.

## Development

After checking out the repo, run `bundle install` to install dependencies. Then run
`bundle exec rake spec` to run the tests and `bundle exec rubocop` to lint. You can also run
`bin/lazycouchbase` directly to try the TUI.

Most specs run against an in-memory fake client and ratatui_ruby's headless test terminal,
so they need no running cluster. Integration specs are skipped unless a Couchbase cluster is
reachable; point them at one with `COUCHBASE_TEST_HOST`, `COUCHBASE_TEST_USERNAME`,
`COUCHBASE_TEST_PASSWORD`, and `COUCHBASE_TEST_BUCKET`.

To install this gem onto your local machine, run `bundle exec rake install`. To release a
new version, update the version number in `version.rb`, and then run `bundle exec rake
release`, which will create a git tag for the version, push git commits and the created tag,
and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/andy4thehuynh/lazycouchbase.
