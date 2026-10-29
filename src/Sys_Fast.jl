module Sys_Fast

# ==============================================================================
# DOECISORY - SYSTEM FAST (IO & UTILS)
# ==============================================================================
# Description: High-speed I/O (Excel/XLSX), system-wide logging, and transient 
#              data orchestration.
# Module Tag:  FAST
# ==============================================================================

using Dates
using Printf
using XLSX
using ZipFile
using DataFrames
using JSON3
using Base64

export FAST_Log_DDEF, FAST_ReadExcel_DDEF, FAST_Catalogue_DDES, FAST_SafeNum_DDEF,
       FAST_GetLabDefaults_DDEF, FAST_InitialiseMaster_DDEF, FAST_SanitiseColumnNames_DDEF!,
       FAST_SanitiseJSON_DDEF, FAST_PrepareDownload_DDEF, FAST_GenSmartName_DDEF,
       FAST_ExtractProjectName_DDEF, FAST_GetTransientPath_DDEF, FAST_ReadToStore_DDEF,
       FAST_UpdateConfig_DDEF, FAST_GetThreadInfo_DDEF, FAST_ResetConfigCache_DDEF,
       FAST_SanitiseInput_DDEF, FAST_AcquireLock_DDEF, FAST_ReleaseLock_DDEF, FAST_ForceReleaseAll_DDEF,
       FAST_ReadCache_DDEF, FAST_WriteCache_DDEF, FAST_ResetCache_DDEF, FAST_WriteVault_DDEF,
       FAST_ReadVault_DDEF, FAST_GetComputeThreads_DDEF, FAST_WriteExcel_DDEF, FAST_CleanTransient_DDEF, 
       FAST_FormatDuration_DDEF, FAST_ValidateDataFrame_DDEF, FAST_GetSystemQuote_DDEF, 
       FAST_RoundColumns_DDEF!, FAST_GetColumn_DDEF, FAST_SanitiseHeader_DDEF, FAST_FormatDisplayHeader_DDEF, 
       FAST_InitialiseWorkforce_DDEF, FAST_CleanWorkforce_DDEF, FAST_Data_DDEC, FAST_SanitiseFilename_DDEF,
       FAST_ReadMemoFile_DDEF, FAST_ExtractDataID_DDEF, FAST_ValidateSheetStructure_DDEF, 
       FAST_FinaliseMasterWrite_DDEF, FAST_ActiveGroup_DDEC, FAST_ApplyExcelStyle_DDEF, 
       FAST_FormatConditionNumber_DDEF, FAST_SortColumns_DDEF, FAST_ExtractPhaseNumber_DDEF,
       FAST_ParseDirection_DDEF, FAST_FormatColumn_DDEF, FAST_ReadConfig_DDEF, FAST_SafeGet_DDEF,
       FAST_CacheLock_DDEC, FAST_CacheStore_DDEC, FAST_LockGuard_DDEC, FAST_OperationLocks_DDEC,
       FAST_ExtractDirections_DDEF, FAST_DecodeDirections_DDEF, FAST_TempRoot_DDEC, FAST_IsNumericInput_DDEF,
       FAST_IsPopulatedInput_DDEF, FAST_WrapDetail_DDEF, FAST_AssembleSvgPlate_DDEF,
       FAST_DetectPhaseMethod_DDEF, FAST_DetectActivePhase_DDEF, FAST_ResolveModelOptions_DDEF

# ==============================================================================
# PART A: TRANSIENT WORKFORCE
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: SYSTEM-WIDE CONSTANTS & COLOURS
# ------------------------------------------------------------------------------

"""
    FAST_Catalogue_DDES
System-wide configuration, metadata structure, and primary colour palettes.
"""
Base.@kwdef struct FAST_Catalogue_DDES
    VERSION::String        = "v0.2.0"
    COLOUR_PURWHI::String  = "#FFFFFF"
    COLOUR_LIGHIG::String  = "#E6E6E6"
    COLOUR_LIGLOW::String  = "#DCDCDC"
    COLOUR_DARLOW::String  = "#A6A6A6"
    COLOUR_DARHIG::String  = "#666666"
    COLOUR_PURBLA::String  = "#000000"
    COLOUR_HUERED::String  = "#FF0000"
    COLOUR_SHAMAG::String  = "#440154"
    COLOUR_SHABLU::String  = "#3B528B"
    COLOUR_TONCYA::String  = "#21918C"
    COLOUR_TONGRE::String  = "#5EC962"
    COLOUR_HUEYEL::String  = "#FDE725"
    COLOUR_INFORG::String  = "#BB4722"
    FONT_DEFAULT::String   = "Inter, sans-serif"
    SHEET_DATA::String     = "DATA"
    SHEET_CONFIG::String   = "CONFIG"
    PRE_VAR::String        = "VARIA_"
    PRE_FIXED::String      = "FIXED_"
    PRE_FILL::String       = "FILL_"
    PRE_MASS::String       = "MASS_"
    PRE_RESULT::String     = "RESULT_"
    PRE_PRED::String       = "PRED_"
    PRE_CHRO::String       = "CHRO_"
    PRE_ACTUAL::String     = "ACTUAL_"
    PRE_TIME_FORW::String  = "TIME_FORW_MINS_"
    PRE_TIME_DCYP::String  = "TIME_DCYP_MINS_"
    PRE_TIME_REVE::String  = "TIME_REVE_MINS_"
    PREFIX_LEADERS::String = "Leaders_"
    COL_EXP_ID::String     = "EXP_ID"
    COL_PHASE::String      = "PHASE"
    COL_RUN_ORDER::String  = "RUN_ORDER"
    COL_STATUS::String     = "STATUS"
    COL_SCORE::String      = "SCORE"
    COL_NOTES::String      = "NOTES"
    COL_ID::String         = "ID"
    ROLE_VAR::String       = "Variable"
    ROLE_FILL::String      = "Filler"
    ROLE_FIX::String       = "Fixed"
    METHOD_BB15::String    = "BB15"
    METHOD_TL09::String    = "TL09"
    METHOD_CD17::String    = "CD17"
    METHOD_DF14::String    = "DF14"
end

"""
    FAST_Data_DDEC

Global constant instance of `FAST_Catalogue_DDES` providing system-wide sheet names,
column headers, status indicators, and design topology identifiers.
"""
const FAST_Data_DDEC = FAST_Catalogue_DDES()

# ------------------------------------------------------------------------------
# SECTION 2: TRANSIENT STORAGE MANAGEMENT
# ------------------------------------------------------------------------------

"""
    FAST_TempRoot_DDEC
Dedicated directory for transient operations to prevent system-wide data scattering.
"""
const FAST_TempRoot_DDEC = let
    base = rstrip(tempdir(), ['/', '\\'])
    endswith(base, "DoECISORY_Workforce") ? base : joinpath(base, "DoECISORY_Workforce")
end

"""
    FAST_ExtractDataID_DDEF(vault) -> String
Standardised extraction of the Data Identity (DataID) from multi-source binary stores.
Prioritises 'dataid' (lowercase) for internal consistency, with failover to 'DataID' and 'content'.
"""
FAST_ExtractDataID_DDEF(::Nothing)          = ""
FAST_ExtractDataID_DDEF(v::AbstractString)  = v
FAST_ExtractDataID_DDEF(v::AbstractDict)    = string(get(v, "dataid", get(v, "DataID", get(v, "content", ""))))
FAST_ExtractDataID_DDEF(::Any)              = ""

"""
    FAST_InitialiseWorkforce_DDEF()
Initialises transient directories and clears existing temporary files.
"""
function FAST_InitialiseWorkforce_DDEF()
    ENV["TMP"]    = FAST_TempRoot_DDEC
    ENV["TEMP"]   = FAST_TempRoot_DDEC
    ENV["TMPDIR"] = FAST_TempRoot_DDEC

    FAST_Log_DDEF("FAST", "WORKFORCE", "Initialising workforce directories...", "WAIT")
    try
        if !isdir(FAST_TempRoot_DDEC)
            mkpath(FAST_TempRoot_DDEC)
            FAST_Log_DDEF("FAST", "WORKFORCE", "Created transient directory: $FAST_TempRoot_DDEC", "OK")
        else
            FAST_CleanWorkforce_DDEF()
            FAST_Log_DDEF("FAST", "WORKFORCE", "Transient directory prepared.", "OK")
        end
    catch e
        FAST_Log_DDEF("FAST", "WORKFORCE_FAIL", "Could not initialise temp directory: $e", "FAIL")
    end
end

# ------------------------------------------------------------------------------
# SECTION 3: FILESYSTEM CLEANING & GARDENING
# ------------------------------------------------------------------------------

function FAST_CleanWorkforce_DDEF(all::Bool=false)::Nothing
    !isdir(FAST_TempRoot_DDEC) && return nothing

    try
        for (root, dirs, files) in walkdir(FAST_TempRoot_DDEC; topdown=false)
            for f in files
                # Restricted deletion for files non-compliant with DoECISORY patterns.
                if all || startswith(f, "DOECISORY_TEMP_") || startswith(f, "DoECISORY_") || startswith(f, "DDE_")
                    try
                        rm(joinpath(root, f); force=true)
                    catch
                    end
                end
            end
            for d in dirs
                try
                    if root != FAST_TempRoot_DDEC || all
                         rm(joinpath(root, d); force=true, recursive=true)
                    end
                catch
                end
            end
        end

        all && FAST_Log_DDEF("FAST", "CLEAN_DEEP", "Extended workforce sweep executed.", "INFO")
    catch e
        FAST_Log_DDEF("FAST", "CLEAN_WARN", "Recursive cleaning encountered an error: $e", "WARN")
    end
    
    return nothing
end

"""
    FAST_CleanTransient_DDEF(path)
Surgically removes a specific transient file from the workforce.
"""
FAST_CleanTransient_DDEF(::Nothing) = nothing
FAST_CleanTransient_DDEF(path::AbstractString) = begin
    (isempty(path) || !isfile(path)) && return nothing
    
    if !startswith(abspath(path), abspath(FAST_TempRoot_DDEC))
        FAST_Log_DDEF("FAST", "GUARD_VIOLATION", "Deletion attempt outside transient scope: $path", "FAIL")
        return nothing
    end

    try
        rm(path; force=true)
    catch
    end
    return nothing
end

# ==============================================================================
# PART B: LOGGING & CONSOLE TELEMETRY
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 4: LOGGING SYSTEM & ANSI COLOURS
# ------------------------------------------------------------------------------

# Static pre-computation of ANSI escape sequences for synchronised console telemetry.
const FAST_ActiveGroup_DDEC = Ref{String}("")
const FAST_LogColours_DDEC = Dict{Symbol, String}(
    :INFO => "\e[34m",
    :OK   => "\e[32m",
    :WARN => "\e[33m",
    :FAIL => "\e[31m",
    :WAIT => "\e[90m",
    :LIST => "\e[37m",
)
const FAST_LogReset_DDEC = "\e[0m"

"""
    FAST_WrapDetail_DDEF(Detail::AbstractString, MaxWidth::Int=45, Indent::Int=45) -> String
Format multi-line or long telemetry payloads with word-wrapping and hanging indentation.
"""
function FAST_WrapDetail_DDEF(Detail::AbstractString, MaxWidth::Int=45, Indent::Int=45)::String
    (length(Detail) <= MaxWidth && !occursin('\n', Detail)) && return String(Detail)
    lines = String[]
    for para in split(Detail, '\n')
        if length(para) <= MaxWidth
            push!(lines, String(para))
        else
            words = split(para, ' ')
            cur = ""
            for w_sub in words
                w = String(w_sub)
                while length(w) > MaxWidth
                    if !isempty(cur)
                        push!(lines, cur)
                        cur = ""
                    end
                    push!(lines, String(first(w, MaxWidth)))
                    w = String(w[(MaxWidth + 1):end])
                end
                if isempty(cur)
                    cur = w
                elseif length(cur) + 1 + length(w) <= MaxWidth
                    cur *= " " * w
                else
                    push!(lines, cur)
                    cur = w
                end
            end
            !isempty(cur) && push!(lines, cur)
        end
    end
    pad = " "^Indent
    return join(lines, "\n" * pad)
