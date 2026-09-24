"""Ordena las candidatas del desafio CazaTalentos.

En cada pueblo las jugadoras tienen indices parecidos:
    θ_i ~ Normal(μ_pueblo, τ²), truncada a (0, 1).
μ_pueblo es desconocido, con prior uniforme en [0.40, 0.92].
El escenario principal usa τ = 0.02, el desvio del peloton normal
de la seccion 2.3 del notebook.

La entrenadora no se queda con el puntaje del torneo. Predice una
ronda nueva de 100 tiros de la candidata que cada cazatalentos presenta.
Ci < Cj solo si P(encestes_i < encestes_j) > 0.5.
"""

from __future__ import annotations

from math import lgamma

import numpy as np

N_TIROS = 100
MUS = np.linspace(0.40, 0.92, 521)
C5_RONDAS = (68, 74, 78, 70, 68, 63, 80, 68, 67, 65)
# Cola superior contada por cada cazatalentos. El resto encesto menos.
TORNEOS = {
    "C1": {"n": 100, "exact": {80: 1, 79: 2, 78: 2}, "rest_max": 77, "score": 80},
    "C2": {"n": 200, "exact": {80: 1, 79: 6, 78: 5}, "rest_max": 77, "score": 80},
    "C4": {"n": 2, "exact": {80: 1, 75: 1}, "rest_max": None, "score": 80},
    "C6": {"n": 1, "exact": {79: 1}, "rest_max": None, "score": 79},
    "C7": {"n": 1, "exact": {79: 1}, "rest_max": None, "score": 79},
}


def _log_choose(n: int) -> np.ndarray:
    ks = np.arange(0, n + 1)
    return np.array([lgamma(n + 1) - lgamma(int(k) + 1) - lgamma(n - int(k) + 1) for k in ks])


def binom_pmf_grid(theta: np.ndarray, n: int) -> np.ndarray:
    """P(X=k | θ). theta tiene forma (...). Devuelve (..., n+1)."""
    ks = np.arange(0, n + 1)
    th = np.clip(theta, 1e-6, 1.0 - 1e-6)
    log_pmf = _log_choose(n) + ks * np.log(th)[..., None] + (n - ks) * np.log(1.0 - th)[..., None]
    log_pmf -= log_pmf.max(axis=-1, keepdims=True)
    pmf = np.exp(log_pmf)
    pmf /= pmf.sum(axis=-1, keepdims=True)
    return pmf


def marginal_score_pmf(mus: np.ndarray, tau: float, n: int = N_TIROS, nz: int = 61) -> np.ndarray:
    """P(X=k | μ), integrando θ ~ Normal(μ, τ²)."""
    if tau == 0:
        return binom_pmf_grid(mus, n)
    zs = np.linspace(-3.5, 3.5, nz)
    dz = zs[1] - zs[0]
    w = np.exp(-0.5 * zs**2) * dz
    w /= w.sum()
    out = np.zeros((len(mus), n + 1))
    for i in range(0, len(mus), 40):
        mu = mus[i : i + 40]
        theta = np.clip(mu[:, None] + tau * zs[None, :], 1e-4, 1.0 - 1e-4)
        out[i : i + 40] = (binom_pmf_grid(theta, n) * w[None, :, None]).sum(axis=1)
    return out


def _weights(loglik: np.ndarray) -> np.ndarray:
    loglik = loglik - np.max(loglik)
    w = np.exp(loglik)
    return w / w.sum()


def loglik_con_resto(pmf: np.ndarray, exact: dict[int, int], n_rest: int, rest_max: int | None) -> np.ndarray:
    ll = np.zeros(pmf.shape[0])
    for score, count in exact.items():
        ll += count * np.log(np.clip(pmf[:, score], 1e-300, None))
    if n_rest:
        p_rest = np.clip(pmf[:, : rest_max + 1].sum(axis=1), 1e-300, None)
        ll += n_rest * np.log(p_rest)
    return ll


def loglik_maximo_unico(pmf: np.ndarray, n_players: int, score: int) -> np.ndarray:
    """Solo se sabe que el maximo unico fue `score`. Ignora el resto del relato."""
    p_score = np.clip(pmf[:, score], 1e-300, None)
    p_below = np.clip(pmf[:, :score].sum(axis=1), 1e-300, None)
    return np.log(n_players) + np.log(p_score) + (n_players - 1) * np.log(p_below)


