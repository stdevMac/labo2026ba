# Local overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On this Mac, `make setup && make data && make z102` writes a Kaggle CSV to Google Drive `labo1`, and `make colab-z102` copies the notebook there and opens Brave — same `datasets/` and `exp/` as Colab.

**Architecture:** Git repo stays in `laboratorio/labo2026ba`. Drive folder `labo1` is the bucket (`LABO_BUCKET`). Makefile loads `.env` via `scripts/resolve_bucket.sh`. Independent R scripts under `scripts/` (they do not `source` the notebooks). Notebooks get one env cell plus `BUCKET`/`DATASET` path swaps. Bitácora: `$LABO_BUCKET/exp/<NAME>/` plus a git-tracked `exp/runs.csv`.

**Tech Stack:** Make, bash, Rscript, `renv` (`data.table`, `rpart`, `rpart.plot`, `ggplot2`, `caret`), Google Drive for Desktop, Brave, Kaggle CLI.

**Spec:** `docs/superpowers/specs/2026-09-02-local-overhaul-design.md`

**Depends on:** `docs/superpowers/plans/2026-09-02-catedra-fixes.md` already merged into local `main`. Do **not** put this work on `fix/catedra-bugs` or in the labo-imp PR.

**Comments:** none unless the code cannot be understood without them.

---

### File map

| File | Responsibility |
|---|---|
| `.gitignore` | stop ignoring markdown; ignore bucket junk, `.env`, `exp/*/` |
| `.env.example` | `LABO_BUCKET` and `LABO_COLAB_FOLDER_URL` |
| `scripts/resolve_bucket.sh` | print bucket path from `.env` or Drive autodetect |
| `scripts/z101_primer_modelo.R` | train z101 recipe, write `submission.csv` |
| `scripts/z102_final_train.R` | train z102 recipe, write `submission.csv` |
| `scripts/run_experiment.R` | create `exp/<NAME>/`, refuse overwrite, append `runs.csv` |
| `scripts/submit.R` | kaggle submit, fill `kaggle_score` |
| `Makefile` | setup, data, doctor, z101, z102, run, submit, colab-*, lab |
| `renv.lock` + `renv/` | package pin |
| `exp/runs.csv` | tracked bitácora |
| `arboles/z102_FinalTrain.ipynb` | env cell + path vars (overhaul only) |
| `zero2hero/zero2hero_01.ipynb` | env cell + path vars |
| `README.md` | how to run |
| `tests/test_overhaul.sh` | abort-if-exists + fake-data z101 |

Scripts do **not** share an `R/` library. Env vars: `LABO_BUCKET`, `LABO_REPO`, `NAME`, `SCRIPT`, `CP`, `MINSPLIT`, `MINBUCKET`, `MAXDEPTH`, `CUTOFF`, `SEED`.

---

### Task 1: Start from main with cátedra fixes

**Files:** none

- [ ] **Step 1: Confirm prerequisite**

```bash
git checkout main
git log --oneline -8
git diff --name-only origin/main
```

Expected: `fix/catedra-bugs` is merged (notebooks changed vs `origin/main`). Specs may already be on `main`. If the notebook fixes are missing, stop and finish `docs/superpowers/plans/2026-09-02-catedra-fixes.md` first.

- [ ] **Step 2: Work on main**

Stay on `main`. Do not commit overhaul files onto `fix/catedra-bugs`.

---

### Task 2: gitignore and .env.example

**Files:**
- Modify: `.gitignore`
- Create: `.env.example`
- Test: `tests/test_overhaul.sh` (created in Task 7; here a one-shot check)

- [ ] **Step 1: Write the failing check**

```bash
git check-ignore -v README.md docs/superpowers/specs/2026-09-02-local-overhaul-design.md || true
```

Expected today: `docs/...` is ignored by `*.md`. After this task it must not be.

- [ ] **Step 2: Replace `.gitignore` with this exact file**

