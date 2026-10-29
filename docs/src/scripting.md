# Programmatic Scripting Guide

This guide covers batch execution, scripted workflows, multi-threading, and system image compilation for **DoECISORY.jl**.

---

## 1. Programmatic Workflow

DoECISORY.jl provides both high-level and low-level APIs for programmatic execution. Currently, `design` serves as the primary high-level endpoint for experimental planning, with further high-level APIs planned for future releases. For direct low-level control, routines follow the symbol template:

```julia
[DOMAIN]_[PascalCase-Action/Entity]_DDE[F|S|T|C]
```

Here: `[DOMAIN]` identifies the subsystem, `[PascalCase-Action/Entity]` describes the operational action or data entity, `DDE` marks a DoECISORY-defined construct, and the terminal letter denotes functions (`_DDEF`), structs (`_DDES`), abstract types (`_DDET`), or constants (`_DDEC`) (e.g. `VISE_AnalyseSensitivity_DDEF` and `CORE_ModifierDCYP_DDES`).

### 1.1. Experimental Planning Example with `design()`

The high-level `design` function constructs experimental matrices, maps physical levels, and evaluates information optimality in a single call:

```julia
using DoECISORY

# 1. Synthesise experimental design matrix & inspect information optimality
begin
  plan = design(:bb15;
    factors = ["Temperature", "Time", "Precursor"],
    levels  = [(60.0, 90.0, 120.0), (5.0, 15.0, 25.0), (15.0, 25.0, 35.0)]
  )
  show(stdout, MIME("text/plain"), plan.dataframe; allrows=true)
  println()
  println("D-Efficiency                    : ", round(plan.metrics["D"] * 100.0, digits=2), "%")
  println("G-Efficiency                    : ", round(plan.metrics["G"] * 100.0, digits=2), "%")
  println("Condition No                    : ", round(plan.metrics["Condition"], digits=2))
end
```

### 1.2. Low-Level Modular Algorithmic Workflow

When custom coordinate manipulation or step-by-step mathematical intervention is required, routines from `Lib_Core`, `Lib_Vise`, and `Sys_Flow` can be invoked directly:

