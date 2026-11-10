# Visual Decision Analytics Guide

This guide details the scientific visualisation and graphic decision analytics implemented in **DoECISORY.jl** via `Lib_Arts` and PlotlyJS. 

Visual analytics in DoECISORY.jl serve a dual purpose: enabling laboratory researchers to interactively explore multidimensional response landscapes in the browser interface, and generating publication-grade vector graphics for peer-reviewed academic manuscripts.

---

## 1. Visual Standards & Design System

All graphic routines in DoECISORY.jl adhere to strict biostatistical visual standards:

* **Scientific Colour Mapping (Viridis Palette):** 
  Response surfaces, contour gradients, and 3D heatmaps natively use the **Viridis** colour scale. Viridis offers three vital properties for peer-reviewed literature:
  1. *Perceptual Uniformity:* Equal steps in numerical data correspond to equal steps in perceived brightness, preventing artificial visual banding or pseudo-features.
  2. *Accessibility:* Remains fully legible for individuals with red-green (deuteranopia, protanopia) or blue-yellow (tritanopia) colour vision deficiencies.
  3. *Monochrome Reproduction:* Converts smoothly to linear greyscale when printed in black-and-white journals without loss of topographic depth.
* **Typographic Hierarchy & Contrast:** Minimalist grid layouts, zero-offset axis lines, and high-contrast marker symbology designed for clarity at manuscript column widths ($85\,\text{mm}$ single column or $175\,\text{mm}$ double column).
* **Dual Rendering Targets:**
  * *Interactive Web Client (`Gui_Lens`):* High frame-rate WebGL surface meshes with 6-degrees-of-freedom camera rotation, slice sliders, and contextual hover tooltips.
  * *Scripted Vector Export (`PlotlyJS.savefig`):* Lossless vector export (`.svg`, `.pdf`) and high-resolution raster export (`.png` at $\ge 300\,\text{DPI}$).

---

## 2. Response Surface Topography & 3-Factor Slicing

Polynomial response models capture complex non-linear curvatures, but human visual perception is inherently constrained to three spatial dimensions (two input factors against one output response).

```
   Factor X2 (Time)
       ▲
       │        ┌───────────────────────────────┐
  Max  │        │   Contour Projection (2D)     │
       │        │   High conversion plateau     │
  Mid  │        │   [Equipotential isoclines]   │
       │        │                               │
  Min  │        └───────────────────────────────┘
       └──────────────────────────────────────────► Factor X1 (Temperature)
               Min            Mid            Max
                               ▲
                               │ [Pin Factor X3 (Precursor) via Slicing]
```

### 2.1. 3D Response Surfaces (`ARTS_RenderSurface_DDEF`)
The 3D response surface visualises the predicted mathematical manifold $\hat{y} = f(x_1, x_2)$ across the active design space.

```julia
using DoECISORY, PlotlyJS

# Renders a 3D response surface for Yield across Temperature (X1) and Time (X2)
# X: Physical factor matrix (N x 3), Idx: active factor indices [1, 2]
fig_surface = ARTS_RenderSurface_DDEF(
    model_yield, 
    X,
    [1, 2],
    ["Temperature (°C)", "Time (min)", "Precursor (mg)"],
    "Radiochemical Yield (%)"
)
```

**Diagnostic Interpretation:**
* **Global Peak / Dome:** Signifies a well-behaved quadratic maximum lying within the search domain.
* **Ridge / Rising Ridge:** Indicates that factors act cooperatively; the true physical summit may reside outside current boundaries, signaling the need for sequential translation (ACTA).
* **Saddle Point (Minimax):** Represents antagonistic cross-term interaction ($x_1 x_2$), where moving in one direction increases response while moving orthogonally decreases it.

### 2.2. 2D Equipotential Contour Projections (`ARTS_RenderContour_DDEF`)
Contour maps project the 3D surface onto a 2D plane, displaying lines of constant response (isoclines).

```julia
fig_contour = ARTS_RenderContour_DDEF(
    model_yield, 
    X,
    [1, 2],
    ["Temperature (°C)", "Time (min)", "Precursor (mg)"],
    "Radiochemical Yield (%)"
)
```