end

"""
    FAST_Log_DDEF(Source, Event, [Detail], [Type])
Standardised console logging with ANSI colour support and timestamps. Bridged to Value-Dispatch.
"""
function FAST_Log_DDEF(::Val{Type}, Source, Event, Detail) where {Type}
    c       = get(FAST_LogColours_DDEC, Type, "\e[34m")
    ts      = Dates.format(now(), "HH:MM:SS.sss")
    det_str = isnothing(Detail) ? "null" : string(Detail)
    grp_pfx = isempty(FAST_ActiveGroup_DDEC[]) ? "" : "[$(FAST_ActiveGroup_DDEC[])] "
    src_fmt = grp_pfx * string(Source)
    det_fmt = FAST_WrapDetail_DDEF(det_str, 45, 45)
    
    @printf("\e[34m[%s]%s \e[32m%-11s%s: %s%-16s%s %s%s%s\n",
        ts, FAST_LogReset_DDEC, src_fmt, FAST_LogReset_DDEC, c, string(Event), FAST_LogReset_DDEC, c, det_fmt, FAST_LogReset_DDEC)
    flush(stdout)
end

# ------------------------------------------------------------------------------
# SECTION 5: FILENAME SANITISATION & COMPATIBILITY
# ------------------------------------------------------------------------------

"""
    FAST_Log_DDEF(Source::AbstractString, Event::AbstractString, Detail::Any="", Type::AbstractString="INFO") -> Nothing
Format and emit a structured console telemetry log with timestamp and severity colour coding.
Dispatches value types to render ANSI terminal escapes for real-time operation tracking.

# Arguments
- `Source::AbstractString`: Emitting subsystem tag (e.g. `"CORE"`, `"VISE"`, `"FAST"`).
- `Event::AbstractString`: Operation or event identifier.
- `Detail::Any`: Contextual message, metric, or status payload (default: `""`).
- `Type::AbstractString`: Severity level (`"INFO"`, `"OK"`, `"WAIT"`, `"WARN"`, or `"FAIL"`).

# Returns
- `Nothing`.
"""
function FAST_Log_DDEF(Source::AbstractString, Event::AbstractString, Detail::Any="", Type::AbstractString="INFO")
    FAST_Log_DDEF(Val(Symbol(Type)), Source, Event, Detail)
end

const FAST_FilenameMap_DDEC = Dict(
    'ç' => 'c', 'Ç' => 'C',
    'ğ' => 'g', 'Ğ' => 'G',
    'ı' => 'i', 'İ' => 'I',
    'ö' => 'o', 'Ö' => 'O',
    'ş' => 's', 'Ş' => 'S',
    'ü' => 'u', 'Ü' => 'U'
)

"""
    FAST_SanitiseFilename_DDEF(name::String) -> String
ASCII-safe filename generator. Converts non-ASCII characters to ASCII and replaces 
non-alphanumeric characters with underscores. Ensures filesystem compatibility.
"""
function FAST_SanitiseFilename_DDEF(name::AbstractString)
    # Character normalisation map for ASCII collation.
    res = map(c -> get(FAST_FilenameMap_DDEC, c, c), name)
    res = replace(res, r"[^\w\-_.]" => "_")
    res = replace(res, r"_{2,}" => "_")
    
    return strip(res, ['_'])
end

# ==============================================================================
# PART C: HIGH-FIDELITY I/O & DATA SANITISATION
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 6: EXCEL I/O & DATA NORMALISATION
# ------------------------------------------------------------------------------

"""
    FAST_SanitiseColumnNames_DDEF!(df::DataFrame)::DataFrame
Standardises DataFrame column names: Strips whitespace and forces Uppercase.
Mutates the DataFrame in-place for performance. Supports unique naming for collisions.
"""
function FAST_SanitiseColumnNames_DDEF!(df::DataFrame; force_upper::Bool=false)::DataFrame
    isempty(df) && return df
    
    f = n -> begin
        s = replace(strip(string(n)), " " => "_")
        force_upper ? uppercase(s) : s
    end

    # DataFrames v1.x compatible mapping for unique standardisation.
    rename!(df, f.(names(df)); makeunique=true)
    return df
end

"""
    FAST_ReadExcel_DDEF(FilePath, SheetName::AbstractString) -> DataFrame
Read an Excel workbook worksheet into a DataFrame with normalised header symbols.
Validates structural columns, strips invalid characters, and handles transient file-access retries.

# Arguments
- `FilePath`: Path to workbook file (returns empty DataFrame if `nothing` or non-existent).
- `SheetName::AbstractString`: Target worksheet name.

# Returns
- `DataFrame`: Extracted sheet tabular data.
"""
function FAST_ReadExcel_DDEF(FilePath::Nothing, SheetName::AbstractString)::DataFrame
    return DataFrame()
end

function FAST_ReadExcel_DDEF(FilePath::AbstractString, SheetName::AbstractString)::DataFrame
    (isempty(FilePath) || !isfile(FilePath)) && return DataFrame()

    ext = lowercase(splitext(FilePath)[2])
    if ext ∉ (".xlsx", ".xlsm")
        FAST_Log_DDEF("FAST", "IO_ERROR", "Invalid Excel document type [$ext].", "FAIL")
        return DataFrame()
    end

    max_retries = 2
    retry_delay = 0.3
    
    for attempt in 1:max_retries
        try
            final_df = XLSX.openxlsx(FilePath) do xf
                if SheetName ∉ XLSX.sheetnames(xf)
                    FAST_Log_DDEF("FAST", "IO_ERROR", "Target sheet [$SheetName] not found.", "FAIL")
                    return nothing
                end

                df = DataFrame(XLSX.gettable(xf[SheetName]))
                
                # Enforcement of mandatory structural columns.
                is_data_sheet = SheetName == FAST_Data_DDEC.SHEET_DATA || startswith(SheetName, FAST_Data_DDEC.PREFIX_LEADERS)
                if is_data_sheet && !FAST_ValidateSheetStructure_DDEF(df, SheetName)
                    throw(ArgumentError("Structural mismatch in sheet [$SheetName]."))
                end

                return df
            end

            isnothing(final_df) && return DataFrame()
            
            FAST_Log_DDEF("FAST", "IO_READ", "$(nrow(final_df)) rows extracted from [$SheetName].", "OK")
            return FAST_SanitiseColumnNames_DDEF!(final_df)

        catch e
            # Exit immediately for structural/logical errors.
            if e isa ArgumentError 
                FAST_Log_DDEF("FAST", "IO_ERROR", "I/O Critical Failure: $(first(string(e), 150))", "FAIL")
                return DataFrame()
            end

            attempt < max_retries || (FAST_Log_DDEF("FAST", "IO_ERROR", "I/O Timeout: $(first(string(e), 150))", "FAIL"); return DataFrame())
            FAST_Log_DDEF("FAST", "IO_RETRY_READ", "Read blocked ($attempt/$max_retries). Retrying...", "WARN")
            sleep(retry_delay)
        end
    end
    return DataFrame()
end

# Internal structural validator for sheets.
function FAST_ValidateSheetStructure_DDEF(df::DataFrame, SheetName::AbstractString)::Bool
    cols = uppercase.(strip.(string.(names(df))))
    has_id = any(x -> x == "EXP_ID" || x == "ID", cols)
    has_ph = any(x -> x == "PHASE", cols)
    
    if !has_id || !has_ph
        FAST_Log_DDEF("FAST", "FORMAT_FAIL", "Mandatory columns (EXP_ID/ID or PHASE) missing in [$SheetName].", "WARN")
        return false
    end
    return true
end

"""
    FAST_ApplyExcelStyle_DDEF(File::AbstractString, ValidPairs::Vector{Pair{String,DataFrame}})::Nothing
Exact-Fit Aesthetics Protocol: Computes exact-fit column dimensions matching text width with natural
OpenXML cell padding, then injects ECMA-376 OpenXML `<cols>` definitions into each worksheet XML.
"""
function FAST_ApplyExcelStyle_DDEF(File::AbstractString, ValidPairs::Vector{Pair{String,DataFrame}}=Pair{String,DataFrame}[])::Nothing
    !isfile(File) && return nothing
    
    temp_file = File * ".tmp_fit.xlsx"
    try
        # Compute exact-fit column dimensions per sheet
        col_widths  = Dict{String, Vector{Float64}}()
        sheet_order = String[]
        calc_w      = s -> begin
            str = string(s)
            isempty(str) && return 0.0
            sum(c -> c in ('M', 'W') ? 1.4 : 1.0, str; init=0.0)
        end

        if !isempty(ValidPairs)
            for (sn, df) in ValidPairs
                ncol(df) == 0 && continue
                push!(sheet_order, sn)
                widths = Float64[]
                for (i, col_name) in enumerate(names(df))
                    header_str = string(col_name)
                    max_w = calc_w(header_str)
                    col_vals = df[!, i]
                    for v in col_vals
                        if !ismissing(v) && !isnothing(v)
                            cw = calc_w(v)
                            if cw > max_w
                                max_w = cw
                            end
                        end
                    end
                    # Strict uniform width for all columns
                    w = occursin("JSON", uppercase(header_str)) ? clamp(Float64(max_w + 1.0), 10.0, 60.0) : Float64(max_w + 1.0)
                    push!(widths, round(w; digits=1))
                end
                col_widths[sn] = widths
            end
        else
            # Fallback inspection: Read cells directly from XLSX workbook when no DataFrames are passed
            try
                XLSX.openxlsx(File) do xf
                    for sn in XLSX.sheetnames(xf)
                        push!(sheet_order, sn)
                        try
                            sh = xf[sn]
                            mat = sh[:]
                            nr, nc = size(mat)
                            widths = Float64[]
                            for c in 1:nc
                                max_l = 0.0
                                for r in 1:nr
                                    val = mat[r, c]
                                    if !ismissing(val) && !isnothing(val)
                                        cw = calc_w(val)
                                        if cw > max_l
                                            max_l = cw
                                        end
                                    end
                                end
                                w = Float64(max_l + 1.0)
                                push!(widths, round(w; digits=1))
                            end
                            if !isempty(widths)
                                col_widths[sn] = widths
                            end
                        catch
                        end
                    end
                end
            catch
            end
        end

        isempty(col_widths) && return nothing

        zin = ZipFile.Reader(File)
        
        # Ingest archive entries preserving exact original order
        entries = Tuple{String, Vector{UInt8}, UInt16}[]
        wb_xml_str = ""
        rels_xml_str = ""
        all_ws = String[]
        for f in zin.files
            b = read(f)
            push!(entries, (f.name, b, f.method))
            if f.name == "xl/workbook.xml"
                wb_xml_str = String(copy(b))
            elseif f.name == "xl/_rels/workbook.xml.rels"
                rels_xml_str = String(copy(b))
            elseif occursin(r"^xl/worksheets/sheet\d+\.xml$", f.name)
                push!(all_ws, f.name)
            end
        end
        close(zin)
        
        # Build mapping from worksheet filename to sheet name via workbook metadata
        rel_to_name = Dict{String, String}()
        if !isempty(wb_xml_str)
            for m in eachmatch(r"<sheet\b[^>]*\bname=\"([^\"]+)\"[^>]*\br:id=\"([^\"]+)\"", wb_xml_str)
                rel_to_name[m.captures[2]] = m.captures[1]
            end
        end
        
        file_to_sheet = Dict{String, String}()
        if !isempty(rels_xml_str)
            for m in eachmatch(r"<Relationship\b[^>]*\bId=\"([^\"]+)\"[^>]*\bTarget=\"([^\"]+)\"", rels_xml_str)
                r_id = m.captures[1]
                target = m.captures[2]
                if haskey(rel_to_name, r_id)
                    file_to_sheet[basename(target)] = rel_to_name[r_id]
                end
            end
        end
        
        # Re-pack archive with auto-fitted column tags and OpenXML structural compliance
        zout = ZipFile.Writer(temp_file)
        for (name, bytes, method) in entries
            f_out = ZipFile.addfile(zout, name; method=method)
            m_sheet = match(r"^xl/worksheets/(sheet\d+\.xml)$", name)
            
            if name == "[Content_Types].xml"
                xml_ct = String(copy(bytes))
                # Ensure all worksheet parts have an explicit Override tag to prevent Excel repair prompt
                for ws in all_ws
                    part_name = "/$ws"
                    if !occursin("PartName=\"$part_name\"", xml_ct)
                        override_tag = "<Override PartName=\"$part_name\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
                        pos_types = findlast("</Types>", xml_ct)
                        if pos_types !== nothing
                            xml_ct = xml_ct[1:first(pos_types)-1] * override_tag * xml_ct[first(pos_types):end]
                        end
                    end
                end
                write(f_out, xml_ct)
            elseif name == "xl/workbook.xml"
                xml_wb = String(copy(bytes))
                # Remove obsolete developer machine absolute path metadata causing external link warning
                xml_wb = replace(xml_wb, r"<mc:AlternateContent\b[^>]*>.*?</mc:AlternateContent>"s => "")
                write(f_out, xml_wb)
            elseif m_sheet !== nothing
                xml = String(copy(bytes))
                # Purge invalid IEEE 754 numeric tokens (NaN, Inf) that cause Excel recovery dialogs
                xml = replace(xml, r"<c\b([^>]*\br=\"[A-Z0-9]+\"[^>]*)><v>(?:NaN|Inf|-Inf)<\/v><\/c>" => s"<c\1/>")
                xml = replace(xml, r"<v>(?:NaN|Inf|-Inf)<\/v>" => "")
                
                sheet_filename = m_sheet.captures[1]
                
                # Resolve target sheet column widths
                sheet_widths = Float64[]
                if haskey(file_to_sheet, sheet_filename)
                    sn = file_to_sheet[sheet_filename]
                    if haskey(col_widths, sn)
                        sheet_widths = col_widths[sn]
                    end
                end
                
                if isempty(sheet_widths)
                    idx_match = match(r"sheet(\d+)\.xml", sheet_filename)
                    if idx_match !== nothing
                        idx = parse(Int, idx_match.captures[1])
                        if 1 <= idx <= length(sheet_order)
                            sn = sheet_order[idx]
                            if haskey(col_widths, sn)
                                sheet_widths = col_widths[sn]
                            end
                        end
                    end
                end
                
                if !isempty(sheet_widths)
                    cols_buf = IOBuffer()
                    print(cols_buf, "<cols>")
                    for (i, w) in enumerate(sheet_widths)
                        print(cols_buf, "<col min=\"", i, "\" max=\"", i, "\" width=\"", w, "\" customWidth=\"1\"/>")
                    end
                    print(cols_buf, "</cols>")
                    cols_tag = String(take!(cols_buf))
                    
                    xml = replace(xml, r"<(?:\w+:)?cols\b[^>]*(?:\/>|>.*?<\/(?:\w+:)?cols>)"s => "")
                    m_data = match(r"<((?:\w+:)?sheetData)[>\s]", xml)
                    if m_data !== nothing
                        pos = m_data.offset
                        xml = xml[1:pos-1] * cols_tag * xml[pos:end]
                    end
                end
                write(f_out, xml)
            else
                write(f_out, bytes)
            end
        end
        close(zout)
        mv(temp_file, File; force=true)
    catch e
        isfile(temp_file) && rm(temp_file; force=true)
        FAST_Log_DDEF("FAST", "STYLE_WARN", "Excel auto-fit non-critical warning: $(e)", "WARN")
    end
    return nothing