def sample_theta(mus, w_mu, tau, score, n_samp, rng, n=N_TIROS) -> np.ndarray:
    """Muestra θ de la candidata que hizo `score` tiros, dado el posterior de μ."""
    mu = mus[rng.choice(len(mus), size=n_samp, p=w_mu)]
    if tau == 0 or n != N_TIROS:
        # τ = 0: todas valen μ. n != 100: C5, una sola θ estimada directo.
        return mu
    zs = np.linspace(-3.5, 3.5, 81)
    dz = zs[1] - zs[0]
    base = np.exp(-0.5 * zs**2) * dz
    theta = np.clip(mu[:, None] + tau * zs[None, :], 1e-4, 1.0 - 1e-4)
    logw = score * np.log(theta) + (n - score) * np.log(1.0 - theta) + np.log(base)
    logw -= logw.max(axis=1, keepdims=True)
    w = np.exp(logw)
    w /= w.sum(axis=1, keepdims=True)
    cdf = np.cumsum(w, axis=1)
    z_idx = np.clip((rng.random(n_samp)[:, None] > cdf).sum(axis=1), 0, theta.shape[1] - 1)
    return theta[np.arange(n_samp), z_idx]


def _resumen_mu(mus: np.ndarray, w: np.ndarray) -> tuple[float, float, float]:
    media = float((w * mus).sum())
    cdf = np.cumsum(w)
    lo = float(mus[min(int(np.searchsorted(cdf, 0.025)), len(mus) - 1)])
    hi = float(mus[min(int(np.searchsorted(cdf, 0.975)), len(mus) - 1)])
    return media, lo, hi


def ajustar(tau: float = 0.02, n_samp: int = 40000, seed: int = 102191, solo_maximo: bool = False):
    """Posterior de cada candidata y tiros de una ronda nueva."""
    rng = np.random.default_rng(seed)
    pmf = marginal_score_pmf(MUS, tau)
    draws = {}
    info = {}

    for name, spec in TORNEOS.items():
        n_exact = sum(spec["exact"].values())
        n_rest = 0 if spec["rest_max"] is None else spec["n"] - n_exact
        if solo_maximo and name in ("C1", "C2"):
            ll = loglik_maximo_unico(pmf, spec["n"], spec["score"])
        else:
            ll = loglik_con_resto(pmf, spec["exact"], n_rest, spec["rest_max"])
        w = _weights(ll)
        theta = sample_theta(MUS, w, tau, spec["score"], n_samp, rng)
        draws[name] = theta
        e_mu, lo, hi = _resumen_mu(MUS, w)
        info[name] = {
            "e_theta": float(theta.mean()),
            "e_encestes": float(100 * theta.mean()),
            "mu_lo": lo,
            "mu_hi": hi,
            "e_mu": e_mu,
        }

    # C5: 701 aciertos en 1000 tiros. Una jugadora, sin pueblo alrededor.
    ll5 = 701 * np.log(np.clip(MUS, 1e-6, None)) + 299 * np.log(np.clip(1.0 - MUS, 1e-6, None))
    w5 = _weights(ll5)
    theta5 = sample_theta(MUS, w5, 0.0, 701, n_samp, rng, n=1000)
    draws["C5"] = theta5
    e_mu, lo, hi = _resumen_mu(MUS, w5)
    info["C5"] = {
        "e_theta": float(theta5.mean()),
        "e_encestes": float(100 * theta5.mean()),
        "mu_lo": lo,
        "mu_hi": hi,
        "e_mu": e_mu,
    }

    futuras = {
        name: rng.binomial(N_TIROS, np.clip(theta, 1e-4, 1.0 - 1e-4))
        for name, theta in draws.items()
    }
    return info, futuras


def prob_menor(futuras: dict[str, np.ndarray], a: str, b: str) -> tuple[float, float, float]:
    fa, fb = futuras[a], futuras[b]
    return float(np.mean(fa < fb)), float(np.mean(fa > fb)), float(np.mean(fa == fb))


