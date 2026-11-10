# Graphical Interface Guide

This guide provides an operational manual for using **DoECISORY.jl** via its interactive browser interface. 

All steps are managed through input forms, visual controls, and Microsoft Excel workbooks without requiring command-line interaction.

---

## 1. Application Startup

From a Julia environment or terminal:

```julia
using DoECISORY
launch()
```

Your default web browser will open the application at `http://127.0.0.1:8060`. The listening port is resolved by `CALL_ResolvePort_DDEF`, which checks for environment port overrides (`ENV["PORT"]`), cloud host indicators (`SPACE_ID`, defaulting to `7860` on Hugging Face Spaces), or defaults to `8060` for local sessions.

---

## 2. Experimental Design (Deck)

The **Deck** workspace manages formulation setup, mass balance auditing, and experimental matrix generation:

```
  [1. Define Factors] ───► Enter Factor Names, Physical Units, and [Min, Mid, Max] Levels
            │
  [2. Select Design]  ───► Choose Design Geometry (BB15, CD17, TL09, or DF14 Directional)
            │
  [3. Recipe Audit]   ───► Specify Precursor, Buffer, Excipients & Run Stoichiometric Check
            │
  [4. Export Excel]   ───► Click "Generate & Download Protocol Workbook (.xlsx)"
```

### 2.1. Defining Ingredients & Stoichiometry
1. In the **Formulation Configuration** card, input each reagent:
   * **Active Precursor (`VAR`):** Continuous variables subject to experimental variation.
   * **Fixed Salts/Buffers (`FIX`):** Constant formulation components.
   * **Diluent/Filler (`FILL`):** Solvent or carrier adjusted to maintain a constant total volume.
2. If working with short-lived radionuclides (e.g. $^{18}\text{F}$, $^{68}\text{Ga}$) or labile reagents, click the **Component Properties** modal on the component row to specify the physical half-life ($t_{1/2}$) alongside its unit (`Minutes`, `Hours`, `Days`). The kinetic decay engine activates automatically when a positive half-life is entered.
3. Click **Audit Mass Balance** to verify that concentration and total volume constraints are strictly satisfied.

### 2.2. Generating the Protocol Sheet
1. Select your target design geometry (e.g. `BB15 Box-Behnken`).
2. Click **Download Protocol Workbook**. An Excel file (`DoECISORY_Protocol.xlsx`) is downloaded containing pre-formatted, colour-coded worksheets ready for benchtop execution.

---

## 3. Data Analysis and Modelling (Lens)

Once laboratory runs are performed and analytical results obtained:

```
  [1. Upload Results] ───► Drag and drop the completed Excel workbook into the Lens Dropzone
            │
  [2. Set Objectives] ───► Define Min/Max targets, enable DCYP time-decay penalty if needed  
            │
  [3. View Report]    ───► Open the Statistical Summary Modal, review ANOVA and Q²
            │
  [4. 3D Inspection]  ───► Rotate 3D response surfaces, inspect equipotential contour slices
            │
  [5. Candidate Pool] ───► Select optimal leader (TOP-01, INP-Precursor, or OUT-Impurity)
```

### 3.1. Uploading Experimental Data
1. Navigate to the **Lens** tab.
2. Drag and drop your completed workbook. The system parses all input columns, measured outputs, and any recorded preparation/measurement latency times (`TIME_FORW_MINS_`, `TIME_REVE_MINS_`).
3. Precursor forward decay and analytical EOS reverse decay corrections are applied automatically via `VISE_ApplyFRDecay_DDEF` if configured.

### 3.2. Interactive Visualisation & Graph Navigation
* **Graph Index Quick Navigation:** Click any category badge above the canvas (`Pareto`, `Factor Slice`, `Factor Contour`, `Interaction Matrix`, `Diagnostic Fits`, `Feasible Space`, `Sweet Spot`) to jump directly to the first plot of that analytical group in the carousel.
* **3D Surface Rotation:** Click and drag on the 3D surface plot to inspect topography, response peaks, and saddle points.
* **Factor Slicing:** Use the slider below the graph to fix the third factor coordinate and evaluate 2D cross-sectional contours.

### 3.3. Statistical Diagnostics and Portfolio Export
1. Click **Analytical Summary** to open the full statistical report modal.
2. The modal displays:
   * Cross-validated $Q^2$ and $R^2$ values,
   * ANOVA $F$-tests and Lack-of-Fit indicators,
   * Variance Inflation Factors (VIF) to ensure absence of collinear distortion.
3. **Exporting Analytics:**
   * **Download Report (.txt):** Saves the complete 7-stage interpreted scientific report.
   * **Download Plot (.png):** Exports the currently active canvas as a high-resolution raster image ($960 \times 1080\,\text{px}$).
   * **Download Portfolio (.zip):** Generates a complete publication archive containing all 12 composite 145 mm SVG plates (`PLATE11` to `PLATE60`), the analytical report (`REPORT.txt`), and structured Excel data (`ANALYTICS.xlsx`).

---

## 4. Sequential Phase Transition (ACTA & ASTM)

Sequential advancement from Phase 1 to Phase 2 is managed through a guided **3-Step IPKT Transition Wizard Modal**:

1. **Step 1/3: Target Phase Selection (`lens-modal-wizard`):**
   * Define the destination experimental stage identifier (e.g. `Phase2`).
