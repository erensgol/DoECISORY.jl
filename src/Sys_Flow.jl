module Sys_Flow

# ==============================================================================
# DOECISORY - SYSTEM FLOW (PROCESS & STATE)
# ==============================================================================
# Description: Experimental phase management, transition logic, and state 
#              synchronisation bus.
# Framework:   Inter-Phase Knowledge Transfer (IPKT = ACTA + ASTM)
#              - ACTA: Adaptive Contraction & Translation Algorithm (intra-space)
#              - ASTM: Affine Space Transformation Model (cross-system)
# Module Tag:  FLOW
# ==============================================================================

using JSON3
using Base64
using DataFrames
using PlotlyJS
using Printf
using ..Sys_Fast
using ..Lib_Core
using ..Lib_Mole

export FLOW_BuildIPKT_DDEF, FLOW_CommitIPKT_DDEF, FLOW_GetCandidates_DDEF,
    FLOW_WriteLeaders_DDEF, FLOW_CalcACTA_DDEF, FLOW_ApplyACTA_DDEF, FLOW_ApplyASTM_DDEF,
    FLOW_ValidateASTM_DDEF, FLOW_AuditLeader_DDEF, FLOW_RenderIPKT_DDEF,
    FLOW_AdvancePhase_DDEF, FLOW_GetPhaseType_DDEF, FLOW_ClassifyBoundaryMode_DDEF,
    FLOW_CheckBoundaryAlert_DDEF, FLOW_GetActionTag_DDEF, FLOW_ExecuteACTA_DDEF,
    FLOW_ContractRange_DDEF, FLOW_SeekCeiling_DDEF, FLOW_SeekFloor_DDEF, FLOW_ShiftWindow_DDEF,
    FLOW_AbstractBoundaryMode_DDET, FLOW_ModeContract_DDES, FLOW_ModeTranslateUpper_DDES,
    FLOW_ModeTranslateLower_DDES, FLOW_ModeSeekUpper_DDES, FLOW_ModeSeekLower_DDES,
    FLOW_ModeReplaced_DDES, FLOW_ResolvePhysicalBounds_DDEF, FLOW_ApplySlotCustomisation_DDEF!,
    FLOW_CustomisePhaseSpace_DDEF, FLOW_ImportWorkspaceState_DDEF, FLOW_SyncPhaseGoals_DDEF,
    FLOW_AppendResponseColumns_DDEF!, FLOW_AppendRadioColumns_DDEF!, FLOW_RoundLevelTriplet_DDEF

# ==============================================================================
# PART A: TYPE DEFINITIONS & CONSTANTS & TRANSITION
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: TRAIT HIERARCHY & BOUNDARY CONSTANTS & DISPATCH HELPERS
# ------------------------------------------------------------------------------

const C = FAST_Data_DDEC

"""
    FLOW_AbstractBoundaryMode_DDET
Trait hierarchy for classifying leader proximity and window adaptation modes.
"""
abstract type FLOW_AbstractBoundaryMode_DDET end
struct FLOW_ModeContract_DDES       <: FLOW_AbstractBoundaryMode_DDET end
struct FLOW_ModeTranslateUpper_DDES <: FLOW_AbstractBoundaryMode_DDET end
struct FLOW_ModeTranslateLower_DDES <: FLOW_AbstractBoundaryMode_DDET end
struct FLOW_ModeSeekUpper_DDES      <: FLOW_AbstractBoundaryMode_DDET end
struct FLOW_ModeSeekLower_DDES      <: FLOW_AbstractBoundaryMode_DDET end
struct FLOW_ModeReplaced_DDES       <: FLOW_AbstractBoundaryMode_DDET end

"""
    FLOW_CheckBoundaryAlert_DDEF(Status) -> Tuple{Bool, String}
Translate a boundary mode trait into its safety flag and user alert.
"""
FLOW_CheckBoundaryAlert_DDEF(::FLOW_ModeContract_DDES)       = (true,  "Optimal candidate point near centre. Search range contracted for finer precision scan.")
FLOW_CheckBoundaryAlert_DDEF(::FLOW_ModeTranslateLower_DDES) = (false, "Optimal candidate point approaching lower boundary. Adaptive translation engaged: search window shifted outward.")
FLOW_CheckBoundaryAlert_DDEF(::FLOW_ModeTranslateUpper_DDES) = (false, "Optimal candidate point approaching upper boundary. Adaptive translation engaged: search window shifted outward.")
FLOW_CheckBoundaryAlert_DDEF(::FLOW_ModeSeekLower_DDES)      = (false, "Optimal candidate point at lower limit. Boundary seeking engaged: minimum span locked at 10% of domain range.")
FLOW_CheckBoundaryAlert_DDEF(::FLOW_ModeSeekUpper_DDES)      = (false, "Optimal candidate point at upper limit. Boundary seeking engaged: minimum span locked at 10% of domain range.")
FLOW_CheckBoundaryAlert_DDEF(::FLOW_ModeReplaced_DDES)       = (true,  "")
FLOW_CheckBoundaryAlert_DDEF(::FLOW_AbstractBoundaryMode_DDET) = (true, "Candidate within operational range.")

"""
    FLOW_GetActionTag_DDEF(Status) -> String
Resolve the automatic telemetry action tag for a boundary mode.
"""
FLOW_GetActionTag_DDEF(::FLOW_ModeContract_DDES)         = "CONTRACTION"
FLOW_GetActionTag_DDEF(::FLOW_ModeTranslateUpper_DDES)   = "TRANS_UPPER"
FLOW_GetActionTag_DDEF(::FLOW_ModeTranslateLower_DDES)   = "TRANS_LOWER"
FLOW_GetActionTag_DDEF(::FLOW_ModeSeekUpper_DDES)        = "SEEK_UPPER"
FLOW_GetActionTag_DDEF(::FLOW_ModeSeekLower_DDES)        = "SEEK_LOWER"
FLOW_GetActionTag_DDEF(::FLOW_ModeReplaced_DDES)         = "REPLACED"
FLOW_GetActionTag_DDEF(::FLOW_AbstractBoundaryMode_DDET) = "CONTRACTION"

"""
    FLOW_ContractRange_DDEF(Status, Rng, Contraction) -> Float64
Contract the factor span when the leader is safe; preserve or bound it at limits.
"""
FLOW_ContractRange_DDEF(::FLOW_ModeContract_DDES,          Rng::Real, Contraction::Real) = Float64(Rng * Contraction)
FLOW_ContractRange_DDEF(::FLOW_ModeTranslateUpper_DDES,   Rng::Real, Contraction::Real) = Float64(Rng * Contraction)
FLOW_ContractRange_DDEF(::FLOW_ModeTranslateLower_DDES,   Rng::Real, Contraction::Real) = Float64(Rng * Contraction)
FLOW_ContractRange_DDEF(::FLOW_ModeSeekUpper_DDES,        Rng::Real, Contraction::Real) = min(Float64(Rng * Contraction), 0.10 * Float64(Rng))
FLOW_ContractRange_DDEF(::FLOW_ModeSeekLower_DDES,        Rng::Real, Contraction::Real) = min(Float64(Rng * Contraction), 0.10 * Float64(Rng))
FLOW_ContractRange_DDEF(::FLOW_ModeReplaced_DDES,         Rng::Real, Contraction::Real) = Float64(Rng)
FLOW_ContractRange_DDEF(::FLOW_AbstractBoundaryMode_DDET, Rng::Real, Contraction::Real) = Float64(Rng * Contraction)

"""
    FLOW_AbstractPhase_DDET
Trait hierarchy for experimental progression phases.
"""
abstract type FLOW_AbstractPhase_DDET end
struct FLOW_PhasePrimary_DDES <: FLOW_AbstractPhase_DDET end
struct FLOW_PhaseSecondary_DDES <: FLOW_AbstractPhase_DDET end
struct FLOW_PhaseTertiary_DDES <: FLOW_AbstractPhase_DDET end
struct FLOW_PhaseCustom_DDES <: FLOW_AbstractPhase_DDET
    PhaseName::String
end

"""
    FLOW_GetPhaseType_DDEF(Phase) -> FLOW_AbstractPhase_DDET
Resolve string phase representation into a typed phase trait.
"""
function FLOW_GetPhaseType_DDEF(p::AbstractString)::FLOW_AbstractPhase_DDET
    clean_p = uppercase(replace(strip(p), " " => ""))
    clean_p == "PHASE1" && return FLOW_PhasePrimary_DDES()
    clean_p == "PHASE2" && return FLOW_PhaseSecondary_DDES()
    clean_p == "PHASE3" && return FLOW_PhaseTertiary_DDES()
    return FLOW_PhaseCustom_DDES(string(p))
end

FLOW_GetPhaseType_DDEF(p::FLOW_AbstractPhase_DDET) = p

"""
    FLOW_AdvancePhase_DDEF(Phase) -> String
Dispatch-driven calculation of the subsequent target phase identifier.
"""
FLOW_AdvancePhase_DDEF(::FLOW_PhasePrimary_DDES)::String = "Phase2"
FLOW_AdvancePhase_DDEF(::FLOW_PhaseSecondary_DDES)::String = "Phase3"
FLOW_AdvancePhase_DDEF(::FLOW_PhaseTertiary_DDES)::String = "Phase4"
function FLOW_AdvancePhase_DDEF(p::FLOW_PhaseCustom_DDES)::String
    digits_only = replace(p.PhaseName, r"[^\d]" => "")
    p_num = tryparse(Int, digits_only)
    return "Phase$(isnothing(p_num) ? 2 : p_num + 1)"
end
FLOW_AdvancePhase_DDEF(p::AbstractString)::String = FLOW_AdvancePhase_DDEF(FLOW_GetPhaseType_DDEF(p))

"""
    FLOW_ResolveSource_DDEF(source) -> String
Resolve master workbook path from physical file path, transient DataHandle, or Store dict.
"""
function FLOW_ResolveSource_DDEF(f::AbstractString)::String
    isempty(strip(f)) && return ""
    isfile(f) && return f
    resolved = FAST_GetTransientPath_DDEF(f)
    return isfile(resolved) ? resolved : ""
end

function FLOW_ResolveSource_DDEF(store::AbstractDict)::String
    resolved = FAST_GetTransientPath_DDEF(store)
    return isfile(resolved) ? resolved : ""
end

FLOW_ResolveSource_DDEF(::Nothing)::String = ""
FLOW_ResolveSource_DDEF(::Any)::String     = ""

"""
    FLOW_IsValidFile_DDEF(Path) -> Bool
True if the path is or resolves to a valid existing master workbook file.
"""
FLOW_IsValidFile_DDEF(::Nothing)            = false
FLOW_IsValidFile_DDEF(Path::AbstractString) = !isempty(strip(Path)) && (isfile(Path) || !isempty(FLOW_ResolveSource_DDEF(Path)))
FLOW_IsValidFile_DDEF(store::AbstractDict)  = !isempty(FLOW_ResolveSource_DDEF(store))
FLOW_IsValidFile_DDEF(::Any)                = false

"""
    FLOW_IsFilled_DDEF(Str) -> Bool
True if the argument is a non-empty string.
"""
FLOW_IsFilled_DDEF(::Nothing)           = false
FLOW_IsFilled_DDEF(Str::AbstractString) = !isempty(Str)

"""
    FLOW_FormatStringDict_DDEF(Src) -> Dict{String, Any}
Normalize dictionary keys to String and sanitize values for JSON/Dash Store transit via FAST_SanitiseJSON_DDEF.
"""
FLOW_FormatStringDict_DDEF(Src::AbstractDict)::Dict{String,Any} = Dict{String,Any}(FAST_SanitiseJSON_DDEF(Src))
FLOW_FormatStringDict_DDEF(::Any)::Dict{String,Any}             = Dict{String,Any}()

"""
    FLOW_IterateEntries_DDEF(Src) -> iterable
Iterate entries of a keyed or sequential JSON container uniformly.
"""
FLOW_IterateEntries_DDEF(Src::AbstractDict)   = values(Src)
FLOW_IterateEntries_DDEF(Src::AbstractVector) = Src

"""
    FLOW_IsTruthy_DDEF(Flag) -> Bool
Interpret heterogeneous boolean flags from JSON or Excel sources.
"""
FLOW_IsTruthy_DDEF(Flag::Bool)           = Flag
FLOW_IsTruthy_DDEF(Flag::Real)           = Flag == 1
FLOW_IsTruthy_DDEF(Flag::AbstractString) = lowercase(strip(Flag)) == "true"
FLOW_IsTruthy_DDEF(::Any)                = false

"""
    FLOW_CopyEntry_DDEF(Val) -> Any
Detach vector values from their source; pass scalars through.
"""
FLOW_CopyEntry_DDEF(Val::AbstractVector) = copy(Val)
FLOW_CopyEntry_DDEF(Val::Any)            = Val

"""
    FLOW_ResolveConfig_DDEF(Custom, Fallback) -> Vector{Dict{String, Any}}
Select a user-supplied configuration when present and non-empty, otherwise the ACTA result.
"""
FLOW_ResolveConfig_DDEF(::Nothing, Fallback::AbstractVector) = Fallback
FLOW_ResolveConfig_DDEF(Custom::AbstractVector, Fallback::AbstractVector) =
    isempty(Custom) ? Fallback :
    [Dict{String,Any}(string(k) => FLOW_CopyEntry_DDEF(v) for (k, v) in pairs(c)) for c in Custom]

"""
    FLOW_ResolveMethod_DDEF(Method) -> CORE_AbstractDesignMethod_DDET
Resolve a design code to its Lib_Core trait without throwing; unknown codes fall back to TL09.
"""
FLOW_ResolveMethod_DDEF(Method::AbstractString)::CORE_AbstractDesignMethod_DDET =
    get(CORE_MethodMap_DDEC, uppercase(strip(Method)), CORE_MethodTL09_DDES())

"""
    FLOW_GetStoredDirection_DDEF(Method, Dir) -> Union{AbstractVector, Nothing}
Return the direction vector to persist; only directional designs retain it.
"""
FLOW_GetStoredDirection_DDEF(::CORE_MethodDF14_DDES,           Dir)    = Dir
FLOW_GetStoredDirection_DDEF(::CORE_AbstractDesignMethod_DDET, ::Any)  = nothing

