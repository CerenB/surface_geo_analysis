rm(list = ls()) # Clean console

library(ggplot2)
library(plotly)
library(Rmisc)
library(showtext)
library(purrr)
library(stringr)
library(dplyr)

# Font setup
font_add("Avenir", regular = "Avenir.ttc")
showtext_auto()

# Set task and paths
task <- "mototopy"
mask <- "area4" # area3a_3b_2_1, area4
path_results <- paste0("/Volumes/extreme/Cerens_files/fMRI/",
                       "GlasserAtlas/Glasser_ROIs_sensorimotor/peakCoord/task-",
                       task, "/")

# Load data

# Set up subject IDs
ctrl_ids <- sprintf("sub-ctrl%03d", 1:17)
mbs_ids  <- sprintf("sub-mbs%03d", 1:7)
subjects <- c(ctrl_ids, mbs_ids)

# Function to read and add hemi column
read_with_hemi <- function(sub, hemi) {
  file_name <- sprintf(
    "%s_fs_LR_p-0pt990_%s_%s_all_peaks_mid.csv", sub, hemi, mask
  )
  file_path <- file.path(path_results, file_name)
  if (file.exists(file_path)) {
    df <- read.csv(file_path)
    df$hemi <- hemi
    df$sub <- sub
    return(df)
  } else {
    warning(paste("File not found:", file_path))
    return(NULL)
  }
}

# Read all R hemisphere files
dfs_r <- map(subjects, ~read_with_hemi(.x, "R"))
data_r <- bind_rows(dfs_r)

# Read all L hemisphere files
dfs_l <- map(subjects, ~read_with_hemi(.x, "L"))
data_l <- bind_rows(dfs_l)

# Combine both hemispheres
all_data <- bind_rows(data_r, data_l)

#count how many vertices per subject, condition, mask, hemi

all_data_count <- all_data %>%
  add_count(sub, condition, mask, hemi, name = "tot_vertex") %>%
  group_by(sub, condition, mask, hemi) %>%
  slice(1) %>%
  ungroup()
head(all_data_count)

# clear the data with zeros
filtered_data <- all_data_count %>%
  filter(vertex > 0)
head(filtered_data)

# create a column for group
# if sub-ctrl* then group is ctrl else mbs
filtered_data$group <- ifelse(grepl("ctrl", filtered_data$sub), "ctrl", "mbs")
head(filtered_data)
# Convert columns to factors
filtered_data$mask <- as.factor(filtered_data$mask)
filtered_data$hemi <- as.factor(filtered_data$hemi)
filtered_data$group <- as.factor(filtered_data$group)
filtered_data$condition <- as.factor(filtered_data$condition)
filtered_data$sub <- as.factor(filtered_data$sub)
filtered_data$tot_vertex <- as.numeric(filtered_data$tot_vertex)
filtered_data$tval <- as.numeric(filtered_data$tval)
filtered_data$x <- as.numeric(filtered_data$x)
filtered_data$y <- as.numeric(filtered_data$y)
filtered_data$z <- as.numeric(filtered_data$z)
filtered_data$vertex <- as.numeric(filtered_data$vertex)


# T-TESTS between groups for each condition
# Initialize a list to store the t-test results
t_test_results <- list()

# Loop through each condition and perform the t-test
conditions <- c("Forehead", "Tongue", "Lips", "Hand", "Foot")
for (condition in conditions) {
  # Filter the data for the current condition
  condition_data <- filtered_data %>%
    filter(condition == !!condition)
  # Perform the t-test
  t_test_result <- t.test(
    tval ~ group,
    data = condition_data,
    var.equal = TRUE
  )
  # Store the result in the list
  t_test_results[[condition]] <- t_test_result
}

# Print the results
for (condition in conditions) {
  cat("\nT-test results for", condition, ":\n")
  print(t_test_results[[condition]])
}

# Let's do anova
library(broom)

# tvalue
anova_model <- aov(tval ~
                     condition * group * hemi, data = filtered_data)
qqnorm(anova_model$residuals)
qqline(anova_model$residuals)
shapiro.test(anova_model$residuals)
# shapiro test suggest residuals is not normal
if (!requireNamespace("car", quietly = TRUE)) {
  install.packages("car")
}
library(car)
leveneTest(tval ~ condition * group * hemi, data = filtered_data)
# significant results suggest variances are not equal

# tot_vertex
anova_model2 <- aov(tot_vertex ~
                      condition * group * hemi, data = filtered_data)
qqnorm(anova_model2$residuals)
qqline(anova_model2$residuals)
shapiro.test(anova_model2$residuals)
# not sig, so residuals are normal
leveneTest(tot_vertex ~ condition * group * hemi, data = filtered_data)
# is sig, so variances are not equal

