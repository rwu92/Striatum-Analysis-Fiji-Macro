library(tidyverse)
library(ggpubr)

#===================================================================================
# SETTINGS -- edit these if your setup changes
#===================================================================================

base_dir  <- "C:/Users/SteeleLab/Desktop/Renqi Master Folder/TH Striatum Project/Striatum Analysis & Quantification"
csv_dir   <- file.path(base_dir, "CSVfiles")   # where the Fiji macro saved arrow + Noise CSVs
stats_dir <- file.path(base_dir, "Stats")      # created automatically, no need to make it yourself
plots_dir <- file.path(base_dir, "Plots")      # created automatically, no need to make it yourself

dir.create(stats_dir, showWarnings = FALSE)
dir.create(plots_dir, showWarnings = FALSE)

number_of_box <- 30   # number of bins each arrow profile is averaged down to

#===================================================================================
# STEP 1: Read every arrow-profile CSV, denoise it, and bin it into number_of_box averages
#===================================================================================

all_files     <- list.files(csv_dir, pattern = "\\.csv$", full.names = FALSE)
noise_files   <- all_files[grepl("^Noise_", all_files)]
profile_files <- all_files[!grepl("^Noise_", all_files)]

read_and_bin_one_file <- function(fname) {

  spectra <- read.csv(file.path(csv_dir, fname))

  # Find the matching Noise CSV: strip the axis prefix, then look for "Noise_<rest>"
  base_name   <- sub("^(DV_|ML_|MV-DL_)", "", fname)
  noise_name  <- paste0("Noise_", base_name)
  noise_data  <- read.csv(file.path(csv_dir, noise_name))

  # Denoise: subtract mean background, floor negatives at 0
  if (!"Mean" %in% names(noise_data)) {
    warning(paste0("Noise file has no 'Mean' column, treating background as 0: ", noise_name))
    noise_mean <- 0
  } else {
    noise_mean <- mean(noise_data$Mean)
  }
  denoised <- spectra$Value - noise_mean
  denoised[denoised < 0] <- 0

  # Crop to a length that divides evenly into number_of_box bins, then bin-average
  n_keep <- floor(length(denoised) / number_of_box) * number_of_box
  denoised <- denoised[1:n_keep]
  pixels_per_box <- n_keep / number_of_box

  box_avg <- sapply(1:number_of_box, function(b) {
    idx <- ((b - 1) * pixels_per_box + 1):(b * pixels_per_box)
    mean(denoised[idx])
  })

  #-------------------------------------------------------------------------------
  # Parse metadata straight out of the filename (adjust these regexes if your
  # naming convention changes)
  #-------------------------------------------------------------------------------

  Axis <- sub("_.*", "", fname)   # "DV", "ML", or "MV-DL"

  # Only look for the gene name in the part of the filename BEFORE "-cre" --
  # this avoids "DAT" (the antibody/channel label that appears later in every
  # filename, e.g. "TH DAT DAPI") being mistaken for the Dat gene line.
  line_prefix <- sub("-cre.*", "", fname, ignore.case = TRUE)

  # "[1l]" tolerates a "1" (digit one) being mistyped as "l" (lowercase L),
  # e.g. "Crhrl-cre" instead of "Crhr1-cre" -- an easy typo since they look
  # nearly identical in many fonts.
  Line <- case_when(
    grepl("calb[1l]", line_prefix, ignore.case = TRUE) ~ "Calb1",
    grepl("crhr[1l]", line_prefix, ignore.case = TRUE) ~ "Crhr1",
    grepl("dat",      line_prefix, ignore.case = TRUE) ~ "Dat",
    grepl("ntsr[1l]", line_prefix, ignore.case = TRUE) ~ "Ntsr1",
    TRUE ~ NA_character_
  )

  # Control filenames mark genotype as "cre-" (e.g. "cre- f.wt") or with
  # spaces/parentheses as "cre (-)" -- this pattern catches both.
  # "wt" (wild-type) tissues are also treated as Control.
  # cKO is inferred as the default for any other Cre-positive file (i.e. "-cre" present)
  # that ISN'T explicitly marked Cre-negative or wt -- this also catches files that
  # never spell out "cKO" in the filename itself (e.g. it's only in the folder name).
  Group <- case_when(
    grepl("cre *\\(?-", fname, ignore.case = TRUE) ~ "Control",
    grepl("\\bwt\\b", fname, ignore.case = TRUE)    ~ "Control",
    grepl("cKO", fname, ignore.case = TRUE)         ~ "cKO",
    grepl("-cre", fname, ignore.case = TRUE)        ~ "cKO",
    TRUE ~ NA_character_
  )

  # Matches "FloxTH 893" as well as the looser "flox 919" variant
  MouseID <- sub(".*flox(th)?\\s+(\\d+).*", "\\2", fname, ignore.case = TRUE)

  # Newer files label the staining round directly, e.g. "(s.1.t.1)" or
  # "(s.2.t.1)" -- but "s.N" represents a round ADDITIONAL to whichever old
  # rounds already exist for THIS gene line (some lines only reached t.1-6 =
  # 1 old round, others reached t.1-12 = 2 old rounds). The actual offset per
  # line gets resolved after all files are read, below -- here we just record
  # the raw pieces (which old round, if any; which set number, if any).
  has_set_label <- grepl("\\(s\\.\\d+\\.t\\.\\d+", fname, ignore.case = TRUE)

  if (has_set_label) {
    SetNumber <- as.numeric(sub(".*\\(s\\.(\\d+)\\.t\\.\\d+.*", "\\1", fname, ignore.case = TRUE))
    Tissue    <- as.numeric(sub(".*\\(s\\.\\d+\\.t\\.(\\d+)[^)]*\\).*", "\\1", fname, ignore.case = TRUE))
    OldRound  <- NA_real_
  } else {
    # "[^)]*" tolerates extra text inside the parentheses after the tissue number,
    # e.g. "(t.3 left half)" or "(t.3 right half)", not just plain "(t.3)"
    Tissue    <- suppressWarnings(as.numeric(sub(".*\\(t\\.(\\d+)[^)]*\\).*", "\\1", fname)))
    OldRound  <- ifelse(Tissue <= 6, 1, 2)
    SetNumber <- NA_real_
  }

  tibble(
    Filename  = fname,
    Line      = Line,
    Group     = Group,
    MouseID   = MouseID,
    OldRound  = OldRound,
    SetNumber = SetNumber,
    Axis      = Axis,
    Box       = 1:number_of_box,
    Value     = box_avg
  )
}

