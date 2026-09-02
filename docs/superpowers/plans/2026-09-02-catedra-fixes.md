# Cátedra surgical fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open a small PR to `labo-imp/labo2026ba` that fixes correctness bugs, copy-paste errors, and confusing typos in two course notebooks — nothing else.

**Architecture:** Branch `fix/catedra-bugs` from `origin/main` (commit `d67db05`, no overhaul docs). Edit notebook cell source in place; do not regenerate JSON, do not execute cells, do not add files. Two commits: code, then typos/intros. Merge that branch into local `main` afterwards so the overhaul can sit on top.

**Tech Stack:** R notebooks (nbformat 4), `data.table` / `rpart` / `caret` already in the cells, `gh` for the PR.

**Spec:** `docs/superpowers/specs/2026-09-02-catedra-fixes-design.md`

**Do not touch:** `arboles/z101_PrimerModelo.R`, hyperparams, Colab paths, `.gitignore`, README, Makefile, pedagogy (single-node tree, Hackeando Kaggle, section 1.04 title). Do not add comments. Do not commit this plan or the spec onto `fix/catedra-bugs`.

---

### File map

| File | Role |
|---|---|
| `arboles/z102_FinalTrain.ipynb` | `Predicted` 0/1 + typos |
| `zero2hero/zero2hero_01.ipynb` | `GananciaArbol` / `ArbolMontecarlo`, 1.08 paths, 1.05 intro, snippet, empty cell, lying comments, typos |

---

### Task 1: Branch from origin/main

**Files:** none

- [ ] **Step 1: Confirm starting point**

Run:

```bash
git fetch origin
git rev-parse origin/main
git log -1 --oneline origin/main
```

Expected: `d67db05` (`sync main to develop`). If origin/main moved, still branch from current `origin/main` — the course files should be the same two notebooks.

- [ ] **Step 2: Create the branch**

```bash
git checkout -b fix/catedra-bugs origin/main
```

Expected: HEAD is `d67db05`, working tree has only course files plus git metadata. `docs/superpowers/` must **not** exist on this branch.

- [ ] **Step 3: Baseline — the bugs are present**

Run:

```bash
rg -n 'Predicted := prob >' arboles/z102_FinalTrain.ipynb
rg -n 'Noy hay|Runtime Tipe|libería|limitacinoes' arboles/z102_FinalTrain.ipynb
rg -n 'createDataPartition\(dataset\$clase_ternaria, p = 0.70' zero2hero/zero2hero_01.ipynb
rg -n 'for \(semilla in ksemillas\)' zero2hero/zero2hero_01.ipynb
rg -n 'modelo < -rpart' zero2hero/zero2hero_01.ipynb
rg -n 'dir.create\("\./exp/' zero2hero/zero2hero_01.ipynb
rg -n 'library\("rpart"\) # cargo la libreria  data.table' zero2hero/zero2hero_01.ipynb
```

Expected: every command prints at least one match. The `createDataPartition` grep prints **four** lines (three inside `GananciaArbol` with two-space indent, one in section 1.11 unindented). Only the indented three get changed later.

No commit (branch creation only).

---

### Task 2: z102 — Predicted is 0/1

**Files:**
- Modify: `arboles/z102_FinalTrain.ipynb`

- [ ] **Step 1: Confirm the failing line**

Run:

```bash
rg -n 'Predicted :=' arboles/z102_FinalTrain.ipynb
```

Expected: one line containing `tb_prediccion[, Predicted := prob > (1/40) ]`

- [ ] **Step 2: Replace it**

In `arboles/z102_FinalTrain.ipynb` replace this exact source string:

```
tb_prediccion[, Predicted := prob > (1/40) ]
```

with:

```
tb_prediccion[, Predicted := as.numeric(prob > (1/40)) ]
```

Do not change surrounding comments.

- [ ] **Step 3: Confirm the bug is gone**

Run:

