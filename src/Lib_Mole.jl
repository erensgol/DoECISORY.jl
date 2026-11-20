"""
    Lib_Mole

Stoichiometric mass balance, physical unit verification, and first-order kinetic decay subsystem
for **DoECISORY.jl**. Parses formulation components, reconciles gravimetric mass and molar budgets,
and compensates for pre-reaction degradation and post-reaction analyte holding latency.

- **Tag:** `MOLE`  |  **Roles:** `Variable`, `Fixed`, `Filler` (`MOLE_ParseTable_DDEF`)
- **Mass & Feasibility:** Gravimetric solver & batch audits (`MOLE_CalcMass_DDEF`, `MOLE_AuditQuick_DDEF`, `MOLE_AuditBatch_DDEF`)
- **Unit Validation:** Physical dimension checks via `Unitful` (`MOLE_ValidatePhysicalUnit_DDEF`)
- **Decay Kinetics:** Forward depletion & EOS restoration (`MOLE_CalcRadioDecay_DDEF`)
"""
module Lib_Mole

using DataFrames
using Printf
using Unitful
using Statistics
using ..Sys_Fast

export MOLE_ParseTable_DDEF, MOLE_AuditQuick_DDEF, MOLE_CalcMass_DDEF,
       MOLE_ApproxEq_DDEF, MOLE_ValidatePhysicalUnit_DDEF, MOLE_AuditMatrix_DDEF,
       MOLE_AuditBatch_DDEF, MOLE_ValidateFeasibility_DDEF, MOLE_CalcRadioDecay_DDEF,
       MOLE_ProcessDesign_DDEF, MOLE_GetPercentageEquivalent_DDEF, MOLE_IsTimeUnit_DDEF,
       MOLE_ConvertToMinutes_DDEF, MOLE_ValidateProtocolInputs_DDEF

# ==============================================================================
# PART A: CHEMICAL DATA STRUCTURES & MODELS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: INGREDIENT DEFINITION
# ------------------------------------------------------------------------------

const C = FAST_Data_DDEC

abstract type MOLE_AbstractIngredientRole_DDET end
struct MOLE_RoleVariable_DDES <: MOLE_AbstractIngredientRole_DDET end
struct MOLE_RoleFixed_DDES    <: MOLE_AbstractIngredientRole_DDET end
struct MOLE_RoleFiller_DDES   <: MOLE_AbstractIngredientRole_DDET end

abstract type MOLE_AbstractStoicUnit_DDET end
struct MOLE_UnitMass_DDES          <: MOLE_AbstractStoicUnit_DDET end
struct MOLE_UnitMolar_DDES         <: MOLE_AbstractStoicUnit_DDET end
struct MOLE_UnitConcentration_DDES <: MOLE_AbstractStoicUnit_DDET end
struct MOLE_UnitOther_DDES         <: MOLE_AbstractStoicUnit_DDET end

const MOLE_UnitMap_DDEC = Dict{String, Tuple{MOLE_AbstractStoicUnit_DDET, Float64}}(
    ""           => (MOLE_UnitMolar_DDES(), 1.0),
    "mr"         => (MOLE_UnitMolar_DDES(), 1.0),
    "ratio"      => (MOLE_UnitMolar_DDES(), 1.0),
    "-"          => (MOLE_UnitMolar_DDES(), 1.0),
    "%m"         => (MOLE_UnitMolar_DDES(), 0.01),
    "%"          => (MOLE_UnitMolar_DDES(), 0.01),
    "%mol"       => (MOLE_UnitMolar_DDES(), 0.01),
    "m"          => (MOLE_UnitConcentration_DDES(), 1000.0),
    "mol/l"      => (MOLE_UnitConcentration_DDES(), 1000.0),
    "molar"      => (MOLE_UnitConcentration_DDES(), 1000.0),
    "mm"         => (MOLE_UnitConcentration_DDES(), 1.0),
    "mmol/l"     => (MOLE_UnitConcentration_DDES(), 1.0),
    "millimolar" => (MOLE_UnitConcentration_DDES(), 1.0),
    "um"         => (MOLE_UnitConcentration_DDES(), 0.001),
    "μm"         => (MOLE_UnitConcentration_DDES(), 0.001),
    "micromolar" => (MOLE_UnitConcentration_DDES(), 0.001),
    "umol/l"     => (MOLE_UnitConcentration_DDES(), 0.001)
)

const MOLE_RoleMap_DDEC = Dict{String, MOLE_AbstractIngredientRole_DDET}(
    "variable" => MOLE_RoleVariable_DDES(),
    "fixed"    => MOLE_RoleFixed_DDES(),
    "filler"   => MOLE_RoleFiller_DDES()
)

const MOLE_TimeFactorMap_DDEC = Dict{String, Float64}(
    "S"         => 1/60,
    "SEC"       => 1/60,
    "SECS"      => 1/60,
    "SECOND"    => 1/60,
    "SECONDS"   => 1/60,
    "MIN"       => 1.0,
    "MINS"      => 1.0,
    "MINUTE"    => 1.0,
    "MINUTES"   => 1.0,
    "H"         => 60.0,
    "HR"        => 60.0,
    "HRS"       => 60.0,
    "HOUR"      => 60.0,
    "HOURS"     => 60.0,
    "D"         => 1440.0,
    "DAY"       => 1440.0,
    "DAYS"      => 1440.0
)

# ------------------------------------------------------------------------------
# SECTION 2: TIME-SERIES NORMALISATION GATEWAY
# ------------------------------------------------------------------------------

"""
    MOLE_ConvertToMinutes_DDEF(Value::Real, Unit::AbstractString) -> Float64
Normalise arbitrary time duration units (seconds, hours, days) into minutes.
Provides dimensional time standardisation across kinetic calculations and decay compensation models.

# Arguments
- `Value::Real`: Numeric time duration value.
- `Unit::AbstractString`: Time unit string (`"s"`, `"sec"`, `"min"`, `"h"`, `"hr"`, `"d"`).

# Returns
- `Float64`: Duration converted into decimal minutes.
"""
function MOLE_ConvertToMinutes_DDEF(Value::Real, Unit::AbstractString)::Float64
    !isfinite(Value) && throw(ArgumentError("Time value must be finite."))
    Value <= 0.0 && return 0.0
    u = uppercase(strip(Unit))
    !haskey(MOLE_TimeFactorMap_DDEC, u) && throw(ArgumentError("Unknown time unit: '$Unit'."))
    return Float64(Value * MOLE_TimeFactorMap_DDEC[u])
end

"""
    MOLE_IsTimeUnit_DDEF(UnitStr::AbstractString) -> Bool
Determine whether a given physical unit string represents a temporal dimension.
Enables the Decay-Coupled Yield Penalty engine to automatically detect incubation time variables among formulation factors.

# Arguments
- `UnitStr::AbstractString`: Unit string to evaluate.

# Returns
- `Bool`: `true` if unit matches recognised time dimensions, `false` otherwise.
"""
function MOLE_IsTimeUnit_DDEF(UnitStr::AbstractString)::Bool
    u = uppercase(strip(UnitStr))
    isempty(u) && return false
    return haskey(MOLE_TimeFactorMap_DDEC, u)
