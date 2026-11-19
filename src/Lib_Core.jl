module Lib_Core

# ==============================================================================
# DOECISORY - LIB CORE (CORE MATRICES)
# ==============================================================================
# Description: Module for experimental design generation, coordinate mapping, 
#              and adaptive search algorithms.
# Module Tag:  CORE
# ==============================================================================

using Random
using LinearAlgebra
using Statistics
using Printf
using ..Sys_Fast
using BlackBoxOptim

export CORE_GenDesign_DDEF, CORE_BuildMatrix_DDEF, CORE_MapLevels_DDEF,
       CORE_CodeMatrix_DDEF, CORE_ExpandModelMatrix_DDEF, CORE_CalcDEfficiency_DDEF,
       CORE_CalcDesignMetrics_DDEF, CORE_OptimiseDesirability_DDEF, CORE_CalcDesirability_DDEF,
       CORE_ExtractGoal_DDEF, CORE_ValidateDesign_DDEF, CORE_ExtractLeader_DDEF,
       CORE_ModifierDCYP_DDES, CORE_ApplyDCYP_DDEF, CORE_GetNeighbourWeights_DDEF,
       CORE_StarWeights_DDEC, CORE_GetMethodType_DDEF, CORE_GetModelType_DDEF,
       CORE_AbstractDesignMethod_DDET, CORE_MethodBB15_DDES, CORE_MethodTL09_DDES,
       CORE_MethodCD17_DDES, CORE_MethodDF14_DDES, CORE_MethodMap_DDEC, CORE_DesignBB15_DDEC,
       CORE_AbstractModelType_DDET, CORE_ModelLinear_DDES, CORE_ModelQuadratic_DDES, 
       CORE_ModelMap_DDEC, CORE_AbstractCriterion_DDET, CORE_CriterionD_DDES, CORE_CriterionA_DDES,
       CORE_CriterionG_DDES, CORE_CriterionI_DDES, CORE_CalcCriterion_DDEF
       
# ==============================================================================
# PART A: DESIGN MATRIX & COORDINATE GENERATION
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: DESIGN METHOD & MODEL DISPATCHERS
# ------------------------------------------------------------------------------

const C = FAST_Data_DDEC

abstract type CORE_AbstractDesignMethod_DDET end
struct CORE_MethodBB15_DDES <: CORE_AbstractDesignMethod_DDET end
struct CORE_MethodTL09_DDES <: CORE_AbstractDesignMethod_DDET end
struct CORE_MethodCD17_DDES <: CORE_AbstractDesignMethod_DDET end
struct CORE_MethodDF14_DDES <: CORE_AbstractDesignMethod_DDET end

const CORE_MethodMap_DDEC = Dict{String, CORE_AbstractDesignMethod_DDET}(
    "BB15" => CORE_MethodBB15_DDES(),
    "TL09" => CORE_MethodTL09_DDES(),
    "CD17" => CORE_MethodCD17_DDES(),
    "DF14" => CORE_MethodDF14_DDES()
)

abstract type CORE_AbstractModelType_DDET end
struct CORE_ModelLinear_DDES <: CORE_AbstractModelType_DDET end
struct CORE_ModelQuadratic_DDES <: CORE_AbstractModelType_DDET end

const CORE_ModelMap_DDEC = Dict{String, CORE_AbstractModelType_DDET}(
    "linear"    => CORE_ModelLinear_DDES(),
    "quadratic" => CORE_ModelQuadratic_DDES(),
    "quad"      => CORE_ModelQuadratic_DDES()
)

# ------------------------------------------------------------------------------
# SECTION 2: CONSTANTS - PRE-ALLOCATED DESIGN MATRICES
# ------------------------------------------------------------------------------

const CORE_DesignTL09_DDEC = Int8[
    -1 -1 -1;
    -1  0  0;
    -1  1  1;
     0 -1  0;
     0  0  1;
     0  1 -1;
     1 -1  1;
     1  0 -1;
     1  1  0
]

const CORE_DesignBB15_DDEC = Int8[
     0  0  0;
    -1 -1  0;
     1 -1  0;
    -1  1  0;
     1  1  0;
     0  0  0;
    -1  0 -1;
     1  0 -1;
    -1  0  1;
     1  0  1;
     0  0  0;
     0 -1 -1;
     0  1 -1;
     0 -1  1;
     0  1  1
]

const CORE_DesignCD17_DDEC = Int8[
     0  0  0;
     1 -1 -1;
    -1  1 -1;
    -1 -1  1;
     1  1  1;
     0  0  0;
     1 -1  1;
    -1  1  1;
     1  1 -1;
    -1 -1 -1;
     0  0  0;
    -1  0  0;
     1  0  0;
     0 -1  0;
     0  1  0;
     0  0 -1;
     0  0  1
]

function CORE_DesignDF14_DDEF(direction::AbstractVector=[-1, -1, -1])::Matrix{Int8}
    s1 = Int8(length(direction) >= 1 && direction[1] >= 0 ? 1 : -1)
    s2 = Int8(length(direction) >= 2 && direction[2] >= 0 ? 1 : -1)
    s3 = Int8(length(direction) >= 3 && direction[3] >= 0 ? 1 : -1)
    return Int8[
         0   0   0;
        s1   0   0;
         1  -1  -1;
        -1   1  -1;
         1   1   1;
         0   0   0;
         0  s2   0;
        -1  -1   1;
         1  -1   1;
        -1   1   1;
         0   0   0;
         0   0  s3;
         1   1  -1;
        -1  -1  -1
    ]
end

"""
    CORE_GenDesign_DDEF(Method::AbstractString, FactorCount::Integer=3; Direction=[-1, -1, -1]) -> Matrix{Int8}
Generate a coded (-1, 0, 1) design matrix for a 3-factor response surface topology.
Constructs standard Box-Behnken (BB15), Central Composite (CD17), Taguchi (TL09), or Directional Fractional (DF14) coordinate runs.

# Arguments
- `Method::AbstractString`: Design identifier (`"BB15"`, `"CD17"`, `"TL09"`, or `"DF14"`).
- `FactorCount::Integer`: Number of continuous factors (fixed at 3).

# Keywords
- `Direction::AbstractVector`: Search orientation vector for `"DF14"` design (default: `[-1, -1, -1]`).

# Returns
- `Matrix{Int8}`: Coded coordinate matrix of size `N × 3`.
"""
function CORE_GenDesign_DDEF(Method::AbstractString, FactorCount::Integer=3; Direction::AbstractVector=[-1, -1, -1])
    if FactorCount != 3
        throw(ArgumentError("DoECISORY experimental design methods (BB15, CD17, TL09, DF14) currently support exactly 3 factors (received FactorCount = $FactorCount)."))
    end
    FAST_Log_DDEF("CORE", "DESIGN_GEN", "Generating matrix for $Method (Strict 3-Var Mode)", "WAIT")
    method_type = CORE_GetMethodType_DDEF(Method)
    design = CORE_BuildMatrix_DDEF(method_type, FactorCount, Direction)
    R, C_dim = size(design)
    FAST_Log_DDEF("CORE", "GEN_SUCCESS", "$R Runs x $C_dim Variables created.", "OK")
    return design