end

FAST_ApplyExcelStyle_DDEF(File::AbstractString, Updates::Dict{<:AbstractString,DataFrame}) = 
    FAST_ApplyExcelStyle_DDEF(File, [k => v for (k, v) in Updates])

# Polymorphic fallback for single-sheet styling dispatches
FAST_ApplyExcelStyle_DDEF(sheet, df::DataFrame) = nothing

"""
    FAST_WriteExcel_DDEF(File::AbstractString, Updates::Dict{<:AbstractString, DataFrame}) -> Nothing
Atomically write or update sheets in an Excel workbook with transient backup and file-lock retry handling.
Merges existing sheets, sanitises IEEE 754 numeric tokens, and auto-fits column widths via OpenXML repackaging.

# Arguments
- `File::AbstractString`: Target workbook path.
- `Updates::Dict{<:AbstractString, DataFrame}`: Mapping from worksheet names to DataFrames to write or update.

# Returns
- `Nothing`.
"""
function FAST_WriteExcel_DDEF(File::AbstractString, Updates::Dict{<:AbstractString,DataFrame})::Nothing
    isempty(File) && return nothing
    
    all_data    = Dict{String,DataFrame}()
    sheet_order = String[]

    # Implementation of "File in Use" Resilience: Retry Loop Protocol
    max_retries = 10
    retry_delay = 0.5
    
    # 1. Read existing data with retry logic
    if isfile(File) && filesize(File) > 0
        for attempt in 1:max_retries
            try
                XLSX.openxlsx(File) do xf
                    for sn in XLSX.sheetnames(xf)
                        push!(sheet_order, sn)
                        if haskey(Updates, sn)
                            all_data[sn] = Updates[sn]
                        else
                            all_data[sn] = try 
                                DataFrame(XLSX.gettable(xf[sn])) 
                            catch 
                                DataFrame() 
                            end
                        end
                    end
                end
                break
            catch e
                GC.gc(false)
                if attempt < max_retries
                    FAST_Log_DDEF("FAST", "IO_RETRY", "File locked ($attempt/$max_retries). Retrying in $(retry_delay)s...", "WARN")
                    sleep(retry_delay)
                else
                    FAST_Log_DDEF("FAST", "IO_LOCK_FAIL", "File inaccessible after $max_retries attempts.", "FAIL")
                    rethrow(e)
                end
            end
        end
    end

    # 2. Merge updates
    for (k, df) in Updates
        if !haskey(all_data, k)
            push!(sheet_order, k)
        end
        all_data[k] = df
    end

    # 3. Filter valid pairs
    valid_pairs = Pair{String, DataFrame}[]
    for sn in sheet_order
        haskey(all_data, sn) || continue
        df = all_data[sn]
        if ncol(df) > 0 && (nrow(df) > 0 || sn == "CONFIG")
            push!(valid_pairs, sn => df)
        end
    end

    # 4. Atomic Write & Style Protocol
    if !isempty(valid_pairs)
        dir_target = dirname(File)
        !isdir(dir_target) && mkpath(dir_target)
        for attempt in 1:max_retries
            try
                # Windows-Specific: Initial delay to ensure previous handles are released.
                sleep(0.3) 
                
                # Standard multi-sheet write via one-shot API
                XLSX.writetable(File, valid_pairs...; overwrite=true)
                
                # Auto-Fit: Enforce optimal column dimensions
                try
                    FAST_ApplyExcelStyle_DDEF(File, valid_pairs)
                catch e_style
                    FAST_Log_DDEF("FAST", "STYLE_WARN", "Excel auto-fit non-critical warning: $(e_style)", "WARN")
                end
                
                FAST_Log_DDEF("FAST", "IO_WRITE", "Updates synchronised: $(File)", "OK")
                
                # Invalidate RAM cache to ensure next read hits the physical disk.
                lock(FAST_ConfigCacheLock_DDEC) do
                    if haskey(FAST_ConfigCache_DDEC, File)
                        delete!(FAST_ConfigCache_DDEC, File)
                    end
                end
                
                return nothing
            catch e
                GC.gc(false)
                if attempt < max_retries
                    FAST_Log_DDEF("FAST", "IO_RETRY", "Save blocked ($attempt/$max_retries). Retrying...", "WARN")
                    sleep(retry_delay)
                else
                    FAST_Log_DDEF("FAST", "IO_FATAL", "Data persistence failed: $e", "FAIL")
                    rethrow(e)
                end
            end
        end
    end
    
    return nothing
end

FAST_WriteExcel_DDEF(::Nothing, ::Dict{<:AbstractString,DataFrame}) = nothing
FAST_WriteExcel_DDEF(File::AbstractString, Sheet::AbstractString, df::DataFrame)::Nothing = 
    FAST_WriteExcel_DDEF(File, Dict(String(Sheet) => df))
FAST_WriteExcel_DDEF(::Nothing, ::AbstractString, ::DataFrame) = nothing

"""
    FAST_RoundColumns_DDEF!(df::DataFrame)::DataFrame
Rounds float columns to academic standard (3 decimal places).
Mutates input for memory efficiency.
"""
function FAST_RoundColumns_DDEF!(df::DataFrame)::DataFrame
    mapcols!(FAST_RoundColumn_DDEF, df)
    return df
end

FAST_RoundColumn_DDEF(col::AbstractVector{<:Union{Missing,AbstractFloat}}) = passmissing(x -> round(x; digits=3)).(col)
FAST_RoundColumn_DDEF(col::AbstractVector)                                 = col

# ------------------------------------------------------------------------------
# SECTION 7: DOWNLOAD PREPARATION & BINARY EXTRACTION
# ------------------------------------------------------------------------------

"""
    FAST_PrepareDownload_DDEF(FilePath) -> (Success, Content)
Reads file contents for web download action.
"""
FAST_PrepareDownload_DDEF(::Nothing) = (false, UInt8[])
function FAST_PrepareDownload_DDEF(FilePath::AbstractString)
    try
        (isempty(FilePath) || !isfile(FilePath)) && return (false, UInt8[])
        return (true, read(FilePath))
    catch
        return (false, UInt8[])
    end
end

# ==============================================================================
# PART D: SCIENTIFIC UTILITIES & TYPE SAFETY
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 8: NUMERIC COERCION & COMPATIBILITY
# ------------------------------------------------------------------------------

"""
    FAST_SafeNum_DDEF(x) -> Float64
Convert numeric, string, or missing inputs into a valid Float64 representation, returning NaN on failure.
Normalises European comma decimals, hyphen placeholders, and sentinel tokens to ensure scientific arithmetic safety.

# Arguments
- `x`: Input value to parse (supports commas, decimals, hyphens, and missing tokens).

# Returns
- `Float64`: Parsed numerical value or `NaN`.
"""
FAST_SafeNum_DDEF(::Nothing) = NaN
FAST_SafeNum_DDEF(::Missing) = NaN
FAST_SafeNum_DDEF(x::AbstractFloat) = Float64(x)
FAST_SafeNum_DDEF(x::Integer) = Float64(x)
FAST_SafeNum_DDEF(x::Bool) = x ? 1.0 : 0.0

function FAST_SafeNum_DDEF(x::AbstractString)::Float64
    s = strip(string(x))
    (isempty(s) || s == "-" || lowercase(s) == "nan") && return NaN
    clean_s = replace(s, ',' => '.')
    res = tryparse(Float64, clean_s)
    return something(res, NaN)
end

FAST_SafeNum_DDEF(x::Any) = FAST_SafeNum_DDEF(string(x))

"""
    FAST_FormatConditionNumber_DDEF(c::Any) -> Tuple{String, String, String}
Scientific condition number formatter: Translates raw condition number (κ) into human-readable numeric scale,
descriptive academic status label, and standard theme colour token.
"""
FAST_FormatConditionNumber_DDEF(::Nothing) = ("N/A", "Unknown", "var(--colour-val3-darlow)")
FAST_FormatConditionNumber_DDEF(::Missing) = ("N/A", "Unknown", "var(--colour-val3-darlow)")
FAST_FormatConditionNumber_DDEF(c::Any)    = FAST_FormatConditionNumber_DDEF(FAST_SafeNum_DDEF(c))

