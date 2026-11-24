# chesterfield_context.R ----
# What:   Chesterfield County (51041) demand-side context for the one-pager:
#         household size by tenure, bedrooms by tenure (supply of small homes),
#         age of householder by tenure (seniors), and cost burden by age of
#         householder (seniors vs. everyone). Complements acs_burden, acs_demographics,
#         pep_migration and pums_ami_dist, which the page reads directly.
# Source: tidycensus ACS 5-year, survey years 2014 / 2019 / 2024 (2024 = 2020-2024).
# Tables: B25074 (renter households by household income), B25009 (tenure by household size), B25042 (tenure by bedrooms),
#         B25007 (tenure by age of householder), B25072 (renter gross rent as a
#         share of income, by age of householder), B25093 (owner costs as a share
#         of income, by age of householder).
# Geo:    Chesterfield County, VA only.
# Output: data/chesterfield_context.rds -- list(hh_size, bedrooms, hh_age, burden_age)
#         data-out/chesterfield_hh_size.csv, _bedrooms.csv, _hh_age.csv, _burden_age.csv

## 1. Setup ----
library(tidyverse)
library(tidycensus)
library(janitor)
source("_common.R") # export_csv()

if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- file.path(Sys.getenv("USERPROFILE"), "Documents", ".Renviron")
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}
message("CENSUS_API_KEY present: ", Sys.getenv("CENSUS_API_KEY") != "")

dir.create("data", showWarnings = FALSE, recursive = TRUE)

## 2. Pull helper ----
# One table, Chesterfield only, with the label split on "!!" so each level of the
# table hierarchy is its own column (l1 = first level under "Total:", and so on).
pull_tbl <- function(table, yr) {
  labs <- load_variables(yr, "acs5", cache = TRUE) |>
    filter(str_starts(name, paste0(table, "_"))) |>
    select(variable = name, label)
  get_acs(
    geography = "county", state = "VA", county = "041",
    table = table, year = yr, survey = "acs5", cache_table = TRUE
  ) |>
    clean_names() |>
    select(geoid, variable, estimate, moe) |>
    left_join(labs, by = "variable") |>
    mutate(
      year = yr,
      label = str_remove_all(label, "^Estimate!!|:$") |> str_remove_all(":")
    ) |>
    separate_wider_delim(label, "!!", names = c("total", "l1", "l2", "l3"),
                         too_few = "align_start", too_many = "drop")
}

years <- c(2014, 2019, 2024)

## 3. Household size by tenure (B25009) ----
hh_size <- map(years, \(y) pull_tbl("B25009", y)) |>
  list_rbind() |>
  filter(!is.na(l2)) |>
  transmute(
    year,
    tenure = l1,
    size = case_match(l2, "1-person household" ~ "1 person", "2-person household" ~ "2 people",
                      .default = "3+ people"),
    estimate, moe
  ) |>
  summarise(estimate = sum(estimate), moe = sqrt(sum(moe^2)), .by = c(year, tenure, size))

## 4. Bedrooms by tenure (B25042), 2024 and 2014 ----
bedrooms <- map(c(2014, 2024), \(y) pull_tbl("B25042", y)) |>
  list_rbind() |>
  filter(!is.na(l2)) |>
  transmute(
    year,
    tenure = l1,
    bedrooms = case_match(l2, c("No bedroom", "1 bedroom") ~ "0-1 bedroom", "2 bedrooms" ~ "2 bedrooms",
                          .default = "3+ bedrooms"),
    estimate, moe
  ) |>
  summarise(estimate = sum(estimate), moe = sqrt(sum(moe^2)), .by = c(year, tenure, bedrooms))

## 5. Householder age by tenure (B25007) ----
hh_age <- map(years, \(y) pull_tbl("B25007", y)) |>
  list_rbind() |>
  filter(!is.na(l2)) |>
  transmute(
    year,
    tenure = l1,
    age = if_else(str_detect(l2, "65 to 74|75 to 84|85 years"), "65 and over", "Under 65"),
    estimate, moe
  ) |>
  summarise(estimate = sum(estimate), moe = sqrt(sum(moe^2)), .by = c(year, tenure, age))