```bash
rg -n 'Predicted := prob >' arboles/z102_FinalTrain.ipynb ; echo "exit:$?"
rg -n 'as.numeric\(prob > \(1/40\)\)' arboles/z102_FinalTrain.ipynb
python3 -c "import json; json.load(open('arboles/z102_FinalTrain.ipynb')); print('ok')"
```

Expected: first rg prints nothing (exit 1), second rg prints one match, python prints `ok`.

- [ ] **Step 4: z102 typos**

Replace these substrings in `arboles/z102_FinalTrain.ipynb` (literal, once each unless noted):

| from | to | times |
|---|---|---|
| `simplificaciónes` | `simplificaciones` | 1 |
| `libería` | `librería` | 1 |
| `busqueda búsqueda` | `búsqueda` | 1 |
| `Noy hay` | `No hay` | 1 |
| `utlizando` | `utilizando` | 1 |
| `limitacinoes` | `limitaciones` | 1 |
| `Change Runtime Tipe` | `Change Runtime Type` | 2 |
| `predccion` | `prediccion` | 1 |
| `estension .csv` | `extension .csv` | 1 |
| `este el el comando` | `este es el comando` | 1 |

Do not rewrite the sentences around them.

- [ ] **Step 5: Confirm z102 typos are gone**

Run:

```bash
rg -n 'simplificaciónes|libería|busqueda búsqueda|Noy hay|utlizando|limitacinoes|Runtime Tipe|predccion|estension \.csv|este el el comando' arboles/z102_FinalTrain.ipynb ; echo "exit:$?"
python3 -c "import json; json.load(open('arboles/z102_FinalTrain.ipynb')); print('ok')"
```

Expected: rg exit 1 (no matches), python `ok`.

- [ ] **Step 6: Commit code+typos for z102**

```bash
git add arboles/z102_FinalTrain.ipynb
git commit -m "fix: z102 Predicted as 0/1 and confusing typos"
```

This is commit 1 of 2. `z102` is small enough that Predicted and typos stay together. `zero2hero` still uses the second commit.

---

### Task 3: zero2hero — GananciaArbol and ArbolMontecarlo

**Files:**
- Modify: `zero2hero/zero2hero_01.ipynb`

- [ ] **Step 1: Confirm the three indented partition lines**

Run:

```bash
rg -n '  train_rows <- createDataPartition\(dataset\$clase_ternaria, p = 0.70' zero2hero/zero2hero_01.ipynb
```

Expected: exactly 3 matches (sections 1.12, 1.14, 1.15). The unindented 1.11 line must remain.

- [ ] **Step 2: Fix the three GananciaArbol partition lines**

Replace all occurrences of this exact string (two leading spaces, inside the function):

```
  train_rows <- createDataPartition(dataset$clase_ternaria, p = 0.70, list = FALSE)
```

with:

```
  train_rows <- createDataPartition(data$clase_ternaria, p = train, list = FALSE)
```

Do **not** replace the 1.11 line:

```
train_rows <- createDataPartition(dataset$clase_ternaria, p = 0.70, list = FALSE)
```

- [ ] **Step 3: Normalize 1.14 and 1.15 with `(1 - train)`**

Replace all occurrences of this exact indented string:

```
  ganancia_testing_normalizada <- ganancia_testing / 0.3
```

with:

```
  ganancia_testing_normalizada <- ganancia_testing / (1 - train)
```

Leave the unindented 1.11 line `ganancia_testing_normalizada <- ganancia_testing / 0.3` unchanged (that chapter still teaches 70/30 with a literal).

Section 1.12 `GananciaArbol` returns `ganancia_testing` with no division — do not add one.

- [ ] **Step 4: Fix ArbolMontecarlo body**

Replace this exact function (section 1.15):

```
ArbolMontecarlo <- function(semillas, data, x, train = 0.70) {
  vector_ganancias <- c() # vector donde voy a ir acumulando las ganancias
  for (semilla in ksemillas)
  {
    ganancia <- GananciaArbol(semilla, dataset, x = x, train = 0.70)
    vector_ganancias <- c(vector_ganancias, ganancia)
  }

  return(mean(vector_ganancias))
}
```

with:

```
ArbolMontecarlo <- function(semillas, data, x, train = 0.70) {
  vector_ganancias <- c() # vector donde voy a ir acumulando las ganancias
  for (semilla in semillas)
  {
    ganancia <- GananciaArbol(semilla, data, x = x, train = train)
    vector_ganancias <- c(vector_ganancias, ganancia)
  }

  return(mean(vector_ganancias))
}
```

Do not change the call sites. They already pass `ksemillas` and `dataset`:

```
ganancia_montecarlo1 <- ArbolMontecarlo(ksemillas, dataset, x = param1, train = 0.70)
ganancia_montecarlo2 <- ArbolMontecarlo(ksemillas, dataset, x = param2, train = 0.70)
```

- [ ] **Step 5: Run the function-level checks**

```bash
rg -n '  train_rows <- createDataPartition\(dataset\$clase_ternaria' zero2hero/zero2hero_01.ipynb ; echo "indented_old:$?"
rg -n '  train_rows <- createDataPartition\(data\$clase_ternaria, p = train' zero2hero/zero2hero_01.ipynb
rg -n 'createDataPartition\(dataset\$clase_ternaria, p = 0.70' zero2hero/zero2hero_01.ipynb
rg -n 'ganancia_testing / \(1 - train\)' zero2hero/zero2hero_01.ipynb
rg -n -A8 'ArbolMontecarlo <- function' zero2hero/zero2hero_01.ipynb
```

Expected:

- indented old partition: no matches
- new partition: 3 matches
- unindented 1.11 `dataset$clase_ternaria, p = 0.70`: **1** match remains
- `(1 - train)`: 2 matches
- `ArbolMontecarlo` body uses `for (semilla in semillas)` and `GananciaArbol(semilla, data, x = x, train = train)`

Do **not** change the 1.14 top-level loop (`for (semilla in ksemillas)` + `GananciaArbol(semilla, dataset, ...)`). That chapter is not wrapped in the function.

---

### Task 4: zero2hero — 1.08 dead dir.create, snippet, empty cell, lying comments

**Files:**
- Modify: `zero2hero/zero2hero_01.ipynb`

- [ ] **Step 1: Remove nested exp/ creates in 1.08**

The 1.08 cell already did `setwd("/content/buckets/b1/exp/ZH2018/")`. In that cell, delete these two lines and the blank line after them:

```
dir.create("./exp/", showWarnings = FALSE)
dir.create("./exp/ZH2018/", showWarnings = FALSE)
```

Keep:

```
fwrite(entrega,
        file = "para_Kaggle_0108.csv",
        sep = ","
)
```

The CSV still lands in `ZH2018`.

- [ ] **Step 2: Confirm**

```bash
rg -n 'dir.create\("\./exp/' zero2hero/zero2hero_01.ipynb ; echo "exit:$?"
rg -n 'para_Kaggle_0108.csv' zero2hero/zero2hero_01.ipynb
```

Expected: first rg no matches, second rg one match.

- [ ] **Step 3: Fix the broken markdown snippet**

Replace this markdown cell source (id `EqsfmFW97JZV`):

```
#genero el modelo
modelo < -rpart(formula="clase_ternaria ~ .",
    data=dataset1,
    xval=0,
    cp=-1,
    maxdepth=3)

#imprimo el modelo graficamente
prp(modelo, extra=101, digits=5, branch=1, type=4, varlen=0, faclen=0, tweak=1.3)
```

with this (same content as the following code cell, still markdown):

```
#genero el modelo
modelo <- rpart(formula="clase_ternaria ~ .",
    data=dataset[foto_mes == 202107],
    xval=0,
    cp=-1,
    maxdepth=3)

#imprimo el modelo graficamente
prp(modelo, extra=101, digits=-5, branch=1, type=4, varlen=0, faclen=0, tweak=1.3)
```

- [ ] **Step 4: Confirm snippet**

```bash
rg -n 'modelo < -rpart|dataset1' zero2hero/zero2hero_01.ipynb ; echo "exit:$?"
```

Expected: no matches.

- [ ] **Step 5: Delete the empty code cell**

