# Modular API Reference

To bridge the gap between modular software architecture and physical laboratory execution, this reference is organised into two complementary views:
1. **[The Experimental Pipeline (Chronological Workflow Map)](#the-experimental-pipeline-chronological-workflow-map):** A step-by-step guide matching standard laboratory protocol sequences.
2. **[Modular Architecture Reference](#modular-architecture-reference):** Complete function signatures, parameter descriptions, and docstrings grouped by library namespace (`Lib_Core`, `Lib_Mole`, `Lib_Vise`, `Lib_Arts`, `Sys_Flow`, `Sys_Fast`).

---

## The Experimental Pipeline (Chronological Workflow Map)

```
  ┌─────────────────────────────────────────────────────────────┐
  │ Stage 1: Formulation & Stoichiometric Audit      (Lib_Mole) │
  └──────────────────────────────┬──────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ Stage 2: Experimental Design & Optimality        (Lib_Core) │
  └──────────────────────────────┬──────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ Stage 3: Data Ingestion, Decay & Modelling       (Lib_Vise) │
  └──────────────────────────────┬──────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ Stage 4: Multi-Objective Optimisation & Pools    (Lib_Core) │
  └──────────────────────────────┬──────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ Stage 5: Interphase Knowledge Transfer (IPKT)    (Sys_Flow) │
  │          [Phase 1 Leader  ──►  Phase 2 Search Bounds]       │
  └──────────────────────────────┬──────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ Stage 6: Scientific Reporting & Visualisation    (Lib_Arts) │
  └─────────────────────────────────────────────────────────────┘
```

### Stage 1: Formulation Specification & Stoichiometric Auditing
*Pre-experimental verification of recipe mass balance, molar ratios, and concentration consistency.*

| Function | Primary Role | Laboratory Action |
| :--- | :--- | :--- |
| [`MOLE_ParseTable_DDEF`](@ref) | Component Parsing | Extracts active reagents (`VAR`), fixed salts (`FIX`), and diluents (`FILL`) from input dictionaries or tables. |
| [`MOLE_AuditQuick_DDEF`](@ref) | Mass Conservation Audit | Verifies that solute masses and diluent volumes sum strictly to the target concentration and total volume. |
| [`MOLE_CalcMass_DDEF`](@ref) | Mass Calculation | Computes mass from volume, concentration, and molecular weight. |
| [`MOLE_ProcessDesign_DDEF`](@ref) | Protocol Synthesis | Computes dynamic ingredient dispensing volumes for every single run across the experimental design matrix. |
| [`MOLE_ValidatePhysicalUnit_DDEF`](@ref) | Unit Verification | Confirms validity and compatibility of physical laboratory units (e.g. `mg`, `ug`, `mL`, `uL`, `mM`). |

---

### Stage 2: Experimental Design Generation & Information Optimality
*Constructing coded matrices, mapping physical laboratory units, and evaluating experimental efficiency.*

| Function | Primary Role | Laboratory Action |
| :--- | :--- | :--- |
| [`CORE_GenDesign_DDEF`](@ref) | Matrix Generator | Generates 3-factor coded matrices for Box-Behnken (`"BB15"`), Central Composite (`"CD17"`), Taguchi (`"TL09"`), or Fractional D-Optimal (`"DF14"`). |
| [`CORE_CalcDesignMetrics_DDEF`](@ref) | Optimality Diagnostics | Evaluates D-, A-, G-, and I-efficiencies and condition numbers $\kappa(X^T X)$ for linear, interaction, or quadratic models. |
| [`CORE_MapLevels_DDEF`](@ref) | Coordinate Mapping | Maps dimensionless coded levels $[-1, 0, 1]$ to physical equipment setpoints and experimental ranges. |
| [`CORE_CodeMatrix_DDEF`](@ref) | Level Normalisation | Transforms raw physical laboratory values back to dimensionless coded coordinates for orthogonal regression. |
| [`CORE_ValidateDesign_DDEF`](@ref) | Geometry Validation | Verifies matrix rank, balance, degree-of-freedom adequacy, and absence of degenerate rows. |

---

### Stage 3: Experimental Data Ingestion & Statistical Diagnostics
*Correcting pre/post latency delays, fitting response surfaces, ANOVA, and cross-validation.*

| Function | Primary Role | Laboratory Action |
| :--- | :--- | :--- |
| [`VISE_ApplyFRDecay_DDEF`](@ref) | Latency Normalisation | Corrects preparation delays ($\Delta t_{\text{forw}}$) and analytical delays ($\Delta t_{\text{reve}}$) using first-order rate kinetics. |
| [`MOLE_CalcRadioDecay_DDEF`](@ref) | Kinetic Decay Engine | Computes forward degradation ($\exp(-\lambda t)$) or reverse reference restoration ($\exp(+\lambda t)$). |
| [`VISE_Regress_DDEF`](@ref) | Response Surface Fitter | Fits Ordinary Least Squares (OLS) linear, 2-factor interaction, or full quadratic response surfaces. |
| [`VISE_SelectBestModel_DDEF`](@ref) | Parsimonious Model Selection | Evaluates AICc, BIC, and adjusted $R^2$ to select the most robust model hierarchy without overfitting. |
| [`VISE_GenANOVATable_DDEF`](@ref) | ANOVA & Hypothesis Testing | Computes Sequential and Adjusted Sum of Squares, mean squares, $F$-statistics, and $p$-values. |
| [`VISE_TestLOF_DDEF`](@ref) | Model Adequacy Diagnostic | Partitions residual sum of squares into Pure Error (replicates) and Lack of Fit. |
| [`VISE_CrossValidate_DDEF`](@ref) | Predictive Power Diagnostic | Evaluates Leave-One-Out cross-validated $Q^2$ and PRESS statistic to protect against model overparameterisation. |
| [`VISE_CalcVIF_DDEF`](@ref) | Multicollinearity Audit | Computes Variance Inflation Factors (VIF) to detect collinear distortions among predictor terms. |

---

### Stage 4: Multi-Objective Optimisation & Candidate Pool Generation
*Arbitrating competing quality targets, applying kinetic trade-off penalties, and isolating leader portfolios.*

| Function | Primary Role | Laboratory Action |
| :--- | :--- | :--- |
| [`CORE_OptimiseDesirability_DDEF`](@ref) | Continuous Metaheuristic | Solves multi-response Derringer-Suich desirability using `BlackBoxOptim` with optional DCYP kinetic penalty. |
| [`VISE_RunGridSearch_DDEF`](@ref) | Deterministic Grid Evaluation | Evaluates regularised composite desirability across $9,261$ to $68,921$ nodes with multi-threaded parallel execution. |
| [`CORE_ApplyDCYP_DDEF`](@ref) | Kinetic Penalty Operator | Penalises composite desirability $D$ against duration: $D_{\text{adj}} = D \cdot \exp(-\lambda \Delta t)$. |
| [`FLOW_GetCandidates_DDEF`](@ref) | Candidate Pool Extraction | Extracts Absolute Leaders (`TOP-01`, `TOP-02`), Input Minimisation (`INP-<Factor>`), and Output Specialisation (`OUT-<Response>`). |
| [`FLOW_AuditLeader_DDEF`](@ref) | Interactive Leader Selection | Queries or selects a specific leader strategy from the candidate pool for interphase advancement. |

---

### Stage 5: Interphase Knowledge Transfer (Phase 1 → Phase 2 Transition)
*Bridging sequential experimental phases, contracting search boundaries, and transferring historical variance.*

| Function | Primary Role | Laboratory Action |
| :--- | :--- | :--- |
| [`FLOW_CalcACTA_DDEF`](@ref) | Boundary Adaptation (ACTA) | Computes contracted or translated factor boundaries $[L^{\text{new}}, U^{\text{new}}]$ around the selected leader. |
| [`FLOW_ApplyACTA_DDEF`](@ref) | Domain Contracting Operator | Directly generates new continuous factor bounds using contraction ratio $c$ and translation offset $\delta$. |
| [`FLOW_ApplyASTM_DDEF`](@ref) | Affine Mapping (ASTM) | Scales and shifts physical factor boundaries ($x' = \alpha x + \beta$) for equipment migration or volume scaling. |
| [`FLOW_ValidateASTM_DDEF`](@ref) | Absolute Boundary Clamping | Enforces hard thermodynamic, physical, and safety boundaries $[L^{\text{abs}}, U^{\text{abs}}]$ onto adapted levels. |
| [`FLOW_BuildIPKT_DDEF`](@ref) | Master Transfer Protocol | Builds the unified IPKT transition payload transferring active factors, fixed settings, and response targets from Phase 1 to Phase 2. |
| [`FLOW_AdvancePhase_DDEF`](@ref) | Phase Advancement | Dispatch-driven progression from current experimental stage to subsequent phase (e.g. Phase 1 → Phase 2). |

---

### Stage 6: Scientific Reporting, Visualisation & Spreadsheet I/O
*Generating academic dossiers, interactive 3D response surfaces, and lossless Excel protocol sheets.*

| Function | Primary Role | Laboratory Action |
| :--- | :--- | :--- |
| [`VISE_GenSciReport_DDEF`](@ref) | Academic Dossier Generator | Compiles a 7-stage interpreted scientific report ready for publication or regulatory filing. |
| [`ARTS_RenderSurface_DDEF`](@ref) | 3D Response Surface | Renders interactive Plotly 3D response surfaces with Viridis topography and optimal coordinate markers. |
| [`ARTS_RenderContour_DDEF`](@ref) | 2D Equipotential Contours | Plots 2D contour projections with fixed-factor slicing. |
| [`ARTS_RenderPareto_DDEF`](@ref) | Pareto Effect Chart | Displays standardised model coefficients sorted by statistical significance. |
| [`ARTS_RenderResiduals_DDEF`](@ref) | Diagnostic Residual Plot | Visualises studentised residuals versus fitted values to diagnose homoscedasticity. |
| [`ARTS_RenderFeasibleSpace_DDEF`](@ref) | Feasible Space Projection | Plots operational regions satisfying all individual response criteria ($D \ge 0.05$). |
| [`ARTS_RenderOptimalZone_DDEF`](@ref) | Optimal Zone Projection | Plots near-optimal operating regions within 10% tolerance of summit desirability ($D \ge 0.90 \times D_{\max}$). |
| [`ARTS_RenderSweetSpot_DDEF`](@ref) | Sweet Spot Projection | Plots primary operating cores within 5% tolerance of summit desirability ($D \ge 0.95 \times D_{\max}$). |
| [`FAST_WriteExcel_DDEF`](@ref) | Protocol Export | Writes multi-tab formatted Excel workbooks preserving cell types, styles, and formulas. |
| [`FAST_ReadExcel_DDEF`](@ref) | Protocol Ingestion | Safely reads completed laboratory spreadsheets into DataFrames with strict type casting. |
| [`FAST_AssembleSvgPlate_DDEF`](@ref) | Composite Plate Generator | Assembles individual vector panels into standardised 145 mm multi-panel SVG plates. |

---

## Modular Architecture Reference

DoECISORY.jl provides both high-level and low-level APIs for programmatic execution. Currently, `design` serves as the primary high-level endpoint for experimental planning, with further high-level APIs planned for future releases. For direct low-level control, routines follow the symbol template:

```julia
[DOMAIN]_[PascalCase-Action/Entity]_DDE[F|S|T|C]
```

Here: `[DOMAIN]` identifies the subsystem, `[PascalCase-Action/Entity]` describes the operational action or data entity, `DDE` marks a DoECISORY-defined construct, and the terminal letter denotes functions (`_DDEF`), structs (`_DDES`), abstract types (`_DDET`), or constants (`_DDEC`) (e.g. `VISE_AnalyseSensitivity_DDEF` and `CORE_ModifierDCYP_DDES`).

---

### High-Level Public Entry Points

```@docs
launch
design
```

---

## Experimental Design & Optimality (`Lib_Core`)

```@docs
CORE_GenDesign_DDEF
CORE_BuildMatrix_DDEF
CORE_MapLevels_DDEF
CORE_CodeMatrix_DDEF
CORE_ExpandModelMatrix_DDEF
CORE_CalcDEfficiency_DDEF
CORE_CalcDesignMetrics_DDEF
CORE_CalcCriterion_DDEF
CORE_OptimiseDesirability_DDEF
CORE_CalcDesirability_DDEF
CORE_ExtractGoal_DDEF
CORE_ValidateDesign_DDEF
CORE_ExtractLeader_DDEF
CORE_ModifierDCYP_DDES
CORE_ApplyDCYP_DDEF
```

---

## Stoichiometry & Mass Conservation (`Lib_Mole`)

```@docs
MOLE_ParseTable_DDEF
MOLE_AuditQuick_DDEF
MOLE_CalcMass_DDEF
MOLE_ApproxEq_DDEF
MOLE_ValidatePhysicalUnit_DDEF
MOLE_AuditMatrix_DDEF
MOLE_AuditBatch_DDEF
MOLE_ValidateFeasibility_DDEF
MOLE_CalcRadioDecay_DDEF
MOLE_ProcessDesign_DDEF
MOLE_GetPercentageEquivalent_DDEF
MOLE_IsTimeUnit_DDEF
MOLE_ConvertToMinutes_DDEF
```

---

## Statistical Modelling & ANOVA (`Lib_Vise`)

```@docs
VISE_Regress_DDEF
VISE_SelectBestModel_DDEF
VISE_Predict_DDEF
VISE_CrossValidate_DDEF
VISE_CalcMetrics_DDEF
VISE_GenANOVATable_DDEF
VISE_TestLOF_DDEF
VISE_CalcVIF_DDEF
VISE_TestNormality_DDEF
VISE_RunGridSearch_DDEF
VISE_AnalyseSensitivity_DDEF
VISE_GenSciReport_DDEF
VISE_ExportToExcel_DDEF
VISE_ApplyFRDecay_DDEF
VISE_ExtractDCYP_DDEF
VISE_Execute_DDEF
VISE_GetTermNames_DDEF
VISE_ExpandDesign_DDEF
```

---

## Response Surface Visualisation (`Lib_Arts`)

```@docs
ARTS_RenderSurface_DDEF
ARTS_RenderContour_DDEF
ARTS_RenderSlice_DDEF
ARTS_RenderTrend_DDEF
ARTS_RenderPareto_DDEF
ARTS_RenderFit_DDEF
ARTS_RenderQQ_DDEF
ARTS_RenderResiduals_DDEF
ARTS_RenderSensitivity_DDEF
ARTS_RenderDesignSpace_DDEF
ARTS_RenderFeasibleSpace_DDEF
ARTS_RenderOptimalZone_DDEF
ARTS_RenderSweetSpot_DDEF
ARTS_RenderCandidates_DDEF
ARTS_RenderInteractionMatrix_DDEF
ARTS_Render_DDEF
ARTS_PlotPriority_DDEC
```

---

## Workflow Transitions (`Sys_Flow`)

```@docs
FLOW_ApplyACTA_DDEF
FLOW_CalcACTA_DDEF
FLOW_ApplyASTM_DDEF
FLOW_ValidateASTM_DDEF
FLOW_AuditLeader_DDEF
FLOW_BuildIPKT_DDEF
FLOW_CommitIPKT_DDEF
FLOW_GetCandidates_DDEF
FLOW_WriteLeaders_DDEF
FLOW_RenderIPKT_DDEF
FLOW_AdvancePhase_DDEF
FLOW_GetPhaseType_DDEF
```

---

## File Exchange & System Utilities (`Sys_Fast`)

```@docs
FAST_ReadExcel_DDEF
FAST_WriteExcel_DDEF
FAST_InitialiseMaster_DDEF
FAST_GenSmartName_DDEF
FAST_SafeNum_DDEF
FAST_Log_DDEF
FAST_Data_DDEC
FAST_AssembleSvgPlate_DDEF
```