end

CORE_GenDesign_DDEF(Method::AbstractString, FactorCount::Integer, Direction::AbstractVector) = 
    CORE_GenDesign_DDEF(Method, FactorCount; Direction=Direction)

function CORE_GetMethodType_DDEF(m::AbstractString)::CORE_AbstractDesignMethod_DDET
    u = uppercase(strip(m))
    haskey(CORE_MethodMap_DDEC, u) && return CORE_MethodMap_DDEC[u]
    throw(ArgumentError("Unknown experimental design method: '$m'. Valid options: TL09, BB15, CD17, DF14."))
end

function CORE_GetModelType_DDEF(m::AbstractString)::CORE_AbstractModelType_DDET
    u = lowercase(strip(m))
    return get(CORE_ModelMap_DDEC, u, CORE_ModelQuadratic_DDES())
end

CORE_GetModelType_DDEF(m::CORE_AbstractModelType_DDET) = m

"""
    CORE_BuildMatrix_DDEF(Method, fc=3, dir=[-1, -1, -1]) -> Matrix{Int8}
Generate the normalised design matrix for the specified experimental method dispatch type or string identifier.
Validates the factor count requirement and dispatches to the corresponding topology constructor.

# Arguments
- `Method`: Design method object or string identifier (`"TL09"`, `"BB15"`, `"CD17"`, `"DF14"`).
- `fc`: Factor count (must be 3 for standard response surface topologies).
- `dir`: Search direction vector for directional designs (e.g. DF14).

# Returns
- A `Matrix{Int8}` containing normalised coordinate points in the domain `[-1, 1]`.
"""
CORE_BuildMatrix_DDEF(::CORE_MethodTL09_DDES, fc::Integer, dir::AbstractVector=[-1, -1, -1]) = 
    fc == 3 ? copy(CORE_DesignTL09_DDEC) : throw(ArgumentError("Method TL09 requires exactly 3 factors (received $fc)."))
CORE_BuildMatrix_DDEF(::CORE_MethodBB15_DDES, fc::Integer, dir::AbstractVector=[-1, -1, -1]) = 
    fc == 3 ? copy(CORE_DesignBB15_DDEC) : throw(ArgumentError("Method BB15 requires exactly 3 factors (received $fc)."))
CORE_BuildMatrix_DDEF(::CORE_MethodCD17_DDES, fc::Integer, dir::AbstractVector=[-1, -1, -1]) = 
    fc == 3 ? copy(CORE_DesignCD17_DDEC) : throw(ArgumentError("Method CD17 requires exactly 3 factors (received $fc)."))
CORE_BuildMatrix_DDEF(::CORE_MethodDF14_DDES, fc::Integer, dir::AbstractVector=[-1, -1, -1]) = 
    fc == 3 ? CORE_DesignDF14_DDEF(dir) : throw(ArgumentError("Method DF14 requires exactly 3 factors (received $fc)."))

CORE_BuildMatrix_DDEF(Method::AbstractString, fc::Integer=3, dir::AbstractVector=[-1, -1, -1]) = 
    CORE_BuildMatrix_DDEF(CORE_GetMethodType_DDEF(Method), fc, dir)

# ------------------------------------------------------------------------------
# SECTION 3: COORDINATE MAPPING (CODED -> PHYSICAL)
# ------------------------------------------------------------------------------

"""
    CORE_MapLevels_DDEF(CodedMatrix::AbstractMatrix, Config::AbstractVector) -> Matrix{Float64}
Map coded coordinates in `[-1.0, 1.0]` to physical engineering units via piecewise linear interpolation.
Interpolates discrete level boundaries to translate dimensionless designs into actual laboratory formulations.

# Arguments
- `CodedMatrix::AbstractMatrix`: Matrix of coded coordinates (`N × 3`).
- `Config::AbstractVector`: Factor configurations containing lower (`L1`), centre (`L2`), and upper (`L3`) physical levels.

# Returns
- `Matrix{Float64}`: Interpolated physical values of size `N × 3`.
"""
function CORE_MapLevels_DDEF(CodedMatrix::AbstractMatrix, Config::AbstractVector)
    rows = size(CodedMatrix, 1)
    cols = size(CodedMatrix, 2)
    length(Config) < cols && throw(ArgumentError("Configuration vector length ($(length(Config))) is insufficient for coded matrix columns ($cols)."))

    result = Matrix{Float64}(undef, rows, cols)
    for i in 1:cols
        cfg_entry = Config[i]
        lvls = isa(cfg_entry, AbstractDict) ? get(cfg_entry, "Levels", zeros(3)) : zeros(3)
        length(lvls) < 3 && (lvls = zeros(3))
        L1, L2, L3 = Float64(lvls[1]), Float64(lvls[2]), Float64(lvls[3])
        for r in 1:rows
            c = Float64(CodedMatrix[r, i])
            result[r, i] = c < 0.0 ? L2 + c * (L2 - L1) : L2 + c * (L3 - L2)
        end
    end
    return result
end

# ==============================================================================
# PART B: ALGORITHMIC OPTIMISERS & DESIRABILITY ENGINE
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 4: MULTI-OBJECTIVE DESIRABILITY & OPTIMISATION
# ------------------------------------------------------------------------------

abstract type CORE_AbstractGoalType_DDET end
struct CORE_GoalMaximise_DDES <: CORE_AbstractGoalType_DDET end
struct CORE_GoalMinimise_DDES <: CORE_AbstractGoalType_DDET end
struct CORE_GoalNominal_DDES  <: CORE_AbstractGoalType_DDET end

const CORE_GoalMap_DDEC = Dict{String, CORE_AbstractGoalType_DDET}(
    "maximise" => CORE_GoalMaximise_DDES(),
    "minimise" => CORE_GoalMinimise_DDES(),
    "nominal"  => CORE_GoalNominal_DDES(),
    "target"   => CORE_GoalNominal_DDES()
)

