# ==============================================================================
# DoECISORY Precompilation Workload
# ==============================================================================
# Executed during sysimage creation to pre-compile critical code paths.
# This file is not a runtime script — it is consumed by PackageCompiler.
# ==============================================================================

using Pkg
const _PROJECT_ROOT = abspath(joinpath(@__DIR__, ".."))
if Pkg.project().path != joinpath(_PROJECT_ROOT, "Project.toml")
    Pkg.activate(_PROJECT_ROOT)
end

# Environment and transient directory configuration
let
    base_tmp = tempdir()
    wf_path  = endswith(rstrip(base_tmp, ['/', '\\']), "DoECISORY_Workforce") ? base_tmp : joinpath(base_tmp, "DoECISORY_Workforce")
    if !isdir(wf_path); mkpath(wf_path) end
    ENV["TMP"]    = wf_path
    ENV["TEMP"]   = wf_path
    ENV["TMPDIR"] = wf_path
    ENV["CHROME_USER_DATA_DIR"]   = wf_path
    ENV["CHROME_CRASH_DUMPS_DIR"] = wf_path
end
ENV["GKSwstype"]                 = "100"
ENV["JULIA_WEBIO_NOT_AVAILABLE"] = "1"
ENV["PLOTLY_KALEIDO_NO_SANDBOX"] = "1"

# --- Package Loading ---
using Logging
Logging.disable_logging(Logging.Warn)
using Dash
using DashBootstrapComponents
Logging.disable_logging(Logging.BelowMinLevel)

using DataFrames
using LoggingExtras

# --- Module Loading (Package Root & Submodules) ---
using DoECISORY
using DoECISORY.Sys_Fast
using DoECISORY.Lib_Core
using DoECISORY.Lib_Mole
using DoECISORY.Sys_Flow
using DoECISORY.Lib_Arts
using DoECISORY.Lib_Vise
using DoECISORY.Gui_Base
using DoECISORY.Gui_Deck
using DoECISORY.Gui_Lens

FAST_InitialiseWorkforce_DDEF()

# ==============================================================================
# WORKLOAD: Exercise every hot code path so PackageCompiler records the traces.
# ==============================================================================

println("[SYSIMAGE] Executing precompilation workload...")

# 1. Numeric utilities
FAST_SafeNum_DDEF("42.0")
FAST_SafeNum_DDEF(42)
FAST_SafeNum_DDEF(42.0)
FAST_SafeNum_DDEF(nothing)
FAST_SafeNum_DDEF("1,5")
FAST_SanitiseFilename_DDEF("Test_Project_Café_Naïve")
FAST_FormatDuration_DDEF(123.456)

# 2. JSON sanitisation
FAST_SanitiseJSON_DDEF(Dict("a" => 1.0, "b" => NaN, "c" => [1, 2, 3]))
FAST_SanitiseJSON_DDEF(DataFrame(A=[1,2], B=[3.0, NaN]))

# 3. Stoichiometry engine
names_mock  = String["A"]
mw_mock     = Float64[100.0]
ratios_mock = Float64[100.0]
units_mock  = String["%M"]
MOLE_CalcMass_DDEF(names_mock, mw_mock, ratios_mock, 5.0, 10.0, units_mock, 1.0; SuppressLog=true)

table_mock = [
    Dict("Name"=>"A", "MW"=>100.0, "Unit"=>"%M", "Type"=>"Variable", "Min"=>0.0, "Max"=>50.0, "Mid"=>25.0, "Rows"=>[[Dict("Unit"=>"%M")]]),
    Dict("Name"=>"W", "MW"=>18.0, "Unit"=>"%", "Type"=>"Filler", "Min"=>0.0, "Max"=>100.0, "Mid"=>50.0),
]
design_mock = fill(20.0, 5, 1)
MOLE_AuditBatch_DDEF(table_mock, design_mock, 5.0, 10.0)

# 4. Design matrix generation
X_dummy = Float64.(CORE_DesignBB15_DDEC)
Y_dummy = [50 + 10*r[1] + 5*r[2] - 2*r[3] + 8*r[1]^2 + 6*r[2]^2 + 4*r[3]^2 for r in eachrow(X_dummy)]

CORE_GenDesign_DDEF("BB15", 3)
CORE_GenDesign_DDEF("TL09", 3)
CORE_GenDesign_DDEF("CD17", 3)
CORE_GenDesign_DDEF("DF14", 3, [-1, -1, -1])

