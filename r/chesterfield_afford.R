# chesterfield_afford.R ----
# What:   Turns each Chesterfield public-service starting salary into what one
#         income can afford: maximum rent and maximum home price at 30% of gross
#         income, compared with Chesterfield's median rent and home value, and
#         with the HUD 80% AMI limit for one person. Feeds the Chesterfield
#         one-pager (chesterfield-onepager.qmd).
# Source: data/chesterfield_pay.rds (r/chesterfield_pay.R); data/acs_market.rds
#         (ACS 2020-2024 5-year, B25064 median gross rent, B25077 median home
#         value, Chesterfield County 51041); HUD FY2026 income limits, Richmond
#         HUD Metro FMR Area (data/summary_county_5176099999.csv); Freddie Mac
#         PMMS and the county FY2027 Proposed Budget for the home-price inputs.
# Output: data/chesterfield_onepager.rds -- list(afford, ctx)
#         data-out/chesterfield_onepager.csv -- afford, one row per pay figure

## 1. Setup ----
library(tidyverse)
source("_common.R") # export_csv()

dir.create("data", showWarnings = FALSE, recursive = TRUE)

rent_share <- 0.30 # HUD cost-burden convention: housing <= 30% of gross income

## 2. Home-price assumptions (each sourced; edit here only) ----
assumptions <- tibble(
  rate = 0.0711, # 30-year fixed, Freddie Mac PMMS
  rate_source = "Freddie Mac Primary Mortgage Market Survey, 30-year fixed, week of Nov 12, 2026",
  rate_date = as.Date("2026-11-12"),
  down_pct = 0.05, # assumption: a first-time buyer's low down payment
  tax_rate = 0.0089, # $0.89 per $100, calendar year 2026
  tax_source = "Chesterfield County FY2027 Proposed Budget (real estate tax rate $0.89 per $100, CY2026)",
  ins_rate = 0.0035, # assumption: homeowners insurance, share of price per year
  pmi_rate = 0.007 # assumption: private mortgage insurance, share of loan per year (applies below 20% down)
)

## 3. Affordability functions ----
# Monthly housing cost per dollar of price: mortgage + taxes + insurance + PMI.
price_factor <- function(rate, down_pct, tax_rate, ins_rate, pmi_rate) {
  r <- rate / 12
  m <- r / (1 - (1 + r)^-360) # monthly payment per dollar borrowed, 30 years
  pmi <- if (down_pct >= 0.20) 0 else pmi_rate # PMI only below 20% down
  (1 - down_pct) * m + tax_rate / 12 + ins_rate / 12 + (1 - down_pct) * pmi / 12
}

# Highest home price whose monthly cost fits in `rent_share` of gross income.
max_price <- function(income, rate, down_pct, tax_rate, ins_rate, pmi_rate) {
  income * rent_share / 12 / price_factor(rate, down_pct, tax_rate, ins_rate, pmi_rate)
}

## 4. Inputs ----
pay <- read_rds("data/chesterfield_pay.rds")
mk <- read_rds("data/acs_market.rds")
acs_val <- \(tbl) mk[[tbl]] |> filter(geoid == "51041", year == 2024) |> pull(estimate)
median_rent <- acs_val("median_rent")
median_value <- acs_val("median_value")

hud <- read_csv("data/summary_county_5176099999.csv", col_names = FALSE, show_col_types = FALSE)
ami80_1p <- hud |>
  filter(str_detect(X1, "Low \\(80%\\)")) |>
  pull(X2) |>
  parse_number()

## 5. Derive and write ----
a <- assumptions
afford <- pay |>
  mutate(
    max_rent = annual_pay * rent_share / 12,
    max_price = max_price(annual_pay, a$rate, a$down_pct, a$tax_rate, a$ins_rate, a$pmi_rate),
    rent_gap = max_rent - median_rent,
    price_gap = max_price - median_value,
    pct_ami80_1p = annual_pay / ami80_1p
  )

f <- price_factor(a$rate, a$down_pct, a$tax_rate, a$ins_rate, a$pmi_rate)
ctx <- list(
  median_rent = median_rent,
  median_value = median_value,
  ami80_1p = ami80_1p,
  income_for_rent = median_rent * 12 / rent_share, # income needed to afford the median rent
  income_for_home = median_value * f * 12 / rent_share, # income needed to afford the median home
  assumptions = assumptions
)

write_rds(list(afford = afford, ctx = ctx), "data/chesterfield_onepager.rds")
export_csv(afford, "chesterfield_onepager")

## 6. Validation ----
stopifnot(
  "median rent should be 1629 (ACS 2020-2024)" = median_rent == 1629,
  "median value should be 366000 (ACS 2020-2024)" = median_value == 366000,
  "HUD 80% AMI one-person limit should be 63600" = ami80_1p == 63600,
  "assumption sources missing" = all(nzchar(c(a$rate_source, a$tax_source))) && !is.na(a$rate_date),
  "max_rent for 60147 should be 1503.675" = abs(
    afford$max_rent[afford$role == "Police officer"] - 1503.675
  ) < 0.01
)
# Independent benchmark: a 30-year loan at 7.11% costs $6.726 a month per $1,000
# borrowed (standard amortization table value), with no tax, insurance or PMI.
stopifnot(
  "amortization factor is off" = abs(price_factor(0.0711, 0, 0, 0, 0) * 1000 - 6.726) < 0.01
)
# Round trip: monthly cost at max_price equals the income-based budget.
cost_at <- afford$max_price * f
stopifnot(
  "max_price round trip is off by more than $1/month" =
    all(abs(cost_at - afford$annual_pay * rent_share / 12) < 1),
  "income_for_home should buy the median home" =
    abs(max_price(ctx$income_for_home, a$rate, a$down_pct, a$tax_rate, a$ins_rate, a$pmi_rate) - median_value) < 1
)

cat("chesterfield_afford: validation passed\n")
cat(sprintf("Income needed: median rent $%s; median home $%s\n",
            format(round(ctx$income_for_rent), big.mark = ","),
            format(round(ctx$income_for_home), big.mark = ",")))
print(afford |> select(role, annual_pay, status, max_rent, rent_gap, max_price, price_gap), n = Inf)