```
# data
*.csv
*.csv.gz
!exp/runs.csv
datasets/

# experiments on the bucket are not this rule; local copies:
exp/*/

# secrets
.env
**/kaggle.json

# R
.Rhistory
.RData
.Rproj.user
renv/library/
renv/staging/
.Rprofile

# notebooks / OS
.ipynb_checkpoints/
.DS_Store
Thumbs.db
*_files/
*copia.ipynb

# python
__pycache__/
*.pyc
```

- [ ] **Step 3: Create `.env.example`**

```
LABO_BUCKET=/Users/YOU/Library/CloudStorage/GoogleDrive-YOU/My Drive/labo1
LABO_COLAB_FOLDER_URL=
```

- [ ] **Step 4: Run the ignore check**

```bash
git check-ignore -v README.md && echo FAIL || echo readme_ok
git check-ignore -v docs/superpowers/specs/2026-09-02-local-overhaul-design.md && echo FAIL || echo specs_ok
git check-ignore -v .env ; echo "env_ignored:$?"
```

Expected: `readme_ok`, `specs_ok`, `.env` is ignored (exit 0 from `git check-ignore`).

- [ ] **Step 5: Commit**

```bash
git add .gitignore .env.example
git add -f docs/superpowers/specs/*.md docs/superpowers/plans/*.md 2>/dev/null || true
git commit -m "chore: gitignore for local labo workflow"
```

(`git add -f` on docs only if they were untracked; they should already be tracked.)

---

### Task 3: resolve_bucket.sh

**Files:**
- Create: `scripts/resolve_bucket.sh`

- [ ] **Step 1: Write the failing test command**

```bash
scripts/resolve_bucket.sh ; echo "exit:$?"
```

Expected: FAIL with `No such file or directory`.

- [ ] **Step 2: Create `scripts/resolve_bucket.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
if [[ -n "${LABO_BUCKET:-}" ]]; then
  printf '%s\n' "$LABO_BUCKET"
  exit 0
fi
found="$(find "$HOME/Library/CloudStorage" -maxdepth 5 -type d -name labo1 2>/dev/null | head -n 1 || true)"
if [[ -n "$found" ]]; then
  printf '%s\n' "$found"
  exit 0
fi
echo "LABO_BUCKET no esta seteado. Crea labo1 en Google Drive y pega el path en .env (ver .env.example)." >&2
exit 1
```

```bash
chmod +x scripts/resolve_bucket.sh
```

- [ ] **Step 3: Test with an explicit env var**

```bash
LABO_BUCKET="/tmp/labo1-test" scripts/resolve_bucket.sh
```

Expected: prints `/tmp/labo1-test`.

- [ ] **Step 4: Test missing bucket (no .env, override empty)**

```bash
env -u LABO_BUCKET HOME=/tmp/empty-home-$$ scripts/resolve_bucket.sh ; echo "exit:$?"
```

Expected: stderr message, exit 1.

- [ ] **Step 5: Commit**

```bash
git add scripts/resolve_bucket.sh
git commit -m "feat: resolve LABO_BUCKET from .env or Drive"
```

---

### Task 4: z101 and z102 scripts

**Files:**
- Create: `scripts/z101_primer_modelo.R`
- Create: `scripts/z102_final_train.R`

These scripts read env vars, never `setwd` to Colab paths, write `submission.csv` into `LABO_OUT_DIR`.

- [ ] **Step 1: Write `scripts/z101_primer_modelo.R`**