"""
    CORE_ExtractGoal_DDEF(Goal::AbstractDict) -> Tuple{CORE_AbstractGoalType_DDET, Float64, Float64, Float64, Float64}
Parse and validate response desirability goal parameters into a typed dispatch tuple.
Extracts numerical limits, target thresholds, and exponential importance weights while resolving default midpoints.

# Arguments
- `Goal::AbstractDict`: Dictionary containing `"Type"` (`"Maximise"`, `"Minimise"`, or `"Nominal"`), `"Min"`, `"Max"`, `"Target"`, and `"Weight"`.

# Returns
- `Tuple`: `(Trait, G_Min, G_Max, G_Tgt, Weight)` where `Trait` is a `CORE_AbstractGoalType_DDET`.
"""
function CORE_ExtractGoal_DDEF(Goal::AbstractDict)::Tuple{CORE_AbstractGoalType_DDET, Float64, Float64, Float64, Float64}
    min_raw = FAST_SafeNum_DDEF(get(Goal, "Min", -Inf))
    max_raw = FAST_SafeNum_DDEF(get(Goal, "Max", Inf))
    G_Min = isnan(min_raw) ? -Inf : Float64(min_raw)
    G_Max = isnan(max_raw) ?  Inf : Float64(max_raw)
    tgt_raw = FAST_SafeNum_DDEF(get(Goal, "Target", nothing))
    G_Tgt = if isfinite(tgt_raw)
        Float64(tgt_raw)
    elseif isfinite(G_Min) && isfinite(G_Max)
        (G_Min + G_Max) / 2
    else
        0.0
    end
    Type_Str = lowercase(strip(string(get(Goal, "Type", "Nominal"))))
    w_raw = FAST_SafeNum_DDEF(get(Goal, "Weight", 1.0))
    Weight = isfinite(w_raw) ? max(0.0, Float64(w_raw)) : 1.0
    
    Trait = get(CORE_GoalMap_DDEC, Type_Str, CORE_GoalNominal_DDES())
    return (Trait, G_Min, G_Max, G_Tgt, Weight)
end

CORE_ExtractGoal_DDEF(G::Tuple) = G

"""
    CORE_CalcDesirability_DDEF(Val::Float64, Goal) -> Float64
Calculate the Derringer-Suich individual desirability score in `[0.0, 1.0]` for an evaluated response.
Applies one-sided or two-sided piecewise exponential utility curves based on the assigned optimisation goal.

# Arguments
- `Val::Float64`: Evaluated or predicted response value.
- `Goal`: Goal parameter dictionary or extracted `Tuple` containing type, limits, target, and exponential weight.

# Returns
- `Float64`: Normalised desirability index clamped between `0.0` (unacceptable) and `1.0` (ideal).
"""
function CORE_CalcDesirability_DDEF(Val::Float64, Goal::AbstractDict)::Float64
    return CORE_CalcDesirability_DDEF(Val, CORE_ExtractGoal_DDEF(Goal))
end

function CORE_CalcDesirability_DDEF(Val::Float64, GoalTup::Tuple{CORE_AbstractGoalType_DDET, Float64, Float64, Float64, Float64})::Float64
    !isfinite(Val) && return 0.0
    return CORE_CalcDesirability_DDEF(GoalTup[1], Val, GoalTup[2], GoalTup[3], GoalTup[4], GoalTup[5])
end

function CORE_CalcDesirability_DDEF(::CORE_GoalMaximise_DDES, Val::Float64, G_Min::Float64, G_Max::Float64, G_Tgt::Float64, Weight::Float64)::Float64
    G_Min > G_Max && return 0.0
    Val <= G_Min && return 0.0
    Val >= G_Tgt && return 1.0
    denom = G_Tgt - G_Min
    res = denom > 1e-9 ? ((Val - G_Min) / denom)^Weight : 1.0
    return clamp(res, 0.0, 1.0)
end

function CORE_CalcDesirability_DDEF(::CORE_GoalMinimise_DDES, Val::Float64, G_Min::Float64, G_Max::Float64, G_Tgt::Float64, Weight::Float64)::Float64
    G_Min > G_Max && return 0.0
    Val >= G_Max && return 0.0
    Val <= G_Tgt && return 1.0
    denom = G_Max - G_Tgt
    res = denom > 1e-9 ? ((G_Max - Val) / denom)^Weight : 1.0
    return clamp(res, 0.0, 1.0)
end

function CORE_CalcDesirability_DDEF(::CORE_GoalNominal_DDES, Val::Float64, G_Min::Float64, G_Max::Float64, G_Tgt::Float64, Weight::Float64)::Float64
    G_Min > G_Max && return 0.0
    (Val <= G_Min || Val >= G_Max) && return 0.0
    abs(Val - G_Tgt) < 1e-12 && return 1.0
    if Val < G_Tgt
        denom = G_Tgt - G_Min
        res = denom > 1e-9 ? ((Val - G_Min) / denom)^Weight : 1.0
    else
        denom = G_Max - G_Tgt
        res = denom > 1e-9 ? ((G_Max - Val) / denom)^Weight : 1.0
    end
    return clamp(res, 0.0, 1.0)
end

const CORE_StarWeights_DDEC = Float64[0.50, 0.75, 1.00, 1.50, 2.00]

function CORE_GetNeighbourWeights_DDEF(Weight::Float64)::Tuple{Float64, Float64, Float64}
    best_idx  = 1
    best_diff = abs(CORE_StarWeights_DDEC[1] - Weight)
    @inbounds for i in 2:length(CORE_StarWeights_DDEC)
        diff = abs(CORE_StarWeights_DDEC[i] - Weight)
        if diff < best_diff
            best_diff = diff
            best_idx  = i
        end
    end
    @inbounds begin
        w_minus = CORE_StarWeights_DDEC[max(1, best_idx - 1)]
        w_curr  = CORE_StarWeights_DDEC[best_idx]
        w_plus  = CORE_StarWeights_DDEC[min(5, best_idx + 1)]
        return (w_minus, w_curr, w_plus)
    end
end

# ------------------------------------------------------------------------------
# SECTION 5: DECAY-COUPLED OPTIMISATION MODIFIER
# ------------------------------------------------------------------------------

"""
    CORE_ModifierDCYP_DDES(TimeIndex::Int, Lambda::Float64, IsotopeName::String)
Decay-Corrected Yield Penalty structure for radiochemical multi-objective optimisation.
Stores the reaction time column index and decay constant to penalise desirability as physical time elapses.

# Fields
- `TimeIndex::Int`: Column index of the incubation or reaction duration factor.
- `Lambda::Float64`: Radioactive decay constant in reciprocal time units (`ln(2) / half_life`).
- `IsotopeName::String`: Radionuclide identifier for tracking and reporting.
"""
struct CORE_ModifierDCYP_DDES
    TimeIndex::Int
    Lambda::Float64
    IsotopeName::String
    TimeScaleToMin::Float64
end
CORE_ModifierDCYP_DDES(TimeIndex::Int, Lambda::Float64, IsotopeName::String) =
    CORE_ModifierDCYP_DDES(TimeIndex, Lambda, IsotopeName, 1.0)