**Diagnostic Interpretation:**
* Elliptical contours indicate strong synergistic or antagonistic two-factor interaction terms ($\beta_{ij} x_i x_j$).
* Circular or concentric contours indicate independent linear and pure quadratic contributions without significant cross-product distortion.

### 2.3. Orthogonal 3-Factor Slicing (`ARTS_RenderSlice_DDEF`)
To systematically explore the full 3-factor volume without loss of information, `ARTS_RenderSlice_DDEF` evaluates cross-sectional slices across the third factor:

```julia
# Evaluates 2D cross-sectional slice across factors 1 and 2 pinned at nominal setting
fig_slices = ARTS_RenderSlice_DDEF(
    model_yield, 
    X,
    [1, 2],
    ["Temperature", "Time", "Precursor"],
    "Yield (%)"
)
```

In the **Lens** web interface, this slicing is controlled interactively via the **Factor Slice Slider**, allowing researchers to glide smoothly along the third dimension and observe the expansion or contraction of the optimal zone.

---

## 3. Statistical Diagnostic Graphics (Model Validation)

Before drawing physical conclusions from response surfaces, the underlying Ordinary Least Squares (OLS) regression must be validated using diagnostic plots.

```
   Standardised Effect |t|
       ▲
       │   █
       │   █   █
       │   █   █   █
  t_crit ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  [p = 0.05 Significance Line]
       │   █   █   █   █   █
       │   █   █   █   █   █   █   █
       └──────────────────────────────────► Model Term
           X1  X2 X1² X2² X1*X2 X3  X3²
```

### 3.1. Pareto Chart of Standardised Effects (`ARTS_RenderPareto_DDEF`)
The Pareto chart ranks the absolute magnitude of studentised regression coefficients ($|t_j| = |\hat{\beta}_j / \text{SE}(\hat{\beta}_j)|$) in descending order:

```julia
fig_pareto = ARTS_RenderPareto_DDEF(
    model_yield, 
    "Radiochemical Yield (%)", 
    model_yield["R2_Adj"], 
    model_yield["Q2"]
)
```

* **Reference Line ($p = 0.05$):** Any effect exceeding the red vertical threshold line is statistically significant at the 95% confidence level.
* **Model Reduction Guide:** Factors and interactions falling well below the critical line represent negligible contributors and can be considered for hierarchical term elimination.

### 3.2. Observed vs. Predicted Response Fit (`ARTS_RenderFit_DDEF`)
Juxtaposes experimental observations against fitted model predictions along the $y = x$ diagonal identity line:

```julia
fig_fit = ARTS_RenderFit_DDEF(
    Y_yield, 
    model_yield["Y_Pred"], 
    "Radiochemical Yield (%)"
)
```

* **Tight Clustering along Diagonal:** Confirms high coefficient of determination ($R^2$) and minimal unexplained residual variance.
* **Systematic Curvature:** Points sagging below the diagonal at low values and bowing above at high values indicate missing quadratic or interaction terms.

### 3.3. Residual Diagnostics (`ARTS_RenderResiduals_DDEF` & `ARTS_RenderQQ_DDEF`)
Evaluates the core Gauss-Markov assumptions of Ordinary Least Squares regression:

```julia
# 1. Residuals vs Predicted (Homoscedasticity)
fig_residuals = ARTS_RenderResiduals_DDEF(
    model_yield["Y_Pred"], 
    model_yield["Resid"], 
    "Radiochemical Yield (%)"
)

# 2. Normal Q-Q Plot of Residuals (Normality)
fig_qq = ARTS_RenderQQ_DDEF(
    model_yield["Resid"], 
    "Radiochemical Yield (%)"
)
```

* **Homoscedasticity Check:** Residuals should scatter randomly within a constant horizontal band around zero. A funnel or wedge shape indicates heteroscedasticity (variance depending on response magnitude), suggesting a power or logarithmic response transformation.
* **Normality Check:** Studentised residuals in the Normal Q-Q plot should align tightly along the straight theoretical quantile reference line. S-shaped departures indicate heavy-tailed distributions or outliers.

### 3.4. Factor Sensitivity & Perturbation (`ARTS_RenderSensitivity_DDEF`)
Compares the relative responsiveness of all input factors radiating outwards from a designated reference coordinate (typically the design centre or active leader coordinate):

