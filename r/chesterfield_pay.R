# chesterfield_pay.R ----
# What:   Curated starting pay for Chesterfield County public-service roles
#         (teachers, instructional assistants, school bus drivers, police,
#         firefighter/EMTs, sheriff's deputies, 911 officers), one row per
#         figure, each with its source, source date, and status. Feeds the
#         Chesterfield one-pager (chesterfield-onepager.qmd).
# Source: Chesterfield County HR job postings and class specifications
#         (governmentjobs.com/careers/chesterfieldco); Chesterfield County
#         Public Schools, "Compensation as a Recruitment and Retention
#         Strategy," Feb 3, 2026; Chesterfield County FY2027 Proposed Budget.
#         Retrieved 2026-11-23. Figures are typed from those documents because
#         the sources are script-rendered web pages and PDFs, not APIs.
# Output: data/chesterfield_pay.rds  -- tibble `pay`
#         data-out/chesterfield_pay.csv
#
# status: "current"  = latest figure confirmed in the cited source as of source_date
#         "proposed" = proposed but not confirmed adopted
#         "stale"    = posting or rate that predates the current fiscal year
# Hourly rates are annualized at 2,080 hours (full-time); school-year workers
# earn less over a year.

## 1. Setup ----
library(tidyverse)
source("_common.R") # export_csv()

dir.create("data", showWarnings = FALSE, recursive = TRUE)

## 2. Curated rows ----
pay_rows <- tribble(
  ~role, ~employer, ~basis, ~amount, ~source, ~source_date, ~status, ~note,
  "Teacher", "CCPS", "annual", 55047,
  "CCPS compensation presentation, slide 12 (bachelor's, step 0, FY26 scale)", "2026-02-03", "current",
  "FY26 scale. FY27 began July 1, 2026; adoption of the FY27 scale is not confirmed.",
  "Teacher", "CCPS", "annual", 57277,
  "CCPS compensation presentation slide 12; county FY2027 Proposed Budget letter", "2026-02-03", "proposed",
  "FY27 proposed starting salary. The deck's own scale table prints $57,227, a likely typo.",
  "Instructional assistant", "CCPS", "hourly", 17.81,
  "CCPS compensation presentation, FY27 Proposed IA Scale (IA-1, step 0)", "2026-02-03", "proposed",
  "FY27 proposed; the FY26 rate is not in the deck. Annualized at 2,080 hours.",
  "School bus driver", "CCPS", "hourly", 24.15,
  "CCPS compensation presentation, Transportation Compensation slide", "2026-02-03", "current",
  "Current starting rate per the deck. Annualized at 2,080 hours.",
  "School bus driver", "CCPS", "hourly", 25.11,
  "CCPS compensation presentation, Proposed Transportation Scale (T1, step 0)", "2026-02-03", "proposed",
  "FY27 proposed starting rate. Annualized at 2,080 hours.",
  "Police officer", "County", "annual", 60147,
  "chesterfield.gov Police Officer recruitment posting (CivicAlerts AID=5439)", "2026-06-01", "current",
  "Recruit starting salary until training completes; $62,751 after field training, $64,163 after Step 2.",
  "Firefighter/EMT", "County", "annual", 60147,
  "governmentjobs.com/careers/chesterfieldco posting 27-00324 (Fire)", "2026-10-26", "current",
  "Posting closes 2026-12-06.",
  "Deputy sheriff", "County", "annual", 56741,
  "governmentjobs.com/careers/chesterfieldco posting 26-00482 (Sheriff)", "2026-01-19", "stale",
  "Recruit starting salary from a January 2026 posting; may predate FY27 pay.",
  "911 officer", "County", "annual", 48447,
  "governmentjobs.com/careers/chesterfieldco class specification, ECC Officer (code 3104), minimum", "2026-11-23", "current",
  "Class-spec minimum, not a posting; no ECC Officer posting was open on the retrieval date."
)

## 3. Derive and write ----
pay <- pay_rows |>
  mutate(
    source_date = as.Date(source_date),
    annual_pay = if_else(basis == "hourly", round(amount * 2080), amount)
  )

write_rds(pay, "data/chesterfield_pay.rds")
export_csv(pay, "chesterfield_pay")

## 4. Validation ----
need_roles <- c(
  "Teacher", "Instructional assistant", "School bus driver",
  "Police officer", "Firefighter/EMT", "Deputy sheriff", "911 officer"
)
stopifnot(
  "a role is missing" = all(need_roles %in% pay$role),
  "required field is NA" = !anyNA(pay[c("role", "annual_pay", "source", "source_date", "status")]),
  "bad status" = all(pay$status %in% c("current", "proposed", "stale")),
  "hourly annualization wrong" = with(
    filter(pay, basis == "hourly"), all(annual_pay == round(amount * 2080))
  )
)
stopifnot(
  "each role may have at most one 'current' row (mark superseded rows 'stale')" =
    all(count(filter(pay, status == "current"), role)$n == 1)
)
pin <- function(r, st, v) {
  got <- pay |> filter(role == r, status == st) |> pull(annual_pay)
  if (!(v %in% got)) stop(r, " (", st, ") should be ", v, call. = FALSE)
}
pin("Police officer", "current", 60147)
pin("Firefighter/EMT", "current", 60147)
pin("911 officer", "current", 48447)
pin("Teacher", "current", 55047)
pin("Teacher", "proposed", 57277)

cat("chesterfield_pay: validation passed,", nrow(pay), "rows\n")
print(pay |> select(role, annual_pay, status, source_date), n = Inf)
