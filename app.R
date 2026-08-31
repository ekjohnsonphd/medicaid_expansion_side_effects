library(shiny)
library(data.table)
library(tidyverse)
library(did)
library(fixest)
library(plotly)
library(shinyWidgets)

# ==============================================================================
# Load reference data (static across analyses)
# ==============================================================================
# Columns already named: location_name, expansion_year, restricted (see R/prep_data.R)
medicaid_expansion <- fread("data/medicaid_expansion_cohorts.csv")

covariates <- fread("data/state_covariates_2010_2019.csv")

# Get available causes from the cause-specific file
cause_data_sample <- fread("data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_CAUSE_2010_2019_Y2025M02D13.CSV", nrows = 10000)
available_causes <- sort(unique(cause_data_sample$cause_name))
available_causes <- available_causes[available_causes != ""]

# ==============================================================================
# UI
# ==============================================================================
ui <- fluidPage(
  titlePanel("Medicaid Expansion Difference-in-Differences Analysis"),

  sidebarLayout(
    sidebarPanel(
      width = 3,

      h4("Data Selection"),
      hr(),

      # Cause selection
      radioButtons(
        "cause_type",
        "Cause Selection:",
        choices = c("All causes" = "all", "Specific cause" = "specific"),
        selected = "all"
      ),
      conditionalPanel(
        condition = "input.cause_type == 'specific'",
        selectInput(
          "specific_cause",
          "Select Cause:",
          choices = available_causes,
          selected = available_causes[1]
        )
      ),

      hr(),

      # Age selection
      radioButtons(
        "age_type",
        "Age Selection:",
        choices = c(
          "Age-standardized" = "Age/sex-standardized",
          "All ages" = "All ages"
        ),
        selected = "Age/sex-standardized"
      ),

      hr(),

      # Payer selection
      checkboxGroupInput(
        "payer_filter",
        "Payers to Display:",
        choices = c(
          "Medicaid" = "mdcd",
          "Medicare" = "mdcr",
          "Private" = "priv",
          "Out-of-pocket" = "oop"
        ),
        selected = c("mdcd", "mdcr", "priv", "oop")
      ),

      hr(),

      # Outcome selection
      selectInput(
        "outcome_var",
        "Outcome Variable:",
        choices = c(
          "Spending per Beneficiary" = "spend_per_bene_mean",
          "Spending per Capita" = "spend_per_capita_mean",
          "Volume per Capita" = "vol_per_capita_mean",
          "Volume per Beneficiary" = "vol_per_bene_mean",
          "Spending per Volume" = "spend_per_vol_mean"
        ),
        selected = "spend_per_bene_mean"
      ),

      hr(),
      h4("Model Parameters"),
      hr(),

      # Estimation method
      selectInput(
        "est_method",
        "Estimation Method:",
        choices = c(
          "Doubly Robust (DR)" = "dr",
          "Inverse Probability Weighting (IPW)" = "ipw",
          "Regression (CS)" = "reg",
          "Two-Way FE Event Study (2014 expanders)" = "twfe"
        ),
        selected = "dr"
      ),

      # Exclude restricted states
      checkboxInput(
        "exclude_restricted",
        "Exclude states with restrictions",
        value = FALSE
      ),

      # Restrict to 2014 expanders (only for CS estimators)
      conditionalPanel(
        condition = "input.est_method != 'twfe'",
        checkboxInput(
          "only_2014_expanders",
          "Only 2014 expanders (vs. never-treated)",
          value = FALSE
        )
      ),

      # Control group (only for CS estimator, and only if not restricted to 2014)
      conditionalPanel(
        condition = "input.est_method != 'twfe' && !input.only_2014_expanders",
        radioButtons(
          "control_group",
          "Control Group:",
          choices = c(
            "Not yet treated" = "notyettreated",
            "Never treated" = "nevertreated"
          ),
          selected = "notyettreated"
        )
      ),

      hr(),

      actionButton(
        "run_analysis",
        "Run Analysis",
        class = "btn-primary btn-lg",
        style = "width: 100%;"
      ),

      hr(),

      # Status message
      verbatimTextOutput("status_message")
    ),

    mainPanel(
      width = 9,
      tabsetPanel(
        tabPanel(
          "Event Study Plot",
          br(),
          fluidRow(
            column(
              width = 4,
              radioButtons(
                "effect_scale",
                "Effect Scale:",
                choices = c(
                  "Absolute" = "absolute",
                  "Relative (% of baseline)" = "relative"
                ),
                selected = "absolute",
                inline = TRUE
              )
            )
          ),
          plotlyOutput("event_study_plot", height = "600px")
        ),
        tabPanel(
          "Summary Statistics",
          br(),
          verbatimTextOutput("model_summary")
        ),
        tabPanel(
          "Data Preview",
          br(),
          DT::dataTableOutput("data_preview")
        )
      )
    )
  )
)