```julia
# Compute normalised local sensitivities (|dy/dX|) around reference coordinate
sens_vals = VISE_AnalyseSensitivity_DDEF(model_yield, [90.0, 15.0, 25.0], X)
fig_sens  = ARTS_RenderSensitivity_DDEF(
    sens_vals, 
    ["Temperature", "Time", "Precursor"], 
    "Radiochemical Yield (%)"
)
```

* Steeper curves denote factors with higher sensitivity, where small physical departures cause sharp response changes.
* Flat lines denote insensitive or robust factors, suitable for cost-saving adjustments or wider equipment tolerances.

---

## 4. Multi-Response Sweet-Spot Zones & Candidate Portfolios

When balancing conflicting laboratory criteria (e.g. maximising yield while simultaneously suppressing impurity formation), isolated single-response plots are insufficient.

### 4.1. Three-Tier Decision Space Architecture (`PLATE60`)

Rather than relying on a single arbitrary cutoff, DoECISORY.jl structures the multi-criteria decision space into three concentric operating tiers:

1. **Feasible Space (`ARTS_RenderFeasibleSpace_DDEF`):**
   Demarcates the broad permissible region where all individual response specifications are satisfied ($D_i \ge 0.05$). This forms the baseline regulatory compliance perimeter.
2. **Optimal Zone (`ARTS_RenderOptimalZone_DDEF`):**
   Restricts the operating space to coordinates achieving at least $90\%$ of the maximum composite desirability ($D \ge 0.90 \times D_{\max}$). Serves as the primary operational territory for process engineering.
3. **Sweet Spot (`ARTS_RenderSweetSpot_DDEF`):**
   Isolates the core operating nucleus within $5\%$ tolerance of summit desirability ($D \ge 0.95 \times D_{\max}$). This provides the target setpoint coordinates for validated clinical batch release.

```julia
# 1. Feasible Space (Baseline Compliance: D >= 0.05, 3D Volumetric)
fig_feasible = ARTS_RenderFeasibleSpace_DDEF(models, goals, X, in_names)

# 2. Optimal Zone (High Yield: D >= 0.90 * D_max, 3D Volumetric)
fig_optimal  = ARTS_RenderOptimalZone_DDEF(models, goals, X, in_names)

# 3. Sweet Spot (Primary Operating Nucleus: D >= 0.95 * D_max, 3D Volumetric)
fig_sweet    = ARTS_RenderSweetSpot_DDEF(models, goals, X, in_names)
```

The concentric projection visually demonstrates how parameter tolerance tightens from broad feasibility towards the optimum.

### 4.2. Candidate Portfolio Spatial Mapping (`ARTS_RenderCandidates_DDEF`)
Visualises where the extracted candidates from the multi-criteria portfolio sit within the 3-factor parameter space:

```julia
# Visualise candidate locations against design space on active axes [1, 2]
fig_candidates = ARTS_RenderCandidates_DDEF(
    models, 
    goals, 
    X, 
    [1, 2], 
    in_names, 
    leaders_df
)
```

* **`TOP-01` to `TOP-08`:** Clustered near the global desirability plateau.
* **`INP-<Factor>`:** Positioned along the low-consumption boundary edges (e.g. `INP-Precursor`), visually demonstrating the input savings achieved relative to the global peak.
* **`OUT-<Response>`:** Oriented towards the optimal frontier for specific critical quality attributes (e.g. `OUT-Impurity`).

---

## 5. Sequential Interphase Dynamics (IPKT Interval Migration)

A core methodological strength of DoECISORY.jl is the seamless transition of experimental knowledge between successive experimental phases without loss of historical variance or coordinate fidelity.

In laboratory investigations, sequential optimisation requires moving from a broad initial exploration space (**Phase 1**) to a focused, high-precision domain (**Phase 2**). The **Inter-Phase Knowledge Transfer (IPKT)** framework automates this transition via two complementary mathematical engines:
1. **Adaptive Contraction & Translation Algorithm (ACTA):** Governs intra-system factor range adaptation, computing continuous coordinate adjustments, domain narrowing, gradient-directed translations, window sliding, and boundary seeking.
2. **Affine Space Transformation Model (ASTM):** Governs cross-system mappings and scale-up projections (e.g. mapping coordinates from a benchtop micro-vial to an automated cassette synthesiser).