function FAST_FormatConditionNumber_DDEF(c::Real)::Tuple{String, String, String}
    c_f = Float64(c)
    if isnan(c_f)
        return ("N/A", "Unknown", "var(--colour-val3-darlow)")
    elseif isinf(c_f) || c_f > 1e12
        return ("Singular", "Ill-Conditioned Matrix", "var(--colour-chr0-huered)")
    elseif c_f < 100.0
        return (@sprintf("%.1f", c_f), "Ideal Orthogonality (κ < 100)", "var(--colour-chr4-tongre)")
    elseif c_f < 1000.0
        return (@sprintf("%.0f", c_f), "Well-Conditioned (κ < 1,000)", "var(--colour-chr4-tongre)")
    elseif c_f < 10000.0
        return (@sprintf("%.0f", c_f), "Moderate Collinearity (κ < 10,000)", "var(--colour-chr5-hueyel)")
    else
        return (@sprintf("%.1e", c_f), "Ill-Conditioned (κ ≥ 10,000)", "var(--colour-chr0-huered)")
    end
end

"""
    FAST_IsNumericInput_DDEF(v::Any) -> Bool
Scientific integrity guard: Validates if a UI input value is a non-empty numeric equivalent.
"""
FAST_IsNumericInput_DDEF(::Nothing) = false
FAST_IsNumericInput_DDEF(::Missing) = false
FAST_IsNumericInput_DDEF(v::Number)  = !isnan(v)
function FAST_IsNumericInput_DDEF(v::AbstractString)::Bool
    s = strip(v)
    isempty(s) && return false
    return !isnothing(tryparse(Float64, replace(s, ',' => '.')))
end
FAST_IsNumericInput_DDEF(::Any) = false

"""
    FAST_IsPopulatedInput_DDEF(v::Any) -> Bool
Architectural guard: Validates if a UI input contains substantial content.
"""
FAST_IsPopulatedInput_DDEF(::Nothing) = false
FAST_IsPopulatedInput_DDEF(::Missing) = false
FAST_IsPopulatedInput_DDEF(v::Number)  = !isnan(v)
function FAST_IsPopulatedInput_DDEF(v::AbstractString)::Bool
    s = strip(v)
    return !isempty(s) && s != "-" && lowercase(s) != "nan"
end
FAST_IsPopulatedInput_DDEF(::Any) = true

# ------------------------------------------------------------------------------
# SECTION 9: INPUT SANITISATION ENGINE
# ------------------------------------------------------------------------------

"""
    FAST_SanitiseInput_DDEF(TableData::AbstractVector)::Tuple{Vector{Dict{String,Any}}, Vector{String}}
Transforms raw UI Table data into typed scientific Dictionaries.
Implements automatic feature recognition for radioactivity and filler logic.
"""
function FAST_SanitiseInput_DDEF(TableData::AbstractVector)::Tuple{Vector{Dict{String,Any}},Vector{String}}
    warnings = String[]

    sanitised = map(enumerate(TableData)) do (idx, raw)
        r = Dict{String,Any}(string(k) => v for (k, v) in raw)

        row_name = string(get(r, "Name", "Unnamed_Item_$(idx)"))
        r["Name"] = row_name
        r["Role"] = string(get(r, "Role", "Variable"))
        r["Unit"] = string(get(r, "Unit", ""))
        r["HalfLifeUnit"] = string(get(r, "HalfLifeUnit", "Hours"))

        r["IsRadioactive"] = get(r, "IsRadioactive", false) == true

        num_fields = ("L1", "L2", "L3", "MW", "Min", "Max", "Target", "HalfLife")
        for key in num_fields
            val = get(r, key, nothing)
            clean_val = FAST_SafeNum_DDEF(val)

            if isnan(clean_val) && FAST_IsPopulatedInput_DDEF(val)
                push!(warnings, "Item '$row_name': Invalid input for '$key' ($val) coerced to 0.0")
            end
            r[key] = isnan(clean_val) ? 0.0 : clean_val
        end

        if r["HalfLife"] > 0.0
            r["IsRadioactive"] = true
        end

        return r
    end

    !isempty(warnings) && FAST_Log_DDEF("FAST", "SANITY", "Resolved $(length(warnings)) data anomalies.", "WARN")
    return (sanitised, warnings)
end

# ------------------------------------------------------------------------------
# SECTION 10: LAB DEFAULTS & SESSION INCEPTION
# ------------------------------------------------------------------------------

"""
    FAST_GetLabDefaults_DDEF()::Dict{String,Any}
Provides the default initial state for a fresh DoECISORY session.
"""
function FAST_GetLabDefaults_DDEF()::Dict{String,Any}
    # Using explicit types for standard return
    return Dict{String,Any}(
        "Inputs" => [
            Dict{String,Any}("Name" => "Var_A", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "Min" => 0.0, "Max" => 50.0, "MW" => 150.0, "Unit" => "mg"),
            Dict{String,Any}("Name" => "Var_B", "Role" => "Variable", "L1" => 1.0, "L2" => 5.0, "L3" => 9.0, "Min" => 0.0, "Max" => 15.0, "MW" => 300.0, "Unit" => "mM"),
            Dict{String,Any}("Name" => "Var_C", "Role" => "Variable", "L1" => 4.0, "L2" => 7.0, "L3" => 10.0, "Min" => 0.0, "Max" => 14.0, "MW" => 50.0, "Unit" => "pH"),
        ],
        "Outputs" => [
            Dict{String,Any}("Name" => "Size", "Unit" => "nm"),
            Dict{String,Any}("Name" => "PDI", "Unit" => "a.u."),
            Dict{String,Any}("Name" => "Zeta", "Unit" => "mV"),
        ],
    )
end

# ------------------------------------------------------------------------------
# SECTION 11: JSON RECURSIVE SANITISATION
# ------------------------------------------------------------------------------

"""
    FAST_SanitiseJSON_DDEF(x::Any)::Any
Recursively filters Julia objects into JSON-compliant structures.
Converts DataFrames to row-dicts and ensures NaNs/Missings map to 'null'.
"""
FAST_SanitiseJSON_DDEF(::Nothing) = nothing
FAST_SanitiseJSON_DDEF(::Missing) = nothing
function FAST_SanitiseJSON_DDEF(x::AbstractFloat)
    isnan(x) ? nothing : x
end
function FAST_SanitiseJSON_DDEF(x::DataFrame)
    [FAST_SanitiseJSON_DDEF(Dict(string(k) => v for (k, v) in zip(keys(r), values(r)))) for r in eachrow(x)]
end
function FAST_SanitiseJSON_DDEF(x::AbstractDict)
    Dict(string(k) => FAST_SanitiseJSON_DDEF(v) for (k, v) in x)
end
function FAST_SanitiseJSON_DDEF(x::AbstractMatrix)
    [FAST_SanitiseJSON_DDEF(x[i, :]) for i in axes(x, 1)]
end
function FAST_SanitiseJSON_DDEF(x::AbstractVector)
    map(FAST_SanitiseJSON_DDEF, x)
end
function FAST_SanitiseJSON_DDEF(x::Union{Tuple,NamedTuple,Pair})
    FAST_SanitiseJSON_DDEF(collect(x))
end
FAST_SanitiseJSON_DDEF(x::Any) = x

# ==============================================================================
# PART E: CONFIGURATION SYNC & VAULT OPS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 12: MASTER RECORD INITIALISATION (XLSX)
# ------------------------------------------------------------------------------

"""
    FAST_InitialiseMaster_DDEF(File::String, InNames::Vector{String}, OutNames::Vector{String}, DesignData::DataFrame, Config::Dict{String,Any}=Dict{String,Any}()) -> Bool
Construct and initialise the master Excel workbook containing design runs, config metadata, and audit records.
Merges incoming experimental topologies with existing historical phases and preserves JSON-encoded configuration state.

# Arguments
- `File::String`: Destination path for master workbook.
- `InNames::Vector{String}`: Experimental factor names.
- `OutNames::Vector{String}`: Response metric names.
- `DesignData::DataFrame`: Formatted experimental design run table.
- `Config::Dict{String, Any}`: Formulation boundaries and operational settings (default: empty dictionary).

# Returns
- `Bool`: `true` if initialisation succeeded, `false` otherwise.
"""
function FAST_InitialiseMaster_DDEF(File::AbstractString, InNames::Vector{String}, OutNames::Vector{String}, 
    DesignData::DataFrame, Config::Dict{String,Any}=Dict{String,Any}())::Bool
    try
        C = FAST_Data_DDEC
        FAST_Log_DDEF("FAST", "INIT_MASTER", "Syncing with DesignData: $File", "WAIT")

        # 1. Normalise input data columns and build comprehensive headers
        FAST_SanitiseColumnNames_DDEF!(DesignData)
        headers = [C.COL_EXP_ID, C.COL_PHASE, C.COL_STATUS, C.COL_NOTES]
        data_cols = names(DesignData)
        
        for col in data_cols
            if (startswith(col, C.PRE_MASS) || startswith(col, C.PRE_FILL)) && col ∉ headers
                push!(headers, col)
            end
        end

        for name in InNames
            n_clean = replace(strip(string(name)), " " => "_")
            for pfx in (C.PRE_VAR, C.PRE_FIXED, C.PRE_FILL)
                target_pfx = pfx * n_clean
                for col in data_cols
                    if (startswith(col, target_pfx) || startswith(col, pfx * name)) && col ∉ headers
                        push!(headers, col)
                    end
                end
            end
        end

        for n in OutNames
            n_clean = replace(strip(string(n)), " " => "_")
            res_matches = filter(c -> startswith(c, C.PRE_RESULT * n_clean), data_cols)
            if !isempty(res_matches)
                for rm in res_matches
                    rm ∉ headers && push!(headers, rm)
                end
            else
                col_res = C.PRE_RESULT * n_clean
                col_res ∉ headers && push!(headers, col_res)
            end
        end
        for n in OutNames
            n_clean = replace(strip(string(n)), " " => "_")
            pred_matches = filter(c -> startswith(c, C.PRE_PRED * n_clean), data_cols)
            if !isempty(pred_matches)
                for pm in pred_matches
                    pm ∉ headers && push!(headers, pm)
                end
            else
                col_pred = C.PRE_PRED * n_clean
                col_pred ∉ headers && push!(headers, col_pred)
            end
        end
        C.COL_SCORE ∉ headers && push!(headers, C.COL_SCORE)

        for col in data_cols
            if (startswith(col, C.PRE_TIME_FORW) || startswith(col, C.PRE_TIME_DCYP) ||
                startswith(col, C.PRE_TIME_REVE) || startswith(col, C.PRE_ACTUAL)) && col ∉ headers
                push!(headers, col)
            end
        end

        # 2. Structure Merge Protocol
        df_new = copy(DesignData)
        for col in setdiff(headers, names(df_new))
            df_new[!, col] = fill(missing, nrow(df_new))
        end
        df_final_data = select!(df_new, headers)

        if isfile(File)
            try
                df_old = FAST_ReadExcel_DDEF(File, C.SHEET_DATA)
                if !isempty(df_old)
                    if (C.COL_PHASE in names(df_final_data)) && (C.COL_PHASE in names(df_old))
                        target_phases = unique(skipmissing(df_final_data[!, C.COL_PHASE]))
                        if !isempty(target_phases)
                            old_statuses = (C.COL_STATUS in names(df_old)) ? collect(df_old[!, C.COL_STATUS]) : fill("", nrow(df_old))
                            mask_keep = .!(in.(df_old[!, C.COL_PHASE], Ref(target_phases)) .& (coalesce.(old_statuses .== "Pending", false)))
                            if any(.!mask_keep)
                                FAST_Log_DDEF("FAST", "INIT_MASTER", "Replacing $(count(.!mask_keep)) existing pending run(s) for phase $(join(target_phases, ", ")).", "INFO")
                                df_old = df_old[mask_keep, :]
                            end
                        end
                    end

                    all_headers = FAST_SortColumns_DDEF(unique(vcat(names(df_old), headers)))
                    for h in setdiff(all_headers, names(df_old))
                        if startswith(h, C.PRE_FILL)
                            backfilled = false
                            try
                                f_ing = replace(h, C.PRE_FILL => "")
                                m_u = match(r"^(.*)_[^_]+$", f_ing)
                                base_ing = !isnothing(m_u) ? m_u.captures[1] : f_ing
                                mass_col = C.PRE_MASS * base_ing * "_mg"
                                g_cfg = get(Config, "Global", Dict{String,Any}())
                                c_vol = FAST_SafeNum_DDEF(get(g_cfg, "Volume", 0.0))
                                c_conc = FAST_SafeNum_DDEF(get(g_cfg, "Conc", 0.0))
                                budget = (c_vol / 1000.0) * c_conc
                                
                                ings = get(Config, "Ingredients", [])
                                f_match = findfirst(r -> string(get(r, "Name", "")) == base_ing || replace(string(get(r, "Name", "")), " " => "_") == base_ing, ings)
                                f_mw = !isnothing(f_match) ? FAST_SafeNum_DDEF(get(ings[f_match], "MW", 0.0)) : 0.0
                                
                                if hasproperty(df_old, Symbol(mass_col)) && budget > 0.0 && f_mw > 0.0
                                    m_vals = [FAST_SafeNum_DDEF(v) for v in df_old[!, Symbol(mass_col)]]
                                    df_old[!, h] = [round((m / f_mw / budget) * 100.0, digits=3) for m in m_vals]
                                    backfilled = true
                                end
                            catch
                            end
                            !backfilled && (df_old[!, h] = fill(missing, nrow(df_old)))
                        else
                            df_old[!, h] = fill(missing, nrow(df_old))
                        end
                    end
                    for h in setdiff(all_headers, names(df_final_data))
                        df_final_data[!, h] = fill(missing, nrow(df_final_data))
                    end
                    df_final_data = vcat(df_old[:, all_headers], df_final_data[:, all_headers])
                end
            catch e
                FAST_Log_DDEF("FAST", "MERGE_WARN", "Structural merge failed: $e", "WARN")
            end
        else
            all_headers = FAST_SortColumns_DDEF(headers)
            df_final_data = df_final_data[:, all_headers]
        end
 
        FAST_FinaliseMasterWrite_DDEF(File, df_final_data, Config)
        return true
    catch e
        FAST_Log_DDEF("FAST", "INIT_MASTER_FAIL", sprint(showerror, e, catch_backtrace()), "FAIL")
        return false
    end