Delete this entire cell object (keep surrounding commas valid — remove the cell and its trailing comma as one JSON value in the `cells` array):

```
    {
      "cell_type": "code",
      "source": [],
      "metadata": {
        "id": "wVw36SJeNjbu"
      },
      "execution_count": null,
      "outputs": []
    },
```

- [ ] **Step 6: Confirm empty cell is gone and JSON is valid**

```bash
rg -n 'wVw36SJeNjbu' zero2hero/zero2hero_01.ipynb ; echo "exit:$?"
python3 -c "import json; nb=json.load(open('zero2hero/zero2hero_01.ipynb')); print(len(nb['cells']), 'cells')"
```

Expected: rg no match; python prints a cell count (one less than before; originally 461, now 460).

- [ ] **Step 7: Fix lying rpart comments**

Replace all occurrences of:

```
library("rpart") # cargo la libreria  data.table
```

with:

```
library("rpart") # cargo la libreria  rpart
```

There are four (sections 1.10, 1.12, 1.14, 1.15). Do not change `library("data.table") # cargo la libreria  data.table`.

- [ ] **Step 8: Confirm comments**

```bash
rg -n 'library\("rpart"\) # cargo la libreria  data.table' zero2hero/zero2hero_01.ipynb ; echo "exit:$?"
rg -n 'library\("rpart"\) # cargo la libreria  rpart' zero2hero/zero2hero_01.ipynb
```

Expected: first no matches, second 4 matches.

---

### Task 5: zero2hero — 1.05 intro and typos

**Files:**
- Modify: `zero2hero/zero2hero_01.ipynb`

- [ ] **Step 1: Replace the copied 1.05 intro**

The markdown cell immediately under `## 1.05 Creando un data.table a partir de las columnas` that starts with `El objetivo de esta sección es analizar el efecto` currently lists colineales / normalizacion / log / outliers (copy of 1.04).

Replace that cell source with:

```
Hasta ahora el data.table se leía de un archivo. Acá se arma uno a partir de dos vectores de igual longitud, y se lo graba con fwrite.
```

Do not rewrite other 1.05 cells.

- [ ] **Step 2: Confirm 1.04 still has the colineales list and 1.05 does not**

```bash
rg -n 'Variables Colineales' zero2hero/zero2hero_01.ipynb
rg -n 'Hasta ahora el data.table se leía de un archivo' zero2hero/zero2hero_01.ipynb
```

Expected: first rg **1** match (section 1.04 only), second rg 1 match.

- [ ] **Step 3: Apply typos**

Literal replacements in `zero2hero/zero2hero_01.ipynb`:

| from | to | times |
|---|---|---|
| `Change Runtime Tipe` | `Change Runtime Type` | 1 |
| `fucion` | `funcion` | 2 (`Sys.time` and `ArbolMontecarlo`) |
| `becnmarks` | `benchmarks` | 1 |
| `bibligrafía` | `bibliografía` | 1 |
| `poscion` | `posicion` | 1 |
| `simplisima` | `simplísima` | 1 |
| `de0la libreria` | `de la libreria` | 1 |
| `un albol de profundidad` | `un arbol de profundidad` | 1 |
| `Disgresión` | `Digresión` | 1 |
| `objtetos` | `objetos` | 1 |
| `garbaje collection` | `garbage collection` | 1 |
| `limpie bore todos` | `limpie y borre todos` | 1 |
| `<bv>` | `<br>` | 2 |
| `numero_de_clente` | `numero_de_cliente` | 1 |
| `lsita` | `lista` | 1 |
| `caracters` | `caracteres` | 1 |
| `exista el tipo` | `existe el tipo` | 1 |
| `qyuedó` | `quedó` | 1 |
| `probabildades` | `probabilidades` | 2 |
| `se obseva` | `se observa` | 1 |
| `libreria  **data.table` | `libreria  **data.table**` | 1 |
| `entrega_de juguete.txt` | `entrega_de_juguete.csv` | 1 |

Do **not** change `## 1.04 Transformado (innecesariamente) las variables`.