end

# ------------------------------------------------------------------------------
# SECTION 3: RADIO-DECAY CALCULATION
# ------------------------------------------------------------------------------

"""
    MOLE_CalcRadioDecay_DDEF(RawValue::Real, HalfLife::Real, HalfLifeUnit::AbstractString, DeltaTMinutes::Real; Reverse::Bool=false) -> Float64
Calculate decayed activity or mass using first-order radioactive kinetics `N(t) = N_0 * exp(±lambda * t)`.
Supports forward decay compensation and backward initial-activity reconstruction for short-lived radiotracers.

# Arguments
- `RawValue::Real`: Initial radioactivity or compound quantity.
- `HalfLife::Real`: Radionuclide half-life value.
- `HalfLifeUnit::AbstractString`: Half-life time unit (e.g. `"min"`, `"h"`, `"days"`).
- `DeltaTMinutes::Real`: Elapsed time interval in minutes.

# Keywords
- `Reverse::Bool`: If `true`, computes pre-decay activity `N_0 = N(t) * exp(+lambda * t)` (default: `false`).

# Returns
- `Float64`: Decay-corrected quantity.
"""
function MOLE_CalcRadioDecay_DDEF(RawValue::Real, HalfLife::Real, HalfLifeUnit::AbstractString, DeltaTMinutes::Real; Reverse::Bool=false)::Float64
    (!isfinite(RawValue) || !isfinite(HalfLife) || !isfinite(DeltaTMinutes)) && throw(ArgumentError("Decay inputs must be finite."))
    DeltaTMinutes < 0.0 && throw(ArgumentError("Elapsed time DeltaTMinutes must be non-negative; use Reverse=true for backward decay."))
    hl_minutes = MOLE_ConvertToMinutes_DDEF(HalfLife, HalfLifeUnit)
    hl_minutes <= 0.0 && return Float64(RawValue)

    lambda       = log(2) / hl_minutes
    decay_factor = exp((Reverse ? lambda : -lambda) * DeltaTMinutes)
    
    return Float64(RawValue * decay_factor)
end

# ------------------------------------------------------------------------------
# SECTION 4: CONSTANTS & TOLERANCE REGISTRY
# ------------------------------------------------------------------------------

const MOLE_StoicTolerance_DDEC = 1e-6   
"""
    MOLE_ApproxEq_DDEF(a::Real, b::Real; atol::Float64=1e-6) -> Bool
Evaluate floating-point equality between chemical quantities within a predefined absolute tolerance.
Prevents false-negative validation failures arising from floating-point rounding during mass balance checks.

# Arguments
- `a::Real`: First numeric quantity.
- `b::Real`: Second numeric quantity.

# Keywords
- `atol::Float64`: Absolute comparison tolerance (default: `1e-6`).

# Returns
- `Bool`: `true` if absolute difference `|a - b| <= atol`, `false` otherwise.
"""
MOLE_ApproxEq_DDEF(a::Real, b::Real; atol::Float64=MOLE_StoicTolerance_DDEC) = isapprox(a, b; atol)

# ==============================================================================
# PART B: STOICHIOMETRIC INTELLIGENCE ENGINE
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 5: CHEMICAL TABLE DATA PARSING
# ------------------------------------------------------------------------------

"""
    MOLE_ParseTable_DDEF(TableData::AbstractVector) -> Dict{String, Any}
Parse tabular formulation records from the UI DataTable into categorised operational arrays.
Extracts component identifiers, functional roles, discrete level bounds, and molecular weights into indexed dictionaries.

# Arguments
- `TableData::AbstractVector`: Array of row dictionaries containing formulation parameters.

# Returns
- `Dict{String, Any}`: Dictionary containing `"Names"`, `"Roles"`, `"Mins"`, `"Mids"`, `"Maxs"`, and `"MWs"`.
"""
function MOLE_ParseTable_DDEF(TableData::AbstractVector)
    clean_data, input_warnings = FAST_SanitiseInput_DDEF(TableData)

    names = string.(get.(clean_data, "Name", "Unknown"))
    roles_str = string.(get.(clean_data, "Role", "Fixed"))
    mins = Float64.(get.(clean_data, "L1", 0.0))
    mids = Float64.(get.(clean_data, "L2", 0.0))
    maxs = Float64.(get.(clean_data, "L3", 0.0))
    mws = Float64.(get.(clean_data, "MW", 0.0))

    tag_var = lowercase(C.ROLE_VAR)
    tag_fill = lowercase(C.ROLE_FILL)

    idx_var = findall(r -> lowercase(r) == tag_var, roles_str)
    idx_fill = findall(r -> lowercase(r) == tag_fill, roles_str)
    idx_fix = findall(r -> (lr = lowercase(r); lr != tag_var && lr != tag_fill), roles_str)
    idx_chem = findall(>(0), mws)

    return Dict(
        "Names" => names, "Roles" => roles_str,
        "Mins" => mins, "Mids" => mids, "Maxs" => maxs, "MWs" => mws,
        "Idx_Var" => idx_var, "Idx_Fix" => idx_fix,
        "Idx_Fill" => idx_fill, "Idx_Chem" => idx_chem,
        "Rows" => clean_data, "RawTable" => clean_data,
        "InputWarnings" => input_warnings
    )
end

function MOLE_IdentifyRole_DDEF(r::AbstractString)::MOLE_AbstractIngredientRole_DDET
    u = lowercase(strip(r))
    return get(MOLE_RoleMap_DDEC, u, MOLE_RoleFixed_DDES())
end

# ------------------------------------------------------------------------------
# SECTION 6: PHYSICAL DIMENSION VALIDATION (Unitful.jl)
# ------------------------------------------------------------------------------

"""
    MOLE_GetUnitType_DDEF(UnitStr::String) -> (Symbol, Float64)
Categorises a unit string into :Mass (Fixed), :Molar (Relational), or :Other.
Returns (Type, ScaleToSystemBase) where the base is mg for mass and fractions for molar values.
"""
function MOLE_GetUnitType_DDEF(UnitStr::AbstractString)::Tuple{MOLE_AbstractStoicUnit_DDET, Float64}
    u = lowercase(strip(UnitStr))
    
    static_lookup = get(MOLE_UnitMap_DDEC, u, nothing)
    !isnothing(static_lookup) && return static_lookup

    try
        u_mod = replace(u, " " => "*", "_" => "*")
        u_mod = replace(u_mod, r"(?:^|(?<=[*/\d]))(mcg|microgram|micrograms)" => "μg")
        u_mod = replace(u_mod, r"(?:^|(?<=[*/\d]))(mc|mic|u)(?=[a-zA-Z])" => "μ")
        
        uq = uparse(u_mod)
        if dimension(uq) == dimension(u"g")
            return (MOLE_UnitMass_DDES(), Float64(ustrip(uconvert(u"mg", 1.0 * uq))))
        end
    catch e
        FAST_HandleCatch_DDEF(FAST_TierSilent_DDES(), e)
    end
    
    return (MOLE_UnitOther_DDES(), 1.0)