"""
    CORE_ApplyDCYP_DDEF(Score::Float64, Mod::CORE_ModifierDCYP_DDES, x) -> Float64
Apply an exponential radio-decay penalty factor `exp(-lambda * t)` to composite desirability.
Resolves the trade-off between chemical reaction completion and radioactive decay loss during formulation.

# Arguments
- `Score::Float64`: Raw composite desirability score in `[0.0, 1.0]`.
- `Mod::CORE_ModifierDCYP_DDES`: Decay modifier specifying time factor index and decay constant.
- `x`: Candidate factor coordinate vector containing the reaction duration.

# Returns
- `Float64`: Decay-penalised desirability score in `[0.0, 1.0]`.
"""
function CORE_ApplyDCYP_DDEF(Score::Float64, Mod::CORE_ModifierDCYP_DDES, x)::Float64
    (Mod.TimeIndex < 1 || Mod.TimeIndex > length(x)) && return Score
    t_val = Float64(x[Mod.TimeIndex]) * Mod.TimeScaleToMin
    t_val <= 0.0 && return Score
    return Score * exp(-Mod.Lambda * t_val)
end

# Dispatch composite scoring onto CORE_CalcDesirability_DDEF so single-point and batch callers share identical StarWeights and DCYP math.
function CORE_CalcDesirability_DDEF(
    Vals::AbstractVector{Float64},
    GoalTuples::AbstractVector{<:Tuple},
    x,
    ModifiersDCYP::AbstractVector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[];
    Weighted::Bool=true,
    NeighbourWeights::Union{AbstractVector{Tuple{Float64, Float64, Float64}}, Nothing}=nothing
)::Float64
    k = length(Vals)
    k == 0 && return 1.0
    inv_k = 1.0 / k
    prod_u = 1.0
    prod_e = 1.0
    @inbounds for j in 1:k
        val = Vals[j]
        !isfinite(val) && return 0.0
        gt = GoalTuples[j]
        b = CORE_CalcDesirability_DDEF(gt[1], val, gt[2], gt[3], gt[4], 1.0)
        b <= 1e-12 && return 0.0
        if Weighted
            w_m, w_c, w_p = isnothing(NeighbourWeights) ? CORE_GetNeighbourWeights_DDEF(gt[5]) : NeighbourWeights[j]
            u = b^(w_c * inv_k)
            e = (b^(w_m * inv_k) + u + b^(w_p * inv_k)) / 3.0
            prod_u *= u
            prod_e *= e
        else
            prod_u *= b^inv_k
        end
    end
    score = Weighted ? clamp(0.50 * prod_u + 0.50 * prod_e, 0.0, 1.0) : clamp(prod_u, 0.0, 1.0)
    if Weighted
        for dm in ModifiersDCYP
            score = CORE_ApplyDCYP_DDEF(score, dm, x)
        end
    end
    return isfinite(score) ? clamp(score, 0.0, 1.0) : 0.0
end

function CORE_CalcDesirability_DDEF(
    Predictions::AbstractMatrix{Float64},
    GoalTuples::AbstractVector{<:Tuple},
    Coords::AbstractMatrix{Float64},
    ModifiersDCYP::AbstractVector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[];
    Weighted::Bool=true
)::Vector{Float64}
    n_pts, k = size(Predictions)
    scores = Vector{Float64}(undef, n_pts)
    k == 0 && (fill!(scores, 1.0); return scores)
    inv_k = 1.0 / k
    n_weights  = Weighted ? [CORE_GetNeighbourWeights_DDEF(gt[5]) for gt in GoalTuples] : Tuple{Float64, Float64, Float64}[]
    Threads.@threads for i in 1:n_pts
        @inbounds begin
            prod_u = 1.0
            prod_e = 1.0
            zero_hit = false
            for j in 1:k
                val = Predictions[i, j]
                gt  = GoalTuples[j]
                b   = isfinite(val) ? CORE_CalcDesirability_DDEF(gt[1], val, gt[2], gt[3], gt[4], 1.0) : 0.0
                if b <= 1e-12
                    zero_hit = true
                    break
                end
                if Weighted
                    w_m, w_c, w_p = n_weights[j]
                    u = b^(w_c * inv_k)
                    e = (b^(w_m * inv_k) + u + b^(w_p * inv_k)) / 3.0
                    prod_u *= u
                    prod_e *= e
                else
                    prod_u *= b^inv_k
                end
            end
            if zero_hit
                scores[i] = 0.0
            elseif !Weighted
                scores[i] = clamp(prod_u, 0.0, 1.0)
            else
                sc = clamp(0.50 * prod_u + 0.50 * prod_e, 0.0, 1.0)
                x_row = view(Coords, i, :)
                for dm in ModifiersDCYP
                    sc = CORE_ApplyDCYP_DDEF(sc, dm, x_row)
                end
                scores[i] = isfinite(sc) ? clamp(sc, 0.0, 1.0) : 0.0
            end
        end
    end
    return scores
end

