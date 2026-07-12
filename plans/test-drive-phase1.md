# Test Drive: fuzzy filter, document view, history, EXPLAIN

Run `bin/lazycouchbase` (or the `~/.local/bin` wrapper). Queries are single-line
— the editor doesn't do newlines yet. Expected outcomes in *italics*.

## 1. Pane fuzzy filter (warm-up)

1. `/` in buckets, type `tr`, `enter` — *only travel-sample matched, selection
   lands on it, collections reload*
2. `2` to focus collections, `/`, type `ta2`, `enter` — *fuzzy subsequence
   lands on tenant_agent_02.*; `esc` games: `/`, type `zzz` — *(0/18)*, `enter`
   — *degrades to cancel*

## 2. Document view

1. `/` in collections → `invair` → `enter`, then `3`, pick an airline, `enter`
2. `j` a few times — *cursor line highlighted, breadcrumb shows
   `travel-sample › inventory.airline › airline_10 › name`*
3. `/` type `icao` `enter` — *cursor jumps to the icao line*
4. `t` — *keys-only outline*; `j` to a key, `enter` — *jumps there*
5. `Y` — *"Copied icao" in status bar; paste somewhere to confirm*
6. Open a hotel document (collection `invhot`) — *long `description` wraps
   with hanging indent, no clipped text*

## 3. Query history (`:` to open the editor)

Run these three in order (enter after each):

```sql
SELECT META().id FROM `travel-sample`.inventory.airline LIMIT 3
```
```sql
SELECT name, city FROM `travel-sample`.inventory.airport WHERE city = "Paris" LIMIT 5
```
```sql
SELECT COUNT(*) AS airports FROM `travel-sample`.inventory.airport
```

Then:
- `↑` — *COUNT query*; `↑ ↑` — *back to the META().id query*; `↓` — *forward*;
  `↓ ↓` — *blank prompt*
- `↑`, type some garbage on the end, `↑` again — *edit discarded, older entry
  shown*
- `esc`, `:` again, `↑` — *starts from newest again (position reset)*
- `q` out of the app entirely, relaunch, `:`, `↑` — *history survived
  (~/.local/share/lazycouchbase/history.jsonl)*

## 4. EXPLAIN (`ctrl-e` on the statement in the editor)

**a) Primary scan warning** (no index on country):
```sql
SELECT META().id FROM `travel-sample`.inventory.airline WHERE country = "France" ORDER BY name LIMIT 5
```
*Headline: "No index used — primary scan reads the whole keyspace", then scan
→ fetch → filter → sort → limit lines, raw plan JSON below.*

**b) Index scan** (city is indexed):
```sql
SELECT name FROM `travel-sample`.inventory.airport WHERE city = "Paris"
```
*Headline: "Uses index: def_inventory_airport_city".*

**c) Count from metadata**:
```sql
SELECT COUNT(*) FROM `travel-sample`.inventory.airport
```
*Headline: "Answered from index metadata — no documents read".*

**d) Group + sort**:
```sql
SELECT city, COUNT(*) AS n FROM `travel-sample`.inventory.airport GROUP BY city ORDER BY n DESC LIMIT 5
```
*Lines include "Group by", "Sort by", "Limit 5".*

**e) The learning loop — fix (a) with an index.** Run (enter, not ctrl-e):
```sql
CREATE INDEX idx_airline_country ON `travel-sample`.inventory.airline(country)
```
Then `↑ ↑` to recall query (a) and `ctrl-e` again —
*headline flips to "Uses index: idx_airline_country"; the sort line is still
there (the index doesn't cover ORDER BY name — that's the next lesson).*
Cleanup when done:
```sql
DROP INDEX idx_airline_country ON `travel-sample`.inventory.airline
```

**f) Plan is a full document view**: on any plan, `t` — *outline of the plan
JSON*; `/` `spans` — *jump into index details*; `y` — *whole plan to
clipboard (paste into cb.fuj.io later)*.

## 5. SQL++ stretch (adds useful history + join/unnest summary lines)

```sql
SELECT r.sourceairport, r.destinationairport, s.day FROM `travel-sample`.inventory.route r UNNEST r.schedule s WHERE s.day = 1 LIMIT 5
```
*ctrl-e: an "Unnest" line appears.*

```sql
SELECT a.name, r.sourceairport, r.destinationairport FROM `travel-sample`.inventory.route r JOIN `travel-sample`.inventory.airline a ON KEYS r.airlineid LIMIT 5
```
*ctrl-e: a join line (shown raw if the operator isn't in the rule table —
that's by design, note what it prints).*

## 6. Error paths

- `SELEKT 1` + enter — *status-bar error, app keeps running; the typo is still
  recallable with ↑ for fixing*
- `SELEKT 1` + ctrl-e — *same, error passes through*
- Empty editor + ctrl-e or enter — *nothing happens*

## Things to note while testing

- Query results are still flat one-line rows — that's Phase 2's
  "results through the document view" work, not a bug.
- If a summary line ever reads as a raw operator name (e.g. `NestedLoopJoin3`
  variants we haven't mapped), jot it down — each one is a cheap rule to add.