```julia
using DoECISORY

begin
# 1. Synthesise experimental design matrix & inspect optimality
  X_coded = CORE_GenDesign_DDEF("BB15", 3)
  factor_config = [
    Dict("Name" => "Temperature", "Levels" => [60.0, 90.0, 120.0]),
    Dict("Name" => "Time",        "Levels" => [5.0,  15.0, 25.0]),
    Dict("Name" => "Precursor",   "Levels" => [15.0, 25.0, 35.0])
  ]
  X = Matrix{Float64}(CORE_MapLevels_DDEF(X_coded, factor_config))
  metrics = CORE_CalcDesignMetrics_DDEF(Float64.(X_coded), "quadratic")
  println("D-Efficiency                    : ", round(metrics["D"] * 100.0, digits=2), "%")
  println("G-Efficiency                    : ", round(metrics["G"] * 100.0, digits=2), "%")
  println("Condition No                    : ", round(metrics["Condition"], digits=2))

# 2. Analytical response observations (Y_conv, Y_yield, Y_impur)
  Y_conv   = [87.4, 53.1, 73.6, 77.2, 94.5, 87.0, 65.3, 82.7, 75.5, 92.1, 87.7, 59.9, 80.4, 70.2, 90.6]
  Y_yield  = [77.6, 45.2, 66.1, 69.9, 72.4, 77.1, 57.4, 73.8, 67.5, 74.2, 77.9, 51.1, 70.3, 63.4, 73.8]
  Y_impur  = [2.5,  8.2,  4.8,  6.4,  5.2,  2.2,  6.9,  4.1,  5.6,  3.3,  2.7,  7.6,  5.4,  6.2,  3.9]

# 3. Fit quadratic response surface models (VISE_Regress_DDEF)
  in_names = ["Temperature", "Time", "Precursor"]
  models = [
    VISE_Regress_DDEF(X, Y_conv,  "quadratic"; InNames=in_names),
    VISE_Regress_DDEF(X, Y_yield, "quadratic"; InNames=in_names),
    VISE_Regress_DDEF(X, Y_impur, "quadratic"; InNames=in_names)
  ]
  println("Model R² (Conv, Yield, Impurity)  : ", [round(m["R2"]; digits=3) for m in models])
  println("Model RMSE (Conv, Yield, Impurity): ", [round(m["RMSE"]; digits=2) for m in models])

# 4. Multi-response desirability optimisation with 18F DCYP & sensitivity
  goals = [
    Dict("Type" => "Maximise", "Min" => 50.0, "Max" => 98.0, "Target" => 92.0, "Weight" => 1.0),
    Dict("Type" => "Maximise", "Min" => 40.0, "Max" => 85.0, "Target" => 80.0, "Weight" => 1.2),
    Dict("Type" => "Minimise", "Min" => 1.0,  "Max" => 10.0, "Target" => 2.0,  "Weight" => 1.5)
  ]
  dcyp = [CORE_ModifierDCYP_DDES(2, log(2.0) / 109.8, "18F")]
  box  = hcat(minimum(X; dims=1)', maximum(X; dims=1)')
  (opt_x, opt_score) = CORE_OptimiseDesirability_DDEF(models, goals, box; MaxTime=0.4, ModifiersDCYP=dcyp)
  opt_preds          = [round(VISE_Predict_DDEF(m, reshape(opt_x, 1, 3))[1]; digits=1) for m in models]
  sensitivities      = VISE_AnalyseSensitivity_DDEF(models[1], opt_x, X)
  println("Multi-Desirability Score        : ", round(opt_score; digits=4))
  println("Optimum (Temp, Time, Precursor) : ", round.(opt_x; digits=2))
  println("Predicted Responses at Optimum  : ", opt_preds)
  println("Factor Sensitivities (%)        : ", round.(sensitivities .* 100.0; digits=1))

# 5. Interphase Knowledge Transfer (IPKT = ACTA + ASTM)
# Step A: ACTA domain contraction (c = 0.50 around leader)
  acta_bounds = FLOW_CalcACTA_DDEF(opt_x[1], [60.0, 90.0, 120.0], 0.5, 0.0, 0.0)
  println("ACTA Phase 2 Contraction (Temp) : ", round.(acta_bounds; digits=2))

# Step B: ASTM affine transformation & verification (α = 0.9, β = 9.0)
  phase2_levels = [FLOW_ApplyASTM_DDEF(x, 0.9, 9.0) for x in acta_bounds]
  println("ASTM Phase 2 Scaling (Temp)     : ", round.(phase2_levels; digits=2))
end
```

### 1.3. Hybrid Laboratory Workflow (DataFrame Ingestion & Candidate Pool Search)

In modern laboratories, researchers often combine the speed of tabular dataframes with the computational rigor of scripted multi-objective grid optimisation. The snippet below illustrates this end-to-end loop:

```julia
using DoECISORY, DataFrames

# 1. Synthesise or ingest completed laboratory dataset
plan = design(:bb15;
  factors = ["Temperature", "Time", "Precursor"],
  levels  = [(60.0, 90.0, 120.0), (5.0, 15.0, 25.0), (15.0, 25.0, 35.0)]
)
df_lab = copy(plan.dataframe)
df_lab[!, "RESULT_Conversion"] = [87.4, 53.1, 73.6, 77.2, 94.5, 87.0, 65.3, 82.7, 75.5, 92.1, 87.7, 59.9, 80.4, 70.2, 90.6]
df_lab[!, "RESULT_Yield"]      = [77.6, 45.2, 66.1, 69.9, 72.4, 77.1, 57.4, 73.8, 67.5, 74.2, 77.9, 51.1, 70.3, 63.4, 73.8]
df_lab[!, "RESULT_Impurity"]   = [2.5,  8.2,  4.8,  6.4,  5.2,  2.2,  6.9,  4.1,  5.6,  3.3,  2.7,  7.6,  5.4,  6.2,  3.9]

# 2. Extract feature matrix and fit multi-response models
X = Matrix{Float64}(df_lab[:, ["Temperature", "Time", "Precursor"]])
models = [
  VISE_Regress_DDEF(X, df_lab[!, "RESULT_Conversion"], "quadratic"; InNames=plan.factors),
  VISE_Regress_DDEF(X, df_lab[!, "RESULT_Yield"],      "quadratic"; InNames=plan.factors),
  VISE_Regress_DDEF(X, df_lab[!, "RESULT_Impurity"],   "quadratic"; InNames=plan.factors)
]

# 3. Multi-threaded high-density grid exploration & DCYP
bounds = [60.0 120.0; 5.0 25.0; 15.0 35.0]
goals = [
  Dict("Type" => "Maximise", "Min" => 50.0, "Max" => 98.0, "Target" => 92.0, "Weight" => 1.0),
  Dict("Type" => "Maximise", "Min" => 40.0, "Max" => 85.0, "Target" => 80.0, "Weight" => 1.2),
  Dict("Type" => "Minimise", "Min" => 1.0,  "Max" => 10.0, "Target" => 2.0,  "Weight" => 1.5)
]
dcyp = [CORE_ModifierDCYP_DDES(2, log(2.0) / 109.8, "18F")]

grid_coords, grid_preds, grid_scores = VISE_RunGridSearch_DDEF(
  models, goals, bounds; ModifiersDCYP=dcyp
)

# 4. Extract Candidate Portfolio (Absolute summit vs Reagent Minimisation)
best_idx  = argmax(grid_scores)
top_score = grid_scores[best_idx]
top_coord = grid_coords[best_idx, :]

tier_mask    = grid_scores .>= (top_score * 0.90)
tier_indices = findall(tier_mask)
min_prec_idx = tier_indices[argmin(grid_coords[tier_indices, 3])]

println("Candidate TOP-01 (Grid Summit) : ", round.(top_coord; digits=1), " | Score: ", round(top_score; digits=4))
println("Candidate INP-Precursor (Green): ", round.(grid_coords[min_prec_idx, :]; digits=1), " | Precursor: ", round(grid_coords[min_prec_idx, 3]; digits=1), " mg")
```

---

## 2. Multi-Threading

The high-density grid evaluation (`VISE_RunGridSearch_DDEF`) scales across all available CPU cores.

### 2.1. Invocation with Multiple Threads
Launch Julia with automated thread detection:

```bash
julia --threads=auto
```

Or specify a dedicated thread allocation:

```bash
julia --threads=8
```

Within Julia, verify thread availability:

```julia
using Base.Threads
println("Allocated Threads: ", nthreads())
```

When thread counts exceed 4, `VISE_RunGridSearch_DDEF` dynamically upgrades evaluation resolution from $21^3$ ($9,261$ coordinates) to $41^3$ ($68,921$ coordinates) without increasing execution latency.

---

## 3. System Image Compilation

To eliminate Just-In-Time (JIT) compilation delays and achieve fast startup, compile a local system image using `PackageCompiler.jl`:

### 3.1. Compilation via `tools/Compiler.jl`

A pre-configured compiler harness is located at `tools/Compiler.jl`, supporting two distinct build profiles:

* **Full Precompilation:** Compiles all dependencies alongside `DoECISORY` and executes the benchmark workload (`tools/Workload.jl`):
  ```bash
  julia --project=. tools/Compiler.jl
  ```
  Generates `tools/Sysimage.dll` (Windows) or `tools/Sysimage.so` (Linux/macOS).

* **Development Profile (`--dev`):** Precompiles heavy third-party dependencies (`Dash`, `PlotlyJS`, `DataFrames`, `XLSX`) while keeping `DoECISORY` interpreted:
  ```bash
  julia --project=. tools/Compiler.jl --dev
  ```
  Generates `tools/Sysimage_Deps.dll`. This allows `tools/Watcher.ps1` to reload code modifications instantly without requiring full sysimage re-compilation.

### 3.2. Launching with Native Sysimage

On Windows (PowerShell):
```powershell
# Standard startup
julia -J tools\Sysimage.dll -e "using DoECISORY; launch()"

# Development watcher mode
julia -J tools\Sysimage_Deps.dll --project=. -e "using DoECISORY; launch()"
```

On Linux / macOS:
```bash
julia -J tools/Sysimage.so -e "using DoECISORY; launch()"
```