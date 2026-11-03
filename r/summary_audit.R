# summary_audit.R
# What:   Margins of error and independent re-computation for the figures that
#         summary.qmd quotes to external audiences (the BHC section's table and
#         the claims that sit closest to a margin of error).
# Source: data/acs_*.rds (ACS 5-year, published 90% MOEs), data/pums_profiles.rds
#         (PUMS replicate-weight SEs), data/hmda_data.parquet + data/hmda.rds,
#         data-out/*-virginia-filings.csv + data/evict.rds.
# Output: data/summary_audit.rds, data-out/summary_audit.csv
#         (key, figure, estimate, 90% MOE, relative MOE, precision tier, note)

## 1. Setup ----
source("_common.R")
library(arrow)

b <- read_rds("data/acs_burden.rds")
mk <- read_rds("data/acs_market.rds")
d <- read_rds("data/acs_demographics.rds")
P <- read_rds("data/pums_profiles.rds")
hm <- read_rds("data/hmda.rds")
ev <- read_rds("data/evict.rds")
lv <- P$levels$ami5

# Census conventions: ACS MOEs are 90%; PUMS SEs convert with 1.645.
# na.rm: the 2014 under-18 cells of the pooled rows have no published MOE (a
# component locality reports none); omitting them understates a ~1.2M-person
# denominator MOE by well under 0.1% of the population, immaterial for shares.
rss <- \(x) sqrt(sum(x^2, na.rm = TRUE))
# MOE of a proportion n/den (Census handbook formula; falls back to the sum form).
pmoe <- function(n, mn, den, md) {
  p <- n / den
  v <- mn^2 - p^2 * md^2
  if (v < 0) v <- mn^2 + p^2 * md^2
  sqrt(v) / den
}
rows <- list()
add <- function(key, figure, est, moe, kind, source, note = "") {
  rows[[length(rows) + 1]] <<- tibble(
    key = key, figure = figure, est = est, moe90 = moe, kind = kind, source = source, note = note
  )
}

## 2. ACS figures (published MOEs) ----
bshare <- function(g, ten, yr, cats) {
  x <- b |> filter(geoid == g, tenure == ten, year == yr, burden != "Not computed")
  y <- x |> filter(burden %in% cats)
  c(sum(y$estimate) / sum(x$estimate), pmoe(sum(y$estimate), rss(y$moe), sum(x$estimate), rss(x$moe)))
}
for (yr in c(2014, 2024)) {
  r <- bshare("rr17", "Renter", yr, c("Cost-burdened", "Severely cost-burdened"))
  add(paste0("renter_b30_", yr), paste("Renters paying 30%+ of income on housing,", yr), r[1], r[2], "pct", "ACS B25070")
}
r <- bshare("rr17", "Renter", 2024, "Severely cost-burdened")
add("renter_b50_2024", "Renters paying 50%+ of income on housing, 2024", r[1], r[2], "pct", "ACS B25070")

x <- d$age_sex |> filter(geoid == "rr17")
for (yr in c(2014, 2024)) {
  xx <- x |> filter(year == yr)
  n <- xx |> filter(age_group == "65 and over")
  add(paste0("pop65_", yr), paste("Population 65+ share,", yr), sum(n$estimate) / sum(xx$estimate),
    pmoe(sum(n$estimate), rss(n$moe), sum(xx$estimate), rss(xx$moe)), "pct", "ACS B01001")
}

inc <- d$median_income |> filter(geoid == "40060")
for (yr in c(2014, 2024)) {
  v <- mk$median_value |> filter(geoid == "40060", year == yr)
  i <- inc |> filter(year == yr)
  R <- v$estimate / i$estimate
  add(paste0("pti_", yr), paste("Median home value / median household income,", yr), R,
    sqrt(v$moe^2 + R^2 * i$moe^2) / i$estimate, "ratio", "ACS B25077, B19013")
}
chg <- function(f) {
  a <- f |> filter(year == 2014)
  z <- f |> filter(year == 2024)
  c(z$estimate_real / a$estimate_real - 1,
    sqrt(z$moe_real^2 + (z$estimate_real / a$estimate_real)^2 * a$moe_real^2) / a$estimate_real)
}
r <- chg(mk$median_value |> filter(geoid == "40060"))
add("value_real_chg", "Real change in median home value, 2014-2024", r[1], r[2], "pct", "ACS B25077")
r <- chg(mk$median_rent |> filter(geoid == "40060"))
add("rent_real_chg", "Real change in median gross rent, 2014-2024", r[1], r[2], "pct", "ACS B25064")
r <- chg(inc)
add("income_real_chg", "Real change in median household income, 2014-2024", r[1], r[2], "pct", "ACS B19013",
  "Rent and income changes are within each other's margins of error; do not say rent outpaced income.")