---

### 5.1. Visual Canvas Architecture (`FLOW_RenderIPKT_DDEF`)

The IPKT transition chart visualises how factor domains shift, narrow, or translate relative to their previous baseline. To allow simultaneous visual comparison across disparate physical dimensions (e.g. Temperature in °C, Time in min, and Precursor in mg), `FLOW_RenderIPKT_DDEF` projects all variables onto a **normalised dimensionless axis** spanning $[-2.0, +2.0]$:

```
                          IPKT Multi-Layer Visual Trace Canvas
                          
  Exploration Floor                                                        Exploration Ceiling
  (Safety Fence: -2.0)                                                     (Safety Fence: +2.0)
          │                                                                        │
          ▼                                                                        ▼
   -2.0   │   -1.5        -1.0 (Lower)     -0.5          0.0         +0.5       +1.0 (Upper)    +1.5       +2.0
────┆─────┼─────┼──────────────┼─────────────┼───────────┼────────────┼──────────────┼────────────┼─────────┆────
    ┆     │                    │                                                     │            │         ┆
    ┆     │                    60.0 [Phase 1 Lower]                120.0 [Phase 1 Upper]          │         ┆
    ┆     │                    ┌─────────────────────────────────────────────────────┐            │         ┆
    ┆     │   Trace 1: Current │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│ (Dark Gray)│         ┆
    ┆     │                    └─────────────────────────────────────────────────────┘            │         ┆
    ┆     │                                                 ┌────────────────────────┐            │         ┆
    ┆     │   Trace 2: Target                               │█████████████●██████████│ (Gold Bar) │         ┆
    ┆     │                                                 └─────────────┼──────────┘            │         ┆
    ┆     │                                                               │                       │         ┆
    ┆     │                                                Trace 3: Target Centre (Green Dot)     │         ┆
    ┆     │                                                Trace 4: Leader Point (Magenta Dot)    │         ┆
    ┆     │                                                               │                       │         ┆
    ┆     │                                            88.18            103.18         118.18     │         ┆
    ┆     │                                           [P2 Min]        [P2 Centre]     [P2 Max]    │         ┆
────┆─────┴─────┼──────────────┼─────────────┼───────────┼────────────┼──────────────┼────────────┴─────────┆────
    ▲                                                                                                       ▲
    └──────────────── Red Dashed Exploration Limit Lines (Hard Boundary Warning) ───────────────────────────┘
```

#### Canvas Components & Traces:
* **Trace 1: Current Baseline (Dark Slate Gray, `COLOUR_DARLOW`):** Fixed horizontal bar of width 12 spanning exactly $[-1.0, +1.0]$, representing the normalised boundaries of the previous Phase 1 operational window $[L_{\text{old}}, U_{\text{old}}]$.
* **Trace 2: Target Domain (Vibrant Gold, `COLOUR_HUEYEL`):** Dynamic horizontal bar of width 12 spanning $[n_{\text{new,min}}, n_{\text{new,max}}]$, indicating the proposed Phase 2 operational range.
* **Trace 3: Target Centre (Emerald Green Circle, `COLOUR_TONGRE`):** Marker placed at $n_{\text{new,mid}}$, pinpointing the geometric centre (zero-level, $0$) of the proposed Phase 2 design.
* **Trace 4: Optimal Leader Point (Magenta Circle, `COLOUR_SHAMAG`):** Marker placed at $n_{\text{leader}}$, indicating the exact physical coordinate of the champion formulation selected from Phase 1.
* **Trace 5: Directional Axial Focus (Teal Circle, `COLOUR_TONCYA`):** Visible when using directional screening geometries (such as `DF14`), highlighting the primary exploratory axial direction (Lower $-1$ or Upper $+1$).
* **Dual Numeric Level Annotations:**
  - **Top Labels ($y + 0.35$):** Low-contrast gray numerals positioned at $-1.0$ and $+1.0$ displaying the previous Phase 1 physical boundaries.
  - **Bottom Labels ($y - 0.35$):** High-contrast bold numerals positioned at $n_{\text{new,min}}$ and $n_{\text{new,max}}$ displaying the adapted Phase 2 physical boundaries.
