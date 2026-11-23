# Chesterfield One-Pager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `chesterfield-onepager.qmd`, a one-page BHC-branded page that renders to HTML and to a single-page PDF, showing what Chesterfield public-service workers earn and what one income affords in rent and home price.

**Architecture:** One script curates the sourced pay rows and validates them (`r/chesterfield_pay.R`); a second turns pay into affordability figures against Chesterfield's ACS median rent and home value (`r/chesterfield_afford.R`); the page reads only the resulting `.rds` and renders with the `typst` and `html` formats. Pages never call APIs.

**Tech Stack:** R (tidyverse, ggplot2, ggtext, kableExtra), Quarto 1.6.39 (Typst PDF), `_common.R`, `_brand.yml`.

**Spec:** `design/2026-11-23-chesterfield-one-pager-design.md`

## Global Constraints

- Follow CLAUDE.md script anatomy: header comment (what, source, output), numbered `## 1. Setup ----` sections, `.Renviron` fallback if a key is needed, `write_rds()` paired with `export_csv()`, a validation block. Scripts are idempotent.
- Pages call `read_rds()` only. No salaries typed into the `.qmd`.
- Native pipe `|>`, tidyverse style, `janitor::clean_names()` on imported raw data.
- Narrative rule: takeaway H2s/title, 2-5 bullets, callouts for caveats. No drafted paragraphs.
- Charts: `theme_rva()`, palette from `_common.R` only (`rva_pal`, `rva_seq`, `rva_brand`), `#| fig-alt:` on every figure, currency via `scales::label_dollar()`, title is a takeaway sentence, subtitle carries geography, units and years, caption from a `_common.R` helper.
- Single-earner headline. Maximum affordable rent is 30% of gross monthly income. Hourly pay is annualized at 2,080 hours and labeled as such.
- Every pay row carries `source`, `source_date` and `status` (`current`, `proposed`, or `stale`). A `proposed` or `stale` figure is never labeled "current" on the page.
- Commit types: `data(...)`, `content(...)`, `docs(...)`. End commits with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- R and Quarto may not be on PATH; see README.md for the prepend. User runs any job over about two minutes. Paths are relative to the project root with forward slashes.

## Review Focus

- A figure marked `proposed` or `stale` must not appear on the page as "current" (the callout and table must show its status).
- A pay row with a missing `source`, `source_date`, or `status` fails validation instead of rendering.
- Hourly roles show the 2,080-hour annualization and a school-year caveat, so a full-time figure is not presented as actual earnings.
- The PDF is exactly one page; a longer table or caption must not spill onto a second page.
- Rent and home figures come from the 2020-2024 ACS window while pay is 2026: the caption states both vintages.

---

### Task 1: Curated pay data

**Files:**
- Create: `r/chesterfield_pay.R`
- Output: `data/chesterfield_pay.rds`, `data-out/chesterfield_pay.csv`

**Interfaces:**
- Produces: tibble `pay` with columns `role` (chr), `employer` (chr: "County" or "CCPS"), `basis` (chr: "annual" or "hourly"), `amount` (dbl, as published), `annual_pay` (dbl; hourly x 2080 rounded to whole dollars), `source` (chr), `source_date` (Date), `status` (chr: "current", "proposed", "stale"), `note` (chr).

