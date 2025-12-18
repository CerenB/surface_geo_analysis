rm(list = ls()) # Clean console

library(ggplot2)
library(plotly)
library(dplyr)
library(Rmisc)
library(showtext)

# Font setup
font_add("Avenir", regular = "Avenir.ttc")
showtext_auto()

# Set task and paths
task <- "mototopy" # or "somatotopy"
mask <- "area4" # area3a_3b_2_1, area4
path_results <- paste0("/Volumes/extreme/Cerens_files/fMRI/",
  "GlasserAtlas/Glasser_ROIs_sensorimotor/peakCoord/task-",
  task, "/"
)

# Load data
data <- read.csv(
  paste(path_results, "/geodesic_distance_p-0pt990_", mask, ".csv", sep = "")
)
head(data)
colnames(data)

# Ensure the required columns are present
data <- data %>%
  select(sub, group, hemi,
         mask, pairs, vertex1,
         vertex2, geodesic_distance, skip)

# Convert columns to factors
data$mask <- as.factor(data$mask)
data$hemi <- as.factor(data$hemi)
data$group <- as.factor(data$group)
data$pairs <- as.factor(data$pairs)
data$sub <- as.factor(data$sub)


# Filter out skipped (zero) data points
filtered_data <- data %>%
  filter(skip != 1)


# Summarize the data to calculate mean, standard deviation, and standard error
df <- summarySE(
  data = filtered_data,
  groupvars = c("group", "hemi", "pairs"),
  measurevar = "geodesic_distance",
  na.rm = TRUE
)
df

# POSTER plot with individual data points
# bar plot with dots & flipped coordinates
custom_pair_order <- c(
  "Lips-Tongue", "Forehead-Lips", "Forehead-Tongue", "Forehead-Hand",
  "Hand-Lips", "Hand-Tongue", "Foot-Hand", "Foot-Forehead",
  "Foot-Lips", "Foot-Tongue"
)
df$pair_order_dist <- match(df$pairs, custom_pair_order)
df$pairs <- factor(df$pairs, levels = custom_pair_order)

max(filtered_data$geodesic_distance) # 91.13
width_dist_btwn_groups <- 0.8

# Error bar colors
errorbar_colors <- c("ctrl" = "#606060ff", "mbs" = "#448c6dff")


bar_p <- ggplot(df, aes(x = pairs, y = geodesic_distance, fill = group)) +
  geom_bar(
    stat = "identity",
    position = position_dodge(width = width_dist_btwn_groups),
    width = 0.8
  ) +
  geom_errorbar(
    aes(ymin = geodesic_distance - se,
        ymax = geodesic_distance + se, color = group),
    width = 0.2,
    position = position_dodge(width = width_dist_btwn_groups),
    size = 1
  ) +
  geom_jitter(
    data = filtered_data,
    aes(x = pairs, y = geodesic_distance, color = group, fill = group),
    position = position_jitterdodge(
      jitter.width = 0.2,
      dodge.width = width_dist_btwn_groups
    ),
    shape = 21, size = 2, alpha = 0.8
  ) +
  facet_wrap(hemi ~ .) +
  ylim(0, 115) +
  labs(
    x = "Body Part pairs",
    y = "Geodesic Distance (mm)",
    fill = "Groups",
    color = "Groups"
  ) +
  theme_minimal() +
  theme(
    text = element_text(family = "Avenir", color = "black"),
    panel.spacing = unit(2, "lines"),
    axis.title.x = element_text(size = 22, face = "bold"),
    axis.title.y = element_text(size = 22, face = "bold"),
    axis.text.x = element_text(size = 20,
                               hjust = 1, color = "black"),
    axis.text.y = element_text(size = 20, color = "black"),
    legend.title = element_text(size = 22),
    legend.text = element_text(size = 20),
    strip.placement = "inside",
    strip.text = element_text(size = 22, hjust = 0.5),
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    legend.position = "top"
  ) +
  scale_fill_manual(values = c("ctrl" = "#7b7979", "mbs" = "#63c599")) +
  scale_color_manual(values = errorbar_colors) +
  coord_flip()
print(bar_p)

filename <- paste(
  path_results,
  "Flipped_Horizontal_GeoDistance_barPlot_Averaged_Ordered_", task, ".pdf",
  sep = ""
)
ggsave(filename,
       plot = bar_p, width = 18, height = 8, units = "in", dpi = 300)



# Poster plot with unorganized labels
width_dist_btwn_groups <- 0.5