df <- map_dfr(profile_files, read_and_bin_one_file)

# Resolve the true Round per Line: find how many old-style rounds THIS line
# actually has (1 or 2, or 0 if it has none), then s.N = that many + N.
line_old_round_max <- df %>%
  filter(!is.na(OldRound)) %>%
  group_by(Line) %>%
  summarize(MaxOldRound = max(OldRound), .groups = "drop")

df <- df %>%
  left_join(line_old_round_max, by = "Line") %>%
  mutate(MaxOldRound = replace_na(MaxOldRound, 0)) %>%
  mutate(Round = case_when(
    !is.na(SetNumber) ~ paste0("Round", MaxOldRound + SetNumber),
    !is.na(OldRound)  ~ paste0("Round", OldRound),
    TRUE ~ NA_character_
  )) %>%
  select(-OldRound, -SetNumber, -MaxOldRound)

# Sanity check -- make sure nothing failed to parse. If any of these print rows,
# go check that file's name against the parsing rules above.
problems <- df %>% filter(is.na(Line) | is.na(Group) | is.na(MouseID) | is.na(Round))
if (nrow(problems) > 0) {
  warning("Some files did not parse correctly and will be EXCLUDED from analysis -- check these filenames:")
  print(unique(problems$Filename))
}

# Actually drop the unparseable rows -- warning about them isn't enough, since
# an NA Line/Group/Round left in the data will crash later steps (color lookups,
# grouping, stats) instead of just being silently wrong. Better to exclude them
# loudly here and keep going with everything that DID parse correctly.
df <- df %>% filter(!is.na(Line), !is.na(Group), !is.na(MouseID), !is.na(Round))


