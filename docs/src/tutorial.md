# Sequential Optimisation Case Study

This case study demonstrates the complete sequential optimisation workflow in **DoECISORY.jl**, tracking an experimental Fluorine-18 ($^{18}\text{F}$) radiotracer formulation through initial recipe auditing, directional experimental design, physical decay adjustments, quadratic regression, multi-objective optimisation with kinetic penalties, and automated phase transition via **ACTA** and **ASTM**.

> [!NOTE] Dual-Track Documentation Architecture
> To bridge the gap between computational data science and benchtop laboratory practice, every step in this case study is presented in two parallel execution tracks:
> * **Track A — Julia Scripting:** Direct functional API calls for automated computational pipelines, batch processing, and reproducible Pluto.jl notebooks.
> * **Track B — Graphical Interface (`Gui_Deck` / `Gui_Lens`):** Interactive browser-based controls, visual input cards, dropzone file ingestion, and slider widgets without writing terminal code.

---

## Problem Formulation

* **Objective:** Optimise synthesis and radiolabelling parameters for a Fluorine-18 ($^{18}\text{F}$) labelled prosthetic radiotracer model.
* **Continuous Factors (3):**
  1. `Temperature` ($X_1$): $60.0$ to $120.0$ ${^\circ\text{C}}$ (centre: $90.0$ ${^\circ\text{C}}$)
  2. `Time` ($X_2$): $5.0$ to $25.0$ $\text{min}$ (centre: $15.0$ $\text{min}$)
  3. `Precursor` ($X_3$): $15.0$ to $35.0$ $\text{mg}$ (centre: $25.0$ $\text{mg}$)
* **Responses (3):**
  1. `Conversion` ($Y_1$, % Radio-TLC): Maximise (Target: 92.0%, Min: 50.0%, Weight: 1.0)
  2. `Yield` ($Y_2$, % Isolated RCY): Maximise (Target: 80.0%, Min: 40.0%, Weight: 1.2)
  3. `Impurity` ($Y_3$, % Radiolytic By-products): Minimise (Target: 2.0%, Max: 10.0%, Weight: 1.5)
* **Radionuclide:** Fluorine-18 ($t_{1/2} = 109.8\,\text{min}$, $\lambda = 0.006315\,\text{min}^{-1}$)

---

## 1. Recipe Specification and Stoichiometry

Before allocating radioactive doses or physical reagents, the formulation recipe is audited for mass balance, target concentration, and molar consistency.

### Track A — Julia Scripting
```julia
using DoECISORY

# Define formulation ingredients with discrete 3-factor bounds and mass budget
recipe = [
    Dict("Name" => "Temperature",   "Role" => "Variable", "L1" => 60.0, "L2" => 90.0, "L3" => 120.0, "Unit" => "degC", "MW" => 0.0),
    Dict("Name" => "Time",          "Role" => "Variable", "L1" => 5.0,  "L2" => 15.0, "L3" => 25.0,  "Unit" => "min",  "MW" => 0.0),
    Dict("Name" => "Precursor",     "Role" => "Variable", "L1" => 15.0, "L2" => 25.0, "L3" => 35.0,  "Unit" => "mg",   "MW" => 450.5),
    Dict("Name" => "Buffer_Salt",   "Role" => "Fixed",    "L1" => 15.0, "L2" => 15.0, "L3" => 15.0,  "Unit" => "mg",   "MW" => 82.03),
    Dict("Name" => "Ascorbic_Acid", "Role" => "Filler",   "L1" => 0.0,  "L2" => 0.0,  "L3" => 0.0,   "Unit" => "%",    "MW" => 176.12)
]

# Run stoichiometric audit (1.0 mL target volume, 300.0 mM target concentration)
begin
    total_vol_mL = 1.0
    target_conc_mM = 300.0
    audit_ok, audit_report, summary_df, total_mass_mg, _ = MOLE_AuditQuick_DDEF(recipe, total_vol_mL, target_conc_mM)
    println("Stoichiometric Audit Passed: ", audit_ok)
end
```