2. **Step 2/3: Candidate Leader Selection (`lens-modal-leader`):**
   * Review ranked solutions from the multi-criteria portfolio:
     * `TOP-01*`: Global unconstrained composite desirability summit (BBO metaheuristic solution).
     * `TOP-02`: High-density grid mode leader.
     * `INP-Precursor`: Green chemistry candidate with lowest precursor consumption within $\ge 90\%$ desirability.
     * `INP-Temperature`: Lowest thermal load candidate.
     * `OUT-Impurity`: Lowest radiolytic impurity candidate.
   * Select your target leader row.
3. **Step 3/3: Design Space Configuration (`lens-modal-preview`):**
   * **Global Contraction Ratio ($c$):** Set domain narrowing via slider ($1.0$, $0.75$, $0.50$ [default], $0.25$, or $0.10$).
   * **Global Translation ($\delta$):** Set search space translation shift in $[-1.0, 1.0]$ when near domain edges.
   * **Factor Slot Customisation:** For each active factor, choose between:
     * `Keep (ACTA)`: Retains the factor and applies standard ACTA contraction/translation.
     * `Scale (ASTM)`: Applies affine scaling ($x' = \alpha x + \beta$) and validates against physical limits $[L^{\text{abs}}, U^{\text{abs}}]$.
     * `Replace`: Drops an uninfluential variable and introduces a new physical process parameter.
   * **IPKT Diagnostic Canvas:** Visually verify the gold target bar relative to the gray baseline and red extrapolation fences ($\pm 2.0$).
   * Click **Commit Phase Transition & Download Phase 2 Protocol**. The updated workbook is generated with prior variance preserved.

---

## 5. UI to Engine Parameter Mapping

For researchers coordinating computational scripts and laboratory interfaces, the table below maps each graphical control in **Deck** and **Lens** to its underlying functional Julia routine:

| Graphical Control / Widget | Workspace | User Operation | Underlying Julia API Function | Engine Arguments & Structs |
| :--- | :--- | :--- | :--- | :--- |
| **Audit Mass Balance Button** | Deck | Verifies formulation conservation | [`MOLE_AuditQuick_DDEF`](@ref) | `TableData::AbstractVector`, `Vol::Float64`, `Conc::Float64` |
| **Design Geometry Dropdown** | Deck | Generates design matrix | [`CORE_GenDesign_DDEF`](@ref) | `Method::String, [FactorCount::Int=3]; Direction=[-1,-1,-1]` |
| **Factor Level Inputs [Min, Mid, Max]** | Deck | Maps coded space to units | [`CORE_MapLevels_DDEF`](@ref) | `X_coded::Matrix`, `FactorConfig::Vector{Dict}` |
| **Download Protocol Workbook Button** | Deck | Builds formatted `.xlsx` | [`FAST_WriteExcel_DDEF`](@ref) | `File::AbstractString`, `Updates::Dict{<:AbstractString, DataFrame}` |
| **Dataset Ingestion Dropzone** | Lens | Parses sheet & applies decay | [`FAST_ReadExcel_DDEF`](@ref) & [`VISE_ApplyFRDecay_DDEF`](@ref) | `df::DataFrame`, `decay_map::Dict` |
| **Model Type Selector** | Lens | Fits response surfaces | [`VISE_Regress_DDEF`](@ref) | `X_Raw::AbstractMatrix{Float64}, Y::AbstractVector{Float64}, ModelType::String` |
| **Analytical Summary Modal** | Lens | Displays 7-stage diagnostic report | [`VISE_GenSciReport_DDEF`](@ref) | `Res::AbstractDict` |
| **ANOVA & Lack-of-Fit Display** | Lens | Evaluates model adequacy | [`VISE_GenANOVATable_DDEF`](@ref) | `Model::AbstractDict`, `X_Raw::Any`, `Y_Raw::Any` |
| **DCYP Kinetic Penalty Toggle** | Lens | Enforces duration trade-off | [`CORE_ApplyDCYP_DDEF`](@ref) | `Score::Float64`, [`CORE_ModifierDCYP_DDES`](@ref), `x` |
| **Execute Optimization Button** | Lens | Solves multi-objective landscape | [`CORE_OptimiseDesirability_DDEF`](@ref) | `Models, Goals, X_Bounds; MaxTime, ModifiersDCYP` |
| **Candidate Portfolio Selector** | Lens | Extracts multi-criteria leaders | [`FLOW_GetCandidates_DDEF`](@ref) | `MasterFile, CurrentPhase` |
| **ACTA Contraction Slider ($c$)** | Lens | Adapts domain boundaries | [`FLOW_CalcACTA_DDEF`](@ref) | `Val::Real, L_Old::AbstractVector, Contraction::Real, Translation::Real, [MinLimit, MaxLimit]` |
| **ASTM Transformation Inputs** | Lens | Applies affine scaling and bounds validation | [`FLOW_ApplyASTM_DDEF`](@ref) | `Val::Real, Alpha::Real, Beta::Real` |
| **Commit Phase Transition Button** | Lens $\rightarrow$ Deck | Bridges sequential phase | [`FLOW_CommitIPKT_DDEF`](@ref) | `MasterFile, CurrentPhase, [LeaderID, Contraction, Method, Translation]; Direction, CustomConfig` |
| **Download Portfolio Button** | Lens | Builds 145 mm multi-plate ZIP | [`FAST_AssembleSvgPlate_DDEF`](@ref) | `Images::AbstractVector{<:AbstractString}, [LayoutType::Symbol=:Grid2x3]` |
| **Graph Index Badges** | Lens | Jumps carousel to plot group | Client-side DOM Trigger | `data-page`, `role="button"` |

