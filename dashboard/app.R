#===============================================================================
# PharmaBI
# Script: app.R
# Objective: Interactive retail sales dashboard
#===============================================================================

library(shiny)
library(bslib)
library(DBI)
library(RSQLite)
library(here)

# Explicit data mode: use synthetic demonstration data by default
source(
  here::here("R", "config", "data_paths.R"),
  local = TRUE
)

dashboard_paths <- pharmabi_data_paths(
  Sys.getenv("PHARMABI_DATA_MODE", unset = "demo")
)

dashboard_is_demo <- identical(dashboard_paths$mode, "demo")

dashboard_title <- if (dashboard_is_demo) {
  "PharmaBI — Retail sales — Synthetic demo"
} else {
  "PharmaBI — Retail sales — Private data"
}

dashboard_scope_label <- if (dashboard_is_demo) {
  "Synthetic demonstration data"
} else {
  "Private operational data"
}

# Load the retail overview, optionally using query parameters

# Database access ----
load_dashboard_query <- function(
    sql_file = "02_retail_overview.sql",
    params = NULL
) {

  database_file <- dashboard_paths$database_file

  if (!file.exists(database_file)) {
    builder_file <- if (dashboard_is_demo) {
      "R/demo/02_build_demo_database.R"
    } else {
      "R/database/01_build_database.R"
    }

    stop(
      "Database not found for data mode '", dashboard_paths$mode,
      "'. Run ", builder_file, " first.",
      call. = FALSE
    )
  }

  connection <- dbConnect(
    SQLite(),
    dbname = database_file,
    flags = SQLITE_RO
  )

  on.exit(dbDisconnect(connection), add = TRUE)

  query <- paste(
    readLines(
      here("sql", sql_file),
      encoding = "UTF-8",
      warn = FALSE
    ),
    collapse = "\n"
  )

  dbGetQuery(connection, query, params = params)
}

retail_overview <- load_dashboard_query()

# Display formatting ----
fmt_number <- function(x, digits = 0L) {
  formatC(
    x,
    format = "f",
    digits = digits,
    big.mark = ".",
    decimal.mark = ","
  )
}

fmt_money <- function(x) {
  paste0("EUR ", fmt_number(x, 2L))
}

fmt_percent <- function(x) {
  paste0(fmt_number(x * 100, 2L), "%")
}

# Basket summary helper ----

summarise_basket_receipts <- function(baskets) {

  baskets |>
    dplyr::summarise(
      receipts = dplyr::n(),
      multi_product_receipts = sum(unique_products >= 2L),
      multi_product_receipt_share =
        multi_product_receipts / receipts,
      average_unique_products = mean(unique_products),
      average_net_revenue_per_receipt = mean(revenue)
    )
}

# User interface----

