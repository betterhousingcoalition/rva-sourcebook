# Chesterfield County affordable-housing one-pager — design

Status: **draft for approval** (2026-11-23). Nothing is built yet.

## Intent

BHC supporters will use this page in public hearings to argue for affordable housing in Chesterfield County. The case it makes: the people who keep the county running (teachers, police, firefighters, deputies, 911 officers, school bus drivers and aides) earn salaries that, on one income, cannot cover a typical Chesterfield rent or home. It should be quotable at a podium, so every number needs a source and a date.

## Goals

- One page, downloadable as a PDF, in BHC branding (`_brand.yml`, logo in `img/`).
- Public service occupations, what they earn (starting pay), and what that pay affords in Chesterfield (rent and home price), set against Chesterfield's median rent and home value.
- Every figure traceable to a county or school-division source, with its date, in a data file rather than typed into the page.
- Also renders as a normal page on the site, with a link to the PDF.

## Non-goals and anti-goals

- No drafted prose (CLAUDE.md narrative rule): a takeaway headline, 2-5 bullet findings, callouts for caveats.
- Not a full wage study. No mid-career or top-of-scale pay in the headline.
- Anti-goal: a number a hearing opponent can knock down. A proposed pay figure shown as current, a stale posting, or a mislabeled annualization would each sink the page. When a figure is uncertain, the page leaves it out.

## Constraints

- Data-flow rule: a prep script writes the pay data, and the page reads it with `read_rds()`. The page calls no APIs.
- Palette and theme from `_common.R`; chart alt text; takeaway titles; subtitle with geography, units and years.
- Single-page PDF. Typst is the first choice, since Quarto bundles it and it reads `_brand.yml`. XeLaTeX (TinyTeX is installed) is the fallback.
- Public-source only.

## Approaches considered

1. **Curated pay table plus a prep script (chosen).** A small `r/chesterfield_pay.R` reads a hand-curated CSV (`data-out/chesterfield_pay.csv`, one row per role, with source URL, effective date and status), validates it, and writes `data/chesterfield_pay.rds`. The page reads that. It keeps sources next to the numbers and follows the repo's data-flow rule.
2. **Salaries typed into the `.qmd`.** Quicker, but the numbers drift and carry no source. Rejected.
3. **Scrape the postings and class specs on every render.** Rejected: pages never call APIs, and the pay sites are script-rendered.

Single earner is the headline (the user's call). A dual-income line appears in the table only.

## What we know: pay data (retrieved 2026-11-23)

All pay figures are gross annual starting pay unless noted. "Hourly" figures are annualized at 2,080 hours, which overstates school-year workers.

| Role | Figure | Source and date | Status |
|---|---|---|---|
| Teacher, bachelor's, step 0 | $55,047 (FY26); $57,277 (FY27) | CCPS "Compensation as a Recruitment and Retention Strategy," Feb 3, 2026 (PDF in repo root); FY27 figure also in the county FY2027 proposed budget letter | FY27 was *proposed* as of Feb 2026; the deck's own scale table prints $57,227, a likely typo |
| Instructional assistant, step 0 | $17.81/hr (FY27 proposed) | same CCPS deck | Proposed. The current FY26 rate is not in the deck |
| School bus driver | $24.15/hr now, $25.11/hr proposed | same CCPS deck | Proposed |
| Police officer (recruit) | $60,147; $62,751 after field training | county Police Officer posting, June 1, 2026 | Posted |
| Firefighter/EMT | $60,147 | county posting 27-00324, opened Oct 26, 2026, closes Dec 6, 2026 | Posted, current |
| Deputy sheriff (recruit) | $56,741 | county posting 26-00482, opened Jan 19, 2026 | Posted, possibly FY26 pay |
| 911 emergency communications officer | $48,447 (minimum) | county class specifications (code 3104) | Not currently posted; class-spec minimum equals the posted hiring minimum for other general-government jobs |

Other facts: the county's older class-spec minimum for police and firefighters ($53,214) is the FY2023 entry rate and is stale. Public-safety starting pay then rose through a 10% increase in FY24 and further adjustments. The FY2027 proposed budget adds a 0.75% midyear starting-pay adjustment and a 2.25% step. The county's public safety pay plan step table was not found, so only the starting and post-field-training figures are used.

HUD FY2026 income limits for the Richmond metro are in `data/summary_county_5176099999.csv` (median family income $113,500; 80% AMI for one person $63,600).

## Affordability method (builder to implement; assumptions marked)

- Maximum affordable rent: 30% of gross monthly income (HUD cost-burden convention). Compare with Chesterfield's median gross rent from `acs_market.rds`.
- Maximum affordable home price: monthly principal, interest, taxes and insurance at 30% of gross income. **My call:** rate from the latest Freddie Mac PMMS, stated on the page with its date; a stated down payment; Chesterfield's real-estate tax rate sourced from the county. Assumptions live in the file header as parameters, never hardcoded in the chart code. Compare with Chesterfield's median home value from `acs_market.rds`.
- Show each role's income as a share of the HUD 80% AMI line for one person.
- ACS median rent and home value are estimates: report the vintage in the caption.

## Page layout (one page, letter size)

```
[BHC logo]   Chesterfield's public servants can't afford to live here   <- takeaway title
             Starting pay vs. what one income affords, Chesterfield County, 2026

 [big number]  [big number]  [big number]
 e.g. median rent   teacher max rent   police/fire max rent

 Chart: starting pay by role (bars) with the pay needed
        for the median rent and median home marked as lines
 Table: role | starting pay | max rent | max home price | vs. median
 Bullets (2-5) and a caveat callout (proposed vs. adopted, annualization)
 Footer: sources with dates; ask line for hearings
```

## Open items for the builder (not settled)

- **Adoption check, most important:** FY27 began July 1, 2026, so the teacher, aide and bus driver figures (proposed in Feb) were probably adopted since. Confirm against the adopted FY27 school budget before labeling any figure "current."
- Fresh deputy sheriff pay, since that posting is from January.
- Whether to show the 911 officer row, given its source is a class spec and not a posting.
- Which assumptions to use for the home-price estimate (rate source, down payment, tax rate).
- Whether Typst renders `_brand.yml` and the logo acceptably; otherwise use XeLaTeX.
- Logo clearance: TODO.md notes BHC has not yet cleared public use of its logo.
- Housekeeping per CLAUDE.md: update TODO.md and LOG.md, add the pay data script, and a `data-notes.qmd` paragraph for the sources.