## 6. Cost burden by age of householder (B25072 renters, B25093 owners), 2024 ----
# Burdened = 30%+ of income on housing (the "not computed" rows are dropped).
renter_b <- pull_tbl("B25072", 2024) |>
  filter(!is.na(l2)) |>
  mutate(tenure = "Renter", age = l1, band = l2)
owner_b <- pull_tbl("B25093", 2024) |>
  filter(!is.na(l2)) |>
  mutate(tenure = "Owner", age = l1, band = l2)

burden_age <- bind_rows(renter_b, owner_b) |>
  filter(!str_detect(band, "(?i)not computed")) |>
  mutate(
    age = if_else(str_detect(age, "65 years and over"), "65 and over", "Under 65"),
    burdened = str_detect(band, "^(30|35|40|50)\\.0 ")
  ) |>
  summarise(estimate = sum(estimate), moe = sqrt(sum(moe^2)), .by = c(tenure, age, burdened)) |>
  mutate(year = 2024)

## 7. Renter households by household income (B25074), 2014 / 2019 / 2024 ----
# Income bands are nominal dollars in each ACS window, so band counts are not
# comparable across years without an inflation adjustment; the page uses the
# renter totals and the burden counts instead.
renter_income <- map(years, \(y) pull_tbl("B25074", y)) |>
  list_rbind() |>
  filter(!is.na(l1)) |>
  mutate(income = l1) |>
  summarise(estimate = sum(estimate[is.na(l2)]), moe = sqrt(sum(moe[is.na(l2)]^2)), .by = c(year, income))

## 8. Write ----
ctx <- list(hh_size = hh_size, bedrooms = bedrooms, hh_age = hh_age, burden_age = burden_age,
            renter_income = renter_income)
write_rds(ctx, "data/chesterfield_context.rds")
export_csv(hh_size, "chesterfield_hh_size")
export_csv(bedrooms, "chesterfield_bedrooms")
export_csv(hh_age, "chesterfield_hh_age")
export_csv(burden_age, "chesterfield_burden_age")
export_csv(renter_income, "chesterfield_renter_income")

## 9. Validation ----
# Same-vintage benchmark: household totals must equal B25003 in acs_market.rds.
mk <- read_rds("data/acs_market.rds")
tot_b25003 <- mk$tenure |> filter(geoid == "51041", year == 2024, tenure == "Total") |> pull(estimate)
tot_size <- hh_size |> filter(year == 2024) |> pull(estimate) |> sum()
tot_age <- hh_age |> filter(year == 2024) |> pull(estimate) |> sum()
tot_bed <- bedrooms |> filter(year == 2024) |> pull(estimate) |> sum()
cat(sprintf("Households 2024: B25003 %s | B25009 %s | B25007 %s | B25042 %s\n",
            tot_b25003, tot_size, tot_age, tot_bed))
stopifnot(
  "all three years present" = setequal(unique(hh_size$year), years),
  "no NA estimates" = !anyNA(c(hh_size$estimate, bedrooms$estimate, hh_age$estimate, burden_age$estimate)),
  "household totals agree with B25003 (same vintage)" = all(c(tot_size, tot_age, tot_bed) == tot_b25003),
  "B25074 has the same income bands every year" = n_distinct(count(renter_income, year)$n) == 1,
  "B25074 renter total agrees with B25003 renters (same vintage)" =
    sum(renter_income$estimate[renter_income$year == 2024]) ==
    mk$tenure |> filter(geoid == "51041", year == 2024, tenure == "Renter") |> pull(estimate)
)
print(renter_income |> summarise(n = sum(estimate), .by = year), n = Inf)

print(hh_size |> filter(year == 2024), n = Inf)
print(burden_age, n = Inf)
cat("chesterfield_context: validation passed\n")
