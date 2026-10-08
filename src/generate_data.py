"""Generate a synthetic dataset of frit batch analyses from four melting furnaces.

All values are simulated (fixed random seed, fully reproducible). No real plant data
is used. Each furnace runs one frit "campaign"; the measured oxide contents scatter
around a campaign target. Four process scenarios are injected on purpose so that the
SPC rules have something to find:

    Furnace A  stable process (control case, should stay quiet)
    Furnace B  slow upward drift of SiO2 after batch 70 (e.g. a quartz sand lot with a
               gradually changing grain/purity profile)
    Furnace C  three isolated spikes (sampling / contamination errors)
    Furnace D  step change of ~+1.1 % SiO2 from batch 85 (raw-material lot change)

Usage:
    python src/generate_data.py            # writes data/frit_batches.csv
"""
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 2026
N_BATCHES = 125          # batches per furnace
HOURS_BETWEEN_BATCHES = 8
START = pd.Timestamp("2026-03-02 06:00")

# target mean and process standard deviation per furnace / frit campaign (oxide wt-%)
CAMPAIGNS = {
    "Furnace-A": dict(frit="FR-A101", sio2=(57.5, 0.45), al2o3=(7.0, 0.18), zro2=(0.02, 0.01), loi=(0.15, 0.05)),
    "Furnace-B": dict(frit="FR-B205", sio2=(61.0, 0.50), al2o3=(11.0, 0.22), zro2=(3.5, 0.10), loi=(0.20, 0.05)),
    "Furnace-C": dict(frit="FR-C310", sio2=(52.0, 0.40), al2o3=(5.5, 0.15), zro2=(8.0, 0.15), loi=(0.10, 0.04)),
    "Furnace-D": dict(frit="FR-D412", sio2=(64.5, 0.55), al2o3=(9.0, 0.20), zro2=(0.5, 0.05), loi=(0.25, 0.06)),
}


def build() -> pd.DataFrame:
    rng = np.random.default_rng(SEED)
    frames = []
    for k, (furnace, c) in enumerate(CAMPAIGNS.items()):
        seq = np.arange(1, N_BATCHES + 1)
        jitter = rng.integers(-40, 41, size=N_BATCHES)  # minutes
        produced_at = (
            START
            + pd.to_timedelta(seq * HOURS_BETWEEN_BATCHES, unit="h")
            + pd.to_timedelta(jitter, unit="m")
            + pd.to_timedelta(k * 70, unit="m")
        )
        mu, sd = c["sio2"]
        sio2 = rng.normal(mu, sd, N_BATCHES)

        # --- injected scenarios (SiO2 only) -------------------------------------
        if furnace == "Furnace-B":                       # linear drift after batch 70
            sio2 += np.clip(seq - 70, 0, None) * 0.03
        if furnace == "Furnace-C":                       # isolated spikes
            for idx, shift in ((52, +4.2), (77, -4.0), (101, +3.8)):
                sio2[idx - 1] += shift * sd
        if furnace == "Furnace-D":                       # step change from batch 85
            sio2 += np.where(seq >= 85, 1.1, 0.0)

        df = pd.DataFrame(
            {
                "batch_id": [f"{furnace[-1]}-{n:04d}" for n in seq],
                "furnace_id": furnace,
                "frit_code": c["frit"],
                "produced_at": produced_at,
                "sio2_pct": sio2,
                "al2o3_pct": rng.normal(*c["al2o3"], N_BATCHES),
                "zro2_pct": np.clip(rng.normal(*c["zro2"], N_BATCHES), 0, None),
                "loi_pct": np.clip(rng.normal(*c["loi"], N_BATCHES), 0, None),
            }
        )
        frames.append(df)

    out = pd.concat(frames, ignore_index=True)
    for col in ("sio2_pct", "al2o3_pct", "zro2_pct", "loi_pct"):
        out[col] = out[col].round(2)
    return out.sort_values(["produced_at", "furnace_id"]).reset_index(drop=True)


if __name__ == "__main__":
    target = Path(__file__).resolve().parent.parent / "data" / "frit_batches.csv"
    target.parent.mkdir(parents=True, exist_ok=True)
    data = build()
    data.to_csv(target, index=False, date_format="%Y-%m-%d %H:%M:%S")
    print(f"{len(data)} rows written to {target}")