```r
#!/usr/bin/env Rscript
stopifnot(nzchar(Sys.getenv("LABO_BUCKET")))
stopifnot(nzchar(Sys.getenv("LABO_OUT_DIR")))

bucket <- Sys.getenv("LABO_BUCKET")
out_dir <- Sys.getenv("LABO_OUT_DIR")
dataset_path <- file.path(bucket, "datasets", "dataset_pequeno.csv")
if (!file.exists(dataset_path)) {
  stop("dataset no encontrado: ", dataset_path)
}

cp <- as.numeric(Sys.getenv("CP", unset = "-0.3"))
minsplit <- as.numeric(Sys.getenv("MINSPLIT", unset = "0"))
minbucket <- as.numeric(Sys.getenv("MINBUCKET", unset = "1"))
maxdepth <- as.numeric(Sys.getenv("MAXDEPTH", unset = "3"))
cutoff <- as.numeric(Sys.getenv("CUTOFF", unset = "0.025"))
seed <- Sys.getenv("SEED", unset = "")
if (nzchar(seed)) set.seed(as.integer(seed))

suppressPackageStartupMessages({
  library("data.table")
  library("rpart")
})

dataset <- fread(dataset_path)
dtrain <- dataset[foto_mes == 202107]
dapply <- dataset[foto_mes == 202109]

modelo_final <- rpart(
  formula = "clase_ternaria ~ .",
  data = dtrain,
  xval = 0,
  cp = cp,
  minsplit = minsplit,
  minbucket = minbucket,
  maxdepth = maxdepth
)

prediccion <- predict(modelo_final, newdata = dapply, type = "prob")
tb_prediccion <- as.data.table(list(
  numero_de_cliente = dapply$numero_de_cliente,
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
```

- [ ] **Step 2: Write `scripts/z102_final_train.R`**

```r
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
```

- [ ] **Step 3: Failing run without env**

```bash
Rscript scripts/z101_primer_modelo.R ; echo "exit:$?"
```

Expected: FAIL (`LABO_BUCKET` empty / `stopifnot`).

- [ ] **Step 4: Commit**

```bash
git add scripts/z101_primer_modelo.R scripts/z102_final_train.R
git commit -m "feat: local z101 and z102 training scripts"
```

---

### Task 5: run_experiment.R

**Files:**
- Create: `scripts/run_experiment.R`

- [ ] **Step 1: Write `scripts/run_experiment.R`**

```r
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
```

If training fails, the dir is removed so a retry with the same `NAME` works.

- [ ] **Step 2: Abort-if-exists test (no dataset needed)**

```bash
tmp=$(mktemp -d)
mkdir -p "$tmp/exp/dup"
export LABO_BUCKET="$tmp" LABO_REPO="$(pwd)" NAME=dup SCRIPT=z101
Rscript scripts/run_experiment.R ; echo "exit:$?"
```

Expected: exit non-zero, message `exp ya existe, no se pisa`.

- [ ] **Step 3: Commit**

```bash
git add scripts/run_experiment.R
git commit -m "feat: experiment runner that refuses to overwrite"
```

---

### Task 6: submit.R

**Files:**
- Create: `scripts/submit.R`

- [ ] **Step 1: Write `scripts/submit.R`**

```r
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
```

- [ ] **Step 2: Failing run without NAME**

```bash
Rscript scripts/submit.R ; echo "exit:$?"
```

Expected: FAIL, missing env.

- [ ] **Step 3: Commit**

```bash
git add scripts/submit.R
git commit -m "feat: kaggle submit updates runs.csv"
```

---

### Task 7: tests/test_overhaul.sh

**Files:**
- Create: `tests/test_overhaul.sh`
- Create: `exp/runs.csv` (header only)

- [ ] **Step 1: Write the test (fails until Makefile exists; still runnable against the scripts)**

Create `tests/test_overhaul.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/datasets" "$tmp/exp"
python3 - "$tmp/datasets/dataset_pequeno.csv" <<'PY'
import csv, sys
path = sys.argv[1]
rows = []
for i in range(1, 81):
    clase = "BAJA+2" if i % 20 == 0 else "CONTINUA"
    rows.append({"numero_de_cliente": i, "foto_mes": 202107, "ctrx_quarter": i % 40, "clase_ternaria": clase})
for i in range(1, 81):
    rows.append({"numero_de_cliente": 1000 + i, "foto_mes": 202109, "ctrx_quarter": i % 40, "clase_ternaria": ""})
with open(path, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["numero_de_cliente", "foto_mes", "ctrx_quarter", "clase_ternaria"])
    w.writeheader()
    w.writerows(rows)
PY

export LABO_BUCKET="$tmp"
export LABO_REPO="$ROOT"
export NAME=test_dry
export SCRIPT=z101
export CP=-0.3
export MINSPLIT=0
export MINBUCKET=1
export MAXDEPTH=3
export CUTOFF=0.025
export SEED=102191

Rscript "$ROOT/scripts/run_experiment.R"
test -f "$tmp/exp/test_dry/submission.csv"
test -f "$tmp/exp/test_dry/params.txt"
grep -q 'test_dry' "$tmp/exp/runs.csv"
grep -q 'test_dry' "$ROOT/exp/runs.csv"

if Rscript "$ROOT/scripts/run_experiment.R"; then
  echo "expected second run to fail"
  exit 1
fi

echo "test_overhaul ok"
```

