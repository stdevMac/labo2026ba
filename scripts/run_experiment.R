#!/usr/bin/env Rscript
bucket <- Sys.getenv("LABO_BUCKET")
repo <- Sys.getenv("LABO_REPO")
name <- Sys.getenv("NAME")
script <- Sys.getenv("SCRIPT")
if (!nzchar(bucket) || !nzchar(repo) || !nzchar(name) || !nzchar(script)) {
  stop("LABO_BUCKET, LABO_REPO, NAME y SCRIPT son obligatorios")
}
if (!script %in% c("z101", "z102")) {
  stop("SCRIPT debe ser z101 o z102, recibido: ", script)
}

out_dir <- file.path(bucket, "exp", name)
if (dir.exists(out_dir)) {
  stop("exp ya existe, no se pisa: ", out_dir)
}
dir.create(out_dir, recursive = TRUE)

cp <- Sys.getenv("CP")
minsplit <- Sys.getenv("MINSPLIT")
minbucket <- Sys.getenv("MINBUCKET")
maxdepth <- Sys.getenv("MAXDEPTH")
cutoff <- Sys.getenv("CUTOFF")
seed <- Sys.getenv("SEED")
ts <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")

params <- c(
  paste0("ts=", ts),
  paste0("name=", name),
  paste0("script=", script),
  paste0("cp=", cp),
  paste0("minsplit=", minsplit),
  paste0("minbucket=", minbucket),
  paste0("maxdepth=", maxdepth),
  paste0("cutoff=", cutoff),
  paste0("seed=", seed)
)
writeLines(params, file.path(out_dir, "params.txt"))

Sys.setenv(LABO_OUT_DIR = out_dir)
script_path <- if (script == "z101") {
  file.path(repo, "scripts", "z101_primer_modelo.R")
} else {
  file.path(repo, "scripts", "z102_final_train.R")
}
rc <- system2("Rscript", script_path)
if (rc != 0) {
  unlink(out_dir, recursive = TRUE)
  stop("el script de entrenamiento fallo")
}

n_ones_file <- file.path(out_dir, "n_ones.txt")
n_ones <- if (file.exists(n_ones_file)) readLines(n_ones_file, warn = FALSE)[[1]] else ""

header <- "ts,name,script,cp,minsplit,minbucket,maxdepth,cutoff,n_ones,kaggle_score"
line <- paste(ts, name, script, cp, minsplit, minbucket, maxdepth, cutoff, n_ones, "", sep = ",")

append_run <- function(path) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  if (!file.exists(path)) {
    writeLines(header, path)
  }
  cat(line, "\n", file = path, append = TRUE, sep = "")
}

append_run(file.path(bucket, "exp", "runs.csv"))
append_run(file.path(repo, "exp", "runs.csv"))
