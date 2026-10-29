using Test

using Dash
using DashBootstrapComponents
using PlotlyJS
using DataFrames
using JSON3
using Base64
using Printf
using LinearAlgebra
using Statistics
using Dates

using DoECISORY
using DoECISORY.Sys_Fast
using DoECISORY.Lib_Core
using DoECISORY.Lib_Mole
using DoECISORY.Sys_Flow
using DoECISORY.Lib_Vise
using DoECISORY.Lib_Arts
using DoECISORY.Gui_Base
using DoECISORY.Gui_Deck
using DoECISORY.Gui_Lens

# ==============================================================================
# DOECISORY TEST METRICS & TRACKING HARNESS
# ==============================================================================
mutable struct GroupTracker
    name::String
    total::Int
    passed::Int
    failed::Int
    duration::Float64
end

const TRACKER = Dict{String, GroupTracker}(
    "G1" => GroupTracker("[G1] Sys_Fast Infrastructure, Resilience & Excel I/O", 0, 0, 0, 0.0),
    "G2" => GroupTracker("[G2] Lib_Core Optimal Matrices, D-A-G-I & Desirability", 0, 0, 0, 0.0),
    "G3" => GroupTracker("[G3] Lib_Mole Stoichiometry, Mass Invariance & Kinetics", 0, 0, 0, 0.0),
    "G4" => GroupTracker("[G4] Lib_Vise Statistical Modelling, OLS & Tournament", 0, 0, 0, 0.0),
    "G5" => GroupTracker("[G5] Lib_Arts Academic Visualisation & Viridis Engine", 0, 0, 0, 0.0),
    "G6" => GroupTracker("[G6] Sys_Flow ACTA Adaptive Transitions & Space Map", 0, 0, 0, 0.0),
    "G7" => GroupTracker("[G7] Gui Presentation Shell, Dispatch & Runtime Motor", 0, 0, 0, 0.0)
)

const GLOBAL_TEST_COUNT = Ref(0)
const GLOBAL_PASS_COUNT = Ref(0)

const TEST_TITLES = String[
    # Group 1 (1-15)
    "Scientific, decimal, and malformed numeric parsing",
    "Filename sanitisation and path traversal defence",
    "Universal DataID and unique hash code extraction",
    "Smart protocol filename generation and extraction",
    "Condition number formatting and GUI colour tokens",
    "Configuration cache isolation and update roundtrip",
    "Input parameter sanitisation and anomaly warnings",
    "DataFrame column rounding and precision retention",
    "Multi-sheet Excel workbook write with dirty data",
    "Sheet structure and data schema layout validation",
    "DataFrame column name normalisation and formatting",
    "Configuration cache invalidation on write events",
    "Transient workforce file deletion and data cleanup",
    "Transient workspace file path isolation routines",
    "Transient workforce workspace directory lifecycle",
    # Group 2 (16-25)
    "Experimental design matrix generation and checks",
    "Directional D-optimal DF14 matrix structure check",
    "Physical parameter level mapping from coded space",
    "Model matrix expansion for Linear-Quadratic forms",
    "Algorithmic D, A, G, and I optimality profiling",
    "Design matrix singularity, anomaly, and duplicates",
    "Desirability formulation, goals, and boundaries",
    "Desirability weighting curvature and sensitivity",
    "Multi-objective interior Pareto trade-off search",
    "Radiochemical DCYP structure and incubation decay",
    # Group 3 (26-35)
    "Recipe target masses and molar ratio conservation",
    "Stoichiometric filler auto-balance and overflows",
    "Stoichiometric validation rules and factor audits",
    "Multi-unit stoichiometric percentage equivalence",
    "Design matrix stoichiometric feasibility auditing",
    "Physical recipe matrix processing and batch audits",
    "Mixed-unit stoichiometric recipe gravimetric audit",
    "Forward and reverse radiochemical decay kinetics",
    "Physical and temporal unit conversion validation",
    "Physical unit taxonomy and ingredient role types",
    # Group 4 (36-65)
    "Quadratic response surface regression matrix fit",
    "Model parameter count and term names generation",
    "Index clamping and numeric boundary validation",
    "Matrix preparation helpers and layout reshaping",
    "Collinear input resilience and metric fallbacks",
    "Regression result struct conversion to dictionary",
    "Linear multi-variable regression model matrix fit",
    "Adjusted R-squared relation and coefficient bounds",
    "Cross-validation Q-squared predictive computation",
    "Outlier leverage detection in cross-validation set",
    "ANOVA sum of squares variance partitioning check",
    "ANOVA lack of fit and pure error partition checks",
    "Lack of fit evaluation without experimental repeat",
    "Variance inflation factor collinearity screening",
    "Regression residual normality distribution tests",
    "Response surface model sensitivity gradient sweep",
    "Statistical model response point prediction check",
    "Model selection tournament via corrected AICc score",
    "Radio-decay DCYP modifier extraction and toggles",
    "Forward and reverse radio-decay matrix correction",
    "High-density grid search within parameter bounds",
    "Underdetermined regression system error resilience",
    "Experimental matrix ingestion with missing values",
    "Multi-response regression ensemble model training",
    "Scientific core optimization execution pipelines",
    "Markdown scientific synthesis report generations",
    "Markdown table alignment and token weight ratings",
    "Column name resolution and DataFrame widening ops",
    "Excel multi-sheet execution and export workflows",
    "Phase data extraction and row partition filters",
    # Group 5 (66-75)
    "Pareto effect chart and significance threshold",
    "Fit diagnostic observed versus predicted plots",
    "Residual normality QQ and fitted value plot maps",
    "Factor sensitivity gradient bar chart rendering",
    "Response surface 2D contour and slice profiles",
    "Factor interaction matrix and trend line plots",
    "3D response surface mesh and camera projections",
    "Design sweet spot space and candidate zone maps",
    "Visual orchestrator multi-mode render pipelines",
    "Viridis colour scale, hex alpha, and grid maths",
    # Group 6 (76-85)
    "ASTM affine transformation and boundary clamping",
    "ASTM boundary status and telemetry alert mapping",
    "Leader proximity evaluation and threshold checks",
    "Adaptive range contraction and clamping via ACTA",
    "Multi-variable simultaneous ACTA range profiling",
    "Candidate extraction and leader ranking from file",
    "Next phase IPKT configuration build and contract",
    "Phase transition fallback and missing data audit",
    "Phase transition visualisation and chart payload",
    "Phase parameter inheritance and commitment audit",
    # Group 7 (86-100)
    "Academic mini vital card layout and token mapping",
    "System and scientific audit dashboard tree layout",
    "Deck and Lens primary application view layouts",
    "Headless Dash application initialisation routine",
    "Multi-module Dash callback registration pipeline",
    "Multi-page URL router dispatch and view resolution",
    "Single public entry point and launch call contract",
    "Chemical formulation grid default row definition",
    "Factor row import mapping and data normalisation",
    "Transition slot card layout and extraction audit",
    "Slot configuration modification and level update",
    "Leaderboard Dash HTML component table generation",
    "State payload sanitisation and base64 roundtrip",
    "Clientside Plotly figure JSON schema serialization",
    "End-to-end multi-phase workflow integration audit"
]

function track_eval(group_key::String, condition::Bool)
    t = TRACKER[group_key]
    t.total += 1
    GLOBAL_TEST_COUNT[] += 1
    if condition
        t.passed += 1
        GLOBAL_PASS_COUNT[] += 1
    else
        t.failed += 1
    end

    cur_t = GLOBAL_TEST_COUNT[]
    cur_p = GLOBAL_PASS_COUNT[]

    status_tag = condition ? "\e[32m[PASS]\e[0m" : "\e[31m[FAIL]\e[0m"
    ratio_tag  = condition ? @sprintf("\e[32m[%3d/%3d]\e[0m", cur_p, cur_t) : @sprintf("\e[31m[%3d/%3d]\e[0m", cur_p, cur_t)
    title_str  = cur_t <= length(TEST_TITLES) ? TEST_TITLES[cur_t] : "Verification"

    @printf("\e[36m[VERIFY  #%03d]\e[0m \e[33m[%s]\e[0m %-52s  %s %s\n", cur_t, group_key, title_str, status_tag, ratio_tag)
    flush(stdout)

    return condition
end

macro track(group_sym, expr)
    grp_str = string(group_sym)
    line = __source__.line
    return quote
        cond = try
            $(esc(expr))
        catch err
            println("[ERROR in ", $grp_str, " L", $line, "]: ", err)
            false
        end
        track_eval($grp_str, cond)
        if !cond
            println("[FAIL in ", $grp_str, " L", $line, "]: ", $(QuoteNode(expr)))
        end
        @test cond
    end
end

const SUITE_START_TIME = time()

