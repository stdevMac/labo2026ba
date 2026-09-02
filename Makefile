SHELL := /bin/bash
REPO := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
DATA_URL := https://storage.googleapis.com/open-courses/austral2026-5da5/labo1/dataset_pequeno.csv

.PHONY: setup data doctor z101 z102 run submit colab-z102 colab-zero2hero colab-pull lab test

setup:
	Rscript -e 'if (!requireNamespace("renv", quietly=TRUE)) install.packages("renv", repos="https://cloud.r-project.org")' && Rscript -e 'renv::restore()'

data:
	bash -c 'set -euo pipefail; source "$(REPO)/scripts/load_env.sh"; test -n "$$LABO_BUCKET" || { echo "LABO_BUCKET vacio"; exit 1; }; mkdir -p "$$LABO_BUCKET/datasets" "$$LABO_BUCKET/exp" "$$LABO_BUCKET/colab" "$$LABO_BUCKET/kaggle"; if [[ ! -f "$$LABO_BUCKET/datasets/dataset_pequeno.csv" ]]; then curl -L "$(DATA_URL)" -o "$$LABO_BUCKET/datasets/dataset_pequeno.csv"; fi'

doctor:
	bash -c 'set -euo pipefail; source "$(REPO)/scripts/load_env.sh"; command -v Rscript >/dev/null; test -n "$$LABO_BUCKET" || { echo "LABO_BUCKET vacio"; exit 1; }; test -d "$$LABO_BUCKET" || { echo "no existe LABO_BUCKET=$$LABO_BUCKET"; exit 1; }; test -f "$$LABO_BUCKET/datasets/dataset_pequeno.csv" || echo "WARN: falta dataset; corre make data"; test -f "$$LABO_BUCKET/kaggle/kaggle.json" || echo "WARN: falta $$LABO_BUCKET/kaggle/kaggle.json"; Rscript -e "ok <- all(sapply(c('\''data.table'\'','\''rpart'\'','\''rpart.plot'\''), requireNamespace, quietly=TRUE)); quit(status = if (ok) 0 else 1)"; open -Ra "Brave Browser" >/dev/null 2>&1 || echo "WARN: Brave no encontrado"; echo "doctor ok bucket=$$LABO_BUCKET"'

run:
	bash -c 'set -euo pipefail; source "$(REPO)/scripts/load_env.sh"; test -n "$(NAME)" || { echo "uso: make run NAME=foo SCRIPT=z102"; exit 1; }; test -n "$(SCRIPT)" || { echo "SCRIPT=z101 o z102"; exit 1; }; export NAME="$(NAME)" SCRIPT="$(SCRIPT)" CP="$(CP)" MINSPLIT="$(MINSPLIT)" MINBUCKET="$(MINBUCKET)" MAXDEPTH="$(MAXDEPTH)" CUTOFF="$(CUTOFF)" SEED="$(SEED)"; Rscript "$(REPO)/scripts/run_experiment.R"'

z101:
	$(MAKE) run NAME=$(or $(NAME),KA2001) SCRIPT=z101 CP=$(or $(CP),-0.3) MINSPLIT=$(or $(MINSPLIT),0) MINBUCKET=$(or $(MINBUCKET),1) MAXDEPTH=$(or $(MAXDEPTH),3) CUTOFF=$(or $(CUTOFF),0.025) SEED=$(SEED)

z102:
	$(MAKE) run NAME=$(or $(NAME),KA2002) SCRIPT=z102 CP=$(or $(CP),-1) MINSPLIT=$(or $(MINSPLIT),250) MINBUCKET=$(or $(MINBUCKET),100) MAXDEPTH=$(or $(MAXDEPTH),3) CUTOFF=$(or $(CUTOFF),0.025) SEED=$(SEED)

submit:
	bash -c 'set -euo pipefail; source "$(REPO)/scripts/load_env.sh"; test -n "$(NAME)" || { echo "uso: make submit NAME=foo"; exit 1; }; export NAME="$(NAME)"; Rscript "$(REPO)/scripts/submit.R"'

colab-z102:
	bash -c 'set -euo pipefail; source "$(REPO)/scripts/load_env.sh"; test -n "$$LABO_BUCKET" || { echo "LABO_BUCKET vacio"; exit 1; }; mkdir -p "$$LABO_BUCKET/colab"; cp "$(REPO)/arboles/z102_FinalTrain.ipynb" "$$LABO_BUCKET/colab/z102_FinalTrain.ipynb"; if [[ -n "$$LABO_COLAB_FOLDER_URL" ]]; then open -a "Brave Browser" "$$LABO_COLAB_FOLDER_URL"; else open -a "Brave Browser" "https://colab.research.google.com/"; echo "File > Open notebook > Drive > labo1/colab/z102_FinalTrain.ipynb"; fi'

colab-zero2hero:
	bash -c 'set -euo pipefail; source "$(REPO)/scripts/load_env.sh"; test -n "$$LABO_BUCKET" || { echo "LABO_BUCKET vacio"; exit 1; }; mkdir -p "$$LABO_BUCKET/colab"; cp "$(REPO)/zero2hero/zero2hero_01.ipynb" "$$LABO_BUCKET/colab/zero2hero_01.ipynb"; if [[ -n "$$LABO_COLAB_FOLDER_URL" ]]; then open -a "Brave Browser" "$$LABO_COLAB_FOLDER_URL"; else open -a "Brave Browser" "https://colab.research.google.com/"; echo "File > Open notebook > Drive > labo1/colab/zero2hero_01.ipynb"; fi'

colab-pull:
	bash -c 'set -euo pipefail; source "$(REPO)/scripts/load_env.sh"; test -n "$$LABO_BUCKET" || { echo "LABO_BUCKET vacio"; exit 1; }; test -d "$$LABO_BUCKET/colab"; if [[ "$(FORCE)" != "1" ]]; then if [[ -f "$$LABO_BUCKET/colab/z102_FinalTrain.ipynb" ]]; then diff -q "$$LABO_BUCKET/colab/z102_FinalTrain.ipynb" "$(REPO)/arboles/z102_FinalTrain.ipynb" >/dev/null || { echo "diff en z102; FORCE=1 para pisar"; exit 1; }; fi; if [[ -f "$$LABO_BUCKET/colab/zero2hero_01.ipynb" ]]; then diff -q "$$LABO_BUCKET/colab/zero2hero_01.ipynb" "$(REPO)/zero2hero/zero2hero_01.ipynb" >/dev/null || { echo "diff en zero2hero; FORCE=1 para pisar"; exit 1; }; fi; fi; if [[ -f "$$LABO_BUCKET/colab/z102_FinalTrain.ipynb" ]]; then cp "$$LABO_BUCKET/colab/z102_FinalTrain.ipynb" "$(REPO)/arboles/z102_FinalTrain.ipynb"; fi; if [[ -f "$$LABO_BUCKET/colab/zero2hero_01.ipynb" ]]; then cp "$$LABO_BUCKET/colab/zero2hero_01.ipynb" "$(REPO)/zero2hero/zero2hero_01.ipynb"; fi'

lab:
	jupyter lab "$(REPO)"

test:
	"$(REPO)/tests/test_overhaul.sh"