"""
    CORE_OptimiseDesirability_DDEF(Models::AbstractVector, Goals::AbstractVector, X_Bounds::AbstractMatrix{Float64}; kwargs...) -> Tuple{Vector{Float64}, Float64}
Locate optimal continuous factor coordinates by maximising composite multi-response desirability via global metaheuristics.
Evaluates geometric-mean composite objective functions across all active response models within the designated bounding box.

# Arguments
- `Models::AbstractVector`: Fitted regression models for all active responses.
- `Goals::AbstractVector`: Optimisation goals and target specifications per response.
- `X_Bounds::AbstractMatrix{Float64}`: Lower and upper search domain bounds of size `3 × 2`.

# Keywords
- `MaxTime::Float64`: Maximum optimisation time budget in seconds (default: `1.0`).
- `PenaltyFn::Union{Function,Nothing}`: Optional boundary constraint penalty function.
- `ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}`: Optional radiochemical decay penalty modifiers.

# Returns
- `Tuple{Vector{Float64}, Float64}`: `(best_coordinates, best_composite_desirability)`.
"""
function CORE_OptimiseDesirability_DDEF(Models::AbstractVector, Goals::AbstractVector, X_Bounds::AbstractMatrix{Float64};
    MaxTime::Float64=1.0, MaxSteps::Union{Int, Nothing}=nothing, PenaltyFn::Union{Function,Nothing}=nothing,
    ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[])
    Dim       = 3
    NumModels = length(Models)

    active_indices = Int[]
    predictors     = Union{CORE_LinearPredictor_DDES, CORE_QuadraticPredictor_DDES}[]
    for m in 1:NumModels
        get(Models[m], "Status", "") != "OK" && continue
        private_beta = collect(Float64, get(Models[m], "Coefs", Float64[]))
        isempty(private_beta) && continue
        mod_type = CORE_GetModelType_DDEF(lowercase(get(Models[m], "ModelType", "quadratic")))
        push!(predictors, CORE_GetPredictor_DDEF(mod_type, private_beta))
        push!(active_indices, m)
    end
    isempty(active_indices) && return (vec(mean(X_Bounds; dims=2)), 0.0)
    active_goals = [CORE_ExtractGoal_DDEF(m <= length(Goals) ? Goals[m] : get(Models[m], "Goal", Dict{String, Any}())) for m in active_indices]
    n_weights    = Tuple{Float64, Float64, Float64}[CORE_GetNeighbourWeights_DDEF(gt[5]) for gt in active_goals]
    vals_buf     = Vector{Float64}(undef, length(active_indices))

    calc_objective(x) = begin
        @inbounds for j in eachindex(predictors)
            vals_buf[j] = predictors[j](x)
        end
        score = CORE_CalcDesirability_DDEF(vals_buf, active_goals, x, ModifiersDCYP; NeighbourWeights=n_weights)

        if PenaltyFn !== nothing
            score *= PenaltyFn(x)
        end

        return -score
    end

    search_range = [(X_Bounds[i, 1], X_Bounds[i, 2]) for i in 1:Dim]

    decay_msg = isempty(ModifiersDCYP) ? "" : " [DCYP: $(join([dm.IsotopeName for dm in ModifiersDCYP], ", "))]"
    FAST_Log_DDEF("CORE", "BBO_START", "Initiating BlackBoxOptim for Global Desirability (MaxTime: $(MaxTime)s)...$(decay_msg)", "WAIT")

    bbo_kwargs = Dict{Symbol, Any}(
        :SearchRange   => search_range,
        :NumDimensions => Dim,
        :MaxTime       => MaxTime,
        :Method        => :adaptive_de_rand_1_bin_radiuslimited,
        :TraceMode     => :silent
    )
    eff_steps = isnothing(MaxSteps) ? (MaxTime <= 0.25 ? 5000 : nothing) : MaxSteps
    if eff_steps !== nothing
        bbo_kwargs[:MaxSteps] = eff_steps
    end

    try
        res = bboptimize(calc_objective; bbo_kwargs...)
        best_x = best_candidate(res)
        best_score = -best_fitness(res)
        FAST_Log_DDEF("CORE", "BBO_SUCCESS", "Global Optimum Found -> Score: $(round(best_score, digits=4))", "OK")
        
        refined_x, refined_score = CORE_RefineLocal_DDEF(calc_objective, best_candidate(res), search_range)
        
        if refined_score > best_score + CORE_OptMinImprove_DDEC
            FAST_Log_DDEF("CORE", "LOCAL_REFINE", "Optimum Polished: $(round(best_score; digits=4)) -> $(round(refined_score; digits=4))", "OK")
            return refined_x, refined_score
        end
        return best_x, best_score
    catch e
        FAST_HandleCatch_DDEF(FAST_TierLogged_DDES(), e, "CORE", "BBO_FAIL", "BlackBoxOptim encountered a critical failure (reverting to geometric centre)")
        return [ (X_Bounds[i, 1] + X_Bounds[i, 2]) / 2.0 for i in 1:Dim ], 0.0
    end
end

const CORE_RefineStepRatio_DDEC  = 0.05
const CORE_RefineMinImprove_DDEC = 1e-7
const CORE_RefineMinStep_DDEC    = 1e-6
const CORE_OptMinImprove_DDEC    = 1e-6

function CORE_RefineLocal_DDEF(obj_fn, start_x, bounds_range; iters=100)
    dim = length(start_x)
    current_x = copy(start_x)
    test_x = similar(current_x)
    current_score = -obj_fn(current_x)
    
    # Adaptive step size starting at 5% of the total span
    step_sizes = [(r[2] - r[1]) * CORE_RefineStepRatio_DDEC for r in bounds_range]
    
    for _ in 1:iters
        improved = false
        for d in 1:dim
            for dir_sign in (-1, 1)
                copyto!(test_x, current_x)
                test_x[d] = clamp(test_x[d] + dir_sign * step_sizes[d], bounds_range[d][1], bounds_range[d][2])
                
                test_score = -obj_fn(test_x)
                if test_score > current_score + CORE_RefineMinImprove_DDEC
                    current_x[d] = test_x[d]
                    current_score = test_score
                    improved = true
                end
            end
        end
        !improved && (step_sizes .*= 0.5)
        all(s < CORE_RefineMinStep_DDEC for s in step_sizes) && break
    end
    
    return current_x, current_score
end

# Concrete functors replace anonymous closures so mixed-model BBO evaluation avoids Any dynamic dispatch.
struct CORE_LinearPredictor_DDES
    b::NTuple{4, Float64}
end
@inline function (p::CORE_LinearPredictor_DDES)(x::AbstractVector{Float64})::Float64
    b = p.b
    @inbounds return b[1] + b[2]*x[1] + b[3]*x[2] + b[4]*x[3]
end

struct CORE_QuadraticPredictor_DDES
    b::NTuple{10, Float64}
end
@inline function (p::CORE_QuadraticPredictor_DDES)(x::AbstractVector{Float64})::Float64
    b = p.b
    @inbounds begin
        x1, x2, x3 = x[1], x[2], x[3]
        return b[1] + b[2]*x1 + b[3]*x2 + b[4]*x3 +
               b[5]*x1*x2 + b[6]*x1*x3 + b[7]*x2*x3 +
               b[8]*x1*x1 + b[9]*x2*x2 + b[10]*x3*x3
    end
end

function CORE_GetPredictor_DDEF(::CORE_ModelLinear_DDES, b::Vector{Float64})::CORE_LinearPredictor_DDES
    length(b) < 4 && throw(ArgumentError("Linear coefficients vector must have at least 4 elements, got $(length(b))"))
    return CORE_LinearPredictor_DDES((b[1], b[2], b[3], b[4]))
end

function CORE_GetPredictor_DDEF(::CORE_ModelQuadratic_DDES, b::Vector{Float64})::CORE_QuadraticPredictor_DDES
    length(b) < 10 && throw(ArgumentError("Quadratic coefficients vector must have at least 10 elements, got $(length(b))"))
    return CORE_QuadraticPredictor_DDES((b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10]))
end

# ------------------------------------------------------------------------------
# SECTION 6: LEADER DATA EXTRACTION
# ------------------------------------------------------------------------------

