# Desafio 4. Copia el estilo del notebook: ftirar() es sum(runif(qty) < prob).
# rbinom(1, qty, prob) cuenta lo mismo y alcanza para miles de pueblos.

set.seed(271211)

ftirar <- function(prob, qty) {
  sum(runif(qty) < prob)
}

c5_rondas <- c(68, 74, 78, 70, 68, 63, 80, 68, 67, 65)
stopifnot(sum(c5_rondas) == 701)

mus <- seq(0.40, 0.92, length.out = 521)
tiros <- 100
n_samp <- 20000

pmf_pueblo <- function(mus, tau, tiros = 100) {
  ks <- 0:tiros
  if (tau == 0) {
    return(t(sapply(mus, function(mu) dbinom(ks, tiros, mu))))
  }
  zs <- seq(-3.5, 3.5, length.out = 41)
  dz <- zs[2] - zs[1]
  w <- dnorm(zs) * dz
  w <- w / sum(w)
  out <- matrix(0, nrow = length(mus), ncol = tiros + 1)
  for (j in seq_along(zs)) {
    theta <- pmin(pmax(mus + tau * zs[j], 1e-4), 1 - 1e-4)
    out <- out + w[j] * t(sapply(theta, function(th) dbinom(ks, tiros, th)))
  }
  out
}

loglik_conteos <- function(pmf, exact, n_rest = 0, rest_max = NULL) {
  ll <- rep(0, nrow(pmf))
  for (k in names(exact)) {
    ll <- ll + exact[[k]] * log(pmax(pmf[, as.integer(k) + 1], 1e-300))
  }
  if (n_rest > 0) {
    p_rest <- rowSums(pmf[, seq_len(rest_max + 1), drop = FALSE])
    ll <- ll + n_rest * log(pmax(p_rest, 1e-300))
  }
  ll
}

loglik_maximo_unico <- function(pmf, n_jugadoras, score) {
  p_score <- pmax(pmf[, score + 1], 1e-300)
  p_abajo <- rowSums(pmf[, seq_len(score), drop = FALSE])
  log(n_jugadoras) + log(p_score) + (n_jugadoras - 1) * log(pmax(p_abajo, 1e-300))
}

pesos <- function(ll) {
  ll <- ll - max(ll)
  w <- exp(ll)
  w / sum(w)
}

sample_theta <- function(mu_draw, tau, score, n_tiros = 100) {
  if (tau == 0) {
    return(mu_draw)
  }
  zs <- seq(-3.5, 3.5, length.out = 81)
  theta <- pmin(pmax(outer(mu_draw, zs, function(m, z) m + tau * z), 1e-4), 1 - 1e-4)
  logw <- dbinom(score, n_tiros, theta, log = TRUE) +
    matrix(dnorm(zs, log = TRUE), nrow = length(mu_draw), ncol = length(zs), byrow = TRUE)
  logw <- logw - apply(logw, 1, max)
  w <- exp(logw)
  w <- w / rowSums(w)
  cdf <- t(apply(w, 1, cumsum))
  u <- runif(length(mu_draw))
  idx <- apply(cdf >= u, 1, function(fila) which(fila)[1])
  theta[cbind(seq_along(mu_draw), idx)]
}

ajustar <- function(tau, solo_maximo = FALSE, n_samp = 20000) {
  pmf <- pmf_pueblo(mus, tau, tiros)
  specs <- list(
    C1 = list(exact = c(`80` = 1, `79` = 2, `78` = 2), n = 100, rest_max = 77, score = 80),
    C2 = list(exact = c(`80` = 1, `79` = 6, `78` = 5), n = 200, rest_max = 77, score = 80),
    C4 = list(exact = c(`80` = 1, `75` = 1), n = 2, rest_max = NULL, score = 80),
    C6 = list(exact = c(`79` = 1), n = 1, rest_max = NULL, score = 79),
    C7 = list(exact = c(`79` = 1), n = 1, rest_max = NULL, score = 79)
  )
  info <- list()
  theta <- list()
  for (nombre in names(specs)) {
    sp <- specs[[nombre]]
    n_exact <- sum(sp$exact)
    n_rest <- if (is.null(sp$rest_max)) 0 else sp$n - n_exact
    if (solo_maximo && nombre %in% c("C1", "C2")) {
      ll <- loglik_maximo_unico(pmf, sp$n, sp$score)
    } else {
      ll <- loglik_conteos(pmf, sp$exact, n_rest, sp$rest_max)
    }
    w <- pesos(ll)
    mu_draw <- sample(mus, n_samp, replace = TRUE, prob = w)
    th <- sample_theta(mu_draw, tau, sp$score, tiros)
    theta[[nombre]] <- th
    info[[nombre]] <- mean(th)
  }
  ll5 <- dbinom(701, 1000, mus, log = TRUE)
  w5 <- pesos(ll5)
  theta$C5 <- sample(mus, n_samp, replace = TRUE, prob = w5)
  info$C5 <- mean(theta$C5)
  futuras <- lapply(theta, function(th) rbinom(length(th), tiros, th))
  list(info = info, futuras = futuras)
}

