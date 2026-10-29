module Gui_Base

# ==============================================================================
# DOECISORY - GUI BASE (SHARED UI COMPONENTS & APP SHELL)
# ==============================================================================
# Description: Reusable Dash-Bootstrap components, high-fidelity styling tokens,
#              global routing orchestration, and JIT warmup engine.
# Module Tag:  BASE
# ==============================================================================

using Dash
using DashBootstrapComponents
using DataFrames
using PlotlyJS
using ..Sys_Fast
using ..Lib_Core
using ..Lib_Mole
using ..Lib_Vise
using ..Lib_Arts

export BASE_StyleCell_DDEC, BASE_StyleInput_DDEC, BASE_StyleInputCentre_DDEC, 
       BASE_StyleHeader_DDEC, BASE_StyleDataTableCell_DDEC, BASE_StyleInlineHeader_DDEC, 
       BASE_StyleHr_DDEC, BASE_EmptyFigure_DDEC, BASE_SafeRows_DDEF, BASE_GetTrigger_DDEF, 
       BASE_BuildPageHeader_DDEF, BASE_BuildGlassPanel_DDEF, BASE_BuildDataTable_DDEF, BASE_BuildModal_DDEF, 
       BASE_ApplyPlotlyWhite_DDEF!, BASE_BuildVitalCard_DDEF, BASE_BuildLoading_DDEF, 
       BASE_BuildSystemAudit_DDEF, BASE_BuildSciAudit_DDEF, BASE_BuildStatusIcon_DDEF, 
       BASE_BuildIconButton_DDEF, BASE_BuildTableHeader_DDEF, BASE_BuildControlGroup_DDEF, 
       BASE_BuildActionButton_DDEF, BASE_BuildSeparator_DDEF, BASE_BuildSidebarHeader_DDEF, 
       BASE_BuildUpload_DDEF, BASE_BuildNextButton_DDEF, BASE_BuildIDRow_DDEF, BASE_BuildLevelRow_DDEF, 
       BASE_BuildLimitsRow_DDEF, BASE_BuildGoalRow_DDEF, BASE_ValidateUniqueNames_DDEF,
       BASE_BuildNavbar_DDEF, BASE_BuildLayout_DDEF, BASE_RoutePage_DDEF, BASE_SyncVault_DDEF,
       BASE_RegisterDiagnostics_DDEF, BASE_RegisterRecovery_DDEF,
       BASE_HandleLoadingOverlay_DDEF, BASE_RegisterAppCallbacks_DDEF,
       BASE_WarmupApp_DDEF, BASE_CreateApp_DDEF, BASE_SystemReady_DDEC

# ==============================================================================
# PART A: DESIGN SYSTEM & ATOMIC WIDGETS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: DATATABLE AESTHETICS & GRID TOKENS
# ------------------------------------------------------------------------------

const BASE_StyleCell_DDEC = Dict(
    "backgroundColor" => "transparent",
    "border"          => "none",
    "borderBottom"    => "none",
    "verticalAlign"   => "middle",
    "padding"         => "0px",
)

const BASE_StyleInput_DDEC = Dict(
    "backgroundColor" => "transparent",
    "border"          => "none",
    "color"           => "var(--colour-val5-purbla)",
    "fontSize"        => "10px",
    "width"           => "100%",
    "outline"         => "none",
    "fontFamily"      => "var(--font-sans)",
)

const BASE_StyleInputCentre_DDEC = merge(BASE_StyleInput_DDEC, Dict("textAlign" => "center"))

const BASE_StyleHeader_DDEC = Dict(
    # Orchestration of the header background colour with standardised padding.
    "backgroundColor" => "var(--colour-val0-purwhi)", 
    "color"           => "var(--colour-val4-darhig)",
    "borderBottom"    => "2px solid var(--colour-val1-lighig)",
    "fontSize"        => "0.70rem", 
    "padding"         => "6px 5px",
    "fontWeight"      => "600",
)

const BASE_StyleDataTableCell_DDEC = Dict(
    # Standardised background colour for data-focused components.
    "backgroundColor" => "var(--colour-val0-purwhi)", 
    "color"           => "var(--colour-val5-purbla)",
    "border"          => "none",
    "borderBottom"    => "none",
    "fontFamily"      => "var(--font-sans)", 
    "fontSize"        => "10px", 
    "padding"         => "6px 5px",
)

const BASE_StyleInlineHeader_DDEC = Dict(
    "backgroundColor" => "transparent",
    "color"           => "var(--colour-val4-darhig)",
    "fontWeight"      => "600",
    "fontSize"        => "0.65rem",
    "letterSpacing"   => "0.05em",
    "border"          => "none",
    "borderBottom"    => "none",
    "paddingBottom"   => "4px",
)

const BASE_StyleHr_DDEC = Dict("borderColor" => "var(--colour-val1-lighig)", "margin" => "6px 0")

const BASE_EmptyFigure_DDEC = let C = FAST_Data_DDEC
    Dict(
        "data"   => [],
        "layout" => Dict(
            "width"          => 480,
            "height"         => 380,
            "autosize"       => false,
            "paper_bgcolor"  => C.COLOUR_PURWHI,
            "plot_bgcolor"   => C.COLOUR_LIGLOW,
            "xaxis"          => Dict("visible" => false, "showgrid" => false, "zeroline" => false),
            "yaxis"          => Dict("visible" => false, "showgrid" => false, "zeroline" => false),
            "margin"         => Dict("l" => 0, "r" => 0, "t" => 0, "b" => 0),
            "annotations"    => [
                Dict(
                    "text"      => "<b>No Visualisation Data</b><br><span style='font-size:12px'>Run analysis to generate plots</span>",
                    "showarrow" => false,
                    "xref"      => "paper",
                    "yref"      => "paper",
                    "x"         => 0.5,
                    "y"         => 0.5,
                    "font"      => Dict("color" => C.COLOUR_DARHIG, "size" => 16, "family" => C.FONT_DEFAULT),
                )
            ],
        ),
    )
end

# ------------------------------------------------------------------------------
# SECTION 2: GENERAL COMPONENT CONSTRUCTORS
# ------------------------------------------------------------------------------

"""
    BASE_BuildPageHeader_DDEF(title, subtitle) -> Row
Constructs a standardised page header with a primary title and descriptive subtitle.
"""
function BASE_BuildPageHeader_DDEF(title::String, subtitle::String)
    return dbc_row(dbc_col([
        html_h3(title, className="mb-1 colourtx-v5pb"),
        html_p([
            subtitle,
            html_br(),
            html_span([
                # System alert for stateless operational constraints.
                html_i(className="fas fa-exclamation-triangle me-1"), 
                " Stateless architecture: Refreshing the browser will clear all inputted parameters and unsaved analyses."
            ], className="small fst-italic colourtx-v4dh", style=Dict("fontSize" => "0.75rem"))
        ], className="small colourtx-v4dh"),
    ], xs=12), className="mb-2")
end

"""
    BASE_BuildGlassPanel_DDEF(title, content; [right_node], [panel_class], [content_class], [overflow]) -> Div
Constructs a semi-transparent 'glass-panel' container for grouping UI elements.
"""
function BASE_BuildGlassPanel_DDEF(title::Union{String, Vector{Any}}, content; right_node=nothing, panel_class="h-100", content_class="glass-content p-2 p-md-3", overflow="hidden")
    header_content = Any[html_span(title, className="glass-caption")]
    !isnothing(right_node) && push!(header_content, right_node)

    return html_div([
        html_div(header_content, className="glass-header d-flex justify-content-between align-items-center mb-0 colourbg-v0pw"),
        html_div(content,        className=content_class)
    ], className="glass-panel colourbg-v0pw $panel_class", style=Dict("overflow" => overflow))
end

