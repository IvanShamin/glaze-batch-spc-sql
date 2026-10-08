"""Draw control charts from the SQL results exported by sql/05_export_results.sql.

Left column : individual SiO2 values with +/- 3 sigma limits
Right column: moving mean of 5 batches with +/- 3 sigma / sqrt(5) limits

All limits, moving means and alert flags come from the SQL views; this script only draws.

Usage (from the project root):
    python src/plot_control_charts.py
"""
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.lines import Line2D

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "output"

# colours: one data hue, neutral ink for reference lines, one status colour for alarms
SURFACE, GRID = "#fcfcfb", "#e1e0d9"
INK, INK_2, MUTED = "#0b0b0b", "#52514e", "#898781"
DATA, ALARM = "#2a78d6", "#d03b3b"


def style_axis(ax):
    ax.set_facecolor(SURFACE)
    ax.grid(axis="y", color=GRID, linewidth=0.6)
    ax.set_axisbelow(True)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color("#c3c2b7")
    ax.tick_params(colors=INK_2, labelsize=8)


def draw_panel(ax, df, value_col, lcl, ucl, center, alert_col, title, n_baseline):
    style_axis(ax)
    ax.axvspan(0.5, n_baseline + 0.5, color=GRID, alpha=0.55, linewidth=0)
    ax.axhline(center, color=MUTED, linewidth=1.0)
    for limit in (lcl, ucl):
        ax.axhline(limit, color=INK_2, linewidth=1.0, linestyle=(0, (4, 3)))
    ax.plot(df["batch_seq"], df[value_col], color=DATA, linewidth=0.9,
            marker="o", markersize=2.8, markeredgewidth=0)
    hit = df[df[alert_col]]
    ax.scatter(hit["batch_seq"], hit[value_col], s=34, marker="D", color=ALARM,
               edgecolor=SURFACE, linewidth=0.8, zorder=4)
    ax.set_title(title, loc="left", fontsize=9.5, color=INK, pad=6)
    ax.set_xlim(0.5, df["batch_seq"].max() + 0.5)


def main():
    series = pd.read_csv(OUT / "spc_series.csv")
    limits = pd.read_csv(OUT / "control_limits.csv").set_index("furnace_id")
    # PostgreSQL exports booleans as t / f
    for col in ("point_alert", "mean_alert", "is_baseline"):
        series[col] = series[col].astype(str).str.lower().isin(["t", "true"])

    furnaces = list(limits.index)
    fig, axes = plt.subplots(len(furnaces), 2, figsize=(13, 2.7 * len(furnaces)),
                             facecolor=SURFACE, sharex=True)
    for row, furnace in enumerate(furnaces):
        d = series[series["furnace_id"] == furnace]
        lim = limits.loc[furnace]
        n_base = int(lim["n_baseline"])
        draw_panel(axes[row, 0], d, "sio2_pct", lim["lcl_individual"], lim["ucl_individual"],
                   lim["center_line"], "point_alert",
                   f"{furnace} · {lim['frit_code']} · individual SiO2 (wt-%)", n_base)
        d5 = d[d["batch_seq"] >= 5]
        draw_panel(axes[row, 1], d5, "mean_5", lim["lcl_mean5"], lim["ucl_mean5"],
                   lim["center_line"], "mean_alert",
                   f"{furnace} · 5-batch moving mean SiO2 (wt-%)", n_base)
        axes[row, 1].set_xlim(0.5, d["batch_seq"].max() + 0.5)
    for ax in axes[-1]:
        ax.set_xlabel("Batch sequence within furnace", fontsize=9, color=INK_2)

    legend_items = [
        Line2D([0], [0], color=DATA, marker="o", markersize=4, linewidth=1, label="Measured / moving mean"),
        Line2D([0], [0], color=MUTED, linewidth=1, label="Centre line (baseline mean)"),
        Line2D([0], [0], color=INK_2, linewidth=1, linestyle=(0, (4, 3)), label="Control limits (UCL / LCL)"),
        Line2D([0], [0], color=ALARM, marker="D", markersize=6, linewidth=0, label="Out of control (alarm)"),
        plt.Rectangle((0, 0), 1, 1, color=GRID, alpha=0.8, label="Baseline period (limits estimated here)"),
    ]
    fig.legend(handles=legend_items, loc="upper center", ncol=5, frameon=False,
               fontsize=9, labelcolor=INK_2, bbox_to_anchor=(0.5, 0.995))
    fig.tight_layout(rect=(0, 0, 1, 0.96))
    target = OUT / "control_charts.png"
    fig.savefig(target, dpi=150, facecolor=SURFACE)
    print(f"saved {target}")


if __name__ == "__main__":
    main()