def relacion(a: str, b: str, p_menor: float, p_mayor: float) -> str:
    if p_menor > 0.5:
        return f"{a} < {b}"
    if p_mayor > 0.5:
        return f"{b} < {a}"
    return f"{a} ≈ {b}"


def _cadena(info, futuras, nombres: list[str]) -> tuple[str, list[tuple]]:
    orden = sorted(nombres, key=lambda nombre: info[nombre]["e_encestes"])
    detalle = []
    texto = orden[0]
    for a, b in zip(orden, orden[1:]):
        p_lt, p_gt, p_eq = prob_menor(futuras, a, b)
        rel = relacion(a, b, p_lt, p_gt)
        if rel == f"{a} < {b}":
            texto += f" < {b}"
        elif rel == f"{b} < {a}":
            texto += f" > {b}"
        else:
            texto += f" ≈ {b}"
        detalle.append((a, b, rel, p_lt, p_gt, p_eq))
    return texto, detalle


def mensaje_zulip(info, futuras, sensibilidad, info_max, fut_max) -> str:
    """Arma el post de Zulip con los numeros de esta corrida."""
    nombres = ["C5", "C1", "C2", "C4", "C6", "C7"]
    orden_txt, detalle = _cadena(info, futuras, nombres)
    p_c2_c1, _, _ = prob_menor(fut_max, "C2", "C1")
    p_bajo_alto, _, _ = prob_menor(futuras, "C2", "C4")

    lineas = [
        f"Orden: {orden_txt}",
        "",
        "C3 no presenta candidata.",
        "",
        "Valor esperado de encestes en 100 tiros nuevos, no el puntaje del pueblo:",
    ]
    for nombre in ("C5", "C1", "C2", "C4", "C6", "C7"):
        lineas.append(f"{nombre}: {info[nombre]['e_encestes']:.1f}")

    lineas += [
        "",
        "Ci < Cj solo si, tirando 100 veces cada una, Ci encesta menos que Cj más de la mitad de las veces.",
        "Comparaciones de esta corrida, de menor a mayor valor esperado:",
    ]
    for a, b, rel, p_lt, p_gt, p_eq in detalle:
        lineas.append(
            f"{rel}   P({a}<{b})={p_lt:.3f}   P({a}>{b})={p_gt:.3f}   P(empate)={p_eq:.3f}"
        )

    e = {nombre: info[nombre]["e_encestes"] for nombre in nombres}
    emax = {nombre: info_max[nombre]["e_encestes"] for nombre in ("C1", "C2")}
    lineas += [
        "",
        (
            f"C5 tiene las 10 rondas: {sum(C5_RONDAS)} encestes en 1000 tiros. "
            f"En la ronda nueva se esperan {e['C5']:.1f}. "
            "El 80 que iba a mostrar es una de esas rondas, la mejor, no el índice."
        ),
        (
            f"C1 y C2 también mostraron 80, pero era el máximo de 100 y de 200, "
            f"con varias en 78 y 79. El valor esperado queda en {e['C1']:.1f} y {e['C2']:.1f}. "
            f"Entre ellas la corrida da P(C1<C2)={prob_menor(futuras, 'C1', 'C2')[0]:.3f}, "
            "así que no se ordenan: C2 comparó más gente, y a la vez había más jugadoras en 79."
        ),
        (
            "Si se deja de lado esa cola y solo se usa que el máximo único fue 80, "
            f"ahí la corrida separa: C2 {emax['C2']:.1f} y C1 {emax['C1']:.1f}, "
            f"P(C2<C1)={p_c2_c1:.3f}."
        ),
        (
            f"C4 son dos jugadoras, 80 contra 75. Esperado {e['C4']:.1f}. "
            f"C6 eligió el número 43 antes de ver los tiros y C7 testeó sola a la del paraje: "
            f"las dos tienen 79/100 sin sesgo de haber ganado el torneo, esperado {e['C6']:.1f} y {e['C7']:.1f}."
        ),
        (
            f"El corte neto de esta corrida es entre {{C5, C1, C2}} y {{C4, C6, C7}}: "
            f"P(C2<C4)={p_bajo_alto:.3f}."
        ),
        "",
        "Misma cuenta cambiando qué tan distintas son las jugadoras de un pueblo (encestes esperados):",
        "tau     C5     C1     C2     C4   C6=C7",
    ]
    for tau, info_tau in sensibilidad:
        vals = [info_tau[n]["e_encestes"] for n in ("C5", "C1", "C2", "C4", "C6")]
        lineas.append(f"{tau:4.2f} " + " ".join(f"{v:6.1f}" for v in vals))
    lineas += [
        "",
        "El orden de arriba usa tau = 0.02, el desvío del pelotón normal del notebook.",
        "Notebook: CazaTalentos/CazaTalentos_colab.ipynb",
    ]
    return "\n".join(lineas)