# need to perform permutation anova on both tval and tot_vertex
library(permuco)
# tval
perm_model <- aovperm(
  tval ~ condition * group * hemi,
  data = filtered_data,
  np = 2000,
  block = filtered_data$sub
)
# tot_vertex
perm_model2 <- aovperm(
  tot_vertex ~ condition * group * hemi,
  data = filtered_data,
  np = 2000,
  block = filtered_data$sub
)
# summarize the results
results <- summary(perm_model)
print(results)
filename <- paste(
  path_results, "permutationAnovaTable_", task, "_tValue.csv", sep = ""
)
write.csv(results, filename)

# plot the interaction group x [condition in somatotopy]


# tot_vertex
results2 <- summary(perm_model2)
print(results2)
filename2 <- paste(
  path_results, "permutationAnovaTable_", task, "_totVertex.csv", sep = ""
)
write.csv(results2, filename2)



# Summarize the data to calculate mean, standard deviation, and standard error
df <- summarySE(
  data = filtered_data,
  groupvars = c("group", "hemi", "condition"),
  measurevar = "tot_vertex",
  na.rm = TRUE
)
df

df2 <- summarySE(
  data = filtered_data,
  groupvars = c("group", "hemi", "condition"),
  measurevar = "tval",
  na.rm = TRUE
)
df2




# now it's time to plot
custom_cond_order <- c(
  "Tongue", "Lips", "Forehead", "Hand", "Foot"
)
# Set the order for the summary and raw data
df2$condition <- factor(df2$condition, levels = custom_cond_order)
filtered_data$condition <-
  factor(filtered_data$condition, levels = custom_cond_order)

width_dist_btwn_groups <- 0.8

# Error bar colors
errorbar_colors <- c("ctrl" = "#606060ff", "mbs" = "#448c6dff")

# Barplot with error bars + dots as individual points - flipped
bar_p <- ggplot(df2, aes(x = condition, y = tval, fill = group)) +
  geom_bar(
    stat = "identity",
    position = position_dodge(width = width_dist_btwn_groups),
    width = 0.8 # try smaller values for more space
  ) +
  geom_errorbar(
    aes(ymin = tval - se, ymax = tval + se, color = group),
    width = 0.2,
    position = position_dodge(width = width_dist_btwn_groups),
    size = 1
  ) +
  # Add individual data points
  geom_jitter(
    data = filtered_data,
    aes(x = condition, y = tval, color = group, fill = group),
    position = position_jitterdodge(
      jitter.width = 0.2,
      dodge.width = width_dist_btwn_groups),
    shape = 21, size = 2, alpha = 0.8
  ) +
  facet_grid(hemi ~ .) +
  ylim(0, 31) +
  labs(
    x = "Body Parts",
    y = "Surface Peak Vertex\nt-value (a.u.)",
    fill = "Groups",
    color = "Groups"
  ) +
  theme_minimal() +
  theme(
    text = element_text(family = "Avenir", color = "black"),
    panel.spacing = unit(2, "lines"),
    axis.title.x = element_text(size = 24),
    axis.title.y = element_text(size = 24),
    axis.text.x = element_text(size = 22,
                               hjust = 0.5, color = "black"), # Center x labels
    axis.text.y = element_text(size = 22, color = "black"),
    legend.title = element_text(size = 24),
    legend.text = element_text(size = 22),
    strip.text = element_text(size = 24, hjust = 0.5),
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
  "Flipped_Vertical_TValueBARPlot_Averaged_Ordered", task, ".pdf", sep = ""
)
ggsave(filename, plot = bar_p, width = 6, height = 8, units = "in", dpi = 300)




# do the horizontal version of the bar plot - flipped
# Barplot with error bars + dots as individual points
bar_p <- ggplot(df2, aes(x = condition, y = tval, fill = group)) +
  geom_bar(
    stat = "identity",
    position = position_dodge(width = width_dist_btwn_groups),
    width = 0.8 # try smaller values for more space
  ) +
  geom_errorbar(
    aes(ymin = tval - se, ymax = tval + se, color = group),
    width = 0.2,
    position = position_dodge(width = width_dist_btwn_groups),
    size = 1
  ) +
  # Add individual data points
  geom_jitter(
    data = filtered_data,
    aes(x = condition, y = tval, color = group, fill = group),
    position = position_jitterdodge(
                                    jitter.width = 0.2,
                                    dodge.width = width_dist_btwn_groups),
    shape = 21, size = 2, alpha = 0.8
  ) +
  facet_wrap(hemi ~ ., strip.position = "top") +
  ylim(0, 31) +
  labs(
    x = "Body Parts",
    y = "Surface Peak Vertex t-value (a.u.)",
    fill = "Groups",
    color = "Groups"
  ) +
  theme_minimal() +
  theme(
    text = element_text(family = "Avenir", color = "black"),
    panel.spacing = unit(2, "lines"),
    axis.title.x = element_text(size = 24),
    axis.title.y = element_text(size = 24),
    axis.text.x = element_text(size = 22,
                               hjust = 0.5, color = "black"), # Center x labels
    axis.text.y = element_text(size = 22, color = "black"),
    legend.title = element_text(size = 24),
    legend.text = element_text(size = 22),
    strip.placement = "inside", # move facet labels inside
    strip.text = element_text(size = 24, hjust = 0.5,
                              margin = margin(b = 0, t = 1)),
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
  "Flipped_Horizontal_TValueBARPlot_Averaged_Ordered", task, ".pdf", sep = ""
)
ggsave(filename, plot = bar_p, width = 12, height = 4, units = "in", dpi = 300)