"""
    FLOW_GetDirectionMap_DDEF(Method, Names, Dir) -> Union{Dict{String, Any}, Nothing}
Map variable names to axial directions for directional designs.
"""
FLOW_GetDirectionMap_DDEF(::CORE_MethodDF14_DDES, Names::AbstractVector{<:AbstractString}, Dir::AbstractVector) =
    (length(Names) == 3 && length(Dir) >= 3) ? Dict{String,Any}(string(Names[i]) => Int(Dir[i]) for i in 1:3) : nothing
FLOW_GetDirectionMap_DDEF(::CORE_MethodDF14_DDES,           ::AbstractVector{<:AbstractString}, ::Nothing) = nothing
FLOW_GetDirectionMap_DDEF(::CORE_AbstractDesignMethod_DDET, ::AbstractVector{<:AbstractString}, ::Any)     = nothing

# ------------------------------------------------------------------------------
# SECTION 2: PROCESS FLOW LOGIC
# ------------------------------------------------------------------------------

"""
    FLOW_ClassifyBoundaryMode_DDEF(Val, Min, Max, MinLimit=-Inf, MaxLimit=Inf, ContractionOrSpan=0.5) -> FLOW_AbstractBoundaryMode_DDET
Classify experimental factor coordinate adaptation mode into contraction, translation, or boundary seeking.
"""
function FLOW_ResolvePhysicalBounds_DDEF(MinRaw, MaxRaw)::Tuple{Float64, Float64}
    mn = FAST_SafeNum_DDEF(MinRaw)
    mx = FAST_SafeNum_DDEF(MaxRaw)
    mn_f = isnan(mn) ? -Inf : Float64(mn)
    mx_f = isnan(mx) ?  Inf : Float64(mx)
    # Treat Gui_Deck's default [0.0, 0.0] sentinel as unbounded limits.
    if mn_f == 0.0 && mx_f == 0.0
        return (-Inf, Inf)
    end
    return (mn_f, mx_f)
end

function FLOW_ClassifyBoundaryMode_DDEF(Val::Real, Min::Real, Max::Real, MinLimit::Real=-Inf, MaxLimit::Real=Inf, Contraction::Real=0.5; Alpha::Real=1.0, TargetSpan::Real=0.0)::FLOW_AbstractBoundaryMode_DDET
    val = Float64(Val)
    span_source = Float64(Max - Min)
    (span_source <= 1e-9) && (span_source = 1.0)

    α = Float64(Alpha)
    span_target = (α != 1.0) ? abs(α) * span_source : span_source

    c_span = if Float64(TargetSpan) > 0.0
        clamp(Float64(TargetSpan), 0.05 * span_target, span_target)
    else
        clamp(Float64(Contraction), 0.05, 1.0) * span_target
    end

    min_lim, max_lim = FLOW_ResolvePhysicalBounds_DDEF(MinLimit, MaxLimit)
    has_min_limit = isfinite(min_lim)
    has_max_limit = isfinite(max_lim)

    val_clamped = clamp(val, min_lim, max_lim)

    edge_lower = Float64(Min) + 0.05 * span_source
    edge_upper = Float64(Max) - 0.05 * span_source
    full_upper = Float64(Max) + 0.50 * span_source
    full_lower = Float64(Min) - 0.50 * span_source

    tentative_span = if edge_lower <= val_clamped <= edge_upper
        c_span
    elseif edge_upper < val_clamped <= full_upper
        c_span + ((val_clamped - edge_upper) / (full_upper - edge_upper)) * (span_target - c_span)
    elseif val_clamped > full_upper
        span_target
    elseif full_lower <= val_clamped < edge_lower
        c_span + ((edge_lower - val_clamped) / (edge_lower - full_lower)) * (span_target - c_span)
    else
        span_target
    end

    cand_l1 = val_clamped - 0.5 * tentative_span
    cand_l3 = val_clamped + 0.5 * tentative_span

    if has_max_limit && (cand_l3 >= max_lim - 1e-9 || val_clamped >= max_lim - 1e-9)
        return FLOW_ModeSeekUpper_DDES()
    elseif has_min_limit && (cand_l1 <= min_lim + 1e-9 || val_clamped <= min_lim + 1e-9)
        return FLOW_ModeSeekLower_DDES()
    end

    if val_clamped > edge_upper + 1e-9
        return FLOW_ModeTranslateUpper_DDES()
    elseif val_clamped < edge_lower - 1e-9
        return FLOW_ModeTranslateLower_DDES()
    end

    return FLOW_ModeContract_DDES()
end

"""
    FLOW_AuditLeader_DDEF(LeaderVal::Real, CurrentRange::Vector{Float64}, MinLimit::Real=-Inf, MaxLimit::Real=Inf) -> Tuple{Bool, String}
Evaluate whether a chosen leader factor coordinate is in proximity to boundary limits, detecting potential space clipping.
Flags coordinates lying dangerously close to the lower or upper physical thresholds to protect subsequent phase search volumes.

# Arguments
- `LeaderVal::Real`: Candidate optimal factor coordinate.
- `CurrentRange::Vector{Float64}`: Current factor domain range `[min, mid, max]`.
- `MinLimit::Real`: Minimum physical boundary threshold (default: `-Inf`).
- `MaxLimit::Real`: Maximum physical boundary threshold (default: `Inf`).

# Returns
- `Tuple{Bool, String}`: `(is_safe, alert_message)`.
"""
function FLOW_AuditLeader_DDEF(LeaderVal::Real, CurrentRange::AbstractVector{<:Real}, MinLimit::Real=-Inf, MaxLimit::Real=Inf, TargetSpan::Real=0.0; Alpha::Real=1.0)
    status = FLOW_ClassifyBoundaryMode_DDEF(LeaderVal, CurrentRange[1], CurrentRange[3], MinLimit, MaxLimit; Alpha=Alpha, TargetSpan=TargetSpan)
    return FLOW_CheckBoundaryAlert_DDEF(status)
end

"""
    FLOW_BuildIPKT_DDEF(MasterFile, CurrentPhase, SelectedLeaderID="", ContractionFactor=0.5) -> Dict{String, Any}
Construct sequential phase transition boundaries by applying ACTA (Adaptive Contraction & Translation Algorithm).
Extracts the selected leader run, scales continuous factor spreads, and computes contracted coordinate bounds for the subsequent design.

# Arguments
- `MasterFile`: Path to master workbook.
- `CurrentPhase`: Current experimental phase identifier.
- `SelectedLeaderID`: Optional leader identifier (defaults to highest desirability run).
- `ContractionFactor`: Search domain scaling factor in `(0.0, 1.0]` (default: `0.5`).

# Returns
- `Dict{String, Any}`: Dictionary containing adapted factor configurations, boundary alerts, and leader coordinates.
"""
function FLOW_BuildIPKT_DDEF(MasterFile::Union{AbstractString,AbstractDict,Nothing}, CurrentPhase::Union{AbstractString,Nothing},
    SelectedLeaderID::Union{AbstractString,Nothing}="", ContractionFactor::Real=0.5)::Dict{String,Any}
    
    is_transient_src = !(MasterFile isa AbstractString && isfile(MasterFile))
    target_file = FLOW_ResolveSource_DDEF(MasterFile)
    try
        !FLOW_IsValidFile_DDEF(target_file) && return Dict("Status" => "FAIL", "Message" => "Invalid master file path provided.")
        !FLOW_IsFilled_DDEF(CurrentPhase) && return Dict("Status" => "FAIL", "Message" => "Current phase not specified.")
        
        RawConf   = FAST_ReadConfig_DDEF(target_file)

        OldConfig  = Dict{String,Any}[]
        Outputs    = Dict{String,Any}[]
        GlobalInfo = Dict{String,Any}()
        InNames    = String[]

        if !isempty(RawConf)
            try
                if haskey(RawConf, "Ingredients")
                    raw_ing  = RawConf["Ingredients"]
                    iter_ing = FLOW_IterateEntries_DDEF(raw_ing)
                    OldConfig = map(iter_ing) do item
                        d = FLOW_FormatStringDict_DDEF(item)
                        d["Levels"] = if haskey(d, "Levels")
                            Float64[let v = FAST_SafeNum_DDEF(x); isfinite(v) ? v : 0.0 end for x in d["Levels"]]
                        elseif all(k -> haskey(d, k), ("L1", "L2", "L3"))
                            Float64[let v = FAST_SafeNum_DDEF(d[k]); isfinite(v) ? v : 0.0 end for k in ("L1", "L2", "L3")]
                        else
                            Float64[0.0, 0.0, 0.0]
                        end

                        if get(d, "Role", "") == C.ROLE_VAR
                            push!(InNames, get(d, "Name", ""))
                        end
                        return d
                    end
                end

                Outputs    = [FLOW_FormatStringDict_DDEF(o) for o in get(RawConf, "Outputs", [])]
                GlobalInfo = FLOW_FormatStringDict_DDEF(get(RawConf, "Global", nothing))

                # Align FORW-corrected variable bounds to observed ACTUAL bounds before ASTM -> ACTA preserves 3 clean levels in Phase N+1.
                r_opts = FLOW_FormatStringDict_DDEF(get(RawConf, "RadioOpts", nothing))
                f_opts = FLOW_FormatStringDict_DDEF(get(r_opts, "FORW", nothing))
                forw_on = FAST_IsFlagTrue_DDEF(get(r_opts, "Apply", false)) &&
                          FAST_IsFlagTrue_DDEF(get(f_opts, "Enabled", false))
                if forw_on
                    df_data = FAST_ReadExcel_DDEF(target_file, C.SHEET_DATA)
                    if !isempty(df_data)
                        col_phase = FAST_GetColumn_DDEF(df_data, C.COL_PHASE)
                        phase_mask = isempty(col_phase) ? trues(nrow(df_data)) :
                            [(!ismissing(v) && strip(string(v)) == strip(string(CurrentPhase))) for v in df_data[!, Symbol(col_phase)]]
                        df_phase = view(df_data, phase_mask, :)
                        if nrow(df_phase) > 0
                            p_names = string.(names(df_data))
                            for conf in OldConfig
                                get(conf, "Role", "") == C.ROLE_VAR || continue
                                v_name = strip(string(get(conf, "Name", "")))
                                (haskey(f_opts, v_name) && f_opts[v_name] isa AbstractDict) || continue

                                col_act = FAST_GetColumn_DDEF(df_data, C.PRE_ACTUAL * v_name)
                                if isempty(col_act)
                                    v_clean = replace(v_name, " " => "_")
                                    pfx, pfx_u = C.PRE_ACTUAL * v_name, C.PRE_ACTUAL * v_clean
                                    act_match = findfirst(c -> c == pfx || startswith(c, pfx * "_") || c == pfx_u || startswith(c, pfx_u * "_"), p_names)
                                    !isnothing(act_match) && (col_act = p_names[act_match])
                                end
                                isempty(col_act) && continue

                                act_vals = Float64[]
                                for raw_v in df_phase[!, Symbol(col_act)]
                                    ismissing(raw_v) && continue
                                    val_num = Float64(FAST_SafeNum_DDEF(raw_v))
                                    (!isnan(val_num) && isfinite(val_num) && val_num > 0.0) && push!(act_vals, val_num)
                                end
                                if length(act_vals) >= 2
                                    act_min, act_max = extrema(act_vals)
                                    act_max > act_min && (conf["Levels"] = Float64[act_min, 0.5 * (act_min + act_max), act_max])
                                end
                            end
                        end
                    end
                end

            catch e
                FAST_HandleCatch_DDEF(FAST_TierLogged_DDES(), e, "FLOW", "STATE_RESTORE", "JSON configuration sync failed")
            end
        end

        isempty(OldConfig) && return Dict("Status" => "FAIL", "Message" => "Configuration state loss detected.")

        Leader = CORE_ExtractLeader_DDEF(target_file, CurrentPhase, SelectedLeaderID, InNames)
        isempty(Leader) && return Dict("Status" => "FAIL", "Message" => "Leader extraction failed for $CurrentPhase.")

        Leader["OldConfig"] = OldConfig
        
        alerts = String[]
        vars_only = filter(c -> get(c, "Role", "") == C.ROLE_VAR, OldConfig)
        for (j, conf) in enumerate(vars_only)
            lvls = get(conf, "Levels", [0.0, 0.0, 0.0])
            val  = (j <= length(Leader["Vals"]) && isfinite(FAST_SafeNum_DDEF(Leader["Vals"][j]))) ? Float64(FAST_SafeNum_DDEF(Leader["Vals"][j])) : Float64(lvls[2])
            min_lim, max_lim = FLOW_ResolvePhysicalBounds_DDEF(get(conf, "Min", -Inf), get(conf, "Max", Inf))

            α = haskey(conf, "Alpha") ? (let v = FAST_SafeNum_DDEF(conf["Alpha"]); isfinite(v) ? Float64(v) : 1.0 end) : 1.0
            β = haskey(conf, "Beta")  ? (let v = FAST_SafeNum_DDEF(conf["Beta"]);  isfinite(v) ? Float64(v) : 0.0 end) : 0.0
            eff_val = (α != 1.0 || β != 0.0) ? FLOW_ApplyASTM_DDEF(val, α, β) : val
            eff_lvls = (α != 1.0 || β != 0.0) ? Float64[FLOW_ApplyASTM_DDEF(x, α, β) for x in lvls] : Float64.(lvls)
            if α != 1.0 || β != 0.0
                _, eff_val, _ = FLOW_ValidateASTM_DDEF(eff_val, min_lim, max_lim)
            end
            sort!(eff_lvls)

            rng = eff_lvls[3] - eff_lvls[1]
            (rng <= 1e-9) && (rng = 1.0)
            target_span = rng * Float64(ContractionFactor)

            # Evaluate leader proximity strictly in target ASTM space so α is never applied twice.
            ok, msg = FLOW_AuditLeader_DDEF(eff_val, eff_lvls, min_lim, max_lim, target_span; Alpha=1.0)
            !ok && push!(alerts, "[Var $(j)]: " * msg)
        end

        NewConfig = FLOW_ApplyACTA_DDEF(Leader, ContractionFactor)
        target_phase = FLOW_AdvancePhase_DDEF(CurrentPhase)

        return Dict(
            "Status"       => "OK",
            "SourcePhase"  => CurrentPhase,
            "TargetPhase"  => target_phase,
            "NewConfig"    => NewConfig,
            "OldConfig"    => OldConfig,
            "LeaderValues" => Float64[let v = FAST_SafeNum_DDEF(x); isfinite(v) ? v : 0.0 end for x in get(Leader, "Vals", Float64[])],
            "LeaderScore"  => (let v = FAST_SafeNum_DDEF(get(Leader, "Score", 0.0)); isfinite(v) ? v : 0.0 end),
            "Outputs"        => Outputs,
            "Global"         => GlobalInfo,
            "BoundaryAlerts" => alerts
        )
    finally
        is_transient_src && FAST_CleanTransient_DDEF(target_file)
    end