* **Exploration Safety Fences (Red Dashed Vertical Lines at $\pm 2.0$):** Demarcate the maximum allowable extrapolation range; any target boundary approaching $\pm 2.0$ triggers a visual boundary warning.

---

### 5.2. ACTA Adaptation Signatures

The ACTA function dynamically selects an adaptation strategy based on the spatial location of the optimal leader coordinate $x^*$ relative to the previous factor domain $[L_{\text{old}}, U_{\text{old}}]$ (width $\Delta x = U_{\text{old}} - L_{\text{old}}$) using the normalised relative position $p_i = \frac{x^* - L_{\text{old}}}{\Delta x}$:

```
   ┌────────────────────────────────────────────────────────────────────────────────────────┐
   │                                ACTA Decision Topology                                  │
   ├───────────────────────┬───────────────────────────────┬────────────────────────────────┤
   │ Leader Position (p_i) │ Boundary Trait                │ Recommended Adaptation         │
   ├───────────────────────┼───────────────────────────────┼────────────────────────────────┤
   │ 0.25 ≤ p_i ≤ 0.75     │ FLOW_BoundarySafe_DDES        │ Contraction (c ∈ (0.0, 1.0])   │
   │ p_i < 0.25            │ FLOW_BoundaryLower_DDES       │ Translation Downward (δ < 0.0) │
   │ p_i > 0.75            │ FLOW_BoundaryUpper_DDES       │ Translation Upward (δ > 0.0)   │
   │ Dist(x*, Limit) < 5%  │ FLOW_BoundarySeekLower/Upper  │ Boundary Seeking (Lock ≥ 10%)  │
   └───────────────────────┴───────────────────────────────┴────────────────────────────────┘
```

#### 1. Internal Centering & Contraction (`FLOW_BoundarySafe_DDES`)
* **Mathematical Condition:** The leader point lies comfortably inside the central inter-quartile range ($0.25 \le p_i \le 0.75$).
* **Adaptation Mechanism:** The search span is contracted symmetrically around the leader:
  ```math
  \Delta x_{\text{new}} = c \cdot \Delta x_{\text{old}}, \quad x_{\text{mid}} = x^*
  ```
  ```math
  L_{\text{new}} = x_{\text{mid}} - \frac{\Delta x_{\text{new}}}{2}, \quad U_{\text{new}} = x_{\text{mid}} + \frac{\Delta x_{\text{new}}}{2}
  ```
  *(Default contraction factor $c = 0.50$, focusing variance on the optimum).*
* **Visual Signature:** The gold target bar is narrower than the gray baseline bar and rests entirely inside $[-1.0, +1.0]$. The magenta leader dot and green centre dot align at the midpoint of the gold bar.

#### 2. Boundary Proximity & Directional Translation (`FLOW_BoundaryLower_DDES` / `Upper_DDES`)
* **Mathematical Condition:** The leader point is located in the outer quartiles ($p_i < 0.25$ or $p_i > 0.75$), indicating that the true optimum lies outside the current exploration space.
* **Adaptation Mechanism:** Contraction is **suspended** ($\Delta x_{\text{new}} = \Delta x_{\text{old}}$) to prevent premature narrowing in an uncharted region. Instead, the entire domain is translated along the response gradient by translation factor $\delta \in [-1.0, 1.0]$:
  ```math
  x_{\text{mid}} = x^* + \delta \cdot \frac{\Delta x_{\text{new}}}{2}
  ```
* **Visual Signature:** The gold bar shifts into the outer quadrants ($[-2.0, -1.0]$ or $[+1.0, +2.0]$). The magenta leader dot sits near the boundary edge, visually demonstrating that Phase 2 will explore new physical territory.