- [ ] **Step 4: Confirm typos are gone**

```bash
rg -n 'Runtime Tipe|fucion|becnmarks|bibligrafía|poscion|simplisima|de0la |un albol |Disgresión|objtetos|garbaje collection|limpie bore|<bv>|numero_de_clente|lsita |caracters|exista el tipo|qyuedó|probabildades|se obseva|entrega_de juguete.txt' zero2hero/zero2hero_01.ipynb ; echo "exit:$?"
python3 -c "import json; json.load(open('zero2hero/zero2hero_01.ipynb')); json.load(open('arboles/z102_FinalTrain.ipynb')); print('ok')"
```

Expected: rg exit 1, python `ok`. `simplísima` still present (the fixed word).

- [ ] **Step 5: Commit zero2hero**

```bash
git add zero2hero/zero2hero_01.ipynb
git commit -m "fix: zero2hero correctness, copy-paste, and confusing typos"
```

---

### Task 6: Verify the PR surface and merge locally

**Files:** none new

- [ ] **Step 1: Diff is only the two notebooks**

```bash
git diff --name-only origin/main...HEAD
git log --oneline origin/main..HEAD
```

Expected names:

```
arboles/z102_FinalTrain.ipynb
zero2hero/zero2hero_01.ipynb
```

Expected two commits. No `docs/`, no `.gitignore`, no `z101`.

- [ ] **Step 2: Inventory grep (spec verification block)**

```bash
rg -n 'Noy hay|Runtime Tipe|dataset\$clase_ternaria, p = 0.70' arboles/z102_FinalTrain.ipynb zero2hero/zero2hero_01.ipynb
rg -n 'modelo < -rpart' zero2hero/zero2hero_01.ipynb
rg -n 'Predicted := prob >' arboles/z102_FinalTrain.ipynb
rg -n '  train_rows <- createDataPartition\(data\$clase_ternaria, p = train' zero2hero/zero2hero_01.ipynb
```

Expected: the first three commands have no hits. The last has 3 hits. (1.11 still has unindented `dataset$clase_ternaria, p = 0.70` — that is allowed.)

- [ ] **Step 3: Merge into local main**

```bash
git checkout main
git merge --no-ff fix/catedra-bugs -m "merge fix/catedra-bugs into main"
```

`main` already has the spec commit (`7171968`). The merge brings the two notebook commits on top. Do not delete `fix/catedra-bugs`.

- [ ] **Step 4: Open the PR**

```bash
git push -u origin fix/catedra-bugs
gh pr create --repo labo-imp/labo2026ba --base main --head stdevMac:fix/catedra-bugs \
  --title "fix: notebook correctness, copy-paste, and confusing typos" \
  --body "$(cat <<'EOF'
Fixes in z102 and zero2hero only.

- z102 Predicted is 0/1 for Kaggle (was TRUE/FALSE)
- GananciaArbol uses its data/train arguments
- ArbolMontecarlo uses semillas/data/train instead of globals
- 1.08 no longer creates a nested unused exp/ folder
- 1.05 intro matches the chapter
- typos that changed meaning (Noy hay, Runtime Tipe, etc.)

No hyperparameter changes, no Colab path changes, no new files.
EOF
)"
```

If `gh` cannot open a PR against `labo-imp` (permissions), keep the branch pushed to `origin` and stop; local `main` already has the merge.

---

### Spec coverage

| Spec item | Task |
|---|---|
| Branch from origin/main, no docs on the PR | 1, 6 |
| z102 Predicted 0/1 | 2 |
| z102 typos | 2 |
| GananciaArbol data/train, 1.12 no extra normalize | 3 |
| 1.14/1.15 `/ (1 - train)` | 3 |
| ArbolMontecarlo args | 3 |
| 1.08 dir.create | 4 |
| markdown snippet | 4 |
| empty cell | 4 |
| lying rpart comments | 4 |
| 1.05 intro | 5 |
| zero2hero typos | 5 |
| z101 untouched | 6 name-only diff |
| PR to labo-imp | 6 |
| merge to local main | 6 |