prob_menor <- function(futuras, a, b) {
  fa <- futuras[[a]]
  fb <- futuras[[b]]
  c(
    menor = mean(fa < fb),
    mayor = mean(fa > fb),
    empate = mean(fa == fb)
  )
}

relacion <- function(a, b, p) {
  if (p["menor"] > 0.5) {
    return(paste(a, "<", b))
  }
  if (p["mayor"] > 0.5) {
    return(paste(b, "<", a))
  }
  paste(a, "≈", b)
}

cadena <- function(info, futuras, nombres) {
  orden <- nombres[order(sapply(nombres, function(n) info[[n]]))]
  texto <- orden[1]
  detalle <- list()
  if (length(orden) >= 2) {
    for (i in seq_len(length(orden) - 1)) {
      a <- orden[i]
      b <- orden[i + 1]
      p <- prob_menor(futuras, a, b)
      rel <- relacion(a, b, p)
      if (rel == paste(a, "<", b)) {
        texto <- paste(texto, "<", b)
      } else if (rel == paste(b, "<", a)) {
        texto <- paste(texto, ">", b)
      } else {
        texto <- paste(texto, "≈", b)
      }
      detalle[[length(detalle) + 1]] <- list(a = a, b = b, rel = rel, p = p)
    }
  }
  list(texto = texto, detalle = detalle)
}

encestes <- function(info) {
  sapply(info, function(th) 100 * th)
}

cat("Corrida principal, tau = 0.02 (desvio del peloton de la seccion 2.3)\n")
principal <- ajustar(0.02, n_samp = n_samp)
e <- encestes(principal$info)
orden_nombres <- c("C5", "C1", "C2", "C4", "C6", "C7")
for (nombre in orden_nombres) {
  cat(sprintf("%s  E[encestes/100] = %.1f\n", nombre, e[[nombre]]))
}

cad <- cadena(principal$info, principal$futuras, orden_nombres)
cat("\nOrden:", cad$texto, "\n\n")
for (item in cad$detalle) {
  p <- item$p
  cat(sprintf(
    "%s   P(%s<%s)=%.3f   P(%s>%s)=%.3f   P(empate)=%.3f\n",
    item$rel, item$a, item$b, p["menor"], item$a, item$b, p["mayor"], p["empate"]
  ))
}

cat("\nSensibilidad\n")
sens <- list()
for (tau in c(0, 0.02, 0.05, 0.10)) {
  if (tau == 0.02) {
    info_tau <- principal$info
  } else {
    info_tau <- ajustar(tau, n_samp = 8000)$info
  }
  sens[[as.character(tau)]] <- encestes(info_tau)
  vals <- sapply(orden_nombres[c(1, 2, 3, 4, 5)], function(n) sens[[as.character(tau)]][[n]])
  cat(sprintf(
    "tau %.2f   C5 %.1f   C1 %.1f   C2 %.1f   C4 %.1f   C6 %.1f\n",
    tau, vals[1], vals[2], vals[3], vals[4], vals[5]
  ))
}

cat("\nSolo el maximo unico = 80\n")
solo_max <- ajustar(0.02, solo_maximo = TRUE, n_samp = 8000)
e_max <- encestes(solo_max$info)
p_max <- prob_menor(solo_max$futuras, "C2", "C1")
cat(sprintf(
  "C1 %.1f   C2 %.1f   %s   P(C2<C1)=%.3f\n",
  e_max[["C1"]], e_max[["C2"]], relacion("C2", "C1", p_max), p_max["menor"]
))