"""
    BASE_BuildDataTable_DDEF(id, columns, data; kwargs...) -> DataTable
A Dash DataTable wrapper ensuring aesthetic consistency and responsive data presentation.
"""
function BASE_BuildDataTable_DDEF(id::String, columns::Vector, data; kwargs...)
    return dash_datatable(;
        id           = id, 
        columns      = columns, 
        data         = data,
        style_table  = Dict("overflowX" => "auto", "overflowY" => "visible", "borderCollapse" => "collapse", "width" => "100%"),
        style_header = BASE_StyleHeader_DDEC,
        style_cell   = BASE_StyleDataTableCell_DDEC,
        css          = [
            Dict("selector" => ".dash-spreadsheet-container .dash-spreadsheet-inner th", "rule" => "padding: 0.25rem; font-size: 0.70rem; letter-spacing: 0.05em;"),
            Dict("selector" => ".dash-spreadsheet-container .dash-spreadsheet-inner td", "rule" => "padding: 0.25rem; font-size: 10px;")
        ],
        kwargs...
    )
end

"""
    BASE_BuildModal_DDEF(id, title, body, footer; [size], [is_open], [centred], [close_button]) -> Modal
Constructs a standardised modal dialogue for focused user interactions.
"""
function BASE_BuildModal_DDEF(id::String, title, body, footer; size="lg", is_open=false, centred=true, close_button=true, kwargs...)
    return dbc_modal([
        dbc_modalheader(dbc_modaltitle(title); close_button=close_button),
        dbc_modalbody(body),
        dbc_modalfooter(footer)
    ]; id=id, is_open=is_open, size=size, centered=centred, kwargs...)
end

# ==============================================================================
# PART B: SHARED HELPERS & DYNAMIC BUILDERS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 3: CALLBACK CONTEXT & DATA TRANSLATION
# ------------------------------------------------------------------------------

"""
    BASE_SafeRows_DDEF(d) -> Vector{Dict{String,Any}}
Converts raw callback data (Any-keyed dictionaries) into string-keyed dictionary vectors for processing.
"""
BASE_SafeRows_DDEF(d) = isnothing(d) ? Dict{String,Any}[] :
                        [Dict{String,Any}(string(k) => v for (k, v) in r) for r in d]

"""
    BASE_GetTrigger_DDEF(ctx) -> String
Extracts the identifier of the component that initiated the current callback.
"""
function BASE_GetTrigger_DDEF(ctx)
    isempty(ctx.triggered) && return ""
    return ctx.triggered[1].prop_id |> x -> split(x, ".")[1]
end

"""
    BASE_ApplyPlotlyWhite_DDEF!(fig_dict) -> Dict
Transforms a PlotlyJS figure object into a high-contrast white theme suitable for academic publications.
"""
function BASE_ApplyPlotlyWhite_DDEF!(fig_dict)
    if haskey(fig_dict, "layout")
        C               = FAST_Data_DDEC
        lay             = fig_dict["layout"]
        lay["template"]      = "plotly_white"
        lay["paper_bgcolor"] = C.COLOUR_PURWHI
        lay["plot_bgcolor"]  = C.COLOUR_PURWHI
        lay["font"]          = Dict("color" => C.COLOUR_PURBLA, "family" => "Arial", "size" => 16)

        if haskey(lay, "scene")
            lay["scene"]["bgcolor"] = C.COLOUR_PURWHI
            for ax in ("xaxis", "yaxis", "zaxis")
                if haskey(lay["scene"], ax)
                    lay["scene"][ax]["color"]           = C.COLOUR_PURBLA
                    lay["scene"][ax]["gridcolor"]       = C.COLOUR_LIGHIG
                    lay["scene"][ax]["zerolinecolor"]   = C.COLOUR_LIGHIG
                    lay["scene"][ax]["backgroundcolor"] = C.COLOUR_PURWHI
                end
            end
        end

        for ax in ("xaxis", "yaxis")
            if haskey(lay, ax)
                lay[ax]["color"]         = C.COLOUR_PURBLA
                lay[ax]["gridcolor"]     = C.COLOUR_LIGHIG
                lay[ax]["zerolinecolor"] = C.COLOUR_LIGHIG
            end
        end
    end
    return fig_dict
end

# ------------------------------------------------------------------------------
# SECTION 4: ATOMIC WIDGETS & INPUT CONTROLS
# ------------------------------------------------------------------------------

"""
    BASE_BuildVitalCard_DDEF(label, value, color) -> Card
Displays a compact quantitative metric for real-time system monitoring.
"""
function BASE_BuildVitalCard_DDEF(label::String, value::String, color_class::String="colourtx-c1sm")
    return dbc_card([
        html_div(label, 
            className = "small text-uppercase fw-bold colourtx-v3dl", 
            style     = Dict("fontSize" => "0.6rem", "letterSpacing" => "0.5px")),
        html_div(value, 
            className = "h6 mb-0 fw-bold $color_class")
    ], body=true, className="p-2 border-0 shadow-sm text-center colourbg-v0pw")
end

"""
    BASE_BuildLoading_DDEF(id, content; [color]) -> Row
Constructs a standardised loading indicator for background process feedback.
"""
function BASE_BuildLoading_DDEF(id::String, content; color::String="var(--colour-chr1-shamag)", class="mt-2 small")
    return dbc_row(dbc_col(dcc_loading(html_div(content, id=id, className=class), type="default", color=color), xs=12))
end

"""
    BASE_BuildStatusIcon_DDEF(symbol, id; [color], [size], [tip], [glow]) -> Span
Constructs a small status indicator for identifying specific dataset attributes in grids.
"""
function BASE_BuildStatusIcon_DDEF(symbol::String, id::String; color_class::String="colourtx-v4dh", size::String="0.65rem", tip=nothing, glow=false)
    s = Dict("fontSize" => size, "marginRight" => "2px", "cursor" => "help")
    if glow
        s["textShadow"] = "0 0 5px currentColor"
        s["fontWeight"] = "bold"
    end
    
    target_id = id
    icon = html_span(symbol, id=target_id, className=color_class, style=s)
    
    isnothing(tip) && return icon
    
    tip_id = "tip-" * id
    return html_span([
        icon, 
        dbc_tooltip(tip, target=target_id, id=tip_id, placement="top", is_open=false)
    ])
end

"""
    BASE_BuildIconButton_DDEF(id, icon_class; [color], [size], [tip]) -> html_button
Compact button containing only a FontAwesome icon, primarily for grid property cogs.
"""
function BASE_BuildIconButton_DDEF(id::String, icon_class::String; color_class="colourtx-v3dl", size="0.80rem", tip=nothing)
    btn = html_button(html_i(className="$icon_class $color_class", style=Dict("fontSize" => size)),
        id=id, n_clicks=0,
        style=Dict("cursor" => "pointer", "background" => "none", "border" => "none", "padding" => "2px"))
    isnothing(tip) && return btn
    return html_span([btn, dbc_tooltip(tip, target=id)])
end

"""
    BASE_BuildTableHeader_DDEF(label; [width], [textAlign]) -> html_th
Standardised table header cell with consistent typography and padding.
"""
function BASE_BuildTableHeader_DDEF(label::String; width="auto", textAlign="center", padding="2px", kwargs...)
    style_payload = copy(BASE_StyleInlineHeader_DDEC)
    
    # Apply standard overrides from defaults
    style_payload["width"] = width
    style_payload["textAlign"] = textAlign
    style_payload["padding"] = padding
    
    args = Dict(kwargs)
    if haskey(args, :style)
        merge!(style_payload, args[:style])
        delete!(args, :style)
    end
    
    return html_th(label; style=style_payload, className="p-0", args...)
end

"""
    BASE_BuildControlGroup_DDEF(label, input; [help]) -> Row
Standardised control unit pairing a descriptive label with a Dash input component.
"""
function BASE_BuildControlGroup_DDEF(label::String, input; class="mb-3")
    return dbc_row(dbc_col([
                dbc_label(label, className="small mb-1"),
                input
            ], xs=12), className=class)
end

"""
    BASE_BuildActionButton_DDEF(id, label, icon; [color], [outline], [size], [class]) -> Button
Constructs a standardised action button with an integrated FontAwesome icon.
"""
function BASE_BuildActionButton_DDEF(id::String, label::String, icon::String; outline=true, size="sm", class="w-100 mb-2 fw-bold", style_override=Dict("borderColor" => "var(--colour-val1-lighig)"), kwargs...)
    return dbc_button([html_i(className="$icon me-2"), label], id=id, n_clicks=0, outline=outline, size=size, className="$class", style=style_override; kwargs...)
