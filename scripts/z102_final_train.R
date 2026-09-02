#!/usr/bin/env Rscript
stopifnot(nzchar(Sys.getenv("LABO_BUCKET")))
stopifnot(nzchar(Sys.getenv("LABO_OUT_DIR")))

bucket <- Sys.getenv("LABO_BUCKET")
out_dir <- Sys.getenv("LABO_OUT_DIR")
dataset_path <- file.path(bucket, "datasets", "dataset_pequeno.csv")
if (!file.exists(dataset_path)) {
  stop("dataset no encontrado: ", dataset_path)
}

cp <- as.numeric(Sys.getenv("CP", unset = "-1"))
minsplit <- as.numeric(Sys.getenv("MINSPLIT", unset = "250"))
minbucket <- as.numeric(Sys.getenv("MINBUCKET", unset = "100"))
maxdepth <- as.numeric(Sys.getenv("MAXDEPTH", unset = "3"))
cutoff <- as.numeric(Sys.getenv("CUTOFF", unset = "0.025"))
seed <- Sys.getenv("SEED", unset = "")
if (nzchar(seed)) set.seed(as.integer(seed))

suppressPackageStartupMessages({
  library("data.table")
  library("rpart")
})

dataset <- fread(dataset_path)
dtrain_final <- dataset[foto_mes == 202107]
dfuture <- dataset[foto_mes == 202109]

param_final <- list(
  cp = cp,
  minsplit = minsplit,
  minbucket = minbucket,
  maxdepth = maxdepth
)

modelo_final <- rpart(
  formula = "clase_ternaria ~ .",
  data = dtrain_final,
  xval = 0,
  control = param_final
)

prediccion <- predict(modelo_final, newdata = dfuture, type = "prob")
tb_prediccion <- as.data.table(list(
  numero_de_cliente = dfuture$numero_de_cliente,
  prob = prediccion[, "BAJA+2"]
))
tb_prediccion[, Predicted := as.numeric(prob > cutoff)]

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
fwrite(
  tb_prediccion[, list(numero_de_cliente, Predicted)],
  file = file.path(out_dir, "submission.csv"),
  sep = ","
)
n_ones <- tb_prediccion[, sum(Predicted == 1)]
writeLines(as.character(n_ones), file.path(out_dir, "n_ones.txt"))
cat(n_ones, "\n")