@testset "DoECISORY Test Suite" begin
    # ==========================================================================
    # GROUP 1: Sys_Fast Infrastructure, Resilience & Excel I/O (15 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G1"
    Sys_Fast.FAST_InitialiseWorkforce_DDEF()

    t_g1 = time()
    @testset "Group 1: Sys_Fast Infrastructure, Resilience & Excel I/O" begin
        # 1: Scientific, decimal, and malformed numeric parsing
        @track G1 isapprox(Sys_Fast.FAST_SafeNum_DDEF("1.25e-3"), 0.00125; atol=1e-6) &&
                  Sys_Fast.FAST_SafeNum_DDEF("12,7") == 12.7 &&
                  Sys_Fast.FAST_SafeNum_DDEF("-0,0035") == -0.0035 &&
                  Sys_Fast.FAST_SafeNum_DDEF(true) == 1.0 &&
                  Sys_Fast.FAST_SafeNum_DDEF(false) == 0.0 &&
                  Sys_Fast.FAST_SafeNum_DDEF(42) == 42.0 &&
                  Sys_Fast.FAST_SafeNum_DDEF(3.1415) == 3.1415 &&
                  Sys_Fast.FAST_SafeNum_DDEF(1.5f0) == 1.5 &&
                  Sys_Fast.FAST_SafeNum_DDEF(Int32(7)) == 7.0 &&
                  isnan(Sys_Fast.FAST_SafeNum_DDEF(:any_sym)) &&
                  isnan(Sys_Fast.FAST_SafeNum_DDEF("NaN")) &&
                  all(isnan, [
                      Sys_Fast.FAST_SafeNum_DDEF(nothing),
                      Sys_Fast.FAST_SafeNum_DDEF(missing),
                      Sys_Fast.FAST_SafeNum_DDEF("  -  "),
                      Sys_Fast.FAST_SafeNum_DDEF("-"),
                      Sys_Fast.FAST_SafeNum_DDEF("nan"),
                      Sys_Fast.FAST_SafeNum_DDEF("abc"),
                      Sys_Fast.FAST_SafeNum_DDEF(""),
                      Sys_Fast.FAST_SafeNum_DDEF("   "),
                      Sys_Fast.FAST_SafeNum_DDEF("1.2.3")
                  ])

        # 2: Filename sanitisation and path traversal defence
        @track G1 Sys_Fast.FAST_SanitiseFilename_DDEF("öğrenci_işleri.xlsx") == "ogrenci_isleri.xlsx" &&
                  Sys_Fast.FAST_SanitiseFilename_DDEF("test/file!name.csv") == "test_file_name.csv" &&
                  Sys_Fast.FAST_SanitiseFilename_DDEF("secret/system.xlsx") == "secret_system.xlsx"

        # 3: Universal DataID and unique hash code extraction
        @track G1 Sys_Fast.FAST_ExtractDataID_DDEF(Dict("dataid" => "HASH_123")) == "HASH_123" &&
                  Sys_Fast.FAST_ExtractDataID_DDEF("HASH_456") == "HASH_456" &&
                  Sys_Fast.FAST_ExtractDataID_DDEF(Dict("DataID" => "HASH_789")) == "HASH_789" &&
                  Sys_Fast.FAST_ExtractDataID_DDEF(Dict("content" => "HASH_CNT")) == "HASH_CNT" &&
                  Sys_Fast.FAST_ExtractDataID_DDEF(nothing) == "" &&
                  Sys_Fast.FAST_ExtractDataID_DDEF("") == "" &&
                  Sys_Fast.FAST_ExtractDataID_DDEF(Dict()) == "" &&
                  Sys_Fast.FAST_ExtractDataID_DDEF(999) == "" &&
                  Sys_Fast.FAST_ExtractDataID_DDEF([1, 2]) == ""

        # 4: Smart protocol filename generation and extraction
        let name = Sys_Fast.FAST_GenSmartName_DDEF("DoECISORY", "Phase1", "Design"),
            name_noext = Sys_Fast.FAST_GenSmartName_DDEF("DoECISORY", "Phase1", "Design", ""),
            name_proj  = Sys_Fast.FAST_GenSmartName_DDEF("CustomProj", "Phase2", "Check"),
            name_empty = Sys_Fast.FAST_GenSmartName_DDEF("", "Phase1", "Check"),
            name_lower = Sys_Fast.FAST_GenSmartName_DDEF("doecisory", "Phase1", "Check"),
            base_ext   = Sys_Fast.FAST_ExtractProjectName_DDEF("arbitrary_file.xlsx"),
            ext_nil1   = Sys_Fast.FAST_ExtractProjectName_DDEF(""),
            ext_nil2   = Sys_Fast.FAST_ExtractProjectName_DDEF("."),
            svg_dummy  = ["data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="],
            t_dummy    = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_DUMMY_PLATE.png"),
            _          = write(t_dummy, "dummy_png_bytes"),
            plate_file = Sys_Fast.FAST_AssembleSvgPlate_DDEF([t_dummy], :Strip1x3),
            _          = Sys_Fast.FAST_CleanTransient_DDEF(t_dummy),
            plate_raw  = Sys_Fast.FAST_AssembleSvgPlate_DDEF(["pure_base64_sample"], :Strip1x3),
            plate_6    = Sys_Fast.FAST_AssembleSvgPlate_DDEF(svg_dummy, :Grid2x3),
            plate_9    = Sys_Fast.FAST_AssembleSvgPlate_DDEF(svg_dummy, :Grid3x3),
            plate_3    = Sys_Fast.FAST_AssembleSvgPlate_DDEF(svg_dummy, :Strip1x3)
            @track G1 (startswith(name, "DoECISORY_") || startswith(name, "DDE_")) && occursin("P1_Design_", name) &&
                      Sys_Fast.FAST_ExtractProjectName_DDEF(name) == "DoECISORY" &&
                      !endswith(name_noext, ".xlsx") && occursin("CustomProj", name_proj) && base_ext == "arbitrary_file" &&
                      startswith(name_empty, "DoECISORY_DoECISORY_") && startswith(name_lower, "DoECISORY_DoECISORY_") &&
                      isempty(ext_nil1) && isempty(ext_nil2) &&
                      occursin("width=\"145mm\" height=\"115.200mm\"", plate_6) &&
                      occursin("width=\"145mm\" height=\"172.800mm\"", plate_9) &&
                      occursin("width=\"145mm\" height=\"57.600mm\"", plate_3) &&
                      occursin("<text x=\"1.988\" y=\"4.528\"", plate_6) &&
                      occursin("font-family=\"Helvetica, Arial, sans-serif\"", plate_6) &&
                      occursin("viewBox=\"18 0 450 540\"", plate_6) &&
                      occursin("width=\"46.333\" height=\"55.600\"", plate_6) &&
                      occursin("ZHVtbXlfcG5nX2J5dGVz", plate_file) && occursin("pure_base64_sample", plate_raw)
        end

        # 5: Condition number formatting and GUI colour tokens
        let c1 = Sys_Fast.FAST_FormatConditionNumber_DDEF(41.25),
            c2 = Sys_Fast.FAST_FormatConditionNumber_DDEF(Inf),
            c3 = Sys_Fast.FAST_FormatConditionNumber_DDEF(NaN),
            c4 = Sys_Fast.FAST_FormatConditionNumber_DDEF(500.0),
            c5 = Sys_Fast.FAST_FormatConditionNumber_DDEF(5000.0),
            c6 = Sys_Fast.FAST_FormatConditionNumber_DDEF(50000.0),
            c7 = Sys_Fast.FAST_FormatConditionNumber_DDEF(missing),
            c8 = Sys_Fast.FAST_FormatConditionNumber_DDEF(1e15),
            c9 = Sys_Fast.FAST_FormatConditionNumber_DDEF("invalid_string"),
            c10 = Sys_Fast.FAST_FormatConditionNumber_DDEF(50.0),
            c11 = Sys_Fast.FAST_FormatConditionNumber_DDEF(nothing),
            num_ok = Sys_Fast.FAST_IsNumericInput_DDEF(42) && Sys_Fast.FAST_IsNumericInput_DDEF("12,7") &&
                     !Sys_Fast.FAST_IsNumericInput_DDEF(nothing) && !Sys_Fast.FAST_IsNumericInput_DDEF(missing) &&
                     !Sys_Fast.FAST_IsNumericInput_DDEF("abc") && !Sys_Fast.FAST_IsNumericInput_DDEF("") &&
                     !Sys_Fast.FAST_IsNumericInput_DDEF(NaN) && !Sys_Fast.FAST_IsNumericInput_DDEF(:sym),
            pop_ok = Sys_Fast.FAST_IsPopulatedInput_DDEF("ok") && Sys_Fast.FAST_IsPopulatedInput_DDEF(100) &&
                     !Sys_Fast.FAST_IsPopulatedInput_DDEF(nothing) && !Sys_Fast.FAST_IsPopulatedInput_DDEF(missing) &&
                     !Sys_Fast.FAST_IsPopulatedInput_DDEF("   ") && Sys_Fast.FAST_IsPopulatedInput_DDEF([1, 2]),
            fmt_fixed = Sys_Fast.FAST_FormatColumn_DDEF(Val(:Fixed), "Buffer"),
            fmt_fill  = Sys_Fast.FAST_FormatColumn_DDEF(Val(:Filler), "Water"),
            fmt_act   = Sys_Fast.FAST_FormatColumn_DDEF(Val(:Actual), "Yield"),
            fmt_gen   = Sys_Fast.FAST_FormatColumn_DDEF(Val(:Custom), "Other"),
            cfg_dict  = Sys_Fast.FAST_ReadConfig_DDEF(Dict("A" => 1)),
            cfg_nil   = Sys_Fast.FAST_ReadConfig_DDEF(123),
            w_nil1    = Sys_Fast.FAST_WriteExcel_DDEF(nothing, "Sheet", DataFrame(A=[1])),
            w_nil2    = Sys_Fast.FAST_WriteExcel_DDEF(nothing, Dict("Sheet" => DataFrame(A=[1])))
            @track G1 c1[1] == "41.2" && c1[3] == "var(--colour-chr4-tongre)" && c2[1] == "Singular" && c2[3] == "var(--colour-chr0-huered)" &&
                      c3[1] == "N/A" && c3[3] == "var(--colour-val3-darlow)" && occursin("Well-Conditioned", c4[2]) &&
                      occursin("Moderate", c5[2]) && occursin("Ill-Conditioned", c6[2]) && c7[1] == "N/A" && c8[1] == "Singular" &&
                      c9[1] == "N/A" && occursin("Ideal", c10[2]) && c11[1] == "N/A" && num_ok && pop_ok &&
                      fmt_fixed == "FIXED_Buffer" && fmt_fill == "FILL_Water" && fmt_act == "ACTUAL_Yield" &&
                      fmt_gen == "Other" && cfg_dict["A"] == 1 && isempty(cfg_nil) && isnothing(w_nil1) && isnothing(w_nil2)
        end

        # 6: Configuration cache isolation and update roundtrip
        let cfg_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_CFG_TEST.xlsx"),
            cfg_bad_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_CFG_BAD.xlsx")
            Sys_Fast.FAST_CleanTransient_DDEF(cfg_file)
            Sys_Fast.FAST_CleanTransient_DDEF(cfg_bad_file)
            df_init = DataFrame("PARAMETER" => ["MasterConfig"], "VALUE_JSON" => [JSON3.write(Dict("Phase" => "Phase1", "Volume" => 10.0))])
            Sys_Fast.FAST_WriteExcel_DDEF(cfg_file, Dict(Sys_Fast.FAST_Data_DDEC.SHEET_CONFIG => df_init))
            df_bad_cfg = DataFrame("PARAMETER" => ["MasterConfig"], "VALUE_JSON" => ["PK_binary_mock_data"])
            Sys_Fast.FAST_WriteExcel_DDEF(cfg_bad_file, Dict(Sys_Fast.FAST_Data_DDEC.SHEET_CONFIG => df_bad_cfg))
            cfg_bad = Sys_Fast.FAST_ReadConfig_DDEF(cfg_bad_file)
            cfg1 = Sys_Fast.FAST_ReadConfig_DDEF(cfg_file)
            cfg1["Volume"] = 25.0
            cfg2 = Sys_Fast.FAST_ReadConfig_DDEF(cfg_file)
            upd_ok = Sys_Fast.FAST_UpdateConfig_DDEF(cfg_file, Dict("Phase" => "Phase1", "Volume" => 50.0))
            cfg3 = Sys_Fast.FAST_ReadConfig_DDEF(cfg_file)
            lock(Sys_Fast.FAST_ConfigCacheLock_DDEC) do
                Sys_Fast.FAST_ConfigCache_DDEC[cfg_file] = (time() - 300.0, cfg3)
            end
            cfg_expired = Sys_Fast.FAST_ReadConfig_DDEF(cfg_file)
            cfg_nil = Sys_Fast.FAST_ReadConfig_DDEF("")
            cfg_none = Sys_Fast.FAST_ReadConfig_DDEF(nothing)
            upd_nil = Sys_Fast.FAST_UpdateConfig_DDEF("", Dict())
            upd_none = Sys_Fast.FAST_UpdateConfig_DDEF(nothing, Dict())
            df_none = Sys_Fast.FAST_ReadExcel_DDEF(nothing, "DATA")
            Sys_Fast.FAST_CleanTransient_DDEF(cfg_file)
            Sys_Fast.FAST_CleanTransient_DDEF(cfg_bad_file)
            @track G1 cfg2["Volume"] == 10.0 && upd_ok && cfg3["Volume"] == 50.0 && cfg_expired["Volume"] == 50.0 &&
                      isempty(cfg_nil) && isempty(cfg_none) && !upd_nil && !upd_none && isempty(df_none) && isempty(cfg_bad)
        end

        # 7: Input parameter sanitisation and anomaly warnings
        let raw_table = [
                Dict("Name" => "Ga-68 Precursor", "Role" => "Variable", "HalfLife" => 67.71, "MW" => 1435.0, "L1" => "10.5"),
                Dict("Name" => "Buffer", "Role" => "Fixed", "MW" => "abc", "L2" => "25.0"),
                Dict("Role" => "Variable"),
                Dict("Name" => "ExoticFactor", "Role" => "UnknownRole", "L1" => "xyz"),
                Dict("Name" => "ExplicitRadio", "IsRadioactive" => true, "L1" => 5.0)
            ],
            (san, warns) = Sys_Fast.FAST_SanitiseInput_DDEF(raw_table)
            @track G1 san[1]["IsRadioactive"] == true && san[1]["L1"] == 10.5 && san[2]["MW"] == 0.0 &&
                      startswith(san[3]["Name"], "Unnamed_Item_") && san[5]["IsRadioactive"] == true && length(warns) >= 2
        end

        # 8: DataFrame column rounding and precision retention
        let df_round = DataFrame("A" => [1.234567, 8.910111], "B" => ["keep", "text"], "C" => [100.1, missing], "D" => [Float32(2.5555), Float32(3.6666)], "E" => [10, 20])
            Sys_Fast.FAST_RoundColumns_DDEF!(df_round)
            @track G1 df_round.A == [1.235, 8.91] && df_round.B == ["keep", "text"] && df_round.C[1] == 100.1 &&
                      isapprox(df_round.D[1], 2.556; atol=1e-3) && df_round.E == [10, 20]
        end

        # 9: Multi-sheet Excel workbook write with dirty data
        let temp_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_TEST_IO.xlsx"),
            nested_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "nested_vault", "DOECISORY_TEMP_NESTED.xlsx")
            Sys_Fast.FAST_CleanTransient_DDEF(temp_file)
            Sys_Fast.FAST_CleanTransient_DDEF(nested_file)
            df_real_dirty = DataFrame(
                Sys_Fast.FAST_Data_DDEC.COL_EXP_ID => ["EXP_P1_01", "EXP_P1_02", "EXP_P1_03"],
                Sys_Fast.FAST_Data_DDEC.COL_PHASE => ["Phase1", "Phase1", "Phase1"],
                "Temp" => [25.0, 50.0, 75.0],
                "Yield" => ["", "", ""],
                "Notes" => ["Initial run", "", "Replicate test"]
            )
            df_cfg = DataFrame("PARAMETER" => ["MasterConfig"], "VALUE_JSON" => ["{\"Variables\": 3}"])
            Sys_Fast.FAST_WriteExcel_DDEF(temp_file, Dict(Sys_Fast.FAST_Data_DDEC.SHEET_DATA => df_real_dirty, Sys_Fast.FAST_Data_DDEC.SHEET_CONFIG => df_cfg))
            Sys_Fast.FAST_WriteExcel_DDEF(nested_file, Dict(
                Sys_Fast.FAST_Data_DDEC.SHEET_CONFIG => DataFrame("PARAMETER" => String[], "VALUE_JSON" => String[]),
                "EMPTY_SKIPPED" => DataFrame("A" => Int[]),
                "ZERO_COLS" => DataFrame()
            ))
            Sys_Fast.FAST_WriteExcel_DDEF(nothing, Dict{String,DataFrame}())
            Sys_Fast.FAST_WriteExcel_DDEF(temp_file, Dict{String,DataFrame}())
            Sys_Fast.FAST_WriteExcel_DDEF("", Dict("DATA" => DataFrame("A" => [1])))
            Sys_Fast.FAST_WriteExcel_DDEF(nothing, "SingleSheet", DataFrame())
            Sys_Fast.FAST_WriteExcel_DDEF(temp_file, "SINGLE_DISPATCH", DataFrame("Col" => [123]))
            is_nest = isfile(nested_file)
            Sys_Fast.FAST_CleanTransient_DDEF(nested_file)
            @track G1 isfile(temp_file) && filesize(temp_file) > 1000 && is_nest
        end

        # 10: Sheet structure and data schema layout validation
        let temp_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_TEST_IO.xlsx"),
            bad_sheet_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_BAD_SHEET.xlsx"),
            C = Sys_Fast.FAST_Data_DDEC
            Sys_Fast.FAST_CleanTransient_DDEF(bad_sheet_file)
            Sys_Fast.FAST_WriteExcel_DDEF(bad_sheet_file, Dict(
                C.SHEET_DATA => DataFrame("WrongCol1" => [1], "WrongCol2" => [2]),
                C.PREFIX_LEADERS * "Phase1" => DataFrame("WrongCol3" => [3])
            ))
            df_bad_data = Sys_Fast.FAST_ReadExcel_DDEF(bad_sheet_file, C.SHEET_DATA)
            df_bad_lead = Sys_Fast.FAST_ReadExcel_DDEF(bad_sheet_file, C.PREFIX_LEADERS * "Phase1")
            Sys_Fast.FAST_CleanTransient_DDEF(bad_sheet_file)

            df_read = Sys_Fast.FAST_ReadExcel_DDEF(temp_file, C.SHEET_DATA)
            valid_struct = Sys_Fast.FAST_ValidateSheetStructure_DDEF(df_read, C.SHEET_DATA)
            valid_id = Sys_Fast.FAST_ValidateSheetStructure_DDEF(DataFrame("ID" => [1], "PHASE" => ["P1"]), C.SHEET_DATA)
            miss_id = Sys_Fast.FAST_ValidateSheetStructure_DDEF(DataFrame("PHASE" => ["P1"]), C.SHEET_DATA)
            miss_ph = Sys_Fast.FAST_ValidateSheetStructure_DDEF(DataFrame("EXP_ID" => [1]), C.SHEET_DATA)
            invalid_struct = Sys_Fast.FAST_ValidateSheetStructure_DDEF(DataFrame("A" => [1], "B" => [2]), "BadSheet")
            empty_struct = Sys_Fast.FAST_ValidateSheetStructure_DDEF(DataFrame(), C.SHEET_DATA)
            df_missing_sheet = Sys_Fast.FAST_ReadExcel_DDEF(temp_file, "NonExistentSheet")
            df_bad_ext = Sys_Fast.FAST_ReadExcel_DDEF(normpath(joinpath(@__DIR__, "..", "Project.toml")), C.SHEET_DATA)
            df_not_exist = Sys_Fast.FAST_ReadExcel_DDEF("not_exist.xlsx", C.SHEET_DATA)
            _ = Sys_Fast.FAST_ApplyExcelStyle_DDEF(temp_file)
            _ = Sys_Fast.FAST_ApplyExcelStyle_DDEF("not_a_file.xlsx")
            _ = Sys_Fast.FAST_ApplyExcelStyle_DDEF("")
            _ = Sys_Fast.FAST_ApplyExcelStyle_DDEF("Sheet", DataFrame("A" => [1]))
            _ = Sys_Fast.FAST_ApplyExcelStyle_DDEF(temp_file, Dict("DATA" => df_read))
            _ = Sys_Fast.FAST_ApplyExcelStyle_DDEF(temp_file, [C.SHEET_DATA => DataFrame("VALUE_JSON" => ["{\"Variables\": 3}"])])
            _ = Sys_Fast.FAST_ApplyExcelStyle_DDEF(temp_file, ["EMPTY" => DataFrame()])
            js_nil = Sys_Fast.FAST_SanitiseJSON_DDEF(nothing)
            js_mis = Sys_Fast.FAST_SanitiseJSON_DDEF(missing)
            js_nan = Sys_Fast.FAST_SanitiseJSON_DDEF(NaN)
            js_flt = Sys_Fast.FAST_SanitiseJSON_DDEF(3.14)
            js_df  = Sys_Fast.FAST_SanitiseJSON_DDEF(DataFrame("A" => [1.0, NaN]))
            js_dic = Sys_Fast.FAST_SanitiseJSON_DDEF(Dict("A" => NaN, "B" => 2.0))
            js_mat = Sys_Fast.FAST_SanitiseJSON_DDEF(ones(2, 2))
            js_vec = Sys_Fast.FAST_SanitiseJSON_DDEF([1.0, NaN, missing])
            js_tup = Sys_Fast.FAST_SanitiseJSON_DDEF((1, 2))
            js_pair = Sys_Fast.FAST_SanitiseJSON_DDEF("k" => 42)
            js_str = Sys_Fast.FAST_SanitiseJSON_DDEF("raw_text")

            Sys_Fast.FAST_ActiveGroup_DDEC[] = ""
            Sys_Fast.FAST_Log_DDEF("SYS", "NO_GRP", "No Group Prefix", "INFO")
            Sys_Fast.FAST_ActiveGroup_DDEC[] = "G1"
            Sys_Fast.FAST_Log_DDEF(Val(:OK), "SYS", "OK_EVENT", "DETAIL")
            Sys_Fast.FAST_Log_DDEF(Val(:WARN), "SYS", "WARN_EVENT", "DETAIL")
            Sys_Fast.FAST_Log_DDEF(Val(:INFO), "SYS", "INFO_EVENT", "DETAIL")
            Sys_Fast.FAST_Log_DDEF(Val(:FAIL), "SYS", "FAIL_EVENT", "DETAIL")
            Sys_Fast.FAST_Log_DDEF(Val(:LIST), "SYS", "LIST_EVENT", "DETAIL")
            Sys_Fast.FAST_Log_DDEF(Val(:WAIT), "SYS", "WAIT_EVENT", "DETAIL")
            Sys_Fast.FAST_Log_DDEF(Val(:UNKNOWN_VAL), "SYS", "UNKNOWN_EVENT", "DETAIL")
            Sys_Fast.FAST_Log_DDEF("SYS", "INFO_STR", nothing, "INFO")
            Sys_Fast.FAST_Log_DDEF("SYS", "WARN_STR", "DETAIL", "WARN")
            wrap_str = Sys_Fast.FAST_WrapDetail_DDEF("Line 1\nLine 2", 45)

            safe_num = Sys_Fast.FAST_SafeNum_DDEF(missing)
            safe_val = Sys_Fast.FAST_SafeGet_DDEF(Dict(), "MissingKey", 42.0)

            # Validation of phase method resolution, model options, and active phase detection
            cfg_mock = Dict("Global" => Dict("PhaseHistory" => Dict("Phase1" => Dict("Method" => "BB15")), "Method" => "BB15"))
            df_phase_mock = DataFrame(
                "PHASE" => vcat(fill("Phase1", 15), fill("Phase2", 9)),
                "RESULT_Yield" => vcat(fill(85.0, 15), fill(missing, 9))
            )
            meth_p1    = Sys_Fast.FAST_DetectPhaseMethod_DDEF(cfg_mock, df_phase_mock, "Phase1")
            meth_p1_sp = Sys_Fast.FAST_DetectPhaseMethod_DDEF(cfg_mock, df_phase_mock, "Phase 1")
            meth_p2    = Sys_Fast.FAST_DetectPhaseMethod_DDEF(cfg_mock, df_phase_mock, "Phase2")
            act_p      = Sys_Fast.FAST_DetectActivePhase_DDEF(df_phase_mock, ["Phase1", "Phase2"])
            (opts_tl, val_tl) = Sys_Fast.FAST_ResolveModelOptions_DDEF("TL09", "Quadratic")
            (opts_bb, val_bb) = Sys_Fast.FAST_ResolveModelOptions_DDEF("BB15", "quadratic")

            @track G1 nrow(df_read) == 3 && valid_struct == true && valid_id == true && !miss_id && !miss_ph && invalid_struct == false && !empty_struct &&
                      isempty(df_bad_data) && isempty(df_bad_lead) &&
                      isempty(df_missing_sheet) && isempty(df_bad_ext) && isempty(df_not_exist) && isnan(safe_num) && safe_val == 42.0 &&
                      !isempty(wrap_str) &&
                      meth_p1 == "BB15" && meth_p1_sp == "BB15" && meth_p2 == "TL09" && act_p == "Phase1" &&
                      length(opts_tl) == 1 && val_tl == "Linear" && length(opts_bb) == 3 && val_bb == "Quadratic" &&
                      isnothing(js_nil) && isnothing(js_mis) && isnothing(js_nan) && js_flt == 3.14 &&
                      length(js_df) == 2 && length(js_mat) == 2 && js_str == "raw_text" && length(js_vec) == 3 &&
                      length(js_tup) == 2 && length(js_pair) == 2
        end

        # 11: DataFrame column name normalisation and formatting
        let df_norm_empty = Sys_Fast.FAST_SanitiseColumnNames_DDEF!(DataFrame()),
            df_norm_case  = Sys_Fast.FAST_SanitiseColumnNames_DDEF!(DataFrame(" exp_id " => [1], "pHAse" => ["P1"]); force_upper=true),
            df_norm_std   = Sys_Fast.FAST_SanitiseColumnNames_DDEF!(DataFrame(" exp id " => [1]))
            @track G1 isempty(df_norm_empty) && names(df_norm_case) == ["EXP_ID", "PHASE"] && names(df_norm_std) == ["exp_id"]
        end

        # 12: Configuration cache invalidation on write events
        let temp_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_TEST_IO.xlsx")
            lock(Sys_Fast.FAST_ConfigCacheLock_DDEC) do
                Sys_Fast.FAST_ConfigCache_DDEC[temp_file] = Dict("Cached" => true)
            end
            Sys_Fast.FAST_WriteExcel_DDEF(temp_file, Dict("DATA" => DataFrame("A" => [1])))
            @track G1 !haskey(Sys_Fast.FAST_ConfigCache_DDEC, temp_file)
        end

        # 13: Transient workforce file deletion and data cleanup
        let temp_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_TEST_IO.xlsx"),
            (dl_ok, dl_bytes) = Sys_Fast.FAST_PrepareDownload_DDEF(temp_file),
            (dl_nil_ok, _)    = Sys_Fast.FAST_PrepareDownload_DDEF(nothing),
            (dl_empty_ok, _)  = Sys_Fast.FAST_PrepareDownload_DDEF(""),
            (dl_miss_ok, _)   = Sys_Fast.FAST_PrepareDownload_DDEF("not_exist_dl.xlsx"),
            store_handle      = Sys_Fast.FAST_ReadToStore_DDEF(temp_file),
            nil_handle        = Sys_Fast.FAST_ReadToStore_DDEF(nothing),
            empty_handle      = Sys_Fast.FAST_ReadToStore_DDEF(""),
            dir_handle        = Sys_Fast.FAST_ReadToStore_DDEF(Sys_Fast.FAST_TempRoot_DDEC),
            _ = Sys_Fast.FAST_ResetConfigCache_DDEF(),
            _ = Sys_Fast.FAST_CleanTransient_DDEF(nothing),
            _ = Sys_Fast.FAST_CleanTransient_DDEF(""),
            _ = Sys_Fast.FAST_CleanTransient_DDEF(normpath(joinpath(@__DIR__, "..", "Project.toml")))
            Sys_Fast.FAST_CleanTransient_DDEF(temp_file)
            @track G1 !isfile(temp_file) && dl_ok && !isempty(dl_bytes) && !dl_nil_ok && !dl_empty_ok && !dl_miss_ok &&
                      !isempty(store_handle) && isempty(nil_handle) && isempty(empty_handle) && isempty(dir_handle)
        end

        # 14: Transient workspace file path isolation routines
        let t_path = Sys_Fast.FAST_GetTransientPath_DDEF(),
            t_path_nil = Sys_Fast.FAST_GetTransientPath_DDEF(nothing),
            t_path_dict = Sys_Fast.FAST_GetTransientPath_DDEF(Dict("dataid" => "x")),
            t_path_b64 = Sys_Fast.FAST_GetTransientPath_DDEF("data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,UEsDBBQAAAA="),
            _ = Sys_Fast.FAST_WriteVault_DDEF("vault_key_15", UInt8[0x50, 0x4b, 0x03, 0x04, 0x00, 0x00]),
            t_path_vault = Sys_Fast.FAST_GetTransientPath_DDEF("vault_key_15"),
            raw_b64_pk = Base64.base64encode(vcat(UInt8[0x50, 0x4b, 0x03, 0x04], fill(UInt8(42), 120))),
            t_path_raw_pk = Sys_Fast.FAST_GetTransientPath_DDEF(raw_b64_pk),
            raw_b64_bad = Base64.base64encode(fill(UInt8(42), 120)),
            t_path_raw_bad = Sys_Fast.FAST_GetTransientPath_DDEF(raw_b64_bad),
            raw_b64_err = repeat("!@#\$%^&*()", 15),
            t_path_raw_err = Sys_Fast.FAST_GetTransientPath_DDEF(raw_b64_err),
            res = startswith(abspath(t_path), abspath(Sys_Fast.FAST_TempRoot_DDEC)) && endswith(t_path, ".xlsx"),
            t_master = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_MASTER_INIT.xlsx"),
            C = Sys_Fast.FAST_Data_DDEC,
            df_init_des = DataFrame(
                C.COL_EXP_ID => ["EXP_01"],
                C.COL_PHASE => ["Phase1"],
                C.COL_STATUS => ["Pending"],
                C.COL_NOTES => ["Initial run"],
                C.PRE_MASS * "Comp1" => [10.0],
                C.PRE_VAR * "Temp" => [50.0],
                C.PRE_FIXED * "Temp" => [25.0],
                C.PRE_FILL * "Temp" => [1.0],
                C.PRE_RESULT * "Yield" => [85.0],
                C.PRE_PRED * "Yield" => [84.2],
                "TIME_FORW_MINS_Temp" => [15.0],
                "TIME_DCYP_MINS_Step" => [30.0],
                "TIME_REVE_MINS_Step" => [45.0],
                "ACTUAL_Temp" => [48.2]
            ),
            ok_m1 = Sys_Fast.FAST_InitialiseMaster_DDEF(t_master, ["Temp"], ["Yield", "Purity"], df_init_des, Dict{String,Any}("Phase" => "Phase1")),
            ok_m2 = Sys_Fast.FAST_InitialiseMaster_DDEF(t_master, ["Temp"], ["Yield"], df_init_des, Dict{String,Any}("Phase" => "Phase1")),
            ok_m3 = Sys_Fast.FAST_InitialiseMaster_DDEF(t_master, ["Temp"], ["Yield"], nothing, Dict{String,Any}("Phase" => "Phase1")),
            ok_nil = Sys_Fast.FAST_InitialiseMaster_DDEF(nothing, ["Temp"], ["Yield"]),
            cfg_hit1 = Sys_Fast.FAST_ReadConfig_DDEF(t_master),
            cfg_hit2 = Sys_Fast.FAST_ReadConfig_DDEF(t_master),
            v_exist = isfile(t_path_vault),
            pk_exist = isfile(t_path_raw_pk),
            b64_exist = isfile(t_path_b64)
            Sys_Fast.FAST_CleanTransient_DDEF(t_master)
            Sys_Fast.FAST_CleanTransient_DDEF(t_path)
            Sys_Fast.FAST_CleanTransient_DDEF(t_path_nil)
            Sys_Fast.FAST_CleanTransient_DDEF(t_path_dict)
            Sys_Fast.FAST_CleanTransient_DDEF(t_path_b64)
            Sys_Fast.FAST_CleanTransient_DDEF(t_path_vault)
            Sys_Fast.FAST_CleanTransient_DDEF(t_path_raw_pk)
            Sys_Fast.FAST_CleanTransient_DDEF(t_path_raw_bad)
            Sys_Fast.FAST_CleanTransient_DDEF(t_path_raw_err)
            @track G1 res && b64_exist && v_exist && pk_exist &&
                      !isfile(t_path_b64) && !isfile(t_path_vault) && !isfile(t_path_raw_pk) &&
                      ok_m1 && ok_m2 && ok_m3 && !ok_nil &&
                      haskey(cfg_hit1, "Phase") && haskey(cfg_hit2, "Phase")
        end

        # 15: Transient workforce workspace directory lifecycle
        let dummy = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_CLEANUP_CHECK.xlsx"),
            _ = Sys_Fast.FAST_WriteExcel_DDEF(dummy, Dict("SHEET" => DataFrame("X" => [1]))),
            _ = Sys_Fast.FAST_CleanWorkforce_DDEF(true),
            th_info = Sys_Fast.FAST_GetThreadInfo_DDEF(),
            comp_th = Sys_Fast.FAST_GetComputeThreads_DDEF(),
            dur_1   = Sys_Fast.FAST_FormatDuration_DDEF(0.0005),
            dur_2   = Sys_Fast.FAST_FormatDuration_DDEF(0.5),
            dur_3   = Sys_Fast.FAST_FormatDuration_DDEF(15.0),
            dur_4   = Sys_Fast.FAST_FormatDuration_DDEF(125.4),
            quote_str = Sys_Fast.FAST_GetSystemQuote_DDEF(),
            hdr_clean = Sys_Fast.FAST_SanitiseHeader_DDEF("  VARIA_Temp_C  "),
            hdr_plain = Sys_Fast.FAST_SanitiseHeader_DDEF("SampleHeader"),
            hdr_disp  = Sys_Fast.FAST_FormatDisplayHeader_DDEF("VARIA_Temp_C"),
            hdr_fix   = Sys_Fast.FAST_SanitiseHeader_DDEF("FIXED_Flow"),
            hdr_fill  = Sys_Fast.FAST_SanitiseHeader_DDEF("FILL_Solvent"),
            hdr_chro  = Sys_Fast.FAST_SanitiseHeader_DDEF("CHRO_Peak"),
            hdr_act   = Sys_Fast.FAST_SanitiseHeader_DDEF("ACTUAL_Temp"),
            hdr_rev   = Sys_Fast.FAST_SanitiseHeader_DDEF("TIME_REVE_MINS_Step"),
            hdr_dcy   = Sys_Fast.FAST_SanitiseHeader_DDEF("TIME_DCYP_MINS_Step"),
            sort_cols = Sys_Fast.FAST_SortColumns_DDEF([
                "EXP_ID", "PHASE", "STATUS", "NOTES", "RUN_ORDER",
                "MASS_A", "VARIA_B", "FIXED_C", "FILL_D", "RESULT_E", "PRED_F",
                "SCORE", "ACTUAL_G", "TIME_FORW_MINS_H", "CUSTOM_I"
            ]),
            sort_empty = Sys_Fast.FAST_SortColumns_DDEF(String[]),
            safe_prop  = Sys_Fast.FAST_SafeGet_DDEF((named_field = "custom_val",), "named_field"),
            v_missing  = Sys_Fast.FAST_ReadVault_DDEF("non_existent_vault_key"),
            df_probe  = DataFrame("EXP_ID" => [1], "PHASE" => ["P1"]),
            col_found = Sys_Fast.FAST_GetColumn_DDEF(df_probe, "EXP_ID"),
            col_empty1 = Sys_Fast.FAST_GetColumn_DDEF(DataFrame(), "EXP_ID"),
            col_empty2 = Sys_Fast.FAST_GetColumn_DDEF(df_probe, ""),
            col_suf    = Sys_Fast.FAST_GetColumn_DDEF(DataFrame("Temp_mg" => [1.0]), "Temp"),
            col_pfx    = Sys_Fast.FAST_GetColumn_DDEF(DataFrame("Yield (%)" => [1.0]), "Yield"),
            col_par    = Sys_Fast.FAST_GetColumn_DDEF(DataFrame("Yield(g)" => [1.0]), "Yield"),
            (df_val_ok, _) = Sys_Fast.FAST_ValidateDataFrame_DDEF(df_probe, ["EXP_ID"]),
            (df_empty_ok, _) = Sys_Fast.FAST_ValidateDataFrame_DDEF(DataFrame()),
            (df_miss_ok, _)  = Sys_Fast.FAST_ValidateDataFrame_DDEF(df_probe, ["MissingCol"]),
            (df_allnan_ok, _) = Sys_Fast.FAST_ValidateDataFrame_DDEF(DataFrame("X" => [NaN, NaN])),
            (df_50nan_ok, _)  = Sys_Fast.FAST_ValidateDataFrame_DDEF(DataFrame("X" => [1.0, NaN, NaN])),
            _ = Sys_Fast.FAST_WriteCache_DDEF("mem_key", DataFrame("K" => [100])),
            cached_df = Sys_Fast.FAST_ReadCache_DDEF("mem_key"),
            _ = Sys_Fast.FAST_ReadCache_DDEF(nothing),
            _ = Sys_Fast.FAST_WriteCache_DDEF(nothing, DataFrame("A" => [1])),
            _ = Sys_Fast.FAST_ReadCache_DDEF("unregistered_cache_key"),
            _ = Sys_Fast.FAST_ResetCache_DDEF(),
            _ = Sys_Fast.FAST_WriteVault_DDEF("v_key", UInt8[65, 66, 67]),
            vault_bytes = Sys_Fast.FAST_ReadVault_DDEF("v_key"),
            vault_nil   = Sys_Fast.FAST_ReadVault_DDEF(nothing),
            lock_ok = Sys_Fast.FAST_AcquireLock_DDEF("test_lock"),
            lock_nil = Sys_Fast.FAST_AcquireLock_DDEF(nothing),
            _ = Sys_Fast.FAST_ReleaseLock_DDEF("test_lock"),
            _ = Sys_Fast.FAST_ForceReleaseAll_DDEF(),
            dirs_ext = Sys_Fast.FAST_ExtractDirections_DDEF(Dict("Directions" => Dict("Phase1" => [1, -1, 0])), ["X1", "X2", "X3"], "Phase1"),
            dirs_dec = Sys_Fast.FAST_DecodeDirections_DDEF(Dict("Directions" => Dict("Phase1" => [1, -1, 0])), ["X1", "X2", "X3"]),
            dirs_dec_vec = Sys_Fast.FAST_DecodeDirections_DDEF([1, -1, 1], ["X1", "X2", "X3"]),
            dirs_dec_short = Sys_Fast.FAST_DecodeDirections_DDEF([1, -1], ["X1", "X2", "X3"]),
            dirs_dec_dict = Sys_Fast.FAST_DecodeDirections_DDEF(Dict("x1" => 1, "x2" => -1), ["X1", "X2", "X3"]),
            dirs_ext_real = Sys_Fast.FAST_ExtractDirections_DDEF(Dict("Phase" => "Phase1", "Direction" => [1, -1, 1]), [Dict("Name" => "X1", "Role" => "Variable"), Dict("Name" => "X2", "Role" => "Variable"), Dict("Name" => "X3", "Role" => "Variable")]),
            dirs_ext_hist = Sys_Fast.FAST_ExtractDirections_DDEF(Dict("PhaseHistory" => Dict("Phase1" => Dict("DirectionMap" => Dict("x1" => 1, "x2" => -1)))), [Dict("Name" => "X1", "Role" => "Variable"), Dict("Name" => "X2", "Role" => "Variable")]),
            ph_num   = Sys_Fast.FAST_ExtractPhaseNumber_DDEF("Phase2"),
            ph_p3    = Sys_Fast.FAST_ExtractPhaseNumber_DDEF("P3"),
            ph_none  = Sys_Fast.FAST_ExtractPhaseNumber_DDEF("NoDigits"),
            src_hist = Sys_Fast.FAST_SelectSource_DDEF(Dict("a"=>1), 10),
            src_glob = Sys_Fast.FAST_SelectSource_DDEF(nothing, 10),
            map_ext  = Sys_Fast.FAST_ExtractMap_DDEF(Dict("a"=>1)),
            map_empty = Sys_Fast.FAST_ExtractMap_DDEF(Dict()),
            hist_act = Sys_Fast.FAST_ResolveHistoryMap_DDEF(Dict("P1" => Dict("DirectionMap" => Dict("x" => 1))), "P1"),
            hist_sort = Sys_Fast.FAST_ResolveHistoryMap_DDEF(Dict("Phase1" => Dict("DirectionMap" => Dict("x" => 1)), "Phase2" => Dict("DirectionMap" => Dict("x" => 2)))),
            hist_none = Sys_Fast.FAST_ResolveHistoryMap_DDEF(Dict("P1" => Dict())),
            dirs_fb  = Sys_Fast.FAST_ExtractDirections_DDEF(Dict("PhaseHistory" => Dict("P1" => Dict("DirectionMap" => Dict("X" => 1)))), [Dict("Name" => "Y", "Role" => "Variable")]),
            lab_def  = Sys_Fast.FAST_GetLabDefaults_DDEF(),
            cfg_nil  = Sys_Fast.FAST_ReadConfig_DDEF(nothing),
            upd_nil  = Sys_Fast.FAST_UpdateConfig_DDEF(nothing, Dict()),
            memo_real = Sys_Fast.FAST_ReadMemoFile_DDEF(normpath(joinpath(@__DIR__, "..", "assets", "Sample.json"))),
            memo_nil = Sys_Fast.FAST_ReadMemoFile_DDEF("missing_memo.json"),
            safe_sym = Sys_Fast.FAST_SafeGet_DDEF(Dict("key" => 123), :key),
            safe_err = Sys_Fast.FAST_SafeGet_DDEF(Dict(), [1, 2], "fallback"),
            safe_nil = Sys_Fast.FAST_SafeGet_DDEF(nothing, "k", 999),
            dir_nil  = Sys_Fast.FAST_DecodeDirections_DDEF(nothing, []),
            map_nil  = Sys_Fast.FAST_GetDirectionMap_DDEF(nothing),
            ext_nil  = Sys_Fast.FAST_ExtractMap_DDEF(nothing),
            hist_nil = Sys_Fast.FAST_ResolveHistoryMap_DDEF(nothing),
            edir_nil = Sys_Fast.FAST_ExtractDirections_DDEF(nothing, nothing),
            dir_str_dec = Sys_Fast.FAST_DecodeDirections_DDEF(Dict("x1" => "Max", "x2" => "Min", "x3" => "Target"), ["X1", "X2", "X3"]),
            col_fmt_m   = Sys_Fast.FAST_FormatColumn_DDEF(Val(:Mass), "Comp"),
            col_fmt_v   = Sys_Fast.FAST_FormatColumn_DDEF(Val(:Variable), "Temp"),
            safe_nt_sym = Sys_Fast.FAST_SafeGet_DDEF((item = "value",), :item),
            safe_nt_str = Sys_Fast.FAST_SafeGet_DDEF((item = "value",), "item"),
            safe_obj    = Sys_Fast.FAST_SafeGet_DDEF(1//2, :den, 0) == 2,
            safe_obj_nil = Sys_Fast.FAST_SafeGet_DDEF(1//2, :non_existent_prop, 42) == 42,
            coerce_1    = Sys_Fast.FAST_ParseDirection_DDEF(1.4) == 1,
            coerce_nan  = Sys_Fast.FAST_ParseDirection_DDEF(NaN) == -1,
            coerce_nil  = Sys_Fast.FAST_ParseDirection_DDEF(nothing) == -1,
            coerce_s1   = Sys_Fast.FAST_ParseDirection_DDEF("+1") == 1,
            coerce_s0   = Sys_Fast.FAST_ParseDirection_DDEF("0") == 0,
            coerce_sm1  = Sys_Fast.FAST_ParseDirection_DDEF("-1") == -1,
            coerce_inv  = Sys_Fast.FAST_ParseDirection_DDEF("invalid") == -1,
            lock_sweep = try
                Sys_Fast.FAST_AcquireLock_DDEF("test_suite_op_lock")
                Sys_Fast.FAST_ReleaseLock_DDEF("test_suite_op_lock")
                Sys_Fast.FAST_ReleaseLock_DDEF("test_suite_op_lock")
                Sys_Fast.FAST_ReleaseLock_DDEF(nothing)
                Sys_Fast.FAST_ReleaseLock_DDEF("")
                Sys_Fast.FAST_ReleaseLock_DDEF("unregistered_op_lock")
                Sys_Fast.FAST_AcquireLock_DDEF("reentrant_op_lock")
                Sys_Fast.FAST_AcquireLock_DDEF("reentrant_op_lock")
                Sys_Fast.FAST_ReleaseLock_DDEF("reentrant_op_lock")
                Sys_Fast.FAST_ReleaseLock_DDEF("reentrant_op_lock")
                Sys_Fast.FAST_AcquireLock_DDEF("timeout_lock")
                lock(Sys_Fast.FAST_LockGuard_DDEC) do
                    Sys_Fast.FAST_OperationLockTimes_DDEC["timeout_lock"] = time() - 15.0
                end
                Sys_Fast.FAST_AcquireLock_DDEF("timeout_lock")
                Sys_Fast.FAST_ReleaseLock_DDEF("timeout_lock")
                Sys_Fast.FAST_ForceReleaseAll_DDEF()
                true
            catch
                false
            end
            @track G1 !isfile(dummy) && th_info[1] >= 1 && comp_th >= 1 && dur_1 == "<1ms" &&
                      dur_2 == "500ms" && dur_3 == "15.00s" && dur_4 == "2.1min" &&
                      !isempty(quote_str) && hdr_clean == "Temp_C" && hdr_plain == "SampleHeader" && hdr_disp == "Temp C" &&
                      hdr_fix == "Flow" && hdr_fill == "Solvent" && hdr_chro == "Peak" && hdr_act == "Temp" &&
                      hdr_rev == "Step" && hdr_dcy == "Step" && length(sort_cols) == 15 && sort_cols[1] == "EXP_ID" &&
                      isempty(sort_empty) && safe_prop == "custom_val" && isnothing(v_missing) &&
                      col_found == "EXP_ID" && isempty(col_empty1) && isempty(col_empty2) &&
                      col_suf == "Temp_mg" && col_pfx == "Yield (%)" && col_par == "Yield(g)" &&
                      df_val_ok && !df_empty_ok && !df_miss_ok && !df_allnan_ok && !df_50nan_ok && cached_df !== nothing &&
                      vault_bytes == UInt8[65, 66, 67] && isnothing(vault_nil) && lock_ok && !lock_nil && ph_num == 2 && ph_p3 == 3 && ph_none == 0 &&
                      dirs_dec_vec == (1, -1, 1) && dirs_dec_short == (-1, -1, -1) && dirs_dec_dict[1] == 1 && dirs_ext_real == (1, -1, 1) &&
                      dirs_ext_hist[1] == 1 && src_hist isa AbstractDict && src_glob == 10 && map_ext isa AbstractDict &&
                      isnothing(map_empty) && hist_act isa AbstractDict && hist_sort isa AbstractDict && isnothing(hist_none) && dirs_fb == (-1, -1, -1) &&
                      !isempty(lab_def) && isempty(cfg_nil) && !upd_nil && !isempty(memo_real) && isempty(memo_nil) && safe_sym == 123 && safe_err == "fallback" && safe_nil == 999 &&
                      safe_nt_sym == "value" && safe_nt_str == "value" && safe_obj && safe_obj_nil &&
                      coerce_1 && coerce_nan && coerce_nil && coerce_s1 && coerce_s0 && coerce_sm1 && coerce_inv &&
                      dir_str_dec == (1, -1, 0) && col_fmt_m == "MASS_Comp_mg" && col_fmt_v == "VARIA_Temp" &&
                      dir_nil == (-1, -1, -1) && isnothing(map_nil) && isnothing(ext_nil) && isnothing(hist_nil) && edir_nil == (-1, -1, -1) &&
                      lock_sweep
        end
    end
    TRACKER["G1"].duration = round(time() - t_g1; digits=2)

    # ==========================================================================
    # GROUP 2: Lib_Core Optimal Matrices, D-A-G-I & Desirability (10 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G2"
    t_g2 = time()
    @testset "Group 2: Lib_Core Optimal Matrices, D-A-G-I & Desirability" begin
        # 16: Experimental design matrix generation and checks
        let bb = Lib_Core.CORE_GenDesign_DDEF("BB15"),
            cd = Lib_Core.CORE_GenDesign_DDEF("CD17"),
            tl = Lib_Core.CORE_GenDesign_DDEF("TL09"),
            df = Lib_Core.CORE_GenDesign_DDEF("DF14", 3, [1, -1, 1]),
            t_bb = Lib_Core.CORE_GetMethodType_DDEF("BB15"),
            t_cd = Lib_Core.CORE_GetMethodType_DDEF("CD17"),
            t_tl = Lib_Core.CORE_GetMethodType_DDEF("TL09"),
            t_df = Lib_Core.CORE_GetMethodType_DDEF("DF14"),
            m_tl = Lib_Core.CORE_BuildMatrix_DDEF(t_tl, 3),
            m_cd = Lib_Core.CORE_BuildMatrix_DDEF(t_cd, 3),
            m_bb = Lib_Core.CORE_BuildMatrix_DDEF(t_bb, 3),
            m_df = Lib_Core.CORE_BuildMatrix_DDEF(t_df, 3, [1, 1, 1]),
            err_thrown = false,
            err_factor = false
            try
                Lib_Core.CORE_GenDesign_DDEF("UNKNOWN_TYPE")
            catch e
                err_thrown = (e isa ArgumentError)
            end
            try
                Lib_Core.CORE_GenDesign_DDEF("BB15", 4)
            catch e
                err_factor = (e isa ArgumentError) && occursin("FactorCount", e.msg)
            end
            err_fc_tl = try Lib_Core.CORE_BuildMatrix_DDEF("TL09", 4); false catch e; (e isa ArgumentError) end
            err_fc_bb = try Lib_Core.CORE_BuildMatrix_DDEF("BB15", 2); false catch e; (e isa ArgumentError) end
            err_fc_cd = try Lib_Core.CORE_BuildMatrix_DDEF("CD17", 4); false catch e; (e isa ArgumentError) end
            err_fc_df = try Lib_Core.CORE_BuildMatrix_DDEF("DF14", 2); false catch e; (e isa ArgumentError) end
            @track G2 size(Lib_Core.CORE_DesignBB15_DDEC) == (15, 3) &&
                      count(r -> all(==(0), r), eachrow(Lib_Core.CORE_DesignBB15_DDEC)) == 3 &&
                      size(Lib_Core.CORE_DesignCD17_DDEC) == (17, 3) &&
                      size(bb) == (15, 3) && size(cd) == (17, 3) && size(tl) == (9, 3) && size(df) == (14, 3) &&
                      size(m_tl) == (9, 3) && size(m_cd) == (17, 3) && size(m_bb) == (15, 3) && size(m_df) == (14, 3) &&
                      err_thrown && err_factor && err_fc_tl && err_fc_bb && err_fc_cd && err_fc_df
        end

        # 17: Directional D-optimal DF14 matrix structure check
        let df14_neg = Lib_Core.CORE_DesignDF14_DDEF([-1, -1, -1]),
            df14_pos = Lib_Core.CORE_DesignDF14_DDEF([1, 1, 1])
            @track G2 size(df14_neg) == (14, 3) &&
                      count(r -> all(==(0), r), eachrow(df14_neg)) == 3 &&
                      isapprox(det(Float64.(df14_neg)' * Float64.(df14_neg)), det(Float64.(df14_pos)' * Float64.(df14_pos)); atol=1e-3)
        end

        # 18: Physical parameter level mapping from coded space
        let coded = [-1.0 0.0 1.0; 1.0 -1.0 0.0],
            config = [
                Dict("Levels" => [10.0, 20.0, 30.0]),
                Dict("Levels" => [5.0, 10.0, 15.0]),
                Dict("Levels" => [100.0, 200.0, 300.0])
            ],
            mapped = Lib_Core.CORE_MapLevels_DDEF(coded, config),
            coded_b = Lib_Core.CORE_CodeMatrix_DDEF(coded, [-1.0 1.0; 0.0 50.0; -5.0 5.0]),
            coded_flat = Lib_Core.CORE_CodeMatrix_DDEF(ones(4, 3)),
            err_cfg_short = try Lib_Core.CORE_MapLevels_DDEF(coded, config[1:2]); false catch e; (e isa ArgumentError) end,
            config_short_lvl = [Dict("Levels" => [10.0]), Dict("Levels" => [5.0, 10.0, 15.0]), Dict("Levels" => [100.0, 200.0, 300.0])],
            mapped_short = Lib_Core.CORE_MapLevels_DDEF(coded, config_short_lvl),
            coded_b_zero = Lib_Core.CORE_CodeMatrix_DDEF(ones(3, 3), [1.0 1.0; 0.0 50.0; -5.0 5.0])
            @track G2 mapped[1, :] == [10.0, 10.0, 300.0] && mapped[2, :] == [30.0, 5.0, 200.0] &&
                      size(coded_b) == (2, 3) && size(coded_flat) == (4, 3) &&
                      err_cfg_short && size(mapped_short) == (2, 3) && size(coded_b_zero) == (3, 3)
        end

        # 19: Model matrix expansion for Linear-Quadratic forms
        let X = Float64.(Lib_Core.CORE_DesignBB15_DDEC),
            X_lin = Lib_Core.CORE_ExpandModelMatrix_DDEF(X, Lib_Core.CORE_ModelLinear_DDES()),
            X_qua = Lib_Core.CORE_ExpandModelMatrix_DDEF(X, Lib_Core.CORE_ModelQuadratic_DDES()),
            X_lin_str = Lib_Core.CORE_ExpandModelMatrix_DDEF(X, "linear"),
            X_qua_str = Lib_Core.CORE_ExpandModelMatrix_DDEF(X, "quadratic"),
            m_lin_t = Lib_Core.CORE_GetModelType_DDEF("linear"),
            m_qua_t = Lib_Core.CORE_GetModelType_DDEF("quadratic"),
            err_c3 = try
                Lib_Core.CORE_ExpandModelMatrix_DDEF(ones(5, 2), "linear")
                false
            catch e
                e isa ArgumentError
            end
            @track G2 size(X_lin) == (15, 4) && size(X_qua) == (15, 10) && all(==(1.0), X_qua[:, 1]) &&
                      size(X_lin_str) == (15, 4) && size(X_qua_str) == (15, 10) &&
                      m_lin_t isa Lib_Core.CORE_ModelLinear_DDES && m_qua_t isa Lib_Core.CORE_ModelQuadratic_DDES &&
                      err_c3
        end

        # 20: Algorithmic D, A, G, and I optimality profiling
        let d_qua = Lib_Core.CORE_CalcDEfficiency_DDEF(Float64.(Lib_Core.CORE_DesignBB15_DDEC)),
            d_lin = Lib_Core.CORE_CalcDEfficiency_DDEF(Float64.(Lib_Core.CORE_DesignBB15_DDEC), "linear"),
            d_short = Lib_Core.CORE_CalcDEfficiency_DDEF(Float64.(Lib_Core.CORE_DesignBB15_DDEC)[1:3, :], "quadratic"),
            d_zero = Lib_Core.CORE_CalcDEfficiency_DDEF(ones(15, 3), "quadratic"),
            m = Lib_Core.CORE_CalcDesignMetrics_DDEF(Float64.(Lib_Core.CORE_DesignBB15_DDEC)),
            m_lin = Lib_Core.CORE_CalcDesignMetrics_DDEF(Float64.(Lib_Core.CORE_DesignBB15_DDEC), "linear"),
            m_bad_dim = Lib_Core.CORE_CalcDesignMetrics_DDEF(ones(10, 2)),
            m_few_rows = Lib_Core.CORE_CalcDesignMetrics_DDEF(ones(2, 3)),
            d_nan = Lib_Core.CORE_CalcDEfficiency_DDEF(fill(NaN, 10, 3), "linear"),
            d_empty = Lib_Core.CORE_CalcDEfficiency_DDEF(zeros(0, 0), "linear"),
            m_nan = Lib_Core.CORE_CalcDesignMetrics_DDEF(fill(NaN, 10, 3)),
            X_bb = Float64.(Lib_Core.CORE_DesignBB15_DDEC),
            X_exp = Lib_Core.CORE_ExpandModelMatrix_DDEF(Lib_Core.CORE_CodeMatrix_DDEF(X_bb), Lib_Core.CORE_ModelQuadratic_DDES()),
            XtX = Matrix{Float64}(X_exp' * X_exp),
            inv_XtX = Matrix{Float64}(pinv(XtX)),
            lev = Vector{Float64}(diag(X_exp * inv_XtX * X_exp')),
            crit_d = Lib_Core.CORE_CalcCriterion_DDEF("D", XtX, 10, 15),
            crit_a = Lib_Core.CORE_CalcCriterion_DDEF("A", inv_XtX, 10, 15),
            crit_g = Lib_Core.CORE_CalcCriterion_DDEF("G", lev, 10, 15),
            crit_i = Lib_Core.CORE_CalcCriterion_DDEF("I", lev, 10, 15),
            crit_err = try Lib_Core.CORE_CalcCriterion_DDEF("UNKNOWN", XtX, 10, 15); false catch e; e isa ArgumentError end
            @track G2 d_qua > 0.35 && d_lin > 0.35 && d_short == 0.0 && d_zero == 0.0 &&
                      m["D"] > 0.30 && m["A"] > 0.0 && m["G"] > 0.0 && m["I"] > 0.0 && m["Condition"] < 100.0 &&
                      m_lin["D"] > 0.30 && m_bad_dim["D"] == 0.0 && m_few_rows["D"] == 0.0 &&
                      d_nan == 0.0 && d_empty == 0.0 && m_nan["D"] == 0.0 &&
                      crit_d > 0.0 && crit_a > 0.0 && crit_g > 0.0 && crit_i > 0.0 && crit_err
        end

        # 21: Design matrix singularity, anomaly, and duplicates
        let m_sing = Lib_Core.CORE_CalcDesignMetrics_DDEF(ones(15, 3)),
            (val_ok, val_warns) = Lib_Core.CORE_ValidateDesign_DDEF(ones(10, 3)),
            X_dup = [0.0 0.0 0.0; 0.0 0.0 0.0; 0.0 0.0 0.0; 0.0 0.0 0.0; 0.0 0.0 0.0; 1.0 2.0 3.0],
            (ok, msg) = Lib_Core.CORE_ValidateDesign_DDEF(X_dup),
            (ok_clean, _) = Lib_Core.CORE_ValidateDesign_DDEF(Float64.(Lib_Core.CORE_DesignBB15_DDEC))
            @track G2 m_sing["D"] == 0.0 && (isinf(m_sing["Condition"]) || m_sing["Condition"] > 1e10) &&
                      val_ok == false && occursin("zero variance", val_warns) &&
                      ok == false && occursin("duplicate rows", msg) && ok_clean == true
        end

        # 22: Desirability formulation, goals, and boundaries
        let g1 = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Maximise", "Min" => 10.0, "Max" => 50.0)),
            g2 = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "InvalidType", "Min" => 5.0, "Max" => 10.0)),
            g3 = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Minimise", "Min" => 0.0, "Max" => 20.0)),
            g4 = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Target", "Target" => 15.0, "Min" => 10.0, "Max" => 20.0)),
            g5 = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "None")),
            g_max = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Maximise", "Min" => 10.0, "Max" => 50.0, "Target" => 40.0, "Weight" => 1.0)),
            g_min = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Minimise", "Min" => 0.0, "Max" => 20.0, "Target" => 5.0, "Weight" => 1.0)),
            g_nom = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Nominal", "Min" => 10.0, "Max" => 30.0, "Target" => 20.0, "Weight" => 1.0)),
            g_tgt = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Target", "Min" => 10.0, "Max" => 30.0, "Target" => 20.0, "Weight" => 1.0)),
            g_non = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "None")),
            d_max = Lib_Core.CORE_CalcDesirability_DDEF(25.0, g_max),
            d_min = Lib_Core.CORE_CalcDesirability_DDEF(2.0, g_min),
            d_nom = Lib_Core.CORE_CalcDesirability_DDEF(20.0, g_nom),
            d_tgt = Lib_Core.CORE_CalcDesirability_DDEF(20.0, g_tgt),
            d_non = Lib_Core.CORE_CalcDesirability_DDEF(0.0, g_non),
            d_nom_lo = Lib_Core.CORE_CalcDesirability_DDEF(5.0, g_nom),
            d_nom_hi = Lib_Core.CORE_CalcDesirability_DDEF(35.0, g_nom),
            d_nom_lft = Lib_Core.CORE_CalcDesirability_DDEF(15.0, g_nom),
            d_nom_rgt = Lib_Core.CORE_CalcDesirability_DDEF(25.0, g_nom),
            d_max_lo = Lib_Core.CORE_CalcDesirability_DDEF(5.0, g_max),
            d_min_hi = Lib_Core.CORE_CalcDesirability_DDEF(25.0, g_min),
            g_tup_id = Lib_Core.CORE_ExtractGoal_DDEF((Lib_Core.CORE_GoalNominal_DDES(), 0.0, 10.0, 5.0, 1.0)),
            w_05  = Lib_Core.CORE_GetNeighbourWeights_DDEF(0.5),
            w_10  = Lib_Core.CORE_GetNeighbourWeights_DDEF(1.0),
            w_20  = Lib_Core.CORE_GetNeighbourWeights_DDEF(2.0)
            @track G2 g1[1] isa Lib_Core.CORE_GoalMaximise_DDES && g1[3] == 50.0 &&
                      g2[1] isa Lib_Core.CORE_GoalNominal_DDES &&
                      g3[1] isa Lib_Core.CORE_GoalMinimise_DDES &&
                      g4[1] isa Lib_Core.CORE_GoalNominal_DDES &&
                      g5[1] isa Lib_Core.CORE_GoalNominal_DDES &&
                      isapprox(d_max, 0.5; atol=1e-3) && d_min == 1.0 && d_nom == 1.0 && d_tgt == 1.0 && d_non == 1.0 &&
                      d_nom_lo == 0.0 && d_nom_hi == 0.0 && d_nom_lft > 0.0 && d_nom_rgt > 0.0 &&
                      d_max_lo == 0.0 && d_min_hi == 0.0 && g_tup_id[2] == 0.0 &&
                      length(w_05) == 3 && length(w_10) == 3 && length(w_20) == 3
        end

        # 23: Desirability weighting curvature and sensitivity
        let g_w1 = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Maximise", "Min" => 0.0, "Max" => 10.0, "Target" => 10.0, "Weight" => 1.0)),
            g_w2 = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Maximise", "Min" => 0.0, "Max" => 10.0, "Target" => 10.0, "Weight" => 2.0)),
            d1 = Lib_Core.CORE_CalcDesirability_DDEF(5.0, g_w1),
            d2 = Lib_Core.CORE_CalcDesirability_DDEF(5.0, g_w2),
            X_opt = Float64.(Lib_Core.CORE_DesignBB15_DDEC),
            Y_yield = [20.0 + 10.0*r[1] for r in eachrow(X_opt)],
            Y_imp   = [2.0 + 10.0*r[1] for r in eachrow(X_opt)],
            m_y = Lib_Vise.VISE_Regress_DDEF(X_opt, Y_yield, "linear"),
            m_i = Lib_Vise.VISE_Regress_DDEF(X_opt, Y_imp, "linear"),
            bounds = [-1.0 1.0; -1.0 1.0; -1.0 1.0],
            g_y_hi = Dict{String,Any}("Type" => "Maximise", "Min" => 10.0, "Max" => 30.0, "Target" => 30.0, "Weight" => 10.0, "WeightVal" => 10.0),
            g_i_lo = Dict{String,Any}("Type" => "Minimise", "Min" => 0.0, "Max" => 15.0, "Target" => 0.0, "Weight" => 1.0, "WeightVal" => 1.0),
            (bx_y, _) = Lib_Core.CORE_OptimiseDesirability_DDEF([m_y, m_i], [g_y_hi, g_i_lo], bounds; MaxTime=0.2),
            g_y_lo = Dict{String,Any}("Type" => "Maximise", "Min" => 10.0, "Max" => 30.0, "Target" => 30.0, "Weight" => 1.0, "WeightVal" => 1.0),
            g_i_hi = Dict{String,Any}("Type" => "Minimise", "Min" => 0.0, "Max" => 15.0, "Target" => 0.0, "Weight" => 10.0, "WeightVal" => 10.0),
            (bx_i, _) = Lib_Core.CORE_OptimiseDesirability_DDEF([m_y, m_i], [g_y_lo, g_i_hi], bounds; MaxTime=0.2)
            @track G2 isapprox(d1, 0.5; atol=1e-3) && isapprox(d2, 0.25; atol=1e-3) && bx_y[1] > bx_i[1]
        end

        # 24: Multi-objective interior Pareto trade-off search
        let X_bb = Float64.(Lib_Core.CORE_DesignBB15_DDEC),
            mod_ok = Lib_Vise.VISE_Regress_DDEF(X_bb, fill(25.0, 15), "linear"),
            mod_fail = Lib_Vise.VISE_Regress_DDEF(X_bb, fill(0.0, 15), "linear"),
            g_ok = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Maximise", "Min" => 10.0, "Max" => 50.0, "Target" => 40.0, "Weight" => 1.0)),
            g_unreach = Dict{String, Any}("Type" => "Maximise", "Min" => 10.0, "Max" => 50.0, "Target" => 40.0, "Weight" => 1.0, "WeightVal" => 1.0),
            (_, score_zero) = Lib_Core.CORE_OptimiseDesirability_DDEF([mod_ok, mod_fail], [g_ok, g_unreach], [-1.0 1.0; -1.0 1.0; -1.0 1.0]; MaxTime=0.1),
            lead_nil = Lib_Core.CORE_ExtractLeader_DDEF("not_a_master_file.xlsx", "Phase1", "", ["X1", "X2"]),
            X_opt = Float64.(Lib_Core.CORE_DesignBB15_DDEC),
            Y_yield = [20.0 + 10.0*r[1] + 5.0*r[2] for r in eachrow(X_opt)],
            Y_imp   = [2.0 + 8.0*r[1] - 3.0*r[2] for r in eachrow(X_opt)],
            m_yield = Lib_Vise.VISE_Regress_DDEF(X_opt, Y_yield, "linear"),
            m_imp   = Lib_Vise.VISE_Regress_DDEF(X_opt, Y_imp, "linear"),
            g_yield = Dict{String,Any}("Type" => "Maximise", "Min" => 10.0, "Max" => 35.0, "Target" => 35.0, "Weight" => 1.0, "WeightVal" => 1.0),
            g_imp   = Dict{String,Any}("Type" => "Minimise", "Min" => 0.0, "Max" => 15.0, "Target" => 0.0, "Weight" => 1.0, "WeightVal" => 1.0),
            bounds  = [-1.0 1.0; -1.0 1.0; -1.0 1.0],
            (best_x, best_s) = Lib_Core.CORE_OptimiseDesirability_DDEF([m_yield, m_imp], [g_yield, g_imp], bounds; MaxTime=0.2),
            m_type_quad = Lib_Core.CORE_GetModelType_DDEF(Lib_Core.CORE_ModelQuadratic_DDES()),
            d_dict_call = Lib_Core.CORE_CalcDesirability_DDEF(0.5, Dict("Type" => "Maximise", "Min" => 0.0, "Max" => 1.0, "Target" => 1.0, "Weight" => 1.0)),
            (opt_pen_x, opt_pen_s) = Lib_Core.CORE_OptimiseDesirability_DDEF([m_yield], [g_yield], bounds; MaxTime=0.05, PenaltyFn=x->0.9),
            (opt_fallback_x, opt_fallback_s) = Lib_Core.CORE_OptimiseDesirability_DDEF([m_yield], [g_yield], [2.0 1.0; 2.0 1.0; 2.0 1.0]; MaxTime=0.05),
            (ref_x, ref_s) = Lib_Core.CORE_RefineLocal_DDEF(x -> -clamp(1.0 - (x[1]-0.5)^2 - (x[2]-0.5)^2, 0.0, 1.0), [0.1, 0.1], [(0.0, 1.0), (0.0, 1.0)])
            @track G2 score_zero < 1e-4 && isempty(lead_nil) && best_s > 0.3 && length(best_x) == 3 &&
                      m_type_quad isa Lib_Core.CORE_ModelQuadratic_DDES && isapprox(d_dict_call, 0.5; atol=1e-3) &&
                      opt_pen_s > 0.0 && length(opt_fallback_x) == 3 && opt_fallback_s == 0.0 &&
                      ref_s > 0.0
        end

        # 25: Radiochemical DCYP structure and incubation decay
        let dm_ga = Lib_Core.CORE_ModifierDCYP_DDES(3, log(2.0) / 67.71, "Ga-68"),
            val_decay = Lib_Core.CORE_ApplyDCYP_DDEF(1.0, dm_ga, [0.0, 0.0, 67.71]),
            dcy_out_idx = Lib_Core.CORE_ApplyDCYP_DDEF(1.0, dm_ga, [1.0]),
            dcy_neg_t = Lib_Core.CORE_ApplyDCYP_DDEF(1.0, dm_ga, [0.0, 0.0, -10.0]),
            dcy_zero_t = Lib_Core.CORE_ApplyDCYP_DDEF(1.0, dm_ga, [0.0, 0.0, 0.0]),
            dm = Lib_Core.CORE_ModifierDCYP_DDES(2, log(2.0) / 109.77, "18F")
            @track G2 isapprox(val_decay, 0.5; atol=1e-2) &&
                      dcy_out_idx == 1.0 && dcy_neg_t == 1.0 && dcy_zero_t == 1.0 &&
                      dm.TimeIndex == 2 && dm.IsotopeName == "18F" && isapprox(dm.Lambda, log(2.0) / 109.77; atol=1e-6)
        end
    end
    TRACKER["G2"].duration = round(time() - t_g2; digits=2)

    # ==========================================================================
    # GROUP 3: Lib_Mole Stoichiometry, Mass Invariance & Kinetics (10 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G3"
    t_g3 = time()
    @testset "Group 3: Lib_Mole Stoichiometry, Mass Invariance & Kinetics" begin
        # 26: Recipe target masses and molar ratio conservation
        let names = ["Precursor", "Buffer"],
            mws = [1435.0, 210.0],
            ratios = [50.0, 50.0],
            df_mass = Lib_Mole.MOLE_CalcMass_DDEF(names, mws, ratios, 5.0, 10.0, ["%", "%"]; SuppressLog=true),
            df_zero_v = Lib_Mole.MOLE_CalcMass_DDEF(names, mws, ratios, 0.0, 10.0, ["%", "%"]),
            df_zero_c = Lib_Mole.MOLE_CalcMass_DDEF(names, mws, ratios, 5.0, 0.0, ["%", "%"]),
            df_overflow = Lib_Mole.MOLE_CalcMass_DDEF(names, mws, [5000.0, 5000.0], 5.0, 10.0, ["mg", "mg"]; SuppressLog=false)
            @track G3 nrow(df_mass) == 2 && df_mass.TARGET_MASS_mg[1] > 0.0 && isapprox(sum(df_mass.Molar_Ratio), 100.0; atol=1e-3) &&
                      nrow(df_zero_v) == 2 && df_zero_v.TARGET_MASS_mg[1] == 0.0 &&
                      nrow(df_zero_c) == 2 && nrow(df_overflow) == 2
        end

        # 27: Stoichiometric filler auto-balance and overflows
        let rows_fill = [
                Dict("Name" => "Var A", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 500.0, "Unit" => "%m"),
                Dict("Name" => "Var B", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 400.0, "Unit" => "%m"),
                Dict("Name" => "Var C", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 300.0, "Unit" => "%m"),
                Dict("Name" => "Saline", "Role" => "Filler", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "MW" => 58.44, "Unit" => "%m")
            ],
            (ok, rep, _, _, _) = Lib_Mole.MOLE_AuditQuick_DDEF(rows_fill, 10.0, 1.0),
            rows_overflow = [
                Dict("Name" => "Var A", "Role" => "Variable", "L1" => 60.0, "L2" => 60.0, "L3" => 60.0, "MW" => 500.0, "Unit" => "%m"),
                Dict("Name" => "Var B", "Role" => "Variable", "L1" => 50.0, "L2" => 50.0, "L3" => 50.0, "MW" => 400.0, "Unit" => "%m"),
                Dict("Name" => "Var C", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 300.0, "Unit" => "%m"),
                Dict("Name" => "Saline", "Role" => "Filler", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "MW" => 58.44, "Unit" => "%m")
            ],
            (ok_over, rep_over, _, _, _) = Lib_Mole.MOLE_AuditQuick_DDEF(rows_overflow, 10.0, 1.0)
            @track G3 ok == true && occursin("auto-balanced", rep) &&
                      ok_over == false && occursin("Filler balance failed", rep_over)
        end

        # 28: Stoichiometric validation rules and factor audits
        let rows_neg_mw = [Dict("Name" => "Bad Chem", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "MW" => -150.0, "Unit" => "mg")],
            rows_nomw_pct = [Dict("Name" => "MolarNoMW", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "MW" => 0.0, "Unit" => "%m")],
            rows_bad_u = [Dict("Name" => "ChemBadU", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "MW" => 100.0, "Unit" => "non_chemical_unit")],
            rows_2vars = [Dict("Name" => "V1", "Role" => "Variable", "L1" => 1.0, "L2" => 2.0, "L3" => 3.0), Dict("Name" => "V2", "Role" => "Variable", "L1" => 1.0, "L2" => 2.0, "L3" => 3.0)],
            rows_2fills = [
                Dict("Name" => "V1", "Role" => "Variable", "L1" => 1.0, "L2" => 2.0, "L3" => 3.0),
                Dict("Name" => "V2", "Role" => "Variable", "L1" => 1.0, "L2" => 2.0, "L3" => 3.0),
                Dict("Name" => "V3", "Role" => "Variable", "L1" => 1.0, "L2" => 2.0, "L3" => 3.0),
                Dict("Name" => "F1", "Role" => "Filler"),
                Dict("Name" => "F2", "Role" => "Filler")
            ],
            (ok1, _, _, _, _) = Lib_Mole.MOLE_AuditQuick_DDEF(rows_neg_mw, 10.0, 1.0),
            (ok2, _, _, _, _) = Lib_Mole.MOLE_AuditQuick_DDEF(Dict{String,Any}[], 0.0, 1.0),
            (ok3, rep3, _, _, _) = Lib_Mole.MOLE_AuditQuick_DDEF(rows_nomw_pct, 10.0, 1.0),
            (ok4, rep4, _, _, _) = Lib_Mole.MOLE_AuditQuick_DDEF(rows_bad_u, 10.0, 1.0),
            (ok5, rep5, _, _, _) = Lib_Mole.MOLE_AuditQuick_DDEF(rows_2vars, 10.0, 1.0),
            (ok6, rep6, _, _, _) = Lib_Mole.MOLE_AuditQuick_DDEF(rows_2fills, 10.0, 1.0)
            @track G3 ok1 == false && ok2 == false && ok3 == false && occursin("mandatory", rep3) &&
                      occursin("Unit Error", rep4) && occursin("Exactly 3 Variables", rep5) && occursin("Maximum 1 Filler", rep6)
        end

        # 29: Multi-unit stoichiometric percentage equivalence
        let eq_pct = Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(15.0, "%m", 100.0, 10.0, 10.0),
            eq_mg  = Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(10.0, "mg", 100.0, 10.0, 10.0),
            eq_mm  = Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(5.0, "mM", 100.0, 10.0, 10.0),
            eq_zero_vol = Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(10.0, "mg", 100.0, 0.0, 10.0),
            eq_zero_mw  = Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(10.0, "mg", 0.0, 10.0, 10.0)
            @track G3 eq_pct == 15.0 && isapprox(eq_mg, 100.0; atol=1e-3) && isapprox(eq_mm, 50.0; atol=1e-3) &&
                      eq_zero_vol == 0.0 && eq_zero_mw == 0.0
        end

        # 30: Design matrix stoichiometric feasibility auditing
        let X_feas = Float64.(Lib_Core.CORE_DesignBB15_DDEC),
            meta_overflow = [
                Dict("Name" => "Salt", "Role" => "Variable", "MW" => 58.44, "Unit" => "%m"),
                Dict("Name" => "Acid", "Role" => "Variable", "MW" => 98.0, "Unit" => "%m"),
                Dict("Name" => "Base", "Role" => "Variable", "MW" => 40.0, "Unit" => "%m"),
                Dict("Name" => "Water", "Role" => "Filler", "MW" => 18.01, "Unit" => "%m")
            ],
            meta_neg = [
                Dict("Name" => "Salt", "Role" => "Variable", "MW" => 58.44, "Unit" => "%m"),
                Dict("Name" => "Acid", "Role" => "Variable", "MW" => 98.0, "Unit" => "%m"),
                Dict("Name" => "Base", "Role" => "Variable", "MW" => 40.0, "Unit" => "%m")
            ],
            (feas_ok, feas_msg) = Lib_Mole.MOLE_ValidateFeasibility_DDEF(X_feas .* 150.0, meta_overflow, 10.0, 1.0),
            (feas_neg_ok, feas_neg_msg) = Lib_Mole.MOLE_ValidateFeasibility_DDEF([-1.0 1.0 1.0; 1.0 1.0 1.0], meta_neg, 10.0, 1.0)
            @track G3 feas_ok == false && occursin("overflow", feas_msg) &&
                      feas_neg_ok == false && occursin("negative", feas_neg_msg)
        end

        # 31: Physical recipe matrix processing and batch audits
        let rows_proc = [
                Dict("Name" => "VarA", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "MW" => 100.0, "Unit" => "%m"),
                Dict("Name" => "VarB", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "MW" => 120.0, "Unit" => "%m"),
                Dict("Name" => "VarC", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "MW" => 150.0, "Unit" => "%m"),
                Dict("Name" => "Buffer", "Role" => "Fixed", "L1" => 5.0, "L2" => 5.0, "L3" => 5.0, "MW" => 100.0, "Unit" => "%m"),
                Dict("Name" => "Solvent", "Role" => "Filler", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "MW" => 18.0, "Unit" => "%m")
            ],
            df_proc = Lib_Mole.MOLE_ProcessDesign_DDEF(Float64.(Lib_Core.CORE_DesignBB15_DDEC), rows_proc, 10.0, 1.0),
            rows_fill = [
                Dict("Name" => "Var A", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 500.0, "Unit" => "%m"),
                Dict("Name" => "Saline", "Role" => "Filler", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "MW" => 58.44, "Unit" => "%m")
            ],
            batch_res = Lib_Mole.MOLE_AuditBatch_DDEF(rows_proc, Float64.(Lib_Core.CORE_DesignBB15_DDEC), 10.0, 1.0),
            batch_bad_dim = Lib_Mole.MOLE_AuditBatch_DDEF(rows_fill, Float64.(Lib_Core.CORE_DesignBB15_DDEC)[:, 1:2], 10.0, 1.0),
            approx_ok = Lib_Mole.MOLE_ApproxEq_DDEF(1.0, 1.0),
            aud_mat_err = Lib_Mole.MOLE_AuditMatrix_DDEF(ones(5, 2), ["A", "B", "C"], [10.0, 20.0, 30.0], 10.0, 1.0),
            rows_under = [
                Dict("Name" => "A", "Role" => "Variable", "L1" => 0.01, "L2" => 0.01, "L3" => 0.01, "MW" => 100.0, "Unit" => "mg"),
                Dict("Name" => "B", "Role" => "Variable", "L1" => 0.01, "L2" => 0.01, "L3" => 0.01, "MW" => 100.0, "Unit" => "mg"),
                Dict("Name" => "C", "Role" => "Variable", "L1" => 0.01, "L2" => 0.01, "L3" => 0.01, "MW" => 100.0, "Unit" => "mg")
            ],
            (_, rep_under, _, _, _) = Lib_Mole.MOLE_AuditQuick_DDEF(rows_under, 100.0, 10.0)
            @track G3 nrow(df_proc) == 15 && "MASS_VarA_mg" in names(df_proc) && "MASS_Solvent_mg" in names(df_proc) &&
                      batch_res["IsFeasible"] == true && length(batch_res["RunMasses"]) == 15 && approx_ok &&
                      batch_bad_dim["IsFeasible"] == true && length(aud_mat_err) == 5 && all(==(0.0), aud_mat_err) &&
                      occursin("UNDER-CONCENTRATED", rep_under)
        end

        # 32: Mixed-unit stoichiometric recipe gravimetric audit
        let rows_mixed = [
                Dict("Name" => "Peptide", "Role" => "Variable", "L1" => 5.0, "L2" => 10.0, "L3" => 15.0, "MW" => 1500.0, "Unit" => "mg"),
                Dict("Name" => "Buffer", "Role" => "Variable", "L1" => 1.0, "L2" => 2.0, "L3" => 3.0, "MW" => 120.0, "Unit" => "mM"),
                Dict("Name" => "Additive", "Role" => "Variable", "L1" => 1.0, "L2" => 2.0, "L3" => 3.0, "MW" => 60.0, "Unit" => "%m"),
                Dict("Name" => "Water", "Role" => "Filler", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "MW" => 18.0, "Unit" => "%m")
            ],
            (ok_m, rep_m, _, _, _) = Lib_Mole.MOLE_AuditQuick_DDEF(rows_mixed, 100.0, 10.0),
            (_, rep_novol, _, _, _) = Lib_Mole.MOLE_AuditQuick_DDEF(rows_mixed, 0.0, 10.0),
            rows_over = [
                Dict("Name" => "A", "Role" => "Variable", "L1" => 100.0, "L2" => 100.0, "L3" => 100.0, "MW" => 10.0, "Unit" => "mg"),
                Dict("Name" => "B", "Role" => "Variable", "L1" => 100.0, "L2" => 100.0, "L3" => 100.0, "MW" => 10.0, "Unit" => "mg"),
                Dict("Name" => "C", "Role" => "Variable", "L1" => 100.0, "L2" => 100.0, "L3" => 100.0, "MW" => 10.0, "Unit" => "mg")
            ],
            (_, rep_overc, _, _, _) = Lib_Mole.MOLE_AuditQuick_DDEF(rows_over, 1.0, 1.0)
            @track G3 ok_m == true && occursin("GRAVIMETRIC AUDIT", rep_m) &&
                       occursin("No liquid environment", rep_novol) && occursin("OVER-CONCENTRATED", rep_overc)
        end

        # 33: Forward and reverse radiochemical decay kinetics
        let fwd = Lib_Mole.MOLE_CalcRadioDecay_DDEF(100.0, 67.71, "Minutes", 135.42; Reverse=false),
            rev = Lib_Mole.MOLE_CalcRadioDecay_DDEF(25.0, 67.71, "Minutes", 135.42; Reverse=true),
            fwd_d = Lib_Mole.MOLE_CalcRadioDecay_DDEF(100.0, 6.647, "Days", 6.647 * 1440.0; Reverse=false),
            d_zero = Lib_Mole.MOLE_CalcRadioDecay_DDEF(100.0, 60.0, "Minutes", 0.0),
            d_inf  = Lib_Mole.MOLE_CalcRadioDecay_DDEF(100.0, 1.0, "Minutes", 1e5)
            @track G3 isapprox(fwd, 25.0; atol=1e-3) && isapprox(rev, 100.0; atol=1e-3) && isapprox(fwd_d, 50.0; atol=1e-3) &&
                      isapprox(d_zero, 100.0; atol=1e-3) && isapprox(d_inf, 0.0; atol=1e-6)
        end

        # 34: Physical and temporal unit conversion validation
        let t_sec  = Lib_Mole.MOLE_ConvertToMinutes_DDEF(120.0, "SEC"),
            t_secs = Lib_Mole.MOLE_ConvertToMinutes_DDEF(120.0, "SECONDS"),
            t_min  = Lib_Mole.MOLE_ConvertToMinutes_DDEF(10.0, "MIN"),
            t_mins = Lib_Mole.MOLE_ConvertToMinutes_DDEF(10.0, "MINS"),
            t_mtes = Lib_Mole.MOLE_ConvertToMinutes_DDEF(10.0, "MINUTES"),
            t_hr   = Lib_Mole.MOLE_ConvertToMinutes_DDEF(2.0, "HR"),
            t_hrs  = Lib_Mole.MOLE_ConvertToMinutes_DDEF(2.0, "HRS"),
            t_hour = Lib_Mole.MOLE_ConvertToMinutes_DDEF(2.0, "HOUR"),
            t_day  = Lib_Mole.MOLE_ConvertToMinutes_DDEF(1.0, "DAY"),
            t_days = Lib_Mole.MOLE_ConvertToMinutes_DDEF(1.0, "DAYS"),
            t_neg  = Lib_Mole.MOLE_ConvertToMinutes_DDEF(-5.0, "MINUTES"),
            (m_ok, _, _)   = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF("5.0 mg", "Mass"),
            (c_ok, _, _)   = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF("10.0 mM", "Concentration"),
            (v_ok, _, _)   = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF("2.5 L", "Volume"),
            (t_ok, _, _)   = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF("1.5 hr", "Time"),
            (r_ok, _, _)   = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF("2.0", "Ratio"),
            (d_ok, _, _)   = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF("1.0", "Dimensionless"),
            (emp_ok, _, _) = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF("", "Volume"),
            (mis_ok, _, _) = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF("5.0 mg", "Volume"),
            (unk_ok, _, _) = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF("10.0", "UnknownDimension"),
            (err_ok, _, _) = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF("illegal!#*unit", "Mass")
            @track G3 t_sec == 2.0 && t_secs == 2.0 && t_min == 10.0 && t_mins == 10.0 && t_mtes == 10.0 &&
                      t_hr == 120.0 && t_hrs == 120.0 && t_hour == 120.0 && t_day == 1440.0 && t_days == 1440.0 &&
                      t_neg == 0.0 && Lib_Mole.MOLE_IsTimeUnit_DDEF("min") && !Lib_Mole.MOLE_IsTimeUnit_DDEF("mg") &&
                      m_ok && c_ok && v_ok && t_ok && r_ok && d_ok && !emp_ok && !mis_ok && !unk_ok && !err_ok
        end

        # 35: Physical unit taxonomy and ingredient role types
        let (u_mg, s_mg) = Lib_Mole.MOLE_GetUnitType_DDEF("mg"),
            (u_mm, s_mm) = Lib_Mole.MOLE_GetUnitType_DDEF("mM"),
            (u_pc, s_pc) = Lib_Mole.MOLE_GetUnitType_DDEF("%m"),
            (u_rat, _)   = Lib_Mole.MOLE_GetUnitType_DDEF("ratio"),
            (u_dash, _)  = Lib_Mole.MOLE_GetUnitType_DDEF("-"),
            (u_molar, _) = Lib_Mole.MOLE_GetUnitType_DDEF("molar"),
            (u_um, _)    = Lib_Mole.MOLE_GetUnitType_DDEF("μm"),
            (u_umol, _)  = Lib_Mole.MOLE_GetUnitType_DDEF("umol/l"),
            (u_oth, _)   = Lib_Mole.MOLE_GetUnitType_DDEF("unknown_dim_xyz"),
            (u_mcg, s_mcg) = Lib_Mole.MOLE_GetUnitType_DDEF("10 mcg"),
            (u_ug, s_ug)   = Lib_Mole.MOLE_GetUnitType_DDEF("microgram"),
            (u_g, s_g)     = Lib_Mole.MOLE_GetUnitType_DDEF("g"),
            (u_kg, s_kg)   = Lib_Mole.MOLE_GetUnitType_DDEF("kg"),
            (u_err, _)     = Lib_Mole.MOLE_GetUnitType_DDEF("invalid#@!unit"),
            pct_m        = Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(10.0, "%m", 100.0, 10.0, 1.0),
            pct_mg       = Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(10.0, "mg", 100.0, 10.0, 1.0),
            pct_mm       = Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(10.0, "mM", 100.0, 10.0, 1.0),
            pct_oth      = Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(10.0, "unknown_unit", 100.0, 10.0, 1.0),
            pct_zero     = Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(10.0, "%m", 100.0, 0.0, 1.0),
            rows_audit = [
                Dict("Name" => "Var A", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 500.0, "Unit" => "%m"),
                Dict("Name" => "Var B", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 400.0, "Unit" => "%m"),
                Dict("Name" => "Var C", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 300.0, "Unit" => "%m"),
                Dict("Name" => "Saline", "Role" => "Filler", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "MW" => 58.44, "Unit" => "%m")
            ],
            parsed_t = Lib_Mole.MOLE_ParseTable_DDEF(rows_audit),
            r_var = Lib_Mole.MOLE_IdentifyRole_DDEF("variable"),
            r_fix = Lib_Mole.MOLE_IdentifyRole_DDEF("fixed"),
            r_fil = Lib_Mole.MOLE_IdentifyRole_DDEF("filler"),
            r_unk = Lib_Mole.MOLE_IdentifyRole_DDEF("unknown_role")
            @track G3 u_mg isa Lib_Mole.MOLE_UnitMass_DDES && s_mg == 1.0 && u_mm isa Lib_Mole.MOLE_UnitConcentration_DDES &&
                      u_pc isa Lib_Mole.MOLE_UnitMolar_DDES && u_rat isa Lib_Mole.MOLE_UnitMolar_DDES &&
                      u_dash isa Lib_Mole.MOLE_UnitMolar_DDES && u_molar isa Lib_Mole.MOLE_UnitConcentration_DDES &&
                      u_um isa Lib_Mole.MOLE_UnitConcentration_DDES && u_umol isa Lib_Mole.MOLE_UnitConcentration_DDES &&
                      u_oth isa Lib_Mole.MOLE_UnitOther_DDES &&
                      u_mcg isa Lib_Mole.MOLE_UnitMass_DDES && isapprox(s_mcg, 0.01; atol=1e-5) &&
                      u_ug isa Lib_Mole.MOLE_UnitMass_DDES && u_g isa Lib_Mole.MOLE_UnitMass_DDES && s_g == 1000.0 &&
                      u_kg isa Lib_Mole.MOLE_UnitMass_DDES && s_kg == 1e6 && u_err isa Lib_Mole.MOLE_UnitOther_DDES &&
                      pct_m == 10.0 && pct_mg > 0.0 && pct_mm > 0.0 &&
                      pct_oth == 0.0 && pct_zero == 0.0 &&
                      length(parsed_t["Idx_Var"]) == 3 && length(parsed_t["Idx_Fill"]) == 1 &&
                      r_var isa Lib_Mole.MOLE_RoleVariable_DDES && r_fix isa Lib_Mole.MOLE_RoleFixed_DDES &&
                      r_fil isa Lib_Mole.MOLE_RoleFiller_DDES && r_unk isa Lib_Mole.MOLE_RoleFixed_DDES
        end
    end
    TRACKER["G3"].duration = round(time() - t_g3; digits=2)

    # ==========================================================================
    # GROUP 4: Lib_Vise Statistical Modelling, OLS & Tournament (30 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G4"
    t_g4 = time()
    @testset "Group 4: Lib_Vise Statistical Modelling, OLS & Tournament" begin
        X_quad = Float64.(Lib_Core.CORE_DesignBB15_DDEC)
        Y_quad = [10.0 + 2.0*r[1] - 1.5*r[2] + 0.8*r[3] + 2.5*r[1]^2 - 3.0*r[2]^2 + 1.2*r[1]*r[2] for r in eachrow(X_quad)]
        names_in = ["X1", "X2", "X3"]

        # 36: Quadratic response surface regression matrix fit
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in)
            @track G4 m_q["Status"] == "OK" && length(m_q["Coefs"]) == 10 && m_q["R2"] > 0.999
        end

        # 37: Model parameter count and term names generation
        let p_cnt_lin = Lib_Vise.VISE_GetParameterCount_DDEF(Lib_Core.CORE_ModelLinear_DDES()),
            p_cnt_qua = Lib_Vise.VISE_GetParameterCount_DDEF("quadratic"),
            terms_lin = Lib_Vise.VISE_GetTermNames_DDEF(names_in, "linear"),
            terms_qua = Lib_Vise.VISE_GetTermNames_DDEF(["A"], "quadratic")
            @track G4 p_cnt_lin == 4 && p_cnt_qua == 10 && length(terms_lin) == 4 && length(terms_qua) == 10
        end

        # 38: Index clamping and numeric boundary validation
        let ci_1 = Lib_Vise.VISE_ClampIndex_DDEF(3, 10),
            ci_2 = Lib_Vise.VISE_ClampIndex_DDEF(15.2, 10),
            ci_3 = Lib_Vise.VISE_ClampIndex_DDEF(-5, 10)
            @track G4 ci_1 == 3 && ci_2 == 10 && ci_3 == 1
        end

        # 39: Matrix preparation helpers and layout reshaping
        let mat_nest = Lib_Vise.VISE_PrepareMatrix_DDEF([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]),
            mat_flat = Lib_Vise.VISE_PrepareMatrix_DDEF([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]),
            mat_raw  = Lib_Vise.VISE_PrepareMatrix_DDEF([1.0, 2.0]),
            mat_mat  = Lib_Vise.VISE_PrepareMatrix_DDEF([1.0 2.0; 3.0 4.0]),
            mat_4    = Lib_Vise.VISE_PrepareMatrix_DDEF([1.0, 2.0, 3.0, 4.0])
            @track G4 size(mat_nest) == (2, 3) && size(mat_flat) == (2, 3) &&
                      size(mat_raw) == (2,) && size(mat_mat) == (2, 2) && length(mat_4) == 4
        end

        # 40: Collinear input resilience and metric fallbacks
        let m_sentry = Lib_Vise.VISE_Regress_DDEF(ones(15, 3), ones(15), "linear"),
            (met_r2, met_adj, met_rmse, met_aic) = Lib_Vise.VISE_CalcMetrics_DDEF(fill(5.0, 4), fill(5.0, 4), 5)
            @track G4 m_sentry["Status"] == "FAIL" &&
                      met_r2 == 0.0 && met_adj == 0.0 && met_rmse == 0.0 && isinf(met_aic)
        end

        # 41: Regression result struct conversion to dictionary
        let reg_struct = Lib_Vise.VISE_RegressionResult_DDES(
                [1.0], ["Intercept"], 0.99, 0.98, 0.1, 10.0, 50.0, 0.001,
                [0.001], [0.05], [20.0], [1.0], [0.1], Int[], 1.5, "linear", 15, "OK"
            ),
            reg_dict = Dict(reg_struct)
            @track G4 reg_dict["Status"] == "OK" && reg_dict["R2"] == 0.99
        end

        # 42: Linear multi-variable regression model matrix fit
        let Y_lin = [5.0 + 3.0*r[1] - 2.0*r[2] + 1.5*r[3] for r in eachrow(X_quad)],
            m_l = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_lin, "linear"; InNames=names_in)
            @track G4 m_l["Status"] == "OK" && length(m_l["Coefs"]) == 4 && m_l["R2"] > 0.999
        end

        # 43: Adjusted R-squared relation and coefficient bounds
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in)
            @track G4 m_q["R2_Adj"] <= m_q["R2"] && m_q["R2"] <= 1.0
        end

        # 44: Cross-validation Q-squared predictive computation
        let q2_clean = Lib_Vise.VISE_CrossValidate_DDEF(X_quad, Y_quad, "quadratic"),
            q2_short = Lib_Vise.VISE_CrossValidate_DDEF(ones(2, 3), [1.0, 2.0], "linear"),
            q2_three = Lib_Vise.VISE_CrossValidate_DDEF(ones(3, 3), [1.0, 2.0, 3.0], "linear"),
            q2_flat  = Lib_Vise.VISE_CrossValidate_DDEF(randn(5, 3), fill(2.0, 5), "linear"),
            q2_err   = Lib_Vise.VISE_CrossValidate_DDEF(fill(NaN, 5, 3), randn(5), "linear")
            @track G4 q2_clean > 0.90 && q2_clean <= 1.0 && isnan(q2_short) && isnan(q2_three) && q2_flat == 0.0 && isnan(q2_err)
        end

        # 45: Outlier leverage detection in cross-validation set
        let Y_outlier = copy(Y_quad)
            Y_outlier[1] += 50.0
            m_out = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_outlier, "quadratic")
            q2_out = Lib_Vise.VISE_CrossValidate_DDEF(X_quad, Y_outlier, "quadratic")
            @track G4 q2_out < 0.50 && m_out["R2"] > q2_out
        end

        # 46: ANOVA sum of squares variance partitioning check
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in),
            anova_t = Lib_Vise.VISE_GenANOVATable_DDEF(m_q, X_quad, Y_quad),
            ss_mod  = anova_t.SS[findfirst(==("Model"), anova_t.Source)],
            ss_res  = anova_t.SS[findfirst(==("Residual"), anova_t.Source)],
            ss_tot  = anova_t.SS[findfirst(==("Total"), anova_t.Source)],
            Y_lin = [5.0 + 3.0*r[1] - 2.0*r[2] + 1.5*r[3] for r in eachrow(X_quad)],
            m_l = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_lin, "linear"; InNames=names_in),
            anova_l = Lib_Vise.VISE_GenANOVATable_DDEF(m_l, X_quad, Y_lin),
            ss_l_mod = anova_l.SS[findfirst(==("Model"), anova_l.Source)],
            ss_l_res = anova_l.SS[findfirst(==("Residual"), anova_l.Source)],
            ss_l_tot = anova_l.SS[findfirst(==("Total"), anova_l.Source)]
            @track G4 isapprox(ss_mod + ss_res, ss_tot; atol=1e-3) &&
                      isapprox(ss_l_mod + ss_l_res, ss_l_tot; atol=1e-3)
        end

        # 47: ANOVA lack of fit and pure error partition checks
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in),
            anova_t = Lib_Vise.VISE_GenANOVATable_DDEF(m_q, X_quad, Y_quad),
            ss_lof = anova_t.SS[findfirst(==("Lack of Fit"), anova_t.Source)],
            ss_pe  = anova_t.SS[findfirst(==("Pure Error"), anova_t.Source)],
            ss_res = anova_t.SS[findfirst(==("Residual"), anova_t.Source)],
            X_rep = [1.0 2.0 3.0; 1.0 2.0 3.0; 4.0 5.0 6.0; 4.0 5.0 6.0; 7.0 8.0 9.0; 7.0 8.0 9.0; 10.0 11.0 12.0; 10.0 11.0 12.0; 13.0 14.0 15.0; 13.0 14.0 15.0],
            Y_rep_diff = [1.0, 1.2, 2.0, 2.4, 3.0, 2.9, 4.0, 4.3, 5.0, 4.8],
            m_rep = Lib_Vise.VISE_Regress_DDEF(X_rep, Y_rep_diff, "linear"),
            anova_rep = Lib_Vise.VISE_GenANOVATable_DDEF(m_rep, X_rep, Y_rep_diff),
            f_lof = anova_rep.F[findfirst(==("Lack of Fit"), anova_rep.Source)],
            p_lof = anova_rep.P[findfirst(==("Lack of Fit"), anova_rep.Source)]
            @track G4 isapprox(ss_lof + ss_pe, ss_res; atol=1e-3) && !ismissing(f_lof) && !ismissing(p_lof) && f_lof > 0.0
        end

        # 48: Lack of fit evaluation without experimental repeat
        let X_no_rep = [1.0 2.0 3.0; 4.0 5.0 6.0; 7.0 8.0 9.0; 10.0 11.0 12.0],
            (f_lof_z, p_lof_z) = Lib_Vise.VISE_TestLOF_DDEF(hcat(ones(4), X_no_rep), [1.0, 2.0, 3.0, 4.0]),
            X_rep = [1.0 2.0 3.0; 1.0 2.0 3.0; 4.0 5.0 6.0; 4.0 5.0 6.0; 7.0 8.0 9.0; 7.0 8.0 9.0; 10.0 11.0 12.0; 10.0 11.0 12.0; 13.0 14.0 15.0; 13.0 14.0 15.0],
            Y_rep_zero = [1.0, 1.0, 2.0, 2.0, 3.0, 3.0, 4.0, 4.0, 5.0, 5.0],
            (f_zero_pe, p_zero_pe) = Lib_Vise.VISE_TestLOF_DDEF(hcat(ones(10), X_rep), Y_rep_zero),
            Y_rep_diff = [1.0, 1.2, 2.0, 2.4, 3.0, 2.9, 4.0, 4.3, 5.0, 4.8],
            (f_rep, p_rep) = Lib_Vise.VISE_TestLOF_DDEF(hcat(ones(10), X_rep), Y_rep_diff),
            m_no_rep = Lib_Vise.VISE_Regress_DDEF(X_no_rep, [1.0, 2.0, 3.0, 4.0], "linear"),
            anova_no_rep = Lib_Vise.VISE_GenANOVATable_DDEF(m_no_rep, X_no_rep, [1.0, 2.0, 3.0, 4.0])
            @track G4 isnan(f_lof_z) && isnan(p_lof_z) && f_zero_pe == 999.0 && p_zero_pe == 0.0 && isfinite(f_rep) && isfinite(p_rep) &&
                      nrow(anova_no_rep) >= 2 && !("Lack of Fit" in anova_no_rep.Source)
        end

        # 49: Variance inflation factor collinearity screening
        let Y_lin = [5.0 + 3.0*r[1] - 2.0*r[2] + 1.5*r[3] for r in eachrow(X_quad)],
            m_l = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_lin, "linear"; InNames=names_in),
            X_coll = copy(X_quad)
            X_coll[:, 2] = 0.999 * X_coll[:, 1] + 0.001 * randn(15)
            m_coll = Lib_Vise.VISE_Regress_DDEF(X_coll, Y_quad, "linear"; InNames=names_in)
            vif_short = Lib_Vise.VISE_CalcVIF_DDEF(ones(10, 1))
            vif_sing  = Lib_Vise.VISE_CalcVIF_DDEF(hcat(ones(10), ones(10, 3)))
            vif_const = Lib_Vise.VISE_CalcVIF_DDEF(hcat(ones(10), fill(5.0, 10), randn(10)))
            vif_tikh  = Lib_Vise.VISE_CalcVIF_DDEF(hcat(ones(10), collect(1.0:10.0), collect(1.0:10.0)))
            @track G4 all(v -> isapprox(v, 1.0; atol=1e-2), m_l["VIFs"]) && any(v -> v > 10.0, m_coll["VIFs"]) &&
                      isempty(vif_short) && length(vif_sing) == 4 && vif_const[2] == 999.0 && vif_tikh[2] >= 1.0
        end

        # 50: Regression residual normality distribution tests
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in),
            norm_test = Lib_Vise.VISE_TestNormality_DDEF(m_q, X_quad, Y_quad),
            norm_empty = Lib_Vise.VISE_TestNormality_DDEF(Dict{String,Any}("Coefs" => Float64[]), X_quad, Y_quad),
            norm_const = Lib_Vise.VISE_TestNormality_DDEF(Dict{String,Any}("Coefs" => [1.0, 0.0, 0.0, 0.0]), ones(2, 3), [1.0, 1.0])
            @track G4 haskey(norm_test, "p") && haskey(norm_test, "IsNormal") &&
                      isnan(norm_empty["p"]) && !norm_empty["IsNormal"] &&
                      isnan(norm_const["p"]) && !norm_const["IsNormal"]
        end

        # 51: Response surface model sensitivity gradient sweep
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in),
            m_l = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "linear"; InNames=names_in),
            sens_q = Lib_Vise.VISE_AnalyseSensitivity_DDEF(m_q, [0.0, 0.0, 0.0], X_quad),
            sens_l = Lib_Vise.VISE_AnalyseSensitivity_DDEF(m_l, [-1.0, 1.0, 0.5], X_quad),
            m_flat = Dict{String, Any}("ModelType" => "linear", "Status" => "OK", "Coefs" => [5.0, 0.0, 0.0, 0.0]),
            sens_flat = Lib_Vise.VISE_AnalyseSensitivity_DDEF(m_flat, [0.0, 0.0, 0.0], X_quad)
            @track G4 length(sens_q) == 3 && all(isfinite, sens_q) && length(sens_l) == 3 && all(isfinite, sens_l) &&
                      isapprox(sens_flat[1], 1.0/3.0; atol=1e-3)
        end

        # 52: Statistical model response point prediction check
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in),
            p_val = Lib_Vise.VISE_Predict_DDEF(m_q, [0.0, 0.0, 0.0]),
            p_mat = Lib_Vise.VISE_Predict_DDEF(m_q, X_quad[1:3, :])
            @track G4 length(p_val) == 1 && isapprox(p_val[1], 10.0; atol=1e-2) && length(p_mat) == 3
        end

        # 53: Model selection tournament via corrected AICc score
        let Y_lin = [5.0 + 3.0*r[1] - 2.0*r[2] + 1.5*r[3] for r in eachrow(X_quad)],
            (best_m_q, _) = Lib_Vise.VISE_SelectBestModel_DDEF(X_quad, Y_quad, names_in),
            (best_m_l, _) = Lib_Vise.VISE_SelectBestModel_DDEF(X_quad, Y_lin, names_in),
            (sel_lin, _)  = Lib_Vise.VISE_SelectBestModel_DDEF(X_quad, Y_lin, names_in, "linear"),
            (sel_quad, _) = Lib_Vise.VISE_SelectBestModel_DDEF(X_quad, Y_quad, names_in, "quadratic"),
            (sel_fail, log_fail) = Lib_Vise.VISE_SelectBestModel_DDEF(ones(5, 3), ones(5), names_in),
            (sel_empty, _) = Lib_Vise.VISE_SelectBestModel_DDEF(X_quad, Y_lin, names_in, "")
            @track G4 best_m_q["ModelType"] == "quadratic" && best_m_l["ModelType"] == "linear" &&
                      sel_lin["ModelType"] == "linear" && sel_quad["ModelType"] == "quadratic" &&
                      sel_fail["Status"] == "FAIL" && occursin("Collinear Matrix", log_fail) &&
                      sel_empty["ModelType"] == "linear"
        end

        # 54: Radio-decay DCYP modifier extraction and toggles
        let cfg_decay = Dict("Ingredients" => [
                Dict("Name" => "ReactionTime", "Unit" => "min"),
                Dict("Name" => "Ga-68", "HalfLife" => 67.71, "HalfLifeUnit" => "min", "IsRadioactive" => true),
                Dict("Name" => "FixedPrecursor", "Role" => "Fixed", "HalfLife" => 67.71, "HalfLifeUnit" => "min", "IsRadioactive" => true)
            ]),
            opts_decay = Dict("RadioOpts" => Dict("Apply" => true, "DCYP" => Dict("Enabled" => true, "Isotope" => "Ga-68"))),
            opts_dcyp_off = Dict("RadioOpts" => Dict("Apply" => true, "DCYP" => Dict("Enabled" => false))),
            opts_dcyp_str = Dict("RadioOpts" => Dict("Apply" => true, "DCYP" => Dict("Enabled" => "ON", "Isotope" => "Ga-68"))),
            opts_dcyp_no_time = Dict("RadioOpts" => Dict("Apply" => true, "DCYP" => Dict("Enabled" => true, "Isotope" => "Ga-68"))),
            cfg_no_time = Dict("Ingredients" => [Dict("Name" => "Temp", "Unit" => "C"), Dict("Name" => "Ga-68", "HalfLife" => 67.71, "IsRadioactive" => true)]),
            cfg_zero_hl = Dict("Ingredients" => [Dict("Name" => "ReactionTime", "Unit" => "min"), Dict("Name" => "Ga-68", "HalfLife" => 0.0, "IsRadioactive" => true)]),
            d_mods = Lib_Vise.VISE_ExtractDCYP_DDEF(["ReactionTime", "Temp", "Conc"], ["Yield"], cfg_decay, opts_decay),
            d_mods_off = Lib_Vise.VISE_ExtractDCYP_DDEF(["ReactionTime", "Temp", "Conc"], ["Yield"], cfg_decay, opts_dcyp_off),
            d_mods_str = Lib_Vise.VISE_ExtractDCYP_DDEF(["ReactionTime", "Temp", "Conc"], ["Yield"], cfg_decay, opts_dcyp_str),
            d_mods_no_t = Lib_Vise.VISE_ExtractDCYP_DDEF(["Temp", "Conc"], ["Yield"], cfg_no_time, opts_dcyp_no_time),
            d_mods_zhl  = Lib_Vise.VISE_ExtractDCYP_DDEF(["ReactionTime", "Temp"], ["Yield"], cfg_zero_hl, opts_decay)
            @track G4 length(d_mods) == 1 && d_mods[1].IsotopeName == "Ga-68" && isempty(d_mods_off) &&
                      length(d_mods_str) == 1 && isempty(d_mods_no_t) && isempty(d_mods_zhl)
        end

        # 55: Forward and reverse radio-decay matrix correction
        let X_test = [100.0 20.0 5.0],
            Y_test = [50.0 25.0],
            in_n = ["Ga-68", "Temp", "pH"],
            out_n = ["ProductActivity", "Purity%"],
            df_test = DataFrame(
                "TIME_FORW_MINS_Ga-68" => [67.71],
                "TIME_FORW_MINS_FixedPrecursor" => [67.71],
                "TIME_REVE_MINS_Ga-68" => [67.71],
                "FIXED_FixedPrecursor" => [20.0],
                "RESULT_ProductActivity" => [50.0],
                "ACTUAL_FixedPrecursor" => [missing]
            ),
            cfg_test = Dict(
                "Ingredients" => [
                    Dict("Name" => "Ga-68", "HalfLife" => 67.71, "HalfLifeUnit" => "min", "IsRadioactive" => true),
                    Dict("Name" => "FixedPrecursor", "Role" => "Fixed", "HalfLife" => 67.71, "HalfLifeUnit" => "min", "IsRadioactive" => true)
                ],
                "Outputs" => [Dict("Name" => "ProductActivity", "Unit" => "MBq"), Dict("Name" => "Purity%", "Unit" => "%")]
            ),
            opts_test = Dict("RadioOpts" => Dict(
                "Apply" => true,
                "FORW" => Dict("Enabled" => true, "Ga-68" => Dict("Name" => "Ga-68 Precursor"), "FixedPrecursor" => Dict("Name" => "Fixed Decayed Precursor")),
                "REVE" => Dict("Enabled" => true, "ProductActivity" => Dict("Source" => "Ga-68"), "Purity%" => Dict("Source" => "Ga-68"))
            )),
            opts_no_radio = Dict("RadioOpts" => Dict("Apply" => false)),
            C = Sys_Fast.FAST_Data_DDEC,
            Log = Sys_Fast.FAST_Log_DDEF,
            audit = Lib_Vise.VISE_ApplyFRDecay_DDEF(X_test, Y_test, in_n, out_n, df_test, cfg_test, opts_test, C, Log),
            audit_off = Lib_Vise.VISE_ApplyFRDecay_DDEF(X_test, Y_test, in_n, out_n, df_test, cfg_test, opts_no_radio, C, Log),
            audit_nil = Lib_Vise.VISE_ApplyFRDecay_DDEF(X_test, Y_test, in_n, out_n, df_test, cfg_test, opts_test, C, Log; mask=falses(1))
            @track G4 length(audit) >= 3 && isapprox(X_test[1, 1], 50.0; atol=1e-2) && isapprox(Y_test[1, 1], 100.0; atol=1e-2) &&
                      isapprox(Y_test[1, 2], 50.0; atol=1e-2) && isempty(audit_off) && isempty(audit_nil)
        end

        # 56: High-density grid search within parameter bounds
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in),
            g_search = Dict{String, Any}("Type" => "Maximise", "Min" => 0.0, "Max" => 30.0, "Target" => 25.0, "Weight" => 1.0, "WeightVal" => 1.0),
            g_zero = Dict{String, Any}("Type" => "Target", "Min" => 0.0, "Max" => 10.0, "Target" => 1000.0, "Weight" => 1.0, "WeightVal" => 1.0)
            m_q["Goal"] = g_search
            grid_out = Lib_Vise.VISE_RunGridSearch_DDEF([m_q], [g_search], [-1.0 1.0; -1.0 1.0; -1.0 1.0]; Steps=5)
            grid_empty_models = Lib_Vise.VISE_RunGridSearch_DDEF(Dict{String,Any}[], Dict{String,Any}[], [-1.0 1.0; -1.0 1.0; -1.0 1.0]; Steps=2)
            m_zero = copy(m_q); m_zero["Goal"] = g_zero
            grid_zero = Lib_Vise.VISE_RunGridSearch_DDEF([m_zero], [g_zero], [-1.0 1.0; -1.0 1.0; -1.0 1.0]; Steps=2)
            mod_dcyp_t = [Lib_Core.CORE_ModifierDCYP_DDES(1, log(2.0) / 67.71, "Ga-68")]
            grid_dcyp = Lib_Vise.VISE_RunGridSearch_DDEF([m_q], [g_search], [-1.0 1.0; -1.0 1.0; -1.0 1.0]; Steps=2, ModifiersDCYP=mod_dcyp_t)
            pop_dcyp = Lib_Vise.VISE_GenPredictions_DDEF([0.0 0.0 0.0; 1.0 1.0 1.0], [10.0; 20.0], [m_q], [g_search]; ModifiersDCYP=mod_dcyp_t)
            @track G4 size(grid_out, 1) > 0 && size(grid_empty_models, 1) > 0 && size(grid_zero, 1) > 0 &&
                      size(grid_dcyp, 1) > 0 && length(pop_dcyp[2]) == 2
        end

        # 57: Underdetermined regression system error resilience
        let m_under = Lib_Vise.VISE_Regress_DDEF(rand(5, 3), rand(5), "quadratic")
            @track G4 m_under["Status"] != "OK" && occursin("Underdetermined", m_under["Error"])
        end

        # 58: Experimental matrix ingestion with missing values
        let C = Sys_Fast.FAST_Data_DDEC,
            Log = Sys_Fast.FAST_Log_DDEF,
            df_raw = DataFrame(
                "EXP_ID" => ["R1", "R2", "R3", "R4"],
                C.PRE_VAR * "Temp" => [20.0, 40.0, 60.0, 80.0],
                C.PRE_VAR * "Time" => [10.0, 20.0, 30.0, 40.0],
                C.PRE_RESULT * "Yield" => [75.0, "", 88.0, missing]
            ),
            cfg = Dict("Ingredients" => [Dict("Name" => "Temp"), Dict("Name" => "Time")], "Outputs" => [Dict("Name" => "Yield")]),
            (X_c, Y_c, in_n, out_n, mask) = Lib_Vise.VISE_ExtractMatrices_DDEF(df_raw, cfg, C, Log),
            df_4vars = DataFrame(
                "EXP_ID" => ["R1", "R2"],
                C.PRE_VAR * "A" => [1.0, 2.0],
                C.PRE_VAR * "B" => [3.0, 4.0],
                C.PRE_VAR * "C" => [5.0, 6.0],
                C.PRE_VAR * "D" => [7.0, 8.0],
                C.PRE_RESULT * "Y" => [10.0, 20.0]
            ),
            (X_4, Y_4, _, _, _) = Lib_Vise.VISE_ExtractMatrices_DDEF(df_4vars, cfg, C, Log),
            df_empty_ingest = DataFrame("EXP_ID" => ["R1"]),
            (X_e, Y_e, _, _, _) = Lib_Vise.VISE_ExtractMatrices_DDEF(df_empty_ingest, cfg, C, Log),
            df_all_nan = DataFrame(
                "EXP_ID" => ["R1", "R2"],
                C.PRE_VAR * "Temp" => [20.0, 40.0],
                C.PRE_VAR * "Time" => [10.0, 20.0],
                C.PRE_RESULT * "Yield" => [NaN, NaN]
            ),
            (X_nan, Y_nan, _, _, mask_nan) = Lib_Vise.VISE_ExtractMatrices_DDEF(df_all_nan, cfg, C, Log)
            @track G4 size(X_c) == (2, 2) && size(Y_c) == (2, 1) && mask == [true, false, true, false] &&
                      size(X_4, 2) == 3 && size(Y_4, 2) == 1 &&
                      isempty(X_e) && isempty(Y_e) && isempty(X_nan) && all(.!mask_nan)
        end

        # 59: Multi-response regression ensemble model training
        let Y_lin = [5.0 + 3.0*r[1] - 2.0*r[2] + 1.5*r[3] for r in eachrow(X_quad)],
            Log = Sys_Fast.FAST_Log_DDEF,
            ens_models = Lib_Vise.VISE_TrainEnsemble_DDEF(X_quad, hcat(Y_quad, Y_lin), names_in, "auto", Dict{String, Any}[], Log)
            @track G4 length(ens_models) == 2 && ens_models[1]["Status"] == "OK" && ens_models[2]["Status"] == "OK"
        end

        # 60: Scientific core optimization execution pipelines
        let Y_lin = [5.0 + 3.0*r[1] - 2.0*r[2] + 1.5*r[3] for r in eachrow(X_quad)],
            C = Sys_Fast.FAST_Data_DDEC,
            df_core = DataFrame(
                C.COL_EXP_ID => ["EXP_$i" for i in 1:15],
                C.COL_PHASE => fill("Phase1", 15),
                C.PRE_VAR * "X1" => X_quad[:, 1],
                C.PRE_VAR * "X2" => X_quad[:, 2],
                C.PRE_VAR * "X3" => X_quad[:, 3],
                C.PRE_RESULT * "Yield" => Y_quad,
                C.PRE_RESULT * "Purity" => Y_lin
            ),
            cfg_core = Dict(
                "Ingredients" => [
                    Dict("Name" => "X1", "Role" => C.ROLE_VAR, "Levels" => [-1.0, 0.0, 1.0]),
                    Dict("Name" => "X2", "Role" => C.ROLE_VAR, "Levels" => [-1.0, 0.0, 1.0]),
                    Dict("Name" => "X3", "Role" => C.ROLE_VAR, "Levels" => [-1.0, 0.0, 1.0])
                ],
                "Outputs" => [Dict("Name" => "Yield"), Dict("Name" => "Purity")]
            ),
            goals_core = [
                Dict{String,Any}("Response" => "Yield", "Type" => "Maximise", "Min" => 0.0, "Max" => 30.0, "Target" => 25.0, "Weight" => 1.0, "WeightVal" => 1.0),
                Dict{String,Any}("Response" => "Purity", "Type" => "Maximise", "Min" => 0.0, "Max" => 20.0, "Target" => 15.0, "Weight" => 1.0, "WeightVal" => 1.0)
            ],
            (core_res, _) = Lib_Vise.VISE_ExecuteInternal_DDEF(deepcopy(df_core), cfg_core, "Phase1", goals_core, "quadratic"; Opts=Dict{String,Any}("MaxTime" => 0.05)),
            (core_few, _) = Lib_Vise.VISE_ExecuteInternal_DDEF(df_core[1:2, :], cfg_core, "Phase1", goals_core, "quadratic"),
            (core_prio, _) = Lib_Vise.VISE_ExecuteInternal_DDEF(deepcopy(df_core), cfg_core, "Phase1", goals_core, "quadratic"; Opts=Dict{String,Any}("Mode" => :Priority, "MaxTime" => 0.05)),
            (core_def, _) = Lib_Vise.VISE_ExecuteInternal_DDEF(deepcopy(df_core), cfg_core, "Phase1", goals_core, "quadratic"; Opts=Dict{String,Any}("Mode" => :Deferred, "MaxTime" => 0.05)),
            (core_no_opt, _) = Lib_Vise.VISE_ExecuteInternal_DDEF(deepcopy(df_core), cfg_core, "Phase1", goals_core, "quadratic"; Optim=false)
            @track G4 core_res["Status"] == "OK" && core_few["Status"] == "FAIL" &&
                      core_prio["Status"] == "OK" && core_def["Status"] == "OK" && core_no_opt["Status"] == "OK"
        end

        # 61: Markdown scientific synthesis report generations
        let Y_lin = [5.0 + 3.0*r[1] - 2.0*r[2] + 1.5*r[3] for r in eachrow(X_quad)],
            C = Sys_Fast.FAST_Data_DDEC,
            df_core = DataFrame(
                C.COL_EXP_ID => ["EXP_$i" for i in 1:15],
                C.COL_PHASE => fill("Phase1", 15),
                C.PRE_VAR * "X1" => X_quad[:, 1],
                C.PRE_VAR * "X2" => X_quad[:, 2],
                C.PRE_VAR * "X3" => X_quad[:, 3],
                C.PRE_RESULT * "Yield" => Y_quad,
                C.PRE_RESULT * "Purity" => Y_lin
            ),
            cfg_core = Dict(
                "Ingredients" => [
                    Dict("Name" => "X1", "Role" => C.ROLE_VAR, "Levels" => [-1.0, 0.0, 1.0]),
                    Dict("Name" => "X2", "Role" => C.ROLE_VAR, "Levels" => [-1.0, 0.0, 1.0]),
                    Dict("Name" => "X3", "Role" => C.ROLE_VAR, "Levels" => [-1.0, 0.0, 1.0])
                ],
                "Outputs" => [Dict("Name" => "Yield"), Dict("Name" => "Purity")]
            ),
            goals_core = [
                Dict{String,Any}("Response" => "Yield", "Type" => "Maximise", "Min" => 0.0, "Max" => 30.0, "Target" => 25.0, "Weight" => 1.0, "WeightVal" => 1.0),
                Dict{String,Any}("Response" => "Purity", "Type" => "Maximise", "Min" => 0.0, "Max" => 20.0, "Target" => 15.0, "Weight" => 1.0, "WeightVal" => 1.0)
            ],
            (core_res, _) = Lib_Vise.VISE_ExecuteInternal_DDEF(deepcopy(df_core), cfg_core, "Phase1", goals_core, "quadratic"; Opts=Dict{String,Any}("MaxTime" => 0.05)),
            rep_md = Lib_Vise.VISE_GenSciReport_DDEF(core_res),
            rep_empty = Lib_Vise.VISE_GenSciReport_DDEF(merge(deepcopy(core_res), Dict("BestPoint" => []))),
            b_lin_hi = Dict{String, Any}(
                "Phase" => "Phase1", "OutNames" => ["Yield"], "DisplayOutNames" => ["Yield (%)"],
                "Models" => [Dict("Status" => "OK", "ModelType" => "linear", "R2_Adj" => 0.85, "Q2" => 0.80, "RMSE" => 0.5, "P_Value" => 0.001,
                                  "Coefs" => [10.0, 2.5, 3.0, 1.2], "TermNames" => ["(Intercept)", "X1", "X2", "X3"],
                                  "P_Coefs" => [0.001, 0.002, 0.008, 0.02], "VIFs" => [1.0, 1.0, 1.0, 1.0])],
                "ANOVA" => [DataFrame(
                    Source = ["Model", "Lack of Fit", "Pure Error", "Residual", "Total"],
                    SS = [120.5, 4.2, 2.1, 6.3, 126.8],
                    df = [3, 2, 4, 6, 9],
                    MS = [40.17, 2.1, 0.525, 1.05, 14.09],
                    F = [38.25, 4.0, missing, missing, missing],
                    P = [0.0002, 0.11, missing, missing, missing]
                )],
                "Vitals" => Dict("D" => 0.72, "A" => 0.4, "G" => 0.5, "I" => 0.4, "Condition" => 45.0, "MaxVIF" => 1.0, "LOF" => 0.25),
                "Normality" => [Dict("p" => 0.35, "IsNormal" => true)],
                "Sensitivities" => [[0.5, 0.3, 0.2]], "InNames" => ["X1", "X2", "X3"],
                "Goals" => [Dict("Name" => "Yield", "Type" => "Target", "Target" => 25.0, "Low" => 10.0, "High" => 40.0, "Weight" => 1.5)],
                "Leaders" => DataFrame("EXP_ID" => ["EXP_01"], "Yield" => [24.5]),
                "BestPoint" => [0.0, 0.0, 0.0], "BestScore" => 0.88, "Elapsed" => "0.2s"
            ),
            rep_lin_hi = Lib_Vise.VISE_GenSciReport_DDEF(b_lin_hi),
            b_lin_lo = merge(b_lin_hi, Dict("Vitals" => Dict("D" => 0.45, "Condition" => 250.0, "MaxVIF" => 3.5, "LOF" => 0.15))),
            rep_lin_lo = Lib_Vise.VISE_GenSciReport_DDEF(b_lin_lo),
            b_severe = Dict{String, Any}(
                "Phase" => "Phase1", "OutNames" => ["Yield"], "DisplayOutNames" => ["Yield (%)"],
                "Models" => [Dict("Status" => "OK", "ModelType" => "quadratic", "R2_Adj" => 0.90, "Q2" => -0.15, "RMSE" => 2.5, "P_Value" => 0.12,
                                  "Coefs" => zeros(10), "TermNames" => ["(Intercept)"; ["X$i" for i in 1:9]],
                                  "P_Coefs" => fill(0.25, 10), "VIFs" => [1.0; fill(15.0, 9)])],
                "ANOVA" => [DataFrame(
                    Source = ["Model", "Lack of Fit", "Pure Error", "Residual", "Total"],
                    SS = [80.0, 40.0, 1.0, 41.0, 121.0],
                    df = [9, 3, 2, 5, 14],
                    MS = [8.89, 13.33, 0.5, 8.2, 8.64],
                    F = [1.08, 26.66, missing, missing, missing],
                    P = [0.45, 0.036, missing, missing, missing]
                )],
                "Vitals" => Dict("D" => 0.25, "Condition" => 2500.0, "MaxVIF" => 15.0, "LOF" => 0.01),
                "Normality" => [Dict("p" => 0.002, "IsNormal" => false)],
                "Goals" => [], "BestPoint" => [1.0, 1.0, 1.0], "BestScore" => 0.35, "BoundaryWarnings" => ["X1 at boundary limit"], "Elapsed" => "0.3s"
            ),
            rep_severe = Lib_Vise.VISE_GenSciReport_DDEF(b_severe),
            b_gap = merge(b_lin_hi, Dict("Models" => [Dict("Status" => "OK", "ModelType" => "linear", "R2_Adj" => 0.88, "Q2" => 0.55, "RMSE" => 1.0, "P_Value" => 0.01, "Coefs" => [1.0, 0.0, 0.0, 0.0], "TermNames" => ["(Intercept)", "X1", "X2", "X3"], "P_Coefs" => fill(0.01, 4), "VIFs" => fill(1.0, 4))])),
            rep_gap = Lib_Vise.VISE_GenSciReport_DDEF(b_gap),
            b_low_q2 = merge(b_lin_hi, Dict("Models" => [Dict("Status" => "OK", "ModelType" => "linear", "R2_Adj" => 0.45, "Q2" => 0.35, "RMSE" => 1.0, "P_Value" => 0.01, "Coefs" => [1.0, 0.0, 0.0, 0.0], "TermNames" => ["(Intercept)", "X1", "X2", "X3"], "P_Coefs" => fill(0.01, 4), "VIFs" => fill(1.0, 4))])),
            rep_low_q2 = Lib_Vise.VISE_GenSciReport_DDEF(b_low_q2),
            rep_low = Lib_Vise.VISE_GenSciReport_DDEF(merge(b_lin_hi, Dict("BestScore" => 0.42))),
            rep_mid = Lib_Vise.VISE_GenSciReport_DDEF(merge(b_lin_hi, Dict("BestScore" => 0.65))),
            sample_rep = "# Diagnostics\n| Output | P-Value |\n| Yield | <0.0001 |\n* Note: (κ < 100) satisfies (p < 0.05).\n<span class=\"badge\">Tagged Content</span>",
            clean_rx = replace(sample_rep, r"</?[a-zA-Z][a-zA-Z0-9]*\b[^>]*>" => ""),
            clean_math = replace(clean_rx, "&lt;" => "<", "&gt;" => ">"),
            preserves_math = occursin("<0.0001", clean_math) && occursin("(κ < 100)", clean_math) && occursin("(p < 0.05)", clean_math) && !occursin("<span", clean_math)
            @track G4 !isempty(rep_md) && occursin("not conducted", rep_empty) && occursin("Adequate efficiency", rep_lin_hi) &&
                      occursin("Low efficiency", rep_lin_lo) && occursin("Severe multicollinearity", rep_severe) &&
                      occursin("Overfitted", rep_severe) && occursin("exceeds 0.20", rep_gap) &&
                      occursin("Low (0 ≤ Q² < 0.50)", rep_low_q2) && occursin("significant compromise", rep_low) &&
                      occursin("acceptable satisfaction", rep_mid) && preserves_math &&
                      occursin("Lack-of-Fit is non-significant", rep_lin_hi) &&
                      occursin("Lack-of-Fit is statistically significant", rep_severe)
        end

        # 62: Markdown table alignment and token weight ratings
        let md_tbl = Lib_Vise.VISE_FormatMarkdownTable_DDEF(["H1", "H2", "H3"], [:left, :right, :centre], [["A", "1", "C"], ["B", "2", "D"]]),
            w_ratings = [Lib_Vise.VISE_GetWeightRating_DDEF(w) for w in (0.50, 0.75, 1.00, 1.50, 2.00, "fallback")]
            @track G4 !isempty(md_tbl) && w_ratings == ["1/5", "2/5", "3/5", "4/5", "5/5", "3/5"]
        end

        # 63: Column name resolution and DataFrame widening ops
        let C = Sys_Fast.FAST_Data_DDEC,
            res_n1 = Lib_Vise.VISE_ResolveName_DDEF("VARIA_X1_mg", "VARIA_", [Dict("Name" => "X1", "Unit" => "mg")], C),
            res_n2 = Lib_Vise.VISE_ResolveName_DDEF("VARIA_X2", "VARIA_", [Dict("Name" => "X2", "Unit" => "-")], C),
            res_n3 = Lib_Vise.VISE_ResolveName_DDEF("X3", "", [Dict("Name" => "X3")], C),
            res_n4 = Lib_Vise.VISE_ResolveName_DDEF("", "VARIA_", [], C),
            res_n5 = Lib_Vise.VISE_ResolveName_DDEF("VARIA_X1 mg", "VARIA_", [Dict("Name" => "X1", "Unit" => "mg")], C),
            res_n6 = Lib_Vise.VISE_ResolveName_DDEF("VARIA_X1_extra", "VARIA_", [Dict("Name" => "X1", "Unit" => "mg")], C),
            res_n7 = Lib_Vise.VISE_ResolveName_DDEF("X1_mg", "VARIA_", [Dict("Name" => "X1", "Unit" => "mg")], C),
            res_n8 = Lib_Vise.VISE_ResolveName_DDEF("VARIA_UnknownCol", "VARIA_", [], C),
            df_col_ops = DataFrame("A" => ["1.0", "", missing], "B" => [1.0, 2.0, 3.0]),
            col_ops_ok = try
                Lib_Vise.VISE_WidenColumnFloat_DDEF!(df_col_ops, :A)
                Lib_Vise.VISE_WidenColumnFloat_DDEF!(df_col_ops, :NewCol)
                Lib_Vise.VISE_InsertColumnAfter_DDEF!(df_col_ops, "B", "A")
                Lib_Vise.VISE_InsertColumnAfter_DDEF!(df_col_ops, "A", "A")
                Lib_Vise.VISE_InsertColumnAfter_DDEF!(df_col_ops, "Z", "A")
                "NewCol" in names(df_col_ops)
            catch
                false
            end,
            opts_dcyp_extr = Dict{String, Any}("RadioOpts" => Dict(
                "Apply" => true,
                "DCYP" => Dict("Enabled" => true, "Isotope" => "Ga-68")
            )),
            cfg_dcyp_extr = Dict("Ingredients" => [
                Dict("Name" => "ReactionTime", "Role" => "Variable", "Unit" => "min"),
                Dict("Name" => "Ga-68", "Role" => "Fixed", "IsRadioactive" => true, "HalfLife" => 67.71, "HalfLifeUnit" => "min")
            ]),
            mods_dcyp_extr = Lib_Vise.VISE_ExtractDCYP_DDEF(["ReactionTime", "X2", "X3"], ["Yield"], cfg_dcyp_extr, opts_dcyp_extr),
            df_fwd_rev = DataFrame(
                "TIME_FORW_MINS_Precursor" => [15.0, 30.0],
                "TIME_REVE_MINS_Yield" => [20.0, 40.0],
                "VARIA_Precursor" => [100.0, 100.0],
                "RESULT_Yield" => [75.0, 80.0],
                "ACTUAL_Precursor" => [missing, missing]
            ),
            X_fwd_rev = [100.0 1.0 1.0; 100.0 2.0 2.0],
            Y_fwd_rev = [75.0; 80.0],
            cfg_fwd_rev = Dict(
                "Ingredients" => [Dict("Name" => "Precursor", "Role" => "Variable", "IsRadioactive" => true, "HalfLife" => 67.71, "HalfLifeUnit" => "min")],
                "Outputs" => [Dict("Name" => "Yield", "Unit" => "%")]
            ),
            opts_fwd_rev = Dict{String, Any}("RadioOpts" => Dict(
                "Apply" => true,
                "FORW" => Dict("Enabled" => true, "Precursor" => Dict("Name" => "Precursor")),
                "REVE" => Dict("Enabled" => true, "Yield" => Dict("Name" => "Yield", "Source" => "Precursor"))
            )),
            audit_fwd_rev = Lib_Vise.VISE_ApplyFRDecay_DDEF(
                X_fwd_rev, Y_fwd_rev, ["Precursor", "X2", "X3"], ["Yield"],
                df_fwd_rev, cfg_fwd_rev, opts_fwd_rev, C, Sys_Fast.FAST_Log_DDEF
            )
            @track G4 res_n1 == "X1" && res_n2 == "X2" && res_n3 == "X3" && isempty(res_n4) &&
                      res_n5 == "X1" && res_n6 == "X1" && res_n7 == "X1" && res_n8 == "UnknownCol" && col_ops_ok &&
                      length(mods_dcyp_extr) == 1 && length(audit_fwd_rev) >= 1 && any(c -> startswith(c, "ACTUAL_Yield"), names(df_fwd_rev)) &&
                      !ismissing(df_fwd_rev[1, :ACTUAL_Precursor])
        end

        # 64: Excel multi-sheet execution and export workflows
        let Y_lin = [5.0 + 3.0*r[1] - 2.0*r[2] + 1.5*r[3] for r in eachrow(X_quad)],
            C = Sys_Fast.FAST_Data_DDEC,
            df_core = DataFrame(
                C.COL_EXP_ID => ["EXP_$i" for i in 1:15],
                C.COL_PHASE => fill("Phase1", 15),
                C.PRE_VAR * "X1" => X_quad[:, 1],
                C.PRE_VAR * "X2" => X_quad[:, 2],
                C.PRE_VAR * "X3" => X_quad[:, 3],
                C.PRE_RESULT * "Yield" => Y_quad,
                C.PRE_RESULT * "Purity" => Y_lin
            ),
            cfg_core = Dict(
                "Ingredients" => [
                    Dict("Name" => "X1", "Role" => C.ROLE_VAR, "Levels" => [-1.0, 0.0, 1.0]),
                    Dict("Name" => "X2", "Role" => C.ROLE_VAR, "Levels" => [-1.0, 0.0, 1.0]),
                    Dict("Name" => "X3", "Role" => C.ROLE_VAR, "Levels" => [-1.0, 0.0, 1.0])
                ],
                "Outputs" => [Dict("Name" => "Yield"), Dict("Name" => "Purity")]
            ),
            goals_core = [
                Dict{String,Any}("Response" => "Yield", "Type" => "Maximise", "Min" => 0.0, "Max" => 30.0, "Target" => 25.0, "Weight" => 1.0, "WeightVal" => 1.0),
                Dict{String,Any}("Response" => "Purity", "Type" => "Maximise", "Min" => 0.0, "Max" => 20.0, "Target" => 15.0, "Weight" => 1.0, "WeightVal" => 1.0)
            ],
            (core_res, _) = Lib_Vise.VISE_ExecuteInternal_DDEF(deepcopy(df_core), cfg_core, "Phase1", goals_core, "quadratic"; Opts=Dict{String,Any}("MaxTime" => 0.05)),
            opts_radio_disp = Dict{String, Any}("MaxTime" => 0.05, "RadioOpts" => Dict(
                "Apply" => true,
                "FORW" => Dict("Enabled" => true, "X1" => Dict("Name" => "X1_Radio", "Unit" => "mg")),
                "REVE" => Dict("Enabled" => true, "Yield" => Dict("Name" => "Yield_Radio", "Unit" => "%"))
            )),
            (core_radio, _) = Lib_Vise.VISE_ExecuteInternal_DDEF(deepcopy(df_core), cfg_core, "Phase1", goals_core, "linear"; Opts=opts_radio_disp, RenderMode=:Minimal),
            (fail_mod, _) = Lib_Vise.VISE_SelectBestModel_DDEF(zeros(5, 3), rand(5), ["X1", "X2", "X3"], "Auto"),
            cv_short = Lib_Vise.VISE_CrossValidate_DDEF(rand(3, 2), rand(3), "linear"),
            df_multi = vcat(df_core, DataFrame(
                C.COL_EXP_ID => ["EXP_P2_01", "EXP_P2_02"],
                C.COL_PHASE => ["Phase2", "Phase2"],
                C.PRE_VAR * "X1" => [0.0, 1.0],
                C.PRE_VAR * "X2" => [0.0, 1.0],
                C.PRE_VAR * "X3" => [0.0, 1.0],
                C.PRE_RESULT * "Yield" => [15.0, 18.0],
                C.PRE_RESULT * "Purity" => [12.0, 14.0]
            ); cols=:union),
            t_core_xlsx = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_VISE_EXEC.xlsx"),
            t_exp_xlsx  = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_VISE_EXP.xlsx"),
            t_exp_full = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_EXP_FULL.xlsx"),
            rad_audit = [
                Dict("Name" => "Ga-68", "Type" => "FORW (Fixed)", "HalfLife" => 67.71, "Unit" => "min", "AvgDeltaT" => 30.0, "AvgDF" => 0.73, "IsCorrected" => true),
                Dict("Name" => "Lu-177", "Type" => "REVE (Product)", "HalfLife" => 6.647, "Unit" => "days", "AvgDeltaT" => 60.0, "AvgDF" => 0.99, "IsCorrected" => false)
            ],
            bundle_full_vise = merge(deepcopy(core_res), Dict(
                "RadioCorrection" => rad_audit, "RadioAudit" => rad_audit,
                "BoundaryWarnings" => ["X1 near boundary limits"], "Warns" => ["Notice: Minor residual variance"],
                "BestScore" => 0.95
            )),
            rep_full_md = Lib_Vise.VISE_GenSciReport_DDEF(bundle_full_vise),
            fail_samples = Lib_Vise.VISE_ExecuteInternal_DDEF(df_core[1:2, :], cfg_core, "Phase1", goals_core)[1],
            exp_full_ok = Lib_Vise.VISE_ExportToExcel_DDEF(bundle_full_vise, t_exp_full)
            Sys_Fast.FAST_CleanTransient_DDEF(t_exp_full)
            Sys_Fast.FAST_CleanTransient_DDEF(t_core_xlsx)
            Sys_Fast.FAST_CleanTransient_DDEF(t_exp_xlsx)
            Sys_Fast.FAST_WriteExcel_DDEF(t_core_xlsx, Dict(
                C.SHEET_DATA => df_multi,
                C.SHEET_CONFIG => DataFrame("PARAMETER" => ["MasterConfig"], "VALUE_JSON" => [JSON3.write(cfg_core)])
            ))
            exec_res = Lib_Vise.VISE_Execute_DDEF(t_core_xlsx, "Phase1", goals_core, "quadratic"; Opts=Dict{String,Any}("MaxTime" => 0.2, "GridSteps" => 21), ConfigUpdates=Dict{String,Any}("CustomParam" => "MergedVal"), Optim=true)
            exec_no_opt = Lib_Vise.VISE_Execute_DDEF(t_core_xlsx, "Phase1", goals_core, "quadratic"; Optim=false)
            exec_bad_phase = Lib_Vise.VISE_Execute_DDEF(t_core_xlsx, "PhaseNonExistent", goals_core)
            exp_ok = Lib_Vise.VISE_ExportToExcel_DDEF(core_res, t_exp_xlsx)
            exp_bad = Lib_Vise.VISE_ExportToExcel_DDEF(core_res, Sys_Fast.FAST_TempRoot_DDEC)
            Sys_Fast.FAST_CleanTransient_DDEF(t_core_xlsx)
            Sys_Fast.FAST_CleanTransient_DDEF(t_exp_xlsx)
            @track G4 exec_res["Status"] == "OK" && exec_no_opt["Status"] == "OK" && haskey(exec_no_opt, "_Hidden_Sheets") &&
                      exec_bad_phase["Status"] == "FAIL" && exp_ok && !exp_bad && exp_full_ok &&
                      contains(rep_full_md, "Radiochemical Decay Corrections") && fail_samples["Status"] == "FAIL" &&
                      core_radio["Status"] == "OK" && fail_mod["Status"] == "FAIL" && isnan(cv_short)
        end

        # 65: Phase data extraction and row partition filters
        let C = Sys_Fast.FAST_Data_DDEC,
            df_core = DataFrame(
                C.COL_EXP_ID => ["EXP_$i" for i in 1:15],
                C.COL_PHASE => fill("Phase1", 15),
                C.PRE_VAR * "X1" => X_quad[:, 1],
                C.PRE_VAR * "X2" => X_quad[:, 2],
                C.PRE_VAR * "X3" => X_quad[:, 3],
                C.PRE_RESULT * "Yield" => Y_quad,
                C.PRE_RESULT * "Purity" => fill(10.0, 15)
            ),
            t_ph_xlsx = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_PHASE_LOAD.xlsx"),
            _ = Sys_Fast.FAST_WriteExcel_DDEF(t_ph_xlsx, Dict(C.SHEET_DATA => df_core)),
            df_ph_file  = Lib_Vise.VISE_LoadPhaseData_DDEF(t_ph_xlsx, "Phase1", C),
            _ = Sys_Fast.FAST_CleanTransient_DDEF(t_ph_xlsx),
            df_ph_empty = Lib_Vise.VISE_LoadPhaseData_DDEF(DataFrame(), "Phase1", C),
            df_ph_all   = Lib_Vise.VISE_LoadPhaseData_DDEF(df_core, "", C),
            df_ph_p1    = Lib_Vise.VISE_LoadPhaseData_DDEF(df_core, "Phase1", C),
            df_ph_noph  = Lib_Vise.VISE_LoadPhaseData_DDEF(DataFrame("A" => [1.0]), "Phase1", C)
            @track G4 isempty(df_ph_empty) && nrow(df_ph_all) == 15 && nrow(df_ph_p1) == 15 &&
                      nrow(df_ph_file) == 15 && nrow(df_ph_noph) == 1
        end
    end
    TRACKER["G4"].duration = round(time() - t_g4; digits=2)

    # ==========================================================================
    # GROUP 5: Lib_Arts Academic Visualisation & Viridis Engine (10 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G5"
    t_g5 = time()
    @testset "Group 5: Lib_Arts Academic Visualisation & Viridis Engine" begin
        X_arts = Float64.(Lib_Core.CORE_DesignBB15_DDEC)
        Y_arts = [10.0 + 2.0*r[1] for r in eachrow(X_arts)]
        model_arts = Lib_Vise.VISE_Regress_DDEF(X_arts, Y_arts, "linear"; InNames=["X1", "X2", "X3"])

        # 66: Pareto effect chart and significance threshold
        let p_pareto = Lib_Arts.ARTS_RenderPareto_DDEF(model_arts, "Yield", 0.9, 0.8),
            p_fail = Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotPareto_DDES(), Dict("Status" => "FAIL"), "Yield", 0.0, 0.0),
            p_nocoef = Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotPareto_DDES(), Dict("Status" => "OK", "Coefs" => Float64[]), "Yield", 0.0, 0.0)
            @track G5 p_pareto isa PlotlyJS.Plot && p_fail isa PlotlyJS.Plot && p_nocoef isa PlotlyJS.Plot
        end

        # 67: Fit diagnostic observed versus predicted plots
        let p_fit = Lib_Arts.ARTS_RenderFit_DDEF(Y_arts, Y_arts, "Yield"),
            p_draw_fit = Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotFit_DDES(), Y_arts, Y_arts, "Yield"),
            p_flat = Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotFit_DDES(), fill(10.0, 15), fill(10.0, 15), "FlatOut")
            @track G5 p_fit isa PlotlyJS.Plot && p_draw_fit isa PlotlyJS.Plot && p_flat isa PlotlyJS.Plot
        end

        # 68: Residual normality QQ and fitted value plot maps
        let p_qq = Lib_Arts.ARTS_RenderQQ_DDEF(Y_arts .- 10.0, "Yield"),
            p_res = Lib_Arts.ARTS_RenderResiduals_DDEF(Y_arts, Y_arts .- 10.0, "Yield")
            @track G5 p_qq isa PlotlyJS.Plot && p_res isa PlotlyJS.Plot
        end

        # 69: Factor sensitivity gradient bar chart rendering
        let p_sens = Lib_Arts.ARTS_RenderSensitivity_DDEF([0.5, 0.3, 0.2], ["X1", "X2", "X3"], "Yield")
            @track G5 p_sens isa PlotlyJS.Plot
        end

        # 70: Response surface 2D contour and slice profiles
        let p_cont = Lib_Arts.ARTS_RenderContour_DDEF(model_arts, X_arts, [1, 2], ["X1", "X2"], "Yield"),
            p_slice = Lib_Arts.ARTS_RenderSlice_DDEF(model_arts, X_arts, [1, 2], ["X1", "X2"], "Yield")
            @track G5 p_cont isa PlotlyJS.Plot && p_slice isa PlotlyJS.Plot && length(Lib_Arts.ARTS_SlicePairs_DDEC) == 6
        end

        # 71: Factor interaction matrix and trend line plots
        let p_trend = Lib_Arts.ARTS_RenderTrend_DDEF(model_arts, X_arts, Y_arts, [1], ["X1"], "Yield"),
            p_imat = Lib_Arts.ARTS_RenderInteractionMatrix_DDEF(model_arts, ["X1", "X2", "X3"], "Yield"),
            imat_lin = Lib_Arts.ARTS_GetInteractionMatrix_DDEF(Lib_Core.CORE_ModelLinear_DDES(), [1.0, 2.0, 3.0, 4.0]),
            imat_quad = Lib_Arts.ARTS_GetInteractionMatrix_DDEF(Lib_Core.CORE_ModelQuadratic_DDES(), collect(1.0:10.0))
            @track G5 p_trend isa PlotlyJS.Plot && p_imat isa PlotlyJS.Plot &&
                      size(imat_lin) == (3, 3) && size(imat_quad) == (3, 3)
        end

        # 72: 3D response surface mesh and camera projections
        let p_surf = Lib_Arts.ARTS_RenderSurface_DDEF(model_arts, X_arts, [1, 2], ["X1", "X2"], "Yield"),
            m_quad = Lib_Vise.VISE_Regress_DDEF(X_arts, Y_arts, "quadratic"; InNames=["X1", "X2", "X3"]),
            p_surf_quad = Lib_Arts.ARTS_RenderSurface_DDEF(m_quad, X_arts, [1, 2], ["X1", "X2"], "Yield"),
            p_cont_quad = Lib_Arts.ARTS_RenderContour_DDEF(m_quad, X_arts, [1, 2], ["X1", "X2"], "Yield"),
            p_slice_quad = Lib_Arts.ARTS_RenderSlice_DDEF(m_quad, X_arts, [1, 2], ["X1", "X2"], "Yield")
            @track G5 p_surf isa PlotlyJS.Plot && p_surf_quad isa PlotlyJS.Plot &&
                      p_cont_quad isa PlotlyJS.Plot && p_slice_quad isa PlotlyJS.Plot
        end

        # 73: Design sweet spot space and candidate zone maps
        let (p_oz, oz_pct) = Lib_Arts.ARTS_RenderOptimalZone_DDEF([model_arts], [Dict("Type"=>"Maximise", "Min"=>0.0, "Max"=>50.0)], X_arts, ["X1", "X2", "X3"]),
            (p_fs, fs_pct) = Lib_Arts.ARTS_RenderFeasibleSpace_DDEF([model_arts], [Dict("Type"=>"Maximise", "Min"=>0.0, "Max"=>50.0)], X_arts, ["X1", "X2", "X3"]),
            (p_ss, ss_pct) = Lib_Arts.ARTS_RenderSweetSpot_DDEF([model_arts], [Dict("Type"=>"Maximise", "Min"=>0.0, "Max"=>50.0)], X_arts, ["X1", "X2", "X3"]),
            p_sp = Lib_Arts.ARTS_RenderDesignSpace_DDEF([model_arts], [Dict("Type"=>"Maximise", "Min"=>0.0, "Max"=>50.0)], X_arts, [1, 2], ["X1", "X2", "X3"]),
            (p_ca, ca_pct) = Lib_Arts.ARTS_RenderCandidates_DDEF([model_arts], [Dict("Type"=>"Maximise", "Min"=>0.0, "Max"=>50.0)], X_arts, [1, 2], ["X1", "X2", "X3"]),
            m_nan = Dict("Status" => "OK", "ModelType" => "linear", "Coefs" => [NaN, NaN, NaN, NaN]),
            (p_fs_nan, _) = Lib_Arts.ARTS_RenderFeasibleSpace_DDEF([m_nan], [Dict("Type"=>"Maximise", "Min"=>0.0, "Max"=>50.0)], X_arts, ["X1", "X2", "X3"]),
            (p_oz_nan, _) = Lib_Arts.ARTS_RenderOptimalZone_DDEF([m_nan], [Dict("Type"=>"Maximise", "Min"=>0.0, "Max"=>50.0)], X_arts, ["X1", "X2", "X3"]),
            (p_ss_nan, _) = Lib_Arts.ARTS_RenderSweetSpot_DDEF([m_nan], [Dict("Type"=>"Maximise", "Min"=>0.0, "Max"=>50.0)], X_arts, ["X1", "X2", "X3"]),
            (p_ca_nan, _) = Lib_Arts.ARTS_RenderCandidates_DDEF([m_nan], [Dict("Type"=>"Maximise", "Min"=>0.0, "Max"=>50.0)], X_arts, [1, 2], ["X1", "X2", "X3"])
            @track G5 p_oz isa PlotlyJS.Plot && p_fs isa PlotlyJS.Plot && p_ss isa PlotlyJS.Plot &&
                      p_sp isa PlotlyJS.Plot && p_ca isa PlotlyJS.Plot &&
                      p_fs_nan isa PlotlyJS.Plot && p_oz_nan isa PlotlyJS.Plot &&
                      p_ss_nan isa PlotlyJS.Plot && p_ca_nan isa PlotlyJS.Plot &&
                      !isempty(oz_pct) && !isempty(fs_pct) && !isempty(ss_pct) && !isempty(ca_pct)
        end

        # 74: Visual orchestrator multi-mode render pipelines
        let g_full = Lib_Arts.ARTS_Render_DDEF([model_arts], X_arts, reshape(Y_arts, :, 1), ["X1", "X2", "X3"], ["Yield"], [Dict("Type"=>"Maximise", "Min"=>0.0, "Max"=>50.0)], [0.95], [0.90], Dict("Mode" => :Full), DataFrame(), [[0.5, 0.3, 0.2]], [Y_arts .- 10.0]),
            g_prio = Lib_Arts.ARTS_Render_DDEF([model_arts], X_arts, reshape(Y_arts, :, 1), ["X1", "X2", "X3"], ["Yield"], [Dict("Type"=>"Maximise", "Min"=>0.0, "Max"=>50.0)], [0.95], [0.90], Dict("Mode" => :Priority)),
            g_def  = Lib_Arts.ARTS_Render_DDEF([model_arts], X_arts, reshape(Y_arts, :, 1), ["X1", "X2", "X3"], ["Yield"], [Dict("Type"=>"Maximise", "Min"=>0.0, "Max"=>50.0)], [0.95], [0.90], Dict("Mode" => :Deferred))
            @track G5 length(g_full) >= 5 && length(g_prio) >= 2 && length(g_def) >= 3 &&
                      length(Lib_Arts.ARTS_PlotPriority_DDEC) == 15 &&
                      Lib_Arts.ARTS_PlotPriority_DDEC["SweetSpot"] == 15 &&
                      Lib_Arts.ARTS_PlotPriority_DDEC["FeasibleSpace"] == 13
        end

        # 75: Viridis colour scale, hex alpha, and grid maths
        let ds = Lib_Arts.ARTS_Downsample_DDEF(X_arts, 5, 2),
            (gx1, gx2, gmat) = Lib_Arts.ARTS_BuildGrid_DDEF(X_arts, 1, 2, 10),
            sm = Lib_Arts.ARTS_SmoothMatrix_DDEF(rand(5, 5), 2),
            sm_nan = Lib_Arts.ARTS_SmoothMatrix_DDEF([1.0 2.0 NaN; 4.0 NaN 6.0; 7.0 8.0 9.0], 1),
            rgba = Lib_Arts.ARTS_HexToRGBA_DDEF("#112233", 0.5),
            av = Lib_Arts.ARTS_GenAlphaViridis_DDEF(0.5),
            bl = Lib_Arts.ARTS_BuildBaseLayout_DDEF("Test Base Layout"; height=450),
            p_mat = Lib_Arts.ARTS_PrepareMatrix_DDEF([1.0, 2.0, 3.0]),
            p_vvec = Lib_Arts.ARTS_PrepareMatrix_DDEF([[1.0, 2.0], [3.0, 4.0]]),
            p_subm = Lib_Arts.ARTS_PrepareMatrix_DDEF(view(ones(3, 3), 1:2, 1:2)),
            p_str = Lib_Arts.ARTS_PrepareStringVector_DDEF(["A", "B"]),
            p_syms = Lib_Arts.ARTS_PrepareStringVector_DDEF([:A, :B]),
            p_flt = Lib_Arts.ARTS_PrepareFloatVector_DDEF([1.0, 2.0]),
            p_ints = Lib_Arts.ARTS_PrepareFloatVector_DDEF([1, 2, 3]),
            p_nst = Lib_Arts.ARTS_PrepareNestedVector_DDEF([[1.0, 2.0]]),
            dyn_n = Lib_Arts.ARTS_GetDynamicGridN_DDEF(),
            ad_n = Lib_Arts.ARTS_CalcAdaptiveGridN_DDEF(50),
            ad_large = Lib_Arts.ARTS_CalcAdaptiveGridN_DDEF(200, 1000)
            @track G5 size(ds, 1) <= 6 && size(gmat, 2) == 3 &&
                      size(sm) == (5, 5) && size(sm_nan) == (3, 3) && startswith(rgba, "rgba(") && length(av) >= 5 &&
                      bl isa PlotlyJS.Layout && length(p_mat) == 3 && size(p_vvec) == (2, 2) && size(p_subm) == (2, 2) &&
                      length(p_str) == 2 && length(p_syms) == 2 &&
                      length(p_flt) == 2 && length(p_ints) == 3 && length(p_nst) == 1 &&
                      dyn_n >= 61 && ad_n <= 50 && ad_large <= 31
        end
    end
    TRACKER["G5"].duration = round(time() - t_g5; digits=2)

    # ==========================================================================
    # GROUP 6: Sys_Flow ACTA Adaptive Transitions & Space Map (10 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G6"
    t_g6 = time()
    @testset "Group 6: Sys_Flow ACTA Adaptive Transitions & Space Map" begin
        # 76: ASTM affine transformation and boundary clamping
        let map_mid = Sys_Flow.FLOW_ApplyASTM_DDEF(10.0, 1.5, 5.0),
            map_zero = Sys_Flow.FLOW_ApplyASTM_DDEF(0.0, 1.5, 5.0),
            (ok_b, val_b, _) = Sys_Flow.FLOW_ValidateASTM_DDEF(95.0, 0.0, 90.0),
            (ok_lo, val_lo, _) = Sys_Flow.FLOW_ValidateASTM_DDEF(-10.0, 0.0, 100.0),
            (ok_hi, val_hi, _) = Sys_Flow.FLOW_ValidateASTM_DDEF(150.0, 0.0, 100.0),
            src_nil  = Sys_Flow.FLOW_ResolveSource_DDEF(nothing),
            src_any  = Sys_Flow.FLOW_ResolveSource_DDEF(123),
            src_tok  = Sys_Flow.FLOW_ResolveSource_DDEF("NON_EXISTENT_TOKEN_XYZ")
            @track G6 map_mid == 20.0 && map_zero == 5.0 && !ok_b && val_b == 90.0 &&
                      !ok_lo && val_lo == 0.0 && !ok_hi && val_hi == 100.0 &&
                      isempty(src_nil) && isempty(src_any) && isempty(src_tok)
        end

        # 77: ASTM boundary status, telemetry alert and range contraction dispatch
        let b_lo      = Sys_Flow.FLOW_ValidateBoundaryStatus_DDEF(2.0, 0.0, 100.0),
            b_hi      = Sys_Flow.FLOW_ValidateBoundaryStatus_DDEF(98.0, 0.0, 100.0),
            b_sf      = Sys_Flow.FLOW_ValidateBoundaryStatus_DDEF(50.0, 0.0, 100.0),
            tag_safe  = Sys_Flow.FLOW_GetActionTag_DDEF(Sys_Flow.FLOW_BoundarySafe_DDES()),
            tag_low   = Sys_Flow.FLOW_GetActionTag_DDEF(Sys_Flow.FLOW_BoundaryLower_DDES()),
            alert_low = Sys_Flow.FLOW_CheckBoundaryAlert_DDEF(Sys_Flow.FLOW_BoundaryLower_DDES())[2],
            rng_sf    = Sys_Flow.FLOW_ContractRange_DDEF(Sys_Flow.FLOW_BoundarySafe_DDES(), 10.0, 0.5),
            rng_lo    = Sys_Flow.FLOW_ContractRange_DDEF(Sys_Flow.FLOW_BoundaryLower_DDES(), 10.0, 0.5)
            @track G6 b_lo isa Sys_Flow.FLOW_BoundaryLower_DDES &&
                      b_hi isa Sys_Flow.FLOW_BoundaryUpper_DDES &&
                      b_sf isa Sys_Flow.FLOW_BoundarySafe_DDES &&
                      tag_safe == "CONTRACTION" && tag_low == "TRANS_AUTO" &&
                      occursin("LOWER", alert_low) &&
                      rng_sf == 5.0 && rng_lo == 10.0
        end

        # 78: Leader proximity evaluation and threshold checks
        let ask_mid  = Sys_Flow.FLOW_AuditLeader_DDEF(50.0, [0.0, 50.0, 100.0]),
            ask_low  = Sys_Flow.FLOW_AuditLeader_DDEF(1.0, [0.0, 50.0, 100.0]),
            ask_safe = Sys_Flow.FLOW_AuditLeader_DDEF(20.0, [10.0, 20.0, 30.0]),
            ask_edge_lo = Sys_Flow.FLOW_AuditLeader_DDEF(10.1, [10.0, 20.0, 30.0]),
            ask_edge_hi = Sys_Flow.FLOW_AuditLeader_DDEF(29.9, [10.0, 20.0, 30.0])
            @track G6 ask_mid[1] == true && ask_low[1] == false &&
                      ask_safe[1] == true && ask_edge_lo[1] == false && ask_edge_hi[1] == false
        end

        # 79: Adaptive range contraction, clamping and multi-variable profiling via ACTA
        let z_rng = Sys_Flow.FLOW_CalcACTA_DDEF(50.0, [0.0, 50.0, 100.0], 0.5, 0.0, 0.0),
            s_rng = Sys_Flow.FLOW_CalcACTA_DDEF(98.0, [0.0, 50.0, 100.0], 1.0, 0.2, 0.0),
            c_rng = Sys_Flow.FLOW_CalcACTA_DDEF(2.0, [0.0, 50.0, 100.0], 1.0, 0.2, 0.0),
            u_neg = Sys_Flow.FLOW_CalcACTA_DDEF(99.0, [0.0, 50.0, 100.0], 0.8, -0.2, -10.0),
            l_pos = Sys_Flow.FLOW_CalcACTA_DDEF(1.0, [0.0, 50.0, 100.0], 0.8, 0.2, 0.0),
            r2    = Sys_Flow.FLOW_CalcACTA_DDEF(9.5, [0.0, 5.0, 10.0], 0.8, 0.1, 0.0),
            r3    = Sys_Flow.FLOW_CalcACTA_DDEF(105.0, [100.0, 200.0, 300.0], 0.6, 0.1, 0.0)
            @track G6 (z_rng[3] - z_rng[1]) == 50.0 && s_rng[2] > 98.0 && c_rng[1] >= 0.0 &&
                      length(u_neg) == 3 && length(l_pos) == 3 &&
                      r2[2] > 9.5 && r3[1] >= 0.0
        end

        # 80: Method traits, spatial direction and state dispatch helpers
        let m_df      = Sys_Flow.FLOW_ResolveMethod_DDEF(" df14 "),
            m_un      = Sys_Flow.FLOW_ResolveMethod_DDEF("UNKNOWN"),
            d_map     = Sys_Flow.FLOW_GetDirectionMap_DDEF(m_df, ["A", "B", "C"], [1, -1, 1]),
            d_nil     = Sys_Flow.FLOW_GetDirectionMap_DDEF(m_df, ["A", "B", "C"], nothing),
            s_dir     = Sys_Flow.FLOW_GetStoredDirection_DDEF(m_df, [1, -1, 1]),
            u_dir     = Sys_Flow.FLOW_GetStoredDirection_DDEF(m_un, [1, -1, 1]),
            fb        = [Dict{String,Any}("Name" => "A")],
            cfg_nil   = Sys_Flow.FLOW_ResolveConfig_DDEF(nothing, fb),
            cfg_empty = Sys_Flow.FLOW_ResolveConfig_DDEF([], fb),
            d_norm    = Sys_Flow.FLOW_FormatStringDict_DDEF(Dict(:k => 1, :sub => Dict(:inner => 2))),
            res_nil   = Sys_Flow.FLOW_ResolveSource_DDEF(nothing),
            res_str   = Sys_Flow.FLOW_ResolveSource_DDEF("   "),
            res_store = Sys_Flow.FLOW_ResolveSource_DDEF(Dict("filepath" => "dummy.xlsx")),
            fcfg_nil  = Sys_Fast.FAST_ReadConfig_DDEF(nothing),
            safe_k    = Sys_Fast.FAST_SafeGet_DDEF(Dict("Name" => "TestVar"), "Name")
            @track G6 m_df isa Lib_Core.CORE_MethodDF14_DDES &&
                      m_un isa Lib_Core.CORE_MethodTL09_DDES &&
                      s_dir == [1, -1, 1] && isnothing(u_dir) &&
                      d_map["B"] == -1 && isnothing(d_nil) &&
                      Sys_Flow.FLOW_IsTruthy_DDEF(" True ") && !Sys_Flow.FLOW_IsTruthy_DDEF(nothing) &&
                      !Sys_Flow.FLOW_IsValidFile_DDEF(nothing) && !Sys_Flow.FLOW_IsFilled_DDEF("") &&
                      d_norm["k"] == 1 && d_norm["sub"]["inner"] == 2 && cfg_nil === fb && cfg_empty === fb &&
                      res_nil == "" && res_str == "" && res_store == "" && isempty(fcfg_nil) && safe_k == "TestVar"
        end

        # 81: Candidate extraction and leader ranking from file
        let temp_lead_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_LEADERS.xlsx")
            Sys_Fast.FAST_CleanTransient_DDEF(temp_lead_file)
            df_leads = DataFrame(
                "EXP_ID" => ["RUN_01", "RUN_02"],
                "SCORE" => [0.82, 0.94],
                "PHASE" => ["Phase1", "Phase1"],
                "X1" => [20.0, 20.0],
                "X2" => [2.0, 2.0],
                "X3" => [200.0, 200.0]
            )
            Sys_Fast.FAST_WriteExcel_DDEF(temp_lead_file, Dict(Sys_Fast.FAST_Data_DDEC.PREFIX_LEADERS * "Phase1" => df_leads))
            cand_list = Sys_Flow.FLOW_GetCandidates_DDEF(temp_lead_file, "Phase1")
            Sys_Fast.FAST_CleanTransient_DDEF(temp_lead_file)
            @track G6 length(cand_list) == 2 && cand_list[1]["Score"] == 0.94
        end

        # 82: Next phase IPKT configuration build and contract
        let temp_lead_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_LEADERS.xlsx"),
            C_flow = Sys_Fast.FAST_Data_DDEC
            Sys_Fast.FAST_CleanTransient_DDEF(temp_lead_file)
            df_leads = DataFrame("EXP_ID" => ["RUN_01", "RUN_02"], "SCORE" => [0.82, 0.94], "PHASE" => ["Phase1", "Phase1"], "X1" => [20.0, 20.0], "X2" => [2.0, 2.0], "X3" => [200.0, 200.0])
            df_cfg_flow = DataFrame("PARAMETER" => ["MasterConfig"], "VALUE_JSON" => [JSON3.write(Dict(
                "Ingredients" => [
                    Dict("Name" => "X1", "Role" => C_flow.ROLE_VAR, "Levels" => [10.0, 20.0, 30.0]),
                    Dict("Name" => "X2", "Role" => C_flow.ROLE_VAR, "Levels" => [1.0, 2.0, 3.0]),
                    Dict("Name" => "X3", "Role" => C_flow.ROLE_VAR, "Levels" => [100.0, 200.0, 300.0])
                ],
                "Global" => Dict("Volume" => 10.0, "Conc" => 1.0)
            ))])
            Sys_Fast.FAST_WriteExcel_DDEF(temp_lead_file, Dict(C_flow.SHEET_CONFIG => df_cfg_flow, C_flow.PREFIX_LEADERS * "Phase1" => df_leads))
            next_phase_res = Sys_Flow.FLOW_BuildIPKT_DDEF(temp_lead_file, "Phase1", "RUN_02", 0.5, 0.0)
            old_span1 = next_phase_res["OldConfig"][1]["Levels"][3] - next_phase_res["OldConfig"][1]["Levels"][1]
            new_span1 = next_phase_res["NewConfig"][1]["Levels"][3] - next_phase_res["NewConfig"][1]["Levels"][1]
            Sys_Fast.FAST_CleanTransient_DDEF(temp_lead_file)
            ph1_next = Sys_Flow.FLOW_AdvancePhase_DDEF("Phase1")
            ph2_next = Sys_Flow.FLOW_AdvancePhase_DDEF("Phase2")
            ph3_next = Sys_Flow.FLOW_AdvancePhase_DDEF("Phase3")
            ph_c_next = Sys_Flow.FLOW_AdvancePhase_DDEF("Phase 10")
            ph_t1 = Sys_Flow.FLOW_AdvancePhase_DDEF(Sys_Flow.FLOW_PhasePrimary_DDES())
            ph_t2 = Sys_Flow.FLOW_AdvancePhase_DDEF(Sys_Flow.FLOW_PhaseSecondary_DDES())
            ph_t3 = Sys_Flow.FLOW_AdvancePhase_DDEF(Sys_Flow.FLOW_PhaseTertiary_DDES())
            ph_raw = Sys_Flow.FLOW_GetPhaseType_DDEF(Sys_Flow.FLOW_PhasePrimary_DDES())
            @track G6 next_phase_res["Status"] == "OK" && next_phase_res["TargetPhase"] == "Phase2" &&
                      isapprox(new_span1, old_span1 * 0.5; atol=1e-3) && next_phase_res["LeaderScore"] == 0.94 &&
                      ph1_next == "Phase2" && ph2_next == "Phase3" && ph3_next == "Phase4" &&
                      ph_c_next == "Phase11" && ph_t1 == "Phase2" && ph_t2 == "Phase3" && ph_t3 == "Phase4" &&
                      ph_raw isa Sys_Flow.FLOW_PhasePrimary_DDES
        end

        # 83: Phase transition fallback and missing data audit
        let temp_lead_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_LEADERS.xlsx"),
            C_flow = Sys_Fast.FAST_Data_DDEC
            Sys_Fast.FAST_CleanTransient_DDEF(temp_lead_file)
            df_leads = DataFrame("EXP_ID" => ["RUN_01", "RUN_02"], "SCORE" => [0.82, 0.94], "PHASE" => ["Phase1", "Phase1"], "X1" => [20.0, 20.0], "X2" => [2.0, 2.0], "X3" => [200.0, 200.0])
            df_cfg_flow = DataFrame("PARAMETER" => ["MasterConfig"], "VALUE_JSON" => [JSON3.write(Dict(
                "Ingredients" => [
                    Dict("Name" => "X1", "Role" => C_flow.ROLE_VAR, "Levels" => [10.0, 20.0, 30.0]),
                    Dict("Name" => "X2", "Role" => C_flow.ROLE_VAR, "Levels" => [1.0, 2.0, 3.0]),
                    Dict("Name" => "X3", "Role" => C_flow.ROLE_VAR, "Levels" => [100.0, 200.0, 300.0])
                ],
                "Global" => Dict("Volume" => 10.0, "Conc" => 1.0)
            ))])
            Sys_Fast.FAST_WriteExcel_DDEF(temp_lead_file, Dict(C_flow.SHEET_CONFIG => df_cfg_flow, C_flow.PREFIX_LEADERS * "Phase1" => df_leads))
            cands = Sys_Flow.FLOW_GetCandidates_DDEF(temp_lead_file, "Phase1")
            cands_empty = Sys_Flow.FLOW_GetCandidates_DDEF(nothing, "Phase1")
            cands_nophase = Sys_Flow.FLOW_GetCandidates_DDEF(temp_lead_file, nothing)
            bad_lead_res = Sys_Flow.FLOW_BuildIPKT_DDEF(temp_lead_file, "Phase1", "NON_EXISTENT_LEADER", 0.5, 0.0)
            nil_file_res = Sys_Flow.FLOW_BuildIPKT_DDEF(nothing, "Phase1", "RUN_01", 0.5, 0.0)
            nil_phase_res = Sys_Flow.FLOW_BuildIPKT_DDEF(temp_lead_file, "", "RUN_01", 0.5, 0.0)
            Sys_Fast.FAST_CleanTransient_DDEF(temp_lead_file)
            @track G6 bad_lead_res["Status"] == "OK" && bad_lead_res["LeaderScore"] == 0.94 &&
                      nil_file_res["Status"] == "FAIL" && nil_phase_res["Status"] == "FAIL" &&
                      length(cands) == 2 && isempty(cands_empty) && isempty(cands_nophase)
        end

        # 84: Phase transition visualisation and chart payload
        let old_conf_m = [
                Dict("Name" => "Temp", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [20.0, 50.0, 80.0]),
                Dict("Name" => "Time", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [10.0, 20.0, 30.0]),
                Dict("Name" => "Dose", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [1.0, 2.0, 3.0])
            ],
            new_conf_m = [
                Dict("Name" => "Temp", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [35.0, 50.0, 65.0]),
                Dict("Name" => "Time", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [20.0, 25.0, 30.0]),
                Dict("Name" => "Catalyst", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [1.5, 2.0, 2.5], "IsReplaced" => true)
            ],
            shift_up = [
                Dict("Name" => "Temp", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [100.0, 110.0, 120.0]),
                Dict("Name" => "Time", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [10.0, 20.0, 30.0]),
                Dict("Name" => "Dose", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [1.0, 2.0, 3.0])
            ],
            shift_lo = [
                Dict("Name" => "Temp", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [-60.0, -50.0, -40.0]),
                Dict("Name" => "Time", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [10.0, 20.0, 30.0]),
                Dict("Name" => "Dose", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [1.0, 2.0, 3.0])
            ],
            shift_wide = [
                Dict("Name" => "Temp", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [-100.0, 50.0, 200.0]),
                Dict("Name" => "Time", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [10.0, 20.0, 30.0]),
                Dict("Name" => "Dose", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [1.0, 2.0, 3.0])
            ],
            rend_trans = Sys_Flow.FLOW_RenderIPKT_DDEF(old_conf_m, new_conf_m, [50.0, 20.0, 2.0]; Method="DF14", Direction=[1, -1, 1]),
            rend_auto  = Sys_Flow.FLOW_RenderIPKT_DDEF(old_conf_m, new_conf_m, [50.0, 20.0, 2.0]; Method="TL09"),
            rend_up    = Sys_Flow.FLOW_RenderIPKT_DDEF(old_conf_m, shift_up, [110.0, 20.0, 2.0]),
            rend_lo    = Sys_Flow.FLOW_RenderIPKT_DDEF(old_conf_m, shift_lo, [-50.0, 20.0, 2.0]),
            rend_wide  = Sys_Flow.FLOW_RenderIPKT_DDEF(old_conf_m, shift_wide, [50.0, 20.0, 2.0]),
            rend_empty = Sys_Flow.FLOW_RenderIPKT_DDEF([], [], [])
            @track G6 haskey(rend_trans, "data") && haskey(rend_trans, "layout") && length(rend_trans["data"]) >= 3 &&
                      haskey(rend_auto, "data") && haskey(rend_empty, "layout") &&
                      haskey(rend_up, "data") && haskey(rend_lo, "data") && haskey(rend_wide, "data")
        end

        # 85: Phase parameter inheritance and commitment audit
        let conf_sample = [Dict("Name" => "Precursor", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [10.0, 20.0, 30.0], "MW" => 1435.0, "Unit" => "mg")],
            next_conf = Sys_Flow.FLOW_ApplyACTA_DDEF(Dict("OldConfig" => conf_sample, "Vals" => [20.0]), 0.5, 0.0),
            t_lead = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_LEAD_WRITE.xlsx"),
            t_build = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_FLOW_BUILD.xlsx")
            Sys_Fast.FAST_CleanTransient_DDEF(t_lead)
            df_to_write = DataFrame("EXP_ID" => ["P1_01"], "SCORE" => [0.95], "PHASE" => ["Phase1"])
            ok_write = Sys_Flow.FLOW_WriteLeaders_DDEF(t_lead, "Phase1", df_to_write)
            df_read_lead = Sys_Fast.FAST_ReadExcel_DDEF(t_lead, Sys_Fast.FAST_Data_DDEC.PREFIX_LEADERS * "Phase1")
            Sys_Fast.FAST_CleanTransient_DDEF(t_lead)

            Sys_Fast.FAST_CleanTransient_DDEF(t_build)
            df_init = DataFrame("EXP_ID" => ["EXP_P1_01", "EXP_P1_02"], "PHASE" => ["Phase1", "Phase1"], "Temp" => [25.0, 50.0], "Yield" => [70.0, 92.0])
            df_cfg = DataFrame("PARAMETER" => ["MasterConfig"], "VALUE_JSON" => [JSON3.write(Dict(
                "Ingredients" => [
                    Dict("Name" => "Temp", "Role" => "Variable", "Levels" => [25.0, 50.0, 75.0]),
                    Dict("Name" => "Time", "Role" => "Variable", "Levels" => [10.0, 20.0, 30.0], "Unit" => "min"),
                    Dict("Name" => "Dose", "Role" => "Variable", "Levels" => [1.0, 2.0, 3.0], "IsRadioactive" => true, "HalfLife" => 67.71, "Unit" => "mCi")
                ],
                "Outputs" => [Dict("Name" => "Yield", "Unit" => "%"), Dict("Name" => "Purity", "Unit" => "%")],
                "Global" => Dict("Volume" => 10.0, "Conc" => 1.0)
            ))])
            df_lead = DataFrame("EXP_ID" => ["EXP_P1_02"], "SCORE" => [0.92], "PHASE" => ["Phase1"], "Temp" => [50.0], "Time" => [20.0], "Dose" => [2.0])
            Sys_Fast.FAST_WriteExcel_DDEF(t_build, Dict(
                Sys_Fast.FAST_Data_DDEC.SHEET_DATA => df_init,
                Sys_Fast.FAST_Data_DDEC.SHEET_CONFIG => df_cfg,
                Sys_Fast.FAST_Data_DDEC.PREFIX_LEADERS * "Phase1" => df_lead
            ))
            res_build = Sys_Flow.FLOW_CommitIPKT_DDEF(t_build, "Phase1", "EXP_P1_02", 0.5, "TL09", 0.0)
            res_df14  = Sys_Flow.FLOW_CommitIPKT_DDEF(t_build, "Phase1", "EXP_P1_02", 0.5, "DF14", 0.0; Direction=[-1, 1, -1])
            res_custom = Sys_Flow.FLOW_CommitIPKT_DDEF(t_build, "Phase1", "EXP_P1_02", 0.5, "DF14", 0.0;
                Direction=[1, -1, 1], ProjectName="FlowProject",
                CustomConfig=[
                    Dict("Name" => "Temp", "Role" => "Variable", "Levels" => [30.0, 50.0, 70.0], "MW" => 100.0, "Unit" => "%m"),
                    Dict("Name" => "Time", "Role" => "Variable", "Levels" => [15.0, 20.0, 25.0], "MW" => 50.0, "Unit" => "min"),
                    Dict("Name" => "Dose", "Role" => "Variable", "Levels" => [1.5, 2.0, 2.5], "MW" => 20.0, "Unit" => "mCi", "IsRadioactive" => true, "HalfLife" => 67.71),
                    Dict("Name" => "Saline", "Role" => "Filler", "Levels" => [0.0, 0.0, 0.0], "MW" => 58.44, "Unit" => "%m")
                ])
            res_bad_vars = Sys_Flow.FLOW_CommitIPKT_DDEF(t_build, "Phase1", "EXP_P1_02", 0.5, "TL09", 0.0;
                CustomConfig=[Dict("Name" => "Temp", "Role" => "Variable", "Levels" => [30.0, 50.0, 70.0])])
            res_bad_chem = Sys_Flow.FLOW_CommitIPKT_DDEF(t_build, "Phase1", "EXP_P1_02", 0.5, "TL09", 0.0;
                CustomConfig=[
                    Dict("Name" => "A", "Role" => "Variable", "Levels" => [80.0, 80.0, 80.0], "MW" => 100.0, "Unit" => "%m"),
                    Dict("Name" => "B", "Role" => "Variable", "Levels" => [80.0, 80.0, 80.0], "MW" => 100.0, "Unit" => "%m"),
                    Dict("Name" => "C", "Role" => "Variable", "Levels" => [80.0, 80.0, 80.0], "MW" => 100.0, "Unit" => "%m"),
                    Dict("Name" => "Fill", "Role" => "Filler", "Levels" => [0.0, 0.0, 0.0], "MW" => 18.0, "Unit" => "%m")
                ])
            res_bad   = Sys_Flow.FLOW_CommitIPKT_DDEF(nothing, "Phase1")
            flow_src_any = Sys_Flow.FLOW_ResolveSource_DDEF(123)
            flow_val_any = Sys_Flow.FLOW_IsValidFile_DDEF(123)
            flow_src_trans = Sys_Flow.FLOW_ResolveSource_DDEF(Dict("DataHandle" => "nonexistent_transient_key"))
            flow_val_trans = Sys_Flow.FLOW_IsValidFile_DDEF(Dict("DataHandle" => "nonexistent_transient_key"))
            flow_dict_any = Sys_Flow.FLOW_FormatStringDict_DDEF("not_a_dict")
            flow_iter_dict = collect(Sys_Flow.FLOW_IterateEntries_DDEF(Dict("k" => 1)))
            flow_truth_real = Sys_Flow.FLOW_IsTruthy_DDEF(1)
            conf_l123 = [Dict("Name" => "VarL", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0)]
            acta_l123 = Sys_Flow.FLOW_ApplyACTA_DDEF(Dict("OldConfig" => conf_l123, "Vals" => [20.0]), 0.5, 0.0)
            lead_empty_vars = Lib_Core.CORE_ExtractLeader_DDEF(t_build, "Phase1", "EXP_P1_02", String[])
            Sys_Fast.FAST_CleanTransient_DDEF(t_build)
            @track G6 next_conf[1]["Name"] == "Precursor" && next_conf[1]["MW"] == 1435.0 && next_conf[1]["Unit"] == "mg" &&
                      ok_write == true && nrow(df_read_lead) == 1 && df_read_lead.SCORE[1] == 0.95 &&
                      res_build["Status"] == "OK" && res_df14["Status"] == "OK" && res_custom["Status"] == "OK" &&
                      res_bad_vars["Status"] == "FAIL" && res_bad_chem["Status"] == "FAIL" && res_bad["Status"] == "FAIL" &&
                      flow_src_any == "" && !flow_val_any && flow_src_trans == "" && !flow_val_trans &&
                      isempty(flow_dict_any) && length(flow_iter_dict) == 1 && flow_truth_real &&
                      length(acta_l123[1]["Levels"]) == 3 &&
                      lead_empty_vars["ID"] == "EXP_P1_02"
        end
    end
    TRACKER["G6"].duration = round(time() - t_g6; digits=2)

    # ==========================================================================
    # GROUP 7: Gui Presentation Shell, Dispatch & Runtime Motor (15 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G7"
    t_g7 = time()
    @testset "Group 7: Gui Presentation Shell, Dispatch & Runtime Motor" begin
        X_g7 = Float64.(Lib_Core.CORE_DesignBB15_DDEC)
        Y_g7 = [10.0 + 2.0*r[1] for r in eachrow(X_g7)]
        model_g7 = Lib_Vise.VISE_Regress_DDEF(X_g7, Y_g7, "linear"; InNames=["X1", "X2", "X3"])

        # 86: Academic mini vital card layout and token mapping
        let c_card = Gui_Base.BASE_BuildVitalCard_DDEF("Condition (κ)", "41.2", "var(--colour-chr4-tongre)"),
            c_nan  = Gui_Base.BASE_BuildVitalCard_DDEF("D-Eff", "-", "var(--colour-val3-darlow)")
            @track G7 c_card isa DashBootstrapComponents.Component && c_nan isa DashBootstrapComponents.Component
        end

        # 87: System and scientific audit dashboard tree layout
        let audit_sys = Gui_Base.BASE_BuildSystemAudit_DDEF(),
            audit_sci = Gui_Base.BASE_BuildSciAudit_DDEF(),
            g_panel = Gui_Base.BASE_BuildGlassPanel_DDEF("Test Panel", "Content"),
            b_modal = Gui_Base.BASE_BuildModal_DDEF("test_modal", "Title", "Body", "Footer"),
            (u_ok, _) = Gui_Base.BASE_ValidateUniqueNames_DDEF(["A", "B"], "Factor"),
            (u_dup, _) = Gui_Base.BASE_ValidateUniqueNames_DDEF(["A", "A"], "Factor"),
            (u_emp, _) = Gui_Base.BASE_ValidateUniqueNames_DDEF(["", "B"], "Factor"),
            fig_mock = Dict{String, Any}("layout" => Dict{String, Any}(
                "scene" => Dict{String, Any}("xaxis" => Dict{String, Any}(), "yaxis" => Dict{String, Any}(), "zaxis" => Dict{String, Any}()),
                "xaxis" => Dict{String, Any}(), "yaxis" => Dict{String, Any}()
            )),
            white_fig = Gui_Base.BASE_ApplyPlotlyWhite_DDEF!(fig_mock),
            (ov_style0, ov_poll0) = Gui_Base.BASE_HandleLoadingOverlay_DDEF(0),
            (ov_style16, ov_poll16) = Gui_Base.BASE_HandleLoadingOverlay_DDEF(20),
            (ov_style_rdy, ov_poll_rdy) = Gui_Base.BASE_HandleLoadingOverlay_DDEF(nothing),
            d_table = Gui_Base.BASE_BuildDataTable_DDEF("tbl_mock", [Dict("name" => "C1", "id" => "C1")], [Dict("C1" => 1)]),
            safe_nil_rows = Gui_Base.BASE_SafeRows_DDEF(nothing),
            safe_any_rows = Gui_Base.BASE_SafeRows_DDEF([Dict(:a => 1)]),
            trig_empty = Gui_Base.BASE_GetTrigger_DDEF((triggered = [],)),
            trig_found = Gui_Base.BASE_GetTrigger_DDEF((triggered = [(prop_id = "btn_id.n_clicks",),],)),
            load_comp = Gui_Base.BASE_BuildLoading_DDEF("loading_id", "content")
            @track G7 audit_sys isa DashBootstrapComponents.Component && length(audit_sys.children) >= 5 &&
                      audit_sci isa DashBootstrapComponents.Component && length(audit_sci.children) >= 4 &&
                      g_panel isa Dash.Component && b_modal isa Dash.Component &&
                      u_ok && !u_dup && !u_emp &&
                      haskey(white_fig["layout"], "template") && white_fig["layout"]["template"] == "plotly_white" &&
                      ov_poll16 && ov_poll_rdy && d_table isa Dash.Component &&
                      isempty(safe_nil_rows) && safe_any_rows[1]["a"] == 1 &&
                      isempty(trig_empty) && trig_found == "btn_id" && load_comp isa DashBootstrapComponents.Component
        end

        # 88: Deck and Lens primary application view layouts
        let deck_layout = Gui_Deck.DECK_BuildLayout_DDEF(),
            lens_layout = Gui_Lens.LENS_BuildLayout_DDEF(),
            header_comp = Gui_Base.BASE_BuildPageHeader_DDEF("Test Header", "Subtext description"),
            navbar_comp = Gui_Base.BASE_BuildNavbar_DDEF(),
            full_layout = Gui_Base.BASE_BuildLayout_DDEF(),
            btn_act = Gui_Base.BASE_BuildActionButton_DDEF("btn_act", "Action", "fas fa-check"),
            btn_nxt = Gui_Base.BASE_BuildNextButton_DDEF("btn_nxt", "Next"),
            btn_ico = Gui_Base.BASE_BuildIconButton_DDEF("btn_ico", "fas fa-sync"; tip="Sync tooltip"),
            st_icon = Gui_Base.BASE_BuildStatusIcon_DDEF("●", "st_ico"; tip="Status tooltip", glow=true),
            c_group = Gui_Base.BASE_BuildControlGroup_DDEF("Label", "Input"),
            tb_hdr = Gui_Base.BASE_BuildTableHeader_DDEF("Col"; style=Dict("backgroundColor" => "var(--colour-val0-purwhi)")),
            sep_el = Gui_Base.BASE_BuildSeparator_DDEF(),
            sb_hdr = Gui_Base.BASE_BuildSidebarHeader_DDEF("Side"; icon="fas fa-bars"),
            up_el = Gui_Base.BASE_BuildUpload_DDEF("up_id", "Upload", "fas fa-upload"),
            g_right = Gui_Base.BASE_BuildGlassPanel_DDEF("Panel", "Content"; right_node=html_span("Right")),
            r_id = Gui_Base.BASE_BuildIDRow_DDEF(1, Gui_Deck.DECK_GetDefaultRow_DDEF(1), true, true),
            r_id_rad = Gui_Base.BASE_BuildIDRow_DDEF(1, Dict("Name" => "RadioChem", "Role" => "Variable", "MW" => 150.0, "HalfLife" => 67.71, "IsRadioactive" => true), true),
            r_lvl = Gui_Base.BASE_BuildLevelRow_DDEF(1, Gui_Deck.DECK_GetDefaultRow_DDEF(1), true),
            r_lim = Gui_Base.BASE_BuildLimitsRow_DDEF(1, Gui_Deck.DECK_GetDefaultRow_DDEF(1), true),
            r_goal = Gui_Base.BASE_BuildGoalRow_DDEF(1),
            _ = Gui_Base.BASE_WarmupApp_DDEF(),
            _ = (ENV["DOECISORY_DEV"] = "true"; Gui_Base.BASE_WarmupApp_DDEF(); delete!(ENV, "DOECISORY_DEV")),
            _ = (ENV["DOECISORY_FAST_BOOT"] = "true"; Gui_Base.BASE_WarmupApp_DDEF(); delete!(ENV, "DOECISORY_FAST_BOOT"))
            @track G7 (deck_layout isa DashBootstrapComponents.Component || deck_layout isa Dash.Component) &&
                      (lens_layout isa DashBootstrapComponents.Component || lens_layout isa Dash.Component) &&
                      (header_comp isa DashBootstrapComponents.Component || header_comp isa Dash.Component) &&
                      navbar_comp isa Dash.Component && full_layout isa Dash.Component &&
                      btn_act isa Dash.Component && btn_nxt isa Dash.Component &&
                      btn_ico isa Dash.Component && st_icon isa Dash.Component &&
                      g_right isa Dash.Component && r_id_rad isa Dash.Component &&
                      r_id isa Dash.Component && r_lvl isa Dash.Component && r_lim isa Dash.Component && r_goal isa Dash.Component
        end

        # 89: Headless Dash application initialisation routine
        let headless_app = Gui_Base.BASE_CreateApp_DDEF()
            @track G7 headless_app isa Dash.DashApp && headless_app.layout isa Dash.Component
        end

        # 90: Multi-module Dash callback registration pipeline
        let headless_app = Gui_Base.BASE_CreateApp_DDEF(),
            _ = Gui_Base.BASE_RegisterAppCallbacks_DDEF(headless_app),
            _ = Gui_Deck.DECK_RegisterCallbacks_DDEF(headless_app),
            _ = Gui_Lens.LENS_RegisterCallbacks_DDEF(headless_app)
            @track G7 headless_app.layout isa Dash.Component && length(headless_app.callbacks) >= 40
        end

        # 91: Multi-page URL router dispatch and view resolution
        let routing_root = Gui_Base.BASE_RoutePage_DDEF("/"),
            routing_deck = Gui_Base.BASE_RoutePage_DDEF("/design"),
            routing_lens = Gui_Base.BASE_RoutePage_DDEF("/analysis"),
            routing_any  = Gui_Base.BASE_RoutePage_DDEF("/unregistered_portal_slug"),
            diag_open    = Gui_Base.BASE_RegisterDiagnostics_DDEF(1, 0, false; mock_trigger="btn-open-sys-audit"),
            diag_close   = Gui_Base.BASE_RegisterDiagnostics_DDEF(0, 1, true; mock_trigger="btn-close-diagnostics"),
            diag_idle    = Gui_Base.BASE_RegisterDiagnostics_DDEF(0, 0, false; mock_trigger="other"),
            diag_nil     = Gui_Base.BASE_RegisterDiagnostics_DDEF(0, 0, false; mock_trigger=nothing),
            rec_unlock   = Gui_Base.BASE_RegisterRecovery_DDEF(1, 0; mock_trigger="btn-diag-force-unlock"),
            rec_clear    = Gui_Base.BASE_RegisterRecovery_DDEF(0, 1; mock_trigger="btn-diag-clear-temp"),
            rec_idle     = Gui_Base.BASE_RegisterRecovery_DDEF(0, 0; mock_trigger="other"),
            rec_nil      = Gui_Base.BASE_RegisterRecovery_DDEF(0, 0; mock_trigger=nothing),
            overlay_poll = Gui_Base.BASE_HandleLoadingOverlay_DDEF(1),
            overlay_to   = Gui_Base.BASE_HandleLoadingOverlay_DDEF(20),
            sync_res     = Gui_Base.BASE_SyncVault_DDEF("deck_mock", "lens_mock", "analysis_mock"),
            sync_deck    = Gui_Base.BASE_SyncVault_DDEF("deck_mock", "lens_mock", "analysis_mock"; mock_trigger="sync-deck-content"),
            sync_lens    = Gui_Base.BASE_SyncVault_DDEF("deck_mock", "lens_mock", "analysis_mock"; mock_trigger="sync-lens-content"),
            sync_ana     = Gui_Base.BASE_SyncVault_DDEF("deck_mock", "lens_mock", "analysis_mock"; mock_trigger="sync-lens-analysis"),
            ctx_sync     = Dash.with_context(Dash._callback_context_storage, (triggered = [(prop_id = "sync-deck-content.value", value = nothing)],)) do
                Gui_Base.BASE_SyncVault_DDEF("deck_mock", "lens_mock", "analysis_mock")
            end,
            ctx_diag     = Dash.with_context(Dash._callback_context_storage, (triggered = [(prop_id = "btn-open-sys-audit.n_clicks", value = 1)],)) do
                Gui_Base.BASE_RegisterDiagnostics_DDEF(1, 0, false)
            end,
            ctx_rec      = Dash.with_context(Dash._callback_context_storage, (triggered = [(prop_id = "btn-diag-force-unlock.n_clicks", value = 1)],)) do
                Gui_Base.BASE_RegisterRecovery_DDEF(1, 0)
            end
            @track G7 routing_root isa Dash.Component && routing_deck isa Dash.Component &&
                      routing_lens isa Dash.Component && routing_any isa Dash.Component &&
                      diag_open[1] == true && diag_close[1] == false && !diag_idle[1] && !diag_nil[1] &&
                      rec_unlock[1] isa Int && rec_clear[1] == Dash.no_update() && rec_idle[1] == Dash.no_update() && rec_nil[1] == Dash.no_update() &&
                      overlay_poll[2] == true && overlay_to[2] == true &&
                      sync_res == Dash.no_update() &&
                      sync_deck == "deck_mock" && sync_lens == "lens_mock" && sync_ana == "analysis_mock" &&
                      ctx_sync == "deck_mock" && ctx_diag[1] == true && ctx_rec[1] isa Int
        end

        # 92: Single public entry point and launch call contract
        let has_launch = isdefined(DoECISORY, :launch),
            has_design = isdefined(DoECISORY, :design),
            entry_m = which(DoECISORY.launch, ()),
            app_inst = DoECISORY.launch(; open_browser=false, start_server=false),
            port_custom = DoECISORY.CALL_ResolvePort_DDEF(8099),
            port_default = DoECISORY.CALL_ResolvePort_DDEF(),
            port_env = withenv("PORT" => "8088") do
                DoECISORY.CALL_ResolvePort_DDEF()
            end,
            port_hf = withenv("SPACE_ID" => "cloudapp_demo", "PORT" => nothing) do
                DoECISORY.CALL_ResolvePort_DDEF()
            end,
            plan_bb = design(:bb15),
            plan_cd = design(:cd17),
            plan_tl = design(:tl09),
            plan_df = design(:df14; direction=[1, -1, 1]),
            plan_custom = design(:bb15;
                factors = ["FactorA", "FactorB", "FactorC"],
                levels  = [(10.0, 20.0, 30.0), (1.0, 2.0, 3.0), (0.1, 0.2, 0.3)],
                limits  = [(5.0, 35.0), (0.5, 3.5), (0.05, 0.35)]
            ),
            io_buf = IOBuffer(),
            _ = show(io_buf, plan_bb),
            show_str = String(take!(io_buf)),
            err_factors = try design(:bb15; factors=["A", "B"]); false catch e; (e isa ArgumentError) end,
            err_levels  = try design(:bb15; levels=[(1.0, 2.0)]); false catch e; (e isa ArgumentError) end,
            err_sublvl  = try design(:bb15; levels=[(1.0, 2.0), (1.0, 2.0), (1.0, 2.0)]); false catch e; (e isa ArgumentError) end,
            err_limits  = try design(:bb15; limits=[(1.0, 2.0)]); false catch e; (e isa ArgumentError) end
            @track G7 has_launch && has_design && entry_m !== nothing && app_inst isa Dash.DashApp &&
                      app_inst.layout isa Dash.Component && length(app_inst.callbacks) >= 40 &&
                      port_custom == 8099 && port_default == 8060 && port_env == 8088 && port_hf == 7860 &&
                      plan_bb isa DoECISORY.CALL_Design_DDES && plan_cd isa DoECISORY.CALL_Design_DDES &&
                      plan_tl isa DoECISORY.CALL_Design_DDES && plan_df isa DoECISORY.CALL_Design_DDES &&
                      plan_custom isa DoECISORY.CALL_Design_DDES &&
                      contains(show_str, "DoECISORY ExperimentDesign") && contains(show_str, "D-Efficiency") &&
                      err_factors && err_levels && err_sublvl && err_limits
        end

        # 93: Chemical formulation grid default row definition
        let row_deck = Gui_Deck.DECK_GetDefaultRow_DDEF(1),
            row_fixed = Gui_Deck.DECK_GetDefaultRow_DDEF(4),
            m_chem = Gui_Deck.DECK_BuildPropertyModal_DDEF(),
            m_stoch = Gui_Deck.DECK_BuildStoicModal_DDEF(),
            m_audit = Gui_Deck.DECK_BuildAuditModal_DDEF(),
            tbl_id = Gui_Deck.DECK_BuildIDTable_DDEF(1:3, [Gui_Deck.DECK_GetDefaultRow_DDEF(i) for i in 1:3], 3, true),
            tbl_lvl = Gui_Deck.DECK_BuildLevelTable_DDEF(1:3, [Gui_Deck.DECK_GetDefaultRow_DDEF(i) for i in 1:3], 3),
            tbl_lim = Gui_Deck.DECK_BuildLimitsTable_DDEF(1:3, [Gui_Deck.DECK_GetDefaultRow_DDEF(i) for i in 1:3], 3),
            out_row = Gui_Deck.DECK_BuildOutputRow_DDEF(1, "Yield", "%"),
            safe_z = Gui_Deck.DECK_SafeNumZero_DDEF(NaN) == 0.0 && Gui_Deck.DECK_SafeNumZero_DDEF(5.5) == 5.5,
            safe_k = Sys_Fast.FAST_SafeGet_DDEF(Dict("k" => 1), "k", 0) == 1 && Sys_Fast.FAST_SafeGet_DDEF(Dict(), "k", 42) == 42
            @track G7 row_deck["Role"] == "Variable" && row_fixed["Role"] == "Fixed" && haskey(row_deck, "MW") && haskey(row_deck, "Unit") &&
                      m_chem isa Dash.Component && m_stoch isa Dash.Component && m_audit isa Dash.Component &&
                      tbl_id isa Dash.Component && tbl_lvl isa Dash.Component && tbl_lim isa Dash.Component &&
                      out_row isa Dash.Component && safe_z && safe_k
        end

        # 94: Factor row import mapping and data normalisation
        let raw_in = [
                Dict("Name" => "FactorA", "Role" => "Variable", "L1" => 10, "L2" => 20, "L3" => 30, "Unit" => "mg"),
                Dict("Name" => "FactorB", "Role" => "Variable", "L1" => 1, "L2" => 2, "L3" => 3, "Unit" => "mM"),
                Dict("Name" => "FactorC", "Role" => "Variable", "L1" => 100, "L2" => 200, "L3" => 300, "Unit" => "%m"),
                Dict("Name" => "Buffer", "Role" => "Fixed", "L1" => 5, "Unit" => "g")
            ],
            mapped_rows = Gui_Deck.DECK_MapImportRow_DDEF(raw_in; override_roles=false),
            t_deck = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "TEMP_DECK_GEN.xlsx")
            Sys_Fast.FAST_CleanTransient_DDEF(t_deck)
            in_deck = [
                Dict("Name" => "ReactionTime", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "Unit" => "%M", "MW" => 100.0),
                Dict("Name" => "FactorB", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "Unit" => "%M", "MW" => 100.0),
                Dict("Name" => "FactorC", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "Unit" => "%M", "MW" => 100.0),
                Dict("Name" => "RadioA", "Role" => "Fixed", "L1" => 5.0, "L2" => 5.0, "L3" => 5.0, "Unit" => "mCi", "MW" => 0.0, "IsRadioactive" => true, "HalfLife" => 68.0, "HalfLifeUnit" => "Minutes")
            ]
            out_deck = [
                Dict("Name" => "Yield", "Unit" => "%"),
                Dict("Name" => "Purity", "Unit" => "%"),
                Dict("Name" => "Titer", "Unit" => "g/L")
            ]
            res_gen_df14 = Gui_Deck.DECK_GenProtocol_DDEF(t_deck, in_deck, out_deck, 10.0, 1.0, "DF14", Dict("FillerName" => "Water", "FillerMW" => 18.0), "ProjDeck"; direction=[1, -1, 1], target_phase="Phase1")
            df_deck_p1 = Sys_Fast.FAST_ReadExcel_DDEF(t_deck, Sys_Fast.FAST_Data_DDEC.SHEET_DATA)
            has_fill_water = "FILL_Water_%M" in names(df_deck_p1) && !any(ismissing, df_deck_p1[!, "FILL_Water_%M"])
            res_gen_phase2 = Gui_Deck.DECK_GenProtocol_DDEF(t_deck, in_deck, out_deck, 10.0, 1.0, "BB15", Dict(), "ProjDeck")
            in_time_rad = deepcopy(in_deck); in_time_rad[1]["Unit"] = "Minutes"; in_time_rad[1]["MW"] = 0.0
            res_time_rad = Gui_Deck.DECK_GenProtocol_DDEF(t_deck, in_time_rad, out_deck, 10.0, 1.0, "BB15", Dict(), "ProjDeck"; target_phase=nothing)
            res_gen_fail = Gui_Deck.DECK_GenProtocol_DDEF("", [], [], 0.0, 0.0, "BB15", Dict())
            res_gen_bad_vars = Gui_Deck.DECK_GenProtocol_DDEF(t_deck, in_deck[1:2], out_deck, 10.0, 1.0, "BB15", Dict())
            res_gen_bad_outs = Gui_Deck.DECK_GenProtocol_DDEF(t_deck, in_deck, out_deck[1:2], 10.0, 1.0, "BB15", Dict())
            in_bad_lvl = deepcopy(in_deck); in_bad_lvl[1]["L1"] = 50.0; in_bad_lvl[1]["L2"] = 20.0
            res_gen_bad_lvl = Gui_Deck.DECK_GenProtocol_DDEF(t_deck, in_bad_lvl, out_deck, 10.0, 1.0, "BB15", Dict())
            in_bad_u = deepcopy(in_deck); in_bad_u[1]["Unit"] = "bad_unit"
            res_bad_u = Gui_Deck.DECK_GenProtocol_DDEF(t_deck, in_bad_u, out_deck, 10.0, 1.0, "BB15", Dict())
            in_dup_v = deepcopy(in_deck); in_dup_v[2]["Name"] = in_dup_v[1]["Name"]
            res_dup_v = Gui_Deck.DECK_GenProtocol_DDEF(t_deck, in_dup_v, out_deck, 10.0, 1.0, "BB15", Dict())
            out_dup_r = deepcopy(out_deck); out_dup_r[2]["Name"] = out_dup_r[1]["Name"]
            res_dup_r = Gui_Deck.DECK_GenProtocol_DDEF(t_deck, in_deck, out_dup_r, 10.0, 1.0, "BB15", Dict())
            in_over_bg = deepcopy(in_deck); in_over_bg[1]["L3"] = 80.0; in_over_bg[2]["L3"] = 80.0
            res_over_bg = Gui_Deck.DECK_GenProtocol_DDEF(t_deck, in_over_bg, out_deck, 10.0, 1.0, "BB15", Dict())
            res_gen_phase1_again = Gui_Deck.DECK_GenProtocol_DDEF(t_deck, in_deck, out_deck, 10.0, 1.0, "BB15", Dict(), "ProjDeck"; target_phase="Phase1")
            Sys_Fast.FAST_CleanTransient_DDEF(t_deck)
            @track G7 length(mapped_rows) == 4 && mapped_rows[1]["Role"] == "Variable" && mapped_rows[4]["Role"] == "Fixed" &&
                      res_gen_df14[1] && has_fill_water && res_gen_phase2[1] && res_gen_phase1_again[1] && !res_gen_fail[1] &&
                      !res_gen_bad_vars[1] && !res_gen_bad_outs[1] && !res_gen_bad_lvl[1] &&
                      !res_bad_u[1] && !res_dup_v[1] && !res_dup_r[1] && res_time_rad[1] && !res_over_bg[1]
        end

        # 95: Transition slot card layout and extraction audit
        let slot_card1 = Gui_Lens.LENS_BuildSlotCard_DDEF(1),
            slot_card2 = Gui_Lens.LENS_BuildSlotCard_DDEF(2),
            slot_card3 = Gui_Lens.LENS_BuildSlotCard_DDEF(3),
            slot_conf = Dict("Slots" => [
                Dict("Mode" => "SCALE", "Alpha" => 1.2, "Beta" => 0.5, "NewName" => "Temp_Scaled"),
                Dict("Mode" => "REPLACE", "NewName" => "Catalyst", "NewL1" => 1.0, "NewL2" => 2.0, "NewL3" => 3.0),
                Dict("Mode" => "KEEP")
            ]),
            extracted_slots = Gui_Lens.LENS_ExtractSlots_DDEF(slot_conf)
            @track G7 slot_card1 isa Dash.Component && slot_card2 isa Dash.Component &&
                      slot_card3 isa Dash.Component && length(extracted_slots) == 3
        end

        # 96: Slot configuration modification and level update
        let mock_conf = [
                Dict{String,Any}("Name" => "Temp", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [20.0, 50.0, 80.0]),
                Dict{String,Any}("Name" => "Time", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [10.0, 20.0, 30.0]),
                Dict{String,Any}("Name" => "Dose", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [1.0, 2.0, 3.0])
            ],
            slots_ext = Gui_Lens.LENS_ExtractSlots_DDEF(Dict("Slots" => [
                Dict("Mode" => "REPLACE", "NewName" => "Catalyst", "NewL1" => 1.0, "NewL2" => 2.0, "NewL3" => 3.0),
                Dict("Mode" => "SCALE", "Alpha" => 1.2, "Beta" => 0.5, "NewName" => "Time_Scaled"),
                Dict("Mode" => "KEEP")
            ])),
            _ = Gui_Lens.LENS_ApplySlotCustomisation_DDEF!(mock_conf, slots_ext, [50.0, 20.0, 2.0])
            @track G7 mock_conf[1]["Name"] == "Catalyst" && mock_conf[1]["Levels"] == [1.0, 2.0, 3.0] &&
                      mock_conf[2]["Name"] == "Time_Scaled" && mock_conf[3]["Name"] == "Dose"
        end

        # 97: Leaderboard Dash HTML component table generation
        let mock_ldf = DataFrame(
                Sys_Fast.FAST_Data_DDEC.COL_EXP_ID => ["EXP_01", "EXP_02"],
                Sys_Fast.FAST_Data_DDEC.PRE_VAR * "Temp" => [50.0, 48.0],
                Sys_Fast.FAST_Data_DDEC.PRE_PRED * "Yield" => [92.0, 89.5],
                Sys_Fast.FAST_Data_DDEC.COL_SCORE => [0.95, 0.91]
            ),
            mock_res_html = Dict("InNames" => ["Temp"], "OutNames" => ["Yield"]),
            leaders_html = Gui_Lens.LENS_BuildLeadersTable_DDEF(mock_ldf, mock_res_html),
            df_lead_test = DataFrame(
                "EXP_ID" => ["EXP_01", "EXP_02"],
                "SCORE" => [0.95, 0.88],
                "Varia_Temp" => [50.0, 60.0],
                "Pred_Yield" => [92.0, 85.0]
            ),
            lens_table = Gui_Lens.LENS_BuildLeadersTable_DDEF(df_lead_test, Dict("DisplayOutNames" => ["Yield (%)"])),
            empty_html = Gui_Lens.LENS_BuildLeadersTable_DDEF(DataFrame(), Dict()),
            safe_flt = Gui_Lens.LENS_SafeFloat_DDEF(42.5),
            safe_flt_nil = Gui_Lens.LENS_SafeFloat_DDEF(nothing),
            safe_flt_nan = Gui_Lens.LENS_SafeFloat_DDEF(NaN),
            safe_flt_mis = Gui_Lens.LENS_SafeFloat_DDEF(missing),
            safe_flt_str = Gui_Lens.LENS_SafeFloat_DDEF("text"),
            c_deff_hi  = Gui_Lens.LENS_EvalBadgeClass_DDEF(:d_eff, 0.45),
            c_deff_lo  = Gui_Lens.LENS_EvalBadgeClass_DDEF(:d_eff, 0.15),
            c_deff_nil = Gui_Lens.LENS_EvalBadgeClass_DDEF(:d_eff, nothing),
            c_vif_ok   = Gui_Lens.LENS_EvalBadgeClass_DDEF(:vif, 2.5),
            c_vif_med  = Gui_Lens.LENS_EvalBadgeClass_DDEF(:vif, 7.5),
            c_vif_bad  = Gui_Lens.LENS_EvalBadgeClass_DDEF(:vif, 12.0),
            c_lof_ok   = Gui_Lens.LENS_EvalBadgeClass_DDEF(:lof, 0.20),
            c_lof_bad  = Gui_Lens.LENS_EvalBadgeClass_DDEF(:lof, 0.01),
            c_q2_hi    = Gui_Lens.LENS_EvalBadgeClass_DDEF(:q2, 0.75),
            c_q2_neg   = Gui_Lens.LENS_EvalBadgeClass_DDEF(:q2, -0.30),
            c_pval_sig = Gui_Lens.LENS_EvalBadgeClass_DDEF(:pval, 0.01),
            c_pval_ins = Gui_Lens.LENS_EvalBadgeClass_DDEF(:pval, 0.15),
            c_cpval    = Gui_Lens.LENS_EvalBadgeClass_DDEF(:coef_pval, 0.02),
            c_cvif     = Gui_Lens.LENS_EvalBadgeClass_DDEF(:coef_vif, 2, 8.0),
            c_sens     = Gui_Lens.LENS_EvalBadgeClass_DDEF(:sensitivity, 0.85),
            c_anova_m  = Gui_Lens.LENS_EvalBadgeClass_DDEF(:anova, "Model", 0.001),
            c_anova_l  = Gui_Lens.LENS_EvalBadgeClass_DDEF(:anova, "Lack of Fit", 0.001),
            c_anova_ok = Gui_Lens.LENS_EvalBadgeClass_DDEF(:anova, "Lack of Fit", 0.15),
            fmt_deff   = Gui_Lens.LENS_FormatMetric_DDEF(:d_eff, 0.725),
            fmt_eff    = Gui_Lens.LENS_FormatMetric_DDEF(:eff, 0.854),
            fmt_vif    = Gui_Lens.LENS_FormatMetric_DDEF(:vif, 1.25),
            fmt_lof    = Gui_Lens.LENS_FormatMetric_DDEF(:lof, 0.045),
            fmt_lof_na = Gui_Lens.LENS_FormatMetric_DDEF(:lof, nothing),
            ext_nil    = Gui_Lens.LENS_ExtractSlots_DDEF(nothing),
            ext_nov    = Gui_Lens.LENS_ExtractSlots_DDEF(Dict("Slots" => nothing)),
            rep_in     = "<span class=\"report-pos\">+5.2</span> <span class=\"report-neg\">-1.4</span> <span>normal</span>",
            parsed_inl = Gui_Lens.LENS_ParseInlineContent_DDEF(rep_in; is_cell=true),
            md_tbl_txt = "| Metric | Value |\n|:---:|---:|\n| D-Eff | 0.85 |\n| VIF | 1.2 |",
            realigned_tbl = Gui_Lens.LENS_RealignMarkdownTables_DDEF(md_tbl_txt),
            acad_rep   = "# Academic Report\n### Subheader 3\n#### Subheader 4\n---\n*Important notice paragraph*\n- First finding bullet\n| Metric | Center | Right |\n|---|:---:|---:|\n| **Model** | `OLS` | Pass |\n\nConclusion text with <ins>positive</ins> note.",
            rend_rep   = Gui_Lens.LENS_RenderAcademicReport_DDEF(acad_rep),
            c_anova_oth = Gui_Lens.LENS_EvalBadgeClass_DDEF(:anova, "OtherSource", 0.01),
            realign_extra = Gui_Lens.LENS_RealignMarkdownTables_DDEF("| Col |\n|---|\n| cell |\nPlain text line"),
            realign_sparse = Gui_Lens.LENS_RealignMarkdownTables_DDEF("| H1 | H2 | H3 |\n| --- |\n| cell1 |\n| SingleLine |"),
            act_det1   = Gui_Lens.LENS_DetectAbsoluteActivity_DDEF([Dict("Name" => "Act", "Unit" => "MBq")]),
            act_det2   = Gui_Lens.LENS_DetectAbsoluteActivity_DDEF([Dict("Name" => "EOS Activity", "Unit" => "mCi")]),
            act_det_eos = Gui_Lens.LENS_DetectAbsoluteActivity_DDEF([Dict("Name" => "EOS Activity", "Unit" => "")]),
            act_det3   = Gui_Lens.LENS_DetectAbsoluteActivity_DDEF([Dict("Name" => "Purity", "Unit" => "%")]),
            act_det4   = Gui_Lens.LENS_DetectAbsoluteActivity_DDEF([Dict("Name" => "Iso", "IsRadioactive" => true)]),
            tbl_fallback = Gui_Lens.LENS_BuildLeadersTable_DDEF(DataFrame(Sys_Fast.FAST_Data_DDEC.PRE_VAR * "UnknownVar" => [1.0], Sys_Fast.FAST_Data_DDEC.PRE_PRED * "UnknownPred" => [2.0], "SCORE" => [0.9]), Dict()),
            meta_lead    = Gui_Lens.LENS_GetGraphMeta_DDEF(Dict("type" => "OptimalZone", "out_idx" => 1, "sub_idx" => 2)),
            meta_empty   = Gui_Lens.LENS_GetGraphMeta_DDEF(Dict())
            @track G7 leaders_html isa Dash.Component && isempty(empty_html) &&
                      (lens_table isa DashBootstrapComponents.Component || lens_table isa Dash.Component || isdefined(lens_table, :children)) &&
                      tbl_fallback isa Dash.Component &&
                      meta_lead == ("OptimalZone", 1, 2) && meta_empty == ("", 0, 0) &&
                      safe_flt == 42.5 && isnothing(safe_flt_nil) && isnothing(safe_flt_nan) && isnothing(safe_flt_mis) && isnothing(safe_flt_str) &&
                      occursin("c4tg", c_deff_hi) && occursin("c0hr", c_deff_lo) && occursin("v5pb", c_deff_nil) &&
                      occursin("c4tg", c_vif_ok) && occursin("c5hy", c_vif_med) && occursin("c0hr", c_vif_bad) &&
                      occursin("c4tg", c_lof_ok) && occursin("c0hr", c_lof_bad) &&
                      occursin("c4tg", c_q2_hi) && occursin("c0hr", c_q2_neg) &&
                      occursin("c4tg", c_pval_sig) && occursin("c0hr", c_pval_ins) &&
                      occursin("c4tg", c_cpval) && occursin("c0hr", c_cvif) && occursin("v5pb", c_sens) &&
                      occursin("c4tg", c_anova_m) && occursin("c0hr", c_anova_l) && occursin("c4tg", c_anova_ok) &&
                      c_anova_oth == "fw-bold" &&
                      fmt_deff == "0.725" && fmt_eff == "0.85" && fmt_vif == "1.25" && fmt_lof == "0.045" && fmt_lof_na == "N/A" &&
                      isempty(ext_nil) && isempty(ext_nov) && length(parsed_inl) >= 3 &&
                      occursin("0.85", realigned_tbl) && !isempty(realign_extra) && !isempty(realign_sparse) && rend_rep isa Dash.Component &&
                      act_det1 == "Act" && act_det2 == "EOS Activity" && act_det_eos == "EOS Activity" && isempty(act_det3) && act_det4 == "Iso"
        end

        # 98: State payload sanitisation and base64 roundtrip
        let clean_bundle = Sys_Fast.FAST_SanitiseJSON_DDEF(Dict(
                "Status" => "OK", "Scores" => [0.91, 0.85],
                "Vitals" => Dict("D" => 0.42, "A" => 0.85, "Condition" => 41.2),
                "Matrix" => [1.0 NaN 2.0; 3.0 4.0 NaN],
                "Tuple" => (1.0, NaN, "text"),
                "NamedTuple" => (a = 1.0, b = NaN),
                "Pair" => "k" => NaN
            )),
            json_str = JSON3.write(clean_bundle),
            read_back = JSON3.read(json_str, Dict{String, Any}),
            cfg_lens = Dict{String, Any}(
                "Type"      => "DoECISORY_Lens_Config",
                "Version"   => "0.1.0",
                "Timestamp" => string(Dates.now()),
                "Project"   => "ValidationProject",
                "Phase"     => "Phase1",
                "Model"     => "Quadratic",
                "Goals"     => [
                    Dict("Index" => 1, "Name" => "Purity", "Min" => 90.0, "Target" => 98.0, "Max" => 100.0, "Type" => "Maximise", "Weight" => "1.00")
                ],
                "Radioactivity" => Dict("ForwMode" => "OFF", "DcypMode" => "OFF", "ReveMode" => "OFF")
            ),
            lens_json = JSON3.write(cfg_lens),
            lens_b64 = Base64.base64encode(lens_json),
            lens_parsed = JSON3.read(String(Base64.base64decode(lens_b64)), Dict{String, Any})
            @track G7 read_back["Status"] == "OK" && read_back["Scores"][1] == 0.91 && read_back["Vitals"]["Condition"] == 41.2 &&
                      lens_parsed["Type"] == "DoECISORY_Lens_Config" && lens_parsed["Project"] == "ValidationProject"
        end

        # 99: Clientside Plotly figure JSON schema serialization
        let p_pareto = Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotPareto_DDES(), model_g7, "Yield", 0.9, 0.8),
            plot_json = JSON3.write(Dict("data" => p_pareto.data, "layout" => p_pareto.layout)),
            parsed_plot = JSON3.read(plot_json, Dict{String, Any})
            @track G7 haskey(parsed_plot, "data") && haskey(parsed_plot, "layout") && length(parsed_plot["data"]) >= 1
        end

        # 100: End-to-end multi-phase workflow integration audit
        let e2e_plan = design(:bb15;
                factors = ["Temperature", "Time", "Precursor"],
                levels  = [(60.0, 90.0, 120.0), (5.0, 15.0, 25.0), (15.0, 25.0, 35.0)]
            ),
            e2e_X = e2e_plan.matrix,
            e2e_temp = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_E2E_MASTER.xlsx")
            Sys_Fast.FAST_CleanTransient_DDEF(e2e_temp)
            
            # 1. Blank protocol generation & benchtop observation recording
            e2e_df = DataFrame(
                "EXP_ID"            => ["EXP_P1_$(lpad(i, 2, '0'))" for i in 1:15],
                "PHASE"             => fill("Phase1", 15),
                "VARIA_Temperature" => e2e_X[:, 1],
                "VARIA_Time"        => e2e_X[:, 2],
                "VARIA_Precursor"   => e2e_X[:, 3],
                "RESULT_Conversion" => fill(NaN, 15),
                "RESULT_Yield"      => fill(NaN, 15),
                "RESULT_Impurity"   => fill(NaN, 15)
            )
            Sys_Fast.FAST_WriteExcel_DDEF(e2e_temp, Dict("DATA" => e2e_df))
            
            # 2. Populate laboratory responses & roundtrip verification
            e2e_Y_conv  = [87.4, 53.1, 73.6, 77.2, 94.5, 87.0, 65.3, 82.7, 75.5, 92.1, 87.7, 59.9, 80.4, 70.2, 90.6]
            e2e_Y_yield = [77.6, 45.2, 66.1, 69.9, 72.4, 77.1, 57.4, 73.8, 67.5, 74.2, 77.9, 51.1, 70.3, 63.4, 73.8]
            e2e_Y_impur = [2.5,  8.2,  4.8,  6.4,  5.2,  2.2,  6.9,  4.1,  5.6,  3.3,  2.7,  7.6,  5.4,  6.2,  3.9]
            e2e_df[!, "RESULT_Conversion"] = e2e_Y_conv
            e2e_df[!, "RESULT_Yield"]      = e2e_Y_yield
            e2e_df[!, "RESULT_Impurity"]   = e2e_Y_impur
            Sys_Fast.FAST_WriteExcel_DDEF(e2e_temp, Dict("DATA" => e2e_df))
            e2e_read = Sys_Fast.FAST_ReadExcel_DDEF(e2e_temp, "DATA")
            
            # 3. Multi-response quadratic model fitting
            e2e_models = [
                Lib_Vise.VISE_Regress_DDEF(e2e_X, Float64.(e2e_read[!, "RESULT_Conversion"]), "quadratic"; InNames=e2e_plan.factors),
                Lib_Vise.VISE_Regress_DDEF(e2e_X, Float64.(e2e_read[!, "RESULT_Yield"]),      "quadratic"; InNames=e2e_plan.factors),
                Lib_Vise.VISE_Regress_DDEF(e2e_X, Float64.(e2e_read[!, "RESULT_Impurity"]),   "quadratic"; InNames=e2e_plan.factors)
            ]
            
            # 4. Multi-objective desirability optimisation with 18F DCYP
            e2e_goals = [
                Dict{String, Any}("Type" => "Maximise", "Min" => 50.0, "Max" => 98.0, "Target" => 92.0, "Weight" => 1.0),
                Dict{String, Any}("Type" => "Maximise", "Min" => 40.0, "Max" => 85.0, "Target" => 80.0, "Weight" => 1.2),
                Dict{String, Any}("Type" => "Minimise", "Min" => 1.0,  "Max" => 10.0, "Target" => 2.0,  "Weight" => 1.5)
            ]
            e2e_decay  = [Lib_Core.CORE_ModifierDCYP_DDES(2, log(2.0) / 109.8, "18F")]
            e2e_bounds = hcat(minimum(e2e_X; dims=1)', maximum(e2e_X; dims=1)')
            
            (e2e_best_x, e2e_best_s) = Lib_Core.CORE_OptimiseDesirability_DDEF(e2e_models, e2e_goals, e2e_bounds; MaxTime=0.4, ModifiersDCYP=e2e_decay)
            e2e_preds = [Lib_Vise.VISE_Predict_DDEF(m, reshape(e2e_best_x, 1, 3))[1] for m in e2e_models]
            
            # 5. Sensitivity analysis & sequential inter-phase migration (ACTA/ASTM)
            e2e_sens       = Lib_Vise.VISE_AnalyseSensitivity_DDEF(e2e_models[1], e2e_best_x, e2e_X)
            e2e_next_range = Sys_Flow.FLOW_CalcACTA_DDEF(e2e_best_x[1], [60.0, 90.0, 120.0], 0.5, 0.0, 0.0)
            e2e_astm       = [Sys_Flow.FLOW_ApplyASTM_DDEF(x, 0.9, 9.0) for x in e2e_next_range]
            
            Sys_Fast.FAST_CleanTransient_DDEF(e2e_temp)
            _ = Sys_Fast.FAST_CleanWorkforce_DDEF(true)

            @track G7 (e2e_plan isa DoECISORY.CALL_Design_DDES && haskey(e2e_plan.metrics, "D") &&
                      all(m -> m["R2"] > 0.95 && m["RMSE"] >= 0.0, e2e_models) &&
                      e2e_best_s > 0.8 && length(e2e_preds) == 3 &&
                      e2e_preds[1] > 85.0 && e2e_preds[2] > 70.0 && e2e_preds[3] < 4.0 &&
                      isapprox(sum(e2e_sens), 1.0; atol=1e-5) && length(e2e_best_x) == 3 &&
                      length(e2e_next_range) == 3 && length(e2e_astm) == 3 && !isfile(e2e_temp))
        end
    end
    TRACKER["G7"].duration = round(time() - t_g7; digits=2)

    Sys_Fast.FAST_ActiveGroup_DDEC[] = ""
    println()
