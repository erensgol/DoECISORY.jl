# ==============================================================================
# DoECISORY Code Coverage Runner & Summary Reporter
# ==============================================================================
# Description: Executes automated test suite with line-by-line coverage and
#              computes AST-based metrics matching Codecov.io standards.
# ==============================================================================

using Printf
using Logging
using Dates

const COVERAGE_START_TIME = time()
const COVERAGE_ROOT_DIR   = normpath(joinpath(@__DIR__, ".."))
const SRC_DIR             = joinpath(COVERAGE_ROOT_DIR, "src")

# Pre-load Coverage.jl AST engine (loaded from global environment if available)
const HAS_COVERAGE_PKG = try
    @eval using Coverage
    true
catch
    false
end

function cleanup_cov_files()
    isdir(COVERAGE_ROOT_DIR) || return nothing
    for (root, _, files) in walkdir(COVERAGE_ROOT_DIR)
        for f in files
            if endswith(f, ".cov")
                rm(joinpath(root, f); force=true)
            end
        end
    end
end

cleanup_cov_files()

tablo1_lines = String[]
println("[INFO] Executing DoECISORY automated test suite with coverage enabled...")
try
    test_file = joinpath(COVERAGE_ROOT_DIR, "test", "runtests.jl")
    cmd = `$(Base.julia_cmd()) --color=yes --depwarn=no --threads=auto --code-coverage=user --project=$COVERAGE_ROOT_DIR $test_file`
    proc = open(cmd, "r")
    is_capturing = false
    for line in eachline(proc)
        println(line)
        if occursin("DoECISORY TEST SUITE REPORT", line)
            is_capturing = true
        end
        if is_capturing
            push!(tablo1_lines, line)
            if startswith(line, "==========================================================================================") && length(tablo1_lines) > 2
                is_capturing = false
            end
        end
    end
    close(proc)
catch e
    println("\n[ERROR] Test suite execution failed: ", e)
end

println("\n[INFO] Analysing source coverage metrics via $(HAS_COVERAGE_PKG ? "Coverage.jl" : "Direct Analysis")...")
if !HAS_COVERAGE_PKG
    println("  [NOTICE] Coverage.jl is not detected in environment. Using Direct Analysis fallback.")
    println("  To preserve DoECISORY's lightweight dependencies, Coverage is not bundled in Project.toml.")
    println("  To enable AST-based metrics matching Codecov, install Coverage once globally:")
    println("    julia -e 'using Pkg; Pkg.add(\"Coverage\")'\n")
end

struct FileCoverageSummary
    filename::String
    covered::Int
    total::Int
    missed_lines::Vector{Int}
    line_hits::Vector{Pair{Int, Int}}
end

function format_line_intervals(lines::Vector{Int})::String
    isempty(lines) && return "-"
    intervals = String[]
    s = lines[1]
    e = s
    for i in 2:length(lines)
        if lines[i] == e + 1
            e = lines[i]
        else
            push!(intervals, s == e ? "L$s" : "L$s-$e")
            s = lines[i]
            e = s
        end
    end
    push!(intervals, s == e ? "L$s" : "L$s-$e")
    return join(intervals, ", ")
end