"""
    CORE_ExtractLeader_DDEF(FilePath::AbstractString, PhaseCode::AbstractString, SelectedID::AbstractString="", VarNames::AbstractVector{<:AbstractString}=String[]) -> Dict{String, Any}
Extract the optimal leader run coordinates and desirability score from an experimental phase record.
Reads the specified phase candidate table, retrieves the global best or user-selected run, and extracts factor levels.

# Arguments
- `FilePath::AbstractString`: Path to the master Excel workbook.
- `PhaseCode::AbstractString`: Phase identifier (e.g. `"Phase1"`).
- `SelectedID::AbstractString`: Optional specific run identifier (defaults to highest score if empty).
- `VarNames::AbstractVector{<:AbstractString}`: Specific factor names to extract.

# Returns
- `Dict{String, Any}`: Dictionary containing `"ID"`, `"Score"`, `"Vals"` (factor coordinates), and `"InputNames"`.
"""
function CORE_ExtractLeader_DDEF(FilePath::AbstractString, PhaseCode::AbstractString, SelectedID::Union{AbstractString, Nothing}="", VarNames::AbstractVector{<:AbstractString}=String[])
    sel_id = isnothing(SelectedID) ? "" : SelectedID
    sheet = C.PREFIX_LEADERS * PhaseCode

    df = FAST_ReadExcel_DDEF(FilePath, sheet)
    if isempty(df)
        FAST_Log_DDEF("CORE", "EXTRACTION_FAIL", "Sheet '$sheet' not found or empty.", "FAIL")
        return Dict{String,Any}()
    end

    cols      = names(df)
    col_score = findfirst(c -> occursin("SCORE", uppercase(strip(string(c)))), cols)
    col_id    = findfirst(c -> uppercase(strip(string(c))) in ("ID", "EXP_ID"), cols)

    isnothing(col_score) && return Dict{String,Any}()

    idx = 0
    if !isempty(sel_id) && !isnothing(col_id)
        idx = findfirst(==(sel_id), string.(df[!, col_id]))
        if isnothing(idx)
            FAST_Log_DDEF("CORE", "LEADER_WARN", "ID '$sel_id' not found. Defaulting to Best.", "WARN")
        else
            FAST_Log_DDEF("CORE", "LEADER_FETCH", "Manual selection: $sel_id", "OK")
        end
    end

    if isnothing(idx) || idx == 0
        _, idx = findmax(df[!, col_score])
        FAST_Log_DDEF("CORE", "LEADER_FETCH", "Automatic selection: Global Best", "OK")
    end

    row = df[idx, :]

    vals = Float64[]
    if !isempty(VarNames)
        for v_name in VarNames
            v_key_pfx = startswith(uppercase(v_name), uppercase(C.PRE_VAR)) ? v_name : "$(C.PRE_VAR)$v_name"
            
            actual_key = FAST_GetColumn_DDEF(df, v_key_pfx)
            actual_alt = isempty(actual_key) ? FAST_GetColumn_DDEF(df, v_name) : ""
            
            val = !isempty(actual_key) ? row[Symbol(actual_key)] : (!isempty(actual_alt) ? row[Symbol(actual_alt)] : 0.0)
            push!(vals, FAST_SafeNum_DDEF(val))
        end
    else
        input_cols = filter(n -> startswith(uppercase(string(n)), uppercase(C.PRE_VAR)), cols)
        vals       = FAST_SafeNum_DDEF.(values(row[input_cols]))
    end

    id_str = isnothing(col_id) ? "N/A" : string(row[col_id])
    FAST_Log_DDEF("CORE", "LEADER_DATA",
        "ID: $id_str | Score: $(round(row[col_score]; digits=4))", "OK")

    return Dict{String,Any}(
        "ID"         => id_str,
        "Score"      => row[col_score],
        "Vals"       => collect(vals),
        "InputNames" => isempty(VarNames) ? filter(n -> startswith(uppercase(string(n)), uppercase(C.PRE_VAR)), cols) : VarNames,
        "OldConfig"  => Any[]
    )
end

# ------------------------------------------------------------------------------
# SECTION 7: DESIGN MATRIX VALIDATION
# ------------------------------------------------------------------------------

"""
    CORE_ValidateDesign_DDEF(DesignMatrix::AbstractMatrix, Config::AbstractVector=[]) -> Tuple{Bool, String}
Perform pre-flight numerical and structural validation on an experimental design matrix.
Checks for minimum sample size, zero-variance columns, excessive duplicate runs, and matrix near-singularity.

# Arguments
- `DesignMatrix::AbstractMatrix`: Matrix of candidate experimental runs (`N × k`).
- `Config::AbstractVector`: Optional factor configurations.

# Returns
- `Tuple{Bool, String}`: `(is_valid, report)` indicating rank sufficiency, column variance, and duplicate runs.
"""
function CORE_ValidateDesign_DDEF(DesignMatrix::AbstractMatrix, Config::AbstractVector=[])
    R, K   = size(DesignMatrix)
    issues = String[]

    !all(isfinite, DesignMatrix) && push!(issues, "Design matrix contains non-finite (NaN/Inf) entries.")
    R < 3 && push!(issues, "Design has fewer than 3 runs ($R). Regression will fail.")

    @inbounds for j in 1:K
        col = view(DesignMatrix, :, j)
        if all(==(col[1]), col)
            push!(issues, "Column $j has zero variance (all values = $(col[1])).")
        end
    end

    seen      = Set{Vector{Float64}}()
    dup_count = 0
    @inbounds for i in 1:R
        row = Float64.(DesignMatrix[i, :])
        if row in seen
            dup_count += 1
        else
            push!(seen, row)
        end
    end
    dup_count > R ÷ 2 && push!(issues, "Design has $dup_count duplicate rows out of $R total.")

    if R >= K && isempty(issues)
        # Scale to [-1, 1] before QR so large factor offsets do not trigger false singularity.
        X_sc = CORE_CodeMatrix_DDEF(DesignMatrix)
        F = qr(hcat(ones(Float64, R), X_sc))
        if rank(F.R) < K + 1
            push!(issues, "Design is rank-deficient or near-singular. Regression may fail.")
        end
    end

    is_valid = isempty(issues)
    if is_valid
        FAST_Log_DDEF("CORE", "VALIDATE", "Design matrix OK ($R×$K, $(R-dup_count) unique).", "OK")
    else
        FAST_Log_DDEF("CORE", "VALIDATE", "Design issues: $(join(issues, " | "))", "WARN")
    end

    return (is_valid, join(issues, "\n"))
end

# ------------------------------------------------------------------------------
# SECTION 8: DESIGN QUALITY METRICS (D, A, G, I Efficiency)
# ------------------------------------------------------------------------------

