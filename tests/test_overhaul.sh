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

python3 - "$tmp/exp/test_dry/submission.csv" <<'PY'
import csv
import sys

path = sys.argv[1]
with open(path, newline="") as f:
    reader = csv.DictReader(f)
    if not reader.fieldnames:
        sys.exit("submission.csv has no header")
    names = [n.strip() for n in reader.fieldnames]
    if "Predicted" not in names:
        sys.exit("submission.csv missing Predicted column: " + ",".join(reader.fieldnames))
    pred_name = reader.fieldnames[names.index("Predicted")]
    for i, row in enumerate(reader, start=2):
        raw = (row.get(pred_name) or "").strip()
        if raw not in ("0", "1"):
            sys.exit(f"line {i}: Predicted={raw!r} is not 0 or 1")
PY

ck_before=$(cksum "$tmp/exp/test_dry/submission.csv")

if Rscript "$ROOT/scripts/run_experiment.R"; then
  echo "expected second run to fail"
  exit 1
fi

ck_after=$(cksum "$tmp/exp/test_dry/submission.csv")
if [ "$ck_before" != "$ck_after" ]; then
  echo "overwrite guard failed: submission.csv changed"
  echo "before: $ck_before"
  echo "after:  $ck_after"
  exit 1
fi

echo "test_overhaul ok"