end

"""
    FLOW_GetCandidates_DDEF(MasterFile, CurrentPhase) -> Vector{Dict{String, Any}}
Retrieve and sort all candidate optimal runs from the designated phase record by composite desirability.
Parses the leader sheet in the workbook and returns a descending priority queue of experimental formulations.

# Arguments
- `MasterFile`: Path to master workbook.
- `CurrentPhase`: Phase identifier from which candidates are loaded.

# Returns
- `Vector{Dict{String, Any}}`: Sorted array of candidate runs with associated factors, responses, and desirability scores.
"""
function FLOW_GetCandidates_DDEF(MasterFile::Union{AbstractString,AbstractDict,Nothing}, CurrentPhase::Union{AbstractString,Nothing})::Vector{Dict{String,Any}}
    is_transient_src = !(MasterFile isa AbstractString && isfile(MasterFile))
    target_file = FLOW_ResolveSource_DDEF(MasterFile)
    try
        !FLOW_IsValidFile_DDEF(target_file) && return Dict{String,Any}[]
        !FLOW_IsFilled_DDEF(CurrentPhase) && return Dict{String,Any}[]
        
        df = FAST_ReadExcel_DDEF(target_file, C.PREFIX_LEADERS * CurrentPhase)
        isempty(df) && return Dict{String,Any}[]

        candidates = map(eachrow(df)) do row
            d          = Dict{String,Any}(string(k) => (v isa AbstractFloat && !isfinite(v) ? nothing : v) for (k, v) in pairs(row))
            lookup     = Dict(uppercase(string(k)) => v for (k, v) in pairs(row))
            d["Score"] = let v = FAST_SafeNum_DDEF(get(lookup, "SCORE", 0.0)); isfinite(v) ? v : 0.0 end
            return d
        end

        return sort!(candidates; by=x -> x["Score"], rev=true, alg=Base.Sort.MergeSort)
    finally
        is_transient_src && FAST_CleanTransient_DDEF(target_file)
    end
end

"""
    FLOW_SeekCeiling_DDEF(eff_mid::Real, MinLimit::Real, MaxLimit::Real, SeekSpan::Real=0.0) -> Vector{Float64}
Rule 3: Boundary seeking alignment at upper ceiling boundary with anti-degeneracy protection.
"""
function FLOW_SeekCeiling_DDEF(eff_mid::Real, MinLimit::Real, MaxLimit::Real, SeekSpan::Real=0.0)::Vector{Float64}
    if !isfinite(MaxLimit)
        return FLOW_ShiftWindow_DDEF(eff_mid, SeekSpan > 1e-9 ? SeekSpan : 1.0, MinLimit, MaxLimit)
    end
    span = Float64(SeekSpan)
    if span <= 1e-9
        span = (isfinite(MinLimit) && isfinite(MaxLimit) && MaxLimit > MinLimit) ? 0.10 * (Float64(MaxLimit) - Float64(MinLimit)) : 1.0
    end
    (span <= 1e-9) && (span = 1.0)

    l3 = Float64(MaxLimit)
    l1 = isfinite(MinLimit) ? max(Float64(MinLimit), l3 - span) : (l3 - span)
    l2 = (l1 + l3) / 2.0
    return Float64[l1, l2, l3]
end

"""
    FLOW_SeekFloor_DDEF(eff_mid::Real, MinLimit::Real, MaxLimit::Real, SeekSpan::Real=0.0) -> Vector{Float64}
Rule 3: Boundary seeking alignment at lower floor boundary with anti-degeneracy protection.
"""
function FLOW_SeekFloor_DDEF(eff_mid::Real, MinLimit::Real, MaxLimit::Real, SeekSpan::Real=0.0)::Vector{Float64}
    if !isfinite(MinLimit)
        return FLOW_ShiftWindow_DDEF(eff_mid, SeekSpan > 1e-9 ? SeekSpan : 1.0, MinLimit, MaxLimit)
    end
    span = Float64(SeekSpan)
    if span <= 1e-9
        span = (isfinite(MinLimit) && isfinite(MaxLimit) && MaxLimit > MinLimit) ? 0.10 * (Float64(MaxLimit) - Float64(MinLimit)) : 1.0
    end
    (span <= 1e-9) && (span = 1.0)

    l1 = Float64(MinLimit)
    l3 = isfinite(MaxLimit) ? min(Float64(MaxLimit), l1 + span) : (l1 + span)
    l2 = (l1 + l3) / 2.0
    return Float64[l1, l2, l3]
end

"""
    FLOW_ShiftWindow_DDEF(eff_mid::Real, Span::Real, MinLimit::Real, MaxLimit::Real) -> Vector{Float64}
Shift search space window against physical limits without domain span collapse (window clamping / sliding).
Preserves the full adapted span when candidate bounds exceed limits while the leader remains in non-seeking zones.

# Arguments
- `eff_mid::Real`: Effective centre coordinate value.
- `Span::Real`: Target search space width `(L3 - L1)`.
- `MinLimit::Real`: Minimum physical boundary threshold.
- `MaxLimit::Real`: Maximum physical boundary threshold.

# Returns
- `Vector{Float64}`: 3-element vector containing window-shifted `[L1, L2, L3]` levels.
"""
function FLOW_ShiftWindow_DDEF(eff_mid::Real, Span::Real, MinLimit::Real, MaxLimit::Real)::Vector{Float64}
    span_val  = Float64(Span)
    half_span = 0.5 * span_val
    cand_l1   = Float64(eff_mid) - half_span
    cand_l3   = Float64(eff_mid) + half_span

    if isfinite(MaxLimit) && cand_l3 > Float64(MaxLimit)
        cand_l3 = Float64(MaxLimit)
        cand_l1 = isfinite(MinLimit) ? max(Float64(MinLimit), cand_l3 - span_val) : (cand_l3 - span_val)
        cand_l2 = (cand_l1 + cand_l3) / 2.0
        return Float64[cand_l1, cand_l2, cand_l3]
    elseif isfinite(MinLimit) && cand_l1 < Float64(MinLimit)
        cand_l1 = Float64(MinLimit)
        cand_l3 = isfinite(MaxLimit) ? min(Float64(MaxLimit), cand_l1 + span_val) : (cand_l1 + span_val)
        cand_l2 = (cand_l1 + cand_l3) / 2.0
        return Float64[cand_l1, cand_l2, cand_l3]
    end

    return Float64[cand_l1, Float64(eff_mid), cand_l3]
end

"""
    FLOW_ExecuteACTA_DDEF(Status, Val, L_Old, Contraction=0.5, MinLimit=-Inf, MaxLimit=Inf) -> Vector{Float64}
Multiple dispatch kernel for ACTA search space adaptation based on boundary mode traits.
"""
function FLOW_ExecuteACTA_DDEF(::FLOW_ModeContract_DDES, Val::Real, L_Old::AbstractVector{<:Real}, Contraction::Real=0.5, MinLimit::Real=-Inf, MaxLimit::Real=Inf; Alpha::Real=1.0)::Vector{Float64}
    span_source = Float64(L_Old[3] - L_Old[1])
    (span_source <= 1e-9) && (span_source = 1.0)
    α = Float64(Alpha)
    span_target = (α != 1.0) ? abs(α) * span_source : span_source
    c_ratio = clamp(Float64(Contraction), 0.05, 1.0)
    span = c_ratio * span_target
    val = Float64(Val)
    min_lim, max_lim = FLOW_ResolvePhysicalBounds_DDEF(MinLimit, MaxLimit)
    half_span = 0.5 * span
    l1 = val - half_span
    l2 = val
    l3 = val + half_span
    isfinite(min_lim) && (l1 = max(l1, min_lim))
    isfinite(max_lim) && (l3 = min(l3, max_lim))
    l1 > l3 && isfinite(min_lim) && isfinite(max_lim) && ((l1, l3) = (min_lim, max_lim))
    l2 = clamp(l2, l1, l3)
    return Float64[l1, l2, l3]
end

function FLOW_ExecuteACTA_DDEF(::FLOW_ModeTranslateUpper_DDES, Val::Real, L_Old::AbstractVector{<:Real}, Contraction::Real=0.5, MinLimit::Real=-Inf, MaxLimit::Real=Inf; Alpha::Real=1.0)::Vector{Float64}
    span_source = Float64(L_Old[3] - L_Old[1])
    (span_source <= 1e-9) && (span_source = 1.0)
    α = Float64(Alpha)
    span_target = (α != 1.0) ? abs(α) * span_source : span_source
    c_ratio = clamp(Float64(Contraction), 0.05, 1.0)
    val = Float64(Val)
    min_lim, max_lim = FLOW_ResolvePhysicalBounds_DDEF(MinLimit, MaxLimit)

    edge_upper = Float64(L_Old[3]) - 0.05 * span_source
    full_upper = Float64(L_Old[3]) + 0.50 * span_source
    c_span = c_ratio * span_target
    anchor_lower = edge_upper - 0.5 * c_span

    if val <= full_upper
        span = c_span + ((val - edge_upper) / (full_upper - edge_upper)) * (span_target - c_span)
        half_span = 0.5 * span
        l1 = max(val - half_span, anchor_lower)
        l2 = val
        l3 = val + half_span
    else
        span = span_target
        half_span = 0.5 * span
        l1 = val - half_span
        l2 = val
        l3 = val + half_span
    end
    isfinite(min_lim) && (l1 = max(l1, min_lim))
    isfinite(max_lim) && (l3 = min(l3, max_lim))
    l1 > l3 && isfinite(min_lim) && isfinite(max_lim) && ((l1, l3) = (min_lim, max_lim))
    l2 = clamp(l2, l1, l3)
    return Float64[l1, l2, l3]
end

function FLOW_ExecuteACTA_DDEF(::FLOW_ModeTranslateLower_DDES, Val::Real, L_Old::AbstractVector{<:Real}, Contraction::Real=0.5, MinLimit::Real=-Inf, MaxLimit::Real=Inf; Alpha::Real=1.0)::Vector{Float64}
    span_source = Float64(L_Old[3] - L_Old[1])
    (span_source <= 1e-9) && (span_source = 1.0)
    α = Float64(Alpha)
    span_target = (α != 1.0) ? abs(α) * span_source : span_source
    c_ratio = clamp(Float64(Contraction), 0.05, 1.0)
    val = Float64(Val)
    min_lim, max_lim = FLOW_ResolvePhysicalBounds_DDEF(MinLimit, MaxLimit)

    edge_lower = Float64(L_Old[1]) + 0.05 * span_source
    full_lower = Float64(L_Old[1]) - 0.50 * span_source
    c_span = c_ratio * span_target
    anchor_upper = edge_lower + 0.5 * c_span

    if val >= full_lower
        span = c_span + ((edge_lower - val) / (edge_lower - full_lower)) * (span_target - c_span)
        half_span = 0.5 * span
        l3 = min(val + half_span, anchor_upper)
        l2 = val
        l1 = val - half_span
    else
        span = span_target
        half_span = 0.5 * span
        l1 = val - half_span
        l2 = val
        l3 = val + half_span
    end
    isfinite(min_lim) && (l1 = max(l1, min_lim))
    isfinite(max_lim) && (l3 = min(l3, max_lim))
    l1 > l3 && isfinite(min_lim) && isfinite(max_lim) && ((l1, l3) = (min_lim, max_lim))
    l2 = clamp(l2, l1, l3)
    return Float64[l1, l2, l3]
end

function FLOW_ExecuteACTA_DDEF(::FLOW_ModeSeekUpper_DDES, Val::Real, L_Old::AbstractVector{<:Real}, Contraction::Real=0.5, MinLimit::Real=-Inf, MaxLimit::Real=Inf; Alpha::Real=1.0)::Vector{Float64}
    span_source = Float64(L_Old[3] - L_Old[1])
    (span_source <= 1e-9) && (span_source = 1.0)
    α = Float64(Alpha)
    span_target = (α != 1.0) ? abs(α) * span_source : span_source
    min_lim_res, max_lim_res = FLOW_ResolvePhysicalBounds_DDEF(MinLimit, MaxLimit)
    max_lim = isfinite(max_lim_res) ? max_lim_res : Float64(L_Old[3])
    val = Float64(Val)
    d = max_lim - val
    span_min = 0.10 * span_target

    if 2.0 * d >= span_min && val < max_lim
        l3 = max_lim
        l2 = val
        l1 = val - d
        isfinite(min_lim_res) && (l1 = max(l1, min_lim_res))
        l2 = clamp(l2, l1, l3)
        return Float64[l1, l2, l3]
    else
        l3 = max_lim
        l1 = max_lim - span_min
        isfinite(min_lim_res) && (l1 = max(l1, min_lim_res))
        l1 > l3 && (l1 = l3)
        l2 = (l1 + l3) * 0.5
        return Float64[l1, l2, l3]
    end
end

function FLOW_ExecuteACTA_DDEF(::FLOW_ModeSeekLower_DDES, Val::Real, L_Old::AbstractVector{<:Real}, Contraction::Real=0.5, MinLimit::Real=-Inf, MaxLimit::Real=Inf; Alpha::Real=1.0)::Vector{Float64}
    span_source = Float64(L_Old[3] - L_Old[1])
    (span_source <= 1e-9) && (span_source = 1.0)
    α = Float64(Alpha)
    span_target = (α != 1.0) ? abs(α) * span_source : span_source
    min_lim_res, max_lim_res = FLOW_ResolvePhysicalBounds_DDEF(MinLimit, MaxLimit)
    min_lim = isfinite(min_lim_res) ? min_lim_res : Float64(L_Old[1])
    val = Float64(Val)
    d = val - min_lim
    span_min = 0.10 * span_target

    if 2.0 * d >= span_min && val > min_lim
        l1 = min_lim
        l2 = val
        l3 = val + d
        isfinite(max_lim_res) && (l3 = min(l3, max_lim_res))
        l2 = clamp(l2, l1, l3)
        return Float64[l1, l2, l3]
    else
        l1 = min_lim
        l3 = min_lim + span_min
        isfinite(max_lim_res) && (l3 = min(l3, max_lim_res))
        l1 > l3 && (l3 = l1)
        l2 = (l1 + l3) * 0.5
        return Float64[l1, l2, l3]
    end