#===================================================================================
# STEP 2: Normalize each curve to its own Line+Round's control-group maximum
#===================================================================================
# This keeps the 2 staining rounds comparable within a line (each round is
# normalized against its OWN round's controls), while still making the
# normalized numbers meaningful for cross-line comparison (all expressed as
# "% of that line's own control maximum").

control_curve <- df %>%
  filter(Group == "Control") %>%
  group_by(Line, Round, Axis, Box) %>%
  summarize(CtrlMean = mean(Value), .groups = "drop")

control_max <- control_curve %>%
  group_by(Line, Round, Axis) %>%
  summarize(CtrlMax = max(CtrlMean), .groups = "drop")

df <- df %>%
  left_join(control_max, by = c("Line", "Round", "Axis")) %>%
  mutate(Normalized = Value / CtrlMax)

#===================================================================================
# STEP 3: Group-average curves + 95% CI, for plotting
# (averaged across both rounds, since normalization already accounts for round)
#===================================================================================

ci95 <- function(x) {
  x <- x[!is.na(x)]
  n <- length(x)
  se <- sd(x) / sqrt(n)
  se * qt(0.975, df = n - 1)
}

summary_within_line_cko <- df %>%
  filter(Group == "cKO") %>%
  group_by(Line, Axis, Box) %>%
  summarize(
    Mean = mean(Normalized, na.rm = TRUE),
    CI   = ci95(Normalized),
    .groups = "drop"
  )

summary_cross_line_cko <- df %>%
  filter(Group == "cKO") %>%
  group_by(Line, Axis, Box) %>%
  summarize(
    Mean = mean(Normalized, na.rm = TRUE),
    CI   = ci95(Normalized),
    .groups = "drop"
  )

# Pooled Control curve -- combines control animals from ALL 4 lines into one
# single reference curve. Used in every individual within-line plot (not the
# cross-line plot, which shows cKO-only comparison across genes).
summary_pooled_control <- df %>%
  filter(Group == "Control") %>%
  group_by(Axis, Box) %>%
  summarize(
    Mean = mean(Normalized, na.rm = TRUE),
    CI   = ci95(Normalized),
    .groups = "drop"
  )

summary_cross_line <- summary_cross_line_cko

#===================================================================================
# STEP 4: Plots
#===================================================================================

# Shared color per gene line -- used in BOTH the within-line plots (as the cKO
# curve's color) and the cross-line plot, so each line's color stays consistent
# across every figure.
line_colors <- c(
  "Calb1"   = "#E75480",  # pink
  "Crhr1"   = "#2E8B57",  # green
  "Dat"     = "#1F77B4",  # blue
  "Ntsr1"   = "#FF8C00",  # orange
  "Control" = "grey40"    # pooled control reference curve
)

# --- Within-line: cKO vs Control, one plot per Line x Axis ---
plot_within_line <- function(line, axis) {
  cko_data <- summary_within_line_cko %>% filter(Line == line, Axis == axis) %>% mutate(Group = "cKO")
  control_data <- summary_pooled_control %>% filter(Axis == axis) %>% mutate(Group = "Control")

  data <- bind_rows(cko_data, control_data)

  group_colors <- c("Control" = line_colors[["Control"]], "cKO" = line_colors[[line]])

  ggplot(data, aes(x = Box, y = Mean, color = Group, fill = Group)) +
    geom_ribbon(aes(ymin = Mean - CI, ymax = Mean + CI), alpha = 0.2, color = NA) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = group_colors) +
    scale_fill_manual(values = group_colors) +
    scale_y_continuous(breaks = c(0, 0.5, 1.0, 1.5)) +
    coord_cartesian(ylim = c(0, 1.5)) +
    labs(x = NULL, y = "Normalized Fluorescence") +
    theme_classic() +
    theme(legend.position = "none") +
    theme(
      axis.title.y = element_text(face = "bold", size = 17),
      axis.text.y  = element_text(size = 13),
      axis.text.x  = element_blank(),
      axis.ticks.x = element_blank()
    )
}