## 3. PUMS figures (90% MOE = 1.645 x SE) ----
bc <- P$band_counts |> filter(unit == "Households")
pf <- \(tp, cat, band, ten) P$profile |> filter(unit == "Households", topic == tp, category == cat, ami5 == band, tenure == ten)
cnt <- function(bands, ten) {
  x <- bc |> filter(ami5 %in% bands, tenure == ten)
  c(sum(x$est), 1.645 * rss(x$se))
}
le <- P$le80 |> filter(unit == "Households", geo == "Core three", tenure == "All households")
add("le80_all", "Core-three households at or below 80% of AMI", le$est, 1.645 * le$se, "pct", "ACS PUMS 2020-2024")
r <- cnt(lv[1:3], "Renter")
add("renters_le80", "Core-three renter households at or below 80% of AMI", r[1], r[2], "n", "ACS PUMS 2020-2024")
r <- cnt(lv[1:3], "Owner")
add("owners_le80", "Core-three owner households at or below 80% of AMI", r[1], r[2], "n", "ACS PUMS 2020-2024")
x <- pf("Cost burden", "Severely cost-burdened (50%+)", lv[1], "Renter")
add("renter_le30_sev", "Renters at or below 30% of AMI paying 50%+ of income", x$est, 1.645 * x$se, "pct", "ACS PUMS 2020-2024")
x1 <- pf("Cost burden", "Cost-burdened (30-49%)", lv[5], "Renter")
x2 <- pf("Cost burden", "Severely cost-burdened (50%+)", lv[5], "Renter")
add("renter_gt120_b30", "Renters above 120% of AMI paying 30%+ of income", x1$est + x2$est, 1.645 * rss(c(x1$se, x2$se)), "pct",
  "ACS PUMS 2020-2024", paste0("Small sample (", min(x1$n_obs, x2$n_obs), " cases in the smaller category); quote as 'about 3%'."))
# Seniors: count x share by band, delta method, treating count and share as independent.
sen <- function(bands, ten) {
  est <- 0
  v <- 0
  for (bd in bands) {
    c1 <- bc |> filter(ami5 == bd, tenure == ten)
    s1 <- pf("Householder age", "65 and over", bd, ten)
    est <- est + c1$est * s1$est
    v <- v + (c1$est * s1$se)^2 + (s1$est * c1$se)^2
  }
  c(est, 1.645 * sqrt(v))
}
r <- sen(lv[1:2], "Renter")
n_sen <- sum(map_dbl(lv[1:2], \(bd) pf("Householder age", "65 and over", bd, "Renter")$n_obs * pf("Householder age", "65 and over", bd, "Renter")$est))
add("senior_renters_le50", "Renter households at or below 50% of AMI with a householder 65+", r[1], r[2], "n",
  "ACS PUMS 2020-2024", paste0("Derived (count x share); roughly ", round(n_sen), " sample households. Quote as 'about 12,000'."))
rr_le50 <- cnt(lv[1:2], "Renter")
add("senior_share_renters_le50", "65+ share of renter households at or below 50% of AMI", r[1] / rr_le50[1], r[2] / rr_le50[1], "pct",
  "ACS PUMS 2020-2024", "Approximate MOE (ignores the numerator-denominator overlap).")
r <- sen(lv[1:2], "Owner")
add("senior_owners_le50", "Owner households at or below 50% of AMI with a householder 65+", r[1], r[2], "n", "ACS PUMS 2020-2024",
  "Derived (count x share).")
d5 <- P$dist5 |> filter(unit == "Households", tenure == "Renter", measure == "count", geo != "Core three", band %in% lv[1:3])
g <- d5 |> summarise(n = sum(est), v = sum(se^2), .by = geo)
city <- g |> filter(geo == "Richmond city")
p <- city$n / sum(g$n)
add("low_renter_city", "Share of lower-income renters living in Richmond city", p,
  1.645 * sqrt((1 - p)^2 * city$v + p^2 * (sum(g$v) - city$v)) / sum(g$n), "pct", "ACS PUMS 2020-2024")

## 4. HMDA: administrative records, so the interval is descriptive only ----
# HMDA covers reporting lenders' applications in full (no sampling), so a
# binomial interval only shows how much a rate moves with the number of cases.
by <- hm$by_race |>
  filter(activity_year %in% (max(activity_year) - 3):max(activity_year)) |>
  summarise(den = sum(denied), n = sum(decided_apps), .by = race_ethnicity) |>
  mutate(rate = den / n, moe = 1.645 * sqrt(rate * (1 - rate) / n))
