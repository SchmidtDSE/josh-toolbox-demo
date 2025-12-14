# Post-Fire Vegetation Recovery: Scenario Comparison Visualizations
# ==============================================================================
#
# Creates publication-quality visualizations comparing management scenarios.
#
# Trees initialized with varied ages (0-20 years) to approximate equilibrium.
# Fire (if any) occurs at step 0.
#
# Scenarios:
#   baseline     - No fire (counterfactual)
#   fire_only    - Fire, no intervention
#   fire_seeding - Fire + seeding intervention
#   fire_removal - Fire + invasive removal
#   fire_both    - Fire + combined interventions
#
# ==============================================================================

library(tidyverse)
library(scales)

# Create output directories (organized structure)
dir.create("analysis/figures/timeseries", showWarnings = FALSE, recursive = TRUE)
dir.create("analysis/figures/spatial", showWarnings = FALSE, recursive = TRUE)
dir.create("analysis/figures/comparisons", showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# DATA LOADING
# ==============================================================================

# Load combined results (check both old and new locations)
data_path <- if (file.exists("analysis/summaries/all_scenarios_combined.csv")) {
  "analysis/summaries/all_scenarios_combined.csv"
} else if (file.exists("results/all_scenarios_combined.csv")) {
  "results/all_scenarios_combined.csv"
} else {
  stop("Run demo_workflow.ipynb first to generate scenario data")
}

cat("Loading data from:", data_path, "\n")
data <- read_csv(data_path, show_col_types = FALSE)

# Standardize column names if needed
if ("numSeedling" %in% names(data)) {
  data <- data %>%
    rename(
      seedlingCount = numSeedling,
      juvenileCount = numJuvenile,
      adultCount = numAdult,
      totalTrees = numAlive,
      x = position.x,
      y = position.y
    )
}

# Define scenario order and labels
scenario_order <- c("baseline", "fire_only", "fire_seeding", "fire_removal", "fire_both")
scenario_labels <- c(
  "baseline" = "Baseline\n(No Fire)",
  "fire_only" = "Fire Only",
  "fire_seeding" = "Fire +\nSeeding",
  "fire_removal" = "Fire +\nRemoval",
  "fire_both" = "Fire +\nBoth"
)

# Apply factor ordering
data <- data %>%
  filter(scenario %in% scenario_order) %>%
  mutate(scenario = factor(scenario, levels = scenario_order, labels = scenario_labels))

# Use step directly as year_post_fire (fire at step 0)
data <- data %>%
  mutate(year_post_fire = step)

cat("Data dimensions:", nrow(data), "rows\n")
cat("Scenarios:", paste(levels(data$scenario), collapse = ", "), "\n")
cat("Years:", min(data$year_post_fire), "to", max(data$year_post_fire), "\n")

# ==============================================================================
# AGGREGATE TIME SERIES
# ==============================================================================

time_series <- data %>%
  group_by(scenario, replicate, year_post_fire) %>%
  summarise(
    totalSeedlings = sum(seedlingCount, na.rm = TRUE),
    totalJuveniles = sum(juvenileCount, na.rm = TRUE),
    totalAdults = sum(adultCount, na.rm = TRUE),
    totalTrees = sum(totalTrees, na.rm = TRUE),
    meanInvasive = mean(invasiveCover, na.rm = TRUE) * 100,
    .groups = "drop"
  )

time_series_summary <- time_series %>%
  group_by(scenario, year_post_fire) %>%
  summarise(
    trees_mean = mean(totalTrees),
    trees_se = sd(totalTrees) / sqrt(n()),
    trees_lower = trees_mean - 1.96 * max(trees_se, 0.1, na.rm = TRUE),
    trees_upper = trees_mean + 1.96 * max(trees_se, 0.1, na.rm = TRUE),
    invasive_mean = mean(meanInvasive),
    invasive_se = sd(meanInvasive) / sqrt(n()),
    invasive_lower = pmax(0, invasive_mean - 1.96 * max(invasive_se, 0.1, na.rm = TRUE)),
    invasive_upper = pmin(100, invasive_mean + 1.96 * max(invasive_se, 0.1, na.rm = TRUE)),
    seedlings_mean = mean(totalSeedlings),
    juveniles_mean = mean(totalJuveniles),
    adults_mean = mean(totalAdults),
    .groups = "drop"
  )

# ==============================================================================
# FIGURE 1: TOTAL TREE POPULATION - SCENARIO COMPARISON
# ==============================================================================

# Color palette for scenarios (must match scenario_labels)
scenario_colors <- c(
  "Baseline\n(No Fire)" = "#2166ac",
  "Fire Only" = "#b2182b",
  "Fire +\nSeeding" = "#4daf4a",
  "Fire +\nRemoval" = "#ff7f00",
  "Fire +\nBoth" = "#984ea3"
)

p1 <- ggplot(time_series_summary, aes(x = year_post_fire, y = trees_mean, color = scenario, fill = scenario)) +
  geom_ribbon(aes(ymin = trees_lower, ymax = trees_upper), alpha = 0.15, color = NA) +
  geom_line(linewidth = 1.2) +
  scale_color_manual(values = scenario_colors) +
  scale_fill_manual(values = scenario_colors) +
  labs(
    title = "Tree Population Recovery Under Different Management Scenarios",
    subtitle = "50-year cold start to equilibrium, then fire at Year 0; showing post-fire recovery",
    x = "Years Post-Fire",
    y = "Total Living Trees (all patches)",
    color = "Scenario",
    fill = "Scenario"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  ) +
  guides(color = guide_legend(nrow = 1), fill = guide_legend(nrow = 1))

ggsave("analysis/figures/timeseries/fig1_tree_population_comparison.png", p1, width = 12, height = 7, dpi = 300)
cat("Saved: analysis/figures/timeseries/fig1_tree_population_comparison.png\n")

# ==============================================================================
# FIGURE 2: INVASIVE COVER - SCENARIO COMPARISON
# ==============================================================================

p2 <- ggplot(time_series_summary, aes(x = year_post_fire, y = invasive_mean, color = scenario, fill = scenario)) +
  geom_ribbon(aes(ymin = invasive_lower, ymax = invasive_upper), alpha = 0.15, color = NA) +
  geom_line(linewidth = 1.2) +
  geom_hline(yintercept = 50, linetype = "dashed", color = "gray40", linewidth = 0.8) +
  annotate("text", x = 48, y = 53, label = "Establishment threshold (50%)",
           hjust = 1, size = 3, color = "gray40") +
  scale_color_manual(values = scenario_colors) +
  scale_fill_manual(values = scenario_colors) +
  scale_y_continuous(limits = c(0, 100), labels = function(x) paste0(x, "%")) +
  labs(
    title = "Invasive Grass Cover Under Different Management Scenarios",
    subtitle = "Above 50% threshold, native seedling establishment is blocked",
    x = "Years Post-Fire",
    y = "Mean Invasive Cover",
    color = "Scenario",
    fill = "Scenario"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  ) +
  guides(color = guide_legend(nrow = 1), fill = guide_legend(nrow = 1))

ggsave("analysis/figures/timeseries/fig2_invasive_cover_comparison.png", p2, width = 12, height = 7, dpi = 300)
cat("Saved: analysis/figures/timeseries/fig2_invasive_cover_comparison.png\n")

# ==============================================================================
# FIGURE 3: FINAL OUTCOMES BAR CHART
# ==============================================================================

final_outcomes <- time_series %>%
  filter(year_post_fire == max(year_post_fire)) %>%
  group_by(scenario) %>%
  summarise(
    trees_mean = mean(totalTrees),
    trees_sd = sd(totalTrees),
    invasive_mean = mean(meanInvasive),
    invasive_sd = sd(meanInvasive),
    .groups = "drop"
  )

# Get baseline for comparison
baseline_trees <- final_outcomes$trees_mean[final_outcomes$scenario == "Baseline\n(No Fire)"]

p3 <- ggplot(final_outcomes, aes(x = scenario, y = trees_mean, fill = scenario)) +
  geom_col(width = 0.7) +
  geom_errorbar(aes(ymin = pmax(0, trees_mean - trees_sd), ymax = trees_mean + trees_sd),
                width = 0.2) +
  geom_hline(yintercept = baseline_trees, linetype = "dashed", color = "gray40", linewidth = 0.8) +
  annotate("text", x = 5.3, y = baseline_trees + 100, label = "Baseline level",
           hjust = 1, size = 3, color = "gray40") +
  scale_fill_manual(values = scenario_colors) +
  labs(
    title = "Final Tree Population at Year 50",
    subtitle = "Dashed line = baseline (no fire) counterfactual",
    x = NULL,
    y = "Total Trees"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "none",
    plot.title = element_text(face = "bold"),
    axis.text.x = element_text(size = 10)
  )

ggsave("analysis/figures/comparisons/fig3_final_tree_population.png", p3, width = 10, height = 6, dpi = 300)
cat("Saved: analysis/figures/comparisons/fig3_final_tree_population.png\n")

# ==============================================================================
# FIGURE 4: FIRE SEVERITY MAP (from fire_only scenario)
# ==============================================================================

fire_data <- data %>%
  filter(year_post_fire == 0, replicate == min(replicate),
         scenario == "Fire Only") %>%
  select(x, y, fireSeverity) %>%
  distinct()

if (nrow(fire_data) > 0) {
  p4 <- ggplot(fire_data, aes(x = x, y = y, fill = fireSeverity)) +
    geom_tile() +
    scale_fill_gradient2(
      low = "white", mid = "orange", high = "darkred",
      midpoint = 0.5, limits = c(0, 1), labels = scales::percent
    ) +
    coord_fixed() +
    labs(
      title = "Fire Severity Map",
      subtitle = "Input disturbance pattern from external GeoTIFF",
      x = "Longitude (grid units)",
      y = "Latitude (grid units)",
      fill = "Severity"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      legend.position = "right"
    )

  ggsave("analysis/figures/spatial/fig4_fire_severity_map.png", p4, width = 8, height = 7, dpi = 300)
  cat("Saved: analysis/figures/spatial/fig4_fire_severity_map.png\n")
}

# ==============================================================================
# FIGURE 5: INTERVENTION EFFECTIVENESS (% of baseline recovered)
# ==============================================================================

fire_only_trees <- final_outcomes$trees_mean[final_outcomes$scenario == "Fire Only"]

effectiveness <- final_outcomes %>%
  filter(scenario != "Baseline\n(No Fire)") %>%
  mutate(
    recovery_pct = (trees_mean - fire_only_trees) / (baseline_trees - fire_only_trees) * 100,
    recovery_pct = pmax(0, recovery_pct)  # Cap at 0%
  )

p5 <- ggplot(effectiveness, aes(x = scenario, y = recovery_pct, fill = scenario)) +
  geom_col(width = 0.7) +
  geom_hline(yintercept = 0, color = "gray40") +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray40") +
  annotate("text", x = 4.3, y = 103, label = "Full recovery", hjust = 1, size = 3, color = "gray40") +
  scale_fill_manual(values = scenario_colors) +
  scale_y_continuous(labels = function(x) paste0(x, "%"), limits = c(-5, 110)) +
  labs(
    title = "Intervention Effectiveness: Recovery Towards Baseline",
    subtitle = "0% = fire_only outcome, 100% = baseline (no fire) outcome",
    x = NULL,
    y = "Recovery (%)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "none",
    plot.title = element_text(face = "bold"),
    axis.text.x = element_text(size = 10)
  )

ggsave("analysis/figures/comparisons/fig5_intervention_effectiveness.png", p5, width = 10, height = 6, dpi = 300)
cat("Saved: analysis/figures/comparisons/fig5_intervention_effectiveness.png\n")

# ==============================================================================
# FIGURE 6: LIFE STAGE COMPOSITION BY SCENARIO
# ==============================================================================

life_stage_data <- time_series_summary %>%
  select(scenario, year_post_fire, seedlings_mean, juveniles_mean, adults_mean) %>%
  pivot_longer(
    cols = c(seedlings_mean, juveniles_mean, adults_mean),
    names_to = "stage", values_to = "count"
  ) %>%
  mutate(stage = factor(
    stage,
    levels = c("seedlings_mean", "juveniles_mean", "adults_mean"),
    labels = c("Seedlings", "Juveniles", "Adults")
  ))

p6 <- ggplot(life_stage_data, aes(x = year_post_fire, y = count, fill = stage)) +
  geom_area(alpha = 0.8, position = "stack") +
  facet_wrap(~scenario, nrow = 1) +
  scale_fill_manual(values = c("Seedlings" = "#66c2a5", "Juveniles" = "#fc8d62", "Adults" = "#8da0cb")) +
  labs(
    title = "Tree Population Composition by Life Stage",
    subtitle = "Population starts from 50-year equilibrium; fire scenarios show post-fire recovery",
    x = "Years Post-Fire",
    y = "Number of Trees",
    fill = "Life Stage"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank(),
    strip.text = element_text(size = 9)
  )

ggsave("analysis/figures/timeseries/fig6_life_stages_by_scenario.png", p6, width = 14, height = 5, dpi = 300)
cat("Saved: analysis/figures/timeseries/fig6_life_stages_by_scenario.png\n")

# ==============================================================================
# FIGURE 7: COMPREHENSIVE SCENARIO DASHBOARD (Faceted)
# ==============================================================================

# Prepare data for faceted view - trees and invasive cover over time
dashboard_data <- time_series_summary %>%
  select(scenario, year_post_fire, trees_mean, invasive_mean,
         seedlings_mean, juveniles_mean, adults_mean) %>%
  pivot_longer(
    cols = c(trees_mean, invasive_mean),
    names_to = "metric",
    values_to = "value"
  ) %>%
  mutate(
    metric = factor(metric,
                    levels = c("trees_mean", "invasive_mean"),
                    labels = c("Total Trees", "Invasive Cover (%)"))
  )

p7 <- ggplot(dashboard_data, aes(x = year_post_fire, y = value, color = scenario)) +
  geom_line(linewidth = 1.2) +
  facet_grid(metric ~ scenario, scales = "free_y", switch = "y") +
  scale_color_manual(values = scenario_colors) +
  labs(
    title = "Scenario Comparison Dashboard",
    subtitle = "Tree population and invasive cover dynamics across all management scenarios",
    x = "Years Post-Fire",
    y = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "none",
    plot.title = element_text(face = "bold", size = 14),
    strip.text = element_text(size = 9, face = "bold"),
    strip.placement = "outside",
    panel.grid.minor = element_blank(),
    panel.spacing = unit(0.5, "lines")
  )

ggsave("analysis/figures/comparisons/fig7_scenario_dashboard.png", p7, width = 16, height = 8, dpi = 300)
cat("Saved: analysis/figures/comparisons/fig7_scenario_dashboard.png\n")

# ==============================================================================
# FIGURE 8: ALL METRICS BY SCENARIO (Comprehensive Faceted View)
# ==============================================================================

# Create a long-form dataset with all key metrics
metrics_long <- time_series_summary %>%
  select(scenario, year_post_fire,
         `Total Trees` = trees_mean,
         `Invasive Cover (%)` = invasive_mean,
         `Seedlings` = seedlings_mean,
         `Juveniles` = juveniles_mean,
         `Adults` = adults_mean) %>%
  pivot_longer(
    cols = -c(scenario, year_post_fire),
    names_to = "metric",
    values_to = "value"
  ) %>%
  mutate(
    metric = factor(metric, levels = c("Total Trees", "Invasive Cover (%)",
                                        "Seedlings", "Juveniles", "Adults"))
  )

p8 <- ggplot(metrics_long, aes(x = year_post_fire, y = value, color = metric)) +
  geom_line(linewidth = 1) +
  facet_wrap(~ scenario, nrow = 1, scales = "free_y") +
  scale_color_manual(values = c(
    "Total Trees" = "#1b9e77",
    "Invasive Cover (%)" = "#d95f02",
    "Seedlings" = "#7570b3",
    "Juveniles" = "#e7298a",
    "Adults" = "#66a61e"
  )) +
  labs(
    title = "Complete Scenario Comparison: All Metrics Over Time",
    subtitle = "Each panel shows one scenario with all key metrics",
    x = "Years Post-Fire",
    y = "Value",
    color = "Metric"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    plot.title = element_text(face = "bold", size = 14),
    strip.text = element_text(size = 10, face = "bold"),
    panel.grid.minor = element_blank()
  ) +
  guides(color = guide_legend(nrow = 1))

ggsave("analysis/figures/comparisons/fig8_all_metrics_by_scenario.png", p8, width = 18, height = 6, dpi = 300)
cat("Saved: analysis/figures/comparisons/fig8_all_metrics_by_scenario.png\n")

# ==============================================================================
# FIGURE 9: INTERVENTION COMPARISON MATRIX
# ==============================================================================

# Compare fire scenarios side by side
fire_scenarios <- time_series_summary %>%
  filter(scenario != "Baseline\n(No Fire)")

# Dual-axis style plot using separate panels
comparison_data <- fire_scenarios %>%
  select(scenario, year_post_fire, trees_mean, invasive_mean) %>%
  mutate(
    `Tree Population` = trees_mean,
    `Invasive Cover (%)` = invasive_mean
  ) %>%
  select(-trees_mean, -invasive_mean) %>%
  pivot_longer(
    cols = c(`Tree Population`, `Invasive Cover (%)`),
    names_to = "metric",
    values_to = "value"
  )

p9 <- ggplot(comparison_data, aes(x = year_post_fire, y = value, color = scenario)) +
  geom_line(linewidth = 1.2) +
  geom_hline(data = data.frame(metric = "Invasive Cover (%)", yint = 50),
             aes(yintercept = yint), linetype = "dashed", color = "gray50") +
  facet_wrap(~ metric, scales = "free_y", ncol = 1) +
  scale_color_manual(values = c(
    "Fire Only" = "#b2182b",
    "Fire +\nSeeding" = "#4daf4a",
    "Fire +\nRemoval" = "#ff7f00",
    "Fire +\nBoth" = "#984ea3"
  )) +
  labs(
    title = "Fire Scenario Comparison: Effect of Management Interventions",
    subtitle = "Comparing tree recovery and invasive dynamics across intervention strategies",
    x = "Years Post-Fire",
    y = NULL,
    color = "Scenario"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    plot.title = element_text(face = "bold"),
    strip.text = element_text(size = 11, face = "bold"),
    panel.grid.minor = element_blank()
  ) +
  guides(color = guide_legend(nrow = 1))

ggsave("analysis/figures/comparisons/fig9_intervention_comparison.png", p9, width = 12, height = 10, dpi = 300)
cat("Saved: analysis/figures/comparisons/fig9_intervention_comparison.png\n")

# ==============================================================================
# SUMMARY TABLE
# ==============================================================================

max_year <- max(time_series$year_post_fire)

cat("\n========================================\n")
cat(sprintf("SUMMARY: Final Outcomes at Year %d Post-Fire\n", max_year))
cat("========================================\n\n")

summary_table <- final_outcomes %>%
  mutate(
    trees = sprintf("%.0f", trees_mean),
    invasive = sprintf("%.1f%%", invasive_mean),
    vs_baseline = sprintf("%.0f%%", trees_mean / baseline_trees * 100)
  ) %>%
  select(scenario, trees, invasive, vs_baseline)

print(summary_table, n = Inf)

cat("\n")
cat("Key findings:\n")
cat("- Baseline (no fire): ", round(baseline_trees), " trees\n", sep = "")
cat("- Fire only (no intervention): ", round(fire_only_trees), " trees (",
    round(fire_only_trees/baseline_trees*100), "% of baseline)\n", sep = "")

best_intervention <- final_outcomes %>%
  filter(scenario != "Baseline\n(No Fire)") %>%
  arrange(desc(trees_mean)) %>%
  slice(1)

cat("- Best intervention: ", as.character(best_intervention$scenario), " with ",
    round(best_intervention$trees_mean), " trees (",
    round(best_intervention$trees_mean/baseline_trees*100), "% of baseline)\n", sep = "")

# Show equilibrium state at fire time
year0_data <- time_series %>%
  filter(year_post_fire == 0) %>%
  group_by(scenario) %>%
  summarise(trees = mean(totalTrees), .groups = "drop")

cat("\nEquilibrium at fire time (Year 0):\n")
for (i in 1:nrow(year0_data)) {
  cat("  ", as.character(year0_data$scenario[i]), ": ", round(year0_data$trees[i]), " trees\n", sep = "")
}

# ==============================================================================
# FIGURE 10: SPATIAL FINAL STATE MAPS - TREE DENSITY BY SCENARIO
# ==============================================================================

# Get final state spatial data
final_spatial <- data %>%
  filter(year_post_fire == max(year_post_fire), replicate == min(replicate))

# Tree density map across scenarios
p10 <- ggplot(final_spatial, aes(x = x, y = y, fill = totalTrees)) +
  geom_tile() +
  facet_wrap(~scenario, nrow = 1) +
  scale_fill_viridis_c(option = "D", limits = c(0, max(final_spatial$totalTrees, na.rm = TRUE))) +
  coord_fixed() +
  labs(
    title = "Tree Density at Year 50 by Scenario",
    subtitle = "Spatial distribution of recovery across management strategies",
    x = "X coordinate",
    y = "Y coordinate",
    fill = "Trees/patch"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold"),
    strip.text = element_text(size = 9, face = "bold"),
    legend.position = "right"
  )

ggsave("analysis/figures/spatial/fig10_final_tree_density_maps.png", p10, width = 18, height = 5, dpi = 300)
cat("Saved: analysis/figures/spatial/fig10_final_tree_density_maps.png\n")

# ==============================================================================
# FIGURE 11: SPATIAL FINAL STATE MAPS - INVASIVE COVER BY SCENARIO
# ==============================================================================

p11 <- ggplot(final_spatial, aes(x = x, y = y, fill = invasiveCover * 100)) +
  geom_tile() +
  facet_wrap(~scenario, nrow = 1) +
  scale_fill_gradient(low = "white", high = "darkgreen", limits = c(0, 100)) +
  coord_fixed() +
  labs(
    title = "Invasive Cover at Year 50 by Scenario",
    subtitle = "Spatial distribution of invasive grass across management strategies",
    x = "X coordinate",
    y = "Y coordinate",
    fill = "Cover (%)"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold"),
    strip.text = element_text(size = 9, face = "bold"),
    legend.position = "right"
  )

ggsave("analysis/figures/spatial/fig11_final_invasive_cover_maps.png", p11, width = 18, height = 5, dpi = 300)
cat("Saved: analysis/figures/spatial/fig11_final_invasive_cover_maps.png\n")

# ==============================================================================
# FIGURE 12: INTERVENTION BENEFIT DIFFERENCE MAPS
# ==============================================================================

# Calculate spatial differences for intervention benefits
fire_only_final <- final_spatial %>%
  filter(scenario == "Fire Only") %>%
  select(x, y, fire_only_trees = totalTrees)

# Join intervention scenarios with fire_only
intervention_diffs <- final_spatial %>%
  filter(scenario != "Baseline\n(No Fire)") %>%
  left_join(fire_only_final, by = c("x", "y")) %>%
  mutate(tree_diff = totalTrees - fire_only_trees)

p12 <- ggplot(intervention_diffs %>% filter(scenario != "Fire Only"),
              aes(x = x, y = y, fill = tree_diff)) +
  geom_tile() +
  facet_wrap(~scenario, nrow = 1) +
  scale_fill_gradient2(low = "#d73027", mid = "white", high = "#1a9850", midpoint = 0) +
  coord_fixed() +
  labs(
    title = "Intervention Benefit Maps: Additional Trees vs Fire-Only",
    subtitle = "Green = intervention added trees; Red = fewer trees than fire-only baseline",
    x = "X coordinate",
    y = "Y coordinate",
    fill = "Tree\ndifference"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold"),
    strip.text = element_text(size = 10, face = "bold"),
    legend.position = "right"
  )

ggsave("analysis/figures/spatial/fig12_intervention_benefit_maps.png", p12, width = 14, height = 5, dpi = 300)
cat("Saved: analysis/figures/spatial/fig12_intervention_benefit_maps.png\n")

cat("\n========================================\n")
cat("All figures saved to analysis/figures/\n")
cat("========================================\n")
