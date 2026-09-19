# Spec: fixes quirúrgicos para la cátedra

Fecha: 2026-09-02  
Repo destino del PR: `labo-imp/labo2026ba`  
Branch: `fix/catedra-bugs` desde `origin/main` (`d67db05`, idéntico a `upstream/main`)

## Problema

El material de Laboratorio de Implementación I (Austral 2026 BA) tiene errores reales de corrección, intros copiadas al capítulo equivocado, snippets rotos y typos que cambian el sentido. No es un rewrite: es un PR que un estudiante puede mandar sin pelearse con la pedagogía.

## Objetivo

Un PR chico, revisable, que deja los 3 archivos de la cátedra correctos. Encima de ese branch se hace el overhaul local (spec aparte). Si `labo-imp` no mergea, igual se mergea a `main` local y se sigue.

## Fuera de alcance

- Hiperparámetros distintos entre `z101` y `z102`
- El árbol de un solo nodo, Hackeando Kaggle, switch Python → R de Colab
- Paths `/content/...` y `~/buckets/b1`
- `.gitignore`, README, Makefile, extraer scripts, celda de entorno local
- Reescribir prosa, unificar estilo, acentos menores que no confunden (`autentico`, `optimos` si no están en la lista)
- Comentarios nuevos. Solo se corrige el comentario que miente
- `arboles/z101_PrimerModelo.R` no se toca (`Predicted` ya es numérico)

## Git

1. Branch `fix/catedra-bugs` desde `origin/main`, **no** desde un commit que tenga `docs/superpowers/` ni el overhaul.
2. Uno o dos commits. Si hay dos: (1) corrección de código (2) typos / intros.
3. PR: `stdevMac/labo2026ba:fix/catedra-bugs` → `labo-imp/labo2026ba` (default branch del upstream).
4. Mergear ese branch a `main` local. El overhaul va arriba.
5. Este spec **no** entra en el PR.

## Inventario

### `arboles/z102_FinalTrain.ipynb`

| Qué | Cambio |
|---|---|
| `Predicted := prob > (1/40)` | `Predicted := as.numeric(prob > (1/40))` |
| `simplificaciónes` | `simplificaciones` |
| `libería` | `librería` |
| `busqueda búsqueda` | `búsqueda` |
| `Noy hay` | `No hay` |
| `utlizando` | `utilizando` |
| `limitacinoes` | `limitaciones` |
| `Change Runtime Tipe` (2 veces) | `Change Runtime Type` |
| `predccion` | `prediccion` |
| `estension .csv` | `extension .csv` |
| `este el el comando` | `este es el comando` |

### `zero2hero/zero2hero_01.ipynb`

**Código**

1. `GananciaArbol` aparece 3 veces (secciones 1.12, 1.14, 1.15). Hoy:

   ```r
   train_rows <- createDataPartition(dataset$clase_ternaria, p = 0.70, list = FALSE)
   ```

   Debe ser:

   ```r
   train_rows <- createDataPartition(data$clase_ternaria, p = train, list = FALSE)
   ```

   En 1.12 **no** se agrega normalización: ese capítulo muestra ganancia cruda.

   En 1.14 y 1.15, reemplazar `ganancia_testing / 0.3` por `ganancia_testing / (1 - train)`.

2. `ArbolMontecarlo` (1.15) hoy itera `ksemillas` (global) y llama `GananciaArbol(..., dataset, train = 0.70)`. Debe usar los argumentos:

   ```r
   ArbolMontecarlo <- function(semillas, data, x, train = 0.70) {
     vector_ganancias <- c()
     for (semilla in semillas) {
       ganancia <- GananciaArbol(semilla, data, x = x, train = train)
       vector_ganancias <- c(vector_ganancias, ganancia)
     }
     return(mean(vector_ganancias))
   }
   ```

   La llamada posterior pasa `ksemillas` como primer argumento (ya existe).

3. Sección 1.08: el `setwd` ya está en `/content/buckets/b1/exp/ZH2018/`. Borrar las dos líneas `dir.create("./exp/...")`. Dejar el `fwrite` a `para_Kaggle_0108.csv` (cae en `ZH2018`).

4. Celda markdown con `modelo < -rpart` y `dataset1`: el snippet tiene que coincidir con la celda de código siguiente (`modelo <- rpart(...)`, `data = dataset[foto_mes == 202107]`, `cp = -1`, `maxdepth = 3`).

5. Celda de código vacía (después de 1.13, antes de 1.14): eliminarla.

6. `library("rpart") # cargo la libreria  data.table` (todas las copias) → `# cargo la libreria  rpart`.

**Intro 1.05**

Hoy copia el objetivo de 1.04 (colineales, normalización, log, outliers). Reemplazar por:

```
Hasta ahora el data.table se leía de un archivo. Acá se arma uno a partir de dos vectores de igual longitud, y se lo graba con fwrite.
```

No reescribir el resto del capítulo.

**Typos** (reemplazo literal, no reescribir la oración):

| De | A |
|---|---|
| `Change Runtime Tipe` | `Change Runtime Type` |
| `fucion` | `funcion` |
| `becnmarks` | `benchmarks` |
| `bibligrafía` | `bibliografía` |
| `poscion` | `posicion` |
| `simplisima` | `simplísima` |
| `de0la libreria` | `de la libreria` |
| `un albol de profundidad` | `un arbol de profundidad` |
| `Disgresión` | `Digresión` |
| `objtetos` | `objetos` |
| `garbaje collection` | `garbage collection` |
| `limpie bore todos` | `limpie y borre todos` |
| `<bv>` | `<br>` (2 veces) |
| `numero_de_clente` | `numero_de_cliente` |
| `lsita` | `lista` |
| `caracters` | `caracteres` |
| `exista el tipo` | `existe el tipo` |
| `qyuedó` | `quedó` |
| `probabildades` | `probabilidades` (2 veces) |
| `se obseva` | `se observa` |
| `**data.table` (cierre de bold faltante, 1.05) | `**data.table**` |
| `entrega_de juguete.txt` | `entrega_de_juguete.csv` |

Título `## 1.04 Transformado (innecesariamente) las variables`: no se toca (es pedagogía).

## Cómo editar notebooks

- Editar las celdas, no regenerar el `.ipynb`.
- No ejecutar (no meter outputs).
- JSON válido (`nbformat` 4).
- No agregar celdas salvo que una corrección lo exija (no debería).
- No cambiar `id` de celdas ni metadata de Colab.

## Verificación

- `python3 -c "import json; json.load(open('arboles/z102_FinalTrain.ipynb')); json.load(open('zero2hero/zero2hero_01.ipynb'))"`
- Grep: no quedan `Noy hay`, `Runtime Tipe`, `dataset$clase_ternaria, p = 0.70`, `modelo < -rpart`, `Predicted := prob >`.
- Diff contra `origin/main`: solo esos dos notebooks.
- No se corre el modelo (no hay dataset en el repo).

## Criterio de hecho

El PR se puede abrir. Un revisor de la cátedra ve correcciones, no un fork con otra arquitectura.