end

# ------------------------------------------------------------------------------
# SECTION 7: MOLAR PERCENTAGE DISPATCH ENGINE
# ------------------------------------------------------------------------------

"""
    MOLE_GetPercentageEquivalent_DDEF(Value::Float64, UnitStr::AbstractString, MW::Float64, Vol::Float64, Conc::Float64) -> Float64
Calculate the equivalent molar percentage contribution of a formulation component within the total system budget.
Translates absolute masses, molar concentrations, and percentage ratios into a unified percentage scale for mass audit.

# Arguments
- `Value::Float64`: Ingredient level value.
- `UnitStr::AbstractString`: Physical unit string (e.g. `"mg"`, `"mM"`, `"%"`).
- `MW::Float64`: Molecular weight in grams per mole.
- `Vol::Float64`: Total formulation volume in millilitres.
- `Conc::Float64`: Target overall molar concentration in millimoles per litre.

# Returns
- `Float64`: Equivalent molar percentage contribution in `[0.0, 100.0]`.
"""
function MOLE_GetPercentageEquivalent_DDEF(Value::Float64, UnitStr::AbstractString, MW::Float64, Vol::Float64, Conc::Float64)::Float64
    (isnan(Vol) || isnan(Conc) || Vol <= 0.0 || Conc <= 0.0 || MW <= 0.0) && return 0.0
    budget = (Vol / 1000.0) * Conc
    budget <= 0.0 && return 0.0
    u_type, u_scale = MOLE_GetUnitType_DDEF(UnitStr)
    return MOLE_CalcPercentage_DDEF(u_type, Value, u_scale, MW, Vol, budget, lowercase(strip(UnitStr)))
end

MOLE_CalcPercentage_DDEF(::MOLE_UnitMolar_DDES, v::Float64, s::Float64, mw::Float64, vol::Float64, b::Float64, u_str::AbstractString)::Float64 = (u_str == "%m" || u_str == "%" || u_str == "%mol") ? v : 0.0
MOLE_CalcPercentage_DDEF(::MOLE_UnitMass_DDES, v::Float64, s::Float64, mw::Float64, vol::Float64, b::Float64, u_str::AbstractString)::Float64 = ((v * s) / mw / b) * 100.0
MOLE_CalcPercentage_DDEF(::MOLE_UnitConcentration_DDES, v::Float64, s::Float64, mw::Float64, vol::Float64, b::Float64, u_str::AbstractString)::Float64 = (((vol / 1000.0) * (v * s)) / b) * 100.0
MOLE_CalcPercentage_DDEF(::MOLE_UnitOther_DDES, v::Float64, s::Float64, mw::Float64, vol::Float64, b::Float64, u_str::AbstractString)::Float64 = 0.0

"""
    MOLE_ValidatePhysicalUnit_DDEF(ValueStr::AbstractString, ExpectedType::AbstractString) -> Tuple{Bool, Float64, String}
Validate physical dimensional correctness using strict Unitful dimensional analysis.
Ensures entered values match expected physical dimensions (Volume, Concentration, Mass, or Time) and converts them to base units.

# Arguments
- `ValueStr::AbstractString`: Input string containing numeric magnitude and unit (e.g. `"250 uL"`).
- `ExpectedType::AbstractString`: Expected physical dimension (`"Volume"`, `"Concentration"`, `"Mass"`, `"Time"`, or `"Ratio"`).

# Returns
- `Tuple{Bool, Float64, String}`: `(is_valid, magnitude_in_system_units, status_message)`.
"""
function MOLE_ValidatePhysicalUnit_DDEF(ValueStr::AbstractString, ExpectedType::AbstractString)
    val_clean = strip(ValueStr)
    isempty(val_clean) && return (false, 0.0, "Input is empty.")

    parse_str = replace(val_clean, " " => "*", "_" => "*")
    parse_str = replace(parse_str, r"(?:^|(?<=[*/\d]))(mcg|microgram|micrograms)"i => "μg")
    parse_str = replace(parse_str, r"(?:^|(?<=[*/\d]))(mc|mic|u)(?=[a-zA-Z])"i => "μ")

    try
        exp_val = uparse(parse_str)
        if typeof(exp_val) <: Real
            exp_val = exp_val * u"1" 
        end

        tgt_unit      = nothing
        expected_name = ""

        if ExpectedType == "Volume"
            tgt_unit      = u"L"
            expected_name = "Volume (Dimensional Unit)"
        elseif ExpectedType == "Concentration"
            tgt_unit      = u"mol/L"
            expected_name = "Concentration (Dimensional Unit)"
        elseif ExpectedType == "Mass"
            tgt_unit      = u"g"
            expected_name = "Mass (Dimensional Unit)"
        elseif ExpectedType == "Time"
            tgt_unit      = u"hr"
            expected_name = "Time (Temporal Unit)"
        elseif ExpectedType == "Ratio" || ExpectedType == "Dimensionless"
            tgt_unit      = u"1"
            expected_name = "Dimensionless Ratio"
        else
            return (false, 0.0, "Unknown physical dimension requested: $ExpectedType")
        end

        if dimension(exp_val) == dimension(u"1")
            if ExpectedType == "Ratio" || ExpectedType == "Dimensionless"
                return (true, Float64(ustrip(exp_val)), "OK")
            end
            return (false, 0.0, "Dimensional mismatch: Expected $expected_name, got dimensionless quantity.")
        end

        if dimension(exp_val) != dimension(tgt_unit)
            return (false, 0.0, "Dimensional mismatch: Expected $expected_name, got $(dimension(exp_val)).")
        end

        sys_val = uconvert(tgt_unit, 1.0 * exp_val)
        return (true, Float64(ustrip(sys_val)), "OK")
    catch e
        FAST_HandleCatch_DDEF(FAST_TierLogged_DDES(), e, "MOLE", "UNIT_PARSE_WARN", "Unitful parsing failed for '$val_clean'"; MsgType="WARN")
        return (false, 0.0, "Unitful Parsing Error: Invalid format or unknown unit ('$val_clean') -> $e")
    end
end

# ==============================================================================
# PART C: GRAVIMETRIC AUDIT & FEASIBILITY
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 8: SYSTEM GRAVIMETRIC AUDIT
# ------------------------------------------------------------------------------

