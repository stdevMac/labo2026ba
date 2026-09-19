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