```bash
chmod +x tests/test_overhaul.sh
```

Create `exp/runs.csv`:

```
ts,name,script,cp,minsplit,minbucket,maxdepth,cutoff,n_ones,kaggle_score
```

- [ ] **Step 2: Run it**

```bash
tests/test_overhaul.sh
```

Expected: PASS if `data.table` and `rpart` are installed in the current R. If R packages are missing, this waits for Task 8 (`make setup`). If it fails only on packages, continue to Task 8 and re-run.

- [ ] **Step 3: Commit the test and header**

```bash
git add tests/test_overhaul.sh exp/runs.csv
git commit -m "test: fake-data z101 run and overwrite guard"
```

---

### Task 8: renv, load_env.sh, Makefile

**Files:**
- Create: `scripts/load_env.sh`
- Create: `Makefile`
- Create: `renv.lock` via renv (generated)
- Keep `.Rprofile` if `renv::init` writes one

Do **not** `include .env` from Make (`My Drive` has spaces). Recipes `source scripts/load_env.sh` under `.ONESHELL`.

- [ ] **Step 1: Init renv and snapshot**

```bash
Rscript -e 'if (!requireNamespace("renv", quietly=TRUE)) install.packages("renv", repos="https://cloud.r-project.org")'
Rscript -e 'renv::init(bare = TRUE, restart = FALSE)'
Rscript -e 'renv::install(c("data.table", "rpart", "rpart.plot", "ggplot2", "caret"))'
Rscript -e 'renv::snapshot()'
```

Expected: `renv.lock` lists those packages.

- [ ] **Step 2: Write `scripts/load_env.sh`**

```bash
#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
if [[ -z "${LABO_BUCKET:-}" ]]; then
  LABO_BUCKET="$("$ROOT/scripts/resolve_bucket.sh")"
  export LABO_BUCKET
fi
export LABO_REPO="$ROOT"
```

```bash
chmod +x scripts/load_env.sh
```

- [ ] **Step 3: Write `Makefile`** (this is the only Makefile; do not write a second draft)