- [ ] **Step 1: Resolve the adoption check.** Look up the adopted FY27 CCPS budget (School Board and Board of Supervisors) for teacher step 0, instructional assistant step 0, and bus driver T1 step 1. Re-check the Deputy Sheriff starting pay on the current county posting. If a figure is confirmed adopted or posted for FY27, set `status = "current"` and cite the adopted document; otherwise leave `proposed`/`stale`. Record what you found in the `note` column.
- [ ] **Step 2: Write the validation block first** at the bottom of the script, asserting: 7 roles present (teacher, instructional assistant, school bus driver, police officer, firefighter/EMT, deputy sheriff, 911 officer); no NA in `role`, `annual_pay`, `source`, `source_date`, `status`; `status %in% c("current","proposed","stale")`; every hourly row has `annual_pay == round(amount * 2080)`; police `annual_pay == 60147`, firefighter/EMT `annual_pay == 60147`, 911 officer `annual_pay == 48447`, teacher (FY26) `annual_pay == 55047`. Run it with the curated tibble stubbed empty and confirm it fails.
- [ ] **Step 2b: Run to see it fail.** Run: `Rscript r/chesterfield_pay.R`. Expected: stopifnot error naming the missing roles.
- [ ] **Step 3: Fill the curated `tribble()`** in the script (one row per role, values from the design doc's pay table plus Step 1 results; teacher gets both the FY26 `current` row and, unless adopted, an FY27 `proposed` row). Compute `annual_pay`, write with `write_rds()` and `export_csv(pay, "chesterfield_pay")`.
- [ ] **Step 4: Run to see it pass.** Run: `Rscript r/chesterfield_pay.R`. Expected: no error; `data/chesterfield_pay.rds` and `data-out/chesterfield_pay.csv` exist.
- [ ] **Step 5: Commit.** `data(chesterfield-pay): add curated public-service starting pay with sources`.

### Task 2: Affordability figures

**Files:**
- Create: `r/chesterfield_afford.R`
- Output: `data/chesterfield_onepager.rds`, `data-out/chesterfield_onepager.csv`

**Interfaces:**
- Consumes: `data/chesterfield_pay.rds` (Task 1 `pay`); `data/acs_market.rds` rows with `geoid == "51041"`, `year == 2024`, `measure %in% c("median_rent", "median_value")`, column `estimate`; `data/summary_county_5176099999.csv` (HUD FY2026 limits, 80% AMI one-person limit $63,600).
- Produces: `afford` tibble: all columns of `pay` plus `max_rent` (dbl, `annual_pay * 0.30 / 12`), `max_price` (dbl), `rent_gap` (dbl, `max_rent - median_rent`), `price_gap` (dbl, `max_price - median_value`), `pct_ami80_1p` (dbl, `annual_pay / 63600`); and a list `ctx` with `median_rent`, `median_value`, `assumptions` (one-row tibble: `rate`, `rate_source`, `rate_date`, `down_pct`, `tax_rate`, `tax_source`, `ins_rate`, `pmi_rate`). Saved together as a named list `list(afford = , ctx = )` in the `.rds`.

- [ ] **Step 1: Write the validation block first:** `max_rent` for $60,147 equals 1503.675 (within 0.01); round-trip check, i.e. for every row the monthly PITI at `max_price` equals `annual_pay * 0.30 / 12` within $1; Chesterfield `median_rent == 1629` and `median_value == 366000` (same-vintage ACS figures already in `data/acs_market.rds`); `assumptions` has non-empty `rate_source`, `rate_date`, `tax_source`. Run: `Rscript r/chesterfield_afford.R`. Expected: fails (no data yet).
- [ ] **Step 2: Implement `max_price(income, rate, down_pct, tax_rate, ins_rate, pmi_rate) -> dbl`** in the script. Algorithm: budget `B = income * 0.30 / 12`; monthly mortgage factor `m = r/12 / (1 - (1 + r/12)^-360)`; `price = B / ((1 - down_pct) * m + tax_rate/12 + ins_rate/12 + (1 - down_pct) * pmi_rate/12)`, with `pmi_rate` forced to 0 when `down_pct >= 0.20`.
- [ ] **Step 3: Source the assumptions** and enter them in the `assumptions` tibble: the latest Freddie Mac PMMS 30-year rate (record the date), Chesterfield's current real-estate tax rate per $100 from chesterfield.gov (record the URL), a stated down payment, homeowners insurance rate and PMI rate. Write each source into the tibble. Join `pay` to the ACS and HUD values, compute the columns above, `write_rds()` and `export_csv()`.
- [ ] **Step 4: Run.** `Rscript r/chesterfield_afford.R`. Expected: validation passes; log the rent and price gaps per role in `LOG.md` later.
- [ ] **Step 5: Commit.** `data(chesterfield-afford): compute affordable rent and price by role`.

### Task 3: The one-pager page (HTML and PDF)

**Files:**
- Create: `chesterfield-onepager.qmd`
- Modify: `_common.R` (add caption helper `chesterfield_pay_cap() -> chr`)

**Interfaces:**
- Consumes: `data/chesterfield_onepager.rds` list `afford` and `ctx` from Task 2.
- Produces: `docs/chesterfield-onepager.html` and `docs/chesterfield-onepager.pdf` (one page).

- [ ] **Step 1: Add `chesterfield_pay_cap(...)` to `_common.R`:** bold-markdown "Source:" line naming Chesterfield County HR postings, Chesterfield County Public Schools' Feb 3, 2026 compensation presentation, the 2020-2024 ACS 5-year (Tables B25064, B25077), and HUD FY2026 income limits.
- [ ] **Step 2: Write the QMD front matter:** title is a takeaway sentence; `format:` with `html` (site theme, links to the PDF at `chesterfield-onepager.pdf`) and `typst` (letter paper, narrow margins, `_brand.yml` brand, horizontal logo in the header, `toc: false`). If Typst does not apply the brand fonts or logo acceptably, fall back to `pdf` with `latex-engine: xelatex`, and note it in LOG.md.
- [ ] **Step 3: Setup chunk** (`source("_common.R")`, `read_rds("data/chesterfield_onepager.rds")`, inline scalars for the big numbers). Body in this order: three big-number callouts (median rent, teacher max rent, police/fire max rent); chart `fig-pay-vs-afford` (starting pay by role as bars, with lines for the pay needed to afford the median rent and the median home, bold ggtext subtitle spans, no legend); table `tbl-roles` (role, starting pay, status, max rent, max home price, vs. median rent) via `kbl() |> kable_styling(c("condensed","striped"))` and a dual-income line; 2-5 bullets; a caveat callout (proposed vs adopted via `status`, 2,080-hour annualization, school-year schedules, 2020-2024 ACS vs 2026 pay); a sources footer from `chesterfield_pay_cap()`.
- [ ] **Step 4: Render HTML.** Run: `quarto render chesterfield-onepager.qmd --to html`. Expected: no error, `fig-pay-vs-afford` has `fig-alt`.
- [ ] **Step 5: Render the PDF and confirm one page.** Run: `quarto render chesterfield-onepager.qmd --to typst`, then `pdftotext docs/chesterfield-onepager.pdf -` and count form-feed characters. Expected: exactly 1 page. If it overflows, shrink the table and chart, not the caveat callout.
- [ ] **Step 6: Eyeball the PDF** (open `docs/chesterfield-onepager.pdf`): logo, brand colors, legible table, no clipped text.
- [ ] **Step 7: Commit.** `content(chesterfield-onepager): add one-page Chesterfield affordability brief`.

### Task 4: Site wiring and housekeeping

**Files:**
- Modify: `_quarto.yml` (navbar entry "Chesterfield" to `chesterfield-onepager.qmd`), `data-notes.qmd` (paragraph on pay sources, status labels and the affordability method), `CLAUDE.md` (repo-map line for the new page and the two scripts), `TODO.md`, `LOG.md`

- [ ] **Step 1: Add the navbar entry** and a `data-notes.qmd` paragraph covering sources, dates, `status` meaning, the 30%-of-income rule, and the home-price assumptions with their sources.
- [ ] **Step 2: Update `CLAUDE.md`** repo map, and `TODO.md`: check off this work, add the open items (adopted FY27 confirmation if not resolved, BHC logo clearance, firefighter/sheriff pay-plan step tables).
- [ ] **Step 3: Append a `LOG.md` entry:** what was built, the data surprises (the class-spec police minimum of $53,214 predates FY24 raises; the CCPS deck's $57,227 vs $57,277 typo; Deputy Sheriff pay from a January posting), and what is left open.
- [ ] **Step 4: Run the full site render of the new page and its neighbors:** `quarto render` for the project or `quarto render chesterfield-onepager.qmd`. Expected: no errors; user runs the full site render if it exceeds two minutes.
- [ ] **Step 5: Commit.** `docs: wire Chesterfield one-pager into site, update TODO and LOG`.

## Self-review notes

- Spec coverage: pay data (Task 1), affordability method and assumptions (Task 2), one-page layout, branding, HTML and PDF (Task 3), housekeeping per CLAUDE.md (Task 4), adoption check and 911-row decision (Task 1 Step 1; the 911 row is kept, labeled as a class-spec minimum).
- Deviation from the design doc: the curated pay rows live in a `tribble()` inside `r/chesterfield_pay.R` (committed, sources beside the numbers), not a separate hand-edited CSV, because `data/raw/` is gitignored and `data-out/` is for outputs.