p <- ggplot(
  df, aes(x = pairs, y = geodesic_distance, color = group)
) +
  geom_point(position =
               position_dodge(width = width_dist_btwn_groups), size = 8) +
  geom_errorbar(
    aes(ymin = geodesic_distance - se, ymax = geodesic_distance + se),
    width = 0.2,
    position = position_dodge(width = width_dist_btwn_groups)
  ) +
  facet_grid(hemi ~ .) +
  ylim(0, 90) +
  labs(x = "Body Part pairs", y = "Geodesic Distance", color = "Groups") +
  theme_minimal() +
  theme(
    text = element_text(family = "Avenir", color = "black"),
    panel.spacing = unit(2, "lines"),
    axis.title.x = element_text(size = 20),
    axis.title.y = element_text(size = 20),
    axis.text.x = element_text(size = 16, angle = 45, hjust = 1),
    axis.text.y = element_text(size = 16),
    legend.title = element_text(size = 20),
    legend.text = element_text(size = 18),
    strip.text = element_text(size = 20, hjust = 0.5),
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    legend.position = "top"
  ) +
  scale_color_manual(values = c("ctrl" = "#7b7979", "mbs" = "#63c599"))
print(p)

filename <- paste(
  path_results, "VGeodesicDistancePlot_Averaged_", task, ".pdf", sep = ""
)
ggsave(filename, plot = p, width = 18, height = 6, units = "in", dpi = 300)
ggsave(filename, plot = p, width = 18, height = 9, units = "in", dpi = 300)




# Plot the zeros
zero_data <- data %>% filter(skip == 1)
zero_counts <- zero_data %>%
  group_by(group, hemi, pairs) %>%
  summarise(n_zeros = n()) %>%
  ungroup()