end

"""
    FAST_FormatColumn_DDEF(::Val{Role}, name::AbstractString) -> String
Construct standardised DataFrame column headers prefixed by scientific role tag.
"""
FAST_FormatColumn_DDEF(::Val{:Mass}, name::AbstractString)      = FAST_Data_DDEC.PRE_MASS * name * "_mg"
FAST_FormatColumn_DDEF(::Val{:Variable}, name::AbstractString)  = FAST_Data_DDEC.PRE_VAR * name
FAST_FormatColumn_DDEF(::Val{:Result}, name::AbstractString)    = FAST_Data_DDEC.PRE_RESULT * name
FAST_FormatColumn_DDEF(::Val{:Predicted}, name::AbstractString) = FAST_Data_DDEC.PRE_PRED * name
FAST_FormatColumn_DDEF(::Val{:Fixed}, name::AbstractString)     = FAST_Data_DDEC.PRE_FIXED * name
FAST_FormatColumn_DDEF(::Val{:Filler}, name::AbstractString)    = FAST_Data_DDEC.PRE_FILL * name
FAST_FormatColumn_DDEF(::Val{:Actual}, name::AbstractString)    = FAST_Data_DDEC.PRE_ACTUAL * name
FAST_FormatColumn_DDEF(::Val{T}, name::AbstractString) where {T} = name

function FAST_InitialiseMaster_DDEF(File::AbstractString, InNames::Vector{String}, OutNames::Vector{String}, 
    ::Nothing=nothing, Config::Dict{String,Any}=Dict{String,Any}())::Bool
    try
        C = FAST_Data_DDEC
        FAST_Log_DDEF("FAST", "INIT_MASTER", "Baseline Initialisation: $File", "WAIT")

        headers = [C.COL_EXP_ID, C.COL_PHASE, C.COL_STATUS, C.COL_NOTES]
        for n in InNames
            col_mass = FAST_FormatColumn_DDEF(Val(:Mass), n)
            col_mass ∉ headers && push!(headers, col_mass)
            col_in = FAST_FormatColumn_DDEF(Val(:Variable), n)
            col_in ∉ headers && push!(headers, col_in)
        end
        for n in OutNames
            col_res = FAST_FormatColumn_DDEF(Val(:Result), n)
            col_res ∉ headers && push!(headers, col_res)
        end
        for n in OutNames
            col_pred = FAST_FormatColumn_DDEF(Val(:Predicted), n)
            col_pred ∉ headers && push!(headers, col_pred)
        end
        C.COL_SCORE ∉ headers && push!(headers, C.COL_SCORE)

        df_final_data = DataFrame([h => [] for h in headers]...)
        
        FAST_FinaliseMasterWrite_DDEF(File, df_final_data, Config)
        return true
    catch e
        FAST_Log_DDEF("FAST", "INIT_MASTER_FAIL", sprint(showerror, e, catch_backtrace()), "FAIL")
        return false
    end
end

# Internal utility to handle the atomicity of Master write operations.
function FAST_FinaliseMasterWrite_DDEF(File::AbstractString, df::DataFrame, Config::Dict)
    C = FAST_Data_DDEC
    FAST_RoundColumns_DDEF!(df)
    
    clean_config = FAST_SanitiseJSON_DDEF(Config)
    json_str     = isempty(Config) ? "{}" : JSON3.write(clean_config)
    config_df    = DataFrame(
        "PARAMETER"  => ["MasterConfig"],
        "VALUE_JSON" => [json_str],
        "UPDATED_AT" => [string(now())],
    )

    updates = Dict{String,DataFrame}(
        C.SHEET_DATA   => df,
        C.SHEET_CONFIG => config_df
    )

    FAST_WriteExcel_DDEF(File, updates)
end

# Bridge for nothing/empty calls
FAST_InitialiseMaster_DDEF(::Nothing, args...) = false

# ------------------------------------------------------------------------------
# SECTION 13: STRUCTURED PROTOCOL FILENAME GENERATION
# ------------------------------------------------------------------------------

"""
    FAST_GenSmartName_DDEF(Project::AbstractString, Phase::AbstractString, Tag::AbstractString, Ext::AbstractString="xlsx") -> String
Generate a standardised, timestamped filename for protocol workbooks and reports.
Sanitises non-ASCII characters, encodes phase and subproject tags, and appends chronological timestamps.

# Arguments
- `Project::AbstractString`: Project name identifier.
- `Phase::AbstractString`: Phase code (e.g. `"Phase1"`).
- `Tag::AbstractString`: Context tag (e.g. `"Deck"`, `"Lens"`).
- `Ext::AbstractString`: File extension without leading dot (default: `"xlsx"`).

# Returns
- `String`: Formatted filename matching `DoECISORY_<Project>_<Phase>_<Tag>_<Timestamp>.<Ext>`.
"""
function FAST_GenSmartName_DDEF(Project::AbstractString, Phase::AbstractString, Tag::AbstractString, Ext::AbstractString="xlsx")::String
    p_raw    = strip(Project)
    p_clean  = (isempty(p_raw) || lowercase(p_raw) == "doecisory") ? "DoECISORY" : FAST_SanitiseFilename_DDEF(p_raw)
    ph_clean = replace(Phase, "Phase" => "P")
    ts       = Dates.format(now(), "yyyy_mmdd_HHMM")
    
    return isempty(Ext) ? "DoECISORY_$(p_clean)_$(ph_clean)_$(Tag)_$(ts)" : "DoECISORY_$(p_clean)_$(ph_clean)_$(Tag)_$(ts).$(Ext)"
end

"""
    FAST_ExtractProjectName_DDEF(Filename::AbstractString) -> String
Extracts the project name from a DoECISORY standard filename.
Returns empty string if the pattern doesn't match. Supports both DoECISORY_ and legacy DDE_ prefixes.
"""
function FAST_ExtractProjectName_DDEF(Filename::AbstractString)::String
    # Formulation of the extraction pattern: (DoECISORY|DDE)_ProjectName_Phase_Tag_TS.ext.
    m = match(r"^(?:DoECISORY|DDE)_(.*?)_P\d+_", Filename)
    !isnothing(m) && return string(m.captures[1])

    # Fallback Protocol: If the filename is non-standard, return the base name minus extension.
    base = splitext(Filename)[1]
    (isempty(base) || base == "." ) && return ""
    return base
end

# ------------------------------------------------------------------------------
# SECTION 14: TRANSIENT PATH ORCHESTRATION
# ------------------------------------------------------------------------------

"""
    FAST_GetTransientPath_DDEF([DataHandle]) -> String
Creates an identifiable temporary file path within the transient directory.
If DataHandle is a Hash, it retrieves binary from Vault. If it's Base64, it decodes it.
"""
function FAST_GetTransientPath_DDEF()::String
    isdir(FAST_TempRoot_DDEC) || mkpath(FAST_TempRoot_DDEC)
    ts = Dates.format(now(), "HHmmss_SSS")
    rnd = rand(1000:9999)
    return joinpath(FAST_TempRoot_DDEC, "DOECISORY_TEMP_$(ts)_$(rnd).xlsx")
end

FAST_GetTransientPath_DDEF(::Nothing) = FAST_GetTransientPath_DDEF()
FAST_GetTransientPath_DDEF(vault::AbstractDict) = FAST_GetTransientPath_DDEF(FAST_ExtractDataID_DDEF(vault))

# Specialised handling for Data Handles (Vault vs Base64 vs Empty)
function FAST_GetTransientPath_DDEF(DataHandle::AbstractString)::String
    isempty(DataHandle) && return FAST_GetTransientPath_DDEF()
    
    # 1. Check Vault for Hash Reference
    vault_binary = FAST_ReadVault_DDEF(DataHandle)
    if !isnothing(vault_binary)
        tmp_path = FAST_GetTransientPath_DDEF()
        write(tmp_path, vault_binary)
        return tmp_path
    end

    # 2. Check for Embedded Base64 Payload or raw base64
    if contains(DataHandle, ";base64,")
        tmp_path = FAST_GetTransientPath_DDEF()
        write(tmp_path, base64decode(split(DataHandle, ',')[end]))
        return tmp_path
    elseif length(DataHandle) > 100
        try
            decoded = base64decode(DataHandle)
            if length(decoded) >= 4 && decoded[1] == 0x50 && decoded[2] == 0x4b
                tmp_path = FAST_GetTransientPath_DDEF()
                write(tmp_path, decoded)
                return tmp_path
            end
        catch
        end
    end
    
    return FAST_GetTransientPath_DDEF()
end

"""
    FAST_ReadToStore_DDEF(Path) -> String
Reads a file, persists it to Server Vault, and returns its Hash handle for frontend.
"""
FAST_ReadToStore_DDEF(::Nothing) = ""

function FAST_ReadToStore_DDEF(Path::AbstractString)::String
    isdir(Path) && return ""
    !isfile(Path) && return ""
    
    try
        binary = read(Path)
        h_val = string(hash(binary))
        FAST_WriteVault_DDEF(h_val, binary)
        return h_val
    catch
        return ""
    end
end

# Configuration cache
const FAST_ConfigCache_DDEC = Dict{String, Any}()
const FAST_ConfigCacheLock_DDEC = ReentrantLock()

"""
    FAST_ResetConfigCache_DDEF() 
Manually invalidates the MasterConfig cache.
"""
function FAST_ResetConfigCache_DDEF()
    lock(FAST_ConfigCacheLock_DDEC) do
        empty!(FAST_ConfigCache_DDEC)
    end
    return true
