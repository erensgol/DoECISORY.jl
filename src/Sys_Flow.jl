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
    FLOW_ModeTranslateLower_DDES, FLOW_ModeSeekUpper_DDES, FLOW_ModeSeekLower_DDES

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

"""
    FLOW_CheckBoundaryAlert_DDEF(Status) -> Tuple{Bool, String}
Translate a boundary mode trait into its safety flag and user alert.
"""
FLOW_CheckBoundaryAlert_DDEF(::FLOW_ModeContract_DDES)       = (true,  "Optimal candidate point near centre. Search range contracted for finer precision scan.")
FLOW_CheckBoundaryAlert_DDEF(::FLOW_ModeTranslateLower_DDES) = (false, "Optimal candidate point approaching lower boundary. Adaptive translation engaged: search window shifted outward.")
FLOW_CheckBoundaryAlert_DDEF(::FLOW_ModeTranslateUpper_DDES) = (false, "Optimal candidate point approaching upper boundary. Adaptive translation engaged: search window shifted outward.")
FLOW_CheckBoundaryAlert_DDEF(::FLOW_ModeSeekLower_DDES)      = (false, "Optimal candidate point at lower limit. Boundary seeking engaged: minimum span locked at 10% of domain range.")
FLOW_CheckBoundaryAlert_DDEF(::FLOW_ModeSeekUpper_DDES)      = (false, "Optimal candidate point at upper limit. Boundary seeking engaged: minimum span locked at 10% of domain range.")
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
function FLOW_ClassifyBoundaryMode_DDEF(Val::Real, Min::Real, Max::Real, MinLimit::Real=-Inf, MaxLimit::Real=Inf, ContractionOrSpan::Real=0.5; Alpha::Real=1.0)::FLOW_AbstractBoundaryMode_DDET
    val = Float64(Val)
    span_source = Float64(Max - Min)
    (span_source <= 1e-9) && (span_source = 1.0)

    α = Float64(Alpha)
    span_target = (α != 1.0) ? α * span_source : span_source

    c_arg = Float64(ContractionOrSpan)
    c_ratio = (c_arg > 1.0) ? clamp(c_arg / span_target, 0.05, 1.0) : clamp(c_arg, 0.05, 1.0)
    c_span = c_ratio * span_target

    has_max_limit = isfinite(MaxLimit) && (Float64(MaxLimit) > 0.0 || (isfinite(MinLimit) && Float64(MaxLimit) > Float64(MinLimit)))
    has_min_limit = isfinite(MinLimit)
    max_lim = has_max_limit ? Float64(MaxLimit) : Inf
    min_lim = has_min_limit ? Float64(MinLimit) : -Inf

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
    status = FLOW_ClassifyBoundaryMode_DDEF(LeaderVal, CurrentRange[1], CurrentRange[3], MinLimit, MaxLimit, TargetSpan; Alpha=Alpha)
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
    
    target_file = FLOW_ResolveSource_DDEF(MasterFile)
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
                        Float64[FAST_SafeNum_DDEF(x) for x in d["Levels"]]
                    elseif all(k -> haskey(d, k), ("L1", "L2", "L3"))
                        Float64[FAST_SafeNum_DDEF(d[k]) for k in ("L1", "L2", "L3")]
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

        catch e
            FAST_Log_DDEF("FLOW", "STATE_RESTORE", "JSON configuration sync failed: $e", "FAIL")
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
        val  = (j <= length(Leader["Vals"])) ? Float64(Leader["Vals"][j]) : Float64(lvls[2])
        min_lim = haskey(conf, "Min") ? Float64(FAST_SafeNum_DDEF(conf["Min"])) : -Inf
        max_lim = haskey(conf, "Max") ? Float64(FAST_SafeNum_DDEF(conf["Max"])) : Inf

        α = haskey(conf, "Alpha") ? Float64(FAST_SafeNum_DDEF(conf["Alpha"])) : 1.0
        β = haskey(conf, "Beta")  ? Float64(FAST_SafeNum_DDEF(conf["Beta"]))  : 0.0
        eff_val = (α != 1.0 || β != 0.0) ? FLOW_ApplyASTM_DDEF(val, α, β) : val
        eff_lvls = (α != 1.0 || β != 0.0) ? Float64[FLOW_ApplyASTM_DDEF(x, α, β) for x in lvls] : Float64.(lvls)
        if α != 1.0 || β != 0.0
            _, eff_val, _ = FLOW_ValidateASTM_DDEF(eff_val, min_lim, max_lim)
        end
        sort!(eff_lvls)

        rng = eff_lvls[3] - eff_lvls[1]
        (rng <= 1e-9) && (rng = 1.0)
        target_span = rng * Float64(ContractionFactor)

        ok, msg = FLOW_AuditLeader_DDEF(eff_val, lvls, min_lim, max_lim, target_span; Alpha=α)
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
        "LeaderValues" => collect(get(Leader, "Vals", Float64[])),
        "LeaderScore"  => get(Leader, "Score", 0.0),
        "Outputs"        => Outputs,
        "Global"         => GlobalInfo,
        "BoundaryAlerts" => alerts
    )
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
    target_file = FLOW_ResolveSource_DDEF(MasterFile)
    !FLOW_IsValidFile_DDEF(target_file) && return Dict{String,Any}[]
    !FLOW_IsFilled_DDEF(CurrentPhase) && return Dict{String,Any}[]
    
    df = FAST_ReadExcel_DDEF(target_file, C.PREFIX_LEADERS * CurrentPhase)
    isempty(df) && return Dict{String,Any}[]

    candidates = map(eachrow(df)) do row
        d          = Dict{String,Any}(string(k) => v for (k, v) in pairs(row))
        lookup     = Dict(uppercase(string(k)) => v for (k, v) in pairs(row))
        d["Score"] = FAST_SafeNum_DDEF(get(lookup, "SCORE", 0.0))
        return d
    end

    return sort!(candidates; by=x -> x["Score"], rev=true, alg=Base.Sort.MergeSort)
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
    span_target = (α != 1.0) ? α * span_source : span_source
    c_ratio = clamp(Float64(Contraction), 0.05, 1.0)
    span = c_ratio * span_target
    val = Float64(Val)
    half_span = 0.5 * span
    l1 = val - half_span
    l2 = val
    l3 = val + half_span
    if isfinite(MinLimit) && l1 < Float64(MinLimit)
        l1 = Float64(MinLimit)
    end
    if isfinite(MaxLimit) && (Float64(MaxLimit) > 0.0 || (isfinite(MinLimit) && Float64(MaxLimit) > Float64(MinLimit))) && l3 > Float64(MaxLimit)
        l3 = Float64(MaxLimit)
    end
    return Float64[l1, l2, l3]
