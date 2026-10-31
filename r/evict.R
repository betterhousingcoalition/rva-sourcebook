# evict.R ----
# What:   Combines the three monthly eviction-filing exports (Richmond city,
#         Henrico, Chesterfield) into one tidy frame and derives the series the
#         market page needs: monthly filings and defaults by locality, a
#         core-three total, an annual rollup, and a pre-pandemic comparison.
#         Evictions are a housing-stability indicator that sits beside the ACS
#         cost-burden figures.
# Source: Monthly eviction filing records from the general district courts,
#         saved by hand to data-out/<locality>-virginia-filings.csv (one file
#         per locality; columns month_start_date, jurisdiction, filings_count,
#         percent_of_historical_average, defaults_count, defaults_comparison).
#         The "historical average" baseline is the source's own and is not
#         documented in the export; it is carried through, not recomputed.
# Output: data/evict.rds   -- named list of 3 frames (monthly, annual, summary)
#         data-out/evict_monthly.csv, evict_annual.csv -- tidy exports

## 1. Setup ----
library(tidyverse)
library(janitor)
source("_common.R") # export_csv()

dir.create("data", showWarnings = FALSE, recursive = TRUE)

evict_files <- c(
  "richmond-city" = "data-out/richmond-city-virginia-filings.csv",
  "henrico"       = "data-out/henrico-virginia-filings.csv",
  "chesterfield"  = "data-out/chesterfield-virginia-filings.csv"
)
stopifnot("input CSVs missing" = all(file.exists(evict_files)))

# Join keys: Richmond city is FIPS 51760, Henrico 51087, Chesterfield 51041.
loc_lookup <- tibble(
  file_key = names(evict_files),
  geoid    = c("51760", "51087", "51041"),
  locality = c("Richmond city", "Henrico", "Chesterfield")
)

## 2. Read and combine ----
raw <- evict_files |>
  imap(\(path, key) {
    read_csv(path, col_types = cols(.default = col_character())) |>
      clean_names() |>
      mutate(file_key = key)
  }) |>
  list_rbind()

## 3. Clean ----
# month_start_date carries a noon timestamp; keep the date. defaults_comparison
# is empty in every file, so it is dropped (checked in the validation block).
# Do not rely on the jurisdiction string for identity: the file key decides it,
# and the string is only cross-checked.
monthly_loc <- raw |>
  select(-defaults_comparison) |>
  mutate(
    month    = as_date(ymd_hms(month_start_date)),
    filings  = as.integer(filings_count),
    defaults = as.integer(defaults_count),
    pct_hist = as.numeric(percent_of_historical_average)
  ) |>
  left_join(loc_lookup, by = "file_key") |>
  mutate(
    year = year(month),
    # Implied monthly baseline from the source's own percent-of-average figure,
    # so the region's percent can be rebuilt as a ratio of sums, not an average
    # of percents.
    baseline = filings / (pct_hist / 100),
    # The first defaults value of each series (Jan 2016) is a partial count: it
    # is a few dozen against hundreds in every later month. Treat it as missing.
    defaults = if_else(month == min(month), NA_integer_, defaults),
    default_share = defaults / filings
  ) |>
  select(month, year, geoid, locality, filings, defaults, default_share,
         pct_hist, baseline) |>
  arrange(locality, month)

# Core-three total (Richmond city + Henrico + Chesterfield).
monthly_core <- monthly_loc |>
  summarise(
    filings  = sum(filings),
    defaults = if_else(any(is.na(defaults)), NA_integer_, sum(defaults)),
    baseline = sum(baseline),
    .by = c(month, year)
  ) |>
  mutate(
    geoid = "bhc3",
    locality = "Richmond core",
    default_share = defaults / filings,
    pct_hist = 100 * filings / baseline
  )

monthly <- bind_rows(monthly_loc, monthly_core) |>
  arrange(geoid, month)