"""
    MOLE_AuditQuick_DDEF(TableData::AbstractVector, Vol::Float64, Conc::Float64) -> Tuple{Bool, String, DataFrame, Float64, String}
Execute a rapid gravimetric and stoichiometric audit on baseline formulation recipes.
Verifies variable factor counts, checks mass conservation limits, and automatically computes filler reagent quantities.

# Arguments
- `TableData::AbstractVector`: Vector of formulation component dictionaries.
- `Vol::Float64`: Target batch volume in millilitres.
- `Conc::Float64`: Target overall molar concentration in millimoles per litre.

# Returns
- `Tuple`: `(is_valid, audit_report_text, summary_dataframe, total_batch_mass_mg, filler_status)`.
"""
function MOLE_AuditQuick_DDEF(TableData::AbstractVector, Vol::Float64, Conc::Float64)
    D = MOLE_ParseTable_DDEF(TableData)
    ratios = Float64.(D["Mids"]) 
    idx_fill = D["Idx_Fill"]
    idx_chem = D["Idx_Chem"]
    num_vars = length(D["Idx_Var"])
    num_fills = length(idx_fill)

    io = IOBuffer()
    write(io, "=== SYSTEM GRAVIMETRIC AUDIT ===\n")
    @printf(io, "Environment: %.2f mL | Target: %.2f mM\n", Vol, Conc)
    write(io, "--------------------------------------\n")

    is_valid = true
    if num_vars != 3
        write(io, "![ERROR] Exactly 3 Variables required (Found: $num_vars)\n")
        is_valid = false
    end
    if num_fills > 1
        write(io, "![ERROR] Maximum 1 Filler allowed (Found: $num_fills)\n")
        is_valid = false
    end

    for r in D["Rows"]
        unit = lowercase(strip(string(get(r, "Unit", ""))))
        mw = Float64(get(r, "MW", 0.0))
        name = string(get(r, "Name", "Unknown"))
        
        if mw < 0.0
            @printf(io, "![ERROR] Physical Impossibility: Component '%s' has negative Molecular Weight (%.2f). Calculation aborted.\n", name, mw)
            is_valid = false
        end

        if (unit == "%m" || unit == "%" || unit == "%mol" || unit == "mr" || unit == "ratio" || unit == "m") && mw <= 0.0
            @printf(io, "![ERROR] Stoichiometry Error: Component '%s' uses unit '%s' (Molar/Ratio) but has no Molecular Weight (MW). MW is mandatory for these calculations.\n", name, unit)
            is_valid = false
        end

        if mw > 0.0 && !isempty(unit) && unit != "-" && unit != "%m" && unit != "%" && unit != "%mol" && unit != "mr" && unit != "ratio" && unit != "m"
            u_type, _ = MOLE_GetUnitType_DDEF(unit)
            MOLE_ValidateUnitSafely_DDEF(u_type, io, name, unit)
        end
    end

    if !isempty(idx_fill) && is_valid
        fill_idx = idx_fill[1]
        consumed_pct = 0.0
        for k in eachindex(ratios)
            (k == fill_idx || D["MWs"][k] <= 0.0) && continue
            
            u_str = string(get(D["Rows"][k], "Unit", "-"))
            mw    = D["MWs"][k]
            val   = ratios[k]
            
            consumed_pct += MOLE_GetPercentageEquivalent_DDEF(val, u_str, mw, Vol, Conc)
        end
        
        if consumed_pct > 100.0 * (1.0 + 1e-6)
            @printf(io, "![ERROR] Filler balance failed: Consumed molar budget (%.2f%%) exceeds 100%%\n", consumed_pct)
            is_valid = false
            ratios[fill_idx] = 0.0
        else
            # Filler component functions as the primary stoichiometric balancer.
            ratios[fill_idx] = max(0.0, 100.0 - consumed_pct)
        end
    end

    units = String[string(get(r, "Unit", "")) for r in D["Rows"]]
    mass_results = MOLE_CalcMass_DDEF(
        Vector{String}(D["Names"][idx_chem]),
        Vector{Float64}(D["MWs"][idx_chem]),
        Vector{Float64}(ratios[idx_chem]),
        Vol,
        Conc,
        Vector{String}(units[idx_chem])
    )

    total_moles_target_mmol = (Vol / 1000.0) * Conc
    if total_moles_target_mmol > 0 && is_valid
        total_moles_calc = sum(mass_results[!, :Moles_mmol])
        # Identify instances of over-concentration.
        if total_moles_calc > total_moles_target_mmol * (1.0 + 1e-6) + 1e-9
            @printf(io, "![WARN] OVER-CONCENTRATED: Total moles (%.6f mmol) exceeds target (%.6f mmol). Breakdown reflects absolute input excess.\n", total_moles_calc, total_moles_target_mmol)
        # Identify instances of under-concentration and budget gaps.
        elseif total_moles_calc < total_moles_target_mmol * (1.0 - 1e-6) - 1e-9
            @printf(io, "![WARN] UNDER-CONCENTRATED: Total moles (%.6f mmol) is below target budget (%.6f mmol). Ensure a 'Filler' or sufficient 'Ratio' components are defined.\n", total_moles_calc, total_moles_target_mmol)
        end
    end

    total_mass_mg = sum(mass_results[!, :TARGET_MASS_mg])

    target_moles_mmol = (Vol / 1000.0) * Conc
    if target_moles_mmol > 0 && is_valid
        moles_sum = sum(mass_results[!, :Moles_mmol])
        if !isapprox(moles_sum, target_moles_mmol; rtol=1e-6, atol=1e-10)
            @printf(io, "\n[WARN] Meticulous check: Molar balance deviation. Sum = %.8f (targeted %.8f)\n", moles_sum, target_moles_mmol)
        end
    end

    write(io, "\n[CHEMICAL BREAKDOWN (CENTRE / L2)]\n")
    for (i, row) in enumerate(eachrow(mass_results))
        role_type = MOLE_IdentifyRole_DDEF(D["Roles"][idx_chem[i]])
        u_label = MOLE_GetAuditLabel_DDEF(role_type, row[:IsFixed])
        u_raw = lowercase(strip(units[idx_chem][i]))
        mw_missing = (u_raw == "%m" || u_raw == "%" || u_raw == "%mol" || u_raw == "mr" || u_raw == "ratio" || u_raw == "m") && (D["MWs"][idx_chem][i] <= 0.0 || isnan(D["MWs"][idx_chem][i]))
        
        @printf(io, "> %-15s: %9.3f mg %-15s (Ratio: %6.1f%%)%s\n",
            row[:Component], row[:TARGET_MASS_mg], u_label, row[:Molar_Ratio], mw_missing ? " [⚠️ MW MISSING]" : "")
    end

    write(io, "\n[SOLVENT / MATRIX]\n")
    if Vol > 0
        @printf(io, "> Solvent Req.   : Fill up to %.2f mL total volume (Target Density)\n", Vol)
    else
        write(io, "> ![WARN] No liquid environment defined.\n")
    end

    write(io, "--------------------------------------\n")
    @printf(io, "SUM DRY MASS (CENTRE): %10.4f mg\n", total_mass_mg)

    fill_status = isempty(idx_fill) ? "Direct Fractions (No filler)" : let f_idx=idx_fill[1]; f_name=D["Names"][f_idx]; f_val=ratios[f_idx]; write(io, "\n[SYSTEM] Filler '$f_name' auto-balanced to $(round(f_val; digits=2))%"); "$f_name: $(round(f_val; digits=2))%" end

    FAST_Log_DDEF("MOLE", "AUDIT_COMPLETE", "Total Mass (Centre): $(round(total_mass_mg; digits=2)) mg", "OK")

    return (is_valid && total_mass_mg > 0 && !isempty(mass_results), String(take!(io)), mass_results, total_mass_mg, fill_status)