end

function FLOW_ExecuteACTA_DDEF(::FLOW_ModeTranslateUpper_DDES, Val::Real, L_Old::AbstractVector{<:Real}, Contraction::Real=0.5, MinLimit::Real=-Inf, MaxLimit::Real=Inf; Alpha::Real=1.0)::Vector{Float64}
    span_source = Float64(L_Old[3] - L_Old[1])
    (span_source <= 1e-9) && (span_source = 1.0)
    α = Float64(Alpha)
    span_target = (α != 1.0) ? α * span_source : span_source
    c_ratio = clamp(Float64(Contraction), 0.05, 1.0)
    val = Float64(Val)

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
    if isfinite(MinLimit) && l1 < Float64(MinLimit)
        l1 = Float64(MinLimit)
    end
    if isfinite(MaxLimit) && (Float64(MaxLimit) > 0.0 || (isfinite(MinLimit) && Float64(MaxLimit) > Float64(MinLimit))) && l3 > Float64(MaxLimit)
        l3 = Float64(MaxLimit)
    end
    return Float64[l1, l2, l3]
end

function FLOW_ExecuteACTA_DDEF(::FLOW_ModeTranslateLower_DDES, Val::Real, L_Old::AbstractVector{<:Real}, Contraction::Real=0.5, MinLimit::Real=-Inf, MaxLimit::Real=Inf; Alpha::Real=1.0)::Vector{Float64}
    span_source = Float64(L_Old[3] - L_Old[1])
    (span_source <= 1e-9) && (span_source = 1.0)
    α = Float64(Alpha)
    span_target = (α != 1.0) ? α * span_source : span_source
    c_ratio = clamp(Float64(Contraction), 0.05, 1.0)
    val = Float64(Val)

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
    if isfinite(MinLimit) && l1 < Float64(MinLimit)
        l1 = Float64(MinLimit)
    end
    if isfinite(MaxLimit) && (Float64(MaxLimit) > 0.0 || (isfinite(MinLimit) && Float64(MaxLimit) > Float64(MinLimit))) && l3 > Float64(MaxLimit)
        l3 = Float64(MaxLimit)
    end
    return Float64[l1, l2, l3]
