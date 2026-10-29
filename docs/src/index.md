# DoECISORY.jl

**Design of Experiments with Computational Interactive Sequential Optimisation for Response Yield**

**DoECISORY.jl** is an open-source, registered Julia package and stateless Dash web application developed for classical and adaptive Design of Experiments (DoE), Response Surface Methodology (RSM), stoichiometric verification, and multi-objective optimisation. Executable across local workstations, cloud environments, the native Julia REPL, and reactive Pluto.jl notebooks, it integrates stoichiometric formulation balancing, multi-response statistical modelling, and interactive visual analytics within adaptive sequential workflows that contract and translate search spaces from screening to fine-tuning. Integrated first-order kinetic compensations correct for time-dependent reagent degradation: normalising pre-reaction preparation intervals, restoring end-of-synthesis (EOS) yields, and arbitrating reaction trade-offs via kinetic penalty profiling.

---

## Core Capabilities

* **3-Factor Experimental Designs**: Matrices for 3-factor formulation spaces, including Box-Behnken (BB15), Central Composite (CD17), Taguchi (TL09), and Fractional D-Optimal (DF14).
* **Information Optimality Metrics**: Evaluation of D-, A-, G-, and I-efficiencies and design matrix condition numbers.
* **Stoichiometry and Mass Balance**: Automated mass balance audits, excipient balancing, molar ratios, and concentration consistency checks (`Lib_Mole`).
* **Temporal Kinetic Adjustments**: Pre-reaction ingredient degradation normalisation (e.g. stock holding delay, radionuclide decay, or labile precursor degradation) and post-reaction analytical latency restoration back to reference state (e.g. End of Synthesis - EOS) via `VISE_ApplyFRDecay_DDEF` and `MOLE_CalcRadioDecay_DDEF`.
* **Multi-Objective Optimisation and Kinetic Penalties (DCYP)**: Derringer-Suich desirability profiling with continuous and categorical criteria:
  - **Decay-Coupled Yield Penalty (DCYP)**: Universal kinetic trade-off arbitration penalising excessive reaction duration against exponential half-life decay ($t_{1/2}$, e.g. radionuclide decay or labile compound degradation).
  - **Gaussian Neighbour-Weighting Regularisation**: Smoothens multi-objective landscape ridges for stable metaheuristic and grid convergence.
* **Candidate Pool Formulation**: Generates a tiered portfolio of viable formulations rather than a single point:
  - *Absolute Leaders (`TOP-XX`)*: Highest unconstrained composite desirability.
  - *Input Minimisation (`INP-<Factor>`)*: Green chemistry and cost-saving formulations achieving $\ge 90\%$ desirability with minimal reagent consumption, reduced heating load, or shortest residence time.
  - *Output Specialisation (`OUT-<Response>`)*: Solutions prioritising critical quality attributes like minimal impurity, high purity, or specific activity.
* **Sequential Interphase Transfer (ACTA and ASTM)**: Bridges successive experimental phases through:
  - *ACTA (Adaptive Contraction & Translation Algorithm)*: Evaluates relative position ($p_i$) to contract search boundaries ($c$) around the leader or translate them ($\delta$) upon boundary contact.
  - *ASTM (Affine Space Transformation Model)*: Applies affine scaling ($x_{\text{new}} = \alpha \cdot x_{\text{old}} + \beta$) and absolute physical clamping.
* **Statistical Diagnostics**: Seven-stage scientific analysis report featuring OLS linear and quadratic regression, ANOVA, Lack-of-Fit tests, cross-validated $Q^2$ (overfitting protection), and VIF multicollinearity screening.
* **Visualisation**: PlotlyJS 3D response surfaces, equipotential 2D contour maps with fixed-factor slicing, and IPKT interval shift charts (`Lib_Arts`).
* **Spreadsheet Data Exchange (Excel)**: Multi-sheet protocol workbooks (`.xlsx`) with formatting standards, formula preservation, and zero data loss (`Sys_Fast`).

---

## Execution Modes

DoECISORY.jl provides two operational interfaces:

### [Graphical Interface (GUI)](interface.md)
* **Users:** Laboratory chemists, radiopharmacists, radiochemists, and formulation scientists.
* **Interface:** Browser-based interactive Dash platform (`launch()`).
* **Workflow:** Graphical factor setup, automatic Excel workbook download, dropzone data ingestion, interactive 3D Plotly surfaces, and slider-controlled IPKT transitions without terminal coding.

### [Scripting and Batch Pipeline](scripting.md)
* **Users:** Biostatisticians, data scientists, chemical engineers, and automation specialists.
* **Interface:** Julia REPL, reactive Pluto.jl notebooks, or automated batch scripts.
* **Workflow:** Direct API dispatch, multi-threaded high-density grid evaluations (`--threads=auto`), and ahead-of-time sysimage compilation (`tools/Compiler.jl`).

---

## Installation

Install the package via the Julia package manager:

```julia
using Pkg
Pkg.add("DoECISORY")
```

Or clone the development branch directly from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/erensgol/DoECISORY.jl")
```

---

## Minimal Verification Example

Synthesise a standard 15-point Box-Behnken design (`:bb15`), evaluate optimality, fit a quadratic response surface from experimental observations, predict the centre point, and apply an IPKT interphase adaptation:

```julia
using DoECISORY

begin
# 1. Synthesise experimental design matrix
  plan = design(:bb15;
    factors = ["Temperature", "Time", "Precursor"],
    levels  = [(60.0, 90.0, 120.0), (5.0, 15.0, 25.0), (15.0, 25.0, 35.0)]
  )
  println("D-Efficiency: ", round(plan.metrics["D"] * 100.0, digits=2), "%")

# 2. Analytical response observations (Isolated RCY, %)
  X = plan.matrix
  Y = [77.6, 45.2, 66.1, 69.9, 72.4, 77.1, 57.4, 73.8, 67.5, 74.2, 77.9, 51.1, 70.3, 63.4, 73.8]

# 3. Fit quadratic response surface model
  model = VISE_Regress_DDEF(X, Y, "quadratic"; InNames=plan.factors)
  println("Model R²: ", round(model["R2"], digits=3))

# 4. Predict response at the centre point
  pred = VISE_Predict_DDEF(model, [90.0, 15.0, 25.0])
  println("Predicted Centre Value: ", round(pred[1], digits=2))

# 5. Interphase Knowledge Transfer (IPKT = ACTA + ASTM)
# Step A: ACTA domain contraction (c = 0.50 around centre 90.0)
  acta_levels = FLOW_CalcACTA_DDEF(90.0, [60.0, 90.0, 120.0], 0.50, 0.0, 0.0)

# Step B: ASTM affine scaling and boundary safety verification (α = 0.9, β = 9.0)
  phase2_levels = [FLOW_ApplyASTM_DDEF(x, 0.9, 9.0) for x in acta_levels]
  println("Adapted Phase 2 Levels (Temp): ", round.(phase2_levels, digits=2))
end
```

---

## Documentation Contents

```@contents
Pages = [
    "methodology.md",
    "interface.md",
    "scripting.md",
    "tutorial.md",
    "statistics.md",
    "visuals.md",
    "api.md",
    "citation.md"
]
Depth = 2
```