def main() -> None:
    assert sum(C5_RONDAS) == 701
    print("C5 sumo", sum(C5_RONDAS), "encestes en 1000 tiros.")
    print("Ci < Cj solo si P(encestes i < encestes j | 100 tiros) > 0.5")
    print("Escenario principal: τ = 0.02 (desvio del peloton de la seccion 2.3).")
    print()

    info, futuras = ajustar(tau=0.02, n_samp=80000)
    orden = sorted(info, key=lambda nombre: info[nombre]["e_encestes"])
    print(f"{'':4} {'E[θ]':>8} {'E[enc/100]':>10} {'μ pueblo, 95%':>22}")
    for nombre in ("C5", "C1", "C2", "C4", "C6", "C7"):
        f = info[nombre]
        print(
            f"{nombre:4} {f['e_theta']:8.4f} {f['e_encestes']:10.2f} "
            f"  [{f['mu_lo']:.3f}, {f['mu_hi']:.3f}]"
        )

    print()
    print("Cadena, de menor a mayor valor esperado:")
    for a, b in zip(orden, orden[1:]):
        p_lt, p_gt, p_eq = prob_menor(futuras, a, b)
        print(
            f"  {relacion(a, b, p_lt, p_gt):12}  "
            f"P({a}<{b})={p_lt:.3f}  P({a}>{b})={p_gt:.3f}  P(=)={p_eq:.3f}"
        )

    print()
    print("P(fila encesta MENOS que columna). >0.5 significa fila < columna.")
    nombres = ["C5", "C1", "C2", "C4", "C6", "C7"]
    print("     " + " ".join(f"{n:>7}" for n in nombres))
    for a in nombres:
        celdas = []
        for b in nombres:
            if a == b:
                celdas.append(f"{'—':>7}")
            else:
                p_lt, _, _ = prob_menor(futuras, a, b)
                celdas.append(f"{p_lt:7.3f}")
        print(f"{a:>4} " + " ".join(celdas))

    print()
    print("Sensibilidad a qué tan distintas son las jugadoras del mismo pueblo.")
    print(f"{'τ':>6} {'C5':>7} {'C1':>7} {'C2':>7} {'C4':>7} {'C6=C7':>7}")
    sensibilidad = []
    for tau in (0.0, 0.02, 0.05, 0.10):
        if tau == 0.02:
            info_tau = info
        else:
            info_tau, _ = ajustar(tau=tau, n_samp=20000, seed=102191 + int(1000 * tau))
        sensibilidad.append((tau, info_tau))
        vals = [info_tau[n]["e_encestes"] for n in ("C5", "C1", "C2", "C4", "C6")]
        print(f"{tau:6.2f} " + " ".join(f"{v:7.2f}" for v in vals))

    print()
    print("Si solo se usa que el maximo unico fue 80 (se tiran 'seis en 79', etc.):")
    info_max, fut_max = ajustar(tau=0.02, n_samp=40000, seed=7, solo_maximo=True)
    p_lt, p_gt, _ = prob_menor(fut_max, "C2", "C1")
    print(
        f"  E[encestes] C1={info_max['C1']['e_encestes']:.2f}  "
        f"C2={info_max['C2']['e_encestes']:.2f}  "
        f"{relacion('C2', 'C1', p_lt, p_gt)}  "
        f"P(C2<C1)={p_lt:.3f}"
    )

    print()
    print("=" * 24 + " PEGAR EN ZULIP " + "=" * 24)
    print(mensaje_zulip(info, futuras, sensibilidad, info_max, fut_max))
    print("=" * 64)


if __name__ == "__main__":
    main()