function collect_source_coverage(src_dir::String)::Vector{FileCoverageSummary}
    if HAS_COVERAGE_PKG
        processed = with_logger(NullLogger()) do
            Coverage.process_folder(src_dir)
        end
        results = FileCoverageSummary[]
        for f in processed
            rel_name = relpath(f.filename, src_dir)
            cov, tot = Coverage.get_summary(f)
            missed = Int[]
            hits = Pair{Int, Int}[]
            if isdefined(f, :coverage) && !isnothing(f.coverage)
                for (idx, c) in enumerate(f.coverage)
                    if c !== nothing
                        if c == 0
                            push!(missed, idx)
                        elseif c >= 500
                            push!(hits, idx => c)
                        end
                    end
                end
            end
            push!(results, FileCoverageSummary(rel_name, cov, tot, missed, hits))
        end
        sort!(results; by = x -> x.filename)
        return results
    else
        # Fallback in environments without Coverage.jl package
        file_map = Dict{String, Vector{Union{Int, Nothing}}}()
        for (root, _, files) in walkdir(src_dir)
            for f in files
                if endswith(f, ".cov")
                    cov_path = joinpath(root, f)
                    orig_name = replace(f, r"\.[0-9]+\.cov$" => "")
                    orig_name = replace(orig_name, r"\.cov$" => "")
                    lines = readlines(cov_path)
                    if !haskey(file_map, orig_name)
                        file_map[orig_name] = Vector{Union{Int, Nothing}}(fill(nothing, length(lines)))
                    end
                    counts = file_map[orig_name]
                    if length(lines) > length(counts)
                        append!(counts, fill(nothing, length(lines) - length(counts)))
                    end
                    for (idx, line) in enumerate(lines)
                        if length(line) >= 9
                            cnt_str = strip(line[1:9])
                            if cnt_str != "-" && !isempty(cnt_str)
                                cnt = tryparse(Int, cnt_str)
                                if !isnothing(cnt)
                                    curr = counts[idx]
                                    counts[idx] = isnothing(curr) ? cnt : (curr + cnt)
                                end
                            end
                        end
                    end
                end
            end
        end
        results = FileCoverageSummary[]
        for (fname, line_counts) in sort(collect(file_map); by=first)
            tot = count(!isnothing, line_counts)
            cov = count(x -> !isnothing(x) && x > 0, line_counts)
            missed = Int[]
            hits = Pair{Int, Int}[]
            for (idx, c) in enumerate(line_counts)
                if !isnothing(c)
                    if c == 0
                        push!(missed, idx)
                    elseif c >= 500
                        push!(hits, idx => c)
                    end
                end
            end
            push!(results, FileCoverageSummary(fname, cov, tot, missed, hits))
        end
        return results
    end
end

cov_results = collect_source_coverage(SRC_DIR)
const COVERAGE_DURATION = round(time() - COVERAGE_START_TIME; digits=2)