end

"""
    BASE_BuildNextButton_DDEF(id, label; [icon]) -> Row
Primary navigation button intended for phase transitions and execution triggers.
"""
function BASE_BuildNextButton_DDEF(id::String, label::String; icon::String="fas fa-play", class="w-100 fw-bold mb-2", kwargs...)
    return dbc_row(dbc_col(dbc_button([html_i(className="$icon me-2"), label], id=id, n_clicks=0, style=Dict("borderWidth" => "1px", "borderStyle" => "solid", "borderColor" => "var(--colour-chr4-tongre)"), size="sm", className="$class colourgl-c4tg"; kwargs...), xs=12))
end

"""
    BASE_BuildSeparator_DDEF(; [class]) -> dbc_row
Standardised horizontal rule for dividing sidebar sections.
"""
function BASE_BuildSeparator_DDEF(; class="my-2")
    return dbc_row(dbc_col(html_hr(style=BASE_StyleHr_DDEC, className=class), xs=12))
end

"""
    BASE_BuildSidebarHeader_DDEF(label; [icon]) -> Row
Standardised header for demarcating logical sections within the application sidebar.
"""
function BASE_BuildSidebarHeader_DDEF(label::String; icon=nothing, class="small mb-1 fw-bold text-center")
    children = Any[]
    if !isnothing(icon)
        push!(children, html_i(className="$icon me-2"))
    end
    push!(children, label)
    return dbc_row(dbc_col(html_div(children, className=class), xs=12))
end

"""
    BASE_BuildUpload_DDEF(id, label, icon; [multiple]) -> dbc_row
Standardised upload component for dataset ingestion.
"""
function BASE_BuildUpload_DDEF(id::String, label::String, icon::String; multiple=false, class="w-100 mb-2 fw-bold", kwargs...)
    return dbc_row(dbc_col(dcc_upload(id=id, children=BASE_BuildActionButton_DDEF(id * "-btn", label, icon; class=class, kwargs...), multiple=multiple), xs=12))
end

# ------------------------------------------------------------------------------
# SECTION 5: UI BUILDERS (DECK & LENS)
# ------------------------------------------------------------------------------

"""
    BASE_BuildIDRow_DDEF(i, row, visible, [show_del]) -> Tr
Constructs a table row for ingredient identification, including deletion and property controls.
"""
function BASE_BuildIDRow_DDEF(i, row, visible, show_del=false)
    row_style = Dict("display" => visible ? "table-row" : "none")
    name_val  = string(get(row, "Name", ""))

    name_input_style = Dict{String, Any}()

    del_btn = html_button("×", id="deck-del-$i", n_clicks=0,
        className = "colourtx-v4dh",
        style = Dict(
            "display"    => show_del ? "block" : "none",
            "cursor"     => "pointer", 
            "fontSize"   => "1.1rem", 
            "fontWeight" => "700",
            "lineHeight" => "1", 
            "background" => "none", 
            "border"     => "none", 
            "padding"    => "0",
            "margin"     => "0 auto"
        )
    )

    # Automated determination of radioactivity status for UI synchronisation.
    hl_v     = Float64(get(row, "HalfLife", 0.0))
    is_radio = (get(row, "IsRadioactive", false) == true) || (hl_v > 0.0)

    mw_v        = Float64(get(row, "MW", 0.0))
    # Chromatic orchestration for molecular weight and radioactivity indicators.
    dot1_class  = mw_v > 0.0 ? "colourtx-c2sb" : "colourtx-v4dh" 
    dot2_class  = hl_v > 0.0 ? "colourtx-c4tg" : "colourtx-v4dh"

    dots = html_span([
        is_radio  ? html_i(className="fas fa-radiation me-1 colourtx-c0hr", style=Dict("fontSize" => "0.7rem")) : nothing,
        BASE_BuildStatusIcon_DDEF("●", "deck-dot1-$i", color_class=dot1_class, tip=mw_v > 0.0 ? "Molecular Weight defined (Scientific context ACTIVE)" : "No Molecular Weight", glow=mw_v > 0.0),
        BASE_BuildStatusIcon_DDEF("●", "deck-dot2-$i", color_class=dot2_class, tip=hl_v > 0.0 ? "Radioactive Decay data present" : "No half-life data", glow=hl_v > 0.0),
    ], style=Dict("display" => "inline-flex", "alignItems" => "center"))

    prop_btn = BASE_BuildIconButton_DDEF("btn-prop-$i", "fas fa-cog", color_class="colourtx-v3dl")

    row_children = Any[]
    
    push!(row_children, html_td(del_btn,
        style     = merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "30px", "display" => show_del ? "table-cell" : "none")),
        className = "p-0"))

    push!(row_children, html_td(
        dcc_input(id="deck-name-$i", type="text", value=name_val, debounce=true, style=name_input_style),
        className = "deck-name-cell p-0", 
        style     = BASE_StyleCell_DDEC)
    )

    push!(row_children, html_td(
        html_span([dots, prop_btn], style=Dict("display" => "inline-flex", "alignItems" => "center", "justifyContent" => "center")),
        style     = merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "55px")), 
        className = "p-0")
    )

    return html_tr(row_children; style=row_style, id="deck-row-id-$i")
end

"""
    BASE_BuildLevelRow_DDEF(i, row, visible) -> Tr
Constructs a table row for experimental level specifications (Lower, Centre, Upper).
"""
function BASE_BuildLevelRow_DDEF(i, row, visible)
    row_style = Dict("display" => visible ? "table-row" : "none")
    is_const  = (i >= 4)
    l1_val    = is_const ? nothing : get(row, "L1", 0.0)
    l2_val    = get(row, "L2", 0.0)
    l3_val    = is_const ? nothing : get(row, "L3", 0.0)
    row_class = is_const ? "deck-tr-constant" : "deck-tr-variable"

    return html_tr([
        html_td(dcc_input(id="deck-l1-$i", type="number", value=l1_val, debounce=true, disabled=is_const, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px", "display" => is_const ? "none" : "block")), className="px-0 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "33%")), className="p-0 $(is_const ? "deck-cell-disabled" : "")"),
        html_td(dcc_input(id="deck-l2-$i", type="number", value=l2_val, debounce=true, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px")), className="px-0 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "34%")), className="p-0"),
        html_td(dcc_input(id="deck-l3-$i", type="number", value=l3_val, debounce=true, disabled=is_const, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px", "display" => is_const ? "none" : "block")), className="px-0 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "33%")), className="p-0 $(is_const ? "deck-cell-disabled" : "")")
    ]; style=row_style, className=row_class, id="deck-row-level-$i")
end

"""
    BASE_BuildLimitsRow_DDEF(i, row, visible) -> Tr
Constructs a table row for search space boundaries and unit metadata.
"""
function BASE_BuildLimitsRow_DDEF(i, row, visible)
    row_style = Dict("display" => visible ? "table-row" : "none")
    is_const  = (i >= 4)
    min_val   = is_const ? nothing : get(row, "Min",  0.0)
    max_val   = is_const ? nothing : get(row, "Max",  0.0)
    unit_val  = string(get(row, "Unit", "-"))
    row_class = is_const ? "deck-tr-constant" : "deck-tr-variable"

    return html_tr([
        html_td(dcc_input(id="deck-min-$i",  type="number", value=min_val,  debounce=true, disabled=is_const, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px", "display" => is_const ? "none" : "block")), className="px-0 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "33%")), className="p-0 $(is_const ? "deck-cell-disabled" : "")"),
        html_td(dcc_input(id="deck-unit-$i", type="text",   value=unit_val, debounce=true, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px")), className="px-0 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "34%")), className="p-0"),
        html_td(dcc_input(id="deck-max-$i",  type="number", value=max_val,  debounce=true, disabled=is_const, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px", "display" => is_const ? "none" : "block")), className="px-0 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "33%")), className="p-0 $(is_const ? "deck-cell-disabled" : "")")
    ]; style=row_style, className=row_class, id="deck-row-limits-$i")
end