"""
    CORE_CodeMatrix_DDEF(X::AbstractMatrix, Bounds::Union{AbstractMatrix, Nothing}=nothing) -> Matrix{Float64}
Transform physical factor values into dimensionless coded coordinates in the standard range `[-1.0, 1.0]`.
Enables scale-invariant model fitting and condition number evaluation across factors with differing physical dimensions.

# Arguments
- `X::AbstractMatrix`: Matrix of physical experimental factor coordinates (`N × k`).
- `Bounds::Union{AbstractMatrix, Nothing}`: Optional explicit `k × 2` matrix of `[min, max]` domain bounds.

# Returns
- `Matrix{Float64}`: Dimensionless coded matrix with coordinates scaled to `[-1.0, 1.0]`.
"""
function CORE_CodeMatrix_DDEF(X::AbstractMatrix, Bounds::Union{AbstractMatrix, Nothing}=nothing)
    R, K = size(X)
    X_coded = Matrix{Float64}(undef, R, K)
    
    @inbounds for j in 1:K
        col = @view X[:, j]
        c_min, c_max = minimum(col), maximum(col)
        
        if Bounds !== nothing
            b_min, b_max = Bounds[j, 1], Bounds[j, 2]
        else
            b_min, b_max = c_min, c_max
        end
        
        range_val = b_max - b_min
        col_safe  = clamp.(col, b_min, b_max)
        
        if range_val < 1e-9
            X_coded[:, j] .= 0.0
        else
            X_coded[:, j] .= 2.0 .* (col_safe .- b_min) ./ range_val .- 1.0
        end
    end
    return X_coded
end

"""
    CORE_ExpandModelMatrix_DDEF(X::AbstractMatrix, ModelType=CORE_ModelQuadratic_DDES()) -> Matrix{Float64}
Expand a 3-factor coded matrix into linear (p=4) or full quadratic (p=10) model design columns.
Generates intercept, linear terms, cross-product two-way interactions, and pure quadratic squared columns.

# Arguments
- `X::AbstractMatrix`: Coded factor matrix of size `N × 3`.
- `ModelType`: Model type object (`CORE_ModelLinear_DDES`, `CORE_ModelQuadratic_DDES`) or name string (`"linear"`, `"quadratic"`).

# Returns
- `Matrix{Float64}`: Expanded model matrix of size `N × 4` (linear) or `N × 10` (intercept, linear, interaction, quadratic).
"""
function CORE_ExpandModelMatrix_DDEF(X::AbstractMatrix, ModelType::CORE_AbstractModelType_DDET=CORE_ModelQuadratic_DDES())::Matrix{Float64}
    R, K = size(X)
    K != 3 && throw(ArgumentError("DoECISORY model matrix expansion requires exactly 3 factor columns. Found: $K"))

    if isa(ModelType, CORE_ModelLinear_DDES)
        X_exp = Matrix{Float64}(undef, R, 4)
        @inbounds for i in 1:R
            X_exp[i, 1] = 1.0
            X_exp[i, 2] = Float64(X[i, 1])
            X_exp[i, 3] = Float64(X[i, 2])
            X_exp[i, 4] = Float64(X[i, 3])
        end
        return X_exp
    else
        X_exp = Matrix{Float64}(undef, R, 10)
        @inbounds for i in 1:R
            x1, x2, x3 = Float64(X[i, 1]), Float64(X[i, 2]), Float64(X[i, 3])
            X_exp[i, 1]  = 1.0
            X_exp[i, 2]  = x1
            X_exp[i, 3]  = x2
            X_exp[i, 4]  = x3
            X_exp[i, 5]  = x1 * x2
            X_exp[i, 6]  = x1 * x3
            X_exp[i, 7]  = x2 * x3
            X_exp[i, 8]  = x1 * x1
            X_exp[i, 9]  = x2 * x2
            X_exp[i, 10] = x3 * x3
        end
        return X_exp
    end
end

function CORE_ExpandModelMatrix_DDEF(X::AbstractMatrix, ModelType::AbstractString)::Matrix{Float64}
    return CORE_ExpandModelMatrix_DDEF(X, CORE_GetModelType_DDEF(ModelType))
end

"""
    CORE_CalcDEfficiency_DDEF(X::AbstractMatrix, ModelType=CORE_ModelQuadratic_DDES()) -> Float64
Calculate the normalised D-optimality efficiency criterion based on the Fisher information matrix determinant.
Quantifies the volume of the joint confidence ellipsoid for parameter estimates relative to an ideal orthogonal design.

# Arguments
- `X::AbstractMatrix`: Experimental factor coordinates (`N × 3`).
- `ModelType`: Model specification type or name string (`"linear"` or `"quadratic"`).

# Returns
- `Float64`: D-efficiency metric `(|X'X| / N^p)^(1/p)` in `[0.0, 1.0]`.
"""
function CORE_CalcDEfficiency_DDEF(X::AbstractMatrix, ModelType::CORE_AbstractModelType_DDET=CORE_ModelQuadratic_DDES())::Float64
    try
        R, _ = size(X)
        effective_model = (R < 10 && ModelType isa CORE_ModelQuadratic_DDES) ? CORE_ModelLinear_DDES() : ModelType
        X_sc = CORE_CodeMatrix_DDEF(X)
        X_exp = CORE_ExpandModelMatrix_DDEF(X_sc, effective_model)
        p = size(X_exp, 2)
        R < p && return 0.0

        M = X_exp' * X_exp
        det_val = det(M)
        (isnan(det_val) || det_val <= 0.0) && return 0.0
        eff = (det_val / (Float64(R)^p))^(1.0 / p)
        return isnan(eff) ? 0.0 : clamp(eff, 0.0, 1.0)
    catch e
        return FAST_HandleCatch_DDEF(FAST_TierLogged_DDES(), e, "CORE", "DEFF_FAIL", "D-efficiency computation failed; returning 0.0", 0.0; MsgType="WARN")
    end
end

function CORE_CalcDEfficiency_DDEF(X::AbstractMatrix, ModelType::AbstractString)::Float64
    return CORE_CalcDEfficiency_DDEF(X, CORE_GetModelType_DDEF(ModelType))
end

# ------------------------------------------------------------------------------
# SECTION 9: OPTIMALITY CRITERIA DISPATCH TYPES & CALCULATION
# ------------------------------------------------------------------------------

"""
    CORE_AbstractCriterion_DDET
Trait hierarchy for algorithmic design optimality evaluation (D, A, G, I criteria).
"""
abstract type CORE_AbstractCriterion_DDET end
struct CORE_CriterionD_DDES <: CORE_AbstractCriterion_DDET end
struct CORE_CriterionA_DDES <: CORE_AbstractCriterion_DDET end
struct CORE_CriterionG_DDES <: CORE_AbstractCriterion_DDET end
struct CORE_CriterionI_DDES <: CORE_AbstractCriterion_DDET end