### Track B — Graphical Interface (`Gui_Deck`)
1. Open the browser interface at `http://127.0.0.1:8060` and navigate to the **Deck** tab.
2. Under the **Formulation Configuration** card, input each reagent:
   * **Active Precursor (`VAR`):** Enter Name `Precursor`, Role `VAR`, MW `450.5`, Unit `mg`, Levels `15.0 / 25.0 / 35.0`.
   * **Process Variables (`VAR`):** Add `Temperature` (60 / 90 / 120 °C) and `Time` (5 / 15 / 25 min).
   * **Fixed Salts (`FIX`):** Add `Buffer_Salt` (15.0 mg, MW 82.03).
   * **Stabiliser (`FILL`):** Add `Ascorbic_Acid` (Filler, MW 176.12).
3. Set Target Volume to `1.0 mL` and Target Concentration to `300 mM`.
4. Click **Audit Mass Balance**. The card updates with a green status badge (*Audit Status: Passed*), displaying total formulation mass ($50.85\,\text{mg}$) and molar ratios.

---

## 2. Design Matrix Generation (BB15)

We construct a standard 15-point Box-Behnken (`"BB15"`) design matrix comprising 12 edge midpoints and 3 replicated centre points, then evaluate its information efficiency.

### Track A — Julia Scripting
```julia
# 1. Generate coded 15-run Box-Behnken design matrix in [-1, 0, 1]
X_coded = CORE_GenDesign_DDEF("BB15", 3)

# 2. Evaluate D-, G-, and Condition metrics for a quadratic model
begin
    metrics = CORE_CalcDesignMetrics_DDEF(Float64.(X_coded), "quadratic")
    println("D-efficiency:     ", round(metrics["D"] * 100.0, digits=2), "%")
    println("G-efficiency:     ", round(metrics["G"] * 100.0, digits=2), "%")
    println("Condition Number: ", round(metrics["Condition"], digits=2))
end

# 3. Map coded coordinates to physical laboratory units
begin
    factor_config = [
        Dict("Name" => "Temperature", "Levels" => [60.0, 90.0, 120.0]),
        Dict("Name" => "Time",        "Levels" => [5.0,  15.0, 25.0]),
        Dict("Name" => "Precursor",   "Levels" => [15.0, 25.0, 35.0])
    ]
    X_physical = CORE_MapLevels_DDEF(X_coded, factor_config)
end
```

### Track B — Graphical Interface (`Gui_Deck`)
1. In the **Experimental Factors** section of **Deck**, configure the 3 continuous factors:
   * `Temperature`: Min `60.0`, Mid `90.0`, Max `120.0` (°C)
   * `Time`: Min `5.0`, Mid `15.0`, Max `25.0` (min)
   * `Precursor`: Min `15.0`, Mid `25.0`, Max `35.0` (mg)
2. Under **Design Geometry**, select **Box-Behnken (15 Runs, BB15)**.
3. Inspect the real-time **Information Optimality Card**: D-Efficiency (36.64%) and condition number (17.97) are displayed for the spherical 15-run domain.
4. Click **Download Protocol Workbook (.xlsx)**. The system generates and downloads `DoECISORY_Protocol.xlsx`, containing pre-populated benchtop execution tables.

---

## 3. Experimental Dataset and Analytical Observations

Laboratory observations are recorded across all three responses: Radio-TLC conversion ($Y_1$), isolated radiochemical yield ($Y_2$), and radio-HPLC radiolytic impurity ($Y_3$).

### Track A — Julia Scripting
```julia
begin
    using DataFrames

    # 15 Canonical experimental observations matching the Box-Behnken topology
    df_exp = DataFrame(
        :RUN => 1:15,
        :VARIA_Temperature => X_physical[:, 1],
        :VARIA_Time        => X_physical[:, 2],
        :VARIA_Precursor   => X_physical[:, 3],
        :RESULT_Conversion => [87.4, 53.1, 73.6, 77.2, 94.5, 87.0, 65.3, 82.7, 75.5, 92.1, 87.7, 59.9, 80.4, 70.2, 90.6],
        :RESULT_Yield      => [77.6, 45.2, 66.1, 69.9, 72.4, 77.1, 57.4, 73.8, 67.5, 74.2, 77.9, 51.1, 70.3, 63.4, 73.8],
        :RESULT_Impurity   => [2.5,  8.2,  4.8,  6.4,  5.2,  2.2,  6.9,  4.1,  5.6,  3.3,  2.7,  7.6,  5.4,  6.2,  3.9]
    )
    df_exp
end
```