"""
    BASE_BuildGoalRow_DDEF(i) -> Tr
Constructs a row for defining analytical objectives and desirability constraints.
"""
function BASE_BuildGoalRow_DDEF(i)
    return html_tr([
        html_td(dcc_input(id="lens-goal-name-$i", type="text", value="", style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px", "fontWeight" => "600", "height" => "31px", "lineHeight" => "31px", "boxSizing" => "border-box")), className="px-0 py-0", disabled=true), style=merge(BASE_StyleCell_DDEC, Dict("width" => "17%", "height" => "31px")), className="p-0 deck-cell-disabled"),
        html_td(dcc_input(id="lens-goal-min-$i",  type="number", value=0, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px", "height" => "31px", "lineHeight" => "31px", "boxSizing" => "border-box")), className="px-0 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("width" => "15%", "height" => "31px")), className="p-0"),
        html_td(dcc_input(id="lens-goal-target-$i", type="number", value=0, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px", "height" => "31px", "lineHeight" => "31px", "boxSizing" => "border-box")), className="px-0 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("width" => "15%", "height" => "31px")), className="p-0"),
        html_td(dcc_input(id="lens-goal-max-$i",  type="number", value=0, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px", "height" => "31px", "lineHeight" => "31px", "boxSizing" => "border-box")), className="px-0 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("width" => "15%", "height" => "31px")), className="p-0"),
        html_td(dbc_select(id="lens-goal-type-$i", options=[
                    Dict("label" => "Nominal",  "value" => "Nominal"),
                    Dict("label" => "Maximise", "value" => "Maximise"),
                    Dict("label" => "Minimise", "value" => "Minimise"),
                ], value="Nominal", className="form-select form-select-sm border-0 py-0 text-center colourtx-v5pb", style=Dict("width" => "100%", "height" => "31px", "minHeight" => "31px", "maxHeight" => "31px", "lineHeight" => "31px", "fontSize" => "10px", "backgroundColor" => "transparent", "boxShadow" => "none", "boxSizing" => "border-box")), style=merge(BASE_StyleCell_DDEC, Dict("width" => "19%", "height" => "31px")), className="p-0"),
        html_td(dbc_select(id="lens-goal-weight-$i", options=[
                    Dict("label" => "★☆☆☆☆", "value" => "0.50"),
                    Dict("label" => "★★☆☆☆", "value" => "0.75"),
                    Dict("label" => "★★★☆☆", "value" => "1.00"),
                    Dict("label" => "★★★★☆", "value" => "1.50"),
                    Dict("label" => "★★★★★", "value" => "2.00"),
                ], value="1.00", className="form-select form-select-sm border-0 py-0 text-center colourtx-v4dh", style=Dict("width" => "100%", "height" => "31px", "minHeight" => "31px", "maxHeight" => "31px", "lineHeight" => "31px", "fontSize" => "10px", "backgroundColor" => "transparent", "boxShadow" => "none", "boxSizing" => "border-box")), style=merge(BASE_StyleCell_DDEC, Dict("width" => "19%", "height" => "31px")), className="p-0")
    ]; className="deck-goal-row", id="lens-goal-row-$i", style=Dict("height" => "31px", "minHeight" => "31px", "maxHeight" => "31px"))
end

# ==============================================================================
# PART C: SYSTEM DIAGNOSTICS & INTEGRITY
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 6: SYSTEM AUDIT UI (HARDWARE MONITOR)
# ------------------------------------------------------------------------------

"""
    BASE_BuildSystemAudit_DDEF() -> Container
Generates the technical diagnostic interface for monitoring system health and resources.
"""
function BASE_BuildSystemAudit_DDEF()
    nt = Threads.nthreads()
    thread_colour = nt > 1 ? "var(--colour-chr4-tongre)" : "var(--colour-chr5-hueyel)"
    thread_stat   = nt > 1 ? "OPTIMAL" : "LIMITED"

    free_mem  = Sys.free_memory() / 1024^3
    total_mem = Sys.total_memory() / 1024^3
    mem_str   = "$(round(free_mem, digits=1)) / $(round(total_mem, digits=1)) GB"
    mem_perc  = (total_mem - free_mem) / total_mem
    mem_colour = mem_perc > 0.9 ? "var(--colour-chr0-huered)" : "var(--colour-chr4-tongre)"

    cache_len = lock(FAST_CacheLock_DDEC) do
        length(FAST_CacheStore_DDEC)
    end
    
    lock_len = lock(FAST_LockGuard_DDEC) do
        length(FAST_OperationLocks_DDEC)
    end

    status_icon = (nt > 1 && mem_perc <= 0.9) ? "fa-check-circle colourtx-c4tg" : "fa-exclamation-triangle colourtx-c5hy"
    status_text = (nt > 1 && mem_perc <= 0.9) ? "System Status: MISSION READY" : "System Status: SUB-OPTIMAL"

    return dbc_container([
        html_h6("DOECISORY SYSTEM DIAGNOSTICS", className="fw-bold mb-3 colourtx-c3te text-center", style=Dict("letterSpacing" => "1px")),
        html_hr(style=BASE_StyleHr_DDEC),
        dbc_row([
            dbc_col(BASE_BuildVitalCard_DDEF("Thread Count", "$nt [$thread_stat]", thread_colour), xs=12, md=3),
            dbc_col(BASE_BuildVitalCard_DDEF("Memory Free", mem_str, mem_colour), xs=12, md=3),
            dbc_col(BASE_BuildVitalCard_DDEF("Cache Entries", string(cache_len), "var(--colour-chr3-toncya)"), xs=12, md=3),
            dbc_col(BASE_BuildVitalCard_DDEF("Active Locks", string(lock_len), "var(--colour-chr3-toncya)"), xs=12, md=3),
        ], className="g-3 mb-4 mt-2", style=Dict("marginRight" => "0", "marginLeft" => "0")),
        html_div([
            html_i(className="fas $status_icon me-2"),
            status_text
        ], className="text-center fw-bold colourtx-v4dh mt-2"),

        html_hr(style=BASE_StyleHr_DDEC),
        dbc_row([
            dbc_col(html_div("RECOVERY TOOLS", className="small fw-bold colourtx-v3dl text-start"), width="auto"),
            dbc_col([
                dbc_button([html_i(className="fas fa-unlock-alt me-1"), "Force Open Lock"], 
                    id="btn-diag-force-unlock", className="colourgl-c0hr me-2", size="sm", outline=true, n_clicks=0),
                dbc_button([html_i(className="fas fa-trash-alt me-1"), "Clear Temp"], 
                    id="btn-diag-clear-temp", className="colourgl-c1sm", size="sm", outline=true, n_clicks=0),
            ], className="text-end")
        ], align="center", className="mt-1"),
        
        html_div(id="diag-global-output", className="mt-2 small text-center")
    ], fluid=true, className="overflow-hidden p-0")
end

# ------------------------------------------------------------------------------
# SECTION 7: SYSTEM INTEGRITY CERTIFICATE
# ------------------------------------------------------------------------------

"""
    BASE_BuildSciAudit_DDEF() -> Container
Generates the integrity certificate interface to verify architectural consistency.
"""
function BASE_BuildSciAudit_DDEF()
    pm = parentmodule(@__MODULE__)
    modules = [:Sys_Fast, :Lib_Core, :Lib_Mole, :Lib_Vise, :Lib_Arts]
    missing_mods = [m for m in modules if !isdefined(pm, m)]

    bridges = [
        ("Lib_Core -> Lib_Vise", :CORE_CalcDEfficiency_DDEF),
        ("Lib_Mole -> Lib_Core", :MOLE_ValidateFeasibility_DDEF),
        ("Lib_Vise -> Lib_Arts", :VISE_GenSciReport_DDEF)
    ]
    broken_bridges = [label for (label, sym) in bridges if !(isdefined(pm, Symbol(split(label, " -> ")[1])) && isdefined(getfield(pm, Symbol(split(label, " -> ")[1])), sym))]

    has_metrics = isdefined(pm, :Lib_Core) && isdefined(pm.Lib_Core, :CORE_CalcDesignMetrics_DDEF)

    mod_colour = isempty(missing_mods) ? "var(--colour-chr4-tongre)" : "var(--colour-chr0-huered)"
    bridge_colour = isempty(broken_bridges) ? "var(--colour-chr4-tongre)" : "var(--colour-chr0-huered)"
    metrics_colour = has_metrics ? "var(--colour-chr4-tongre)" : "var(--colour-chr0-huered)"

    is_passed = isempty(missing_mods) && isempty(broken_bridges) && has_metrics
 
    stat_mod = isempty(missing_mods) ? "ALL LOADED" : "MISSING"
    stat_bridge = isempty(broken_bridges) ? "CONNECTED" : "BROKEN"
    stat_metrics = has_metrics ? "ACTIVE" : "MISSING"

    icon_cls = is_passed ? "fa-award" : "fa-exclamation-triangle"
    text_cls = is_passed ? "colourtx-c4tg" : "colourtx-c0hr"
    
    msg_text = is_passed ? "Final Integrity Check: PASSED. Project ready for academic submission." : "Final Integrity Check: FAILED. Please resolve missing modules or broken bridges."

    return dbc_container([
        html_h6("SYSTEM INTEGRITY CERTIFICATE", className="fw-bold mb-3 colourtx-c3te text-center", style=Dict("letterSpacing" => "1px")),
        html_hr(style=BASE_StyleHr_DDEC),
        dbc_row([
            dbc_col(BASE_BuildVitalCard_DDEF("Core Modules", stat_mod, mod_colour), xs=12, md=4),
            dbc_col(BASE_BuildVitalCard_DDEF("Architectural Bridges", stat_bridge, bridge_colour), xs=12, md=4),
            dbc_col(BASE_BuildVitalCard_DDEF("Math Metrics", stat_metrics, metrics_colour), xs=12, md=4),
        ], className="g-3 mb-4 mt-2", style=Dict("marginRight" => "0", "marginLeft" => "0")),
        html_div([
            html_i(className="fas $icon_cls me-2 $text_cls"),
            msg_text
        ], className="text-center fw-bold colourtx-v4dh mt-2 fst-italic")
    ], fluid=true, className="overflow-hidden p-0")
end

# ------------------------------------------------------------------------------
# SECTION 8: NOMENCLATURE VALIDATION BUS
# ------------------------------------------------------------------------------

"""
    BASE_ValidateUniqueNames_DDEF(Names::AbstractVector, EntityType::AbstractString="Response") -> Tuple{Bool, String}
Validates that input or response names are non-empty and strictly unique.
"""
function BASE_ValidateUniqueNames_DDEF(Names::AbstractVector, EntityType::AbstractString="Response")::Tuple{Bool, String}
    seen = Set{String}()
    for (i, raw_n) in enumerate(Names)
        n = strip(string(raw_n))
        if isempty(n)
            return (false, "Systematic Error: $(EntityType) name for row $(i) cannot be empty.")
        end
        if n in seen
            return (false, "Systematic Error: $(EntityType) names must be unique. '$(n)' is repeated.")
        end
        push!(seen, n)
    end
    return (true, "")
end

# ==============================================================================
# PART D: APPLICATION SHELL & ORCHESTRATION
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 9: GLOBAL NAVIGATION & APPLICATION LAYOUT
# ------------------------------------------------------------------------------

const BASE_SystemReady_DDEC = Threads.Atomic{Bool}(false)

"""
    BASE_BuildNavbar_DDEF() -> Component
Constructs the top navigation glass-navbar component.
"""
function BASE_BuildNavbar_DDEF()
    return html_div([
        html_div([
            dcc_link(html_div([
                html_img(src="/assets/favicon.ico", style=Dict("height" => "32px", "marginRight" => "10px", "borderRadius" => "4px")),
                html_span("DoECISORY", className="fw-bold tracking-tight", style=Dict("color" => "var(--colour-val5-purbla)")),
            ], className="nav-brand"), href="/", style=Dict("textDecoration" => "none")),
        ], style=Dict("flex" => "1")),

        html_div([
            html_a("Design",  href="/design",   className="nav-item"),
            html_a("Analyse", href="/analysis", className="nav-item"),
        ], className="nav-links d-flex justify-content-center"),

        html_div([
            html_span(FAST_Data_DDEC.VERSION, 
                className="badge opacity-75", 
                style=Dict("backgroundColor" => "var(--colour-val3-darlow)", "color" => "var(--colour-val0-purwhi)")
            ),
        ], className="nav-actions", style=Dict("flex" => "1", "textAlign" => "right")),
    ], className="glass-navbar d-flex align-items-center justify-content-between")
end

"""
    BASE_BuildLayout_DDEF() -> Component
Constructs the primary application shell layout containing navigation, routing viewport,
persistence stores, diagnostics modal, and the loading overlay.
"""
function BASE_BuildLayout_DDEF()
    return html_div([
        dcc_location(id="url", refresh=false),
        BASE_BuildNavbar_DDEF(),
        html_div(id="page-content", className="app-container"),

        dcc_store(id="store-session-config", storage_type="memory"),
        dcc_store(id="store-master-vault",   storage_type="memory"),
        dcc_store(id="sync-deck-content",    storage_type="memory"),
        dcc_store(id="sync-lens-content",    storage_type="memory"),
        dcc_store(id="sync-lens-analysis",   storage_type="memory"),
        dcc_store(id="lens-store-diag-force", data=0, storage_type="memory"),

        dbc_toast(id="global-toast",
            header="System Notification", is_open=false, dismissable=true,
            duration=4000, icon="danger",
            style=Dict(
                "position" => "fixed", "top" => 60, "right" => 20,
                "width"    => 350, "zIndex" => 9999
            )
        ),

        dbc_modal([
            dbc_modalheader("System Diagnostics & Integrity"),
            dbc_modalbody([
                dbc_tabs([
                    dbc_tab([
                        html_div(id="modal-diagnostics-sys-content", className="p-3 d-flex flex-column justify-content-center")
                    ], label="System Health", tab_id="tab-sys"),
                    dbc_tab([
                        html_div(id="modal-diagnostics-sci-content", className="p-3 d-flex flex-column justify-content-center")
                    ], label="System Integrity", tab_id="tab-sci"),
                ], id="modal-diagnostics-tabs", active_tab="tab-sys")
            ]),
            dbc_modalfooter(dbc_button("Close", id="btn-close-diagnostics", className="ms-auto colourgl-c0hr", n_clicks=0, outline=false))
        ], id="modal-diagnostics", size="xl", is_open=false),

        dcc_interval(id="sys-ready-poll", interval=2000, max_intervals=-1),

        html_div(id="sys-loading-overlay", children=[
            html_div([
                html_div(className="sys-spinner"),
                html_h4("DoECISORY", className="fw-bold mb-2 text-center", style=Dict("color" => "var(--colour-val5-purbla)")),
                html_p("Synchronising modules...", className="text-center",
                    style=Dict("color" => "var(--colour-val3-darlow)", "margin" => "0"), id="sys-loading-msg"),
            ], style=Dict(
                "position"      => "relative",
                "display"       => "flex", 
                "flexDirection" => "column", 
                "alignItems"    => "center",
                "justifyContent"=> "center", 
            )),
        ], style=Dict(
            "position"        => "fixed", 
            "top"             => "0", 
            "left"            => "0", 
            "width"           => "100vw", 
            "height"          => "100vh",
            "backgroundColor" => "var(--colour-val2-liglow)", 
            "zIndex"          => "99999", 
            "display"         => "flex",
            "alignItems"      => "center", 
            "justifyContent"  => "center",
        )),
    ])
end

# ------------------------------------------------------------------------------
# SECTION 10: TOP-LEVEL ROUTING & STATE BRIDGES
# ------------------------------------------------------------------------------

"""
    BASE_SyncVault_DDEF(deck::Any, lens::Any, lens_analysis::Any) -> Any
Synchronises session data between the UI components and the master repository.
"""
function BASE_SyncVault_DDEF(deck::Any, lens::Any, lens_analysis::Any; mock_trigger::Union{String, Nothing}=nothing)
    trig = mock_trigger
    if isnothing(trig)
        ctx = try callback_context() catch; nothing end
        (isnothing(ctx) || isempty(ctx.triggered)) && return Dash.no_update()
        trig = split(ctx.triggered[1].prop_id, ".")[1]
    end

    if trig == "sync-deck-content"
        return deck
    elseif trig == "sync-lens-content"
        return lens
    else
        return lens_analysis
    end
end

"""
    BASE_RoutePage_DDEF(pathname::AbstractString) -> Component
Top-level routing orchestrator for navigating between experimental and analytical modules.
"""
function BASE_RoutePage_DDEF(pathname::AbstractString)
    pm = parentmodule(@__MODULE__)
    if pathname == "/design"
        return isdefined(pm, :Gui_Deck) ? pm.Gui_Deck.DECK_BuildLayout_DDEF() : pm.Gui_Deck.DECK_BuildLayout_DDEF()
    elseif pathname == "/analysis"
        return isdefined(pm, :Gui_Lens) ? pm.Gui_Lens.LENS_BuildLayout_DDEF() : pm.Gui_Lens.LENS_BuildLayout_DDEF()
    else
        # Central application portal dashboard interface.
        nt::Int, tstyle::String, tmsg::String = FAST_GetThreadInfo_DDEF()
        
        return html_div([
            dbc_container([
                dbc_row(dbc_col([
                    html_h1("DoECISORY", 
                        className = "fw-bold display-4 mb-3", 
                        style     = Dict("letterSpacing" => "-0.04em", "color" => "var(--colour-val5-purbla)")
                    ),
                    html_p([
                        "Design of Experiments with",
                        html_br(),
                        "Computational Interactive Sequential Optimisation for Response Yield"
                    ],
                        className = "lead mb-2", 
                        style     = Dict("color" => "var(--colour-val4-darhig)", "maxWidth" => "800px", "margin" => "0 auto")
                    ),
                    html_p("Under active system development. No liability is assumed for the accuracy of results or computations during this phase.",
                        className = "small opacity-75 mb-5",
                        style     = Dict("color" => "var(--colour-val3-darlow)", "fontStyle" => "italic")
                    ),
                ], xs=12, className="text-center mt-5 pt-4")),

                dbc_row([
                    dbc_col([
                        dcc_link(html_div([
                            html_div(html_i(className="fas fa-flask", style=Dict("color" => "var(--colour-val0-purwhi)")),
                                style=Dict(
                                    "width"        => "50px", "height" => "50px", "borderRadius" => "12px",
                                    "background"   => "linear-gradient(135deg, var(--colour-chr0-huered) 0%, var(--colour-chr5-hueyel) 100%)",
                                    "display"      => "flex", "alignItems" => "center", "justifyContent" => "center",
                                    "fontSize"     => "1.5rem", "marginBottom" => "1.5rem", 
                                    "boxShadow"    => "0 10px 20px -5px var(--colour-val2-liglow)"
                                )
                            ),
                            html_h3("Experimental Design", className="fw-bold mb-2", style=Dict("color" => "var(--colour-val5-purbla)")),
                            html_p("Generate experimental matrices using Box-Behnken, Central Composite, D-Optimal, or Taguchi methods. Define factor ranges, units, and stoichiometry to produce protocols.",
                                className="small mb-0", style=Dict("color" => "var(--colour-val4-darhig)", "lineHeight" => "1.6")),
                        ], className="glass-panel h-100 p-4", style=Dict("transition" => "transform 0.2s ease, box-shadow 0.2s ease", "cursor" => "pointer")), href="/design", style=Dict("textDecoration" => "none")),
                    ], xs=12, md=6, className="mb-4"),

                    dbc_col([
                        dcc_link(html_div([
                            html_div(html_i(className="fas fa-chart-line", style=Dict("color" => "var(--colour-val0-purwhi)")),
                                style=Dict(
                                    "width"        => "50px", "height" => "50px", "borderRadius" => "12px",
                                    "background"   => "linear-gradient(135deg, var(--colour-chr1-shamag) 0%, var(--colour-val4-darhig) 100%)",
                                    "display"      => "flex", "alignItems" => "center", "justifyContent" => "center",
                                    "fontSize"     => "1.5rem", "marginBottom" => "1.5rem", 
                                    "boxShadow"    => "0 10px 20px -5px var(--colour-val3-darlow)"
                                )
                            ),
                            html_h3("Statistical Analysis", className="fw-bold mb-2", style=Dict("color" => "var(--colour-val5-purbla)")),
                            html_p("Fit response surface models to experimental data, generate 2D contour and 3D surface plots, and apply desirability functions to identify optimal experimental conditions.",
                                className="small mb-0", style=Dict("color" => "var(--colour-val4-darhig)", "lineHeight" => "1.6")),
                        ], className="glass-panel h-100 p-4", style=Dict("transition" => "transform 0.2s ease, box-shadow 0.2s ease", "cursor" => "pointer")), href="/analysis", style=Dict("textDecoration" => "none")),
                    ], xs=12, md=6, className="mb-4"),
                ], className="g-4 mb-5", style=Dict("maxWidth" => "900px", "margin" => "0 auto")),

                dbc_row(dbc_col(html_div([
                    html_div([
                        html_div([
                            html_i(className="fas fa-server me-2", style=Dict("color" => "var(--colour-chr1-shamag)")), 
                            html_span("System Online", className="fw-bold", style=Dict("color" => "var(--colour-val3-darlow)"))
                        ], className="d-flex align-items-center me-4"),
                        html_div([
                            html_i(className="fas fa-microchip me-2", style=Dict("color" => "var(--colour-chr4-tongre)")), 
                            html_span(tmsg, className="fw-bold", style=Dict("color" => "var(--colour-val3-darlow)"))
                        ], className="d-flex align-items-center me-4"),
                        html_div([
                            html_span([html_i(className="fas fa-cog me-1"), "Diagnostics"],
                                id="btn-open-sys-audit", className="badge border", n_clicks=0,
                                style=Dict("cursor" => "pointer", "backgroundColor" => "var(--colour-val1-lighig)", "color" => "var(--colour-val5-purbla)"))
                        ], className="d-flex align-items-center"),
                    ], className="d-flex justify-content-center align-items-center p-3 rounded-pill",
                    style=Dict(
                        "background" => "var(--colour-val0-purwhi)", 
                        "border"     => "1px solid var(--colour-val2-liglow)", 
                        "boxShadow"  => "0 4px 6px -1px var(--colour-val1-lighig)", 
                        "display"    => "inline-flex", 
                        "margin"     => "0 auto"
                    ))
                ], className="text-center"), xs=12), style=Dict("maxWidth" => "900px", "margin" => "0 auto")),
            ], fluid=true, className="pb-5 mt-2")
        ])
    end
end

"""
    BASE_HandleLoadingOverlay_DDEF(n::Any) -> Tuple{Any, Bool}
Manages the visibility of the initial loading screen based on background JIT pre-compilation status.
"""
function BASE_HandleLoadingOverlay_DDEF(n::Any)
    try
        ready::Bool = BASE_SystemReady_DDEC[]
        
        n_val = 0
        if !isnothing(n)
            parsed_n = tryparse(Int, string(n))
            n_val = isnothing(parsed_n) ? 0 : parsed_n
        end

        if !ready && n_val % 10 == 0
            FAST_Log_DDEF("BOOT", "UiSync", "Status Check: Waiting for System Pre-compilation... (Poll #$n_val)", "INFO")
        end

        if ready
            return Dict("display" => "none"), true
        end
        
        if n_val > 15
            FAST_Log_DDEF("BOOT", "UiSync", "Timeout threshold exceeded ($n_val polls). Force releasing loading overlay.", "WARN")
            BASE_SystemReady_DDEC[] = true
            return Dict("display" => "none"), true
        end

        return Dash.no_update(), false
    catch e
        FAST_Log_DDEF("BOOT", "UI_SYNC_FAIL", "Error in loading overlay sync: $e. Releasing lock.", "FAIL")
        BASE_SystemReady_DDEC[] = true
        return Dict("display" => "none"), true
    end
end

"""
    BASE_RegisterDiagnostics_DDEF(n_open, n_close, is_open; mock_trigger::Union{String, Nothing}=nothing) -> Tuple{Any, Any, Any}
Handles diagnostics modal opening, closing, and content generation.
"""
function BASE_RegisterDiagnostics_DDEF(n_open, n_close, is_open; mock_trigger::Union{String, Nothing}=nothing)
    trig = mock_trigger
    if isnothing(trig)
        ctx = try callback_context() catch; nothing end
        (isnothing(ctx) || isempty(ctx.triggered)) && return false, Dash.no_update(), Dash.no_update()
        trig = split(ctx.triggered[1].prop_id, ".")[1]
    end

    if trig == "btn-open-sys-audit"
        if !isnothing(n_open) && n_open > 0
            return true, BASE_BuildSystemAudit_DDEF(), BASE_BuildSciAudit_DDEF()
        end
    elseif trig == "btn-close-diagnostics"
        return false, Dash.no_update(), Dash.no_update()
    end

    return is_open, Dash.no_update(), Dash.no_update()
end

"""
    BASE_RegisterRecovery_DDEF(n_lock, n_temp; mock_trigger::Union{String, Nothing}=nothing) -> Tuple{Any, Any}
Handles force open lock release and transient storage purge actions.
"""
function BASE_RegisterRecovery_DDEF(n_lock, n_temp; mock_trigger::Union{String, Nothing}=nothing)
    trig = mock_trigger
    if isnothing(trig)
        ctx = try callback_context() catch; nothing end
        (isnothing(ctx) || isempty(ctx.triggered)) && return Dash.no_update(), Dash.no_update()
        trig = split(ctx.triggered[1].prop_id, ".")[1]
    end
    
    if trig == "btn-diag-force-unlock"
        (isnothing(n_lock) || n_lock == 0) && return Dash.no_update(), Dash.no_update()
        FAST_ForceReleaseAll_DDEF()
        new_force = Int(round(time()))
        msg = html_div([
            html_span("✅ Force Open Lock: SUCCESS", className="fw-bold colourtx-c4tg d-block"),
            html_span("Backend locks cleared. System control guards reset.", className="x-small colourtx-v4dh")
        ], className="mt-2 text-center")
        return new_force, msg
    elseif trig == "btn-diag-clear-temp"
        (isnothing(n_temp) || n_temp == 0) && return Dash.no_update(), Dash.no_update()
        FAST_CleanWorkforce_DDEF(true)
        msg = html_div([
            html_span("✅ Clear Temporary Files: SUCCESS", className="fw-bold colourtx-c4tg d-block text-center"),
            html_span("Transient storage directory successfully cleared and reset.", className="x-small colourtx-v4dh d-block text-center")
        ], className="mt-2")
        return Dash.no_update(), msg
    end
    return Dash.no_update(), Dash.no_update()
end

# ------------------------------------------------------------------------------
# SECTION 11: APPLICATION CALLBACK REGISTRATION
# ------------------------------------------------------------------------------

"""
    BASE_RegisterAppCallbacks_DDEF(app) -> Nothing
Registers all top-level application callbacks: page routing, store synchronization,
diagnostics modal, emergency recovery lock release, and loading overlay dismissal.
"""
function BASE_RegisterAppCallbacks_DDEF(app)::Nothing
    # Top-level routing
    callback!(app, Output("page-content", "children"), Input("url", "pathname")) do pathname
        return BASE_RoutePage_DDEF(isnothing(pathname) ? "/" : pathname)
    end

    # Master vault synchronization
    callback!(app,
        Output("store-master-vault",  "data"),
        Input("sync-deck-content",    "data"),
        Input("sync-lens-content",    "data"),
        Input("sync-lens-analysis",   "data"),
        prevent_initial_call = true
    ) do deck, lens, lens_analysis
        return BASE_SyncVault_DDEF(deck, lens, lens_analysis)
    end

    # Diagnostics orchestrator
    callback!(app,
        Output("modal-diagnostics",             "is_open"),
        Output("modal-diagnostics-sys-content", "children"),
        Output("modal-diagnostics-sci-content", "children"),
        Input("btn-open-sys-audit",             "n_clicks"),
        Input("btn-close-diagnostics",          "n_clicks"),
        State("modal-diagnostics",              "is_open"),
        prevent_initial_call = true
    ) do n_open, n_close, is_open
        return BASE_RegisterDiagnostics_DDEF(n_open, n_close, is_open)
    end

    # Emergency recovery & lock release
    callback!(app,
        Output("lens-store-diag-force", "data"),
        Output("diag-global-output",    "children"),
        Input("btn-diag-force-unlock",  "n_clicks"),
        Input("btn-diag-clear-temp",    "n_clicks"),
        prevent_initial_call = true
    ) do n_lock, n_temp
        return BASE_RegisterRecovery_DDEF(n_lock, n_temp)
    end

    # Loading overlay poll
    callback!(app,
        Output("sys-loading-overlay", "style"),
        Output("sys-ready-poll",      "disabled"),
        Input("sys-ready-poll",       "n_intervals")
    ) do n
        return BASE_HandleLoadingOverlay_DDEF(n)
    end

    return nothing
end

# ------------------------------------------------------------------------------
# SECTION 12: DASH APPLICATION FACTORY
# ------------------------------------------------------------------------------

"""
    BASE_CreateApp_DDEF(; assets_folder::String = "") -> DashApp
Instantiates and configures the core Dash application with stylesheets, custom HTML template,
and primary shell layout.
"""
function BASE_CreateApp_DDEF(; assets_folder::String = "")
    FAST_Log_DDEF("INIT", "Setup", "Configuring Dash Framework...", "WAIT")
    pathname_prefix = get(ENV, "DASH_REQUESTS_PATHNAME_PREFIX", "/")

    app = if !isempty(assets_folder) && isdir(assets_folder)
        dash(;
            assets_folder                = assets_folder,
            requests_pathname_prefix     = pathname_prefix,
            external_stylesheets         = [
                DashBootstrapComponents.dbc_themes.BOOTSTRAP,
                "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css",
                "https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600&display=swap",
            ],
            suppress_callback_exceptions = true,
        )
    else
        dash(;
            requests_pathname_prefix     = pathname_prefix,
            external_stylesheets         = [
                DashBootstrapComponents.dbc_themes.BOOTSTRAP,
                "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css",
                "https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600&display=swap",
            ],
            suppress_callback_exceptions = true,
        )
    end

    app.title = "DoECISORY"

    app.index_string = """
<!DOCTYPE html>
<html>
    <head>
        {%metas%}
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>{%title%}</title>
        {%favicon%}
        {%css%}
    </head>
    <body class="dash-template">
        {%app_entry%}
        <footer>
            {%config%}
            {%scripts%}
            {%renderer%}
        </footer>
        <script>
            /* Navigation guards removed for seamless page transitions */
        </script>
    </body>
</html>
"""

    app.layout = BASE_BuildLayout_DDEF()
    return app
end

# ------------------------------------------------------------------------------
# SECTION 13: JIT PRE-COMPILATION WARMUP ROUTINE
# ------------------------------------------------------------------------------

"""
    BASE_WarmupApp_DDEF() -> Nothing
Orchestrates Just-In-Time (JIT) pre-compilation pulse across algorithmic, stoichiometric,
and visualisation layers to guarantee instant frontend response.
"""
function BASE_WarmupApp_DDEF()::Nothing
    t0           = time()
    is_hf        = haskey(ENV, "SPACE_ID")
    is_dev       = get(ENV, "DOECISORY_DEV", "false") == "true"
    is_fast_boot = get(ENV, "DOECISORY_FAST_BOOT", "false") == "true" || 
                   occursin("sysimage", lowercase(unsafe_string(Base.JLOptions().image_file)))

    # Production environment integrity ensured through comprehensive warmup.
    if is_hf && !is_dev
        FAST_Log_DDEF("BOOT", "Warmup", "Production Environment Detected (HF Spaces).", "WAIT")
        sleep(2)
    elseif is_dev
        FAST_Log_DDEF("BOOT", "Warmup", "Development Mode: Fast Boot triggered.", "INFO")
        FAST_SafeNum_DDEF("1.0")
        BASE_SystemReady_DDEC[] = true
        return nothing
    elseif is_fast_boot
        FAST_Log_DDEF("BOOT", "Warmup", "Sysimage active (JIT pulse bypassed).", "OK")
        FAST_SafeNum_DDEF("1.0")
        BASE_SystemReady_DDEC[] = true
        return nothing
    end

    FAST_Log_DDEF("BOOT", "Precompile", "Initiating JIT Pulse...", "WAIT") 

    try
        FAST_SafeNum_DDEF("42.0")
        
        # Simulation mass data balanced to stoichiometric unity via relative mass units.
        names_mock  = String["A"]
        mw_mock     = Float64[100.0]
        ratios_mock = Float64[100.0]
        units_mock  = String["%M"]
        MOLE_CalcMass_DDEF(names_mock, mw_mock, ratios_mock, 5.0, 10.0, units_mock, 1.0; SuppressLog=true)
        
        # Synthesised audit batch parameters including auto-balancing filler components.
        table_mock = [Dict("Name"=>"A", "MW"=>100.0, "Unit"=>"%M", "Type"=>"Variable", "Min"=>0.0, "Max"=>50.0, "Mid"=>25.0, "Rows"=>[[Dict("Unit"=>"%M")]]),
                     Dict("Name"=>"W", "MW"=>18.0, "Unit"=>"%", "Type"=>"Filler", "Min"=>0.0, "Max"=>100.0, "Mid"=>50.0)]
        design_mock = fill(20.0, 5, 1) 

        MOLE_AuditBatch_DDEF(table_mock, design_mock, 5.0, 10.0)
        pfx_in, pfx_out = FAST_Data_DDEC.PRE_VAR, FAST_Data_DDEC.PRE_RESULT

        # Standard BB15 matrix from Lib_Core for JIT pulse
        X_dummy = Float64.(CORE_DesignBB15_DDEC)
        
        # Dynamic Y response synthesis: Parabolic function to ensure perfect modelling fit
        Y_dummy = [50 + 10*r[1] + 5*r[2] - 2*r[3] + 8*r[1]^2 + 6*r[2]^2 + 4*r[3]^2 for r in eachrow(X_dummy)]
        
        names_in = ["X1", "X2", "X3"]
        bounds_dummy = [-1.0 1.0; -1.0 1.0; -1.0 1.0]
        goal_dummy = Dict{String, Any}("Type"=>"Maximise", "Min"=>0.0, "Max"=>20.0, "Target"=>15.0, "Weight"=>1.0, "WeightVal" => 1.0)

        # PULSE 1: Linear Path Warmup
        FAST_Log_DDEF("BOOT", "Warmup", "Pulsing Algorithmic Layer (Phase-A: Linear)...", "WAIT")
        mod_lin = VISE_Regress_DDEF(X_dummy, vec(Y_dummy), "linear"; InNames=names_in)
        mod_lin["Goal"] = goal_dummy
        VISE_RunGridSearch_DDEF([mod_lin], [goal_dummy], bounds_dummy; Steps=11)
        FAST_Log_DDEF("BOOT", "Warmup", "Phase-A completed. Pulsing Phase-B...", "OK")
        ARTS_Draw_DDEF(ARTS_PlotSurface_DDES(), mod_lin, X_dummy, [1, 2], ["X1", "X2"], "Pulse-L")

        # PULSE 2: Quadratic Path Warmup
        FAST_Log_DDEF("BOOT", "Warmup", "Pulsing Algorithmic Layer (Phase-B: Quadratic)...", "WAIT")
        mod_quad = VISE_Regress_DDEF(X_dummy, vec(Y_dummy), "quadratic"; InNames=names_in)
        mod_quad["Goal"] = goal_dummy
        VISE_RunGridSearch_DDEF([mod_quad], [goal_dummy], bounds_dummy; Steps=11)
        FAST_Log_DDEF("BOOT", "Warmup", "Phase-B completed. Pulsing Phase-C...", "OK")

        # PULSE 3: Optimisation & Stoichiometry Pulse (The BBO & Mole Path)
        FAST_Log_DDEF("BOOT", "Warmup", "Pulsing Algorithmic Layer (Phase-C: BBO & Audit)...", "WAIT")
        CORE_OptimiseDesirability_DDEF([mod_quad], [goal_dummy], bounds_dummy; MaxTime=0.1)
        ingredients_dummy = [Dict("Name"=>"X1", "MW"=>100.0, "Unit"=>"mg", "Ratio"=>1.0)]
        MOLE_AuditBatch_DDEF(ingredients_dummy, X_dummy, 5.0, 10.0)

        # PULSE 4: Diagnostic Statistics Pulse (ANOVA & Normality)
        FAST_Log_DDEF("BOOT", "Warmup", "Pulsing Algorithmic Layer (Phase-D: Diagnostics)...", "WAIT")
        VISE_GenANOVATable_DDEF(mod_quad, X_dummy, vec(Y_dummy))
        VISE_TestNormality_DDEF(mod_quad, X_dummy, vec(Y_dummy))
        VISE_AnalyseSensitivity_DDEF(mod_quad, [0.5, 0.5, 0.5], X_dummy)

        # PULSE 5: Integration Layer Warmup
        FAST_Log_DDEF("BOOT", "Warmup", "Pulsing Integration Layer (Phase-E: Finalisation)...", "WAIT")

        df_mock = DataFrame()
        df_mock[!, "$(pfx_in)X1"] = X_dummy[:, 1]
        df_mock[!, "$(pfx_in)X2"] = X_dummy[:, 2]
        df_mock[!, "$(pfx_in)X3"] = X_dummy[:, 3]
        df_mock[!, "$(pfx_out)Y1"] = Y_dummy

        config_mock = Dict{String, Any}(
            "Ingredients" => [Dict("Name" => "X1"), Dict("Name" => "X2"), Dict("Name" => "X3")],
            "Outputs"     => [Dict("Name" => "Y1")],
            "Global"      => Dict("Volume" => 5.0, "Conc" => 10.0)
        )
        warmup_opts = Dict{String, Any}("MaxTime" => 0.1, "GridSteps" => 11)
        
        FAST_Log_DDEF("BOOT", "Warmup", "Pulsing Integration Layer (Linear Mode)...", "WAIT")
        VISE_ExecuteInternal_DDEF(df_mock, config_mock, "PulsePhase", [goal_dummy], "linear"; 
            t_start=time(), Opts=warmup_opts, RenderMode=:Priority)
        
        FAST_Log_DDEF("BOOT", "Warmup", "Pulsing Integration Layer (Quadratic Mode)...", "WAIT")
        VISE_ExecuteInternal_DDEF(df_mock, config_mock, "PulsePhase", [goal_dummy], "quadratic"; 
            t_start=time(), Opts=warmup_opts, RenderMode=:Priority)

        # Visualisation Pulse: Triggering PlotlyJS and RSM rendering logic compilation
        ARTS_Draw_DDEF(ARTS_PlotPareto_DDES(), mod_quad, "Pulse-Q", 0.9, 0.8)
        ARTS_Draw_DDEF(ARTS_PlotSurface_DDES(), mod_quad, X_dummy, [1, 2], ["X1", "X2"], "Pulse-Q")
        ARTS_Draw_DDEF(ARTS_PlotContour_DDES(), mod_quad, X_dummy, [1, 2], ["X1", "X2"], "Pulse-Q")
        ARTS_Draw_DDEF(ARTS_PlotTrend_DDES(), mod_quad, X_dummy, vec(Y_dummy), [1], ["X1"], "Pulse-Q")
        ARTS_Draw_DDEF(ARTS_PlotSlice_DDES(), mod_quad, X_dummy, [1, 2], ["X1", "X2"], "Pulse-Q")
        ARTS_Draw_DDEF(ARTS_PlotQQ_DDES(), rand(10), "Pulse-Q")
        
        GC.gc()
        BASE_SystemReady_DDEC[] = true
        elapsed                = round(time() - t0; digits=2)
        FAST_Log_DDEF("BOOT", "Precompile", "JIT complete ($(elapsed)s) — System Ready.", "OK")
    catch e
        FAST_Log_DDEF("BOOT", "WARMUP_FAIL", "JIT pre-compilation failed: $(sprint(showerror, e))", "FAIL")
        BASE_SystemReady_DDEC[] = true
    end
    return nothing
end

end