## 4. Analysis ----
# The latest calendar year in the files may be incomplete. Annual figures flag
# it rather than silently comparing a partial year with full ones.
last_month <- max(monthly$month)
months_per_year <- monthly |>
  filter(geoid == "bhc3") |>
  count(year, name = "n_months")

annual <- monthly |>
  summarise(
    filings  = sum(filings),
    defaults = sum(defaults, na.rm = TRUE),
    baseline = sum(baseline),
    n_months = n(),
    .by = c(geoid, locality, year)
  ) |>
  mutate(
    default_share = defaults / filings,
    pct_hist = 100 * filings / baseline,
    complete_year = n_months == 12
  ) |>
  # 2016 defaults miss January, so the 2016 default total is understated.
  mutate(defaults = if_else(year == min(year), NA_integer_, defaults),
         default_share = if_else(year == min(year), NA_real_, default_share)) |>
  arrange(geoid, year)

# Summary: pre-pandemic (2016-2019) monthly mean vs the latest 12 months.
pre_years <- 2016:2019
latest12 <- seq(last_month, by = "-1 month", length.out = 12)

summary_tbl <- monthly |>
  summarise(
    pre_mean_filings    = mean(filings[year %in% pre_years]),
    min_filings         = min(filings),
    min_month           = month[which.min(filings)],
    low_month_filings   = filings[month == as_date("2020-05-01")],
    latest12_mean       = mean(filings[month %in% latest12]),
    latest12_pct_hist   = 100 * sum(filings[month %in% latest12]) /
      sum(baseline[month %in% latest12]),
    peak_filings        = max(filings),
    peak_month          = month[which.max(filings)],
    .by = c(geoid, locality)
  ) |>
  mutate(latest12_vs_pre = latest12_mean / pre_mean_filings - 1)

## 5. Write ----
evict <- list(monthly = monthly, annual = annual, summary = summary_tbl,
              last_month = last_month)
write_rds(evict, "data/evict.rds")
export_csv(select(monthly, -baseline), "evict_monthly")
export_csv(select(annual, -baseline), "evict_annual")

## 6. Validation ----
# Structural checks hard-fail; the vintage-style comparisons are logged only.
stopifnot(
  "expected 3 localities x 128 months" =
    nrow(monthly_loc) == 3 * n_distinct(monthly_loc$month),
  "each locality has the same months" =
    n_distinct(count(monthly_loc, locality)$n) == 1,
  "no duplicate locality-months" =
    !anyDuplicated(monthly_loc[c("geoid", "month")]),
  "months are not contiguous" =
    all(diff(sort(unique(monthly_loc$month))) %in% 28:31),
  "defaults_comparison not empty -- inspect before dropping" =
    all(is.na(raw$defaults_comparison) | raw$defaults_comparison == ""),
  "no all-NA columns" = !any(map_lgl(monthly, \(x) all(is.na(x)))),
  "jurisdiction string disagrees with file key" =
    all(str_detect(str_to_lower(raw$jurisdiction),
                   str_replace(raw$file_key, "-", " "))),
  "core total equals sum of localities" =
    sum(monthly_core$filings) == sum(monthly_loc$filings),
  "defaults exceed filings somewhere" =
    all(monthly$defaults <= monthly$filings, na.rm = TRUE)
)

message("Months: ", min(monthly$month), " to ", last_month)
message("Months per year (core):")
print(months_per_year)
message("Latest month: ", last_month,
        " -- check whether the source counts it as complete before quoting it.")

message("Annual core filings and % of historical average:")
annual |>
  filter(geoid == "bhc3") |>
  select(year, filings, defaults, pct_hist, complete_year) |>
  mutate(pct_hist = round(pct_hist, 1)) |>
  print(n = Inf)

message("Summary (logged, not gated):")
print(summary_tbl |> mutate(across(where(is.double), \(x) round(x, 2))), width = Inf)

# Flag implausible percent-of-average swings for review.
big <- monthly_loc |> filter(pct_hist > 200 | pct_hist < 20)
message("Locality-months with pct of average >200 or <20: ", nrow(big))
