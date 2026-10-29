# ---------------------

using DataFrames
using Printf
using Dash
using Logging
using LoggingExtras

# ---------------------

"""
    CALL_ResolvePort_DDEF(port::Int) -> Int
Direct passthrough dispatch when an explicit port integer is provided.
"""
CALL_ResolvePort_DDEF(port::Int)::Int = port

"""
    CALL_ResolvePort_DDEF(::Nothing=nothing) -> Int
Resolve target HTTP listening port from environment overrides (ENV["PORT"]), cloud identifiers (SPACE_ID), or fallback to 8060.
"""
function CALL_ResolvePort_DDEF(::Nothing=nothing)::Int
    haskey(ENV, "PORT")     && return parse(Int, ENV["PORT"])
    haskey(ENV, "SPACE_ID") && return 7860
    return 8060
end

"""
    launch(; host="0.0.0.0", port=nothing, debug=false, open_browser=true, wait=false, start_server=true) -> Union{Nothing, Task, Dash.DashApp}

Launch the DoECISORY interactive web application in-process within the active Julia session.
Initialises the experimental design formulation workspace (Deck) alongside the response surface analysis suite (Lens).

# Keywords
- `host::String`: Host network interface address to bind (default: `"0.0.0.0"`).
- `port::Union{Int, Nothing}`: Network port to bind (default: `8060` or `7860` on Hugging Face Spaces).
- `debug::Bool`: Enables Dash developer hot-reloading and debug tools (default: `false`).
- `open_browser::Bool`: Automatically launches the default web browser upon startup (default: `true`).
- `wait::Bool`: Blocks the calling process until the web server is terminated (default: `false`).
- `start_server::Bool`: Whether to bind and launch the HTTP server (default: `true`). When `false`, returns the configured `DashApp` instance without opening sockets.

# Returns
- `Nothing` when `wait=true`, the background server `Task` when `wait=false`, or `DashApp` when `start_server=false`.

# Examples
```julia
using DoECISORY
launch()
```
"""
function CALL_Launch_DDEF(; host::String="0.0.0.0", port::Union{Int, Nothing}=nothing, debug::Bool=false, open_browser::Bool=true, wait::Bool=false, start_server::Bool=true, SuppressBanner::Bool=false)
    let
        base_tmp = tempdir()
        wf_path  = endswith(rstrip(base_tmp, ['/', '\\']), "DoECISORY_Workforce") ? base_tmp : joinpath(base_tmp, "DoECISORY_Workforce")
        if !isdir(wf_path)
            mkpath(wf_path)
        end
        ENV["TMP"]                    = wf_path
        ENV["TEMP"]                   = wf_path
        ENV["TMPDIR"]                 = wf_path
        ENV["CHROME_USER_DATA_DIR"]   = wf_path
        ENV["CHROME_CRASH_DUMPS_DIR"] = wf_path
    end

    ENV["GKSwstype"]               = "100"
    ENV["JULIA_WEBIO_NOT_AVAILABLE"] = "1"
    ENV["PLOTLY_KALEIDO_NO_SANDBOX"] = "1"

    FAST_InitialiseWorkforce_DDEF()

    if !SuppressBanner
        let (n_threads, _, _) = FAST_GetThreadInfo_DDEF()
            status = n_threads > 1 ? "[OPTIMAL]" : "[LIMITED]"

            println("\e[1m                  \e[32m_\e[0m")
            println("\e[1m      \e[34m_\e[0m       _ \e[31m_\e[32m(_)\e[35m_\e[0m     |")
            println("\e[1m     \e[34m(_)\e[0m     | \e[31m(_)\e[0m \e[35m(_)\e[0m    |  \e[1mDoECISORY\e[0m $(FAST_Data_DDEC.VERSION)")
            println("\e[1m      _ _   _| |_  __ _   |  System Status: $status\e[0m")
            println("\e[1m     | | | | | | |/ _` |  |  Author: E.S. GÖL, MPharm")
            println("\e[1m     | | |_| | | | (_| |  |  Department of Radiopharmacy")
            println("\e[1m    _/ |\\__'_|_|_|\\__'_|  |  Hacettepe University. 2026.")
            println("\e[1m   |__/                   |")

            println("\n\e[1m[ComputeCores] \e[0m\e[32m$n_threads Threads\e[0m")
            println("\e[1m[SystemWisdom] \e[0m\e[35m\"$(FAST_GetSystemQuote_DDEF())\"\e[0m\n")
        end
    end

    is_hf = haskey(ENV, "SPACE_ID")
    target_port = CALL_ResolvePort_DDEF(port)

    pkg_root = something(pkgdir(@__MODULE__), dirname(@__DIR__))
    assets_path = isdir(joinpath(pkg_root, "assets")) ? normpath(joinpath(pkg_root, "assets")) : ""

    app = BASE_CreateApp_DDEF(; assets_folder = assets_path)

    BASE_RegisterAppCallbacks_DDEF(app)
    DECK_RegisterCallbacks_DDEF(app)
    LENS_RegisterCallbacks_DDEF(app)

    if start_server
        Threads.@spawn BASE_WarmupApp_DDEF()
    end

    is_dev = get(ENV, "DOECISORY_DEV", "false") == "true"
    should_open_browser = start_server && open_browser && !is_hf && !is_dev && get(ENV, "DOECISORY_NO_BROWSER", "false") != "true"

    if should_open_browser
        @async begin
            t0 = time()
            target_ip = (host == "0.0.0.0" || isempty(host)) ? "127.0.0.1" : host
            while time() - t0 < 60.0
                sleep(0.25)
                try
                    sock = Dash.HTTP.Sockets.connect(target_ip, target_port)
                    close(sock)
                    break
                catch
                end
            end
            try
                if Sys.iswindows()
                    run(`cmd /c start http://127.0.0.1:$(target_port)`; wait=false)
                    sleep(0.5)
                    run(`powershell -NoProfile -NonInteractive -Command "(New-Object -ComObject WScript.Shell).AppActivate('DoECISORY')"`; wait=false)
                elseif Sys.isapple()
                    run(`open http://127.0.0.1:$(target_port)`; wait=false)
                else
                    run(`xdg-open http://127.0.0.1:$(target_port)`; wait=false)
                end
            catch
            end
        end
    end

    env_label = is_hf ? "Cloud (HF Spaces)" : "Local $(Threads.nthreads())T"
    FAST_Log_DDEF("SERVER", "Ready", "DoECISORY listening on :$(target_port) ($env_label)", "OK")

    custom_logger = ActiveFilteredLogger(current_logger()) do rec
        if rec.level == Logging.Error && contains(string(rec.message), "operation canceled")
            FAST_Log_DDEF("SERVER", "Disconnect", "Connection reset by browser (ECANCELED)", "INFO")
            return false
        end
        return true
    end

    if !start_server
        return app
    end

    server_task = () -> with_logger(custom_logger) do
        run_server(app, host, target_port; debug=debug)
    end

    if wait
        server_task()
        return nothing
    else
        return @async server_task()
    end