"""
    CORE_CalcCriterion_DDEF(Criterion::CORE_AbstractCriterion_DDET, arg, p::Int, R::Int) -> Float64
    CORE_CalcCriterion_DDEF(Criterion::AbstractString, arg, p::Int, R::Int) -> Float64

Calculate information matrix optimality efficiency criteria (D, A, G, or I) using multiple dispatch.
Evaluates parameter estimation precision, average variance, and prediction dispersion across experimental designs.

# Arguments
- `Criterion`: Optimality criterion trait (`CORE_CriterionD_DDES()`, `CORE_CriterionA_DDES()`, `CORE_CriterionG_DDES()`, `CORE_CriterionI_DDES()`) or string identifier (`"D"`, `"A"`, `"G"`, `"I"`).
- `arg`: Information matrix \$X^T X\$, its inverse \$(X^T X)^{-1}\$, or leverage diagonal vector \$h = \\operatorname{diag}(X (X^T X)^{-1} X^T)\$.
- `p::Int`: Number of estimated model parameters.
- `R::Int`: Number of experimental design runs.

# Returns
- `Float64`: Normalised efficiency score bounded in \$[0.0, 1.0]\$.
"""
CORE_CalcCriterion_DDEF(::CORE_CriterionD_DDES, XtX::AbstractMatrix{Float64}, p::Int, R::Int)::Float64 = begin
    det_val = det(XtX)
    det_val > 0.0 ? clamp((det_val / (Float64(R)^p))^(1.0 / p), 0.0, 1.0) : 0.0
end

CORE_CalcCriterion_DDEF(::CORE_CriterionA_DDES, inv_XtX::AbstractMatrix{Float64}, p::Int, R::Int)::Float64 = begin
    tr_inv = tr(inv_XtX)
    tr_inv > 0.0 ? clamp(p / (R * tr_inv), 0.0, 1.0) : 0.0
end

CORE_CalcCriterion_DDEF(::CORE_CriterionG_DDES, lev::AbstractVector{Float64}, p::Int, R::Int)::Float64 = begin
    max_var = maximum(lev)
    max_var > 0.0 ? clamp(p / (R * max_var), 0.0, 1.0) : 0.0
end

CORE_CalcCriterion_DDEF(::CORE_CriterionI_DDES, inv_XtX::AbstractMatrix{Float64}, p::Int, R::Int)::Float64 = begin
    M = zeros(Float64, p, p)
    M[1, 1] = 1.0
    for i in 2:min(4, p)
        M[i, i] = 1.0 / 3.0
    end
    if p >= 10
        for i in 5:7
            M[i, i] = 1.0 / 9.0
        end
        for i in 8:10
            M[i, i] = 1.0 / 5.0
            M[1, i] = M[i, 1] = 1.0 / 3.0
            for j in 8:10
                i != j && (M[i, j] = 1.0 / 9.0)
            end
        end
    end
    avg_var = tr(inv_XtX * M)
    # Normalise against orthogonal baseline tr(M)/R so cube I-efficiency stays strictly within (0, 1].
    avg_var > 0.0 ? clamp(tr(M) / (R * avg_var), 0.0, 1.0) : 0.0
end

CORE_CalcCriterion_DDEF(::CORE_CriterionI_DDES, lev::AbstractVector{Float64}, p::Int, R::Int)::Float64 = begin
    mean_lev = sum(lev) / length(lev)
    mean_lev > 0.0 ? clamp(p / (R * mean_lev), 0.0, 1.0) : 0.0
end

function CORE_CalcCriterion_DDEF(Crit::AbstractString, arg, p::Int, R::Int)::Float64
    u = uppercase(strip(Crit))
    u == "D" && return CORE_CalcCriterion_DDEF(CORE_CriterionD_DDES(), arg, p, R)
    u == "A" && return CORE_CalcCriterion_DDEF(CORE_CriterionA_DDES(), arg, p, R)
    u == "G" && return CORE_CalcCriterion_DDEF(CORE_CriterionG_DDES(), arg, p, R)
    u == "I" && return CORE_CalcCriterion_DDEF(CORE_CriterionI_DDES(), arg, p, R)
    throw(ArgumentError("Unknown criterion type: '$Crit'. Valid options: D, A, G, I."))
end

"""
    CORE_CalcDesignMetrics_DDEF(X::AbstractMatrix, ModelType=CORE_ModelQuadratic_DDES()) -> Dict{String, Float64}
Compute information matrix conditioning and optimality criteria (D-, A-, G-, and I-efficiencies).
Provides a comprehensive diagnostic assessment of parameter variance, prediction error dispersion, and numerical stability.

# Arguments
- `X::AbstractMatrix`: Experimental factor coordinates (`N × 3`).
- `ModelType`: Model specification type or name string (`"linear"` or `"quadratic"`).

# Returns
- `Dict{String, Float64}`: Dictionary containing `"D"`, `"A"`, `"G"`, `"I"` efficiency scores and matrix `"Condition"`.
"""
function CORE_CalcDesignMetrics_DDEF(X::AbstractMatrix, ModelType::CORE_AbstractModelType_DDET=CORE_ModelQuadratic_DDES())
    R, K = size(X)
    res  = Dict("D" => 0.0, "A" => 0.0, "G" => 0.0, "I" => 0.0, "Condition" => Inf)
    K != 3 && return res

    effective_model = (R < 10 && ModelType isa CORE_ModelQuadratic_DDES) ? CORE_ModelLinear_DDES() : ModelType
    X_sc = CORE_CodeMatrix_DDEF(X)
    X_exp = CORE_ExpandModelMatrix_DDEF(X_sc, effective_model)
    p = size(X_exp, 2)
    R < p && return res

    try
        XtX = Matrix{Float64}(X_exp' * X_exp)
        res["Condition"] = cond(X_exp)
        res["D"] = CORE_CalcCriterion_DDEF(CORE_CriterionD_DDES(), XtX, p, R)

        inv_XtX = Matrix{Float64}(pinv(XtX))
        res["A"] = CORE_CalcCriterion_DDEF(CORE_CriterionA_DDES(), inv_XtX, p, R)

        lev = Vector{Float64}(diag(X_exp * inv_XtX * X_exp'))
        res["G"] = CORE_CalcCriterion_DDEF(CORE_CriterionG_DDES(), lev, p, R)
        res["I"] = CORE_CalcCriterion_DDEF(CORE_CriterionI_DDES(), inv_XtX, p, R)
    catch e
        FAST_HandleCatch_DDEF(FAST_TierLogged_DDES(), e, "CORE", "METRICS_ERR", "Stability error in design metrics"; MsgType="WARN")
    end
    return res
end

function CORE_CalcDesignMetrics_DDEF(X::AbstractMatrix, ModelType::AbstractString)
    return CORE_CalcDesignMetrics_DDEF(X, CORE_GetModelType_DDEF(ModelType))
end

end