for (line in unique(df$Line)) {
  for (axis in unique(df$Axis)) {
    p <- plot_within_line(line, axis)
    ggsave(filename = file.path(plots_dir, paste0("WithinLine_", line, "_", axis, ".png")),
           plot = p, width = 6, height = 4, dpi = 300)
  }
}

# --- Cross-line: all 4 lines' cKO curves overlaid, one plot per Axis ---
plot_cross_line <- function(axis) {
  data <- summary_cross_line %>% filter(Axis == axis)

  ggplot(data, aes(x = Box, y = Mean, color = Line, fill = Line)) +
    geom_ribbon(aes(ymin = Mean - CI, ymax = Mean + CI), alpha = 0.15, color = NA) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = line_colors) +
    scale_fill_manual(values = line_colors) +
    scale_y_continuous(breaks = c(0, 0.5, 1.0, 1.5)) +
    coord_cartesian(ylim = c(0, 1.5)) +
    labs(x = NULL, y = "Normalized Fluorescence") +
    theme_classic() +
    theme(legend.position = "none") +
    theme(
      axis.title.y = element_text(face = "bold", size = 17),
      axis.text.y  = element_text(size = 13),
      axis.text.x  = element_blank(),
      axis.ticks.x = element_blank()
    )
}

for (axis in unique(df$Axis)) {
  p <- plot_cross_line(axis)
  ggsave(filename = file.path(plots_dir, paste0("CrossLine_cKO_", axis, ".png")),
         plot = p, width = 6, height = 4, dpi = 300)
}

#===================================================================================
# STEP 5: Statistics -- two-way ANOVA + Tukey HSD, testing group differences at
# each bin position separately (this matches "is there a difference at THIS
# specific point along the arrow" rather than a single overall comparison)
#===================================================================================

# Keeps only the contrasts that compare the SAME bin across two levels of the
# factor of interest (e.g. "cKO:12-Control:12", not "cKO:12-Control:5")
extract_same_bin_contrasts <- function(tukey_table, factor_name) {
  keep <- sapply(rownames(tukey_table), function(rn) {
    parts <- strsplit(rn, ":")[[1]]
    if (length(parts) < 3) return(FALSE)
    first  <- strsplit(parts[2], "-")[[1]][1]
    last   <- parts[length(parts)]
    first == last
  })
  as.data.frame(tukey_table[keep, , drop = FALSE])
}

# --- Within-line stats: cKO vs Control at each bin, separately per Line x Axis ---
for (line in unique(df$Line)) {
  for (axis in unique(df$Axis)) {

    data <- df %>% filter(Line == line, Axis == axis) %>%
      mutate(Group = as.factor(Group), Box = as.factor(Box))

    if (n_distinct(data$Group) < 2) next  # skip if only one group present

    model <- aov(Normalized ~ Group * Box, data = data)
    tukey <- TukeyHSD(model)$`Group:Box`
    result <- extract_same_bin_contrasts(tukey, "Group")

    write.csv(result, file.path(stats_dir, paste0("Tukey_WithinLine_", line, "_", axis, ".csv")))
  }
}

# --- Cross-line stats: comparing the 4 lines' cKO severity at each bin, per Axis ---
for (axis in unique(df$Axis)) {

  data <- df %>% filter(Group == "cKO", Axis == axis) %>%
    mutate(Line = as.factor(Line), Box = as.factor(Box))

  if (n_distinct(data$Line) < 2) next  # skip if fewer than 2 lines present for this axis

  model <- aov(Normalized ~ Line * Box, data = data)
  tukey <- TukeyHSD(model)$`Line:Box`
  result <- extract_same_bin_contrasts(tukey, "Line")

  write.csv(result, file.path(stats_dir, paste0("Tukey_CrossLine_cKO_", axis, ".csv")))
}

#===================================================================================
# Done. Outputs:
#   Plots/  -> WithinLine_<Line>_<Axis>.png   (cKO vs Control per gene)
#             CrossLine_cKO_<Axis>.png        (all 4 genes' cKO curves overlaid)
#   Stats/  -> Tukey_WithinLine_<Line>_<Axis>.csv
#             Tukey_CrossLine_cKO_<Axis>.csv
#===================================================================================
