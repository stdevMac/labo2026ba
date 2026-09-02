# Spec: overhaul local (Makefile, Drive bucket, bitácora)

Fecha: 2026-09-02  
Se apoya en: `docs/superpowers/specs/2026-09-02-catedra-fixes-design.md`  
Branch de trabajo: `main` local, **arriba** de `fix/catedra-bugs`. Este trabajo **no** entra en el PR a `labo-imp`.

## Problema

La cátedra corre en Colab + Google Drive (`labo1` = bucket `b1`) o en una VM GCP con `~/buckets/b1`. Este clone no tiene README, Makefile, ni forma de correr lo mismo en la Mac y ver los mismos `datasets/` y `exp/` que Colab.

## Objetivo

Trabajar en esta Mac con R nativo, y abrir Brave con el Colab listo, ambos escribiendo al mismo disco: Google Drive `labo1`. Bitácora de corridas. Scripts y notebooks independientes (la lógica se puede divergir; no hay `R/` compartido).

## Fuera de alcance

- Docker
- Grid de hiperparámetros, ranking, plots de experimentos
- Poner el `.git` dentro de Drive
- Unificar scripts y notebooks en un núcleo común
- Cambiar la pedagogía de los notebooks más allá de la celda de entorno y paths parametrizados
- Subir el overhaul a `labo-imp`

## Dos raíces

| Nombre | Qué es | Qué vive ahí |
|---|---|---|
| `REPO` | `/Users/maceo/laboratorio/labo2026ba` | git, scripts, notebooks, Makefile, `exp/runs.csv` (copia para git) |
| `LABO_BUCKET` | `.../My Drive/labo1` (Drive for Desktop) | `datasets/`, `exp/<nombre>/`, `kaggle/kaggle.json`, `colab/*.ipynb` |

`.env` en la raíz del repo (gitignored):

```
LABO_BUCKET=/Users/maceo/Library/CloudStorage/<GoogleDrive-...>/My Drive/labo1
LABO_COLAB_FOLDER_URL=
```

`LABO_COLAB_FOLDER_URL` es el URL de Drive de `labo1/colab`. Si está vacío, `make colab-*` igual copia el notebook y abre `https://colab.research.google.com/`, e imprime “File → Open notebook → Drive → labo1/colab/…”. No se usa la API de Drive ni se parsean xattr.

Autodetect si `.env` no tiene `LABO_BUCKET`: primer directorio `labo1` bajo `~/Library/CloudStorage`. Si no hay, `make doctor` falla con el mensaje de crear `labo1` en Drive y pegar el path.

## Layout del repo

```
arboles/                 # cátedra post-fixes + celda de entorno (overhaul)
zero2hero/               # idem
scripts/
  z101_primer_modelo.R
  z102_final_train.R
  run_experiment.R
  submit.R
datasets/                # no se usa; el CSV vive en el bucket
exp/runs.csv             # bitácora versionada
renv.lock
renv/
Makefile
README.md
.env.example
.env                     # gitignored
```

No hay `R/` de librería compartida.

## gitignore

Hoy `*.md` está ignorado salvo `README.md`. Cambiar:

- Dejar de ignorar `*.md`
- Ignorar: `datasets/`, `exp/*/`, `.env`, `.Rhistory`, `.RData`, `.DS_Store`, `.ipynb_checkpoints/`, `renv/library/`
- Seguir ignorando `*.csv` y `*.csv.gz` con excepción `!exp/runs.csv`
- Sacar el ruido de Java/LaTeX/Scala/Xcode que no aplica
- Seguir ignorando `kaggle.json` si alguien lo copia al repo (`**/kaggle.json`)

## R nativo

- `renv` con: `data.table`, `rpart`, `rpart.plot`, `ggplot2`, `caret`
- `make setup` = `renv::restore()` (o `init` + snapshot la primera vez)
- Runtime de trabajo: `Rscript`. Jupyter local es opcional (`make lab`) con IRkernel; no es el camino principal
- Las celdas Python de los notebooks (mount Drive, wget) **no** se corren en local. `make data` ya dejó el CSV en el bucket. README: en Jupyter local, arrancar en la primera celda R

## Celda de entorno en notebooks

Al inicio de la parte R de `z102_FinalTrain.ipynb` y `zero2hero_01.ipynb` (después de las celdas Python de Colab):

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

Reemplazar en esas notebooks los paths hardcodeados de R:

- `setwd("/content/buckets/b1/exp")` → `setwd(file.path(BUCKET, "exp"))`
- `fread("/content/datasets/dataset_pequeno.csv")` → `fread(DATASET)`

No tocar las celdas `%%shell` / Python: en Colab siguen siendo el arranque en frío.

`z101_PrimerModelo.R` de la cátedra se deja con `~/buckets/b1`. El script de trabajo es `scripts/z101_primer_modelo.R`, que usa `LABO_BUCKET`.

## Scripts (independientes de los notebooks)

