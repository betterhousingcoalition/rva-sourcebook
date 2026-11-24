# TODO.md — punch list

**Always check TODO.md before starting work.** Update it as tasks land (`[x]`), start (`[~]`), or get skipped (`[-]`). See [LOG.md](LOG.md) for the history behind any line, [METHODOLOGY.md](METHODOLOGY.md) for the data/scope rules, and [PLAN.md](PLAN.md) for the full phased build order.

## Session 0 — repo cleanup (2026-09-15)

- [x] Remove the nested `rva-sourcebook/` duplicate subfolder (superseded by root files).
- [x] Remove stale generic scaffold: `rva-sourcebook.qmd`, `app.R`, `_site/`.
- [x] Rewrite `PLAN.md` — was a Fauquier County/Better Housing Coalition plan for an unrelated engagement.
- [x] Rewrite `CLAUDE.md` — fix geography section (`rr`/`bhc`/`secondary`/`ashland`/`regions`, not `pha`/4-primary), switch book → website language, drop PHA/BHC client-review conventions, add `mapgl` section, trim "Known gotchas" to what's real.
- [x] Reset this file to a real, accurate punch list.
- [x] Write `README.md` (quick start, renv guide, status).
- [x] Write `METHODOLOGY.md` (geography/scope conventions, referenced by CLAUDE.md but never written).
- [x] Reconcile `_quarto.yml` — real navbar (Home/About/Inventory/Demographics/Market/Data Notes), `output-dir: docs`, `freeze: auto`, `execute-dir: project`. Added stub content to `inventory.qmd`/`demographics.qmd`/`market.qmd`/`data-notes.qmd`/`index.qmd`/`about.qmd` so the site renders end-to-end even before real data lands.
- [x] First `LOG.md` entry for this session.
- [x] Commit the cleanup (including removing the leftover `rva-sourcebook/` folder that survived the first pass).

## Phase 1 — foundations