end

FLOW_ExecuteACTA_DDEF(::FLOW_AbstractBoundaryMode_DDET, Val::Real, L_Old::AbstractVector{<:Real}, Contraction::Real=0.5, MinLimit::Real=-Inf, MaxLimit::Real=Inf; Alpha::Real=1.0)::Vector{Float64} =
    FLOW_ExecuteACTA_DDEF(FLOW_ModeContract_DDES(), Val, L_Old, Contraction, MinLimit, MaxLimit; Alpha=Alpha)

"""
    FLOW_RoundLevelTriplet_DDEF(levels::AbstractVector{<:Real}, MinLimit::Real=-Inf, MaxLimit::Real=Inf) -> Vector{Float64}
Round an adapted [L1, L2, L3] triplet to `C.PREC_DATA` decimal places while preserving symmetry, strict ordering `L1 < L2 < L3`, and physical bounds.
"""
function FLOW_RoundLevelTriplet_DDEF(levels::AbstractVector{<:Real}, MinLimit::Real=-Inf, MaxLimit::Real=Inf)::Vector{Float64}
    l1, l2, l3 = Float64(levels[1]), Float64(levels[2]), Float64(levels[3])
    mn = isfinite(Float64(MinLimit)) ? Float64(MinLimit) : -Inf
    mx = isfinite(Float64(MaxLimit)) ? Float64(MaxLimit) : Inf
    # Round centre and half-span together for symmetric intervals so L2 - L1 == L3 - L2 stays exact.
    is_sym = abs((l3 - l2) - (l2 - l1)) <= 1e-9 * max(1.0, l3 - l1)
    for d in C.PREC_DATA:C.PREC_FINE
        cand = if is_sym
            c_mid  = clamp(round(l2; digits=d), mn, mx)
            c_half = round(0.5 * (l3 - l1); digits=d)
            Float64[clamp(round(c_mid - c_half; digits=d), mn, mx), c_mid, clamp(round(c_mid + c_half; digits=d), mn, mx)]
        else
            Float64[clamp(round(x; digits=d), mn, mx) for x in (l1, l2, l3)]
        end
        cand[1] < cand[2] < cand[3] && return cand
    end
    return Float64[l1, l2, l3]
end

"""
    FLOW_CalcACTA_DDEF(Val, L_Old, Contraction=0.5; Translation=0.0, MinLimit=-Inf, MaxLimit=Inf, Alpha=1.0) -> Vector{Float64}
Calculate adapted factor coordinate triplet [L1, L2, L3] by harmonising ASTM, ACTA, and SEEK guardrails.
"""
function FLOW_CalcACTA_DDEF(
    Val::Real,
    L_Old::AbstractVector{<:Real},
    Contraction::Real=0.5;
    Translation::Real=0.0,
    MinLimit::Real=-Inf,
    MaxLimit::Real=Inf,
    Alpha::Real=1.0
)::Vector{Float64}
    length(L_Old) < 3 && return Float64[Float64(Val) - 1.0, Float64(Val), Float64(Val) + 1.0]

    val = Float64(Val)
    α = Float64(Alpha)
    span_source = Float64(L_Old[3] - L_Old[1])
    (span_source <= 1e-9) && (span_source = 1.0)
    span_target = (α != 1.0) ? abs(α) * span_source : span_source
    c_ratio = clamp(Float64(Contraction), 0.05, 1.0)

    if abs(Float64(Translation)) > 1e-9
        trans_offset = Float64(Translation) * (span_target * c_ratio * 0.5)
        val = val + trans_offset
    end

    min_lim, max_lim = FLOW_ResolvePhysicalBounds_DDEF(MinLimit, MaxLimit)

    val_clamped = clamp(val, min_lim, max_lim)

    status = FLOW_ClassifyBoundaryMode_DDEF(val_clamped, L_Old[1], L_Old[3], min_lim, max_lim, c_ratio; Alpha=α)
    raw_levels = FLOW_ExecuteACTA_DDEF(status, val_clamped, L_Old, c_ratio, min_lim, max_lim; Alpha=α)
    return FLOW_RoundLevelTriplet_DDEF(raw_levels, min_lim, max_lim)
end

function FLOW_CalcACTA_DDEF(
    Val::Real,
    L_Old::AbstractVector{<:Real},
    Contraction::Real,
    Translation::Real;
    MinLimit::Real=-Inf,
    MaxLimit::Real=Inf,
    Alpha::Real=1.0
)::Vector{Float64}
    return FLOW_CalcACTA_DDEF(Val, L_Old, Contraction; Translation=Translation, MinLimit=MinLimit, MaxLimit=MaxLimit, Alpha=Alpha)
end

function FLOW_CalcACTA_DDEF(
    Val::Real,
    L_Old::AbstractVector{<:Real},
    Contraction::Real,
    Translation::Real,
    MinLimit::Real;
    MaxLimit::Real=Inf,
    Alpha::Real=1.0
)::Vector{Float64}
    return FLOW_CalcACTA_DDEF(Val, L_Old, Contraction; Translation=Translation, MinLimit=MinLimit, MaxLimit=MaxLimit, Alpha=Alpha)
end

function FLOW_CalcACTA_DDEF(
    Val::Real,
    L_Old::AbstractVector{<:Real},
    Contraction::Real,
    Translation::Real,
    MinLimit::Real,
    MaxLimit::Real;
    Alpha::Real=1.0
)::Vector{Float64}
    return FLOW_CalcACTA_DDEF(Val, L_Old, Contraction; Translation=Translation, MinLimit=MinLimit, MaxLimit=MaxLimit, Alpha=Alpha)
end

# ------------------------------------------------------------------------------
# SECTION 3: EXCEL-CENTRIC PHASE TRANSITION
# ------------------------------------------------------------------------------

"""
    FLOW_AppendResponseColumns_DDEF!(df::DataFrame, outputs::AbstractVector) -> DataFrame
Append unallocated result, prediction, and global score columns to the protocol table.
"""
function FLOW_AppendResponseColumns_DDEF!(df::DataFrame, outputs::AbstractVector)::DataFrame
    n_runs = nrow(df)
    for o in outputs
        n = replace(strip(string(get(o, "Name", ""))), " " => "_")
        u = replace(strip(string(get(o, "Unit", ""))), " " => "_")
        isempty(n) && continue
        
        res_header  = (isempty(u) || u == "-") ? C.PRE_RESULT * n : C.PRE_RESULT * n * "_" * u
        pred_header = (isempty(u) || u == "-") ? C.PRE_PRED * n   : C.PRE_PRED * n   * "_" * u
        
        df[!, res_header]  = Vector{Union{Missing, Float64}}(missing, n_runs)
        df[!, pred_header] = Vector{Union{Missing, Float64}}(missing, n_runs)
    end
    df[!, C.COL_SCORE] = Vector{Union{Missing, Float64}}(missing, n_runs)
    return df
end

"""
    FLOW_AppendRadioColumns_DDEF!(df::DataFrame, NewConfig::AbstractVector, var_indices::AbstractVector{<:Integer}) -> DataFrame
Append radioactive decay tracking and decay-corrected activity columns when isotope factors exist.
"""
function FLOW_AppendRadioColumns_DDEF!(df::DataFrame, NewConfig::AbstractVector, var_indices::AbstractVector{<:Integer})::DataFrame
    n_runs = nrow(df)
    for c in NewConfig
        is_rad = FLOW_IsTruthy_DDEF(get(c, "IsRadioactive", false))
        hl_val = FAST_SafeNum_DDEF(get(c, "HalfLife", 0.0))
        if is_rad || hl_val > 0.0
            rn = string(FAST_SafeGet_DDEF(c, "Name", ""))
            ru = string(FAST_SafeGet_DDEF(c, "Unit", "mCi"))
            if !isempty(rn)
                df[!, C.PRE_TIME_FORW * rn] = fill(0.0, n_runs)
                
                dcyp_vals = fill(0.0, n_runs)
                for vi in var_indices
                    v_r = NewConfig[vi]
                    v_u = string(FAST_SafeGet_DDEF(v_r, "Unit", ""))
                    v_n = string(FAST_SafeGet_DDEF(v_r, "Name", ""))
                    if MOLE_IsTimeUnit_DDEF(v_u) || occursin(r"(?i)min|time|duration", v_n)
                        col_cand  = C.PRE_VAR * v_n * "_" * v_u
                        col_cand2 = C.PRE_VAR * v_n
                        target_c  = hasproperty(df, Symbol(col_cand)) ? Symbol(col_cand) : (hasproperty(df, Symbol(col_cand2)) ? Symbol(col_cand2) : nothing)
                        if !isnothing(target_c)
                            dcyp_vals = Float64.(df[!, target_c])
                            break
                        end
                    end
                end
                df[!, C.PRE_TIME_DCYP * rn] = dcyp_vals
                df[!, C.PRE_TIME_REVE * rn] = fill(0.0, n_runs)

                act_header = (isempty(ru) || ru == "-") ? C.PRE_ACTUAL * rn : C.PRE_ACTUAL * rn * "_" * ru
                df[!, act_header] = Vector{Union{Missing, Float64}}(missing, n_runs)
            end
        end
    end
    return df
end

"""
    FLOW_CommitIPKT_DDEF(MasterFile, CurrentPhase, SelectedLeaderID="", ContractionFactor=0.5, Method="TL09"; kwargs...) -> Dict{String, Any}
Finalise and persist sequential phase transition configurations and generated design matrices into the master workbook.
Generates the new experimental protocol sheet, updates configuration tracking records, and logs the evolutionary step.

# Arguments
- `MasterFile`: Path to master workbook.
- `CurrentPhase`: Active experimental phase code.
- `SelectedLeaderID`: Run identifier to advance as phase leader.
- `ContractionFactor`: ACTA search space contraction ratio.
- `Method`: Design method code for subsequent phase (`"TL09"`, `"BB15"`, `"CD17"`, `"DF14"`).

# Keywords
- `Direction`: Directional vector for `"DF14"` design method.
- `CustomConfig`: Optional overridden factor boundaries and units.
- `ProjectName`: Optional project title for metadata tracking.

# Returns
- `Dict{String, Any}`: Status dictionary with write confirmation and destination sheet details.
"""
function FLOW_CommitIPKT_DDEF(MasterFile::Union{AbstractString,AbstractDict,Nothing}, CurrentPhase::Union{AbstractString,Nothing},
    SelectedLeaderID::Union{AbstractString,Nothing}="", ContractionFactor::Real=0.5, Method::AbstractString="TL09";
    Direction::Union{Vector{Int}, Nothing}=[-1, -1, -1],
    CustomConfig::Union{AbstractVector, Nothing}=nothing,
    ProjectName::Union{AbstractString, Nothing}=nothing)::Dict{String,Any}
    
    is_transient_src = !(MasterFile isa AbstractString && isfile(MasterFile))
    target_file = FLOW_ResolveSource_DDEF(MasterFile)
    try
        !FLOW_IsValidFile_DDEF(target_file) && return Dict("Status" => "FAIL", "Message" => "Invalid master file path provided.")

        res = FLOW_BuildIPKT_DDEF(target_file, CurrentPhase, SelectedLeaderID, ContractionFactor)
        res["Status"] != "OK" && return res

        NewConfig   = FLOW_ResolveConfig_DDEF(CustomConfig, res["NewConfig"])
        TargetPhase = res["TargetPhase"]
        FAST_Log_DDEF("FLOW", "PHASE_BUILD", "Designing $TargetPhase search space from $CurrentPhase leader...", "WAIT")

        GlobalData = get(res, "Global", Dict())
        vol        = Float64(FAST_SafeNum_DDEF(FAST_SafeGet_DDEF(GlobalData, "Volume", 0.0)))
        conc       = Float64(FAST_SafeNum_DDEF(FAST_SafeGet_DDEF(GlobalData, "Conc", 0.0)))

        audit_rows = map(NewConfig) do c
            lvls = FAST_SafeGet_DDEF(c, "Levels", [0.0, 0.0, 0.0])
            Dict(
                "Name" => string(FAST_SafeGet_DDEF(c, "Name", "Unknown")), 
                "Role" => string(FAST_SafeGet_DDEF(c, "Role", "Fixed")),
                "L1"   => Float64(lvls[1]), 
                "L2"   => Float64(lvls[2]), 
                "L3"   => Float64(lvls[3]), 
                "MW"   => Float64(FAST_SafeGet_DDEF(c, "MW", 0.0)),
                "Unit" => string(FAST_SafeGet_DDEF(c, "Unit", "-"))
            )
        end

        audit_ok, audit_report, audit_results, t_mass, _ = MOLE_AuditQuick_DDEF(audit_rows, vol, conc)
        if !audit_ok && t_mass > 1e-4
            FAST_Log_DDEF("FLOW", "CHEM_FAIL", "Proposed subspace violates stoichiometry!", "FAIL")
            return Dict("Status" => "FAIL", "Message" => "Stoichiometric invalidity in new search space.\n" * audit_report)
        elseif !audit_ok
            FAST_Log_DDEF("FLOW", "CHEM_SKIP", "Stoichiometry not configured or zero mass. Proceeding...", "INFO")
        end

        if !isempty(audit_results)
            for c in NewConfig
                if FAST_SafeGet_DDEF(c, "Role", "") == C.ROLE_FILL
                    c_name = FAST_SafeGet_DDEF(c, "Name", "")
                    m_idx = findfirst(r -> r.Component == c_name, eachrow(audit_results))
                    if !isnothing(m_idx)
                        c["Levels"] = [0.0, audit_results[m_idx, :TARGET_MASS_mg], 0.0]
                    end
                end
            end
        end

        var_indices = findall(c -> FAST_SafeGet_DDEF(c, "Role", "") == C.ROLE_VAR, NewConfig)
        length(var_indices) != 3 && return Dict("Status" => "FAIL", "Message" => "System requires 3 ingredients for phase transitions.")
        any(i -> (c = NewConfig[i]; lv = FAST_SafeGet_DDEF(c, "Levels", [0.0, 0.0, 0.0]); get(c, "ReplaceReady", true) == false || length(lv) < 3 || !all(isfinite, lv[1:3]) || !(lv[1] < lv[2] < lv[3]) || isempty(strip(string(FAST_SafeGet_DDEF(c, "Name", ""))))), var_indices) && return Dict("Status" => "FAIL", "Message" => "Each variable requires a valid name and strictly increasing finite levels (L1 < L2 < L3).")
        design_coded = CORE_GenDesign_DDEF(Method, 3, Direction)
        method_type  = FLOW_ResolveMethod_DDEF(Method)
        N_Runs       = size(design_coded, 1)

        configs     = [Dict("Levels" => FAST_SafeGet_DDEF(NewConfig[i], "Levels", [0.0, 0.0, 0.0])) for i in var_indices]
        real_matrix = CORE_MapLevels_DDEF(design_coded, configs)

        p_num = something(tryparse(Int, replace(TargetPhase, "Phase" => "")), 2)

        df_sys = DataFrame(
            C.COL_EXP_ID    => ["EXP_P$(p_num)_$(lpad(i, 2, '0'))" for i in 1:N_Runs],
            C.COL_PHASE     => fill(TargetPhase, N_Runs),
            C.COL_STATUS    => fill("Pending", N_Runs),
            C.COL_NOTES     => fill("", N_Runs)
        )

        df_chem = MOLE_ProcessDesign_DDEF(real_matrix, audit_rows, vol, conc)

        df = hcat(df_sys, df_chem)

        FLOW_AppendResponseColumns_DDEF!(df, get(res, "Outputs", []))
        FLOW_AppendRadioColumns_DDEF!(df, NewConfig, var_indices)
        
        current_config                = FAST_ReadConfig_DDEF(target_file)
        for c in NewConfig
            if haskey(c, "Levels") && c["Levels"] isa AbstractVector && length(c["Levels"]) >= 3
                c["L1"] = Float64(c["Levels"][1])
                c["L2"] = Float64(c["Levels"][2])
                c["L3"] = Float64(c["Levels"][3]); delete!(c, "ReplaceReady")
            end
        end
        current_config["Ingredients"] = [FLOW_FormatStringDict_DDEF(c) for c in NewConfig]

        g_info                   = get(current_config, "Global", Dict{String,Any}())
        g_info["Method"]         = Method
        g_info["Direction"]      = FLOW_GetStoredDirection_DDEF(method_type, Direction)
        if !isnothing(ProjectName) && !isempty(strip(ProjectName))
            g_info["ProjectName"] = strip(string(ProjectName))
        end

        ph_raw     = get(g_info, "PhaseHistory", Dict{String,Any}())
        ph_history = FLOW_FormatStringDict_DDEF(ph_raw)
        var_names  = [string(FAST_SafeGet_DDEF(NewConfig[i], "Name", "")) for i in var_indices]

        ph_entry = Dict{String,Any}(
            "Method"            => Method,
            "DirectionMap"      => FLOW_GetDirectionMap_DDEF(method_type, var_names, Direction),
            "LeaderID"          => string(SelectedLeaderID),
            "ContractionFactor" => Float64(ContractionFactor),
            "N_Runs"            => N_Runs
        )
        ph_history[TargetPhase] = ph_entry
        g_info["PhaseHistory"]  = ph_history
        g_info["Phase"]         = TargetPhase
        current_config["Global"] = g_info

        out_names = String[replace(strip(string(get(o, "Name", ""))), " " => "_") for o in get(res, "Outputs", []) if !isempty(get(o, "Name", ""))]
        in_names  = String[replace(strip(string(FAST_SafeGet_DDEF(c, "Name", ""))), " " => "_") for c in NewConfig]

        success = FAST_InitialiseMaster_DDEF(target_file, in_names, out_names, df, current_config)
        !success && return Dict("Status" => "FAIL", "Message" => "Excel commit failed for $TargetPhase.")

        FAST_Log_DDEF("FLOW", "PHASE_BUILD", "Protocol $TargetPhase ($N_Runs runs) committed to Vault.", "OK")
        return Dict("Status" => "OK", "TargetPhase" => TargetPhase, "N_Runs" => N_Runs, "LeaderScore" => res["LeaderScore"])
    finally
        is_transient_src && FAST_CleanTransient_DDEF(target_file)
    end