end

function FLOW_ExecuteACTA_DDEF(::FLOW_ModeSeekUpper_DDES, Val::Real, L_Old::AbstractVector{<:Real}, Contraction::Real=0.5, MinLimit::Real=-Inf, MaxLimit::Real=Inf; Alpha::Real=1.0)::Vector{Float64}
    span_source = Float64(L_Old[3] - L_Old[1])
    (span_source <= 1e-9) && (span_source = 1.0)
    α = Float64(Alpha)
    span_target = (α != 1.0) ? α * span_source : span_source
    max_lim = isfinite(MaxLimit) ? Float64(MaxLimit) : Float64(L_Old[3])
    val = Float64(Val)
    d = max_lim - val
    span_min = 0.10 * span_target

    if 2.0 * d >= span_min && val < max_lim
        l3 = max_lim
        l2 = val
        l1 = val - d
        return Float64[l1, l2, l3]
    else
        l3 = max_lim
        l1 = max_lim - span_min
        if isfinite(MinLimit) && l1 < Float64(MinLimit)
            l1 = Float64(MinLimit)
        end
        l2 = (l1 + l3) * 0.5
        return Float64[l1, l2, l3]
    end
end

function FLOW_ExecuteACTA_DDEF(::FLOW_ModeSeekLower_DDES, Val::Real, L_Old::AbstractVector{<:Real}, Contraction::Real=0.5, MinLimit::Real=-Inf, MaxLimit::Real=Inf; Alpha::Real=1.0)::Vector{Float64}
    span_source = Float64(L_Old[3] - L_Old[1])
    (span_source <= 1e-9) && (span_source = 1.0)
    α = Float64(Alpha)
    span_target = (α != 1.0) ? α * span_source : span_source
    min_lim = isfinite(MinLimit) ? Float64(MinLimit) : Float64(L_Old[1])
    val = Float64(Val)
    d = val - min_lim
    span_min = 0.10 * span_target

    if 2.0 * d >= span_min && val > min_lim
        l1 = min_lim
        l2 = val
        l3 = val + d
        return Float64[l1, l2, l3]
    else
        l1 = min_lim
        l3 = min_lim + span_min
        if isfinite(MaxLimit) && (Float64(MaxLimit) > 0.0 || (isfinite(MinLimit) && Float64(MaxLimit) > Float64(MinLimit))) && l3 > Float64(MaxLimit)
            l3 = Float64(MaxLimit)
        end
        l2 = (l1 + l3) * 0.5
        return Float64[l1, l2, l3]
    end
end