- [x] `renv::init()` + `renv::snapshot()` — **user runs**, package installs are a long job. Pin R + tidyverse/tidycensus/tigris/sf/mapgl/kableExtra/ggtext/formattable/janitor.
- [x] Add `.Rprofile` (`source("renv/activate.R")`) once renv exists.
- [x] `renv::snapshot()` 2026-11-12 recorded `arrow`, `assertthat`, `readxlsb` (GitHub source `velofrog/readxlsb`, compiled; needs Rtools to restore). `renv::status()` clean.
- [x] Define a palette + light theme in `_common.R` — `rva_pal` (8-hue categorical), `rva_seq` (sequential blue ramp), `rva_ink` (chart chrome), `theme_rva()`. Values from the dataviz skill's validated reference palette.
- [x] Decide the `mapgl` basemap style — `rva_map_style` in `_common.R`, Carto's free Positron MapLibre style, no token.
- [x] `r/geo.R` written — tigris county/independent-city boundaries for the `rr` region → `data/geo.rds` + `data-out/geo.csv`.
- [x] **Run `Rscript r/geo.R`** — user runs (tigris pull is a long job). Confirms `data/geo.rds` writes clean and the validation block passes (17 localities, valid geometry, EPSG:4326). Verified 2026-09-16: `data/geo.rds` is an `sf` frame, 17 rows, all `rr` GEOIDs, EPSG:4326, zero empty geometries.
- [x] Confirm `CENSUS_API_KEY` is visible (`Sys.getenv("CENSUS_API_KEY") != ""`) — TRUE/FALSE check only, never print the value. Not needed by `geo.R` (tigris doesn't require a key) but will be for every ACS script from Phase 2 on. Verified TRUE 2026-09-16 via the `.Renviron` fallback.
- [-] Once `mapgl` is in `renv.lock`, build one small proof-of-concept map (e.g. `rr` region colored by `aland`) to confirm `rva_map_style` + `data/geo.rds` actually render before wiring real data into it. **Blocked:** `mapgl` is not in `renv.lock` — needs a user-run `renv::install("mapgl")` + `renv::snapshot()`.

- [ ] `r/acs_tenure.R`'s header comment (lines 18–21) still says "8 `rr` localities" / "4 primary localities" / `region4` — doesn't match `_common.R` (`rr`=17, `bhc`=3) or the script's own `region3` pooling. Sibling-project debris missed in the 2026-09-15 cleanup; reconcile the comment (and sanity-check no other `r/*.R` header has the same mismatch).

## Phase 2 — inventory page

- [x] `r/acs_stock.R` — ACS B25001 (units), B25002/B25004 (occupancy/vacancy), B25024 (structure type), B25034–36 (year built). Ran clean; validation passes. **B25036 dropped from scope** — not published in the 2014 window, which would break the three-window trend (recorded in METHODOLOGY.md). B25035 is pulled but carries no pooled rows, since a median can't be summed.
- [x] BPS building permits (census.gov text files) — annual permits by structure type for the `rr` region. `r/bps_permits.R`, 2000–2025, cached under `data/cache/bps/`. Ran clean; the `rr17` pooled row reconciles to its 17 members in all 26 years.
- [x] Build out `inventory.qmd` (currently an empty stub). 6 figures, 3 tables, takeaway H2s, bullets, callouts; renders standalone in ~10s.

## Phase 3 — demographics page

- [x] `r/acs_demographics.R` written and run 2026-10-28 (population + age/sex B01001, race/ethnicity B03002, household type B11001, income B19001/B19013/B25118; 3 windows, 25 geographies incl. pooled `bhc3`/`secondary4`/`rr17`). User confirmed validation passed.
- [x] Build out `demographics.qmd` — 7 figures, 3 tables, takeaway H2s, computed-inline bullets, reliability + race-coding callouts. Rendered standalone 2026-10-28 and figures checked visually. All 7 `fig-` chunks have `fig-alt`. (Bullet figures are computed inline; the `fig-alt` text carries typed rounded numbers that will drift on a data refresh, same as `inventory.qmd`.)

- [x] `r/pep_migration.R` + migration sections in `demographics.qmd` (added 2026-10-28 at the user's request, not in the original plan). PEP components of change (natural, international, domestic migration) for the 17 localities, pooled core/ring/region, and Virginia, 2010–2019 and 2020–2025. Ran clean; validation passes, including a same-vintage match to the Census API for all 17 localities. 4 figures, 1 table, 1 callout, all `fig-alt` present; rendered and checked.

## Phase 4 — market page

- [x] `acs_burden.R` reviewed 2026-10-28. **Its output was not current — `data/acs_burden.rds` never existed.** Fixed before first run: dropped the sibling-project tract tier and `baseline_2022` block, fixed stale `acs_income.R` refs, switched the collapsed-band MOE to quadrature (was `moe_sum(moe, estimate)` on an already-summed scalar), added pooled `bhc3`/`secondary4`/`rr17` rows, rewrote the validation block (25 geographies × 3 windows × 2 tenures × 4 categories; rr17 reconciles to its 17 members). User ran it; validation passed.
- [~] `r/bls_wage.R` written (BLS LAUS unemployment + CES average hourly earnings + CPI-U, Richmond MSA vs. `regions` metros) — **not yet run.** User: `renv::install("blscrapeR")` + `renv::snapshot()`, confirm `BLS_KEY` is in `.Renviron`, then `Rscript r/bls_wage.R` and paste back the validation output. Check that the three comparison metros' CES wage series came back (a warning names any that didn't).
- [ ] Add a `bls_cap()` caption helper to `_common.R` when the market page first charts `bls_wage.rds` (`oews_cap`/`cpi_cap` don't fit — `cpi_cap` says "via FRED").
- [~] `r/acs_market.R` written 2026-10-28 — B25003 tenure (not covered by `acs_tenure.R`, which is race-specific only), B25077 home value, B25064 rent; medians carry nominal + real columns. **Not yet run — user:** `Rscript r/acs_market.R`, paste back validation output.
- [~] `market.qmd` drafted 2026-10-28 (7 figures, 4 tables, callouts; replaces the old book's split `ownership.qmd`/`rental.qmd`). Code and layout verified against a scratchpad **mock** `acs_market.rds` (real B25118 tenure counts, synthetic medians) — **the real render is blocked on the user running `Rscript r/acs_market.R`** and pasting back validation output. After that: render `market.qmd` for real, re-read every figure, and revisit the three flagged items — the "Home values and rents climbed in every core locality" H2, the "Price-to-income ratios show where buying is hardest" H2, and the `fig-alt` text on `fig-value`/`fig-rent`/`fig-pti`/`fig-rent-share`, all written before the home-value and rent data existed.

## Phase 4b — PUMS profiles and summary (added 2026-10-30 at the user's request)

- [x] `r/pums/pums_profiles.R` — tidy household/resident estimates by AMI band × tenure × geography with replicate-weight SEs and reliability flags → `data/pums_profiles.rds`, `data-out/pums_ami_dist.csv`, `data-out/pums_profile.csv`. Ran clean; PUMS owner/renter households in the core-3 PUMAs match ACS B25003 within 0.6%.
- [x] `profiles.qmd` — 11 figures, 3 tables, takeaway H2s, computed-inline bullets, geography + reliability callouts; every `fig-` chunk has `fig-alt`. Added to the navbar.
- [x] `summary.qmd` — executive summary of inventory, demographics, market; now includes an income-band section drawn from `profiles.qmd`. Added to the navbar.
- [ ] `inventory.qmd` bullet "peaked at [2022's 10,414] … a 76% collapse" is wrong: 2022 is the series high and the pre-crash peak was ~8,400 (2005). Its "multifamily first exceeded single-family in 2022" line also needs a check (2024 was single-family-led). `summary.qmd` words it around the error.
- [x] `r/pums/pums_prep.R` runs (2026-10-30, after the user added `naics_soc_lookup.R` and `data-out/puma_pow.csv`) and writes `data/pums_rva.rds` (48,802 persons, 215 columns). Nothing reads it yet. Still no script header block.
- [ ] `r/pums/*.R` don't follow the script anatomy (no header block, no `source("_common.R")`, `pums_ami.R` ends with an unguarded `ggplot()` call). `pums_ami.R` also hardcodes the HUD CSV path (`data/summary_county_5176099999.csv`) and the CPI factor; `data/` is gitignored, so the HUD file isn't in the repo — note where it came from in `data-notes.qmd`.
- [ ] `r/pums/` is untracked in git; commit it with `profiles.qmd`, `summary.qmd`, and the log.
- [ ] `data-notes.qmd` needs a PUMS / AMI section (geography caveat, FY2026 limits, CPI inflation, replicate-weight SEs). See METHODOLOGY.md.
- [ ] Optional: a `mapgl` choropleth of share at/below 80% AMI by PUMA for Phase 5 (boundaries for all PUMAs are in `data/puma_va.rds`; the profiles now cover the seven core-three PUMAs).

## Phase 4c — eviction filings (added 2026-10-31 at the user's request)

- [x] `r/evict.R` — combines the three `data-out/*-virginia-filings.csv` exports (Richmond city, Henrico, Chesterfield) into `data/evict.rds` (monthly, annual, summary) + `data-out/evict_monthly.csv`, `evict_annual.csv`. Ran clean; validation passes.
- [x] "Eviction filings" section in `market.qmd` (2 figures, 1 table, bullets, caveat callout, bullet in the opening tip box). Renders clean.
- [x] Eviction section added to `summary.qmd` (2026-11-03).
- [ ] Add an eviction paragraph to `data-notes.qmd` (source, baseline definition, partial 2026).
- [ ] Confirm the source and the "historical average" baseline definition; the exports don't document either.

## Phase 4d — HMDA mortgage lending (added 2026-10-31 at the user's request)

- [x] `r/hmda_prep.R` — core-three, principal-residence, 1-4 unit; originations, denial rates (locality, purpose, race/ethnicity), denial reasons → `data/hmda.rds` + `data-out/hmda_*.csv`.
- [x] Lending section in `market.qmd` (2 figures, 1 table, bullets, callout) and a bullet in the opening box.
- [ ] `r/hmda.R` has no header/validation, no `source("_common.R")` (uses `rr`), and leaves four stray `all(is.na(...))` lines on columns that aren't selected; bring to script anatomy.
- [x] Lending added to `summary.qmd` (2026-11-03).
- [ ] Add lending to `data-notes.qmd` (denial-rate definition, HMDA coverage).

## Phase 4e — external affairs section (added 2026-11-03 at the user's request)

- [x] `summary.qmd` section "For external affairs: connecting the data to Better Housing Coalition's work": quotable-numbers table, bullets by BHC line of work (rental, senior, homeownership, mixed-income/mixed-use), and a "using these figures" callout.
- [x] `r/summary_audit.R` -> `data/summary_audit.rds` + `data-out/summary_audit.csv`: 90% MOEs and independent HMDA/eviction re-computation for the figures the BHC section quotes (2026-11-03). Re-run after any data refresh; the page reads it.
- [ ] Re-check `summary.qmd`'s hand-typed numbers (none remain in prose, but the Profiles and market `fig-alt` text carries rounded values).
- [ ] BHC to supply program facts (units, residents served, pipeline) to pair with the regional figures; the section deliberately states none beyond the 8 senior properties.
- [ ] Mixed-use has no direct data (retail/commercial demand); consider a public source if this section is used for that case.

## Phase 5 — interactive maps

- [ ] One `mapgl` choropleth per page (e.g. inventory: vacancy rate by locality; demographics: median household income; market: median rent or home value).

## Phase 6 — polish & publish

- [ ] `data-notes.qmd` — public-facing methodology, derived from `METHODOLOGY.md`.
- [ ] `about.qmd` — real content (currently a one-line stub).
- [ ] Full `quarto render` completes with no errors.
- [ ] Every `#| label: fig-` chunk has a matching `#| fig-alt:` line. (`inventory.qmd` is done — 6 of 6.)
- [ ] GitHub Pages live from `docs/` on `main`.

## Surfaced during Phase 2 — not blocking

- [ ] `cache_table = TRUE` is deprecated in current tidycensus (one warning per `get_acs()` call, ignored). CLAUDE.md still prescribes it. Drop it project-wide in one pass — `acs_stock.R`, `acs_tenure.R`, `acs_burden.R`, and the CLAUDE.md line together — rather than piecemeal.
- [ ] `theme_rva()`'s caption switched to `element_textbox_simple()` so long source lines wrap instead of clipping. The other pages' charts haven't been re-rendered against it yet; check them when Phases 3–4 land.
- [ ] `formattable::comma()`/`percent()` mask the `scales` versions (`_common.R` loads formattable last) and take `digits`, not `accuracy`. `inventory.qmd` works around it with local `n_fmt()`/`p_fmt()` wrappers — consider promoting those to `_common.R` before the next page repeats the workaround.

## Presentation — external affairs committee deck (2026-11-06)

- [x] `presentation.qmd` + `presentation.css` — 10-slide reveal.js deck built from the `summary.qmd` findings (BHC section first): headline on every slide, big-number cards plus charts, a six-figure quotables table with margins of error, a cautions slide for Q&A. Speaker notes on each slide. Renders standalone to `docs/presentation.html`.
- [x] Deck linked from the site navbar (Presentation tab, opens in a new tab), 2026-11-12. Not committed yet.
- [x] Six 2027 General Assembly legislation slides added 2026-11-12 (nine LIS bills plus unfiled proposals).
- [ ] Legislation slides: confirm the unfiled proposals' source can be shown publicly; add patrons and bill numbers once filed; refresh LIS statuses before the session opens (snapshot is 2026-11-12). Read the LIS history for HB143, HB1376 and SB349 if the slides should say whether they were carried over.
- [ ] Setup chunk copies a subset of `summary.qmd`'s helpers; if those change (or get promoted to `_common.R`), update the deck too. (Renter-income helpers now exist in `summary.qmd`, `presentation.qmd` and `demographics.qmd` — a strong case for promoting `inc_renter()` to `_common.R`.)
- [x] BHC branding on the site and the deck (`_brand.yml`, `styles.css`, `presentation.css`, navbar logo, favicon, title-slide logo).
- [ ] Confirm brand blue/red/brown against the brand guide (extracted only as CMYK swatches, converted approximately) and the logo usage rules; update `_brand.yml` and `rva_brand` in `_common.R` together.
- [ ] Optional: Lato in R charts (`showtext`/`sysfonts`); charts currently use the system sans font.
- [ ] Before publishing `docs/`: confirm BHC has cleared use of its logo and brand on the public site. `img/` logo files are still untracked.

## Renter-income comparison (2026-11-12, at the user's request)

Why: the question is whether renters can move to ownership, so home values and rents are compared with median *renter* household income (ACS B25119), not the all-household median.

- [x] `r/acs_demographics.R` pulls B25119 (`median_income_renter`; nominal + real, 3 windows, all geographies) → `data/acs_demographics.rds`, `data-out/acs_demographics.csv`.
- [x] `r/summary_audit.R` has `pti_*` (renter denominator) and `renter_income_real_chg` keys.
- [x] `presentation.qmd`: price-vs-income chart, homeownership stat, and quotables use renter income.
- [x] `summary.qmd`: `pti()`/`rent_share()` and every income comparison switched to renter income; renter row in the at-a-glance table; all-household income kept as a reference figure.
- [x] `market.qmd`: renter-income versions of the price-to-income and rent-share figures (`fig-pti-renter`, `fig-rent-share-renter`); the all-household versions stay.
- [x] `demographics.qmd`: renter median-income figure (`fig-income-renter`) and bullets.
- [ ] **User: `Rscript r/summary_audit.R`** — the 2026-11-03 audit files predate B25119, so `au("pti_2024")` still shows the all-household margin and `au("renter_income_real_chg")` is empty until it re-runs. Then paste back the output.
- [x] Quoted-figure review: senior sample size (509, not 50), eviction wording, "two-thirds" seniors claim (2026-11-12). Direct senior counts added to `pums_profiles.R`.
- [x] `pums_profiles.R` and `summary_audit.R` re-run with direct senior counts (2026-11-12).
- [ ] **User: render `summary` and `presentation`** (they now read `P$seniors`).
- [ ] **User: render `demographics`, `market`, `summary`, `presentation`** and re-read the new figures. Not yet rendered; `market.qmd` and `demographics.qmd` are frozen pages, so confirm they actually re-execute.
- [ ] Check the typed numbers in the new `fig-alt` text (renter ratio ~5.9 to ~6.5; renter income ~$38k to ~$48k for Richmond city, ~$48k to ~$55k for the metro) against the rendered figures.
- [ ] Add B25119 and the renter-income rationale to `data-notes.qmd` and METHODOLOGY.md (median of renter-occupied households; B25119 is published in all three windows).
- [ ] Confirm B25119 `estimate_real` for small localities: renter-income cells for Amelia (CV 43) and similar are Low reliability and should be suppressed anywhere they're tabled.

## Chesterfield one-pager (2026-11-23, at the user's request)

- [x] `r/chesterfield_pay.R`, `r/chesterfield_afford.R`, `chesterfield-onepager.qmd` (HTML + one-page Typst PDF), navbar entry, data-notes paragraph. Spec and plan in `design/`.
- [x] 2026-11-24: restyled from the BHC Brand Identity Guide and added cost burden, AMI mix, seniors, household size/bedrooms and growth panels (`r/chesterfield_context.R`, `fonts/`, `rva_guide` in `_common.R`).
- [ ] Reconcile `_brand.yml`, `styles.css` and `rva_brand` with the guide's palette (orange #E86C1F, amber #FBB035, cream #FEE49B, green #8CC63F, sky #ADE0ED, teal #00617F); the current blue/red/brown are CMYK guesses not in the guide.
- [ ] Check the HTML version of the one-pager in a browser (not visually checked 2026-11-24).
- [ ] Optional: CHAS-based senior and small-household need; the page uses ACS.
- [ ] Confirm the adopted FY27 CCPS pay (teacher $57,277, instructional assistant $17.81/hr, bus driver $25.11/hr were *proposed* in Feb 2026). If adopted: mark the old FY26 teacher and bus rows `stale`, mark the FY27 rows `current` in `r/chesterfield_pay.R` (the script now fails if a role has two `current` rows), re-run both scripts, then re-render `chesterfield-onepager.qmd`.
- [ ] Deputy sheriff pay ($56,741) is from a January 2026 posting; re-check against the current posting or pay plan.
- [ ] Source or replace the unsourced insurance (0.35%) and PMI (0.7%) assumptions in `r/chesterfield_afford.R`.
- [ ] Confirm BHC has cleared its logo on the public PDF; decide whether the page needs an "ask" line (needs BHC's position).
- [ ] The public safety pay-plan step table was not found; add mid-career pay if it is published.
- [ ] **User: full `quarto render`** — the navbar changed on every page, and `docs/` for the other pages is stale.

## Future — not in scope right now

- [ ] PUMS gap analysis, CHAS, MLS/CoStar, vulnerable-populations data. The PUMA geography groundwork (`puma_core3`/`puma_region`/`puma_locality`) already exists in `_common.R` if this ever gets picked up — see METHODOLOGY.md.
