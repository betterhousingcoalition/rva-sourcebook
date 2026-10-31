# hmda_prep.R ----
# What:   Narrows the regional HMDA file to the core three localities (Richmond
#         city, Henrico, Chesterfield) and builds the mortgage-lending series
#         the market page uses: loans originated for a principal residence, and
#         application denial rates by year, locality, loan purpose, and
#         applicant race/ethnicity, plus the stated reasons for denial.
# Source: Home Mortgage Disclosure Act (HMDA) public loan-level data, CFPB/FFIEC
#         data browser, 2018-2025. Pulled and recoded by r/hmda.R, which writes
#         data/hmda_data.parquet (17 `rr` localities; this script does not
#         re-pull).
# Rules:  - Scope: principal residence, 1-4 unit properties (Single Family
#           dwelling categories). Second homes and investor loans are excluded;
#           multifamily is excluded.
#         - Application outcome (the denominator of every denial rate) is the
#           applications that reached a credit decision: originated (1),
#           approved but not accepted (2), or denied (3). Withdrawn (4), closed
#           for incompleteness (5), purchased loans (6) and preapproval
#           requests (7, 8) are not decisions on an application and are left
#           out. Denial rate = denied / (originated + approved-not-accepted +
#           denied).
#         - Race/ethnicity uses the grouping already built in r/hmda.R. Small
#           groups are flagged by an application-count floor, not a CV.
# Output: data/hmda.rds -- named list (originations, rates, by_race, reasons)
#         data-out/hmda_rates.csv, hmda_by_race.csv, hmda_denial_reasons.csv

## 1. Setup ----
library(tidyverse)
library(arrow)
source("_common.R") # bhc, export_csv()

dir.create("data", showWarnings = FALSE, recursive = TRUE)
stopifnot("run r/hmda.R first" = file.exists("data/hmda_data.parquet"))

# Below this many decided applications a rate is too noisy to quote.
min_apps <- 100

loc_labels <- c(
  "51760" = "Richmond city",
  "51087" = "Henrico",
  "51041" = "Chesterfield",
  "bhc3"  = "Richmond core"
)

## 2. Read and scope ----
hmda <- read_parquet("data/hmda_data.parquet") |>
  filter(
    county_code %in% bhc,
    occupancy_type == "Principal residence",
    str_starts(dwelling_category, "Single Family")
  ) |>
  mutate(
    loan_amount = as.numeric(loan_amount),
    geoid = county_code,
    # Denial reason codes: https://ffiec.cfpb.gov/documentation (denial_reason)
    decided = action_taken %in%
      c("Loan originated", "Application approved but not accepted",
        "Application denied"),
    originated = action_taken == "Loan originated",
    denied = action_taken == "Application denied"
  )

## 3. Originations and denial rates ----
# Locality rows plus a pooled core row, at two purpose grains: all purposes and
# home purchase only (the cleanest measure of access to ownership).
with_core <- \(df) bind_rows(df, mutate(df, geoid = "bhc3"))
with_purpose <- \(df) bind_rows(
  mutate(df, purpose = "All purposes"),
  df |> filter(loan_purpose == "Home purchase") |> mutate(purpose = "Home purchase")
)

rates <- hmda |>
  with_purpose() |>
  with_core() |>
  summarise(
    originated = sum(originated),
    denied = sum(denied),
    decided_apps = sum(decided),
    median_loan = median(loan_amount[originated], na.rm = TRUE),
    .by = c(geoid, activity_year, purpose)
  ) |>
  mutate(
    locality = unname(loc_labels[geoid]),
    denial_rate = denied / decided_apps
  ) |>
  arrange(geoid, purpose, activity_year)

## 4. Denial rate by race/ethnicity (core pooled, home purchase) ----
# Single years of a group within three localities get thin, so the table pools
# the core and carries the application count for a reliability floor.
by_race <- hmda |>
  filter(loan_purpose == "Home purchase", decided) |>
  summarise(
    decided_apps = n(),
    originated = sum(originated),
    denied = sum(denied),
    .by = c(activity_year, race_ethnicity)
  ) |>
  mutate(
    denial_rate = denied / decided_apps,
    reliable = decided_apps >= min_apps
  ) |>
  arrange(race_ethnicity, activity_year)

## 5. Stated reasons for denial (core pooled, latest four years) ----
reason_labels <- c(
  "1" = "Debt-to-income ratio", "2" = "Employment history",
  "3" = "Credit history", "4" = "Collateral", "5" = "Insufficient cash",
  "6" = "Unverifiable information", "7" = "Credit application incomplete",
  "8" = "Mortgage insurance denied", "9" = "Other"
)
reason_years <- max(hmda$activity_year) - 3:0

reasons <- hmda |>
  filter(denied, activity_year %in% reason_years) |>
  select(activity_year, starts_with("denial_reason")) |>
  mutate(.row = row_number()) |>
  pivot_longer(starts_with("denial_reason"), values_to = "code") |>
  filter(!is.na(code), !code %in% c(10, 1111)) |> # 10 = n/a, 1111 = exempt
  mutate(reason = unname(reason_labels[as.character(code)])) |>
  # A denial can cite up to four reasons; count each denial once per reason.
  distinct(.row, reason) |>
  count(reason, name = "denials") |>
  mutate(
    n_denied = sum(hmda$denied & hmda$activity_year %in% reason_years),
    share_of_denials = denials / n_denied
  ) |>
  arrange(desc(denials))

## 6. Write ----
hmda_out <- list(
  rates = rates, by_race = by_race, reasons = reasons,
  min_apps = min_apps, reason_years = reason_years
)
write_rds(hmda_out, "data/hmda.rds")
export_csv(rates, "hmda_rates")
export_csv(by_race, "hmda_by_race")
export_csv(reasons, "hmda_denial_reasons")

## 7. Validation ----
# Structural checks hard-fail; year-over-year swings are logged for review.
core <- rates |> filter(geoid == "bhc3")
locs <- rates |> filter(geoid != "bhc3")
stopifnot(
  "all three localities present" = setequal(unique(locs$geoid), bhc),
  "all activity years present" = setequal(unique(rates$activity_year), 2018:2025),
  "core originations = sum of localities" =
    sum(core$originated) == sum(locs$originated),
  "denial rates outside 0-1" = all(rates$denial_rate >= 0 & rates$denial_rate <= 1,
                                   na.rm = TRUE),
  "originated + denied exceeds decided" =
    all(rates$originated + rates$denied <= rates$decided_apps),
  "no all-NA columns" = !any(map_lgl(rates, \(x) all(is.na(x)))),
  "reason shares should not exceed 100% per denial" =
    all(reasons$share_of_denials <= 1)
)

message("Core originations, principal residence (all purposes / home purchase):")
core |>
  select(activity_year, purpose, originated, decided_apps, denial_rate) |>
  mutate(denial_rate = round(denial_rate, 3)) |>
  print(n = Inf)

message("Core home-purchase originations, yoy % change (flag if beyond +/-40%):")
yoy <- core |>
  filter(purpose == "Home purchase") |>
  mutate(chg = originated / lag(originated) - 1)
print(select(yoy, activity_year, originated, chg))
message("Years flagged: ", paste(yoy$activity_year[abs(yoy$chg) > 0.4], collapse = ", "))

message("Race/ethnicity cells below the ", min_apps, "-application floor: ",
        sum(!by_race$reliable), " of ", nrow(by_race))
message("Denial reasons (core, ", min(reason_years), "-", max(reason_years), "):")
print(reasons)
message("Missing loan_amount among core originations: ",
        sum(is.na(hmda$loan_amount[hmda$originated])))