g <- ggplot(zero_counts, aes(x = pairs, y = n_zeros, fill = group)) +
  geom_bar(stat = "identity", position = "dodge") +
  facet_grid(hemi ~ .) +
  labs(
    title = "Count of Zero/NA Geodesic Distances",
    x = "Pair",
    y = "Count (skip == 1)",
    fill = "Group"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  scale_fill_manual(values = c("ctrl" = "#7b7979", "mbs" = "#63c599"))
print(g)

filename <- paste(
  path_results, "BarPlot_ZeroValues_", task, ".pdf", sep = ""
)
ggsave(filename, plot = g, width = 8, height = 6, units = "in", dpi = 300)



# Heatmap of zeros
zero_counts_sub <- zero_data %>%
  dplyr::count(sub, group, hemi, pairs, name = "n_zeros")

f <- ggplot(zero_counts_sub, aes(x = pairs, y = sub, fill = n_zeros)) +
  geom_tile() +
  facet_grid(group ~ hemi) +
  scale_fill_gradient(low = "white", high = "red") +
  labs(
    title = "Heatmap of Zero/NA Geodesic Distances",
    x = "Pair",
    y = "Subject",
    fill = "Count (skip == 1)"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
print(f)

filename <- paste(
  path_results, "Heatmap_ZeroValues_", task, ".pdf", sep = ""
)
ggsave(filename, plot = f, width = 8, height = 6, units = "in", dpi = 300)



# Plot the number of pairs
pair_counts <- filtered_data %>%
  dplyr::count(sub, hemi, pairs, name = "n_pairs")

g <- ggplot(pair_counts, aes(x = pairs, y = sub, fill = n_pairs)) +
  geom_tile() +
  facet_grid(. ~ hemi) +
  scale_fill_gradient(low = "white", high = "blue") +
  labs(
    title = "Distribution of Pairs Across Subjects, and Hemispheres",
    x = "Pair",
    y = "Subject",
    fill = "Count"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
print(g)




# Order pairs by category (face, mixed, no-face)
filtered_data$category <- ifelse(
  filtered_data$pairs %in% c("Lips-Tongue",
                             "Forehead-Lips", "Forehead-Tongue"), "face",
  ifelse(filtered_data$pairs == "Foot-Hand", "no-face", "mixed")
)
filtered_data$pair_order <- ifelse(
  filtered_data$category == "face", 1,
  ifelse(filtered_data$category == "mixed", 2, 3)
)

df <- summarySE(
  data = filtered_data,
  groupvars = c("group", "hemi", "category", "pairs", "pair_order"),
  measurevar = "geodesic_distance",
  na.rm = TRUE
)

pair_levels <- df %>%
  arrange(pair_order, pairs) %>%
  pull(pairs) %>%
  unique()

df$pairs <- factor(df$pairs, levels = pair_levels)
df

g <- ggplot(df, aes(x = pairs, y = geodesic_distance, fill = group)) +
  geom_bar(stat = "identity", position = "dodge") +
  facet_grid(hemi ~ .) +
  labs(x = "Pairs", y = "Mean Geodesic Distance", fill = "Group") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
print(g)



# Poster plot with ordered pairs - unflipped
# Custom order for pairs
custom_pair_order <- c(
  "Lips-Tongue", "Forehead-Lips", "Forehead-Tongue", "Forehead-Hand",
  "Hand-Lips", "Hand-Tongue", "Foot-Hand", "Foot-Forehead",
  "Foot-Lips", "Foot-Tongue"
)
df$pair_order_dist <- match(df$pairs, custom_pair_order)
df$pairs <- factor(df$pairs, levels = custom_pair_order)
width_dist_btwn_groups <- 0.5

# Error bar colors
errorbar_colors <- c("ctrl" = "#606060ff", "mbs" = "#448c6dff")

# Barplot with error bars ( no individual data points)
bar_p <- ggplot(df, aes(x = pairs, y = geodesic_distance, fill = group)) +
  geom_bar(stat = "identity",
           position = position_dodge(width = width_dist_btwn_groups)) +
  geom_errorbar(
    aes(ymin = geodesic_distance - se,
        ymax = geodesic_distance + se, color = group),
    width = 0.2,
    position = position_dodge(width = width_dist_btwn_groups),
    size = 1
  ) +
  facet_grid(hemi ~ .) +
  ylim(0, 90) +
  labs(
    x = "Body Part pairs",
    y = "Geodesic Distance",
    fill = "Groups",
    color = "Groups"
  ) +
  theme_minimal() +
  theme(
    text = element_text(family = "Avenir", color = "black"),
    panel.spacing = unit(2, "lines"),
    axis.title.x = element_text(size = 20),
    axis.title.y = element_text(size = 20),
    axis.text.x = element_text(size = 16,
                               angle = 45, hjust = 1, color = "black"),
    axis.text.y = element_text(size = 16, color = "black"),
    legend.title = element_text(size = 20),
    legend.text = element_text(size = 18),
    strip.text = element_text(size = 20, hjust = 0.5),
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    legend.position = "top"
  ) +
  scale_fill_manual(values = c("ctrl" = "#7b7979", "mbs" = "#63c599")) +
  scale_color_manual(values = errorbar_colors)
print(bar_p)

filename <- paste(
  path_results,
  "GeodesicDistanceBARPlot_Averaged_Ordered", task, ".pdf", sep = ""
)
ggsave(filename, plot = bar_p, width = 18, height = 9, units = "in", dpi = 300)







# Dot plot with error bars
# library needed for multiple color scales
library(ggnewscale)
errorbar_colors <- c("ctrl" = "#606060ff", "mbs" = "#448c6dff")

dot_p <- ggplot(df, aes(x = pairs, y = geodesic_distance, color = group)) +
  geom_point(position =
               position_dodge(width = width_dist_btwn_groups), size = 8) +
  geom_errorbar(
    aes(ymin = geodesic_distance - se,
        ymax = geodesic_distance + se, color = group),
    width = 0.2,
    position = position_dodge(width = width_dist_btwn_groups),
    size = 1.2
  ) +
  facet_grid(hemi ~ .) +
  ylim(0, 90) +
  labs(
    x = "Body Part pairs",
    y = "Geodesic Distance",
    color = "Groups"
  ) +
  theme_minimal() +
  theme(
    text = element_text(family = "Avenir", color = "black"),
    panel.spacing = unit(2, "lines"),
    axis.title.x = element_text(size = 20),
    axis.title.y = element_text(size = 20),
    axis.text.x = element_text(size = 16,
                               angle = 45, hjust = 1, color = "black"),
    axis.text.y = element_text(size = 16, color = "black"),
    legend.title = element_text(size = 20),
    legend.text = element_text(size = 18),
    strip.text = element_text(size = 20, hjust = 0.5),
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    legend.position = "top"
  ) +
  scale_color_manual(values = c("ctrl" = "#7b7979", "mbs" = "#63c599")) +
  guides(color =
           guide_legend(override.aes = list(color = c("#7b7979", "#63c599")))) +
  ggnewscale::new_scale_color() +
  geom_errorbar(
    aes(
      x = pairs, y = geodesic_distance,
      ymin = geodesic_distance - se,
      ymax = geodesic_distance + se,
      color = group
    ),
    width = 0.2,
    position = position_dodge(width = width_dist_btwn_groups),
    size = 1.2,
    inherit.aes = FALSE
  ) +
  scale_color_manual(values = errorbar_colors, guide = "none")
print(dot_p)

filename <- paste(
  path_results,
  "GeodesicDistanceDOTPlot_Averaged_Ordered", task, ".pdf", sep = ""
)
ggsave(filename, plot = dot_p, width = 18, height = 9, units = "in", dpi = 300)







##### Stats on geodesic distance
library(broom)
filtered_data$category <- ifelse(
  filtered_data$pairs == "Foot-Hand", "no-face",
  ifelse(data$pairs %in% c("Lips-Tongue",
                           "Forehead-Lips", "Forehead-Tongue"), "face", "mixed")
)
head(filtered_data$pairs)

df2 <- summarySE(
  data = filtered_data,
  groupvars = c("group", "hemi", "category", "pairs"),
  measurevar = "geodesic_distance",
  na.rm = TRUE
)
df2

# ANOVA
anova_model <- aov(geodesic_distance ~
                     pairs * group * hemi, data = filtered_data)
qqnorm(anova_model$residuals)
qqline(anova_model$residuals)
shapiro.test(anova_model$residuals)

if (!requireNamespace("car", quietly = TRUE)) {
  install.packages("car")
}
library(car)
leveneTest(geodesic_distance ~ pairs * group * hemi, data = filtered_data)

# Permutation ANOVA
library(permuco)
perm_model <- aovperm(
  geodesic_distance ~ pairs * group * hemi,
  data = filtered_data, np = 2000
)
results <- summary(perm_model)
print(results)
filename <- paste(
  path_results, "permutationAnovaTable_", task, "_GeoDist.csv", sep = ""
)
write.csv(results, filename)




# Interaction pairs:group
title_x <- "Body Part pairs"
title_y <- "Mean Geodesic Distance"
title_mid <- "Interaction Pair:Group (PermutationANOVA)"

df <- summarySE(
  data = filtered_data,
  groupvars = c("pairs", "group"),
  measurevar = "geodesic_distance",
  na.rm = TRUE
)
df
custom_pair_order <- c(
  "Lips-Tongue", "Forehead-Lips", "Forehead-Tongue", "Forehead-Hand",
  "Hand-Lips", "Hand-Tongue", "Foot-Hand", "Foot-Forehead",
  "Foot-Lips", "Foot-Tongue"
)
df$pairs <- factor(df$pairs, levels = custom_pair_order)
group_colors <- c("ctrl" = "#7b7979", "mbs" = "#63c599")

p <- ggplot(
  df,
  aes(x = pairs,
      y = geodesic_distance,
      color = group,
      shape = group,
      group = group)
) +
  geom_point(size = 3, position = position_dodge(width = 0.5)) +
  geom_errorbar(
    aes(ymin = geodesic_distance - se, ymax = geodesic_distance + se),
    width = 0.2,
    position = position_dodge(width = 0.5)
  ) +
  geom_line(
    aes(group = group),
    position = position_dodge(width = 0.5),
    linetype = "dashed", size = 1
  ) +
  labs(
    x = title_x,
    y = title_y,
    color = "Group",
    shape = "Group",
    title = title_mid
  ) +
  scale_color_manual(values = group_colors) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.title = element_text(size = 16, hjust = 0.5)
  )
print(p)

filename <- paste(
  path_results, "PairGroup_Interaction_GeoDist_", task, ".png", sep = ""
)
ggsave(filename, plot = p, width = 12, height = 6, units = "in", dpi = 300)



# Face/no-face/mixed data split x Groups
df <- summarySE(
  data = filtered_data,
  groupvars = c("category", "group", "hemi"),
  measurevar = "geodesic_distance",
  na.rm = TRUE
)
df

title_x <- "BodyPart pairs"
title_y <- "Geodesic Distance"

p <- ggplot(df, aes(x = category, y = geodesic_distance, color = group)) +
  geom_point(position = position_dodge(width = 0.8), size = 3) +
  geom_errorbar(
    aes(ymin = geodesic_distance - se, ymax = geodesic_distance + se),
    width = 0.2,
    position = position_dodge(width = 0.8)
  ) +
  facet_wrap(~ hemi) +
  labs(x = title_x, y = title_y, color = "group") +
  theme_minimal() +
  theme(
    strip.text = element_text(size = 14, hjust = 0.5),
    axis.text.x = element_text(size = 12, angle = 0, hjust = 1),
    axis.text.y = element_text(size = 12),
    axis.title.x = element_text(size = 14),
    axis.title.y = element_text(size = 14),
    legend.text = element_text(size = 10),
    legend.title = element_text(size = 12),
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    legend.position = "top"
  ) +
  scale_color_manual(values = group_colors)
print(p)

filename <- paste(
  path_results, "GeoDistPlot_", task, "_3Categories.png", sep = ""
)
ggsave(filename, plot = p, width = 12, height = 6, units = "in", dpi = 300)



# Permutation ANOVA for these pairs
perm_model <- aovperm(
  geodesic_distance ~ category * group * hemi,
  data = filtered_data, np = 2000
)
results <- summary(perm_model)
print(results)
filename <- paste(
  path_results, "permutationAnovaTable_GeoDist_",
  task,
  "_3Categories.csv", sep = ""
)
write.csv(results, filename)

#