end

const SUITE_DURATION = round(time() - SUITE_START_TIME; digits=2)

let
    total_runs   = sum(t.total for t in values(TRACKER))
    total_passed = sum(t.passed for t in values(TRACKER))
    total_failed = sum(t.failed for t in values(TRACKER))
    pct_overall  = total_runs > 0 ? round((total_passed / total_runs) * 100.0; digits=1) : 0.0

    group_keys = ["G1", "G2", "G3", "G4", "G5", "G6", "G7"]

    println("\n" * "="^90)
    println(" "^31 * "DoECISORY TEST SUITE REPORT" * " "^32)
    println("="^90)
    @printf("  %-56s %5s  %6s  %6s  %8s\n", "Domain Group", "Total", "Passed", "Failed", "Time")
    println("-"^90)

    for k in group_keys
        t = TRACKER[k]
        t_sec = t.duration
        t_str = t_sec >= 60.0 ? @sprintf("%dm%04.1fs", floor(Int, t_sec / 60), mod(t_sec, 60)) : @sprintf("%.1fs", t_sec)
        @printf("  %-56s %5d  %6d  %6d  %8s\n", t.name, t.total, t.passed, t.failed, t_str)
    end

    println("-"^90)
    
    bar_width = 46
    filled = total_runs > 0 ? clamp(round(Int, (total_passed / total_runs) * bar_width), 0, bar_width) : 0
    empty_slots = bar_width - filled
    bar_str = "="^filled * " "^empty_slots

    @printf("  PROGRESS    : [%s] %5.1f%%\n", bar_str, pct_overall)
    @printf("  SUMMARY     : %d / %d passed (%d failed, 0 errored)\n", total_passed, total_runs, total_failed)
    @printf("  DURATION    : %.1f seconds\n", SUITE_DURATION)
    @printf("  FINAL STATUS: %s\n", total_failed == 0 && total_runs == length(TEST_TITLES) ? "PASSED" : "FAILED")
    println("="^90)
end