for (grp in c("Black", "White, non-Hispanic", "Hispanic or Latino")) {
  x <- by |> filter(race_ethnicity == grp)
  add(paste0("denial_", str_extract(grp, "^[A-Za-z]+")), paste("Home-purchase denial rate,", grp), x$rate, x$moe, "pct",
    "HMDA", paste0(format(x$n, big.mark = ","), " decided applications, last four years. Excludes withdrawn and incomplete files."))
}
share_unknown <- by |> filter(race_ethnicity == "Incomplete/No Data") |> pull(n) / sum(by$n)
add("hmda_unknown_race", "Decided home-purchase applications with no race/ethnicity", share_unknown, NA_real_, "pct", "HMDA",
  "Groups are not fully comparable: this share is excluded from every named group.")

## 5. Evictions: court records, no sampling error; baseline is undocumented ----
add("evict_pct_hist", "Latest 12 months as a percent of the historical average",
  ev$summary |> filter(geoid == "bhc3") |> pull(latest12_pct_hist) / 100, NA_real_, "pct", "Eviction court filings",
  "Baseline is the data provider's and is not documented; quote the 2016-19 comparison from counts.")
add("evict_vs_pre", "Latest 12 months vs. 2016-19 monthly mean",
  ev$summary |> filter(geoid == "bhc3") |> pull(latest12_vs_pre), NA_real_, "pct", "Eviction court filings")

## 6. Tier, write ----
audit <- bind_rows(rows) |>
  mutate(
    rel_moe = moe90 / abs(est),
    precision = case_when(
      is.na(moe90) ~ "Not sampled",
      rel_moe > 0.30 ~ "Low",
      rel_moe > 0.15 ~ "Moderate",
      .default = "High"
    ),
    moe_text = case_when(
      is.na(moe90) ~ "n/a (not a sample)",
      kind == "pct" ~ sprintf("±%.1f pts", moe90 * 100),
      kind == "ratio" ~ sprintf("±%.2f", moe90),
      .default = paste0("±", scales::label_comma(accuracy = 1)(signif(moe90, 2)))
    )
  )

write_rds(audit, "data/summary_audit.rds")
export_csv(audit, "summary_audit")

## 7. Validation ----
# Independent re-computation from the raw HMDA and eviction files; these are
# same-vintage structural checks, so they gate the build.
hr <- read_parquet("data/hmda_data.parquet") |>
  filter(county_code %in% bhc, occupancy_type == "Principal residence", str_starts(dwelling_category, "Single Family"))
hp <- hr |> filter(loan_purpose == "Home purchase")
yr_last <- max(hr$activity_year)
raw_orig <- sum(hp$activity_year == yr_last & hp$action_taken == "Loan originated")
stopifnot(
  "HMDA home-purchase originations differ from data/hmda.rds" =
    raw_orig == hm$rates |> filter(geoid == "bhc3", purpose == "Home purchase", activity_year == yr_last) |> pull(originated)
)
dec <- c("Loan originated", "Application approved but not accepted", "Application denied")
w <- hp |> filter(activity_year > yr_last - 4, action_taken %in% dec, race_ethnicity == "Black")
stopifnot("Black denial rate differs from raw HMDA" =
  abs(mean(w$action_taken == "Application denied") - (by |> filter(race_ethnicity == "Black") |> pull(rate))) < 1e-9)

files <- list.files("data-out", pattern = "-virginia-filings\\.csv$", full.names = TRUE)
raw_ev <- map(files, \(f) read_csv(f, show_col_types = FALSE)) |> list_rbind()
raw_tot <- raw_ev |>
  mutate(yr = year(as_date(month_start_date))) |>
  summarise(n = sum(filings_count), .by = yr)
frame_tot <- ev$annual |> filter(geoid == "bhc3") |> select(yr = year, n = filings)
stopifnot(
  "eviction annual totals differ from raw exports" =
    isTRUE(all.equal(arrange(raw_tot, yr), arrange(frame_tot, yr), check.attributes = FALSE))
)

message("Audit rows: ", nrow(audit))
print(audit |> select(figure, est, moe_text, precision) |> mutate(est = signif(est, 4)), n = Inf, width = Inf)
message("Low/Moderate precision: ", paste(audit$key[audit$precision %in% c("Low", "Moderate")], collapse = ", "))