end

const launch = CALL_Launch_DDEF

# ---------------------

struct CALL_Design_DDES
    type::Symbol
    factors::Vector{String}
    levels::Vector{Tuple{Float64, Float64, Float64}}
    limits::Vector{Tuple{Float64, Float64}}
    coded_matrix::Matrix{Float64}
    matrix::Matrix{Float64}
    dataframe::DataFrame
    metrics::Dict{String, Float64}
end

"""
    design(method::Symbol=:bb15; factors=nothing, levels=nothing, limits=nothing, direction=[-1, -1, -1]) -> CALL_Design_DDES

Construct an experimental design plan for response surface methodology, screening, or directional optimization.
Translates dimensionless coded coordinates into physical laboratory formulations via piecewise linear interpolation.

# Arguments
- `method::Symbol`: Topology identifier (`:bb15` for Box-Behnken, `:cd17` for Central Composite, `:tl09` for Taguchi L9, or `:df14` for Directional Fractional CCD). Default is `:bb15`.

# Keywords
- `factors`: Vector of factor names (default: `["X1", "X2", "X3"]`).
- `levels`: Vector of 3-element tuples `(L1, L2, L3)` representing lower (-1), centre (0), and upper (+1) physical levels for each factor.
- `limits`: Optional vector of 2-element tuples `(Min, Max)` defining physical process operating constraints.
- `direction`: Axial search vector for directional designs such as `:df14` (default: `[-1, -1, -1]`).

# Returns
- `CALL_Design_DDES`: Structured design plan containing factor metadata, coded coordinates, real physical matrix, execution `DataFrame`, and optimality efficiency metrics.

# Examples
```julia
using DoECISORY
plan = design(:bb15;
    factors = ["Temperature", "Time", "Precursor"],
    levels  = [(60.0, 90.0, 120.0), (5.0, 15.0, 25.0), (15.0, 25.0, 35.0)]
)
show(stdout, MIME("text/plain"), plan.dataframe; allrows=true)
```
"""
function CALL_Design_DDEF(
    method::Symbol=:bb15;
    factors::Union{AbstractVector{<:AbstractString}, Nothing}=nothing,
    levels::Union{AbstractVector, Nothing}=nothing,
    limits::Union{AbstractVector, Nothing}=nothing,
    direction::AbstractVector=[-1, -1, -1]
)::CALL_Design_DDES
    factor_names = if isnothing(factors)
        ["X1", "X2", "X3"]
    else
        [string(f) for f in factors]
    end
    length(factor_names) != 3 && throw(ArgumentError("DoECISORY response surface designs require exactly 3 factors."))

    norm_levels = Tuple{Float64, Float64, Float64}[]
    if isnothing(levels)
        for _ in 1:3
            push!(norm_levels, (-1.0, 0.0, 1.0))
        end
    else
        length(levels) != 3 && throw(ArgumentError("Levels vector must specify exactly 3 factor specifications."))
        for item in levels
            length(item) != 3 && throw(ArgumentError("Each factor level specification must contain exactly 3 levels: (L1, L2, L3)."))
            push!(norm_levels, (Float64(item[1]), Float64(item[2]), Float64(item[3])))
        end
    end

    norm_limits = Tuple{Float64, Float64}[]
    if isnothing(limits)
        for i in 1:3
            push!(norm_limits, (norm_levels[i][1], norm_levels[i][3]))
        end
    else
        length(limits) != 3 && throw(ArgumentError("Limits vector must specify bounds for exactly 3 factors."))
        for item in limits
            push!(norm_limits, (Float64(item[1]), Float64(item[2])))
        end
    end

    method_str = uppercase(string(method))
    raw_coded = Float64.(CORE_GenDesign_DDEF(method_str, 3; Direction=direction))

    configs = [Dict("Levels" => [norm_levels[i][1], norm_levels[i][2], norm_levels[i][3]]) for i in 1:3]
    real_matrix = CORE_MapLevels_DDEF(raw_coded, configs)
    metrics = CORE_CalcDesignMetrics_DDEF(raw_coded)

    df = DataFrame()
    for (idx, name) in enumerate(factor_names)
        df[!, Symbol(name)] = real_matrix[:, idx]
    end

    return CALL_Design_DDES(
        method,
        factor_names,
        norm_levels,
        norm_limits,
        raw_coded,
        real_matrix,
        df,
        metrics
    )
end

const design = CALL_Design_DDEF

function Base.show(io::IO, d::CALL_Design_DDES)
    println(io, "DoECISORY ExperimentDesign [$(uppercase(string(d.type)))]")
    println(io, "  Runs: $(size(d.matrix, 1))")
    println(io, "  Factors:")
    for i in 1:length(d.factors)
        l1, l2, l3 = d.levels[i]
        println(io, "    • $(d.factors[i]): L1=$l1, L2=$l2, L3=$l3")
    end
    d_eff = get(d.metrics, "D", get(d.metrics, "D_Efficiency", 0.0))
    print(io, "  D-Efficiency: $(round(d_eff * 100.0; digits=2))%")
end
# ---------------------