### Track B — Graphical Interface (`Gui_Lens`)
1. Following physical laboratory runs, fill the measured response values into the downloaded `DoECISORY_Protocol.xlsx` sheet:
   * Column `RESULT_Conversion` (measured % conversion).
   * Column `RESULT_Yield` (isolated % RCY).
   * Column `RESULT_Impurity` (measured % radiolytic impurity).
2. Switch to the **Lens** tab in your browser.
3. Drag and drop `DoECISORY_Protocol.xlsx` into the **Dataset Dropzone**.
4. The system validates the table schema, detects radionuclide $^{18}\text{F}$, and verifies data integrity.

---

## 4. Regression Modelling and ANOVA

We fit full quadratic response surface models for all three outputs and verify goodness-of-fit, lack-of-fit sufficiency, and predictive ability.

### Track A — Julia Scripting
```julia
begin
    in_names  = ["Temperature", "Time", "Precursor"]
    X_mat     = Matrix{Float64}(X_physical)
    Y_conv    = Vector{Float64}(df_exp[!, :RESULT_Conversion])
    Y_yield   = Vector{Float64}(df_exp[!, :RESULT_Yield])
    Y_impur   = Vector{Float64}(df_exp[!, :RESULT_Impurity])

    # Fit quadratic models
    model_conv   = VISE_Regress_DDEF(X_mat, Y_conv,   "quadratic"; InNames=in_names)
    model_yield  = VISE_Regress_DDEF(X_mat, Y_yield,  "quadratic"; InNames=in_names)
    model_impur  = VISE_Regress_DDEF(X_mat, Y_impur,  "quadratic"; InNames=in_names)

    println("--- Model Validation Summary ---")
    println("Conversion | R²: ", round(model_conv["R2"], digits=3),   " | RMSE: ", round(model_conv["RMSE"], digits=2))
    println("Yield      | R²: ", round(model_yield["R2"], digits=3),  " | RMSE: ", round(model_yield["RMSE"], digits=2))
    println("Impurity   | R²: ", round(model_impur["R2"], digits=3),  " | RMSE: ", round(model_impur["RMSE"], digits=2))

    # Check ANOVA and Lack-of-Fit for Primary Response (Yield)
    anova_yield = VISE_GenANOVATable_DDEF(model_yield, X_mat, Y_yield)
end
```

### Track B — Graphical Interface (`Gui_Lens`)
1. In the **Modelling Configuration** panel, set Model Hierarchy to **Quadratic Response Surface**.
2. Click **Fit Models & Run Diagnostics**.
3. Response metrics update instantly:
   * Conversion: $R^2 = 0.998$, $\text{RMSE} = 0.92\%$
   * Yield: $R^2 = 0.997$, $\text{RMSE} = 0.90\%$
   * Impurity: $R^2 = 0.971$, $\text{RMSE} = 0.54\%$
4. Click **View Analytical Summary** to open the 7-stage diagnostic modal:
   * Inspect the ANOVA table: Confirm Lack-of-Fit $p$-value $> 0.05$ (indicating negligible model bias).
   * Check VIF values: All terms $< 2.5$, confirming absence of multicollinearity.

---

## 5. Multi-Objective Optimisation and DCYP

We establish desirability criteria across all 3 responses, apply **DCYP** for Fluorine-18 on factor 2 (`Time`), and explore the multi-criteria Candidate Pool.