end

# ==============================================================================
# PART B: ADAPTIVE RANGE & COMMITMENT BUS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 4: ADAPTIVE SEARCH SPACE
# ------------------------------------------------------------------------------

"""
    FLOW_ApplyACTA_DDEF(LeaderInfo::Dict, ContractionFactor::Float64=0.5) -> Vector{Dict{String, Any}}
Apply Adaptive Contraction & Translation Algorithm (ACTA) to all variable factors in a configuration set.
Iterates over continuous formulation ingredients, updating discrete boundary triplets based on leader coordinates.
Honours cross-system affine transformations (ASTM Alpha/Beta scaling) prior to domain contraction.

# Arguments
- `LeaderInfo::Dict`: Leader metadata containing `"OldConfig"` and `"Vals"`.
- `ContractionFactor::Float64`: Contraction ratio applied to factor level spans (default: `0.5`).

# Returns
- `Vector{Dict{String, Any}}`: Updated factor configuration list with contracted/translated levels.
"""
function FLOW_ApplyACTA_DDEF(LeaderInfo::AbstractDict, ContractionFactor::Real=0.5)
    NewConf = deepcopy(LeaderInfo["OldConfig"])
    SelVals = LeaderInfo["Vals"]

    FAST_Log_DDEF("FLOW", "SEARCH_SPACE", "Calculating ACTA design update (C=$(ContractionFactor))...", "WAIT")

    vars     = [(i, conf) for (i, conf) in enumerate(NewConf) if get(conf, "Role", "Variable") == C.ROLE_VAR]
    n_update = min(length(vars), length(SelVals))

    @inbounds for j in 1:n_update
        i, conf = vars[j]
        L_Old   = if haskey(conf, "Levels")
            Float64[let v = FAST_SafeNum_DDEF(x); isfinite(v) ? v : 0.0 end for x in conf["Levels"]]
        elseif all(k -> haskey(conf, k), ("L1", "L2", "L3"))
            Float64[let v = FAST_SafeNum_DDEF(conf[k]); isfinite(v) ? v : 0.0 end for k in ("L1", "L2", "L3")]
        else
            Float64[0.0, 0.0, 0.0]
        end
        Val     = SelVals[j]
        min_lim, max_lim = FLOW_ResolvePhysicalBounds_DDEF(get(conf, "Min", -Inf), get(conf, "Max", Inf))

        α       = haskey(conf, "Alpha") ? (let v = FAST_SafeNum_DDEF(conf["Alpha"]); isfinite(v) ? Float64(v) : 1.0 end) : 1.0
        β       = haskey(conf, "Beta")  ? (let v = FAST_SafeNum_DDEF(conf["Beta"]);  isfinite(v) ? Float64(v) : 0.0 end) : 0.0
        eff_l_old = (α != 1.0 || β != 0.0) ? Float64[FLOW_ApplyASTM_DDEF(x, α, β) for x in L_Old] : copy(L_Old)
        sort!(eff_l_old)

        if α != 1.0 || β != 0.0
            Val = FLOW_ApplyASTM_DDEF(Val, α, β)
            conf["Alpha"] = 1.0
            conf["Beta"]  = 0.0
        end
        ok_astm, Val, astm_msg = FLOW_ValidateASTM_DDEF(Val, min_lim, max_lim)
        if !ok_astm && !isempty(astm_msg)
            FAST_Log_DDEF("FLOW", "ASTM_ALIGN", "Var $i: $astm_msg", "WARN")
        end

        conf["EffectiveLeader"] = round(Val; digits=C.PREC_DATA)
        conf["OldLevels"]       = FLOW_RoundLevelTriplet_DDEF(eff_l_old)

        # Operate in target ASTM space so boundary classification and contraction never mix source/target coordinates.
        status = FLOW_ClassifyBoundaryMode_DDEF(Val, eff_l_old[1], eff_l_old[3], min_lim, max_lim, ContractionFactor; Alpha=1.0)
        action = FLOW_GetActionTag_DDEF(status)
        raw_levels = FLOW_ExecuteACTA_DDEF(status, Val, eff_l_old, ContractionFactor, min_lim, max_lim; Alpha=1.0)
        new_levels = FLOW_RoundLevelTriplet_DDEF(raw_levels, min_lim, max_lim)

        conf["Levels"] = new_levels
        conf["L1"]     = Float64(new_levels[1])
        conf["L2"]     = Float64(new_levels[2])
        conf["L3"]     = Float64(new_levels[3])

        FAST_Log_DDEF("FLOW", action, "Var $i -> $(action)", "LIST")
    end
    FAST_Log_DDEF("FLOW", "SEARCH_SPACE", "New space configured successfully.", "OK")
    return NewConf
end

"""
    FLOW_ApplySlotCustomisation_DDEF!(conf::AbstractVector, slots::AbstractVector, leader_vals::AbstractVector, Contraction::Real=1.0, old_conf::AbstractVector=conf)
Applies scale (ASTM) or replacement transformations and boundary overrides to phase factor configurations.
"""
function FLOW_ApplySlotCustomisation_DDEF!(conf::AbstractVector, slots::AbstractVector, leader_vals::AbstractVector, Contraction::Real=1.0, old_conf::AbstractVector=conf)
    fixed_mw_lookup = Dict{String,Float64}()
    for item in conf
        lowercase(strip(string(get(item, "Role", "")))) in ("fixed", "fix") || continue
        item_key = lowercase(strip(string(get(item, "Name", ""))))
        isempty(item_key) && continue
        mw_num = FAST_SafeNum_DDEF(get(item, "MW", 0.0))
        fixed_mw_lookup[item_key] = isnan(mw_num) ? 0.0 : Float64(mw_num)
    end

    promoted_fixed = Dict{String,Any}[]
    vi = 0
    for c in conf
        get(c, "Role", "") != C.ROLE_VAR && continue
        vi += 1
        vi > length(slots) && continue
        sl = slots[vi]
        mode = uppercase(strip(string(get(sl, "Mode", "KEEP"))))

        if mode == "REPLACE"
            old_name = strip(string(get(c, "Name", "")))
            eff_num  = haskey(c, "EffectiveLeader") ? FAST_SafeNum_DDEF(c["EffectiveLeader"]) : NaN
            old_leader = if !isnan(eff_num) && isfinite(eff_num)
                Float64(eff_num)
            elseif vi <= length(leader_vals)
                Float64(FAST_SafeNum_DDEF(leader_vals[vi]))
            else
                Float64(FAST_SafeNum_DDEF(get(c, "L2", 0.0)))
            end

            new_name = strip(string(get(sl, "NewName", "")))
            nl1 = FAST_SafeNum_DDEF(get(sl, "NewL1", NaN))
            nl2 = FAST_SafeNum_DDEF(get(sl, "NewL2", NaN))
            nl3 = FAST_SafeNum_DDEF(get(sl, "NewL3", NaN))

            # Promote the superseded factor's leader operating point to a Fixed constant when genuinely replaced.
            if !isempty(new_name) && !isempty(old_name) && lowercase(new_name) != lowercase(old_name) && !isnan(old_leader) && isfinite(old_leader)
                promoted = Dict{String,Any}(string(k) => (v isa AbstractVector ? copy(v) : v) for (k, v) in pairs(c))
                promoted["Role"]   = C.ROLE_FIX
                promoted["Levels"] = Float64[0.0, old_leader, 0.0]
                promoted["L1"]     = 0.0
                promoted["L2"]     = old_leader
                promoted["L3"]     = 0.0
                for stale_k in ("EffectiveLeader", "OldLevels", "ASTMWarning", "IsReplaced", "IsScaled", "ReplaceReady", "Min", "Max", "Alpha", "Beta")
                    delete!(promoted, stale_k)
                end
                push!(promoted_fixed, promoted)
            end

            c["IsReplaced"] = true; c["ReplaceReady"] = !isempty(new_name) && isfinite(nl1) && isfinite(nl2) && isfinite(nl3)
            for stale_k in ("EffectiveLeader", "OldLevels", "ASTMWarning", "IsScaled")
                delete!(c, stale_k)
            end
            c["Alpha"] = 1.0
            c["Beta"]  = 0.0

            if !isempty(new_name)
                c["Name"] = new_name
                new_u = string(get(sl, "NewUnit", ""))
                c["Unit"] = (isempty(new_u) || new_u == "-") ? "" : new_u
                # Prevent old factor MW/radiochemical metadata leaking into the replacement variable.
                c["MW"] = get(fixed_mw_lookup, lowercase(new_name), 0.0)
                c["IsRadioactive"] = false
                c["HalfLife"] = 0.0
                c["HalfLifeUnit"] = "Hours"
            end

            if !isnan(nl1) && !isnan(nl2) && !isnan(nl3)
                c["Levels"] = [nl1, nl2, nl3]
            end
            if haskey(sl, "NewMin")
                c["Min"] = Float64(FAST_SafeNum_DDEF(sl["NewMin"]))
            else
                delete!(c, "Min")
            end
            if haskey(sl, "NewMax")
                c["Max"] = Float64(FAST_SafeNum_DDEF(sl["NewMax"]))
            else
                delete!(c, "Max")
            end

            if vi <= length(leader_vals)
                leader_vals[vi] = if !isnan(nl2)
                    Float64(nl2)
                elseif !isnan(nl1) && !isnan(nl3)
                    0.5 * Float64(nl1 + nl3)
                else
                    Float64(FAST_SafeNum_DDEF(get(c, "L2", 0.0)))
                end
            end

        elseif mode == "SCALE"
            new_s_name = strip(string(get(sl, "NewName", "")))
            !isempty(new_s_name) && (c["Name"] = new_s_name)
            new_u = string(get(sl, "NewUnit", ""))
            !isempty(new_u) && (c["Unit"] = new_u)

            alpha_val = let v = FAST_SafeNum_DDEF(get(sl, "Alpha", 1.0)); isfinite(v) ? Float64(v) : 1.0 end
            beta_val  = let v = FAST_SafeNum_DDEF(get(sl, "Beta",  0.0)); isfinite(v) ? Float64(v) : 0.0 end
            lead_val  = vi <= length(leader_vals) ? Float64(leader_vals[vi]) : Float64(get(c, "L2", 0.0))
            tv        = FLOW_ApplyASTM_DDEF(lead_val, alpha_val, beta_val)
            min_lim, max_lim = FLOW_ResolvePhysicalBounds_DDEF(
                haskey(sl, "NewMin") ? sl["NewMin"] : get(c, "Min", -Inf),
                haskey(sl, "NewMax") ? sl["NewMax"] : get(c, "Max", Inf)
            )
            ok_astm, tv, astm_msg = FLOW_ValidateASTM_DDEF(tv, min_lim, max_lim)
            !ok_astm && !isempty(astm_msg) && (c["ASTMWarning"] = astm_msg)

            old_vars = [o for o in old_conf if get(o, "Role", "") == C.ROLE_VAR]
            lvls = if vi <= length(old_vars) && haskey(old_vars[vi], "Levels")
                Float64.(old_vars[vi]["Levels"])
            elseif haskey(c, "OldLevels")
                Float64.(c["OldLevels"])
            else
                Float64.(get(c, "Levels", [0.0, 0.0, 0.0]))
            end

            # Map source levels into target ASTM space before ACTA so Alpha=1.0 prevents double scaling.
            eff_lvls = (alpha_val != 1.0 || beta_val != 0.0) ?
                Float64[FLOW_ApplyASTM_DDEF(x, alpha_val, beta_val) for x in lvls] : copy(lvls)
            sort!(eff_lvls)

            c["OldLevels"] = FLOW_RoundLevelTriplet_DDEF(eff_lvls)
            c["Levels"]    = FLOW_CalcACTA_DDEF(tv, eff_lvls, Contraction; MinLimit=min_lim, MaxLimit=max_lim, Alpha=1.0)
            isfinite(min_lim) ? (c["Min"] = min_lim) : delete!(c, "Min")
            isfinite(max_lim) ? (c["Max"] = max_lim) : delete!(c, "Max")
            c["Alpha"]     = 1.0
            c["Beta"]      = 0.0
            c["IsScaled"]  = true
            c["EffectiveLeader"] = round(tv; digits=C.PREC_DATA)
            if vi <= length(leader_vals)
                leader_vals[vi] = tv
            end
        else
            haskey(sl, "NewMin") && (c["Min"] = Float64(FAST_SafeNum_DDEF(sl["NewMin"])))
            haskey(sl, "NewMax") && (c["Max"] = Float64(FAST_SafeNum_DDEF(sl["NewMax"])))
        end

        if haskey(c, "Levels") && c["Levels"] isa AbstractVector && length(c["Levels"]) >= 3
            c["L1"] = Float64(c["Levels"][1])
            c["L2"] = Float64(c["Levels"][2])
            c["L3"] = Float64(c["Levels"][3])
        end
    end

    active_var_keys = Set(
        lowercase(strip(string(get(c, "Name", ""))))
        for c in conf
        if get(c, "Role", "") == C.ROLE_VAR && !isempty(strip(string(get(c, "Name", ""))))
    )
    filter!(c -> !(lowercase(strip(string(get(c, "Role", "")))) in ("fixed", "fix") &&
                   lowercase(strip(string(get(c, "Name", "")))) in active_var_keys), conf)

    existing_fix_keys = Set(
        lowercase(strip(string(get(c, "Name", ""))))
        for c in conf
        if lowercase(strip(string(get(c, "Role", "")))) in ("fixed", "fix") && !isempty(strip(string(get(c, "Name", ""))))
    )
    for pf in promoted_fixed
        pf_key = lowercase(strip(string(get(pf, "Name", ""))))
        if !(pf_key in active_var_keys) && !(pf_key in existing_fix_keys)
            push!(conf, pf)
            push!(existing_fix_keys, pf_key)
        end
    end
    return conf
