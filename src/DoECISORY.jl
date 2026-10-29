"""
    DoECISORY

An open-source, registered Julia package and stateless Dash web application developed for classical and 
adaptive Design of Experiments (DoE), Response Surface Methodology (RSM), stoichiometric verification,
and multi-objective optimisation. Executable across local workstations, cloud environments, the native 
Julia REPL, and reactive Pluto.jl notebooks, it integrates stoichiometric formulation balancing, 
multi-response statistical modelling, and interactive visual analytics within adaptive sequential workflows 
that contract and translate search spaces from screening to fine-tuning. Integrated first-order kinetic 
compensations correct for time-dependent reagent degradation: normalising pre-reaction preparation intervals, 
restoring end-of-synthesis (EOS) yields, and arbitrating reaction trade-offs via kinetic penalty profiling.

# Submodules
- `Lib_Core`: Algorithmic matrix generation, optimality metrics (D, A, G, I), and desirability optimisation.
- `Lib_Mole`: Stoichiometric mass conservation, unit conversions, and radiochemical decay kinetics.
- `Lib_Vise`: Ordinary least-squares regression, AIC model selection, ANOVA diagnostics, and scientific report generation.
- `Lib_Arts`: Visualisation routines built upon PlotlyJS with the Viridis colour palette.
- `Sys_Flow`: Inter-Phase Knowledge Transfer (IPKT) via Adaptive Contraction & Translation Algorithm (ACTA) and Affine Space Transformation Model (ASTM).
- `Sys_Fast`: Multi-threaded Excel data exchange, session caching, and workspace file management.
- `Gui_Base`, `Gui_Deck`, `Gui_Lens`: Interactive Dash web application components and page layouts.

# High-Level API Calls
- [`launch`](@ref): Launch the interactive web user interface in-process.
- [`design`](@ref): Algorithmic experimental design plan generation.
"""
module DoECISORY

# ==============================================================================
# DOECISORY - ROOT PACKAGE ENTRY POINT
# ==============================================================================
# Version:     v0.2.0  | October 2026
# Author:      Eren Selim GÖL, MPharm 
# Description: Package root for DoECISORY. Integrates submodules, exports 
#              public APIs, and provides high-level entry points.
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: SUBMODULE COMPONENT INTEGRATION
# ------------------------------------------------------------------------------

include("Sys_Fast.jl")
using .Sys_Fast

include("Lib_Core.jl")
using .Lib_Core

include("Lib_Mole.jl")
using .Lib_Mole

include("Sys_Flow.jl")
using .Sys_Flow

include("Lib_Arts.jl")
using .Lib_Arts

include("Lib_Vise.jl")
using .Lib_Vise

include("Gui_Base.jl")
using .Gui_Base

include("Gui_Deck.jl")
using .Gui_Deck

include("Gui_Lens.jl")
using .Gui_Lens

include("DoE_Call.jl")

# ------------------------------------------------------------------------------
# SECTION 2: PUBLIC INTERFACE EXPORTS
# ------------------------------------------------------------------------------
 
# DoE_Call Exports
export launch, design

# Submodule Accessors
export Sys_Fast, Lib_Core, Lib_Mole, Lib_Vise, Lib_Arts,
       Sys_Flow, Gui_Base, Gui_Deck, Gui_Lens

# Sys_Fast: Excel Data Exchange & Logging
export FAST_ReadExcel_DDEF, FAST_WriteExcel_DDEF,
       FAST_InitialiseMaster_DDEF, FAST_GenSmartName_DDEF,
       FAST_SafeNum_DDEF, FAST_Log_DDEF, FAST_Data_DDEC,
       FAST_AssembleSvgPlate_DDEF

# Lib_Core: Experimental Design Generation, Optimality & Desirability
export CORE_GenDesign_DDEF, CORE_BuildMatrix_DDEF,
       CORE_MapLevels_DDEF, CORE_CodeMatrix_DDEF,
       CORE_ExpandModelMatrix_DDEF, CORE_CalcDEfficiency_DDEF,
       CORE_CalcDesignMetrics_DDEF, CORE_OptimiseDesirability_DDEF,
       CORE_CalcDesirability_DDEF, CORE_CalcCriterion_DDEF, 
       CORE_ExtractGoal_DDEF, CORE_ValidateDesign_DDEF, 
       CORE_ExtractLeader_DDEF, CORE_ModifierDCYP_DDES,
       CORE_ApplyDCYP_DDEF 
       
# Lib_Mole: Stoichiometric Mass Balance & Radiochemical Kinetics
export MOLE_ParseTable_DDEF, MOLE_AuditQuick_DDEF, MOLE_CalcMass_DDEF,
       MOLE_ApproxEq_DDEF, MOLE_ValidatePhysicalUnit_DDEF,
       MOLE_AuditMatrix_DDEF, MOLE_AuditBatch_DDEF,
       MOLE_ValidateFeasibility_DDEF, MOLE_CalcRadioDecay_DDEF,
       MOLE_ProcessDesign_DDEF, MOLE_GetPercentageEquivalent_DDEF,
       MOLE_IsTimeUnit_DDEF, MOLE_ConvertToMinutes_DDEF

# Sys_Flow: Phase Transition & Iterative Space Exploration (ACTA / ASTM)
export FLOW_ApplyACTA_DDEF, FLOW_CalcACTA_DDEF,
       FLOW_ApplyASTM_DDEF, FLOW_ValidateASTM_DDEF,
       FLOW_AuditLeader_DDEF, FLOW_BuildIPKT_DDEF, FLOW_CommitIPKT_DDEF,
       FLOW_GetCandidates_DDEF, FLOW_WriteLeaders_DDEF, FLOW_RenderIPKT_DDEF,
       FLOW_AdvancePhase_DDEF, FLOW_GetPhaseType_DDEF

# Lib_Vise: Statistical Modelling, ANOVA & Scientific Reporting
export VISE_Regress_DDEF, VISE_SelectBestModel_DDEF, VISE_Predict_DDEF,
       VISE_CrossValidate_DDEF, VISE_CalcMetrics_DDEF,
       VISE_GenANOVATable_DDEF, VISE_TestLOF_DDEF, VISE_CalcVIF_DDEF,
       VISE_TestNormality_DDEF, VISE_RunGridSearch_DDEF, 
       VISE_AnalyseSensitivity_DDEF, VISE_GenSciReport_DDEF,
       VISE_ExportToExcel_DDEF, VISE_ApplyFRDecay_DDEF, VISE_ExtractDCYP_DDEF,
       VISE_Execute_DDEF, VISE_GetTermNames_DDEF, VISE_ExpandDesign_DDEF

# Lib_Arts: Plotly Visualisation Suite
export ARTS_RenderSurface_DDEF, ARTS_RenderContour_DDEF, ARTS_RenderSlice_DDEF,
       ARTS_RenderTrend_DDEF, ARTS_RenderPareto_DDEF, ARTS_RenderFit_DDEF,
       ARTS_RenderQQ_DDEF, ARTS_RenderResiduals_DDEF, ARTS_Render_DDEF,
       ARTS_RenderSensitivity_DDEF, ARTS_RenderDesignSpace_DDEF,
       ARTS_RenderFeasibleSpace_DDEF, ARTS_RenderOptimalZone_DDEF,
       ARTS_RenderSweetSpot_DDEF, ARTS_RenderCandidates_DDEF,
       ARTS_RenderInteractionMatrix_DDEF, ARTS_PlotPriority_DDEC
end