### Track A — Julia Scripting
```julia
begin
    # 1. Multi-Objective Goals
    goals = [
        Dict("Type" => "Maximise", "Min" => 50.0, "Max" => 98.0, "Target" => 92.0, "Weight" => 1.0),
        Dict("Type" => "Maximise", "Min" => 40.0, "Max" => 85.0, "Target" => 80.0, "Weight" => 1.2),
        Dict("Type" => "Minimise", "Min" => 1.0,  "Max" => 10.0, "Target" => 2.0,  "Weight" => 1.5)
    ]

    # 2. DCYP Modifier: λ = ln(2) / 109.8 on Factor 2 (Time)
    lambda_f18 = log(2.0) / 109.8
    dcyp_mod   = CORE_ModifierDCYP_DDES(2, lambda_f18, "18F")

    # 3. Continuous Optimisation & Candidate Pool Generation
    bounds = hcat(minimum(X_mat; dims=1)', maximum(X_mat; dims=1)')
    models = [model_conv, model_yield, model_impur]

    best_coords, best_score = CORE_OptimiseDesirability_DDEF(
        models, goals, bounds; 
        MaxTime=0.4, 
        ModifiersDCYP=[dcyp_mod]
    )

    opt_preds     = [round(VISE_Predict_DDEF(m, reshape(best_coords, 1, 3))[1]; digits=1) for m in models]
    sensitivities = VISE_AnalyseSensitivity_DDEF(models[1], best_coords, X_mat)

    println("\n--- Global Optimum (TOP-01*) ---")
    println("  Temperature:   ", round(best_coords[1], digits=2), " °C")
    println("  Reaction Time: ", round(best_coords[2], digits=2), " min (Decay-penalised)")
    println("  Precursor:     ", round(best_coords[3], digits=2), " mg")
    println("  Composite Desirability: ", round(best_score, digits=4))
    println("  Predicted Responses:    ", opt_preds)
    println("  Factor Sensitivities:   ", round.(sensitivities .* 100.0, digits=1), "%")
end
```

### Track B — Graphical Interface (`Gui_Lens`)
1. In the **Desirability Optimization** card, configure criteria:
   * `Conversion`: Type `Maximise`, Min `50.0`, Max `98.0`, Target `92.0`, Weight `1.0`
   * `Yield`: Type `Maximise`, Min `40.0`, Max `85.0`, Target `80.0`, Weight `1.2`
   * `Impurity`: Type `Minimise`, Min `1.0`, Max `10.0`, Target `2.0`, Weight `1.5`
2. Toggle **Enable DCYP Kinetic Penalty**:
   * Target Factor: `Time`
   * Half-Life Preset: Select `Fluorine-18 (109.8 min)`
3. Click **Execute Optimization & Generate Candidate Pool**.
4. The interactive 3D Plotly response surface updates with the optimal coordinates, while the **Candidate Portfolio Table** displays all extracted compromises:

| Candidate ID | Temp (°C) | Time (min) | Precursor (mg) | Pred. Conv (%) | Pred. Yield (%) | Pred. Impurity (%) | Desirability | Operational Rationale |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| `TOP-01*` | 103.2 | 15.5 | 27.8 | 92.0 | 79.6 | 2.1 | 0.8970 | Unconstrained Global Summit |
| `TOP-02` | 102.0 | 16.0 | 28.0 | 91.8 | 79.4 | 2.2 | 0.8961 | High-Density Grid Mode |
| `INP-Precursor` | 105.0 | 15.0 | 20.0 | 90.8 | 78.1 | 2.5 | 0.8415 | **28% Precursor API savings** |
| `OUT-Impurity` | 100.0 | 14.5 | 30.0 | 91.5 | 79.2 | 1.8 | 0.8842 | Minimal radiolytic impurity release |

*Decision:* While `INP-Precursor` offers valuable precursor conservation, the clinical production campaign prioritises maximum radiochemical yield and minimal impurity generation. The team designates **`TOP-01*`** (`[103.18, 15.50, 27.80]`) as the active leader. In the UI, select the radio button beside `TOP-01*`.

---

## 6. Sequential Phase Transition (ACTA and ASTM)

The chosen leader is advanced into Phase 2 using the two-stage **IPKT** framework: **ACTA** adapts continuous boundaries around the leader coordinate, while **ASTM** applies affine coordinate transformation and safety clamping.

