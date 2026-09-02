#!/usr/bin/env Rscript
bucket <- Sys.getenv("LABO_BUCKET")
repo <- Sys.getenv("LABO_REPO")
name <- Sys.getenv("NAME")
if (!nzchar(bucket) || !nzchar(repo) || !nzchar(name)) {
  stop("LABO_BUCKET, LABO_REPO y NAME son obligatorios")
}
csv <- file.path(bucket, "exp", name, "submission.csv")
if (!file.exists(csv)) stop("no hay submission: ", csv)

src_json <- file.path(bucket, "kaggle", "kaggle.json")
if (!file.exists(src_json)) stop("falta ", src_json)
dir.create(path.expand("~/.kaggle"), showWarnings = FALSE)
dst_json <- path.expand("~/.kaggle/kaggle.json")
if (!file.exists(dst_json)) {
  file.copy(src_json, dst_json, overwrite = FALSE)
}
Sys.chmod(dst_json, mode = "0600")

msg <- paste0("labo ", name)
out <- system2(
  "kaggle",
  c("competitions", "submit", "-c", "labo-1-ba-inicial", "-f", csv, "-m", msg),
  stdout = TRUE,
  stderr = TRUE
)
status <- attr(out, "status")
if (is.null(status)) status <- 0
writeLines(out, file.path(bucket, "exp", name, "kaggle_submit.log"))
if (status != 0) {
  stop("kaggle submit fallo:\n", paste(out, collapse = "\n"))
}

score <- ""
joined <- paste(out, collapse = " ")
m <- regmatches(joined, regexpr("[0-9]+(\\.[0-9]+)?", joined))
if (length(m) == 1) score <- m

patch_runs <- function(path) {
  if (!file.exists(path)) return(invisible())
  rows <- readLines(path)
  if (length(rows) < 2) return(invisible())
  header <- rows[[1]]
  body <- rows[-1]
  cols <- strsplit(header, ",", fixed = TRUE)[[1]]
  score_i <- match("kaggle_score", cols)
  name_i <- match("name", cols)
  if (is.na(score_i) || is.na(name_i)) return(invisible())
  for (i in seq_along(body)) {
    parts <- strsplit(body[[i]], ",", fixed = TRUE)[[1]]
    if (length(parts) >= name_i && parts[[name_i]] == name) {
      while (length(parts) < length(cols)) parts <- c(parts, "")
      parts[[score_i]] <- if (nzchar(score)) score else "submitted"
      body[[i]] <- paste(parts, collapse = ",")
    }
  }
  writeLines(c(header, body), path)
}

patch_runs(file.path(bucket, "exp", "runs.csv"))
patch_runs(file.path(repo, "exp", "runs.csv"))
cat(paste(out, collapse = "\n"), "\n")