FLOW_ExecuteACTA_DDEF(::FLOW_AbstractBoundaryMode_DDET, Val::Real, L_Old::AbstractVector{<:Real}, Contraction::Real=0.5, MinLimit::Real=-Inf, MaxLimit::Real=Inf; Alpha::Real=1.0)::Vector{Float64} =
    FLOW_ExecuteACTA_DDEF(FLOW_ModeContract_DDES(), Val, L_Old, Contraction, MinLimit, MaxLimit; Alpha=Alpha)

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
    span_target = (α != 1.0) ? α * span_source : span_source
    c_ratio = clamp(Float64(Contraction), 0.05, 1.0)

    if abs(Float64(Translation)) > 1e-9
        trans_offset = Float64(Translation) * (span_target * c_ratio * 0.5)
        val = val + trans_offset
    end

    min_lim = isfinite(MinLimit) ? Float64(MinLimit) : -Inf
    max_lim = (isfinite(MaxLimit) && (Float64(MaxLimit) > 0.0 || (isfinite(MinLimit) && Float64(MaxLimit) > Float64(MinLimit)))) ? Float64(MaxLimit) : Inf

    val_clamped = clamp(val, min_lim, max_lim)

    status = FLOW_ClassifyBoundaryMode_DDEF(val_clamped, L_Old[1], L_Old[3], min_lim, max_lim, c_ratio; Alpha=α)
    return FLOW_ExecuteACTA_DDEF(status, val_clamped, L_Old, c_ratio, min_lim, max_lim; Alpha=α)
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
    arg4::Real,
    arg5::Real;
    Alpha::Real=1.0
)::Vector{Float64}
    if isfinite(arg5) && Float64(arg5) > Float64(arg4) && Float64(arg5) >= Float64(L_Old[end])
        return FLOW_CalcACTA_DDEF(Val, L_Old, Contraction; Translation=0.0, MinLimit=arg4, MaxLimit=arg5, Alpha=Alpha)
    else
        return FLOW_CalcACTA_DDEF(Val, L_Old, Contraction; Translation=arg4, MinLimit=arg5, MaxLimit=Inf, Alpha=Alpha)
    end
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
                df[!, "TIME_FORW_MINS_" * rn] = fill(0.0, n_runs)
                
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
                df[!, "TIME_DCYP_MINS_" * rn] = dcyp_vals
                df[!, "TIME_REVE_MINS_" * rn] = fill(0.0, n_runs)

                act_header = (isempty(ru) || ru == "-") ? "ACTUAL_" * rn : "ACTUAL_" * rn * "_" * ru
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
    
    target_file = FLOW_ResolveSource_DDEF(MasterFile)
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
            c["L3"] = Float64(c["Levels"][3])
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
            Float64[FAST_SafeNum_DDEF(x) for x in conf["Levels"]]
        elseif all(k -> haskey(conf, k), ("L1", "L2", "L3"))
            Float64[FAST_SafeNum_DDEF(conf[k]) for k in ("L1", "L2", "L3")]
        else
            Float64[0.0, 0.0, 0.0]
        end
        Val     = SelVals[j]
        min_lim = haskey(conf, "Min") ? Float64(FAST_SafeNum_DDEF(conf["Min"])) : -Inf
        max_lim = haskey(conf, "Max") ? Float64(FAST_SafeNum_DDEF(conf["Max"])) : Inf

        α       = haskey(conf, "Alpha") ? Float64(FAST_SafeNum_DDEF(conf["Alpha"])) : 1.0
        β       = haskey(conf, "Beta")  ? Float64(FAST_SafeNum_DDEF(conf["Beta"]))  : 0.0
        raw_l_old = copy(L_Old)

        eff_l_old = (α != 1.0 || β != 0.0) ? Float64[FLOW_ApplyASTM_DDEF(x, α, β) for x in raw_l_old] : copy(raw_l_old)
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

        conf["EffectiveLeader"] = Val
        conf["OldLevels"]       = copy(eff_l_old)

        status = FLOW_ClassifyBoundaryMode_DDEF(Val, raw_l_old[1], raw_l_old[3], min_lim, max_lim, ContractionFactor; Alpha=α)
        action = FLOW_GetActionTag_DDEF(status)
        new_levels = FLOW_ExecuteACTA_DDEF(status, Val, raw_l_old, ContractionFactor, min_lim, max_lim; Alpha=α)

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
    
    target_file = (isfile(File) || endswith(lowercase(strip(File)), ".xlsx") || occursin('/', File) || occursin('\\', File)) ? 
                  String(strip(File)) : FLOW_ResolveSource_DDEF(File)
    !FLOW_IsFilled_DDEF(target_file) && return false
    
    sheet_name = C.PREFIX_LEADERS * Phase

    isempty(LeadersDF) && return false

    try
        FAST_WriteExcel_DDEF(target_file, sheet_name, LeadersDF)
        return true
    catch e
        FAST_Log_DDEF("FLOW", "IO_ERROR", "WriteLeaders Failed: $e", "FAIL")
        return false
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
        msg = "Value $(round(val_f; digits=2)) exceeds $bound_name bound $(round(bound_val; digits=2)). Aligned to limit."
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

        min_lim = haskey(target_conf, "Min") ? Float64(FAST_SafeNum_DDEF(target_conf["Min"])) : 0.0
        max_lim = haskey(target_conf, "Max") ? Float64(FAST_SafeNum_DDEF(target_conf["Max"])) : Inf
        Val_eff = Val
        if isfinite(max_lim) && Val_eff > max_lim
            Val_eff = max_lim
        end
        if isfinite(min_lim) && Val_eff < min_lim
            Val_eff = min_lim
        end
        
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

        tgt_span = base_span
        b_mode   = FLOW_ClassifyBoundaryMode_DDEF(Val_eff, L_Old[1], L_Old[3], min_lim, max_lim, tgt_span; Alpha=α)
        act_tag  = FLOW_GetActionTag_DDEF(b_mode)

        push!(traces, scatter(; 
            x=[n_new_min, n_new_max], y=[y_pos, y_pos], mode="lines",
            name="Target", 
            legendgroup="Target",
            line=attr(color=C.COLOUR_HUEYEL, width=12),
            showlegend=(j == 1), 
            hoverinfo="text",
            hovertext="$new_vname [$act_tag] Target: $(round(L_New[1]; digits=2)) → $(round(L_New[3]; digits=2))"
        ))

        push!(traces, scatter(; 
            x=[n_new_mid], y=[y_pos], mode="markers", 
            name="Target Centre",
            legendgroup="Target", 
            marker=attr(symbol="circle", size=12, color=C.COLOUR_TONGRE, line=attr(color=C.COLOUR_PURWHI, width=2)),
            showlegend=false,
            hoverinfo="text",
            hovertext="$new_vname Centre: $(round(L_New[2]; digits=2))"
        ))

        FLOW_PushAxialFocus_DDEF!(traces, method_type, Direction, j, n_new_min, n_new_max, y_pos, new_vname)

        # 3. Leader Marker
        if !is_replaced && !isnothing(n_leader)
            lead_label = "Leader: $(round(lead_disp; digits=2))"
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
            "text" => is_replaced ? "—" : string(round(L_Old[1]; digits=1)),
            "showarrow" => false, "xanchor" => "center",
            "font" => Dict("size" => 8, "color" => C.COLOUR_DARLOW),
        ))
        push!(annotations, Dict(
            "x" => 1.0, "y" => y_ann_top, "xref" => "x", "yref" => "y",
            "text" => is_replaced ? "—" : string(round(L_Old[3]; digits=1)),
            "showarrow" => false, "xanchor" => "center",
            "font" => Dict("size" => 8, "color" => C.COLOUR_DARLOW),
        ))
        push!(annotations, Dict(
            "x" => n_new_min, "y" => y_ann_bot, "xref" => "x", "yref" => "y",
            "text" => string(round(L_New[1]; digits=1)),
            "showarrow" => false, "xanchor" => "center",
            "font" => Dict("size" => 8, "color" => C.COLOUR_DARHIG),
        ))
        push!(annotations, Dict(
            "x" => n_new_max, "y" => y_ann_bot, "xref" => "x", "yref" => "y",
            "text" => string(round(L_New[3]; digits=1)),
            "showarrow" => false, "xanchor" => "center",
            "font" => Dict("size" => 8, "color" => C.COLOUR_DARHIG),
        ))
    end

    ticks_vals = collect(AXIS_LO:0.5:AXIS_HI)
    ticks_text = [v == 0 ? "0" : (v == -1.0 ? "-1.0 (Lower)" : (v == 1.0 ? "+1.0 (Upper)" : (v == AXIS_LO ? "-L" : (v == AXIS_HI ? "+L" : Printf.@sprintf("%+.1f", v))))) for v in ticks_vals]

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