Leen `LABO_BUCKET` (y si falta, error). Escriben solo al bucket, salvo el append a `REPO/exp/runs.csv`.

`scripts/z101_primer_modelo.R` y `scripts/z102_final_train.R` son copias de la receta de la cátedra (árbol `rpart`, corte, fwrite). Params por defecto:

- z101: `cp=-0.3`, `minsplit=0`, `minbucket=1`, `maxdepth=3`, cutoff `1/40`
- z102: `cp=-1`, `minsplit=250`, `minbucket=100`, `maxdepth=3`, cutoff `1/40`

`Predicted` siempre `as.numeric(prob > cutoff)` (0/1).

No se `source`an entre sí ni desde los notebooks.

## Bitácora

`make run NAME=ka2001_md3 CP=-1 MINSPLIT=250 MINBUCKET=100 MAXDEPTH=3 CUTOFF=0.025 SCRIPT=z102`

Implementación: `scripts/run_experiment.R` llama al script indicado con esos params.

Crea `$LABO_BUCKET/exp/<NAME>/`:

- `params.txt` — name, script, cp, minsplit, minbucket, maxdepth, cutoff, seed, timestamp
- `submission.csv` — `numero_de_cliente, Predicted`

Si `$LABO_BUCKET/exp/<NAME>/` ya existe: abortar con error. No pisar.

Append una línea a:

1. `$LABO_BUCKET/exp/runs.csv`
2. `$REPO/exp/runs.csv`

Columnas: `ts,name,script,cp,minsplit,minbucket,maxdepth,cutoff,n_ones,kaggle_score`

`kaggle_score` nace vacío. `make submit NAME=foo` sube `$LABO_BUCKET/exp/foo/submission.csv` a `labo-1-ba-inicial` con `kaggle competitions submit` usando `$LABO_BUCKET/kaggle/kaggle.json` (copiado a `~/.kaggle/kaggle.json` si hace falta, `chmod 600`). Después rellena `kaggle_score` si el CLI devuelve algo usable; si no, deja un placeholder y el mensaje de stdout.

`make z101` = `make run NAME=KA2001 SCRIPT=z101` con params de cátedra.  
`make z102` = `make run NAME=KA2002 SCRIPT=z102` con params de cátedra.

## Makefile

```
make setup              renv restore
make data               wget https://storage.googleapis.com/open-courses/austral2026-5da5/labo1/dataset_pequeno.csv → $LABO_BUCKET/datasets/ si no existe
make doctor             R, renv, LABO_BUCKET, dataset, kaggle.json, Brave
make z101
make z102
make run NAME=...       ver bitácora
make submit NAME=...
make colab-z102         cp notebook → $LABO_BUCKET/colab/ y abre Brave
make colab-zero2hero
make colab-pull         cp $LABO_BUCKET/colab/*.ipynb de vuelta al repo; si hay diff, aborta salvo FORCE=1
make lab                jupyter lab en el repo (opcional)
```

`make colab-*`:

1. Copia el `.ipynb` del repo a `$LABO_BUCKET/colab/<archivo>.ipynb`
2. Si `LABO_COLAB_FOLDER_URL` está seteado, `open -a "Brave Browser" "$LABO_COLAB_FOLDER_URL"`
3. Si no, `open -a "Brave Browser" "https://colab.research.google.com/"` e imprime la ruta Drive `labo1/colab/<archivo>.ipynb`

Colab, con el arranque en frío de la cátedra, monta Drive y ve el mismo `datasets/` y `exp/` que los scripts locales. No hace falta pushear para abrir el notebook; sí hace falta que Drive for Desktop haya sincrónizado el `cp`.

## README

Corto, en español:

- Qué es (fork de labo 2026 BA, competencia `labo-1-ba-inicial`)
- Crear `labo1` en Drive, Drive for Desktop, copiar `kaggle.json` a `labo1/kaggle/`
- `.env` desde `.env.example`
- `make setup && make data && make doctor`
- `make z102` y `make colab-z102`
- `make run` / `make submit`
- En Colab: Runtime Python para el setup, después R. En local: no correr las celdas Python

Sin tutorial de `rpart`.

## Verificación

- `make doctor` sale 0 con bucket, dataset, R y paquetes (kaggle.json puede warn si falta)
- `make data` es idempotente
- `make run NAME=test_dry SCRIPT=z101` crea la carpeta y una línea en ambos `runs.csv`; segunda vez con el mismo NAME falla
- `python3` carga los notebooks después de la celda de entorno
- `git diff origin/main` del overhaul incluye Makefile, scripts, renv, README, gitignore, celda de entorno; no mezcla el inventario del spec de cátedra (ese ya está en `fix/catedra-bugs`)

## Criterio de hecho

En esta Mac: `make setup && make data && make z102` produce un CSV de Kaggle en Drive. `make colab-z102` abre Brave. Colab y local ven el mismo `exp/`.