configs_bench = [Dict("Levels" => [-1.0, 0.0, 1.0]) for _ in 1:3]
CORE_MapLevels_DDEF(X_dummy, configs_bench)
CORE_CalcDEfficiency_DDEF(X_dummy)

# High-level design API synthesis
plan_pc = design(:bb15; factors=["X1", "X2", "X3"], levels=[(60.0, 90.0, 120.0), (5.0, 15.0, 25.0), (15.0, 25.0, 35.0)])
show(devnull, MIME("text/plain"), plan_pc)

# 5. Linear regression
names_in = ["X1", "X2", "X3"]
mod_lin = VISE_Regress_DDEF(X_dummy, vec(Y_dummy), "linear"; InNames=names_in)

# 6. Quadratic regression
mod_quad = VISE_Regress_DDEF(X_dummy, vec(Y_dummy), "quadratic"; InNames=names_in)

# 7. Grid search
bounds_dummy = [-1.0 1.0; -1.0 1.0; -1.0 1.0]
goal_dummy = Dict{String, Any}("Type"=>"Maximise", "Min"=>0.0, "Max"=>20.0, "Target"=>15.0, "Weight"=>1.0, "WeightVal" => 1.0)
mod_lin["Goal"]  = goal_dummy
mod_quad["Goal"] = goal_dummy

VISE_RunGridSearch_DDEF([mod_lin],  [goal_dummy], bounds_dummy; Steps=11)
VISE_RunGridSearch_DDEF([mod_quad], [goal_dummy], bounds_dummy; Steps=11)

# 8. BlackBoxOptim and DCYP
dcyp_dummy = [CORE_ModifierDCYP_DDES(2, log(2.0) / 109.8, "18F")]
CORE_OptimiseDesirability_DDEF([mod_lin],  [goal_dummy], bounds_dummy; MaxTime=0.1)
CORE_OptimiseDesirability_DDEF([mod_quad], [goal_dummy], bounds_dummy; MaxTime=0.1, ModifiersDCYP=dcyp_dummy)

# 9. Statistical diagnostics
VISE_GenANOVATable_DDEF(mod_quad, X_dummy, vec(Y_dummy))
VISE_TestNormality_DDEF(mod_quad, X_dummy, vec(Y_dummy))
VISE_AnalyseSensitivity_DDEF(mod_quad, [0.5, 0.5, 0.5], X_dummy)
VISE_CrossValidate_DDEF(X_dummy, vec(Y_dummy), "quadratic")
VISE_CrossValidate_DDEF(X_dummy, vec(Y_dummy), "linear")
VISE_TestLOF_DDEF(X_dummy, vec(Y_dummy))
VISE_CalcVIF_DDEF(X_dummy)

# 10. Interphase knowledge transfer (ACTA & ASTM)
acta_dummy = FLOW_CalcACTA_DDEF(0.0, [-1.0, 0.0, 1.0], 0.5, 0.0, -2.0)
FLOW_ApplyASTM_DDEF(acta_dummy[1], 0.9, 0.1)

# 11. Visualisation suite
try
    ARTS_Draw_DDEF(ARTS_PlotSurface_DDES(), mod_quad, X_dummy, [1, 2], ["X1", "X2"], "PC")
    ARTS_Draw_DDEF(ARTS_PlotContour_DDES(), mod_quad, X_dummy, [1, 2], ["X1", "X2"], "PC")
    ARTS_Draw_DDEF(ARTS_PlotTrend_DDES(),   mod_quad, X_dummy, vec(Y_dummy), [1], ["X1"], "PC")
    ARTS_Draw_DDEF(ARTS_PlotSlice_DDES(),   mod_quad, X_dummy, [1, 2], ["X1", "X2"], "PC")
    ARTS_Draw_DDEF(ARTS_PlotPareto_DDES(),  mod_quad, "PC", 0.9, 0.8)
    ARTS_Draw_DDEF(ARTS_PlotQQ_DDES(),      rand(15), "PC")
catch e
    println("[SYSIMAGE] Visualisation warmup skipped: ", e)
end