end

MOLE_ValidateUnitSafely_DDEF(::MOLE_UnitOther_DDES, io, name, unit) = @printf(io, "![WARN] Unit Error: Component '%s' has invalid chemical unit '%s'.\n", name, unit)
MOLE_ValidateUnitSafely_DDEF(::MOLE_AbstractStoicUnit_DDET, io, name, unit) = nothing

MOLE_GetAuditLabel_DDEF(::MOLE_RoleFiller_DDES, is_fix) = "(System  Filler)"
MOLE_GetAuditLabel_DDEF(::MOLE_AbstractIngredientRole_DDET, is_fix) = is_fix ? "(Absolute/Fixed)" : "(Relational MR)"

# ------------------------------------------------------------------------------
# SECTION 9: PRIMARY STOICHIOMETRY ENGINE
# ------------------------------------------------------------------------------

"""
    MOLE_CalcMass_DDEF(Names::AbstractVector{<:AbstractString}, MWs::AbstractVector{Float64}, Ratios::AbstractVector{Float64}, Tgt_Vol::Float64, Tgt_Conc::Float64, Units::AbstractVector{<:AbstractString}, Scale::Float64=1.0; kwargs...) -> DataFrame
Resolve multi-component gravimetric mass requirements using a multi-pass stoichiometric reconciliation engine.
Processes absolute mass and concentration constraints first, allocates internal percentages, and distributes residual moles across stoichiometric components.

# Arguments
- `Names`: Vector of ingredient names.
- `MWs`: Molecular weights in g/mol.
- `Ratios`: Component formulation ratios or level values.
- `Tgt_Vol`: Total batch volume in millilitres.
- `Tgt_Conc`: Target total concentration in millimolar.
- `Units`: Component physical unit strings.
- `Scale`: Optional scaling factor (default: `1.0`).

# Keywords
- `SuppressLog::Bool`: Mutes warning logs during iterative solver loops (default: `false`).

# Returns
- `DataFrame`: Table containing resolved masses (`TARGET_MASS_mg`), millimoles (`Moles_mmol`), and normalised percentages.
"""
function MOLE_CalcMass_DDEF(Names::AbstractVector{<:AbstractString}, MWs::AbstractVector{Float64},
    Ratios::AbstractVector{Float64}, Tgt_Vol::Float64, Tgt_Conc::Float64,
    Units::AbstractVector{<:AbstractString}, Scale::Float64=1.0; SuppressLog::Bool=false)
    
    n = length(Names)
    res_mass_mg = zeros(n)
    res_moles_mmol = zeros(n)
    is_fixed = fill(false, n)

    if (isnan(Tgt_Vol) || isnan(Tgt_Conc) || Tgt_Vol <= 0.0 || Tgt_Conc <= 0.0)
        return DataFrame(
            :Component => Names, :Molar_Ratio => zeros(n), :Moles_mmol => zeros(n),
            :TARGET_MASS_mg => zeros(n), :IsFixed => fill(true, n))
    end

    total_moles_target_mmol = (Tgt_Vol / 1000.0) * (Tgt_Conc * Scale)

    # Absolute Components (Mass / Concentration)
    for i in 1:n
        u_type, u_scale = MOLE_GetUnitType_DDEF(Units[i])
        MOLE_ResolvePrimaryPass_DDEF!(u_type, i, Ratios[i], u_scale, MWs[i], Tgt_Vol, res_mass_mg, res_moles_mmol, is_fixed)
    end

    # Molar Percentage Components (%m, %)
    for i in 1:n
        if !is_fixed[i]
            u_str = lowercase(strip(Units[i]))
            if (u_str == "%m" || u_str == "%" || u_str == "%mol") && MWs[i] > 0
                res_moles_mmol[i] = total_moles_target_mmol * (Ratios[i] / 100.0)
                res_mass_mg[i]    = res_moles_mmol[i] * MWs[i]
                is_fixed[i]       = true
            end
        end
    end

    # Relative Molar/Stoichiometric Components
    fixed_moles_sum_mmol = sum(res_moles_mmol)
    residual_moles_mmol  = total_moles_target_mmol - fixed_moles_sum_mmol

    if residual_moles_mmol < -1e-7
        if !SuppressLog
            FAST_Log_DDEF("MOLE", "BUDGET_EXCEEDED", 
                "Molar budget overflow: sum of absolute components ($(round(fixed_moles_sum_mmol; digits=4)) mmol) exceeds target ($(round(total_moles_target_mmol; digits=4)) mmol).", "WARN")
        end
        residual_moles_mmol = 0.0
    end

    molar_indices = findall(.!is_fixed)
    if !isempty(molar_indices)
        total_molar_parts = sum(Ratios[molar_indices])
        total_molar_parts = abs(total_molar_parts) < 1e-9 ? 1.0 : total_molar_parts
        
        for i in molar_indices
            if MWs[i] > 0
                ratio_frac = Ratios[i] / total_molar_parts
                res_moles_mmol[i] = residual_moles_mmol * ratio_frac
                res_mass_mg[i]    = res_moles_mmol[i] * MWs[i]
            end
        end
    end

    final_ratios = total_moles_target_mmol > 0 ? (res_moles_mmol ./ total_moles_target_mmol) .* 100.0 : copy(Ratios)

    return DataFrame(
        :Component      => Names, 
        :Molar_Ratio    => final_ratios,
        :Moles_mmol     => res_moles_mmol, 
        :TARGET_MASS_mg => res_mass_mg, 
        :IsFixed        => is_fixed
    )
end

MOLE_ResolvePrimaryPass_DDEF!(::MOLE_UnitMass_DDES, i, r, s, mw, vol, rm, rmoles, fix) = (rm[i] = r * s; rmoles[i] = mw > 0 ? rm[i] / mw : 0.0; fix[i] = true)
MOLE_ResolvePrimaryPass_DDEF!(::MOLE_UnitConcentration_DDES, i, r, s, mw, vol, rm, rmoles, fix) = (rmoles[i] = (vol / 1000.0) * (r * s); rm[i] = mw > 0 ? rmoles[i] * mw : 0.0; fix[i] = true)
MOLE_ResolvePrimaryPass_DDEF!(::MOLE_AbstractStoicUnit_DDET, i, r, s, mw, vol, rm, rmoles, fix) = nothing