```makefile
SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -euo pipefail -c
REPO := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
DATA_URL := https://storage.googleapis.com/open-courses/austral2026-5da5/labo1/dataset_pequeno.csv

.PHONY: setup data doctor z101 z102 run submit colab-z102 colab-zero2hero colab-pull lab test

setup:
	Rscript -e 'if (!requireNamespace("renv", quietly=TRUE)) install.packages("renv", repos="https://cloud.r-project.org")'
	Rscript -e 'renv::restore()'

data:
	source "$(REPO)/scripts/load_env.sh"
	mkdir -p "$$LABO_BUCKET/datasets" "$$LABO_BUCKET/exp" "$$LABO_BUCKET/colab" "$$LABO_BUCKET/kaggle"
	if [[ ! -f "$$LABO_BUCKET/datasets/dataset_pequeno.csv" ]]; then
	  curl -L "$(DATA_URL)" -o "$$LABO_BUCKET/datasets/dataset_pequeno.csv"
	fi

doctor:
	source "$(REPO)/scripts/load_env.sh"
	command -v Rscript >/dev/null
	test -n "$$LABO_BUCKET" || { echo "LABO_BUCKET vacio"; exit 1; }
	test -d "$$LABO_BUCKET" || { echo "no existe LABO_BUCKET=$$LABO_BUCKET"; exit 1; }
	test -f "$$LABO_BUCKET/datasets/dataset_pequeno.csv" || echo "WARN: falta dataset; corre make data"
	test -f "$$LABO_BUCKET/kaggle/kaggle.json" || echo "WARN: falta $$LABO_BUCKET/kaggle/kaggle.json"
	Rscript -e 'ok <- all(sapply(c("data.table","rpart","rpart.plot"), requireNamespace, quietly=TRUE)); quit(status = if (ok) 0 else 1)'
	open -Ra "Brave Browser" >/dev/null 2>&1 || echo "WARN: Brave no encontrado"
	echo "doctor ok bucket=$$LABO_BUCKET"

run:
	source "$(REPO)/scripts/load_env.sh"
	test -n "$(NAME)" || { echo "uso: make run NAME=foo SCRIPT=z102"; exit 1; }
	test -n "$(SCRIPT)" || { echo "SCRIPT=z101 o z102"; exit 1; }
	export NAME="$(NAME)" SCRIPT="$(SCRIPT)" CP="$(CP)" MINSPLIT="$(MINSPLIT)" MINBUCKET="$(MINBUCKET)" MAXDEPTH="$(MAXDEPTH)" CUTOFF="$(CUTOFF)" SEED="$(SEED)"
	Rscript "$(REPO)/scripts/run_experiment.R"

z101:
	$(MAKE) run NAME=$(or $(NAME),KA2001) SCRIPT=z101 CP=$(or $(CP),-0.3) MINSPLIT=$(or $(MINSPLIT),0) MINBUCKET=$(or $(MINBUCKET),1) MAXDEPTH=$(or $(MAXDEPTH),3) CUTOFF=$(or $(CUTOFF),0.025) SEED=$(SEED)

z102:
	$(MAKE) run NAME=$(or $(NAME),KA2002) SCRIPT=z102 CP=$(or $(CP),-1) MINSPLIT=$(or $(MINSPLIT),250) MINBUCKET=$(or $(MINBUCKET),100) MAXDEPTH=$(or $(MAXDEPTH),3) CUTOFF=$(or $(CUTOFF),0.025) SEED=$(SEED)

submit:
	source "$(REPO)/scripts/load_env.sh"
	test -n "$(NAME)" || { echo "uso: make submit NAME=foo"; exit 1; }
	export NAME="$(NAME)"
	Rscript "$(REPO)/scripts/submit.R"

colab-z102:
	source "$(REPO)/scripts/load_env.sh"
	mkdir -p "$$LABO_BUCKET/colab"
	cp "$(REPO)/arboles/z102_FinalTrain.ipynb" "$$LABO_BUCKET/colab/z102_FinalTrain.ipynb"
	if [[ -n "$$LABO_COLAB_FOLDER_URL" ]]; then
	  open -a "Brave Browser" "$$LABO_COLAB_FOLDER_URL"
	else
	  open -a "Brave Browser" "https://colab.research.google.com/"
	  echo "File > Open notebook > Drive > labo1/colab/z102_FinalTrain.ipynb"
	fi

colab-zero2hero:
	source "$(REPO)/scripts/load_env.sh"
	mkdir -p "$$LABO_BUCKET/colab"
	cp "$(REPO)/zero2hero/zero2hero_01.ipynb" "$$LABO_BUCKET/colab/zero2hero_01.ipynb"
	if [[ -n "$$LABO_COLAB_FOLDER_URL" ]]; then
	  open -a "Brave Browser" "$$LABO_COLAB_FOLDER_URL"
	else
	  open -a "Brave Browser" "https://colab.research.google.com/"
	  echo "File > Open notebook > Drive > labo1/colab/zero2hero_01.ipynb"
	fi

colab-pull:
	source "$(REPO)/scripts/load_env.sh"
	test -d "$$LABO_BUCKET/colab"
	if [[ "$(FORCE)" != "1" ]]; then
	  if [[ -f "$$LABO_BUCKET/colab/z102_FinalTrain.ipynb" ]]; then
	    diff -q "$$LABO_BUCKET/colab/z102_FinalTrain.ipynb" "$(REPO)/arboles/z102_FinalTrain.ipynb" >/dev/null || { echo "diff en z102; FORCE=1 para pisar"; exit 1; }
	  fi
	fi
	if [[ -f "$$LABO_BUCKET/colab/z102_FinalTrain.ipynb" ]]; then cp "$$LABO_BUCKET/colab/z102_FinalTrain.ipynb" "$(REPO)/arboles/z102_FinalTrain.ipynb"; fi
	if [[ -f "$$LABO_BUCKET/colab/zero2hero_01.ipynb" ]]; then cp "$$LABO_BUCKET/colab/zero2hero_01.ipynb" "$(REPO)/zero2hero/zero2hero_01.ipynb"; fi

lab:
	jupyter lab "$(REPO)"

test:
	"$(REPO)/tests/test_overhaul.sh"
```