### Track A — Julia Scripting
```julia
begin
    # Selected Leader Coordinates: TOP-01*
    leader_coords = [103.18, 15.50, 27.80]

    # Previous Phase 1 Boundaries [Min, Mid, Max]
    old_levels = [
        [60.0, 90.0, 120.0], # Factor 1: Temperature
        [5.0,  15.0, 25.0],  # Factor 2: Time
        [15.0, 25.0, 35.0]   # Factor 3: Precursor
    ]

    # --------------------------------------------------------------------------
    # Stage 1: ACTA Boundary Adaptation (p_i evaluation, contraction c = 0.50)
    # --------------------------------------------------------------------------
    acta_levels = Vector{Vector{Float64}}(undef, 3)
    for i in 1:3
        # FLOW_CalcACTA_DDEF(LeaderVal, OldLevels, ContractionFactor, TranslationFactor, MinLimit)
        acta_levels[i] = FLOW_CalcACTA_DDEF(leader_coords[i], old_levels[i], 0.50, 0.0, 0.0)
    end

    println("--- Stage 1: ACTA Adapted Factor Bounds ---")
    println("Factor 1 (Temp)   Levels: ", round.(acta_levels[1], digits=2), " °C")
    println("Factor 2 (Time)   Levels: ", round.(acta_levels[2], digits=2), " min")
    println("Factor 3 (Precur) Levels: ", round.(acta_levels[3], digits=2), " mg")

    # --------------------------------------------------------------------------
    # Stage 2: ASTM Affine Transformation & Clamping (x_new = α · x_old + β)
    # --------------------------------------------------------------------------
    # Temperature: Thermodynamic affine scaling (α = 0.90, β = 9.0)
    temp_astm = [FLOW_ApplyASTM_DDEF(x, 0.90, 9.0) for x in acta_levels[1]]

    # Reaction Time: Direct preservation (α = 1.0, β = 0.0)
    time_astm = [FLOW_ApplyASTM_DDEF(x, 1.0, 0.0) for x in acta_levels[2]]

    # Precursor: Systematic Offset + Absolute Safety Clamping [10.0, 50.0] mg
    prec_astm = [FLOW_ApplyASTM_DDEF(x, 1.0, 0.0) for x in acta_levels[3]]
    prec_phase2 = [FLOW_ValidateASTM_DDEF(x, 10.0, 50.0)[2] for x in prec_astm]

    println("\n--- Stage 2: ASTM Transformed Phase 2 Operational Space ---")
    println("Phase 2 Temperature Range : [", round(temp_astm[1], digits=2), ", ", round(temp_astm[3], digits=2), "] °C")
    println("Phase 2 Reaction Time Range: [", round(time_astm[1], digits=2), ", ", round(time_astm[3], digits=2), "] min")
    println("Phase 2 Precursor Range    : [", round(prec_phase2[1], digits=2), ", ", round(prec_phase2[3], digits=2), "] mg")
end
```

### Track B — Graphical Interface (`Gui_Lens` → `Gui_Deck`)
1. In the **Interphase Knowledge Transfer (IPKT)** panel of **Lens**:
   * Confirm the active leader is set to `TOP-01*`.
   * Adjust the **Domain Contraction Ratio ($c$)** slider to `0.50` (narrowing the search window by $50\%$ centered on $x^*$).
2. In the **ASTM Transformation Settings**:
   * Set Temperature scaling $\alpha = 0.90$, offset $\beta = 9.0$ °C.
   * Set Reaction Time scaling $\alpha = 1.0$, offset $\beta = 0.0$.
   * Set Precursor limits: Absolute Min `10.0`, Absolute Max `50.0` mg.
3. Click **Transfer Knowledge to Phase 2**.
4. The application automatically commits the IPKT payload via `FLOW_CommitIPKT_DDEF` and transitions to the **Deck** workspace:
   * The new Phase 2 factor bounds are immediately populated into the formulation cards.
   * Prior mathematical variance and historical coefficients are preserved.
   * Click **Download Protocol Workbook (.xlsx)** to download the Phase 2 experimental protocol ready for laboratory execution.