# ==============================================================================
# Server
# ==============================================================================
server <- function(input, output, session) {

  # Reactive value to store results
  results <- reactiveValues(
    agg_results = NULL,
    model_summary = NULL,
    data = NULL,
    baseline_means = NULL
  )

  # Load and prepare data based on selections
  load_data <- reactive({
    req(input$cause_type, input$age_type)

    # Determine which file to load based on selections
    if (input$cause_type == "all") {
      # Use the main TOC PAYER file for all causes
      dt <- fread("data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_2010_2019_Y2025M02D13.CSV")
    } else {
      # Load cause-specific files (split across years)
      dt1 <- fread("data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_CAUSE_2010_2012_Y2025M02D13.CSV")
      dt2 <- fread("data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_CAUSE_2013_2015_Y2025M02D13.CSV")
      dt3 <- fread("data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_CAUSE_2016_2019_Y2025M02D13.CSV")
      dt <- rbindlist(list(dt1, dt2, dt3), fill = TRUE)
    }

    # Filter by age
    dt <- dt[age_name == input$age_type]

    # Filter by cause if specific cause selected
    if (input$cause_type == "specific") {
      dt <- dt[cause_name == input$specific_cause]
    }

    # Filter to relevant TOCs
    dt <- dt[toc %in% c("AM", "ED", "IP", "NF", "RX", "All toc")]

    # Create ID and merge with expansion data
    dt[, id := as.numeric(as.factor(location_name))]
    dt <- merge(dt, medicaid_expansion[, .(location_name, expansion_year, restricted)],
                by = "location_name", all.x = TRUE)
    dt <- merge(dt, covariates, by = c("location_name", "year_id"))

    # Calculate prior uninsured rate
    dt[, ave_prior_uninsured := mean(uninsured_rate[year_id %in% c(2012, 2013)], na.rm = TRUE),
       by = location_name]

    dt[, expansion_year := as.numeric(expansion_year)]
    dt[is.na(expansion_year), expansion_year := 0]

    # Create "All TOC" aggregate
    agg_cols <- names(dt)[grepl("spend|vol", names(dt))]
    group_cols <- setdiff(names(dt), agg_cols)
    group_cols <- group_cols[group_cols != "toc"]

    dt_agg <- dt[, lapply(.SD, sum, na.rm = TRUE),
                 by = group_cols,
                 .SDcols = agg_cols]
    dt_agg[, toc := "All toc"]

    dt <- rbindlist(list(dt, dt_agg), fill = TRUE)

    # Exclude restricted states if selected
    if (input$exclude_restricted) {
      dt <- dt[restricted != "Yes" | is.na(restricted)]
    }

    return(dt)
  })

  # Run analysis when button is clicked
  observeEvent(input$run_analysis, {

    # Show loading message
    output$status_message <- renderText("Loading data and running analysis...")

    tryCatch({
      dt <- load_data()
      results$data <- dt

      if (nrow(dt) == 0) {
        output$status_message <- renderText("No data available for selected filters.")
        return()
      }

      # Check if outcome variable exists
      outcome_var <- input$outcome_var
      if (!outcome_var %in% names(dt)) {
        output$status_message <- renderText(paste("Outcome variable", outcome_var, "not available in data."))
        return()
      }

      # Create model matrix
      payers <- unique(dt$payer)
      tocs <- unique(dt$toc)
      model_grid <- as.data.table(expand.grid(
        payer = as.character(payers),
        toc = as.character(tocs),
        stringsAsFactors = FALSE
      ))
      model_grid[, outcomes := outcome_var]

      # Remove invalid combinations (oop doesn't have per_bene metrics)
      if (grepl("per_bene", outcome_var)) {
        model_grid <- model_grid[payer != "oop"]
      }

      model_grid[, toc := factor(toc, levels = c("All toc", "AM", "ED", "IP", "NF", "RX"))]
      model_grid[, model := paste(payer, toc, outcomes, sep = "|")]
      model_grid[, mod := .I]
      setorder(model_grid, payer, toc)

      method_note <- if (input$est_method == "twfe" || input$only_2014_expanders) " (2014 expanders vs. never-treated)" else ""
      output$status_message <- renderText(paste0("Running ", nrow(model_grid), " models", method_note, "..."))

      # Calculate baseline means for each payer/toc (pre-expansion mean for treated units)
      # For TWFE: treated = 2014 expanders, pre = years < 2014
      # For CS: treated = any expansion_year > 0, pre = year_id < expansion_year
      baseline_means <- dt[expansion_year > 0 & year_id < expansion_year,
                           .(baseline_mean = mean(get(outcome_var), na.rm = TRUE)),
                           by = .(payer, toc)]
      results$baseline_means <- baseline_means

      # Run models - branch based on estimation method
      if (input$est_method == "twfe") {
        # ================================================================
        # Two-Way Fixed Effects Event Study (2014 expanders only)
        # ================================================================

        # Filter to 2014 expanders and never-treated states
        dt_twfe <- dt[expansion_year %in% c(0, 2014)]

        # Create treatment indicator and event time
        dt_twfe[, treated := as.integer(expansion_year == 2014)]
        dt_twfe[, event_time := ifelse(treated == 1, year_id - 2014, NA_integer_)]
        # For never-treated, set event_time to year - 2014 for plotting alignment
        dt_twfe[treated == 0, event_time := year_id - 2014]

        # Run TWFE event study models
        models <- lapply(1:nrow(model_grid), function(i) {
          cur_payer <- as.character(model_grid[i, payer])
          cur_toc <- as.character(model_grid[i, toc])
          cur_outcome <- as.character(model_grid[i, outcomes])

          sub_dt <- dt_twfe[payer == cur_payer & toc == cur_toc]

          if (nrow(sub_dt) < 10) return(NULL)

          # Check for sufficient variation
          if (length(unique(sub_dt$treated)) < 2) return(NULL)

          tryCatch({
            # Event study specification with unit and year FE
            # Reference period is -1 (year before treatment)
            formula_str <- paste0(cur_outcome, " ~ i(event_time, treated, ref = -1) | id + year_id")
            t_model <- feols(as.formula(formula_str),
                             data = sub_dt,
                             cluster = ~id)
            return(t_model)
          }, error = function(e) {
            message(paste("Error in TWFE model", i, ":", e$message))
            return(NULL)
          })
        })

        # Filter out NULL models
        valid_models <- !sapply(models, is.null)
        models <- models[valid_models]
        model_grid <- model_grid[valid_models]
        model_grid[, mod := .I]

        if (length(models) == 0) {
          output$status_message <- renderText("No valid models could be estimated. Check data availability.")
          return()
        }

        # Extract results from TWFE models
        agg_results <- lapply(1:length(models), function(i) {
          model_obj <- models[[i]]
          coef_table <- as.data.table(coeftable(model_obj), keep.rownames = "term")

          # Parse event_time from coefficient names (format: "event_time::X:treated")
          coef_table <- coef_table[grepl("event_time::", term)]
          coef_table[, index := as.integer(gsub("event_time::(-?\\d+):treated", "\\1", term))]

          sdt <- data.table(
            index = coef_table$index,
            att = coef_table$Estimate,
            se = coef_table$`Std. Error`
          )
          sdt[, lower := att - 1.96 * se]
          sdt[, upper := att + 1.96 * se]
          sdt[, exposure_time := ifelse(index >= 0, "Post", "Pre")]
          sdt[, mod := i]

          # Add reference period (index = -1) with zero effect
          ref_row <- data.table(index = -1, att = 0, se = 0, lower = 0, upper = 0,
                                exposure_time = "Pre", mod = i)
          sdt <- rbindlist(list(sdt, ref_row))
          setorder(sdt, index)

          return(sdt)
        }) %>% rbindlist()

        agg_results <- merge(model_grid, agg_results, by = "mod")
        results$agg_results <- agg_results

        # Store overall ATT summary (average post-treatment effect)
        overall_att <- lapply(1:length(models), function(i) {
          model_obj <- models[[i]]
          coef_table <- as.data.table(coeftable(model_obj), keep.rownames = "term")
          coef_table <- coef_table[grepl("event_time::", term)]
          coef_table[, index := as.integer(gsub("event_time::(-?\\d+):treated", "\\1", term))]

          # Average of post-treatment coefficients
          post_coefs <- coef_table[index >= 0]
          if (nrow(post_coefs) > 0) {
            avg_att <- mean(post_coefs$Estimate)
            # Approximate SE (simple average, not accounting for covariance)
            avg_se <- sqrt(mean(post_coefs$`Std. Error`^2) / nrow(post_coefs))
          } else {
            avg_att <- NA
            avg_se <- NA
          }

          data.table(
            payer = as.character(model_grid[i, payer]),
            toc = as.character(model_grid[i, toc]),
            overall_att = avg_att,
            overall_se = avg_se
          )
        }) %>% rbindlist()
        results$model_summary <- overall_att

      } else {
        # ================================================================
        # Callaway & Sant'Anna estimator (DR, IPW, or Regression)
        # ================================================================

        # If only 2014 expanders selected, filter data and force never-treated control
        if (input$only_2014_expanders) {
          dt_cs <- dt[expansion_year %in% c(0, 2014)]
          control_group_use <- "nevertreated"
        } else {
          dt_cs <- dt
          control_group_use <- input$control_group
        }

        models <- lapply(1:nrow(model_grid), function(i) {
          cur_payer <- as.character(model_grid[i, payer])
          cur_toc <- as.character(model_grid[i, toc])
          cur_outcome <- as.character(model_grid[i, outcomes])

          sub_dt <- dt_cs[payer == cur_payer & toc == cur_toc]

          if (nrow(sub_dt) < 10) return(NULL)

          # Check for sufficient variation
          if (length(unique(sub_dt$expansion_year)) < 2) return(NULL)

          tryCatch({
            t_model <- att_gt(
              yname = cur_outcome,
              tname = "year_id",
              idname = "id",
              gname = "expansion_year",
              data = sub_dt,
              control_group = control_group_use,
              clustervars = "id",
              est_method = input$est_method,
              xformla = ~ poverty_rate + median_hh_income + ave_prior_uninsured + prop_under18 + prop_over65
            )
            return(t_model)
          }, error = function(e) {
            message(paste("Error in model", i, ":", e$message))
            return(NULL)
          })
        })

        # Filter out NULL models
        valid_models <- !sapply(models, is.null)
        models <- models[valid_models]
        model_grid <- model_grid[valid_models]
        model_grid[, mod := .I]

        if (length(models) == 0) {
          output$status_message <- renderText("No valid models could be estimated. Check data availability.")
          return()
        }

        # Aggregate models
        agg_models <- lapply(models, function(m) {
          tryCatch(aggte(m, type = "dynamic"), error = function(e) NULL)
        })

        valid_agg <- !sapply(agg_models, is.null)
        agg_models <- agg_models[valid_agg]
        model_grid <- model_grid[valid_agg]
        model_grid[, mod := .I]

        # Extract results
        agg_results <- lapply(1:length(agg_models), function(i) {
          model_obj <- agg_models[[i]]
          sdt <- data.table(
            index = model_obj$egt,
            att = model_obj$att.egt,
            se = model_obj$se.egt
          )
          sdt[, lower := att - 1.96 * se]
          sdt[, upper := att + 1.96 * se]
          sdt[, exposure_time := ifelse(index >= 0, "Post", "Pre")]
          sdt[, mod := i]
          return(sdt)
        }) %>% rbindlist()

        agg_results <- merge(model_grid, agg_results, by = "mod")
        results$agg_results <- agg_results

        # Store overall ATT summary
        overall_att <- lapply(1:length(agg_models), function(i) {
          m <- agg_models[[i]]
          data.table(
            payer = as.character(model_grid[i, payer]),
            toc = as.character(model_grid[i, toc]),
            overall_att = m$overall.att,
            overall_se = m$overall.se
          )
        }) %>% rbindlist()
        results$model_summary <- overall_att
      }

      output$status_message <- renderText(paste("Analysis complete!", length(models), "models estimated."))

    }, error = function(e) {
      output$status_message <- renderText(paste("Error:", e$message))
    })
  })

  # Event study plot
  output$event_study_plot <- renderPlotly({
    req(results$agg_results, input$payer_filter, results$baseline_means)

    data <- copy(results$agg_results)
    baseline_means <- results$baseline_means
    outcome_var <- input$outcome_var

    # Merge baseline means into data
    data <- merge(data, baseline_means, by = c("payer", "toc"), all.x = TRUE)

    # Calculate relative effects (% change from baseline)
    # Handle cases where baseline_mean is NA or 0
    data[, att_rel := ifelse(is.na(baseline_mean) | baseline_mean == 0, NA_real_,
                             100 * att / baseline_mean)]
    data[, lower_rel := ifelse(is.na(baseline_mean) | baseline_mean == 0, NA_real_,
                               100 * lower / baseline_mean)]
    data[, upper_rel := ifelse(is.na(baseline_mean) | baseline_mean == 0, NA_real_,
                               100 * upper / baseline_mean)]
    data[, se_rel := ifelse(is.na(baseline_mean) | baseline_mean == 0, NA_real_,
                            100 * se / baseline_mean)]

    # Create title based on selections
    title_parts <- c()
    if (input$cause_type == "specific") {
      title_parts <- c(title_parts, input$specific_cause)
    } else {
      title_parts <- c(title_parts, "All Causes")
    }
    title_parts <- c(title_parts, input$age_type)

    # Add method indicator
    method_labels <- c(
      "dr" = "CS-DR",
      "ipw" = "CS-IPW",
      "reg" = "CS-Reg",
      "twfe" = "TWFE"
    )
    method_label <- method_labels[input$est_method]
    # Add 2014 expanders note if applicable
    if (input$est_method == "twfe" || input$only_2014_expanders) {
      method_label <- paste0(method_label, " (2014 expanders)")
    }
    title_parts <- c(title_parts, method_label)

    outcome_labels <- c(
      "spend_per_bene_mean" = "Spending per Beneficiary",
      "spend_per_capita_mean" = "Spending per Capita",
      "vol_per_capita_mean" = "Volume per Capita",
      "vol_per_bene_mean" = "Volume per Beneficiary",
      "spend_per_vol_mean" = "Spending per Volume"
    )

    payer_labels <- c(
      "mdcd" = "Medicaid",
      "mdcr" = "Medicare",
      "priv" = "Private",
      "oop" = "Out-of-pocket"
    )

    payer_colors <- c(
      "mdcd" = "#E41A1C",
      "mdcr" = "#377EB8",
      "priv" = "#4DAF4A",
      "oop" = "#984EA3"
    )

    # Add payer labels to data
    data[, payer_label := payer_labels[payer]]

    # Create hover text with both absolute and relative effects
    data[, hover_text := paste0(
      "Payer: ", payer_label, "<br>",
      "TOC: ", toc, "<br>",
      "Years since expansion: ", index, "<br>",
      "Baseline mean: ", ifelse(is.na(baseline_mean), "N/A", round(baseline_mean, 2)), "<br>",
      "<b>ATT (absolute): ", round(att, 2), "</b><br>",
      "95% CI: [", round(lower, 2), ", ", round(upper, 2), "]<br>",
      "<b>ATT (% change): ", ifelse(is.na(att_rel), "N/A", paste0(round(att_rel, 1), "%")), "</b><br>",
      "95% CI: [", ifelse(is.na(lower_rel), "N/A", paste0(round(lower_rel, 1), "%")), ", ",
      ifelse(is.na(upper_rel), "N/A", paste0(round(upper_rel, 1), "%")), "]"
    )]

    # Filter to outcome and selected payers
    plot_data <- data[outcomes == outcome_var & payer %in% input$payer_filter]

    if (nrow(plot_data) == 0) {
      return(plotly_empty() %>% layout(title = "No data for selected payers"))
    }

    # Determine which columns to use based on effect scale
    use_relative <- input$effect_scale == "relative"

    if (use_relative) {
      plot_data[, y_val := att_rel]
      plot_data[, y_lower := lower_rel]
      plot_data[, y_upper := upper_rel]
      y_label <- "ATT Estimate (% change from baseline)"
    } else {
      plot_data[, y_val := att]
      plot_data[, y_lower := lower]
      plot_data[, y_upper := upper]
      y_label <- "ATT Estimate (absolute)"
    }

    # Compute y-limits with some padding (based on att +/- CI, with 10% buffer)
    y_ranges <- plot_data[, .(
      ymin = min(y_lower, na.rm = TRUE),
      ymax = max(y_upper, na.rm = TRUE)
    ), by = toc]
    y_ranges[, padding := (ymax - ymin) * 0.1]
    y_ranges[, ymin := ymin - padding]
    y_ranges[, ymax := ymax + padding]

    # Merge limits back to data for coord_cartesian per facet
    plot_data <- merge(plot_data, y_ranges[, .(toc, ymin, ymax)], by = "toc")

    # Create ggplot
    p <- ggplot(plot_data) +
      geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
      geom_vline(xintercept = 0, linetype = "solid", color = "gray30", linewidth = 0.5) +
      geom_pointrange(
        aes(
          x = index,
          y = y_val,
          ymin = y_lower,
          ymax = y_upper,
          shape = exposure_time,
          color = payer,
          text = hover_text
        ),
        position = position_dodge(width = 0.4),
        alpha = 0.8,
        size = 0.5,
        linewidth = 0.6
      ) +
      geom_blank(aes(y = ymin)) +
      geom_blank(aes(y = ymax)) +
      xlim(c(-4.5, 4.5)) +
      scale_shape_manual(values = c(19, 1)) +
      scale_color_manual(
        values = payer_colors,
        labels = payer_labels
      ) +
      facet_wrap(~toc, scales = "free_y") +
      theme_minimal(base_size = 12) +
      theme(
        legend.position = "bottom",
        panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold"),
        plot.title = element_text(face = "bold")
      ) +
      labs(
        color = "Payer",
        shape = "Period",
        y = y_label,
        x = "Years Since Expansion",
        title = paste(outcome_labels[outcome_var], "-", paste(title_parts, collapse = ", "))
      )

    # Convert to plotly
    ggplotly(p, tooltip = "text") %>%
      layout(
        legend = list(orientation = "h", y = -0.15),
        margin = list(b = 100)
      )
  })

  # Model summary
  output$model_summary <- renderPrint({
    req(results$model_summary, results$baseline_means)
    cat("Overall ATT Estimates by Payer and Type of Care\n")
    cat("================================================\n\n")

    summary_dt <- copy(results$model_summary)
    baseline_means <- results$baseline_means

    # Merge baseline means
    summary_dt <- merge(summary_dt, baseline_means, by = c("payer", "toc"), all.x = TRUE)

    # Calculate relative effects
    summary_dt[, overall_att_pct := 100 * overall_att / baseline_mean]
    summary_dt[, overall_se_pct := 100 * overall_se / baseline_mean]

    summary_dt[, pvalue := 2 * (1 - pnorm(abs(overall_att / overall_se)))]
    summary_dt[, sig := ifelse(pvalue < 0.001, "***",
                               ifelse(pvalue < 0.01, "**",
                                      ifelse(pvalue < 0.05, "*", "")))]

    # Reorder columns for display
    display_cols <- c("payer", "toc", "baseline_mean", "overall_att", "overall_se",
                      "overall_att_pct", "overall_se_pct", "pvalue", "sig")
    display_cols <- display_cols[display_cols %in% names(summary_dt)]

    print(summary_dt[order(payer, toc), ..display_cols])

    cat("\n\nColumn descriptions:")
    cat("\n  baseline_mean: Pre-expansion average for treated units")
    cat("\n  overall_att: Average treatment effect (absolute)")
    cat("\n  overall_att_pct: Average treatment effect (% of baseline)")
    cat("\n\nSignificance: *** p < 0.001, ** p < 0.01, * p < 0.05\n")
  })

  # Data preview
  output$data_preview <- DT::renderDataTable({
    req(results$data)

    preview_cols <- c("location_name", "year_id", "payer", "toc",
                      "expansion_year", input$outcome_var)
    preview_cols <- preview_cols[preview_cols %in% names(results$data)]

    DT::datatable(
      results$data[1:min(1000, nrow(results$data)), ..preview_cols],
      options = list(pageLength = 20, scrollX = TRUE)
    )
  })
}

# ==============================================================================
# Run the application
# ==============================================================================
shinyApp(ui = ui, server = server)