end

"""
    FLOW_CustomisePhaseSpace_DDEF(Proposal::AbstractDict, Slots::AbstractVector; Excluded::AbstractVector=String[]) -> Dict{String,Any}
Compute customised phase evolution space, stoichiometry audit, filler balance, boundary modes, and proximity alerts.
"""
function FLOW_CustomisePhaseSpace_DDEF(Proposal::AbstractDict, Slots::AbstractVector; Excluded::AbstractVector=String[])::Dict{String,Any}
    new_conf      = FAST_SafeGet_DDEF(Proposal, "NewConfig", [])
    old_conf      = FAST_SafeGet_DDEF(Proposal, "OldConfig", new_conf)
    raw_lv        = FAST_SafeGet_DDEF(Proposal, "LeaderValues", Float64[])
    leader_vals   = Float64[FAST_SafeNum_DDEF(x) for x in raw_lv]
    header_info   = FAST_SafeGet_DDEF(Proposal, "Global", Dict())
    vol           = Float64(FAST_SafeNum_DDEF(FAST_SafeGet_DDEF(header_info, "Volume", 0.0)))
    conc          = Float64(FAST_SafeNum_DDEF(FAST_SafeGet_DDEF(header_info, "Conc", 0.0)))
    contraction_f = Float64(FAST_SafeNum_DDEF(FAST_SafeGet_DDEF(Proposal, "SelectedContraction", 0.5)))

    display_conf = [Dict{String,Any}(string(k) => (v isa AbstractVector ? copy(v) : v) for (k, v) in pairs(c)) for c in new_conf]
    FLOW_ApplySlotCustomisation_DDEF!(display_conf, Slots, leader_vals, contraction_f, old_conf)

    excluded_set = Set(String[string(x) for x in Excluded])
    active_conf = filter(c -> !(lowercase(strip(string(FAST_SafeGet_DDEF(c, "Role", "")))) in ("fixed", "fix") &&
                                string(FAST_SafeGet_DDEF(c, "Name", "")) in excluded_set), display_conf)
    active_vars = filter(c -> get(c, "Role", "") == C.ROLE_VAR, active_conf)

    audit_rows = [Dict(
        "Name" => string(get(c, "Name", "Unknown")),
        "Role" => string(get(c, "Role", "Fixed")),
        "L1"   => Float64(get(c, "Levels", [0.0, 0.0, 0.0])[1]),
        "L2"   => Float64(get(c, "Levels", [0.0, 0.0, 0.0])[2]),
        "L3"   => Float64(get(c, "Levels", [0.0, 0.0, 0.0])[3]),
        "MW"   => Float64(get(c, "MW", 0.0)),
        "Unit" => string(get(c, "Unit", "-"))
    ) for c in active_conf]

    audit_ok, audit_report, audit_results, _, _ = MOLE_AuditQuick_DDEF(audit_rows, vol, conc)
    if !isempty(audit_results)
        for c in active_conf
            get(c, "Role", "") != C.ROLE_FILL && continue
            m_idx = findfirst(==(get(c, "Name", "")), audit_results.Component)
            !isnothing(m_idx) && (c["Levels"] = [0.0, audit_results[m_idx, :TARGET_MASS_mg], 0.0])
        end
    end

    var_modes   = FLOW_AbstractBoundaryMode_DDET[]
    live_alerts = String[]
    for (k, c_var) in enumerate(active_vars)
        if get(c_var, "IsReplaced", false) == true
            push!(var_modes, FLOW_ModeReplaced_DDES())
            continue
        end
        lvls      = Float64.(get(c_var, "Levels", [0.0, 0.0, 0.0]))
        val       = (k <= length(leader_vals)) ? Float64(leader_vals[k]) : Float64(lvls[2])
        min_lim, max_lim = FLOW_ResolvePhysicalBounds_DDEF(get(c_var, "Min", -Inf), get(c_var, "Max", Inf))
        ref_lvls  = haskey(c_var, "OldLevels") ? Float64.(c_var["OldLevels"]) : lvls
        cand_span = max(lvls[3] - lvls[1], 1e-9)
        b_stat    = FLOW_ClassifyBoundaryMode_DDEF(val, ref_lvls[1], ref_lvls[3], min_lim, max_lim; TargetSpan=cand_span, Alpha=1.0)
        push!(var_modes, b_stat)
        ok, msg = FLOW_CheckBoundaryAlert_DDEF(b_stat)
        !ok && push!(live_alerts, "[$(get(c_var, "Name", "Var $k"))]: " * msg)
        if haskey(c_var, "ASTMWarning") && !isempty(c_var["ASTMWarning"])
            push!(live_alerts, "[$(get(c_var, "Name", "Var $k")) ASTM]: " * c_var["ASTMWarning"])
        end
    end

    has_slot_override = any(
        uppercase(strip(string(get(s, "Mode", "KEEP")))) != "KEEP" || haskey(s, "NewMin") || haskey(s, "NewMax")
        for s in Slots
    )
    b_alerts = (!isempty(live_alerts) || has_slot_override) ? live_alerts : String[string(a) for a in FAST_SafeGet_DDEF(Proposal, "BoundaryAlerts", String[])]
    fixed_names = String[string(FAST_SafeGet_DDEF(c, "Name", "")) for c in display_conf if lowercase(strip(string(FAST_SafeGet_DDEF(c, "Role", "")))) in ("fixed", "fix")]

    return Dict{String,Any}(
        "DisplayConfig"    => display_conf,
        "ActiveConfig"     => active_conf,
        "OldConfig"        => old_conf,
        "ActiveVars"       => active_vars,
        "FixedNames"       => fixed_names,
        "LeaderValues"     => leader_vals,
        "Volume"           => vol,
        "Conc"             => conc,
        "AuditOK"          => audit_ok,
        "AuditReport"      => audit_report,
        "VarBoundaryModes" => var_modes,
        "BoundaryAlerts"   => b_alerts
    )
end

"""
    FLOW_ImportWorkspaceState_DDEF(Source::Union{AbstractString,AbstractDict}; IsJSON::Bool=false, OverrideRoles::Bool=false, MaxRows::Int=15) -> Dict{String,Any}
Normalise imported JSON protocol templates or Excel master workbooks into workspace state structures.
"""
function FLOW_ImportWorkspaceState_DDEF(Source::Union{AbstractString,AbstractDict};
    IsJSON::Bool=false, OverrideRoles::Bool=false, MaxRows::Int=15)::Dict{String,Any}

    safe_zero(x) = let v = FAST_SafeNum_DDEF(x); isfinite(v) ? v : 0.0 end
    default_row(i::Int) = Dict{String,Any}(
        "Name" => "", "Role" => (i <= 3 ? C.ROLE_VAR : C.ROLE_FIX),
        "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "Levels" => [0.0, 0.0, 0.0],
        "Min" => 0.0, "Max" => 0.0, "MW" => 0.0, "Unit" => "-",
        "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours"
    )
    map_rows(inputs, ov_roles::Bool) = map(enumerate(inputs)) do (i, m)
        role_val = ov_roles ? (i <= 3 ? C.ROLE_VAR : C.ROLE_FIX) : string(FAST_SafeGet_DDEF(m, "Role", i <= 3 ? C.ROLE_VAR : C.ROLE_FIX))
        lvls = FAST_SafeGet_DDEF(m, "Levels", nothing)
        has_lvls = !isnothing(lvls) && lvls isa AbstractVector && length(lvls) >= 3
        l1_v = has_lvls ? safe_zero(lvls[1]) : safe_zero(FAST_SafeGet_DDEF(m, "L1", 0.0))
        l2_v = has_lvls ? safe_zero(lvls[2]) : safe_zero(FAST_SafeGet_DDEF(m, "L2", 0.0))
        l3_v = has_lvls ? safe_zero(lvls[3]) : safe_zero(FAST_SafeGet_DDEF(m, "L3", 0.0))
        Dict{String,Any}(
            "Name" => FAST_SafeGet_DDEF(m, "Name", ""),
            "Role" => role_val,
            "L1" => l1_v, "L2" => l2_v, "L3" => l3_v, "Levels" => [l1_v, l2_v, l3_v],
            "Min" => safe_zero(FAST_SafeGet_DDEF(m, "Min", 0.0)),
            "Max" => safe_zero(FAST_SafeGet_DDEF(m, "Max", 0.0)),
            "MW"  => safe_zero(FAST_SafeGet_DDEF(m, "MW", 0.0)),
            "Unit" => FAST_SafeGet_DDEF(m, "Unit", "-"),
            "IsRadioactive" => FAST_SafeGet_DDEF(m, "IsRadioactive", false),
            "HalfLife" => safe_zero(FAST_SafeGet_DDEF(m, "HalfLife", 0.0)),
            "HalfLifeUnit" => string(FAST_SafeGet_DDEF(m, "HalfLifeUnit", "Hours"))
        )
    end

    if IsJSON || Source isa AbstractDict
        data = if Source isa AbstractDict
            Source
        elseif Source isa AbstractString && isfile(Source)
            FAST_ReadMemoFile_DDEF(Source)
        else
            s = strip(string(Source))
            startswith(s, "{") ? JSON3.read(s) : JSON3.read(String(base64decode(split(s, ",")[end])))
        end
        (isnothing(data) || isempty(data)) && return Dict{String,Any}("Status" => "EMPTY", "HasConfig" => false, "Message" => "Empty JSON configuration.")

        raw_ingreds = FAST_SafeGet_DDEF(data, "Ingredients", FAST_SafeGet_DDEF(data, "Inputs", []))
        filtered_ingreds = filter(itm -> string(FAST_SafeGet_DDEF(itm, "Role", "")) != C.ROLE_FILL, collect(FLOW_IterateEntries_DDEF(raw_ingreds)))
        rows = map_rows(filtered_ingreds, OverrideRoles)
        real_count = 0
        for (i, r) in enumerate(rows)
            !isempty(strip(string(get(r, "Name", "")))) && (real_count = i)
        end
        nc = max(6, real_count)
        while length(rows) < MaxRows
            push!(rows, default_row(length(rows) + 1))
        end

        g = FAST_SafeGet_DDEF(data, "Global", Dict{String,Any}())
        vol_v = FAST_SafeGet_DDEF(g, "Volume", 0.0)
        conc_v = FAST_SafeGet_DDEF(g, "Conc", 0.0)
        stoch = Dict{String,Any}(
            "FillerName" => string(FAST_SafeGet_DDEF(g, "FillerName", "")),
            "FillerMW"   => safe_zero(FAST_SafeGet_DDEF(g, "FillerMW", 0.0)),
            "Volume"     => safe_zero(vol_v),
            "Conc"       => safe_zero(conc_v)
        )
        outs = FAST_SafeGet_DDEF(data, "Outputs", [])
        out_vals = vcat(
            [i <= length(outs) ? FAST_SafeGet_DDEF(outs[i], "Name", "") : "" for i in 1:3],
            [i <= length(outs) ? FAST_SafeGet_DDEF(outs[i], "Unit", "-") : "-" for i in 1:3]
        )
        g_str = FLOW_FormatStringDict_DDEF(g)
        dir_vals = FAST_ExtractDirections_DDEF(g_str, rows)

        return Dict{String,Any}(
            "Status" => "OK", "HasConfig" => true,
            "Rows" => rows[1:MaxRows], "Count" => nc,
            "Volume" => vol_v, "Conc" => conc_v,
            "ProjectName" => string(FAST_SafeGet_DDEF(g, "ProjectName", "")),
            "Method" => string(FAST_SafeGet_DDEF(g, "Method", "")),
            "StochSettings" => stoch, "OutputVals" => out_vals, "DirectionVals" => dir_vals,
            "DetectedPhases" => ["Phase1"], "ActivePhase" => "Phase1"
        )
    else
        is_transient = !(Source isa AbstractString && isfile(Source))
        tmp = is_transient ? FAST_GetTransientPath_DDEF(Source) : String(Source)
        !isfile(tmp) && return Dict{String,Any}("Status" => "FAIL", "HasConfig" => false, "Message" => "Data session stale. Please re-upload.")
        cfg, df_data = try
            FAST_ReadConfig_DDEF(tmp), FAST_ReadExcel_DDEF(tmp, C.SHEET_DATA)
        finally
            is_transient && FAST_CleanTransient_DDEF(tmp)
        end

        (isempty(cfg) || (!haskey(cfg, "Ingredients") && !haskey(cfg, :Ingredients))) &&
            return Dict{String,Any}("Status" => "EMPTY", "HasConfig" => false, "Message" => "No workspace configuration found.")

        g = FAST_SafeGet_DDEF(cfg, "Global", Dict{String,Any}())
        all_ingreds = FAST_SafeGet_DDEF(cfg, "Ingredients", [])
        filtered_ingreds = filter(itm -> string(FAST_SafeGet_DDEF(itm, "Role", "")) != C.ROLE_FILL, collect(FLOW_IterateEntries_DDEF(all_ingreds)))
        rows = map_rows(filtered_ingreds, OverrideRoles)
        real_count = 0
        for (i, r) in enumerate(rows)
            !isempty(strip(string(get(r, "Name", "")))) && (real_count = i)
        end
        nc = max(6, real_count)
        while length(rows) < MaxRows
            push!(rows, default_row(length(rows) + 1))
        end

        detected_phases = String[]
        if !isempty(df_data) && hasproperty(df_data, Symbol(C.COL_PHASE))
            raw_p = filter(!ismissing, unique(df_data[!, Symbol(C.COL_PHASE)]))
            detected_phases = String[string(p) for p in raw_p]
        end
        if isempty(detected_phases)
            ph_h = FAST_SafeGet_DDEF(g, "PhaseHistory", Dict())
            (ph_h isa AbstractDict && !isempty(ph_h)) && (detected_phases = String[string(k) for k in keys(ph_h)])
        end
        isempty(detected_phases) ? (detected_phases = ["Phase1"]) : sort!(detected_phases, by=FAST_ExtractPhaseNumber_DDEF)
        active_ph = detected_phases[end]

        vol_v = FAST_SafeGet_DDEF(g, "Volume", 0.0)
        conc_v = FAST_SafeGet_DDEF(g, "Conc", 0.0)
        stoch = Dict{String,Any}(
            "FillerName" => string(FAST_SafeGet_DDEF(g, "FillerName", "")),
            "FillerMW"   => safe_zero(FAST_SafeGet_DDEF(g, "FillerMW", 0.0)),
            "Volume"     => safe_zero(vol_v),
            "Conc"       => safe_zero(conc_v)
        )
        outs = FAST_SafeGet_DDEF(cfg, "Outputs", [])
        out_vals = vcat(
            [i <= length(outs) ? FAST_SafeGet_DDEF(outs[i], "Name", "") : "" for i in 1:3],
            [i <= length(outs) ? FAST_SafeGet_DDEF(outs[i], "Unit", "-") : "-" for i in 1:3]
        )
        g_str = FLOW_FormatStringDict_DDEF(g)
        dir_vals = FAST_ExtractDirections_DDEF(g_str, filtered_ingreds, active_ph)

        return Dict{String,Any}(
            "Status" => "OK", "HasConfig" => true,
            "Rows" => rows[1:MaxRows], "Count" => nc,
            "Volume" => vol_v, "Conc" => conc_v,
            "ProjectName" => string(FAST_SafeGet_DDEF(g, "ProjectName", "")),
            "Method" => string(FAST_SafeGet_DDEF(g, "Method", "BB15")),
            "StochSettings" => stoch, "OutputVals" => out_vals, "DirectionVals" => dir_vals,
            "DetectedPhases" => detected_phases, "ActivePhase" => active_ph
        )
    end