#### 3. Boundary Seeking
* **Mathematical Condition:** The candidate optimum approaches immutable physical or equipment boundaries (e.g. solvent boiling point $T \le 90^\circ\text{C}$, non-negative concentrations $C \ge 0.0$, or pump limits) within a $5\%$ tolerance window.
* **Adaptation Mechanism:** Rather than collapsing the factor span into a degenerate point, ACTA enforces boundary seeking (`FLOW_SeekFloor_DDEF` / `FLOW_SeekCeiling_DDEF`):
  - The domain span $(U_{\text{new}} - L_{\text{new}})$ is locked to at least $10\%$ of the physical range $(U^{\text{abs}} - L^{\text{abs}})$.
  - The leader is pinned precisely to the boundary edge ($L_1$ floor or $L_3$ ceiling), preventing design matrix singularity while ensuring valid experimental operating volumes.
* **Visual Signature:** The gold target bar anchors reliably to the boundary threshold with a preserved $10\%$ span. The bottom numeric label reflects the boundary alignment rather than an unconstrained mathematical projection.

#### 4. Variable Replacement
* **Mathematical Condition:** When transitioning from a coarse screening phase to a fine response surface phase, an uninfluential factor (flat response slope) is dropped and replaced with a newly identified critical process parameter.
* **Visual Signature:** When `is_replaced = true`, the baseline numeric labels display `—` (em-dash), and the target bar renders a fresh $[-1.0, +1.0]$ domain for the incoming factor.

---

### 5.3. Programmatic Transition Workflow

The following script illustrates an end-to-end IPKT diagnostic workflow in Julia, showing how `FLOW_BuildIPKT_DDEF` extracts historical candidates and generates the interactive Plotly visual specification via `FLOW_RenderIPKT_DDEF`:

```julia
using DoECISORY, PlotlyJS

# 1. Define Phase 1 configuration (18F Baseline)
old_config = [
    Dict("Name" => "Temperature", "Role" => "Variable", "Levels" => [60.0, 90.0, 120.0]),
    Dict("Name" => "Time",        "Role" => "Variable", "Levels" => [5.0,  15.0, 25.0]),
    Dict("Name" => "Precursor",   "Role" => "Variable", "Levels" => [15.0, 25.0, 35.0])
]

# 2. Champion leader coordinates extracted from Phase 1 optimisation (TOP-01*)
# Temperature: 103.18°C (Safe, internal)
# Time: 15.50 min (Safe, internal, decay-penalised)
# Precursor: 27.80 mg (Safe, internal)
leader_coords = [103.18, 15.50, 27.80]

# 3. Compute Phase 2 adapted levels via ACTA (Contraction c = 0.50, Translation δ = 0.0)
new_config = [
    # Temperature: Symmetrically contracted around 103.18°C
    Dict("Name" => "Temperature", "Role" => "Variable", "Levels" => [88.18, 103.18, 118.18]),
    # Time: Symmetrically contracted around 15.50 min
    Dict("Name" => "Time",        "Role" => "Variable", "Levels" => [10.50, 15.50, 20.50]),
    # Precursor: Symmetrically contracted around 27.80 mg
    Dict("Name" => "Precursor",   "Role" => "Variable", "Levels" => [22.80, 27.80, 32.80])
]

# 4. Generate Interactive IPKT Diagnostic Plot
fig_ipkt_dict = FLOW_RenderIPKT_DDEF(
    old_config, 
    new_config, 
    leader_coords;
    Method="BB15"
)

# Render via PlotlyJS
p_ipkt = PlotlyJS.Plot(fig_ipkt_dict["data"], fig_ipkt_dict["layout"])
PlotlyJS.savefig(p_ipkt, "Figure_IPKT_Transition.pdf")
```

---

### 5.4. Laboratory Pre-Commit Verification Protocol

Prior to clicking **Commit Phase 2** in the Graphical Interface (`Gui_Deck`) or calling `FLOW_CommitIPKT_DDEF` via script, the experimental team should verify the following visual criteria on the IPKT diagnostic canvas:

| Diagnostic Feature | Visual Cue | Verification Rule | Action Required if Unmet |
| :--- | :--- | :--- | :--- |
| **Centering Check** | Green Dot vs Gold Bar | The green circle must sit at the exact midpoint of the gold target bar. | If off-centre, check whether an intentional translation factor ($\delta \ne 0$) was entered. |
| **Boundary Margin** | Magenta Dot vs Gray Edges | Verify whether the magenta dot lies within the central 90% of the dark gray bar. | If touching or near $-1.0$ or $+1.0$, activate Translation ($\delta$) to shift search space into unchartered domain. |
| **Boundary Seeking Verification** | Bar End vs Physical Cap | Confirm that gold bars preserve minimum span and anchor cleanly to physical thresholds. | If seeking engaged, verify that the experimental design respects process set-points. |
| **Extrapolation Fence** | Gold Bar vs Red Lines ($\pm 2.0$) | No portion of the gold bar should cross beyond the red dashed fences at $\pm 2.0$. | If breaching $\pm 2.0$, reduce translation step $\delta$ to prevent dangerous extrapolation away from verified data. |
| **Factor Continuity** | Top vs Bottom Variable Names | Ensure all active factors match intended designations; screened variables should show `—`. | Verify sheet configuration if factor roles or names have inadvertently swapped. |

---

## 6. Programmatic Export & 145 mm Composite Plates

### 6.1. Publication-Ready 145 mm Composite Vector Plates (`FAST_AssembleSvgPlate_DDEF`)

For academic manuscripts, doctoral dissertations, and technical reports, DoECISORY.jl standardises graphic exports onto **145 mm fixed-width composite SVG plates** (`PLATE11` to `PLATE60`). Rather than manually stitching disparate raster plots in third-party graphic editors, `FAST_AssembleSvgPlate_DDEF` dynamically embeds individual high-resolution plot panels (provided as PNG file paths or base64 data URIs) into cohesive multi-panel SVG plates:

* **2×3 Multi-Panel Grids** ($115.200\,\text{mm}$ height, e.g. 2D contour pairs, slices, and diagnostic panels)
* **3×3 Manifold Matrices** ($172.800\,\text{mm}$ height, e.g. interaction matrices and response surfaces)
* **1×3 Linear Strips** ($57.600\,\text{mm}$ height, e.g. isolated factor progressions)

```julia
using DoECISORY

# Assemble individual raster PNG panel paths into a standardised 145 mm 2x3 SVG plate
panel_png_paths = [
    "PNGPLOTS/01_Pareto_Yield.png",
    "PNGPLOTS/02_Sensitivity_Yield.png",
    "PNGPLOTS/03_IntMatrix_Yield.png",
    "PNGPLOTS/04_Fit_Yield.png",
    "PNGPLOTS/05_QQ_Yield.png",
    "PNGPLOTS/06_Residuals_Yield.png"
]
svg_plate = FAST_AssembleSvgPlate_DDEF(panel_png_paths, :Grid2x3)
write("PLATE11_Diagnostics_Yield.svg", svg_plate)
```

Each composite plate features:
* Standardised 8 pt bold panel labels (`(a)`, `(b)`, etc.) for direct manuscript citation,
* Strict physical scaling calibrated to standard two-column page widths without text distortion.

### 6.2. Direct PlotlyJS Single-Plot Export

Individual `PlotlyJS.Plot` objects returned by `Lib_Arts` can also be exported directly into lossless vector or high-resolution raster formats:

```julia
using PlotlyJS

# 1. Lossless Vector Export for Journal Submissions (PDF / SVG)
PlotlyJS.savefig(fig_surface, "Figure_3_Surface.pdf"; width=800, height=600)
PlotlyJS.savefig(fig_pareto,  "Figure_4_Pareto.svg";  width=600, height=450)

# 2. High-Resolution Raster Export (300+ DPI PNG)
PlotlyJS.savefig(fig_contour, "Figure_5_Contour.png"; width=1200, height=900, scale=3)

# 3. Standalone Interactive HTML (Supplementary Information)
PlotlyJS.savefig(fig_surface, "Supplementary_3D_Surface.html")
```

### 6.3. Automated Portfolio ZIP Archive

Through the `Gui_Lens` interface, researchers can download the entire analytical output in a single step via **Download Portfolio (.zip)**:
* `PLATE11.svg` to `PLATE60.svg`: All 12 composite vector plates at 145 mm width stored directly in the archive root for immediate document insertion,
* `REPORT.txt`: The complete 7-stage interpreted scientific report,
* `ANALYTICS.xlsx`: Raw regression coefficients, ANOVA tables, and candidate coordinates,
* `PNGPLOTS/`: High-resolution standalone raster plots ($960 \times 1080\,\text{px}$).