# 12. Analytical pipeline
pfx_in  = FAST_Data_DDEC.PRE_VAR
pfx_out = FAST_Data_DDEC.PRE_RESULT
df_mock = DataFrame()
df_mock[!, "$(pfx_in)X1"]  = X_dummy[:, 1]
df_mock[!, "$(pfx_in)X2"]  = X_dummy[:, 2]
df_mock[!, "$(pfx_in)X3"]  = X_dummy[:, 3]
df_mock[!, "$(pfx_out)Y1"] = Y_dummy

config_mock = Dict{String, Any}(
    "Ingredients" => [Dict("Name" => "X1"), Dict("Name" => "X2"), Dict("Name" => "X3")],
    "Outputs"     => [Dict("Name" => "Y1")],
    "Global"      => Dict("Volume" => 5.0, "Conc" => 10.0),
)
w_opts = Dict{String, Any}("MaxTime" => 0.1, "GridSteps" => 11)

try
    VISE_ExecuteInternal_DDEF(df_mock, config_mock, "PC_Lin", [goal_dummy], "linear";
        t_start=time(), Opts=w_opts, RenderMode=:Full)
    VISE_ExecuteInternal_DDEF(df_mock, config_mock, "PC_Quad", [goal_dummy], "quadratic";
        t_start=time(), Opts=w_opts, RenderMode=:Full)
catch e
    println("[SYSIMAGE] Pipeline warmup partial: ", e)
end

# 13. Dash application warmup
try
    launch(; start_server=false)
catch e
    println("[SYSIMAGE] UI warmup partial: ", e)
end

# 14. Design metrics and validation
CORE_CalcDesignMetrics_DDEF(VISE_ExpandDesign_DDEF(CORE_CodeMatrix_DDEF(X_dummy), "quadratic"))

# 15. Excel I/O paths
tmp_path = joinpath(tempdir(), "PC_test.xlsx")
try
    test_df = DataFrame(A=[1,2,3], B=[4.0, 5.0, 6.0])
    FAST_WriteExcel_DDEF(tmp_path, Dict("Sheet1" => test_df))
    FAST_ReadExcel_DDEF(tmp_path, "Sheet1")
    rm(tmp_path; force=true)
catch
end

# 16. Mole processing for design generation path
rows_mock = [
    Dict("Name"=>"Lipid",  "Role"=>"Variable", "MW"=>760.0, "Unit"=>"mg", "L1"=>5.0,  "L2"=>10.0, "L3"=>15.0, "Min"=>0.0, "Max"=>25.0, "IsRadioactive"=>false, "HalfLife"=>0.0, "HalfLifeUnit"=>"Hours"),
    Dict("Name"=>"Chol",   "Role"=>"Variable", "MW"=>386.0, "Unit"=>"mg", "L1"=>2.0,  "L2"=>6.0,  "L3"=>10.0, "Min"=>0.0, "Max"=>15.0, "IsRadioactive"=>false, "HalfLife"=>0.0, "HalfLifeUnit"=>"Hours"),
    Dict("Name"=>"PEG",    "Role"=>"Variable", "MW"=>2800.0,"Unit"=>"mg", "L1"=>1.0,  "L2"=>5.0,  "L3"=>7.0,  "Min"=>0.0, "Max"=>10.0,  "IsRadioactive"=>false, "HalfLife"=>0.0, "HalfLifeUnit"=>"Hours"),
]
try
    parsed = MOLE_ParseTable_DDEF(rows_mock)
    real_mat = CORE_MapLevels_DDEF(X_dummy, [Dict("Levels"=>[rows_mock[i]["L1"], rows_mock[i]["L2"], rows_mock[i]["L3"]]) for i in 1:3])
    MOLE_ProcessDesign_DDEF(real_mat, rows_mock, 5.0, 10.0)
catch
end

# 17. Scientific report generation
try
    VISE_GenSciReport_DDEF(Dict(
        "Vitals"       => Dict("D"=>0.95, "Condition"=>12.0, "LOF"=>0.35),
        "Models"       => [mod_quad],
        "OutNames"     => ["Y1"],
        "DisplayOutNames" => ["Y1"],
        "InNames"      => names_in,
        "DisplayInNames" => names_in,
        "BestPoint"    => [0.5, 0.5, 0.5],
        "BestScore"    => 0.95,
        "Sensitivities"=> [[0.4, 0.35, 0.25]],
    ))
catch
end

GC.gc()
println("[SYSIMAGE] Precompilation workload complete.")