end

"""
    FLOW_SyncPhaseGoals_DDEF(MasterFile, PhaseName, DesiredModel="Auto"; NameResolver=nothing) -> Dict{String,Any}
Compute phase-level response extrema, REVE aliases, saved LensGoals overlays, and valid model options.
"""
function FLOW_SyncPhaseGoals_DDEF(MasterFile::Union{AbstractString,AbstractDict,Nothing}, PhaseName::AbstractString,
    DesiredModel::AbstractString="Auto"; NameResolver::Union{Function,Nothing}=nothing)::Dict{String,Any}

    is_transient_src = !(MasterFile isa AbstractString && isfile(MasterFile))
    cpath = FLOW_ResolveSource_DDEF(MasterFile)
    try
        !isfile(cpath) && return Dict{String,Any}("Status" => "FAIL", "Message" => "Master workbook not found.")
        df = FAST_ReadExcel_DDEF(cpath, C.SHEET_DATA)
        isempty(df) && (df = FAST_ReadExcel_DDEF(cpath, "DATA_RECORDS"))
        config = FAST_ReadConfig_DDEF(cpath)

        phase_str  = isempty(strip(PhaseName)) ? "Phase1" : strip(string(PhaseName))
        phase_meth = FAST_DetectPhaseMethod_DDEF(config, df, phase_str)
        model_opts, model_val_out = FAST_ResolveModelOptions_DDEF(phase_meth, DesiredModel)

        col_phase = Symbol(C.COL_PHASE)
        sub_df = (hasproperty(df, col_phase) && !isempty(phase_str)) ?
                 filter(r -> !ismissing(r[col_phase]) && string(r[col_phase]) == phase_str, df) : df
        isempty(sub_df) && (sub_df = df)

        out_cols = filter(c -> startswith(c, C.PRE_RESULT), names(df))
        goals_name   = fill("", 3)
        goals_min    = fill(0.0, 3)
        goals_target = fill(0.0, 3)
        goals_max    = fill(0.0, 3)
        goals_type   = fill("Nominal", 3)
        goals_weight = fill("1.00", 3)
        outputs_cfg  = get(config, "Outputs", [])

        resolve_col(col_str) = isnothing(NameResolver) ? FAST_SanitiseHeader_DDEF(col_str) : NameResolver(col_str, C.PRE_RESULT, outputs_cfg)

        for (i, c) in enumerate(out_cols[1:min(length(out_cols), 3)])
            raw_vals = hasproperty(sub_df, Symbol(c)) ? skipmissing(sub_df[!, Symbol(c)]) : skipmissing(df[!, Symbol(c)])
            vals = Float64[Float64(v) for v in raw_vals if v isa Number && !isnan(v)]
            if isempty(vals)
                vals = Float64[Float64(v) for v in skipmissing(df[!, Symbol(c)]) if v isa Number && !isnan(v)]
            end
            mn, mx = isempty(vals) ? (0.0, 0.0) : extrema(vals)
            goals_name[i]   = FAST_FormatDisplayHeader_DDEF(resolve_col(c))
            goals_type[i]   = "Nominal"
            goals_min[i]    = round(mn; digits=C.PREC_DATA)
            goals_max[i]    = round(mx; digits=C.PREC_DATA)
            goals_target[i] = round((mn + mx) / 2; digits=C.PREC_DATA)
        end

        orig_goals_name = copy(goals_name)
        radio_opts = get(config, "RadioOpts", Dict{String,Any}())
        apply_flag = get(radio_opts, "Apply", false)
        rev_dict   = get(radio_opts, "REVE", Dict{String,Any}())
        reve_active = (apply_flag === true) && FAST_IsFlagTrue_DDEF(get(rev_dict, "Enabled", false))
        if reve_active
            for (i, name) in enumerate(orig_goals_name)
                if haskey(rev_dict, name) && (rev_dict[name] isa AbstractDict)
                    mapping = rev_dict[name]
                    alias = get(mapping, "Name", "")
                    unit  = get(mapping, "Unit", "")
                    !isempty(alias) && (goals_name[i] = alias * (isempty(unit) ? "" : " ($unit)"))
                end
            end
        end

        saved_goals = get(config, "LensGoals", [])
        norm_g(s) = uppercase(replace(replace(strip(string(s)), "_" => " "), r"\s+" => " "))
        for (i, name) in enumerate(goals_name)
            g_idx = findfirst(g -> norm_g(FAST_SafeGet_DDEF(g, "Name", "")) == norm_g(name), saved_goals)
            isnothing(g_idx) && (g_idx = findfirst(g -> norm_g(FAST_SafeGet_DDEF(g, "Name", "")) == norm_g(orig_goals_name[i]), saved_goals))
            if isnothing(g_idx) && i <= length(out_cols)
                g_idx = findfirst(g -> norm_g(FAST_SafeGet_DDEF(g, "Name", "")) == norm_g(replace(out_cols[i], C.PRE_RESULT => "")), saved_goals)
            end
            isnothing(g_idx) && i <= length(saved_goals) && (g_idx = i)

            if !isnothing(g_idx)
                saved_g = saved_goals[g_idx]
                goals_type[i]   = string(get(saved_g, "Type", "Nominal"))
                goals_weight[i] = Printf.@sprintf("%.2f", FAST_SafeNum_DDEF(get(saved_g, "Weight", 1.0)))
                goals_target[i] = let v = FAST_SafeNum_DDEF(get(saved_g, "Target", goals_target[i])); isnan(v) ? goals_target[i] : v end
                goals_min[i]    = let v = FAST_SafeNum_DDEF(get(saved_g, "Min",    goals_min[i])); isnan(v) ? goals_min[i] : v end
                goals_max[i]    = let v = FAST_SafeNum_DDEF(get(saved_g, "Max",    goals_max[i])); isnan(v) ? goals_max[i] : v end
            end
        end

        return Dict{String,Any}(
            "Status"       => "OK",
            "GoalsName"    => goals_name,
            "GoalsMin"     => goals_min,
            "GoalsTarget"  => goals_target,
            "GoalsMax"     => goals_max,
            "GoalsType"    => goals_type,
            "GoalsWeight"  => goals_weight,
            "ModelOptions" => model_opts,
            "ModelValue"   => model_val_out
        )
    finally
        is_transient_src && FAST_CleanTransient_DDEF(cpath)
    end
end

"""
    FLOW_WriteLeaders_DDEF(File, Phase, LeadersDF::DataFrame) -> Bool
Write prioritised candidate runs for the specified phase into the master Excel workbook.
Stores evaluated factor combinations and desirability ranks under dedicated leader tracking worksheets.

# Arguments
- `File`: Path to target workbook file.
- `Phase`: Experimental phase identifier.
- `LeadersDF::DataFrame`: Table containing candidate coordinates, predictions, and desirability scores.

# Returns
- `Bool`: `true` if write operation succeeded, `false` otherwise.
"""
function FLOW_WriteLeaders_DDEF(File::Union{AbstractString,Nothing}, Phase::Union{AbstractString,Nothing}, LeadersDF::DataFrame)
    (!FLOW_IsFilled_DDEF(File) || !FLOW_IsFilled_DDEF(Phase)) && return false
    
    is_direct_path = File isa AbstractString && (isfile(File) || endswith(lowercase(strip(File)), ".xlsx") || occursin('/', File) || occursin('\\', File))
    target_file = is_direct_path ? String(strip(File)) : FLOW_ResolveSource_DDEF(File)
    try
        !FLOW_IsFilled_DDEF(target_file) && return false
        sheet_name = C.PREFIX_LEADERS * Phase
        isempty(LeadersDF) && return false
        FAST_WriteExcel_DDEF(target_file, sheet_name, LeadersDF)
        return true
    catch e
        return FAST_HandleCatch_DDEF(FAST_TierLogged_DDES(), e, "FLOW", "IO_ERROR", "WriteLeaders failed", false)
    finally
        !is_direct_path && FAST_CleanTransient_DDEF(target_file)
    end
end

# ------------------------------------------------------------------------------
# SECTION 5: CROSS-PROJECT ASTM TRANSFORMS
# ------------------------------------------------------------------------------

"""
    FLOW_ApplyASTM_DDEF(Val::Real, Alpha::Real, Beta::Real) -> Float64
Apply the Affine Space Transformation Model (ASTM: `y = Alpha * Val + Beta`) to project factor levels across experimental domains.
Performs linear scaling and translation to adapt formulation boundaries when switching equipment, scales, or reactors.

# Arguments
- `Val::Real`: Source factor coordinate.
- `Alpha::Real`: Affine scaling factor.
- `Beta::Real`: Affine translation offset.

# Returns
- `Float64`: Transformed coordinate value.
"""
function FLOW_ApplyASTM_DDEF(Val::Real, Alpha::Real, Beta::Real)::Float64
    return Float64(Alpha * Val + Beta)
end