- [ ] **Step 4: `make test` and `make doctor`**

Copy `.env.example` to `.env` and set `LABO_BUCKET` (Drive `labo1`, or a local folder if Drive is not ready). Then:

```bash
make test
make data
make doctor
```

Expected: `test_overhaul ok`; `doctor ok` or WARNs for kaggle/Brave only (exit 0). Second `make data` does not re-download.

- [ ] **Step 5: Commit**

```bash
git add Makefile scripts/load_env.sh renv.lock renv/activate.R renv/settings.json .Rprofile
git commit -m "feat: Makefile, renv, and env loader"
```

Do not add `renv/library/`. If `settings.json` path differs, add whatever `renv::init` created except the library.

---

### Task 9: Notebook env cell (overhaul only)

**Files:**
- Modify: `arboles/z102_FinalTrain.ipynb`
- Modify: `zero2hero/zero2hero_01.ipynb`

Do this **after** cátedra fixes, on `main`, not on `fix/catedra-bugs`.

- [ ] **Step 1: Insert the env cell at the start of the R section**

In `arboles/z102_FinalTrain.ipynb`, immediately before the cell `# limpio la memoria` / `rm(list=ls(all.names=TRUE))` that begins “Final Train”, insert a **new** code cell (new Colab id is fine here; this is the overhaul):

```r
if (dir.exists("/content")) {
  BUCKET <- "/content/buckets/b1"
  DATASET <- "/content/datasets/dataset_pequeno.csv"
} else {
  BUCKET <- Sys.getenv("LABO_BUCKET")
  if (!nzchar(BUCKET)) stop("LABO_BUCKET no esta seteado")
  DATASET <- file.path(BUCKET, "datasets", "dataset_pequeno.csv")
}
```

Same cell, same placement, in `zero2hero/zero2hero_01.ipynb` immediately before the first R `rm(list=ls(...))` after the Python/shell setup (section 1.01 / after the `%%shell` cell). `zero2hero` has several `rm(list=...)` chapter resets. Put the env cell **once**, right after the shell setup, before `setwd("/content/buckets/b1/exp")` in 1.01.

- [ ] **Step 2: Replace R paths**

In **both** notebooks, only inside R cells (not `%%shell`):

| from | to |
|---|---|
| `setwd("/content/buckets/b1/exp")` | `setwd(file.path(BUCKET, "exp"))` |
| `setwd("/content/buckets/b1/exp/")` | `setwd(file.path(BUCKET, "exp"))` |
| `setwd( paste0("/content/buckets/b1/exp/", experimento ))` | `setwd(file.path(BUCKET, "exp", experimento))` |
| `fread("/content/datasets/dataset_pequeno.csv")` | `fread(DATASET)` |
| `read.csv("/content/datasets/dataset_pequeno.csv")` | `read.csv(DATASET)` |
| `dir.create("./ZH` stays | (relative, after setwd — leave) |
| `setwd("/content/buckets/b1/exp/ZH2017/")` and other `setwd("/content/buckets/b1/exp/ZH20xx/")` | `setwd(file.path(BUCKET, "exp", "ZH20xx"))` matching the folder name in that cell |

Do not edit `%%shell` / Python Drive-mount cells.

Also replace later `setwd` that already include the experimento subfolder, using the ZH name from that same cell (`ZH2017`, `ZH2018`, …).

- [ ] **Step 3: JSON still valid; Colab paths remain in shell cells**