p12 <- prob_menor(principal$futuras, "C1", "C2")
p24 <- prob_menor(principal$futuras, "C2", "C4")

lineas <- c(
  paste("Orden:", cad$texto),
  "",
  "C3 no presenta candidata.",
  "",
  "Valor esperado de encestes en 100 tiros nuevos, no el puntaje del pueblo:",
  sprintf("C5: %.1f", e[["C5"]]),
  sprintf("C1: %.1f", e[["C1"]]),
  sprintf("C2: %.1f", e[["C2"]]),
  sprintf("C4: %.1f", e[["C4"]]),
  sprintf("C6: %.1f", e[["C6"]]),
  sprintf("C7: %.1f", e[["C7"]]),
  "",
  "Ci < Cj solo si, tirando 100 veces cada una, Ci encesta menos que Cj más de la mitad de las veces.",
  "Comparaciones de esta corrida, de menor a mayor valor esperado:"
)
for (item in cad$detalle) {
  p <- item$p
  lineas <- c(lineas, sprintf(
    "%s   P(%s<%s)=%.3f   P(%s>%s)=%.3f   P(empate)=%.3f",
    item$rel, item$a, item$b, p["menor"], item$a, item$b, p["mayor"], p["empate"]
  ))
}
lineas <- c(
  lineas,
  "",
  sprintf(
    "C5 tiene las 10 rondas: %d encestes en 1000 tiros. En la ronda nueva se esperan %.1f. El 80 que iba a mostrar es una de esas rondas, la mejor, no el índice.",
    sum(c5_rondas), e[["C5"]]
  ),
  sprintf(
    "C1 y C2 también mostraron 80, pero era el máximo de 100 y de 200, con varias en 78 y 79. El valor esperado queda en %.1f y %.1f. Entre ellas la corrida da P(C1<C2)=%.3f, así que no se ordenan: C2 comparó más gente, y a la vez había más jugadoras en 79.",
    e[["C1"]], e[["C2"]], p12["menor"]
  ),
  sprintf(
    "Si se deja de lado esa cola y solo se usa que el máximo único fue 80, ahí la corrida separa: C2 %.1f y C1 %.1f, P(C2<C1)=%.3f.",
    e_max[["C2"]], e_max[["C1"]], p_max["menor"]
  ),
  sprintf(
    "C4 son dos jugadoras, 80 contra 75. Esperado %.1f. C6 eligió el número 43 antes de ver los tiros y C7 testeó sola a la del paraje: las dos tienen 79/100 sin sesgo de haber ganado el torneo, esperado %.1f y %.1f.",
    e[["C4"]], e[["C6"]], e[["C7"]]
  ),
  sprintf(
    "El corte neto de esta corrida es entre {C5, C1, C2} y {C4, C6, C7}: P(C2<C4)=%.3f.",
    p24["menor"]
  ),
  "",
  "Misma cuenta cambiando qué tan distintas son las jugadoras de un pueblo (encestes esperados):",
  "tau    C5    C1    C2    C4    C6"
)
for (tau in c(0, 0.02, 0.05, 0.10)) {
  s <- sens[[as.character(tau)]]
  lineas <- c(lineas, sprintf(
    "%.2f  %5.1f %5.1f %5.1f %5.1f %5.1f",
    tau, s[["C5"]], s[["C1"]], s[["C2"]], s[["C4"]], s[["C6"]]
  ))
}
lineas <- c(
  lineas,
  "",
  "El orden de arriba usa tau = 0.02, el desvío del pelotón normal del notebook.",
  "Código: el mismo ftirar del notebook (un tiro entra si runif < índice). La cuenta usa rbinom, que es esa suma hecha de una vez.",
  "Notebook: https://github.com/stdevMac/labo2026ba/blob/main/CazaTalentos/CazaTalentos_colab.ipynb"
)

cat("\n")
cat(strrep("=", 24), "PEGAR EN ZULIP", strrep("=", 24), "\n", sep = "")
cat(paste(lineas, collapse = "\n"), "\n")
cat(strrep("=", 64), "\n", sep = "")