"""
    MOLE_AuditMatrix_DDEF(Design::AbstractMatrix, Names::AbstractVector, MWs::AbstractVector, Vol::Float64, Conc::Float64, Units::AbstractVector=fill("-", length(Names))) -> Vector{Float64}
Compute total gravimetric mass requirements for every individual run in an experimental design matrix.
Iterates across all design coordinate rows to evaluate run-by-run batch masses and detect gravimetric inconsistencies.

# Arguments
- `Design::AbstractMatrix`: Matrix of experimental runs (`N × k`).
- `Names::AbstractVector`: Ingredient identifiers.
- `MWs::AbstractVector`: Molecular weights in g/mol.
- `Vol::Float64`: Target batch volume in millilitres.
- `Conc::Float64`: Target concentration in millimolar.
- `Units::AbstractVector`: Physical unit strings for each ingredient.

# Returns
- `Vector{Float64}`: Array of total batch masses in milligrams for each experimental run.
"""
function MOLE_AuditMatrix_DDEF(Design::AbstractMatrix, Names::AbstractVector,
    MWs::AbstractVector, Vol::Float64, Conc::Float64, Units::AbstractVector=fill("-", length(Names)))
    R, K         = size(Design)
    total_masses = Vector{Float64}(undef, R)

    if K != length(Names)
        return zeros(R) 
    end

    names_s = Names isa AbstractVector{<:AbstractString} ? Names : String[string(x) for x in Names]
    mws_f   = MWs isa AbstractVector{Float64} ? MWs : Float64[Float64(FAST_SafeNum_DDEF(x)) for x in MWs]
    units_s = Units isa AbstractVector{<:AbstractString} ? Units : String[string(x) for x in Units]

    for i in 1:R
        ratios          = Design[i, :]
        df              = MOLE_CalcMass_DDEF(names_s, mws_f, ratios, Vol, Conc, units_s)
        total_masses[i] = sum(df.TARGET_MASS_mg)
    end
    
    return total_masses
end

# ------------------------------------------------------------------------------
# SECTION 10: MATRIX AUDIT & IMPOSSIBLE RUN DETECTION
# ------------------------------------------------------------------------------

"""
    MOLE_AuditBatch_DDEF(TableData::AbstractVector, Design::AbstractMatrix, Vol::Float64, Conc::Float64) -> Dict{String, Any}
Conduct a batch-wide stoichiometric feasibility assessment for an experimental design matrix.
Computes mass statistics across all candidate runs, identifies negative component quantities, and verifies budget feasibility.

# Arguments
- `TableData::AbstractVector`: Formulation table metadata.
- `Design::AbstractMatrix`: Coded or physical experimental design matrix.
- `Vol::Float64`: Batch volume in millilitres.
- `Conc::Float64`: Target batch concentration in millimolar.

# Returns
- `Dict{String, Any}`: Dictionary containing `"IsFeasible"`, `"AvgMass_mg"`, `"MaxMass_mg"`, `"MinMass_mg"`, `"StdDev_mg"`, and `"RunMasses"`.
"""
function MOLE_AuditBatch_DDEF(TableData::AbstractVector, Design::AbstractMatrix,
    Vol::Float64, Conc::Float64)
    D       = MOLE_ParseTable_DDEF(TableData)
    idx_var = D["Idx_Var"]
    idx_chem = D["Idx_Chem"]

    R, K = size(Design)

    if K != length(idx_var)
        return Dict(
            "IsFeasible" => false,
            "AvgMass_mg" => 0.0, 
            "MaxMass_mg" => 0.0, 
            "MinMass_mg" => 0.0, 
            "StdDev_mg"  => 0.0,
            "RunMasses"  => zeros(R)
        )
    end

    idx_fix  = D["Idx_Fix"]
    idx_fill = D["Idx_Fill"]

    masses = Vector{Float64}(undef, R)
    # Vector{Bool} avoids non-atomic BitVector word races under Threads.@threads.
    infeasible_flags = fill(false, R)
    Threads.@threads for i in 1:R
        ratios_full = zeros(length(D["Names"]))
        for (j, v_idx) in enumerate(idx_var)
            ratios_full[v_idx] = Design[i, j]
        end
        for f_idx in idx_fix
            ratios_full[f_idx] = D["Mids"][f_idx]
        end

        consumed_pct = 0.0
        for k in eachindex(ratios_full)
            ((!isempty(idx_fill) && k == idx_fill[1]) || D["MWs"][k] <= 0.0) && continue
            val = ratios_full[k]
            if !isfinite(val) || val < 0.0
                infeasible_flags[i] = true
                continue
            end
            u_str = string(get(D["Rows"][k], "Unit", "-"))
            mw    = D["MWs"][k]
            consumed_pct += MOLE_GetPercentageEquivalent_DDEF(val, u_str, mw, Vol, Conc)
        end

        if consumed_pct > 100.0 + 1e-4
            infeasible_flags[i] = true
        end

        if !isempty(idx_fill)
            ratios_full[idx_fill[1]] = max(0.0, 100.0 - consumed_pct)
        end

        r_chem = ratios_full[idx_chem]
        n_chem = D["Names"][idx_chem]
        w_chem = D["MWs"][idx_chem]
        u_chem = String[string(get(r, "Unit", "-")) for r in D["Rows"][idx_chem]]

        if isempty(idx_chem)
            masses[i] = 0.0
        else
            df        = MOLE_CalcMass_DDEF(
                Vector{String}(n_chem),
                Vector{Float64}(w_chem),
                Vector{Float64}(r_chem),
                Vol,
                Conc,
                Vector{String}(u_chem);
                SuppressLog=true
            )
            masses[i] = sum(df.TARGET_MASS_mg)
        end
    end

    avg_mass = isempty(masses) ? 0.0 : mean(masses)
    max_mass = isempty(masses) ? 0.0 : maximum(masses)
    min_mass = isempty(masses) ? 0.0 : minimum(masses)
    std_mass = length(masses) > 1 ? std(masses) : 0.0

    is_feasible = isempty(idx_chem) || (!any(infeasible_flags) && min_mass >= -1e-6 && avg_mass >= 0.0)

    return Dict(
        "IsFeasible" => is_feasible,
        "AvgMass_mg" => avg_mass,
        "MaxMass_mg" => max_mass,
        "MinMass_mg" => min_mass,
        "StdDev_mg"  => std_mass,
        "RunMasses"  => masses
    )
end

# ------------------------------------------------------------------------------
# SECTION 11: DESIGN FEASIBILITY VALIDATION
# ------------------------------------------------------------------------------