end

"""
    FAST_ReadConfig_DDEF(File) -> Dict
Reads the MasterConfig from an existing Excel file's CONFIG sheet with transparent RAM caching.
"""
FAST_ReadConfig_DDEF(::Nothing) = Dict{String,Any}()
FAST_ReadConfig_DDEF(cfg::AbstractDict) = deepcopy(cfg)
FAST_ReadConfig_DDEF(::Any) = Dict{String,Any}()

function FAST_ReadConfig_DDEF(File::AbstractString)::Dict{String,Any}
    isempty(File) && return Dict{String,Any}()
    
    now_ts = time()
    cached = lock(FAST_ConfigCacheLock_DDEC) do
        if haskey(FAST_ConfigCache_DDEC, File)
            ts, cache_dict = FAST_ConfigCache_DDEC[File]
            if (now_ts - ts) < 120.0
                return deepcopy(cache_dict)
            end
        end
        return nothing
    end
    !isnothing(cached) && return cached

    try
        C = FAST_Data_DDEC
        df = FAST_ReadExcel_DDEF(File, C.SHEET_CONFIG)
        isempty(df) && return Dict{String,Any}()
        
        hasproperty(df, :PARAMETER) || return Dict{String,Any}()
        idx = findfirst(==("MasterConfig"), string.(df[!, :PARAMETER]))
        isnothing(idx) && return Dict{String,Any}()

        js_val = string(df[idx, :VALUE_JSON])
        if startswith(js_val, "PK")
            FAST_Log_DDEF("FAST", "READ_CONFIG_WARN", "Binary signature detected in JSON field.", "WARN")
            return Dict{String,Any}()
        end
        
        config = JSON3.read(js_val, Dict{String,Any})
        lock(FAST_ConfigCacheLock_DDEC) do
            FAST_ConfigCache_DDEC[File] = (now_ts, config)
        end
        return deepcopy(config)
    catch e
        FAST_Log_DDEF("FAST", "READ_CONFIG_FAIL", "Error reading config from $File: $e", "WARN")
        return Dict{String,Any}()
    end
end

"""
    FAST_UpdateConfig_DDEF(File, Updates) -> Bool
Surgically updates specific keys in the MasterConfig stored in the Excel file.
"""
FAST_UpdateConfig_DDEF(::Nothing, ::Dict) = false

function FAST_UpdateConfig_DDEF(File::AbstractString, Updates::Dict)::Bool
    try
        (isempty(File) || !isfile(File)) && return false
        C = FAST_Data_DDEC

        current_config = FAST_ReadConfig_DDEF(File)
        for (k, v) in Updates
            current_config[string(k)] = v
        end

        clean_config = FAST_SanitiseJSON_DDEF(current_config)
        json_str = JSON3.write(clean_config)

        config_df = DataFrame(
            "PARAMETER"  => ["MasterConfig"],
            "VALUE_JSON" => [json_str],
            "UPDATED_AT" => [string(now())],
        )

        FAST_WriteExcel_DDEF(File, C.SHEET_CONFIG, config_df)
        FAST_Log_DDEF("FAST", "CONFIG_UPDATED", "Updated $(length(Updates)) keys in MasterConfig", "OK")
        return true
    catch e
        FAST_Log_DDEF("FAST", "UPDATE_CFG_FAIL", sprint(showerror, e, catch_backtrace()), "FAIL")
        return false
    end
end

# ------------------------------------------------------------------------------
# SECTION 15: INFORMATICS SYNCHRONISATION & DIRECTION DISPATCH
# ------------------------------------------------------------------------------

"""
    FAST_SafeGet_DDEF(o, k, d=nothing)
Safely extracts key `k` from dict, named tuple, or struct via multiple dispatch.
"""
FAST_SafeGet_DDEF(::Nothing, k, d=nothing) = d

function FAST_SafeGet_DDEF(d::AbstractDict, k::AbstractString, default=nothing)
    haskey(d, k) && return d[k]
    sy = Symbol(k)
    return haskey(d, sy) ? d[sy] : default
end

function FAST_SafeGet_DDEF(d::AbstractDict, k::Symbol, default=nothing)
    haskey(d, k) && return d[k]
    sk = string(k)
    return haskey(d, sk) ? d[sk] : default
end

function FAST_SafeGet_DDEF(nt::NamedTuple, k::Symbol, default=nothing)
    return hasproperty(nt, k) ? getproperty(nt, k) : default
end

function FAST_SafeGet_DDEF(nt::NamedTuple, k::AbstractString, default=nothing)
    sy = Symbol(k)
    return hasproperty(nt, sy) ? getproperty(nt, sy) : default
end

function FAST_SafeGet_DDEF(o::Any, k, default=nothing)
    try
        sy = Symbol(k)
        hasproperty(o, sy) && return getproperty(o, sy)
    catch
    end
    return default
end

"""
    FAST_ParseDirection_DDEF(v) -> Int
Normalises integer, real, or semantic string representations of factor directions to `[-1, 0, 1]`.
"""
FAST_ParseDirection_DDEF(v::Integer)::Int = Int(clamp(v, -1, 1))

FAST_ParseDirection_DDEF(v::Real)::Int = isnan(v) ? -1 : Int(clamp(round(v), -1, 1))

function FAST_ParseDirection_DDEF(v::AbstractString)::Int
    s = uppercase(strip(v))
    s in ("1", "+1", "MAX", "MAXIMISE", "MAXIMIZE") && return 1
    s in ("0", "TARGET", "CENTER", "CENTRE")        && return 0
    s in ("-1", "MIN", "MINIMISE", "MINIMIZE")      && return -1
    parsed = tryparse(Float64, replace(s, ',' => '.'))
    !isnothing(parsed) && !isnan(parsed) && return Int(clamp(round(parsed), -1, 1))
    return -1
end

FAST_ParseDirection_DDEF(::Any)::Int = -1

"""
    FAST_DecodeDirections_DDEF(source, names) -> Tuple{Int,Int,Int}
Decodes factor directions using multiple dispatch on the source container type.
"""
function FAST_DecodeDirections_DDEF(dm::AbstractDict, names::AbstractVector)
    dm_norm = Dict{String,Int}(lowercase(strip(string(k))) => FAST_ParseDirection_DDEF(v) for (k, v) in pairs(dm))
    function get_val(idx)
        idx > length(names) && return -1
        target_name = lowercase(strip(string(names[idx])))
        return get(dm_norm, target_name, -1)
    end
    return (get_val(1), get_val(2), get_val(3))
end

FAST_DecodeDirections_DDEF(v::AbstractVector, ::AbstractVector) = (
    length(v) >= 3 ? (
        FAST_ParseDirection_DDEF(v[1]),
        FAST_ParseDirection_DDEF(v[2]),
        FAST_ParseDirection_DDEF(v[3])
    ) : (-1, -1, -1)
)

FAST_DecodeDirections_DDEF(::Any, ::AbstractVector) = (-1, -1, -1)

FAST_GetDirectionMap_DDEF(node::AbstractDict) = get(node, "DirectionMap", nothing)
FAST_GetDirectionMap_DDEF(::Any)              = nothing

FAST_ExtractMap_DDEF(dm::AbstractDict) = isempty(dm) ? nothing : dm
FAST_ExtractMap_DDEF(::Any)            = nothing

"""
    FAST_ExtractPhaseNumber_DDEF(key) -> Int
Extracts numeric sequence value from arbitrary phase identifier strings (e.g. "Phase2", "P3" -> 2, 3).
"""
function FAST_ExtractPhaseNumber_DDEF(key::Any)::Int
    m = match(r"\d+", string(key))
    return isnothing(m) ? 0 : something(tryparse(Int, m.match), 0)
end

"""
    FAST_ResolveHistoryMap_DDEF(history, [active_phase]) -> Union{AbstractDict, Nothing}
Dynamically resolves the active direction map across phase records, prioritising active_phase or latest chronological phase.
"""
function FAST_ResolveHistoryMap_DDEF(ph::AbstractDict, active_phase::AbstractString="")
    if !isempty(active_phase) && haskey(ph, active_phase)
        node = get(ph, active_phase, nothing)
        dm = FAST_ExtractMap_DDEF(FAST_GetDirectionMap_DDEF(node))
        !isnothing(dm) && return dm
    end
    # Dynamic chronological sort: sort phase keys by numeric sequence descending without hardcoded limits
    sorted_keys = sort(collect(keys(ph)), by=FAST_ExtractPhaseNumber_DDEF, rev=true)
    for key in sorted_keys
        node = get(ph, key, nothing)
        dm = FAST_ExtractMap_DDEF(FAST_GetDirectionMap_DDEF(node))
        !isnothing(dm) && return dm
    end
    return nothing
end
FAST_ResolveHistoryMap_DDEF(::Any, ::AbstractString="") = nothing

"""
    FAST_SelectSource_DDEF(history_source, global_source)
Selects the priority direction container via type dispatch.
"""
FAST_SelectSource_DDEF(hist::AbstractDict, ::Any) = hist
FAST_SelectSource_DDEF(::Any, glob)               = glob

"""
    FAST_ExtractDirections_DDEF(g, items, [active_phase]) -> Tuple{Int,Int,Int}
Extracts factor directions across multi-phase records and transient vector configurations.
Handles both full ingredient vectors (filtering for Variable) and pre-filtered variable configs.
"""
function FAST_ExtractDirections_DDEF(g::AbstractDict, items::AbstractVector, active_phase::AbstractString="")::Tuple{Int,Int,Int}
    names = [
        string(FAST_SafeGet_DDEF(c, "Name", "")) 
        for c in items 
        if string(FAST_SafeGet_DDEF(c, "Role", "Variable")) in ("Variable", "Var")
    ]
    target_ph = !isempty(active_phase) ? active_phase : string(get(g, "Phase", get(g, :Phase, "")))
    hist_map  = FAST_ResolveHistoryMap_DDEF(get(g, "PhaseHistory", nothing), target_ph)

    # 1. If history map for target phase matches current variable names:
    if !isnothing(hist_map)
        norm_keys = [lowercase(strip(string(k))) for k in keys(hist_map)]
        if any(lowercase(strip(n)) in norm_keys for n in names)
            return FAST_DecodeDirections_DDEF(hist_map, names)
        end
    end

    # 2. Check global Direction vector
    glob_dir = get(g, "Direction", nothing)
    if glob_dir isa AbstractVector && length(glob_dir) >= 3
        return FAST_DecodeDirections_DDEF(glob_dir, names)
    end

    # 3. Fallback to hist_map if available
    if !isnothing(hist_map)
        return FAST_DecodeDirections_DDEF(hist_map, names)
    end

    return (-1, -1, -1)
end

FAST_ExtractDirections_DDEF(::Any, ::Any, ::AbstractString="") = (-1, -1, -1)

"""
    FAST_DetectPhaseMethod_DDEF(Config::AbstractDict, df_data::DataFrame, PhaseName::AbstractString) -> String
Determines the experimental design method (BB15, CD17, DF14, TL09) for a specific phase
by querying PhaseHistory, inspecting run counts, or evaluating factor levels.
"""
function FAST_DetectPhaseMethod_DDEF(Config::AbstractDict, df_data::DataFrame, PhaseName::AbstractString)::String
    isempty(PhaseName) && return "BB15"
    clean_p = replace(strip(string(PhaseName)), " " => "")
    
    # 1. Check PhaseHistory in Config
    g_info = FAST_SafeGet_DDEF(Config, "Global", Dict{String,Any}())
    ph_raw = FAST_SafeGet_DDEF(g_info, "PhaseHistory", Dict{String,Any}())
    if ph_raw isa AbstractDict
        ph_entry = get(ph_raw, PhaseName, get(ph_raw, clean_p, get(ph_raw, Symbol(clean_p), nothing)))
        if ph_entry isa AbstractDict
            meth = uppercase(strip(string(FAST_SafeGet_DDEF(ph_entry, "Method", ""))))
            meth in ("BB15", "CD17", "DF14", "TL09") && return meth
        end
    end
    
    # 2. Inspect DataFrame run count for this phase
    C = FAST_Data_DDEC
    col_p = Symbol(C.COL_PHASE)
    if hasproperty(df_data, col_p)
        r_count = count(p -> !ismissing(p) && replace(strip(string(p)), " " => "") == clean_p, df_data[!, col_p])
        r_count == 15 && return "BB15"
        r_count == 17 && return "CD17"
        r_count == 14 && return "DF14"
        r_count == 9  && return "TL09"
    end
    
    # 3. Fallback to Global method
    glob_meth = uppercase(strip(string(FAST_SafeGet_DDEF(g_info, "Method", "BB15"))))
    glob_meth in ("BB15", "CD17", "DF14", "TL09") && return glob_meth
    
    return "BB15"