"""
    FLOW_ValidateASTM_DDEF(Val::Real, MinLimit::Real, MaxLimit::Real) -> Tuple{Bool, Float64, String}
Validate and preserve an ASTM-transformed value within physical experimental bounds.
Prevents projected factor levels from violating laboratory operating limits or reagent solubility thresholds.

# Arguments
- `Val::Real`: Transformed coordinate value.
- `MinLimit::Real`: Minimum admissible physical threshold.
- `MaxLimit::Real`: Maximum admissible physical threshold.

# Returns
- `Tuple{Bool, Float64, String}`: `(is_valid, aligned_value, warning_message)`.
"""
function FLOW_ValidateASTM_DDEF(Val::Real, MinLimit::Real, MaxLimit::Real)::Tuple{Bool,Float64,String}
    min_f = Float64(MinLimit)
    max_f = Float64(MaxLimit)
    val_f = Float64(Val)

    if !isfinite(min_f) && !isfinite(max_f)
        return (true, val_f, "")
    end
    if isfinite(min_f) && isfinite(max_f) && min_f >= max_f
        return (false, val_f, "Invalid physical bounds: MinLimit ($min_f) must be strictly less than MaxLimit ($max_f).")
    end

    clamped = clamp(val_f, min_f, max_f)
    if clamped != val_f
        bound_name = (val_f < min_f) ? "LOWER" : "UPPER"
        bound_val  = (val_f < min_f) ? min_f : max_f
        msg = "Value $(round(val_f; digits=C.PREC_SUMMARY)) exceeds $bound_name bound $(round(bound_val; digits=C.PREC_SUMMARY)). Aligned to limit."
        return (false, clamped, msg)
    end

    return (true, val_f, "")
end

# ------------------------------------------------------------------------------
# SECTION 6: PHASE TRANSITION VISUALISATION
# ------------------------------------------------------------------------------

"""
    FLOW_PushAxialFocus_DDEF!(Traces, Method, Direction, J, XMin, XMax, YPos, VarName) -> Vector{GenericTrace}
Append the DF14 axial focus marker for factor `J`; other designs leave traces untouched.
"""
function FLOW_PushAxialFocus_DDEF!(Traces::Vector{GenericTrace}, ::CORE_MethodDF14_DDES, Direction::AbstractVector,
    J::Int, XMin::Real, XMax::Real, YPos::Real, VarName::AbstractString)
    dir_j    = (J <= length(Direction)) ? Direction[J] : -1
    tip_x    = (dir_j == -1) ? XMin : XMax
    tip_side = (dir_j == -1) ? "Lower (−1)" : "Upper (+1)"
    push!(Traces, scatter(;
        x=[tip_x], y=[YPos], mode="markers",
        name="DF14 Axial Focus",
        legendgroup="AxialFocus",
        marker=attr(symbol="circle", size=13, color=C.COLOUR_TONCYA, line=attr(color=C.COLOUR_PURWHI, width=2)),
        showlegend=(J == 1),
        hoverinfo="text",
        hovertext="$VarName Axial Focus: $tip_side"
    ))
    return Traces
end

FLOW_PushAxialFocus_DDEF!(Traces::Vector{GenericTrace}, ::CORE_AbstractDesignMethod_DDET, ::AbstractVector,
    ::Int, ::Real, ::Real, ::Real, ::AbstractString) = Traces

"""
    FLOW_RenderIPKT_DDEF(OldConfig::AbstractVector, NewConfig::AbstractVector, LeaderVals::AbstractVector; kwargs...) -> Dict{String, Any}
Generate a Plotly visual representation of search domain shifts (contraction and translation) between successive phases.
Renders relative horizontal bar intervals showing previous boundaries, adapted search ranges, and leader operating points.

# Arguments
- `OldConfig::AbstractVector`: Previous phase factor level configurations.
- `NewConfig::AbstractVector`: Adapted phase factor level configurations.
- `LeaderVals::AbstractVector`: Chosen leader factor coordinates.

# Keywords
- `Method::AbstractString`: Design method for new phase (default: `"TL09"`).
- `Direction::AbstractVector`: Direction vector for directional designs.

# Returns
- `Dict{String, Any}`: Dictionary containing Plotly `"data"` traces and `"layout"` specifications.
"""
function FLOW_RenderIPKT_DDEF(OldConfig::AbstractVector, NewConfig::AbstractVector, LeaderVals::AbstractVector;
    Method::AbstractString="TL09", Direction::AbstractVector=[-1, -1, -1])
    method_type = FLOW_ResolveMethod_DDEF(Method)

    vars = [(i, c) for (i, c) in enumerate(OldConfig) if get(c, "Role", "Variable") == C.ROLE_VAR]
    n_vars = length(vars)

    AXIS_LO = -2.0
    AXIS_HI = 2.0

    traces      = GenericTrace[]
    annotations = Dict{String,Any}[]
    has_leader_legend = false
    new_vars = [c for c in NewConfig if get(c, "Role", "Variable") == C.ROLE_VAR]

    y_nms       = [j <= length(new_vars) ? get(new_vars[j], "Name", "Var$j") : get(c, "Name", "Var$j") for (j, (i, c)) in enumerate(vars)]

    for (j, (i, conf)) in enumerate(vars)
        L_Old = Float64.(get(conf, "Levels", [0.0, 0.0, 0.0]))
        L_New = j <= length(new_vars) ? Float64.(get(new_vars[j], "Levels", L_Old)) : L_Old

        y_pos = n_vars - j + 1

        old_vname = string(get(conf, "Name", "Var$j"))
        new_vname = j <= length(new_vars) ? string(get(new_vars[j], "Name", old_vname)) : old_vname
        is_replaced = (old_vname != new_vname) || (j <= length(new_vars) && get(new_vars[j], "IsReplaced", false) == true)

        target_conf = j <= length(new_vars) ? new_vars[j] : conf
        Val = if haskey(target_conf, "EffectiveLeader")
            Float64(FAST_SafeNum_DDEF(target_conf["EffectiveLeader"]))
        elseif j <= length(LeaderVals)
            Float64(LeaderVals[j])
        else
            L_Old[2]
        end
        α = haskey(target_conf, "Alpha") ? Float64(FAST_SafeNum_DDEF(target_conf["Alpha"])) : 1.0
        β = haskey(target_conf, "Beta")  ? Float64(FAST_SafeNum_DDEF(target_conf["Beta"]))  : 0.0
        if !haskey(target_conf, "EffectiveLeader") && (α != 1.0 || β != 0.0)
            Val = FLOW_ApplyASTM_DDEF(Val, α, β)
        end

        min_lim, max_lim = FLOW_ResolvePhysicalBounds_DDEF(get(target_conf, "Min", -Inf), get(target_conf, "Max", Inf))
        Val_eff = clamp(Val, min_lim, max_lim)
        
        # 1. Current Reference Trace
        push!(traces, scatter(; 
            x=[-1.0, 1.0], y=[y_pos, y_pos], mode="lines",
            name="Current", 
            legendgroup="Current",
            line=attr(color=C.COLOUR_DARLOW, width=12),
            showlegend=(j == 1), 
            hoverinfo="skip"
        ))

        ref_old = haskey(target_conf, "OldLevels") ? Float64.(target_conf["OldLevels"]) : (
            (α != 1.0 || β != 0.0) ? Float64[FLOW_ApplyASTM_DDEF(x, α, β) for x in L_Old] : L_Old
        )
        base_mid  = (ref_old[1] + ref_old[3]) / 2.0
        base_span = max(ref_old[3] - ref_old[1], 1e-5)

        # 2. Target Domain & Centre Mapping
        if is_replaced
            n_new_min = -1.0
            n_new_max = 1.0
            span = L_New[3] - L_New[1]
            n_new_mid = (span > 1e-6) ? clamp(((L_New[2] - (L_New[1] + L_New[3]) / 2.0) / (span / 2.0)), -1.0, 1.0) : 0.0
            n_leader  = nothing
            lead_disp = 0.0
        else
            new_span  = max(L_New[3] - L_New[1], 1e-5)
            FLOW_NormaliseValue_DDEF(v) = (v - base_mid) / (base_span / 2.0)
            FLOW_RelativePosition_DDEF(v) = clamp((v - L_New[1]) / new_span, 0.0, 1.0)

            raw_min   = FLOW_NormaliseValue_DDEF(L_New[1])
            raw_mid   = FLOW_NormaliseValue_DDEF(L_New[2])
            raw_max   = FLOW_NormaliseValue_DDEF(L_New[3])
            raw_lead  = FLOW_NormaliseValue_DDEF(Val_eff)
            lead_disp = Val_eff

            # Continuous domain mapping with symmetric boundary locks:
            # - Lower bound floats freely until 1.10 (capped at 1.10 on far right, -1.90 on far left)
            # - Upper bound floats freely until 1.90 (capped at 1.90 on far right, -1.10 on far left)
            n_new_min = clamp(raw_min, -1.90,  1.10)
            n_new_max = clamp(raw_max, -1.10,  1.90)
            vis_width = n_new_max - n_new_min
            n_new_mid = n_new_min + FLOW_RelativePosition_DDEF(L_New[2]) * vis_width
            n_leader  = n_new_min + FLOW_RelativePosition_DDEF(Val_eff)   * vis_width
        end

        act_tag = if is_replaced
            FLOW_GetActionTag_DDEF(FLOW_ModeReplaced_DDES())
        else
            tgt_span = max(L_New[3] - L_New[1], 1e-5)
            b_mode   = FLOW_ClassifyBoundaryMode_DDEF(Val_eff, ref_old[1], ref_old[3], min_lim, max_lim; TargetSpan=tgt_span, Alpha=1.0)
            FLOW_GetActionTag_DDEF(b_mode)
        end

        push!(traces, scatter(; 
            x=[n_new_min, n_new_max], y=[y_pos, y_pos], mode="lines",
            name="Target", 
            legendgroup="Target",
            line=attr(color=C.COLOUR_HUEYEL, width=12),
            showlegend=(j == 1), 
            hoverinfo="text",
            hovertext="$new_vname [$act_tag] Target: $(round(L_New[1]; digits=C.PREC_DATA)) → $(round(L_New[3]; digits=C.PREC_DATA))"
        ))

        push!(traces, scatter(; 
            x=[n_new_mid], y=[y_pos], mode="markers", 
            name="Target Centre",
            legendgroup="Target", 
            marker=attr(symbol="circle", size=12, color=C.COLOUR_TONGRE, line=attr(color=C.COLOUR_PURWHI, width=2)),
            showlegend=false,
            hoverinfo="text",
            hovertext="$new_vname Centre: $(round(L_New[2]; digits=C.PREC_DATA))"
        ))

        FLOW_PushAxialFocus_DDEF!(traces, method_type, Direction, j, n_new_min, n_new_max, y_pos, new_vname)

        # 3. Leader Marker
        if !is_replaced && !isnothing(n_leader)
            lead_label = "Leader: $(round(lead_disp; digits=C.PREC_DATA))"
            push!(traces, scatter(; 
                x=[n_leader], y=[y_pos], mode="markers", 
                name="Leader",
                legendgroup="Leader",
                marker=attr(
                    symbol="circle", size=12, color=C.COLOUR_SHAMAG,
                    line=attr(color=C.COLOUR_PURWHI, width=2)
                ),
                showlegend=(!has_leader_legend),
                hoverinfo="text",
                hovertext=lead_label
            ))
            has_leader_legend = true
        end

        # Annotations (Top = Baseline, Bottom = Target)
        y_ann_top = y_pos + 0.35
        y_ann_bot = y_pos - 0.35
        push!(annotations, Dict(
            "x" => -1.0, "y" => y_ann_top, "xref" => "x", "yref" => "y",
            "text" => is_replaced ? "—" : string(round(ref_old[1]; digits=C.PREC_DATA)),
            "showarrow" => false, "xanchor" => "center",
            "font" => Dict("size" => 8, "color" => C.COLOUR_DARLOW),
        ))
        push!(annotations, Dict(
            "x" => 1.0, "y" => y_ann_top, "xref" => "x", "yref" => "y",
            "text" => is_replaced ? "—" : string(round(ref_old[3]; digits=C.PREC_DATA)),
            "showarrow" => false, "xanchor" => "center",
            "font" => Dict("size" => 8, "color" => C.COLOUR_DARLOW),
        ))
        push!(annotations, Dict(
            "x" => n_new_min, "y" => y_ann_bot, "xref" => "x", "yref" => "y",
            "text" => string(round(L_New[1]; digits=C.PREC_DATA)),
            "showarrow" => false, "xanchor" => "center",
            "font" => Dict("size" => 8, "color" => C.COLOUR_DARHIG),
        ))
        push!(annotations, Dict(
            "x" => n_new_max, "y" => y_ann_bot, "xref" => "x", "yref" => "y",
            "text" => string(round(L_New[3]; digits=C.PREC_DATA)),
            "showarrow" => false, "xanchor" => "center",
            "font" => Dict("size" => 8, "color" => C.COLOUR_DARHIG),
        ))
    end

    ticks_vals = collect(AXIS_LO:0.5:AXIS_HI)
    ticks_text = [v == 0 ? "0" : (v == AXIS_LO ? "-L" : (v == AXIS_HI ? "+L" : Printf.@sprintf("%+.1f", v))) for v in ticks_vals]

    y_tick_vals = collect(n_vars:-1:1)

    layout = Layout(;
        height         = min(120 + n_vars * 50, 280),
        margin         = attr(l=120, r=40, t=10, b=40),
        plot_bgcolor   = C.COLOUR_PURWHI,
        paper_bgcolor  = "rgba(0,0,0,0)",
        xaxis = attr(
            title      = attr(text="", font=attr(size=10, color=C.COLOUR_DARHIG)),
            gridcolor  = C.COLOUR_LIGHIG, 
            zeroline   = false,
            autorange  = false, 
            range      = [AXIS_LO - 0.05, AXIS_HI + 0.05],
            tickvals   = ticks_vals, 
            ticktext   = ticks_text,
            tickfont   = attr(size=9)
        ),
        yaxis = attr(
            tickvals   = y_tick_vals, 
            ticktext   = y_nms, 
            showgrid   = false,
            zeroline   = false, 
            fixedrange = true,
            tickfont   = attr(size=10, color=C.COLOUR_DARHIG, weight="bold")
        ),
        legend      = attr(orientation="h", y=-0.4, x=0.5, xanchor="center", font=attr(size=9)),
        annotations = annotations,
        shapes      = [
            attr(type="line", x0=AXIS_LO, x1=AXIS_LO, y0=0, y1=1, yref="paper", line=attr(color=C.COLOUR_HUERED, width=1.5, dash="dash")),
            attr(type="line", x0=AXIS_HI, x1=AXIS_HI, y0=0, y1=1, yref="paper", line=attr(color=C.COLOUR_HUERED, width=1.5, dash="dash"))
        ]
    )

    if isempty(traces)
        push!(traces, scatter(x=[0], y=[1], text=["Visualisation engine standby."], mode="text"))
    end

    p = Plot(traces, layout)
    
    return Dict(
        "data"   => p.data,
        "layout" => p.layout
    )
end

end