ui <- page_sidebar(
  title = dashboard_title,
  lang = "en",
  fillable = FALSE,

  sidebar = sidebar(
    title = "Analysis scope",
    width = 320,

    div(
      class = if (dashboard_is_demo) {
        "alert alert-info"
      } else {
        "alert alert-warning"
      },
      role = "note",
      strong(dashboard_scope_label),
      p(
        if (dashboard_is_demo) {
          "Fictional transactions for portfolio demonstration."
        } else {
          "Operational data from the local private dataset."
        }
      )
    ),

    p(
      strong("Available retail data:"),
      br(),
      paste(
        format(
          as.Date(retail_overview$start_date),
          "%Y-%m-%d"
        ),
        "-",
        format(
          as.Date(retail_overview$end_date),
          "%Y-%m-%d"
        )
      )
    ),

    dateRangeInput(
      inputId = "period",
      label = "Current period",
      start = as.Date(retail_overview$start_date),
      end = as.Date(retail_overview$end_date),
      min = as.Date(retail_overview$start_date),
      max = as.Date(retail_overview$end_date),
      format = "yyyy-mm-dd",
      weekstart = 1,
      width = "100%"
    ),

    checkboxInput(
      inputId = "compare_periods",
      label = "Compare with another period",
      value = FALSE
    ),

    conditionalPanel(
      condition = "input.compare_periods",

      dateRangeInput(
        inputId = "reference_period",
        label = "Reference period",
        start = as.Date(retail_overview$start_date),
        end = as.Date(retail_overview$end_date),
        min = as.Date(retail_overview$start_date),
        max = as.Date(retail_overview$end_date),
        format = "yyyy-mm-dd",
        weekstart = 1,
        width = "100%"
      )
    ),

    p("Retail sales only."),
    p("Revenue excludes VAT."),
    p("Recorded profit excludes operating expenses.")
  ),

  navset_tab(

    ## Sales overview ----
    nav_panel(
      "Sales overview",

      layout_columns(
        value_box(
          title = "Net revenue (VAT excluded)",
          value = textOutput("net_revenue", inline = TRUE)
        ),

        value_box(
          title = "Recorded profit",
          value = textOutput("recorded_profit", inline = TRUE)
        ),

        value_box(
          title = "Receipts",
          value = textOutput("receipts", inline = TRUE)
        ),

        value_box(
          title = "Overall margin",
          value = textOutput("overall_margin", inline = TRUE)
        ),

        col_widths = breakpoints(
          sm = c(6, 6, 6, 6),
          xl = c(3, 3, 3, 3)
        )
      ),

      conditionalPanel(
        condition = "input.compare_periods",

        card(
          card_header("Period comparison"),
          textOutput("comparison_period_labels"),

          p(
            "Changes are calculated against the reference period.",
            "Values in EUR unless otherwise indicated."
          ),

          div(
            style = "overflow-x: auto;",
            tableOutput("period_comparison")
          )
        )
      ),

      card(
        card_header(
          textOutput("monthly_revenue_title", inline = TRUE)
        ),

        selectInput(
          inputId = "revenue_metric",
          label = "Revenue chart",
          choices = c(
            "Monthly total" = "revenue",
            "Per active day" = "revenue_per_day"
          ),
          selected = "revenue"
        ),

        plotOutput(
          "monthly_revenue",
          height = "320px"
        ),

        card_footer(
          paste(
            "Revenue excludes VAT.",
            "* marks partial calendar coverage in the selected period.",
            "Daily averages use dates with recorded retail sales."
          )
        )
      )
    ),

    # Product performance
    nav_panel(
      "Products",

      card(
        card_header(
          textOutput("top_products_title", inline = TRUE)
        ),

        selectInput(
          inputId = "product_metric",
          label = "Rank products by",
          choices = c(
            "Recorded profit" = "profit",
            "Net revenue" = "revenue",
            "Packages sold" = "packages"
          ),
          selected = "profit"
        ),

        div(
          style = "overflow-x: auto;",
          tableOutput("top_products")
        ),

        card_footer(
          "Recorded profit reflects revenue minus recorded product costs."
        )
      )
    ),

    # Human ATC category performance
    nav_panel(
      "Human ATC",

      card(
        card_header(
          textOutput("atc_title", inline = TRUE)
        ),

        selectInput(
          inputId = "atc_metric",
          label = "Rank ATC categories by",
          choices = c(
            "Packages sold" = "packages",
            "Net revenue" = "revenue",
            "Recorded profit" = "profit"
          ),
          selected = "packages"
        ),

        div(
          style = "overflow-x: auto;",
          tableOutput("top_atc")
        ),

        card_footer(
          paste(
            "Retail sales with ATC codes, excluding veterinary",
            "codes identified in the current source.",
            "Packages are not patient or dose counts.",
            "Receipt counts can overlap across categories."
          )
        )
      )
    ),

    ## Basket analysis ----
    nav_panel(
      "Basket analysis",

      p(
        "Receipt structure for the current period.",
        "Distinct products are counted by product code."
      ),

      layout_columns(
        value_box(
          title = "Receipts",
          value = textOutput(
            "basket_receipts",
            inline = TRUE
          )
        ),

        value_box(
          title = "Receipts with multiple distinct products",
          value = textOutput(
            "basket_multi_product_share",
            inline = TRUE
          )
        ),

        value_box(
          title = "Average distinct products per receipt",
          value = textOutput(
            "basket_average_products",
            inline = TRUE
          )
        ),

        value_box(
          title = "Average net revenue per receipt",
          value = textOutput(
            "basket_average_revenue",
            inline = TRUE
          )
        ),

        col_widths = c(3, 3, 3, 3)
      ),

      conditionalPanel(
        condition = "input.compare_periods",

        card(
          card_header("Basket structure — period comparison"),

          textOutput("basket_comparison_periods"),

          div(
            style = "overflow-x: auto;",
            tableOutput("basket_period_comparison")
          ),

          card_footer(
            paste(
              "Changes are calculated as current minus reference.",
              "Changes in the multi-product receipt share",
              "are expressed in percentage points (pp)."
            )
          )
        )
      ),

      card(
        card_header(
          "Receipt distribution by number of distinct products"
        ),

        plotOutput(
          "basket_size_distribution",
          height = "400px"
        ),

        card_footer(
          "Each receipt contributes to one bar. Only observed basket sizes are shown."
        )
      ),

      card(
        card_header("Product pairs purchased together"),

        numericInput(
          inputId = "basket_min_pair_receipts",
          label = "Minimum receipts together",
          value = 5,
          min = 1,
          step = 1
        ),

        tags$details(
          tags$summary(
            strong("How to read these indicators")
          ),

          tags$ul(
            tags$li(
              strong("Receipts together: "),
              "Number of receipts containing both products in the current period."
            ),

            tags$li(
              strong("Support: "),
              "Percentage of all retail receipts in the current period containing both products."
            ),

            tags$li(
              strong("Confidence A to B: "),
              "Percentage of receipts containing A that also contain B."
            ),

            tags$li(
              strong("Confidence B to A: "),
              "Percentage of receipts containing B that also contain A."
            ),

            tags$li(
              strong("Lift: "),
              paste(
                "Observed co-occurrence divided by the expected co-occurrence",
                "under independence.",
                "A value above 1 means the pair appears together",
                "more often than expected under that assumption."
              )
            )
          ),

          p(
            "The minimum receipt count filters the displayed pairs;",
            "it does not change their support, confidence or lift."
          )
        ),

        div(
          style = "overflow-x: auto;",
          tableOutput("basket_pairs_table")
        ),

        card_footer(
          paste(
            "Up to 20 pairs, ranked by receipts together.",
            "A and B are ordered by product code.",
            "Counts refer to receipts, not distinct customers.",
            "High lift values should be read alongside the observed counts."
          )
        )
      ),

      p(
        "Multiple-product receipts contain at least two distinct products.",
        "Buying several packages of the same product counts as one distinct product."
      )
    ),


    # Merchandise group performance
    nav_panel(
      "Merchandise groups",

      conditionalPanel(
        condition = "input.compare_periods",

        card(
          card_header("Merchandise group revenue comparison"),

          p(
            "Current and reference periods follow the sidebar selections."
          ),

          selectInput(
            inputId = "gm_comparison_metric",
            label = "Comparison metric",
            choices = c(
              "Total net revenue" = "revenue",
              "Net revenue per active day" = "revenue_per_day"
            ),
            selected = "revenue"
          ),

          p(
            "Daily averages use the retail active days of each entire period."
          ),

          div(
            id = "gm-comparison-scroll",
            style = "overflow: auto; max-height: 450px;",

            tags$style(HTML("
            #gm-comparison-scroll table {
              border-collapse: separate;
              border-spacing: 0;
            }

            #gm-comparison-scroll thead th {
              position: sticky;
              top: 0;
              z-index: 2;
              background-color: var(--bs-body-bg, #ffffff);
              box-shadow: 0 2px 0 #adb5bd;
            }
          ")),

          tableOutput("gm_revenue_comparison")
        ),

          card_footer(
            paste(
              "All categories recorded in either period are included.",
              "Sorted by change in the selected metric,",
              "from largest increase to largest decrease.",
              "Percentage change is N/A when the reference value is zero."
            )
          )
        )
      ),

      card(
        card_header(
          "Top 8 merchandise groups by recorded profit"
        ),

        plotOutput(
          "gm_profit",
          height = "500px"
        ),

        card_footer(
          "Groups are ranked within the selected period."
        )
      )
    )
  )
)

# Server logic ----
server <- function(input, output, session) {

  # Recalculate the overview when the selected period changes
  filtered_overview <- reactive({

    req(
      length(input$period) == 2L,
      !anyNA(input$period)
    )

    validate(
      need(
        input$period[1] <= input$period[2],
        "Start date must not follow end date."
      )
    )

    overview <- load_dashboard_query(
      sql_file = "06_retail_overview_by_period.sql",
      params = list(
        as.character(input$period[1]),
        as.character(input$period[2])
      )
    )

    validate(
      need(
        overview$receipts > 0,
        "No retail sales recorded in this period."
      )
    )

    overview
  })

  # Retrieve KPIs for the reference period
  reference_overview <- reactive({

    req(
      isTRUE(input$compare_periods),
      length(input$reference_period) == 2L,
      !anyNA(input$reference_period)
    )

    validate(
      need(
        input$reference_period[1] <= input$reference_period[2],
        "Reference start date must not follow end date."
      )
    )

    overview <- load_dashboard_query(
      sql_file = "06_retail_overview_by_period.sql",
      params = list(
        as.character(input$reference_period[1]),
        as.character(input$reference_period[2])
      )
    )

    validate(
      need(
        overview$receipts > 0,
        "No retail sales recorded in the reference period."
      )
    )

    overview
  })

  # Load monthly values for the selected period
  filtered_monthly <- reactive({

    # Reuse the existing period and sales availability checks
    filtered_overview()

    load_dashboard_query(
      sql_file = "07_retail_monthly_by_period.sql",
      params = list(
        as.character(input$period[1]),
        as.character(input$period[2])
      )
    )
  })

  ## Basket analysis calculations ----

  # Load one row per receipt for the current period
  filtered_basket_receipts <- reactive({

    filtered_overview()

    load_dashboard_query(
      sql_file = "12_basket_receipts_by_period.sql",
      params = list(
        as.character(input$period[1]),
        as.character(input$period[2])
      )
    )
  })

  # Summarise the structure of receipts in the current period
  filtered_basket_overview <- reactive({

    summarise_basket_receipts(
      filtered_basket_receipts()
    )
  })

  # Summarise receipts for the reference period
  reference_basket_overview <- reactive({

    reference_overview()

    baskets <- load_dashboard_query(
      sql_file = "12_basket_receipts_by_period.sql",
      params = list(
        as.character(input$reference_period[1]),
        as.character(input$reference_period[2])
      )
    )

    summarise_basket_receipts(baskets)
  })

  # Count receipts by number of distinct products
  filtered_basket_distribution <- reactive({

    baskets <- filtered_basket_receipts()

    baskets |>
      dplyr::count(
        unique_products,
        name = "receipts"
      ) |>
      dplyr::arrange(unique_products)
  })

  # Load product pair metrics for the current period
  filtered_basket_pairs <- reactive({

    filtered_overview()

    load_dashboard_query(
      sql_file = "13_basket_pair_frequency_by_period.sql",
      params = list(
        as.character(input$period[1]),
        as.character(input$period[2])
      )
    )
  })

  # Load the product ranking for the selected period
  filtered_products <- reactive({

    filtered_overview()

    req(
      input$product_metric %in%
        c("profit", "revenue", "packages")
    )

    load_dashboard_query(
      sql_file = "08_top_products_by_period.sql",
      params = list(
        as.character(input$period[1]),
        as.character(input$period[2]),
        input$product_metric
      )
    )
  })

  # Load merchandise group performance for the selected period

  filtered_gm <- reactive({

    filtered_overview()

    load_dashboard_query(
      sql_file = "09_top_gm_by_period.sql",
      params = list(
        as.character(input$period[1]),
        as.character(input$period[2])
      )
    )
  })

  ## Merchandise group comparison calculations ----
  gm_period_comparison <- reactive({

    # Reuse the existing checks for both periods
    current_overview <- filtered_overview()
    reference_summary <- reference_overview()

    reference <- load_dashboard_query(
      sql_file = "11_gm_revenue_by_period.sql",
      params = list(
        as.character(input$reference_period[1]),
        as.character(input$reference_period[2])
      )
    ) |>
      dplyr::rename(
        reference_revenue = revenue
      )

    current <- load_dashboard_query(
      sql_file = "11_gm_revenue_by_period.sql",
      params = list(
        as.character(input$period[1]),
        as.character(input$period[2])
      )
    ) |>
      dplyr::rename(
        current_revenue = revenue
      )

    dplyr::full_join(
      reference,
      current,
      by = c("gm_code", "gm_desc")
    ) |>
      dplyr::mutate(
        reference_revenue = dplyr::coalesce(
          reference_revenue, 0
        ),
        current_revenue = dplyr::coalesce(
          current_revenue, 0
        ),

        # Compare total revenue
        revenue_change =
          current_revenue - reference_revenue,

        revenue_change_percent = dplyr::if_else(
          reference_revenue == 0,
          NA_real_,
          revenue_change /
            dplyr::na_if(reference_revenue, 0) * 100
        ),

        # Normalize each category by the period's retail active days
        reference_revenue_per_day =
          reference_revenue / reference_summary$active_days,

        current_revenue_per_day =
          current_revenue / current_overview$active_days,

        revenue_change_per_day =
          current_revenue_per_day - reference_revenue_per_day,

        revenue_change_per_day_percent = dplyr::if_else(
          reference_revenue_per_day == 0,
          NA_real_,
          revenue_change_per_day /
            dplyr::na_if(reference_revenue_per_day, 0) * 100
        )
      ) |>
      dplyr::arrange(
        dplyr::desc(revenue_change),
        gm_code
      )
  })

  # Load human ATC performance for the selected period

  filtered_atc <- reactive({

    filtered_overview()

    req(
      input$atc_metric %in%
        c("packages", "revenue", "profit")
    )

    categories <- load_dashboard_query(
      sql_file = "10_top_atc_by_period.sql",
      params = list(
        as.character(input$period[1]),
        as.character(input$period[2]),
        input$atc_metric
      )
    )

    validate(
      need(
        nrow(categories) > 0L,
        "No human ATC sales recorded in this period."
      )
    )

    categories
  })

  # Output
  output$net_revenue <- renderText({
    fmt_money(filtered_overview()$revenue)
  })

  output$recorded_profit <- renderText({
    fmt_money(filtered_overview()$profit)
  })

  output$receipts <- renderText({
    fmt_number(filtered_overview()$receipts)
  })

  output$overall_margin <- renderText({
    margin <- filtered_overview()$overall_margin

    if (is.na(margin)) {
      return("Not available")
    }

    fmt_percent(margin)
  })

  output$monthly_revenue_title <- renderText({

    req(input$revenue_metric)

    if (isTRUE(input$compare_periods)) {

      if (input$revenue_metric == "revenue") {
        "Period comparison — Net revenue (VAT excluded)"
      } else {
        "Period comparison — Net revenue per active day (VAT excluded)"
      }

    } else {

      if (input$revenue_metric == "revenue") {
        "Monthly net revenue (VAT excluded)"
      } else {
        "Net revenue per active day (VAT excluded)"
      }
    }
  })

  output$monthly_revenue <- renderPlot({

    req(
      input$revenue_metric %in%
        c("revenue", "revenue_per_day")
    )

    if (isTRUE(input$compare_periods)) {

      # Compare the two complete selected intervals
      current <- filtered_overview()
      reference <- reference_overview()

      if (input$revenue_metric == "revenue") {
        values <- c(
          reference$revenue,
          current$revenue
        )
        axis_label <- "EUR"
      } else {
        values <- c(
          reference$revenue_per_active_day,
          current$revenue_per_active_day
        )
        axis_label <- "EUR / active day"
      }

      bar_labels <- c("Reference", "Current")
      bar_colors <- c("#647D34", "#19647E")
      x_axis_label <- "Period"

    } else {

      # Show the monthly breakdown of the main selected period
      monthly <- filtered_monthly()

      month_start <- as.Date(
        paste0(monthly$month, "-01")
      )

      month_end <- as.Date(
        format(month_start + 32, "%Y-%m-01")
      ) - 1

      partial_month <- month_start < input$period[1] |
        month_end > input$period[2]

      bar_labels <- paste0(
        monthly$month,
        ifelse(partial_month, "*", "")
      )

      if (input$revenue_metric == "revenue") {
        values <- monthly$revenue
        axis_label <- "EUR"
      } else {
        values <- monthly$revenue_per_day
        axis_label <- "EUR / active day"
      }

      bar_colors <- "#19647E"
      x_axis_label <- "Month"
    }

    # Draw either chart using the same formatting
    par(mar = c(5, 6, 2, 1))

    barplot(
      height = values,
      names.arg = bar_labels,
      col = bar_colors,
      border = NA,
      xlab = x_axis_label,
      ylab = "",
      yaxt = "n"
    )

    ticks <- axTicks(2)

    axis(
      side = 2,
      at = ticks,
      labels = fmt_number(ticks),
      las = 1
    )

    mtext(axis_label, side = 2, line = 4)

  }, alt = "Retail net revenue for the selected metric, shown by month or compared between the reference and current periods.")

  output$top_products_title <- renderText({

    req(
      input$product_metric %in%
        c("profit", "revenue", "packages")
    )

    switch(
      input$product_metric,
      profit = "Top 10 products by recorded profit",
      revenue = "Top 10 products by net revenue",
      packages = "Top 10 products by packages sold"
    )
  })

  output$top_products <- renderTable({

    products <- filtered_products()

    data.frame(
      "Product code" = products$product_code,
      "Product" = products$product_desc,
      "Packages" = fmt_number(products$packages_sold),
      "Receipts" = fmt_number(products$receipts),
      "Net revenue (EUR)" = fmt_number(products$revenue, 2L),
      "Recorded profit (EUR)" = fmt_number(products$profit, 2L),
      "Margin" = ifelse(
        is.na(products$overall_margin),
        "N/A",
        fmt_percent(products$overall_margin)
      ),
      check.names = FALSE
    )

  },
  striped = TRUE,
  hover = TRUE,
  width = "100%",
  align = "llrrrrr",
  rownames = FALSE
  )

  output$gm_profit <- renderPlot({

    gm <- filtered_gm()

    labels <- vapply(
      gm$gm_desc,
      function(description) {
        paste(
          strwrap(description, width = 30),
          collapse = "\n"
        )
      },
      character(1)
    )

    par(mar = c(5, 17, 2, 1))

    barplot(
      height = rev(gm$profit),
      names.arg = rev(labels),
      horiz = TRUE,
      las = 1,
      cex.names = 1.1,
      col = "#19647E",
      border = NA,
      xaxt = "n"
    )

    ticks <- axTicks(1)

    axis(
      side = 1,
      at = ticks,
      labels = fmt_number(ticks)
    )

    mtext(
      "Recorded profit (EUR)",
      side = 1,
      line = 3
    )
  }, alt = "Top merchandise groups by recorded profit in the selected period.")

  output$atc_title <- renderText({

    req(
      input$atc_metric %in%
        c("packages", "revenue", "profit")
    )

    switch(
      input$atc_metric,
      packages = "Top 10 ATC level 2 categories by packages sold",
      revenue = "Top 10 ATC level 2 categories by net revenue",
      profit = "Top 10 ATC level 2 categories by recorded profit"
    )
  })


  output$top_atc <- renderTable({

    categories <- filtered_atc()

    data.frame(
      "ATC" = categories$atc_level2,
      "Category" = categories$atc_level2_desc,
      "Packages" = fmt_number(categories$packages_sold),
      "Receipts" = fmt_number(categories$receipts),
      "Net revenue (EUR)" = fmt_number(categories$revenue, 2L),
      "Recorded profit (EUR)" = fmt_number(categories$profit, 2L),
      "Margin" = ifelse(
        is.na(categories$overall_margin),
        "N/A",
        fmt_percent(categories$overall_margin)
      ),
      check.names = FALSE
    )

  },
  striped = TRUE,
  hover = TRUE,
  width = "100%",
  align = "llrrrrr",
  rownames = FALSE
  )

  output$comparison_period_labels <- renderText({

    req(
      isTRUE(input$compare_periods),
      length(input$period) == 2L,
      length(input$reference_period) == 2L,
      !anyNA(input$period),
      !anyNA(input$reference_period)
    )

    paste0(
      "Current: ",
      format(input$period[1], "%Y-%m-%d"),
      " – ",
      format(input$period[2], "%Y-%m-%d"),
      " | Reference: ",
      format(input$reference_period[1], "%Y-%m-%d"),
      " – ",
      format(input$reference_period[2], "%Y-%m-%d")
    )
  })

  output$period_comparison <- renderTable({

    current <- filtered_overview()
    reference <- reference_overview()

    # Select the six indicators compared using percentage changes
    fields <- c(
      "active_days",
      "receipts",
      "revenue",
      "profit",
      "revenue_per_active_day",
      "profit_per_active_day"
    )

    current_values <- unlist(current[fields], use.names = FALSE)
    reference_values <- unlist(reference[fields], use.names = FALSE)

    absolute_changes <- current_values - reference_values

    relative_changes <- ifelse(
      reference_values == 0 | is.na(reference_values),
      NA_real_,
      absolute_changes / reference_values
    )

    # Display counts without decimals and monetary values with two
    format_values <- function(values) {
      c(
        fmt_number(values[1:2]),
        fmt_number(values[3:6], 2L)
      )
    }

    comparison <- data.frame(
      Indicator = c(
        "Active days",
        "Receipts",
        "Net revenue",
        "Recorded profit",
        "Net revenue per active day",
        "Recorded profit per active day"
      ),
      Reference = format_values(reference_values),
      Current = format_values(current_values),
      Change = format_values(absolute_changes),
      `Change (%)` = ifelse(
        is.na(relative_changes),
        "N/A",
        fmt_percent(relative_changes)
      ),
      check.names = FALSE
    )

    # Margin changes are expressed in percentage points
    margin_change <- (
      current$overall_margin - reference$overall_margin
    ) * 100

    margin_row <- data.frame(
      Indicator = "Overall margin",
      Reference = ifelse(
        is.na(reference$overall_margin),
        "N/A",
        fmt_percent(reference$overall_margin)
      ),
      Current = ifelse(
        is.na(current$overall_margin),
        "N/A",
        fmt_percent(current$overall_margin)
      ),
      Change = ifelse(
        is.na(margin_change),
        "N/A",
        paste0(fmt_number(margin_change, 2L), " pp")
      ),
      `Change (%)` = "—",
      check.names = FALSE
    )

    rbind(comparison, margin_row)

  },
  striped = TRUE,
  hover = TRUE,
  width = "100%",
  align = "lrrrr",
  rownames = FALSE
  )

  ## Merchandise group comparison table ----
  output$gm_revenue_comparison <- renderTable({

    req(
      input$gm_comparison_metric %in%
        c("revenue", "revenue_per_day")
    )

    categories <- gm_period_comparison()

    # Choose the columns and units for the selected metric
    if (input$gm_comparison_metric == "revenue") {

      fields <- c(
        "reference_revenue",
        "current_revenue",
        "revenue_change",
        "revenue_change_percent"
      )

      unit_label <- "EUR"

    } else {

      fields <- c(
        "reference_revenue_per_day",
        "current_revenue_per_day",
        "revenue_change_per_day",
        "revenue_change_per_day_percent"
      )

      unit_label <- "EUR / active day"
    }

    # Give either set of columns the same working names
    comparison <- categories[
      c("gm_code", "gm_desc", fields)
    ]

    names(comparison) <- c(
      "gm_code",
      "gm_desc",
      "reference_value",
      "current_value",
      "change_value",
      "change_percent"
    )

    # Rank categories using the selected metric
    comparison <- comparison |>
      dplyr::arrange(
        dplyr::desc(change_value),
        gm_code
      )

    display_table <- data.frame(
      code = comparison$gm_code,
      category = comparison$gm_desc,
      reference = fmt_number(comparison$reference_value, 2L),
      current = fmt_number(comparison$current_value, 2L),
      change = fmt_number(comparison$change_value, 2L),
      percentage = ifelse(
        is.na(comparison$change_percent),
        "N/A",
        paste0(
          fmt_number(comparison$change_percent, 2L),
          "%"
        )
      ),
      stringsAsFactors = FALSE
    )

    names(display_table) <- c(
      "GM code",
      "Category",
      paste0("Reference (", unit_label, ")"),
      paste0("Current (", unit_label, ")"),
      paste0("Change (", unit_label, ")"),
      "Change (%)"
    )

    display_table

  },
  striped = TRUE,
  hover = TRUE,
  width = "100%",
  align = "llrrrr",
  rownames = FALSE
  )

  ## Basket analysis outputs ----

  output$basket_receipts <- renderText({
    fmt_number(filtered_basket_overview()$receipts)
  })

  output$basket_multi_product_share <- renderText({
    fmt_percent(
      filtered_basket_overview()$multi_product_receipt_share
    )
  })

  output$basket_average_products <- renderText({
    fmt_number(
      filtered_basket_overview()$average_unique_products,
      digits = 2L
    )
  })

  output$basket_average_revenue <- renderText({
    fmt_money(
      filtered_basket_overview()$average_net_revenue_per_receipt
    )
  })

  output$basket_size_distribution <- renderPlot({

    distribution <- filtered_basket_distribution()

    par(mar = c(5, 6, 2, 1))

    bar_positions <- barplot(
      height = distribution$receipts,
      names.arg = distribution$unique_products,
      col = "#19647E",
      border = NA,
      xlab = "Distinct products per receipt",
      ylab = "",
      yaxt = "n",
      ylim = c(
        0,
        max(distribution$receipts) * 1.18
      )
    )

    ticks <- axTicks(2)

    axis(
      side = 2,
      at = ticks,
      labels = fmt_number(ticks),
      las = 1
    )

    mtext("Receipts", side = 2, line = 4)

    text(
      x = bar_positions,
      y = distribution$receipts,
      labels = fmt_number(distribution$receipts),
      pos = 3,
      offset = 0.4,
      cex = 0.9
    )

  }, alt = "Number of retail receipts by number of distinct products in the current period, with exact counts above each bar.")

  output$basket_pairs_table <- renderTable({

    minimum <- input$basket_min_pair_receipts

    req(
      length(minimum) == 1L,
      !is.na(minimum)
    )

    validate(
      need(
        is.finite(minimum) &&
          minimum >= 1 &&
          minimum == floor(minimum),
        "Enter a positive whole number."
      )
    )

    pairs <- filtered_basket_pairs() |>
      dplyr::filter(receipts_together >= minimum) |>
      dplyr::slice_head(n = 20)

    validate(
      need(
        nrow(pairs) > 0L,
        "No product pairs meet the selected minimum in this period."
      )
    )

    data.frame(
      "Product A" = paste0(
        pairs$product_desc_a,
        " [", pairs$product_code_a, "]"
      ),
      "Product B" = paste0(
        pairs$product_desc_b,
        " [", pairs$product_code_b, "]"
      ),
      "Receipts together" = fmt_number(
        pairs$receipts_together
      ),
      "Support" = fmt_percent(pairs$support),
      "Confidence A to B" = fmt_percent(
        pairs$confidence_a_to_b
      ),
      "Confidence B to A" = fmt_percent(
        pairs$confidence_b_to_a
      ),
      "Lift" = fmt_number(pairs$lift, digits = 2L),
      check.names = FALSE
    )

  },
  striped = TRUE,
  hover = TRUE,
  width = "100%",
  align = "llrrrrr",
  rownames = FALSE
  )

  ## Basket period comparison outputs ----

  output$basket_comparison_periods <- renderText({

    req(
      isTRUE(input$compare_periods),
      length(input$period) == 2L,
      length(input$reference_period) == 2L,
      !anyNA(input$period),
      !anyNA(input$reference_period)
    )

    paste0(
      "Current: ",
      format(input$period[1], "%Y-%m-%d"),
      " — ",
      format(input$period[2], "%Y-%m-%d"),
      " | Reference: ",
      format(input$reference_period[1], "%Y-%m-%d"),
      " — ",
      format(input$reference_period[2], "%Y-%m-%d")
    )
  })

  output$basket_period_comparison <- renderTable({

    req(isTRUE(input$compare_periods))

    current <- filtered_basket_overview()
    reference <- reference_basket_overview()

    data.frame(
      "Indicator" = c(
        "Receipts with multiple distinct products",
        "Average distinct products per receipt",
        "Average net revenue per receipt"
      ),

      "Reference" = c(
        fmt_percent(reference$multi_product_receipt_share),
        fmt_number(reference$average_unique_products, 2L),
        fmt_money(reference$average_net_revenue_per_receipt)
      ),

      "Current" = c(
        fmt_percent(current$multi_product_receipt_share),
        fmt_number(current$average_unique_products, 2L),
        fmt_money(current$average_net_revenue_per_receipt)
      ),

      "Change" = c(
        paste0(
          fmt_number(
            (
              current$multi_product_receipt_share -
                reference$multi_product_receipt_share
            ) * 100,
            2L
          ),
          " pp"
        ),

        fmt_number(
          current$average_unique_products -
            reference$average_unique_products,
          2L
        ),

        fmt_money(
          current$average_net_revenue_per_receipt -
            reference$average_net_revenue_per_receipt
        )
      ),

      check.names = FALSE
    )

  },
  striped = TRUE,
  hover = TRUE,
  width = "100%",
  align = "lrrr",
  rownames = FALSE
  )

}  # End of server

# Application startup ----
shinyApp(ui = ui, server = server)