# let's do the same thing for the tot_vertex - flipped
# Set the order for the summary and raw data
df
df$condition <- factor(df$condition, levels = custom_cond_order)
filtered_data$condition <-
  factor(filtered_data$condition, levels = custom_cond_order)

width_dist_btwn_groups <- 0.8

# Error bar colors
errorbar_colors <- c("ctrl" = "#606060ff", "mbs" = "#448c6dff")

# Barplot with error bars + dots as individual points
bar_p <- ggplot(df, aes(x = condition, y = tot_vertex, fill = group)) +
  geom_bar(
    stat = "identity",
    position = position_dodge(width = width_dist_btwn_groups),
    width = 0.8 # try smaller values for more space
  ) +
  geom_errorbar(
    aes(ymin = tot_vertex - se, ymax = tot_vertex + se, color = group),
    width = 0.2,
    position = position_dodge(width = width_dist_btwn_groups),
    size = 1
  ) +
  # Add individual data points
  geom_jitter(
    data = filtered_data,
    aes(x = condition, y = tot_vertex, color = group, fill = group),
    position = position_jitterdodge(
      jitter.width = 0.2,
      dodge.width = width_dist_btwn_groups),
    shape = 21, size = 2, alpha = 0.8
  ) +
  facet_grid(hemi ~ .) +
  ylim(0, 1850) +
  labs(
    x = "Body Parts",
    y = "Number of Vertices (a.u.)",
    fill = "Groups",
    color = "Groups"
  ) +
  theme_minimal() +
  theme(
    text = element_text(family = "Avenir", color = "black"),
    panel.spacing = unit(2, "lines"),
    axis.title.x = element_text(size = 24),
    axis.title.y = element_text(size = 24),
    axis.text.x = element_text(size = 22,
                               hjust = 0.5, color = "black"), # Center x labels
    axis.text.y = element_text(size = 22, color = "black"),
    legend.title = element_text(size = 24),
    legend.text = element_text(size = 22),
    strip.text = element_text(size = 24, hjust = 0.5),
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
  "Flipped_Vertical_TotVertex_BARPlot_Averaged_Ordered", task, ".pdf", sep = ""
)
ggsave(filename, plot = bar_p, width = 6, height = 8, units = "in", dpi = 300)



# horizontal bar plot with total number of vertices - flipped
# Barplot with error bars + dots as individual points
bar_p <- ggplot(df, aes(x = condition, y = tot_vertex, fill = group)) +
  geom_bar(
    stat = "identity",
    position = position_dodge(width = width_dist_btwn_groups),
    width = 0.8 # try smaller values for more space
  ) +
  geom_errorbar(
    aes(ymin = tot_vertex - se, ymax = tot_vertex + se, color = group),
    width = 0.2,
    position = position_dodge(width = width_dist_btwn_groups),
    size = 1
  ) +
  # Add individual data points
  geom_jitter(
    data = filtered_data,
    aes(x = condition, y = tot_vertex, color = group, fill = group),
    position = position_jitterdodge(
      jitter.width = 0.2,
      dodge.width = width_dist_btwn_groups
    ),
    shape = 21, size = 2, alpha = 0.8
  ) +
  facet_wrap(hemi ~ .) +
  ylim(0, 1850) +
  labs(
    x = "Body Parts",
    y = "Number of Vertices (a.u.)",
    fill = "Groups",
    color = "Groups"
  ) +
  theme_minimal() +
  theme(
    text = element_text(family = "Avenir", color = "black"),
    panel.spacing = unit(2, "lines"),
    axis.title.x = element_text(size = 24),
    axis.title.y = element_text(size = 24),
    axis.text.x = element_text(size = 22,
                               hjust = 0.5, color = "black"), # Center x labels
    axis.text.y = element_text(size = 22, color = "black"),
    legend.title = element_text(size = 24),
    legend.text = element_text(size = 22),
    strip.text = element_text(size = 24, hjust = 0.5),
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
  "Flipped_Horizontal_TotVertexBARPlot_Averaged_Ordered", task, ".pdf", sep = ""
)
ggsave(filename, plot = bar_p, width = 12, height = 4, units = "in", dpi = 300)