try
    let
        total_covered = sum(item.covered for item in cov_results; init=0)
        total_lines   = sum(item.total for item in cov_results; init=0)
        total_missed  = total_lines - total_covered
        tot_pct       = total_lines > 0 ? round((total_covered / total_lines) * 100.0; digits=1) : 0.0

        println("\n" * "="^90)
        println(" "^30 * "DoECISORY CODE COVERAGE REPORT" * " "^30)
        println("="^90)
        @printf("  %-56s %5s  %6s  %6s  %8s\n", "Source File", "Total", "Hit", "Missed", "Coverage")
        println("-"^90)

        for item in cov_results
            missed = item.total - item.covered
            pct = item.total > 0 ? round((item.covered / item.total) * 100.0; digits=1) : 0.0
            @printf("  %-56s %5d  %6d  %6d  %7.1f%%\n", item.filename, item.total, item.covered, missed, pct)
        end

        println("-"^90)

        bar_width = 46
        filled = total_lines > 0 ? clamp(round(Int, (total_covered / total_lines) * bar_width), 0, bar_width) : 0
        empty_slots = bar_width - filled
        bar_str = "="^filled * " "^empty_slots

        @printf("  PROGRESS    : [%s] %5.1f%%\n", bar_str, tot_pct)
        @printf("  SUMMARY     : %d / %d lines covered (%d missed)\n", total_covered, total_lines, total_missed)
        @printf("  DURATION    : %.1f seconds\n", COVERAGE_DURATION)
        @printf("  TOTAL SCORE : %.1f%%\n", tot_pct)
        println("="^90 * "\n")

        # ----------------------------------------------------------------------
        # Test Suite & Code Coverage Report (test/test_report.txt)
        # ----------------------------------------------------------------------
        report_path = joinpath(COVERAGE_ROOT_DIR, "test", "test_report.txt")
        open(report_path, "w") do io
            println(io, "="^90)
            println(io, " "^30 * "DoECISORY TEST REPORT" * " "^30)
            println(io, "="^90)
            println(io, "  Timestamp : ", Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))
            println(io, "-"^90)
            println(io)

            if !isempty(tablo1_lines)
                println(io, "[SECTION 1: TEST SUITE EXECUTION]")
                println(io, "-"^90)
                found_header = false
                for l in tablo1_lines
                    if occursin("Domain Group", l)
                        found_header = true
                    end
                    if found_header && !startswith(l, "===")
                        clean_l = replace(l, r"\e\[[0-9;]*m" => "")
                        println(io, clean_l)
                    end
                end
                println(io, "-"^90)
                println(io)
            end

            println(io, "[SECTION 2: CODE COVERAGE PER MODULE]")
            println(io, "-"^90)
            @printf(io, "  %-56s %5s  %6s  %6s  %8s\n", "Source File", "Total", "Hit", "Missed", "Coverage")
            println(io, "-"^90)
            for item in cov_results
                missed = item.total - item.covered
                pct = item.total > 0 ? round((item.covered / item.total) * 100.0; digits=1) : 0.0
                @printf(io, "  %-56s %5d  %6d  %6d  %7.1f%%\n", item.filename, item.total, item.covered, missed, pct)
            end
            println(io, "-"^90)
            @printf(io, "  PROGRESS    : [%s] %5.1f%%\n", bar_str, tot_pct)
            @printf(io, "  SUMMARY     : %d / %d lines covered (%d missed)\n", total_covered, total_lines, total_missed)
            @printf(io, "  DURATION    : %.1f seconds\n", COVERAGE_DURATION)
            @printf(io, "  TOTAL SCORE : %.1f%%\n", tot_pct)
            println(io, "-"^90)
            println(io)

            println(io, "[SECTION 3: UNCOVERED LINE INTERVALS]")
            println(io, "-"^90)
            @printf(io, "  %-24s %6s   %s\n", "Source File", "Missed", "Line Intervals")
            println(io, "-"^90)
            for item in cov_results
                missed_cnt = item.total - item.covered
                missed_cnt == 0 && continue
                int_str = format_line_intervals(item.missed_lines)
                @printf(io, "  %-24s %6d   %s\n", item.filename, missed_cnt, int_str)
            end
            println(io, "-"^90)
            println(io)

            println(io, "[SECTION 4: EXECUTION FREQUENCY (LINES >= 500 HITS)]")
            println(io, "-"^90)
            
            hotspots = Tuple{Int, String, Int, String}[]
            for item in cov_results
                src_path = joinpath(SRC_DIR, item.filename)
                src_lines = isfile(src_path) ? readlines(src_path) : String[]
                for (line_idx, cnt) in item.line_hits
                    snippet = line_idx <= length(src_lines) ? strip(src_lines[line_idx]) : ""
                    push!(hotspots, (cnt, item.filename, line_idx, snippet))
                end
            end
            sort!(hotspots; by = x -> x[1], rev = true)

            if isempty(hotspots)
                println(io, "  No execution hotspots detected above threshold (all lines < 500 hits).")
            else
                @printf(io, "  %-6s  %-20s %-8s  %s\n", "Hits", "Source File", "Line", "Code Expression")
                println(io, "-"^90)
                for (cnt, fname, line_idx, snip) in hotspots
                    disp_snip = length(snip) > 50 ? (first(snip, 47) * "...") : snip
                    @printf(io, "  %-6d  %-20s L%-7d  %s\n", cnt, fname, line_idx, disp_snip)
                end
            end
            println(io, "-"^90)
            println(io, "\n" * "="^90)
            println(io, "  END OF REPORT — Generated by DoECISORY")
            println(io, "="^90)
        end
        println("[INFO] Audit report overwritten to: test/test_report.txt")
    end
finally
    cleanup_cov_files()
end