end

"""
    FAST_ResolveModelOptions_DDEF(PhaseMethod::AbstractString, DesiredModel::AbstractString="Auto") -> Tuple{Vector{Dict{String,String}}, String}
Constructs dropdown options and validates the selected statistical model based on design methodology.
Restricts screening designs (TL09) strictly to Linear, while higher-order response surface protocols
(BB15, CD17, DF14) provide Automatic, Linear, and Quadratic selections.
"""
function FAST_ResolveModelOptions_DDEF(PhaseMethod::AbstractString, DesiredModel::AbstractString="Auto")::Tuple{Vector{Dict{String,String}}, String}
    m_clean = uppercase(strip(PhaseMethod))
    if m_clean in ("TL09", "TAGUCHI", "LINEAR")
        opts = [Dict("label" => "Linear", "value" => "Linear")]
        return (opts, "Linear")
    end

    opts = [
        Dict("label" => "Automatic", "value" => "Auto"),
        Dict("label" => "Linear",    "value" => "Linear"),
        Dict("label" => "Quadratic", "value" => "Quadratic")
    ]
    cand = titlecase(strip(string(DesiredModel)))
    val = cand in ("Auto", "Linear", "Quadratic") ? cand : "Auto"
    return (opts, val)
end

"""
    FAST_DetectActivePhase_DDEF(df_data::DataFrame, Phases::AbstractVector) -> String
Identifies the default active phase for statistical evaluation. Selects the latest phase
containing experimental outcome measurements, falling back to Phase 1 for pending protocols.
"""
function FAST_DetectActivePhase_DDEF(df_data::DataFrame, Phases::AbstractVector)::String
    isempty(Phases) && return "Phase1"
    length(Phases) == 1 && return string(Phases[1])
    
    C = FAST_Data_DDEC
    col_p = Symbol(C.COL_PHASE)
    !hasproperty(df_data, col_p) && return string(Phases[1])
    
    out_cols = [Symbol(c) for c in names(df_data) if startswith(string(c), C.PRE_RESULT)]
    isempty(out_cols) && return string(Phases[1])
    
    # Inspect phases in reverse chronological order with zero intermediate allocations
    for p in reverse(Phases)
        p_clean = replace(strip(string(p)), " " => "")
        has_results = false
        for r in eachrow(df_data)
            row_p = ismissing(r[col_p]) ? "" : replace(strip(string(r[col_p])), " " => "")
            row_p != p_clean && continue
            for oc in out_cols
                val = r[oc]
                if !ismissing(val) && val isa Number && !isnan(val)
                    has_results = true
                    break
                end
            end
            has_results && break
        end
        has_results && return string(p)
    end
    
    return string(Phases[1])
end

# ------------------------------------------------------------------------------
# SECTION 16: HARDWARE AUDIT & THREADING
# ------------------------------------------------------------------------------

"""
    FAST_GetThreadInfo_DDEF()::Tuple{Int, String, String}
Audit check for CPU concurrency status. Returns (Count, Theme_Colour, Status_Message).
"""
function FAST_GetThreadInfo_DDEF()::Tuple{Int,String,String}
    n::Int = Threads.nthreads()
    n > 1 ? (n, "var(--colour-chr4-tongre)", "$n Threads [OPTIMAL]") : (n, "var(--colour-chr5-hueyel)", "1 Thread [SUB-OPTIMAL]")
end

"""
    FAST_ReadMemoFile_DDEF(FilePath::String) -> Dict{String, Any}
Loads a standardised DDE Memo file (JSON) from the local filesystem.
Returns an empty dictionary if the file is not found or is corrupt.
"""
function FAST_ReadMemoFile_DDEF(FilePath::AbstractString)::Dict{String,Any}
    try
        if !isfile(FilePath)
            FAST_Log_DDEF("FAST", "MEMO_NOT_FOUND", "Project reference $FilePath missing.", "WARN")
            return Dict{String,Any}()
        end
        
        json_str = read(FilePath, String)
        return JSON3.read(json_str, Dict{String,Any})
    catch e
        FAST_Log_DDEF("FAST", "MEMO_LOAD_FAIL", "Corruption in $FilePath: $e", "FAIL")
        return Dict{String,Any}()
    end
end

# ------------------------------------------------------------------------------
# SECTION 17: RACE CONDITION LOCK
# ------------------------------------------------------------------------------

# Global atomic lock pool — keyed by operation name
const FAST_OperationLocks_DDEC = Dict{String,ReentrantLock}()
const FAST_OperationLockTimes_DDEC = Dict{String,Float64}()
const FAST_LockGuard_DDEC = ReentrantLock()

"""
    FAST_AcquireLock_DDEF(op_name, Reason::AbstractString="Unspecified") -> Bool
Attempts to acquire a named operation lock without blocking. If the lock is held for more than 10.0 seconds, it is forcefully reset and re-acquired. Status telemetry is documented for system transparency.
"""
FAST_AcquireLock_DDEF(::Nothing, ::AbstractString="Unspecified") = false

function FAST_AcquireLock_DDEF(op_name::AbstractString, Reason::AbstractString="Unspecified")::Bool
    isempty(op_name) && return false
    now_time = time()
    
    lock(FAST_LockGuard_DDEC) do
        haskey(FAST_OperationLocks_DDEC, op_name) || (FAST_OperationLocks_DDEC[op_name] = ReentrantLock())
        
        # Check lock timeout (10 seconds)
        lk = FAST_OperationLocks_DDEC[op_name]
        if islocked(lk) && haskey(FAST_OperationLockTimes_DDEC, op_name)
            held_duration = now_time - FAST_OperationLockTimes_DDEC[op_name]
            if held_duration > 10.0
                FAST_Log_DDEF("SYS", "LOCK_TIMEOUT", "Lock: $op_name has been held for $(round(held_duration; digits=1))s. Force unlocking.", "WARN")
                try
                    while islocked(lk)
                        unlock(lk)
                    end
                catch e
                    FAST_Log_DDEF("SYS", "LOCK_TIMEOUT_ERR", "Failed to force unlock: $e", "FAIL")
                end
                delete!(FAST_OperationLockTimes_DDEC, op_name)
            end
        end
    end
    
    lk = FAST_OperationLocks_DDEC[op_name]
    success = trylock(lk)
    if success
        lock(FAST_LockGuard_DDEC) do
            FAST_OperationLockTimes_DDEC[op_name] = now_time
        end
        FAST_Log_DDEF("SYS", "LOCK_ACQUIRE", "Lock: $op_name | Reason: $Reason", "OK")
    else
        FAST_Log_DDEF("SYS", "LOCK_REJECT", "Lock: $op_name | Active Process Detected", "WARN")
    end
    return success
end

"""
    FAST_ReleaseLock_DDEF(op_name::Union{AbstractString,Nothing})
Releases the named operation lock safely. Telemetry records release status and handles reentrancy or ownership violations.
"""
FAST_ReleaseLock_DDEF(::Nothing) = nothing

function FAST_ReleaseLock_DDEF(op_name::AbstractString)
    isempty(op_name) && return nothing
    haskey(FAST_OperationLocks_DDEC, op_name) || return nothing
    lk = FAST_OperationLocks_DDEC[op_name]
    if islocked(lk)
        try
            unlock(lk)
            still_locked = islocked(lk)
            if still_locked
                FAST_Log_DDEF("SYS", "LOCK_REL_PARTIAL", "Lock: $op_name (Reentrancy Level Decreased)", "INFO")
            else
                lock(FAST_LockGuard_DDEC) do
                    delete!(FAST_OperationLockTimes_DDEC, op_name)
                end
                FAST_Log_DDEF("SYS", "LOCK_RELEASE", "Lock: $op_name (Active Lock: OFF)", "INFO")
            end
        catch e
            FAST_Log_DDEF("SYS", "LOCK_REL_FAIL", "Lock: $op_name | Error: $(string(e))", "FAIL")
        end
    else
        FAST_Log_DDEF("SYS", "LOCK_REL_IDLE", "Lock: $op_name already free.", "LIST")
    end
    return nothing
end

"""
    FAST_ForceReleaseAll_DDEF()
Clears all operation locks from the global pool. Reserved exclusively for system recovery protocols.
"""
function FAST_ForceReleaseAll_DDEF()
    lock(FAST_LockGuard_DDEC) do
        empty!(FAST_OperationLocks_DDEC)
        empty!(FAST_OperationLockTimes_DDEC)
    end
    FAST_Log_DDEF("SYS", "LOCK_FLUSH", "All operation locks successfully cleared during system recovery.", "WARN")
    return nothing
end

# ------------------------------------------------------------------------------
# SECTION 18: IN-MEMORY TRANSIENT CACHE
# ------------------------------------------------------------------------------

const FAST_CacheStore_DDEC = Dict{String,DataFrame}()
const FAST_CacheLock_DDEC  = ReentrantLock()

"""
    FAST_ReadCache_DDEF(key) -> Union{DataFrame, Nothing}
Thread-safe read from the in-memory cache.
"""
FAST_ReadCache_DDEF(::Nothing) = nothing

function FAST_ReadCache_DDEF(key::AbstractString)::Union{DataFrame,Nothing}
    isempty(key) && return nothing
    lock(FAST_CacheLock_DDEC) do
        haskey(FAST_CacheStore_DDEC, key) ? copy(FAST_CacheStore_DDEC[key]) : nothing
    end
end

"""
    FAST_WriteCache_DDEF(key, df)
Thread-safe write to the in-memory cache.
"""
FAST_WriteCache_DDEF(::Nothing, ::DataFrame) = nothing

function FAST_WriteCache_DDEF(key::AbstractString, df::DataFrame)::Nothing
    isempty(key) && return nothing
    lock(FAST_CacheLock_DDEC) do
        FAST_CacheStore_DDEC[key] = copy(df)
    end
    FAST_Log_DDEF("CACHE", "WRITE", "Cached '$(key)' ($(nrow(df)) rows)", "OK")
    return nothing
end

function FAST_ResetCache_DDEF()
    lock(FAST_CacheLock_DDEC) do
        empty!(FAST_CacheStore_DDEC)
    end
    FAST_Log_DDEF("CACHE", "EVICT", "All in-memory DataFrames cleared.", "INFO")
    return nothing
end

# ------------------------------------------------------------------------------
# SECTION 19: BINARY VAULT (SERVER-SIDE BLOB STORAGE)
# ------------------------------------------------------------------------------

# Binary storage for binary objects (Excel archives).
const FAST_VaultStore_DDEC = Dict{String, Vector{UInt8}}()
const FAST_VaultLock_DDEC   = ReentrantLock()

"""
    FAST_WriteVault_DDEF(key, binary)
Thread-safe write to binary vault.
"""
function FAST_WriteVault_DDEF(key::AbstractString, binary::Vector{UInt8})::Nothing
    lock(FAST_VaultLock_DDEC) do
        FAST_VaultStore_DDEC[key] = binary
    end
    FAST_Log_DDEF("VAULT", "STORE", "Binary persisted ($key) | Size: $(length(binary) ÷ 1024) KB", "OK")
    return nothing