"""
    MOLE_ValidateFeasibility_DDEF(DesignMatrix::AbstractMatrix, InMeta::AbstractVector, Vol::Float64=100.0, Conc::Float64=10.0) -> Tuple{Bool, String}
Validate stoichiometric mass balance feasibility across all coordinate points of an experimental design.
Checks every design run for molar budget overconsumption and verifies that continuous factor levels do not generate negative quantities.

# Arguments
- `DesignMatrix::AbstractMatrix`: Physical experimental factor coordinates (`N × 3`).
- `InMeta::AbstractVector`: Ingredient metadata dictionaries with roles, units, and molecular weights.
- `Vol::Float64`: Batch volume in millilitres (default: `100.0`).
- `Conc::Float64`: Target concentration in millimolar (default: `10.0`).

# Returns
- `Tuple{Bool, String}`: `(is_valid, validation_report)` detailing any violating run indices.
"""
function MOLE_ValidateFeasibility_DDEF(DesignMatrix::AbstractMatrix, InMeta::AbstractVector, Vol::Float64=100.0, Conc::Float64=10.0)
    R      = size(DesignMatrix, 1)
    chems  = [m for m in InMeta if get(m, "Role", "") != "Result"]
    
    # Identify operational indices.
    var_indices   = findall(m -> get(m, "Role", "") == "Variable", chems)
    fill_index    = findfirst(m -> get(m, "Role", "") == "Filler", chems)
    fixed_indices = findall(m -> get(m, "Role", "") == "Fixed", chems)

    issues = String[]
    
    for i in 1:R
        ratios = zeros(length(chems))
        for (j, matrix_col) in enumerate(var_indices)
            ratios[matrix_col] = DesignMatrix[i, j]
        end
        for idx in fixed_indices
            ratios[idx] = FAST_SafeNum_DDEF(get(chems[idx], "L2", 0.0))
        end

        # Execute stoichiometric budget verification and non-negativity checks on chemical ingredients only.
        total_consumed_pct = 0.0
        has_neg_chem = false
        has_nonfinite = false
        for k in eachindex(chems)
            role = get(chems[k], "Role", "")
            mw   = FAST_SafeNum_DDEF(get(chems[k], "MW", 0.0))
            val  = ratios[k]
            if !isfinite(val)
                has_nonfinite = true
                continue
            end
            (role == "Filler" || mw <= 0.0) && continue
            val < 0.0 && (has_neg_chem = true)

            unit = string(get(chems[k], "Unit", "-"))
            total_consumed_pct += MOLE_GetPercentageEquivalent_DDEF(val, unit, mw, Vol, Conc)
        end

        has_nonfinite && push!(issues, "Run $i: Contains non-finite (NaN/Inf) coordinates.")
        if total_consumed_pct > 100.0 + 1e-4
            push!(issues, "Run $i: Stoichiometric budget overflow ($(round(total_consumed_pct; digits=2))%).")
        end
        has_neg_chem && push!(issues, "Run $i: Contains negative chemical gradients.")
    end

    valid = isempty(issues)
    msg   = valid ? "Stoichiometric feasibility confirmed for all runs." : join(unique(issues), " | ")

    return (valid, msg)
end

"""
    MOLE_ValidateProtocolInputs_DDEF(RawRows, StochSettings, Vol, Conc; CheckLevels=true, CheckBudget=true, EnforceBounds=false) -> Dict{String,Any}
Normalise ingredient rows, inject configured filler, validate factor counts, unique names,
physical units, monotonic factor levels, and upper-boundary molar budgets.
"""
function MOLE_ValidateProtocolInputs_DDEF(
    RawRows::AbstractVector,
    StochSettings::Union{AbstractDict,Nothing},
    Vol::Union{Real,AbstractString,Nothing},
    Conc::Union{Real,AbstractString,Nothing};
    CheckLevels::Bool=true,
    CheckBudget::Bool=true,
    EnforceBounds::Bool=false
)::Dict{String,Any}
    fail_res(msg::String) = Dict{String,Any}("Ok" => false, "Message" => msg)

    processed_rows = Dict{String,Any}[
        Dict{String,Any}(string(k) => v for (k, v) in pairs(r))
        for r in RawRows if string(FAST_SafeGet_DDEF(r, "Role", "")) != C.ROLE_FILL
    ]

    st_data = isnothing(StochSettings) ? Dict{String,Any}() : StochSettings
    f_name  = strip(string(FAST_SafeGet_DDEF(st_data, "FillerName", "")))
    f_mw    = FAST_SafeNum_DDEF(FAST_SafeGet_DDEF(st_data, "FillerMW", 0.0))
    if !isempty(f_name) && !isnan(f_mw) && f_mw > 0.0
        push!(processed_rows, Dict{String,Any}(
            "Name" => f_name, "Role" => C.ROLE_FILL, "MW" => f_mw,
            "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "Min" => 0.0, "Max" => 0.0,
            "Unit" => "%M", "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours"
        ))
    end

    D = MOLE_ParseTable_DDEF(processed_rows)
    num_vars  = length(D["Idx_Var"])
    num_fills = length(D["Idx_Fill"])
    num_vars != 3 && return fail_res("Requires exactly 3 Variable ingredients (Found: $num_vars).")
    num_fills > 1 && return fail_res("Maximum 1 Filler allowed (Found: $num_fills).")

    seen = Set{String}()
    for (i, r) in enumerate(D["Rows"])
        n = strip(string(get(r, "Name", "")))
        isempty(n) && return fail_res("Systematic Error: Ingredient name for row $(i) cannot be empty.")
        n in seen && return fail_res("Systematic Error: Ingredient names must be unique. '$(n)' is repeated.")
        push!(seen, n)

        unit = string(get(r, "Unit", ""))
        mw_v = FAST_SafeNum_DDEF(get(r, "MW", 0.0))
        mw   = isnan(mw_v) ? 0.0 : mw_v
        if mw > 0.0 && !isempty(unit) && unit != "-"
            u_type, _ = MOLE_GetUnitType_DDEF(unit)
            if u_type isa MOLE_UnitOther_DDES
                ok_m, _, _ = MOLE_ValidatePhysicalUnit_DDEF(unit, "Mass")
                ok_c, _, _ = MOLE_ValidatePhysicalUnit_DDEF(unit, "Concentration")
                (!ok_m && !ok_c) && return fail_res("Unit Error: Ingredient '$n' has invalid chemical unit '$unit'.")
            end
        end

        if CheckLevels && get(r, "Role", "") == C.ROLE_VAR
            l1 = FAST_SafeNum_DDEF(get(r, "L1", 0.0))
            l2 = FAST_SafeNum_DDEF(get(r, "L2", 0.0))
            l3 = FAST_SafeNum_DDEF(get(r, "L3", 0.0))
            if !(isfinite(l1) && isfinite(l2) && isfinite(l3))
                return fail_res("Systematic Error: Levels for '$n' (Variable) must be finite numbers.")
            end
            if EnforceBounds
                mn_v = FAST_SafeNum_DDEF(get(r, "Min", 0.0))
                mx_v = FAST_SafeNum_DDEF(get(r, "Max", 0.0))
                minv = isnan(mn_v) ? 0.0 : mn_v
                maxv = isnan(mx_v) ? 0.0 : mx_v
                if l1 < minv || l3 > maxv || l1 > l2 || l2 > l3
                    return fail_res("Audit Failed: Variable '$n' must strictly obey Min <= Low <= Centre <= High <= Max boundary logic. (Got: $minv <= $l1 <= $l2 <= $l3 <= $maxv)")
                end
            elseif !(l1 < l2 && l2 < l3)
                return fail_res("Systematic Error: Levels for '$n' (Variable) must show a strict increase (LOWER $l1 < CENTRE $l2 < UPPER $l3).")
            end
        end
    end

    sv_raw = FAST_SafeNum_DDEF(Vol)
    sc_raw = FAST_SafeNum_DDEF(Conc)
    sv = isnan(sv_raw) ? 0.0 : Float64(sv_raw)
    sc = isnan(sc_raw) ? 0.0 : Float64(sc_raw)
    has_stoic_env = sv > 0.0 && sc > 0.0

    if CheckBudget && has_stoic_env && (!isempty(D["Idx_Chem"]) || !isempty(D["Idx_Fill"]))
        sum_max_pct = 0.0
        for r in D["Rows"]
            mw   = FAST_SafeNum_DDEF(get(r, "MW", 0.0))
            unit = string(get(r, "Unit", "-"))
            role = get(r, "Role", "")
            val  = (role == C.ROLE_VAR) ? FAST_SafeNum_DDEF(get(r, "L3", 0.0)) : FAST_SafeNum_DDEF(get(r, "L2", 0.0))
            sum_max_pct += MOLE_GetPercentageEquivalent_DDEF(val, unit, mw, sv, sc)
        end
        if sum_max_pct > 100.0 + 1e-4
            return fail_res("Stoichiometry Error: Total molar budget exceeded at upper boundaries (Sum: $(round(sum_max_pct; digits=2))%). Please adjust limits, volume, or concentration.")
        end
    end

    return Dict{String,Any}(
        "Ok"            => true,
        "Message"       => "OK",
        "ProcessedRows" => processed_rows,
        "Parsed"        => D,
        "Vol"           => sv,
        "Conc"          => sc,
        "HasStoicEnv"   => has_stoic_env
    )