```bash
python3 -c "import json; json.load(open('arboles/z102_FinalTrain.ipynb')); json.load(open('zero2hero/zero2hero_01.ipynb')); print('ok')"
rg -n 'fread\("/content/datasets' arboles/z102_FinalTrain.ipynb zero2hero/zero2hero_01.ipynb ; echo "r_fread:$?"
rg -n 'wget|My Drive/labo1' arboles/z102_FinalTrain.ipynb | head
```

Expected: python `ok`; R `fread("/content/datasets` gone; shell wget still present.

- [ ] **Step 4: Commit**

```bash
git add arboles/z102_FinalTrain.ipynb zero2hero/zero2hero_01.ipynb
git commit -m "feat: local LABO_BUCKET env cell in course notebooks"
```

---

### Task 10: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write `README.md`**

```markdown
# labo2026ba

Fork de Laboratorio de Implementacion I (Austral 2026 BA). Competencia Kaggle: `labo-1-ba-inicial`.

El disco de trabajo es Google Drive `labo1` (bucket `b1` de la catedra). Git vive en esta carpeta; datos y experimentos en Drive.

## Una vez

1. Drive for Desktop. Crea `My Drive/labo1`.
2. Copia `kaggle.json` a `labo1/kaggle/kaggle.json`.
3. `cp .env.example .env` y pega el path de `labo1` en `LABO_BUCKET`.
4. `make setup && make data && make doctor`

## Dia a dia

```bash
make z102
make run NAME=ka2001_md3 SCRIPT=z102 CP=-1 MINSPLIT=250 MINBUCKET=100 MAXDEPTH=3 CUTOFF=0.025
make submit NAME=ka2001_md3
make colab-z102
```

`make z101` / `make z102` usan los hiperparametros de la catedra y los nombres `KA2001` / `KA2002`. Si esa carpeta ya existe, aborta: cambia `NAME`.

## Colab

Runtime Python 3 para el setup (Drive, wget). Despues Runtime R. En esta Mac no corras las celdas Python; `make data` ya dejo el CSV en el bucket.

`make colab-z102` copia el notebook a `labo1/colab/` y abre Brave. `make colab-pull FORCE=1` trae el ipynb de vuelta.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: README for local make and Drive bucket"
```

---

### Task 11: End-to-end check

**Files:** none new

- [ ] **Step 1: Fake-data tests still pass**

```bash
make test
```

Expected: `test_overhaul ok`.

- [ ] **Step 2: Real doctor/data if Drive is configured**

```bash
make data
make doctor
```

Expected: exit 0. Dataset file exists under `$LABO_BUCKET/datasets/`. Second `make data` does not re-download (idempotent).

- [ ] **Step 3: Optional real train**

If the real `dataset_pequeno.csv` is in the bucket:

```bash
make z101 NAME=KA2001_smoke
ls "$LABO_BUCKET/exp/KA2001_smoke/submission.csv"
head exp/runs.csv
```

Expected: CSV with `numero_de_cliente,Predicted` and values `0`/`1`. Second `make z101 NAME=KA2001_smoke` fails.

- [ ] **Step 4: Confirm overhaul is not on the cátedra branch**

```bash
git log --oneline fix/catedra-bugs ^origin/main
git diff --name-only origin/main...fix/catedra-bugs
```

Expected: only the two notebooks from the cátedra plan. Makefile/README/scripts are on `main` only.

---

### Spec coverage

| Spec item | Task |
|---|---|
| Two roots, `.env`, autodetect | 3, 8 |
| gitignore rewrite, `!exp/runs.csv` | 2 |
| renv packages | 8 |
| scripts independent, z101/z102 params | 4 |
| Predicted 0/1 | 4 |
| `make run` bitácora, no overwrite | 5, 7, 8 |
| dual `runs.csv` | 5 |
| `make submit` | 6, 8 |
| Makefile targets + Brave | 8 |
| env cell + path swap | 9 |
| leave cátedra z101 `~/buckets/b1` | 4 (new script) + 9 (does not edit z101.R) |
| README | 10 |
| `make doctor` / idempotent data / test_dry | 7, 11 |
| not in labo-imp PR | 1, 11 |