end

"""
    FAST_ReadVault_DDEF(key) -> Vector{UInt8}
Thread-safe read from binary vault.
"""
FAST_ReadVault_DDEF(::Nothing) = nothing

function FAST_ReadVault_DDEF(key::AbstractString)::Union{Vector{UInt8}, Nothing}
    lock(FAST_VaultLock_DDEC) do
        return haskey(FAST_VaultStore_DDEC, key) ? FAST_VaultStore_DDEC[key] : nothing
    end
end

# ------------------------------------------------------------------------------
# SECTION 20: COMPUTE RESOURCES & SYSTEM DIAGNOSTICS
# ------------------------------------------------------------------------------

"""
    FAST_GetComputeThreads_DDEF() -> Int
Returns available threading resources for parallel computation, reserving a primary thread for the HTTP loop.
"""
function FAST_GetComputeThreads_DDEF()::Int
    total = Threads.nthreads()
    return max(1, total - 1)
end

function FAST_FormatDuration_DDEF(seconds::Float64)::String
    seconds < 0.001 && return "<1ms"
    seconds < 1.0   && return @sprintf("%.0fms", seconds * 1000)
    seconds < 60.0  && return @sprintf("%.2fs", seconds)
    minutes = seconds / 60.0
    return @sprintf("%.1fmin", minutes)
end

function FAST_ValidateDataFrame_DDEF(df::DataFrame, RequiredCols::Vector{String}=String[])::Tuple{Bool,Vector{String}}
    issues = String[]
    isempty(df) && (push!(issues, "DataFrame is empty."); return (false, issues))
    for c in RequiredCols
        if !hasproperty(df, Symbol(c))
            push!(issues, "Missing required column: '$c'")
        end
    end
    for col in names(df)
        T = eltype(df[!, col])
        if T <: Union{Missing,Number} || T <: Number
            vals = collect(skipmissing(df[!, col]))
            numeric_vals = filter(v -> v isa Number, vals)
            if !isempty(numeric_vals)
                nan_count = count(v -> v isa AbstractFloat && isnan(v), numeric_vals)
                if nan_count == length(numeric_vals)
                    push!(issues, "Column '$col' is entirely NaN.")
                elseif nan_count > length(numeric_vals) * 0.5
                    push!(issues, "Column '$col' has >50% NaN values ($(nan_count)/$(length(numeric_vals))).")
                end
            end
        end
    end
    return (isempty(issues), issues)
end

"""
    FAST_GetSystemQuote_DDEF() -> String
Provides a stochastic selection of scientific and academic citations to reinforce research focus.
"""
function FAST_GetSystemQuote_DDEF()::String
    quotes = [
        "Mathematics is the language of the universe. - G.G.",
        "Everything should be as simple as possible, but not simpler. - A.E.",
        "Errors with data are better than errors without it. - F.N.",
        "The best way to predict the future is to create it. - P.D.",
        "Measure what is measurable, and make measurable what is not. - G.G.",
        "Science is a way of thinking, not a body of knowledge. - C.S.",
        "All science is the refinement of everyday thinking. - A.E.",
        "An investment in knowledge pays the best interest. - B.F.",
        "I have no special talent, I am only passionately curious. - A.E.",
        "The science of today is the technology of tomorrow. - E.T.",
    ]
    return rand(quotes)
end

"""
    FAST_GetColumn_DDEF(df::DataFrame, Target::AbstractString)::String
Identifies the formalised column name in a DataFrame matching the target criterion (Non-destructive operation).
"""
function FAST_GetColumn_DDEF(df::DataFrame, Target::AbstractString)::String
    isempty(df) && return ""
    isempty(strip(Target)) && return ""

    norm_col(s) = uppercase(replace(replace(strip(string(s)), " " => "_"), r"_+" => "_"))
    t_norm = norm_col(Target)

    # 1. Exact normalised match (spaces vs underscores, case-insensitive)
    for n in names(df)
        n_str = string(n)
        if norm_col(n_str) == t_norm
            return n_str
        end
    end

    # 2. Match with unit or suffix attached (e.g. TARGET_unit or TARGET_%)
    for n in names(df)
        n_str = string(n)
        n_norm = norm_col(n_str)
        if startswith(n_norm, t_norm * "_")
            return n_str
        end
    end

    # 3. Flexible prefix match (e.g. TARGET (%))
    for n in names(df)
        n_str = string(n)
        n_norm = norm_col(n_str)
        if startswith(n_norm, t_norm) && (length(n_norm) == length(t_norm) || n_norm[length(t_norm)+1] in ('_', ' ', '(', '%'))
            return n_str
        end
    end

    return ""
end

"""
    FAST_SanitiseHeader_DDEF(Header::AbstractString) -> String
Standardises column headers through the removal of internal system prefixes.
"""
function FAST_SanitiseHeader_DDEF(Header::AbstractString)
    h = strip(string(Header))
    isempty(h) && return ""
    C = FAST_Data_DDEC
    prefixes = (C.PRE_VAR, C.PRE_FIXED, C.PRE_FILL, C.PRE_MASS, C.PRE_RESULT, C.PRE_PRED, C.PRE_CHRO, C.PRE_ACTUAL, C.PRE_TIME_FORW, C.PRE_TIME_REVE, C.PRE_TIME_DCYP)
    for pfx in prefixes
        if startswith(uppercase(h), uppercase(pfx))
            return string(strip(h[nextind(h, length(pfx)):end]))
        end
    end
    return h
end

"""
    FAST_FormatDisplayHeader_DDEF(Header::AbstractString) -> String
Standardises column headers for human presentation in the UI:
Strips internal system prefixes (VARIA_, RESULT_, PRED_, ACTUAL_, etc.) and converts underscores to spaces.
Never presents internal prefixes or raw underscores in the user interface.
"""
function FAST_FormatDisplayHeader_DDEF(Header::AbstractString)::String
    h = strip(string(Header))
    isempty(h) && return ""
    clean = FAST_SanitiseHeader_DDEF(h)
    return replace(clean, "_" => " ")
end

# ------------------------------------------------------------------------------
# SECTION 21: STRUCTURAL COLUMN ORDERING & KINETIC DECAY ORCHESTRATION
# ------------------------------------------------------------------------------

"""
    FAST_SortColumns_DDEF(cols::Vector{String}) -> Vector{String}
Arranges dataset column headers according to standard DoECISORY scientific taxonomy:
System -> Mass -> Variables -> Fixed -> Fill -> Results -> Predictions -> Score -> Radioactivity -> Others.
"""
function FAST_SortColumns_DDEF(cols::Vector{String})::Vector{String}
    isempty(cols) && return cols
    C = FAST_Data_DDEC

    b_sys    = String[]
    b_mass   = String[]
    b_var    = String[]
    b_fix    = String[]
    b_fill   = String[]
    b_res    = String[]
    b_pred   = String[]
    b_score  = String[]
    b_act    = String[]
    b_time   = String[]
    b_other  = String[]

    sys_order = [C.COL_EXP_ID, C.COL_PHASE, C.COL_STATUS, C.COL_NOTES, C.COL_RUN_ORDER]

    for col in cols
        c_up = uppercase(strip(col))
        if col in sys_order || c_up in uppercase.(sys_order)
            push!(b_sys, col)
        elseif startswith(c_up, uppercase(C.PRE_MASS))
            push!(b_mass, col)
        elseif startswith(c_up, uppercase(C.PRE_VAR))
            push!(b_var, col)
        elseif startswith(c_up, uppercase(C.PRE_FIXED))
            push!(b_fix, col)
        elseif startswith(c_up, uppercase(C.PRE_FILL))
            push!(b_fill, col)
        elseif startswith(c_up, uppercase(C.PRE_RESULT))
            push!(b_res, col)
        elseif startswith(c_up, uppercase(C.PRE_PRED))
            push!(b_pred, col)
        elseif col == C.COL_SCORE || c_up == uppercase(C.COL_SCORE)
            push!(b_score, col)
        elseif startswith(c_up, uppercase(C.PRE_ACTUAL))
            push!(b_act, col)
        elseif startswith(c_up, uppercase(C.PRE_TIME_FORW)) || startswith(c_up, uppercase(C.PRE_TIME_DCYP)) ||
               startswith(c_up, uppercase(C.PRE_TIME_REVE))
            push!(b_time, col)
        else
            push!(b_other, col)
        end
    end
    b_radio = vcat(b_act, b_time)

    sorted_sys = String[]
    for s in sys_order
        idx = findfirst(c -> uppercase(strip(c)) == uppercase(strip(s)), b_sys)
        !isnothing(idx) && push!(sorted_sys, b_sys[idx])
    end
    for c in b_sys
        c ∉ sorted_sys && push!(sorted_sys, c)
    end

    return vcat(sorted_sys, b_mass, b_var, b_fix, b_fill, b_res, b_pred, b_score, b_radio, b_other)
end

# ------------------------------------------------------------------------------
# SECTION 37: COMPOSITE SVG FIGURE PLATE ASSEMBLER
# ------------------------------------------------------------------------------

"""
    FAST_AssembleSvgPlate_DDEF(Images::AbstractVector{<:AbstractString}, LayoutType::Symbol=:Grid2x3) -> String
Assemble a composite SVG figure plate according to the 145 mm publication standard.
Accepts either a vector of base64 PNG data strings or local PNG file paths.
Supported LayoutTypes:
- `:Grid2x3` (default): 6 panels (2 rows × 3 columns, 145 mm × 115.200 mm), labelled A to F.
- `:Grid3x3`: 9 panels (3 rows × 3 columns, 145 mm × 172.800 mm), labelled A to I.
- `:Strip1x3`: 3 panels (1 row × 3 columns, 145 mm × 57.600 mm), labelled A to C.
"""
function FAST_AssembleSvgPlate_DDEF(Images::AbstractVector{<:AbstractString}, LayoutType::Symbol=:Grid2x3)::String
    n_panels = (LayoutType == :Grid3x3) ? 9 : ((LayoutType == :Strip1x3) ? 3 : 6)
    h_str    = (LayoutType == :Grid3x3) ? "172.800" : ((LayoutType == :Strip1x3) ? "57.600" : "115.200")

    col_x = (1.0, 49.333, 97.666)
    row_y = (1.0, 58.600, 116.200)

    buf = IOBuffer()
    print(buf, "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"145mm\" height=\"", h_str, "mm\" viewBox=\"0 0 145 ", h_str, "\"><rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>")

    max_items = min(length(Images), n_panels)
    for i in 1:max_items
        r = (i - 1) ÷ 3
        c = (i - 1) % 3
        px = col_x[c + 1]
        py = row_y[r + 1]
        tx = px + 0.988
        ty = py + 3.528
        lbl = Char('A' + (i - 1))

        px_str = (px == 1.0) ? "1" : @sprintf("%.3f", px)
        py_str = (py == 1.0) ? "1" : @sprintf("%.3f", py)
        tx_str = @sprintf("%.3f", tx)
        ty_str = @sprintf("%.3f", ty)

        raw = Images[i]
        b64 = if isfile(raw)
            Base64.base64encode(read(raw))
        elseif startswith(raw, "data:image/png;base64,")
            raw[23:end]
        else
            raw
        end

        print(buf, "<svg x=\"", px_str, "\" y=\"", py_str, "\" width=\"46.333\" height=\"55.600\" viewBox=\"18 0 450 540\" preserveAspectRatio=\"none\"><image width=\"480\" height=\"540\" href=\"data:image/png;base64,", b64, "\" xlink:href=\"data:image/png;base64,", b64, "\"/></svg>")
        print(buf, "<text x=\"", tx_str, "\" y=\"", ty_str, "\" font-family=\"Helvetica, Arial, sans-serif\" font-weight=\"700\" font-size=\"2.822\" fill=\"#000000\">", lbl, "</text>")
    end

    print(buf, "</svg>")
    return String(take!(buf))
end

end