end

# ==============================================================================
# PART D: EXPERIMENTAL PROTOCOL MACROS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 12: DESIGN MATRIX EXPANSION
# ------------------------------------------------------------------------------

"""
    MOLE_ProcessDesign_DDEF(DesignMatrix::AbstractMatrix, TableData::AbstractVector, Vol::Float64, Conc::Float64) -> DataFrame
Translate a design matrix into a fully specified laboratory protocol worksheet with mass balance calculations.
Constructs standardised input, fixed, and filler column headers while resolving run-by-run masses and residual volumes.

# Arguments
- `DesignMatrix::AbstractMatrix`: Physical coordinate matrix (`N × 3`).
- `TableData::AbstractVector`: Formulation component rows.
- `Vol::Float64`: Total formulation volume in millilitres.
- `Conc::Float64`: Total concentration in millimoles per litre.

# Returns
- `DataFrame`: Complete experimental protocol table ready for execution and Excel workbook export.
"""
function MOLE_ProcessDesign_DDEF(DesignMatrix::AbstractMatrix, TableData::AbstractVector, Vol::Float64, Conc::Float64)
    D = MOLE_ParseTable_DDEF(TableData)
    R, C_dim = size(DesignMatrix)
    
    df = DataFrame()
    
    # Generation of variable column headers.
    for (k, v_idx) in enumerate(D["Idx_Var"])
        u = string(get(D["Rows"][v_idx], "Unit", ""))
        h = (isempty(u) || u == "-") ? C.PRE_VAR * D["Names"][v_idx] : C.PRE_VAR * D["Names"][v_idx] * "_" * u
        df[!, h] = DesignMatrix[:, k]
    end
    
    # Generation of fixed component headers.
    for idx in D["Idx_Fix"]
        u = string(get(D["Rows"][idx], "Unit", ""))
        h = (isempty(u) || u == "-") ? C.PRE_FIXED * D["Names"][idx] : C.PRE_FIXED * D["Names"][idx] * "_" * u
        df[!, h] = fill(FAST_SafeNum_DDEF(D["Rows"][idx]["L2"]), R)
    end
    
    # Generation of system filler headers.
    for idx in D["Idx_Fill"]
        u = string(get(D["Rows"][idx], "Unit", ""))
        h = (isempty(u) || u == "-") ? C.PRE_FILL * D["Names"][idx] : C.PRE_FILL * D["Names"][idx] * "_" * u
        df[!, h] = fill(0.0, R)
    end

    # Execution of runtime computations for mass and molar resolution.
    mass_cols = Dict{String, Vector{Float64}}()
    
    for i in 1:R
        current_ratios = zeros(length(D["Names"]))
        for (k, v_idx) in enumerate(D["Idx_Var"])
            current_ratios[v_idx] = DesignMatrix[i, k]
        end
        for idx in D["Idx_Fix"]
            current_ratios[idx] = FAST_SafeNum_DDEF(D["Rows"][idx]["L2"])
        end
    
        if !isempty(D["Idx_Fill"])
            consumed_pct = 0.0
            for r_idx in D["Idx_Chem"]
                (r_idx == D["Idx_Fill"][1] || D["MWs"][r_idx] <= 0.0) && continue
                val  = current_ratios[r_idx]
                unit = string(get(D["Rows"][r_idx], "Unit", "-"))
                mw   = D["MWs"][r_idx]
                consumed_pct += MOLE_GetPercentageEquivalent_DDEF(val, unit, mw, Vol, Conc)
            end
            
            f_idx = D["Idx_Fill"][1]
            f_val = max(0.0, 100.0 - consumed_pct)
            current_ratios[f_idx] = f_val
            
            u = string(get(D["Rows"][f_idx], "Unit", ""))
            h = (isempty(u) || u == "-") ? C.PRE_FILL * D["Names"][f_idx] : C.PRE_FILL * D["Names"][f_idx] * "_" * u
            df[i, h] = f_val
        end
        
        chems = D["Idx_Chem"]
        units = String[string(get(r, "Unit", "-")) for r in D["Rows"][chems]]
        m_df  = MOLE_CalcMass_DDEF(
            Vector{String}(D["Names"][chems]),
            Vector{Float64}(D["MWs"][chems]),
            Vector{Float64}(current_ratios[chems]),
            Vol,
            Conc,
            Vector{String}(units)
        )
        
        for r in eachrow(m_df)
            k = C.PRE_MASS * r.Component * "_mg"
            haskey(mass_cols, k) || (mass_cols[k] = zeros(R))
            mass_cols[k][i] = r.TARGET_MASS_mg
        end
    end
    for (ckey, cval) in mass_cols
        df[!, ckey] = cval
    end
    
    return df
end
end