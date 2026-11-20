"""
    Lib_Arts

Scientific visualisation and decision analytics subsystem for **DoECISORY.jl**. Built upon
`PlotlyJS` with perceptually uniform Viridis colour mapping and publication typography, rendering
response manifolds, statistical diagnostics, and 3D desirability operating spaces.

- **Tag:** `ARTS`  |  **Palette:** Viridis scale & bipolar interaction theme (`ARTS_Theme_DDEC`)
- **Response Topography:** 3D surfaces, 2D contours, slices, trends (`ARTS_RenderSurface_DDEF`, `ARTS_RenderContour_DDEF`, `ARTS_RenderSlice_DDEF`)
- **Model Diagnostics:** Pareto, fit, Q-Q, residuals, sensitivity, heatmaps (`ARTS_RenderPareto_DDEF`, `ARTS_RenderInteractionMatrix_DDEF`)
- **Decision Spaces:** Feasible space, optimal zone, sweet spot, candidates (`ARTS_Render_DDEF`, `ARTS_RenderCandidates_DDEF`)
"""
module Lib_Arts

using Base.Threads
using PlotlyJS
using Printf
using Statistics
using Distributions
using DataFrames
using ..Sys_Fast
using ..Lib_Core

export ARTS_RenderPareto_DDEF, ARTS_RenderFit_DDEF, ARTS_RenderSurface_DDEF,
    ARTS_RenderContour_DDEF, ARTS_RenderSlice_DDEF, ARTS_RenderTrend_DDEF,
    ARTS_RenderDesignSpace_DDEF, ARTS_RenderCandidates_DDEF, ARTS_Render_DDEF,
    ARTS_Downsample_DDEF, ARTS_RenderFeasibleSpace_DDEF, ARTS_RenderOptimalZone_DDEF,
    ARTS_RenderSweetSpot_DDEF, ARTS_RenderInteractionMatrix_DDEF, ARTS_RenderQQ_DDEF,
    ARTS_RenderResiduals_DDEF, ARTS_RenderSensitivity_DDEF, ARTS_BuildBaseLayout_DDEF,
    ARTS_Predict_DDEF, ARTS_BuildGrid_DDEF, ARTS_CalcAdaptiveGridN_DDEF,
    ARTS_GetDynamicGridN_DDEF, ARTS_PlotPareto_DDES, ARTS_PlotCandidates_DDES,
    ARTS_PlotFit_DDES, ARTS_PlotInteractionMatrix_DDES, ARTS_PlotQQ_DDES,
    ARTS_PlotResiduals_DDES, ARTS_PlotSensitivity_DDES, ARTS_PlotSurface_DDES,
    ARTS_PlotContour_DDES, ARTS_PlotSlice_DDES, ARTS_PlotTrend_DDES, ARTS_PlotFeasibleSpace_DDES,
    ARTS_PlotOptimalZone_DDES, ARTS_PlotSweetSpot_DDES, ARTS_PlotDesignSpace_DDES,
    ARTS_PlotPriority_DDEC, ARTS_Draw_DDEF, ARTS_AddGapCard_DDEF!

# ==============================================================================
# PART A: VISUAL CORE & INFRASTRUCTURE
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: THEME & CONSTANTS
# ------------------------------------------------------------------------------

const C = FAST_Data_DDEC

abstract type ARTS_AbstractPlotType_DDET end
struct ARTS_PlotPareto_DDES            <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotFit_DDES               <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotSurface_DDES           <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotContour_DDES           <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotSlice_DDES             <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotTrend_DDES             <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotFeasibleSpace_DDES     <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotOptimalZone_DDES       <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotSweetSpot_DDES         <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotDesignSpace_DDES       <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotCandidates_DDES        <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotInteractionMatrix_DDES <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotQQ_DDES                <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotResiduals_DDES         <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotSensitivity_DDES       <: ARTS_AbstractPlotType_DDET end

"""
    ARTS_PlotPriority_DDEC

Constant dictionary mapping visual analytical plot types to their deterministic 
carousel display and sorting priority order (1 to 15).
"""
const ARTS_PlotPriority_DDEC = Dict{String, Int}(
    "Pareto"        => 1,
    "Fit"           => 2,
    "Trend"         => 3,
    "Slice"         => 4,
    "IntMatrix"     => 5,
    "Surface"       => 6,
    "Contour"       => 7,
    "QQ"            => 8,
    "Residuals"     => 9,
    "Sensitivity"   => 10,
    "DesignSpace"   => 11,
    "Candidates"    => 12,
    "FeasibleSpace"   => 13,
    "OptimalZone"     => 14,
    "SweetSpot"       => 15
)

const ARTS_Theme_DDEC = (
    PURWHI = C.COLOUR_PURWHI,
    LIGHIG = C.COLOUR_LIGHIG,
    LIGLOW = C.COLOUR_LIGLOW,
    DARLOW = C.COLOUR_DARLOW,
    DARHIG = C.COLOUR_DARHIG,
    PURBLA = C.COLOUR_PURBLA,
    HUERED = C.COLOUR_HUERED,
    SHAMAG = C.COLOUR_SHAMAG,
    SHABLU = C.COLOUR_SHABLU,
    TONCYA = C.COLOUR_TONCYA,
    TONGRE = C.COLOUR_TONGRE,
    HUEYEL = C.COLOUR_HUEYEL,
    INFORG = C.COLOUR_INFORG,
    FONT   = C.FONT_DEFAULT
)

const ARTS_FactorPairs_DDEC = ((1, 2), (1, 3), (2, 3))
const ARTS_SlicePairs_DDEC  = ((1, 2), (2, 3), (3, 1), (1, 3), (2, 1), (3, 2))
const ARTS_DefaultVolumeGridN_DDEC = 41

const ARTS_ViridisScale_DDEC = [
    [0.00, C.COLOUR_SHAMAG],
    [0.25, C.COLOUR_SHABLU],
    [0.50, C.COLOUR_TONCYA],
    [0.75, C.COLOUR_TONGRE],
    [1.00, C.COLOUR_HUEYEL]
]

const ARTS_BipolarScale_DDEC = [
    [0.00, C.COLOUR_SHABLU],
    [0.50, C.COLOUR_PURWHI],
    [1.00, C.COLOUR_INFORG]
]

"""
    ARTS_FormatSigned_DDEF(Value::Real) -> String
Format a signed scalar with an explicit typographic sign (+ / U+2212) at two decimal places.
"""
function ARTS_FormatSigned_DDEF(Value::Real)::String
    v = round(Float64(Value); digits=2)
    iszero(v) && return "0.00"
    return string(v < 0 ? "\u2212" : "+", @sprintf("%.2f", abs(v)))
end

# ------------------------------------------------------------------------------
# SECTION 2: PLOT DIMENSIONS & FONT SIZES
# ------------------------------------------------------------------------------

# ==============================================================================
# GROUP 2A: PLOT DIMENSIONS
# ==============================================================================

const ARTS_WidthPlot_DDEC           = 480
const ARTS_HeightPlot_DDEC          = 540
const ARTS_MarginTop_DDEC           = 35
const ARTS_MarginBottom_DDEC        = 145
const ARTS_MarginParetoLeft_DDEC    = 95
const ARTS_MarginLeft_DDEC          = 95
const ARTS_MarginRight_DDEC         = 25

# ==============================================================================
# GROUP 2B: TITLES
# ==============================================================================
const ARTS_SizeTitle_DDEC           = 22
const ARTS_SizeAxisTitle2D_DDEC     = 18
const ARTS_SizeAxisTitle3D_DDEC     = 18

# ==============================================================================
# GROUP 2C: AXIS TICKS
# ==============================================================================
const ARTS_SizeAxisTick2D_DDEC      = 16
const ARTS_SizeAxisTick3D_DDEC      = 14

# ==============================================================================
# GROUP 2D: CARDS & LEGENDS
# ==============================================================================
const ARTS_SizeGapCardText_DDEC     = 14
const ARTS_SizeInfoCardText_DDEC    = 14
const ARTS_SizeLegendText_DDEC      = 14
const ARTS_SizeColourbarTick_DDEC   = 14
const ARTS_SizeParetoBarText_DDEC   = 14
const ARTS_SizeContourText_DDEC     = 14

const ARTS_SizeDataMarker_DDEC      = 10
const ARTS_SizeLeaderMarker_DDEC    = 2

# ==============================================================================
# GROUP 2E: 3D SCENE PERSPECTIVE & CAMERA
# ==============================================================================
const ARTS_CameraEye3D_DDEC         = (x=1.85, y=1.85, z=1.35)
const ARTS_CameraCenter3D_DDEC      = (x=0.06, y=-0.06, z=-0.12)

# Regression line and trend stroke width (px).
const ARTS_WidthModelLine_DDEC      = 3

# Axis grid line stroke width (px).
const ARTS_WidthGrid_DDEC           = 1

# Plot frame and card border stroke width (px).
const ARTS_WidthFrame_DDEC          = 1

# Statistical limit and reference line stroke width (px).
const ARTS_WidthLimitLine_DDEC      = 3

# Pareto tick label rotation angle (deg).
const ARTS_AngleParetoTick_DDEC     = -45

# Interaction Matrix Y-axis tick label rotation angle (deg).
const ARTS_AngleIntMatrixTick_DDEC  = -90

# Distance between X-axis title and tick labels (px).
const ARTS_StandoffXAxis_DDEC       = 16

# Distance between Y-axis title and tick labels (px).
const ARTS_StandoffYAxis_DDEC       = 16

# Distance from top edge to chart title (px).
const ARTS_PadTitleTop_DDEC         = 10

# Vertical offset of 3D gap card centre from plot bottom (px).
const ARTS_GapCenterOffset_DDEC     = 40

# Vertical offset of info card centre from plot bottom (px).
const ARTS_CardCenterOffset_DDEC    = 100

# Height of info cards and gap cards (px).
const ARTS_CardHeight_DDEC          = 40

# Colourbar thickness (px).
const ARTS_ThickColourbar_DDEC      = 14

# Colourbar length as a fraction of plot width.
const ARTS_LenColourbar_DDEC        = 0.9

# Legend item width in card (px).
const ARTS_WidthLegendItem_DDEC     = 22

const ARTS_NetHeightPlot_DDEC       = ARTS_HeightPlot_DDEC - ARTS_MarginTop_DDEC - ARTS_MarginBottom_DDEC
const ARTS_YTitle_DDEC              = 1.0 - (ARTS_PadTitleTop_DDEC / ARTS_HeightPlot_DDEC)
const ARTS_YCenterGap_DDEC          = -(ARTS_GapCenterOffset_DDEC / ARTS_NetHeightPlot_DDEC)
const ARTS_Y0GapCard_DDEC           = -((ARTS_GapCenterOffset_DDEC + ARTS_CardHeight_DDEC / 2.0) / ARTS_NetHeightPlot_DDEC)
const ARTS_Y1GapCard_DDEC           = -((ARTS_GapCenterOffset_DDEC - ARTS_CardHeight_DDEC / 2.0) / ARTS_NetHeightPlot_DDEC)
const ARTS_YCenterCard_DDEC         = -(ARTS_CardCenterOffset_DDEC / ARTS_NetHeightPlot_DDEC)
const ARTS_Y0Card_DDEC              = -((ARTS_CardCenterOffset_DDEC + ARTS_CardHeight_DDEC / 2.0) / ARTS_NetHeightPlot_DDEC)
const ARTS_Y1Card_DDEC              = -((ARTS_CardCenterOffset_DDEC - ARTS_CardHeight_DDEC / 2.0) / ARTS_NetHeightPlot_DDEC)

# ------------------------------------------------------------------------------
# SECTION 3: BASE LAYOUT FACTORY
# ------------------------------------------------------------------------------

"""
    ARTS_BuildBaseLayout_DDEF(title; [height]) -> Layout
Generates a standardised PlotlyJS layout with fixed square canvas.
"""
function ARTS_BuildBaseLayout_DDEF(title::AbstractString; height=ARTS_HeightPlot_DDEC, subtitle::AbstractString="")
    return Layout(;
        title=attr(
            text="<b>$title</b>",
            font=attr(
                size=ARTS_SizeTitle_DDEC,
                family=ARTS_Theme_DDEC.FONT,
                color=ARTS_Theme_DDEC.PURBLA,
                weight="bold"
            ),
            xref="paper",
            x=0.5,
            xanchor="center",
            y=ARTS_YTitle_DDEC,
            yanchor="top"
        ),
        width=ARTS_WidthPlot_DDEC,
        height=height,
        autosize=true,
        paper_bgcolor=ARTS_Theme_DDEC.PURWHI,
        plot_bgcolor=ARTS_Theme_DDEC.PURWHI,
        font=attr(
            family=ARTS_Theme_DDEC.FONT,
            color=ARTS_Theme_DDEC.DARHIG,
            size=ARTS_SizeAxisTitle2D_DDEC,
            weight="bold"
        ),
        margin=attr(l=ARTS_MarginLeft_DDEC, r=ARTS_MarginRight_DDEC, t=ARTS_MarginTop_DDEC, b=ARTS_MarginBottom_DDEC),
        showlegend=true,
        dragmode="pan",
        uirevision=true,
        modebar=attr(
            orientation="v",
            bgcolor="transparent",
            color=ARTS_Theme_DDEC.DARLOW,
            activecolor=ARTS_Theme_DDEC.TONCYA
        ),
        legend=attr(
            orientation="h",
            yanchor="middle",
            y=ARTS_YCenterCard_DDEC,
            xanchor="center",
            x=0.5,
            bgcolor="transparent",
            bordercolor="transparent",
            borderwidth=0,
            font=attr(
                family=ARTS_Theme_DDEC.FONT,
                size=ARTS_SizeLegendText_DDEC,
                color=ARTS_Theme_DDEC.PURBLA,
                weight="bold"
            ),
            itemwidth=ARTS_WidthLegendItem_DDEC,
            tracegroupgap=5
        ),
        xaxis=attr(
            showline=true,
            showgrid=true,
            gridcolor=ARTS_Theme_DDEC.LIGHIG,
            gridwidth=ARTS_WidthGrid_DDEC,
            griddash="dash",
            zeroline=false,
            linecolor=ARTS_Theme_DDEC.DARLOW,
            linewidth=ARTS_WidthFrame_DDEC,
            mirror=true,
            ticks="outside",
            tickfont=attr(size=ARTS_SizeAxisTick2D_DDEC, weight="bold"),
            automargin=false,
            title=attr(standoff=ARTS_StandoffXAxis_DDEC, font=attr(size=ARTS_SizeAxisTitle2D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG, weight="bold"))
        ),
        yaxis=attr(
            showline=true,
            showgrid=true,
            gridcolor=ARTS_Theme_DDEC.LIGHIG,
            gridwidth=ARTS_WidthGrid_DDEC,
            griddash="dash",
            zeroline=false,
            linecolor=ARTS_Theme_DDEC.DARLOW,
            linewidth=ARTS_WidthFrame_DDEC,
            mirror=true,
            ticks="outside",
            tickfont=attr(size=ARTS_SizeAxisTick2D_DDEC, weight="bold"),
            automargin=false,
            title=attr(standoff=ARTS_StandoffYAxis_DDEC, font=attr(size=ARTS_SizeAxisTitle2D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG, weight="bold"))
        ),
        colorway=[
            ARTS_Theme_DDEC.SHAMAG,
            ARTS_Theme_DDEC.SHABLU,
            ARTS_Theme_DDEC.TONCYA
        ],
        hovermode="closest",
        template="plotly_white",
        shapes=[
            attr(
                type="rect",
                xref="paper",
                yref="paper",
                x0=0.0,
                x1=1.0,
                y0=0.0,
                y1=1.0,
                fillcolor="transparent",
                line=attr(color=ARTS_Theme_DDEC.DARLOW, width=ARTS_WidthFrame_DDEC)
            ),
            attr(
                type="rect",
                xref="paper",
                yref="paper",
                x0=0.0,
                x1=1.0,
                y0=ARTS_Y0Card_DDEC,
                y1=ARTS_Y1Card_DDEC,
                fillcolor=ARTS_Theme_DDEC.PURWHI,
                line=attr(color=ARTS_Theme_DDEC.DARLOW, width=ARTS_WidthFrame_DDEC)
            )
        ]
    )
end

"""
    ARTS_SetAxisTitles_DDEF!(layout, xtitle, [ytitle])
Applies strict standoff distance to axes titles to eliminate overlaps with the lower info card.
"""
function ARTS_SetAxisTitles_DDEF!(layout, xtitle::AbstractString, ytitle::AbstractString="")
    layout[:xaxis][:title] = attr(text="<b>$xtitle</b>", standoff=ARTS_StandoffXAxis_DDEC, font=attr(size=ARTS_SizeAxisTitle2D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG))
    if !isempty(ytitle)
        layout[:yaxis][:title] = attr(text="<b>$ytitle</b>", standoff=ARTS_StandoffYAxis_DDEC, font=attr(size=ARTS_SizeAxisTitle2D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG))
    end
end

"""
    ARTS_AddGapCard_DDEF!(layout)
Appends a secondary container card matching the primary info card geometry to house 3D badges.
"""
function ARTS_AddGapCard_DDEF!(layout)
    push!(layout[:shapes], attr(
        type="rect",
        xref="paper",
        yref="paper",
        x0=0.0,
        x1=1.0,
        y0=ARTS_Y0GapCard_DDEC,
        y1=ARTS_Y1GapCard_DDEC,
        fillcolor=ARTS_Theme_DDEC.PURWHI,
        line=attr(color=ARTS_Theme_DDEC.DARLOW, width=ARTS_WidthFrame_DDEC)
    ))
end

# ------------------------------------------------------------------------------
# SECTION 4: ADAPTIVE GRID RESOLUTION LOGIC
# ------------------------------------------------------------------------------

const ARTS_MaxGridPoints_DDEC = 11000

"""
    ARTS_CalcAdaptiveGridN_DDEF(preferred, [max_total]) -> Int
Returns a grid resolution N such that N×N ≤ max_total.
"""
function ARTS_CalcAdaptiveGridN_DDEF(preferred::Integer, max_total::Integer=ARTS_MaxGridPoints_DDEC)
    N = preferred
    while N * N > max_total && N > 5
        N -= 1
    end
    return N
end

# ------------------------------------------------------------------------------
# SECTION 5: DYNAMIC HARDWARE RESOLUTION & DOWNSAMPLING & MATRIX PREPARATION
# ------------------------------------------------------------------------------

"""
    ARTS_GetDynamicGridN_DDEF() -> Int
Returns a dynamic grid resolution (N) based on available system hardware threads.
Rule: N=61 for ≤4 threads, N=101 for >4 threads.
"""
function ARTS_GetDynamicGridN_DDEF()::Int
    threads = FAST_GetComputeThreads_DDEF()
    return (threads <= 4 ? 61 : 101)
end

"""
    ARTS_Downsample_DDEF(Z, target_rows, target_cols) -> Matrix
Sub-samples oversized matrices using strided decimation for optimal browser performance.
"""
function ARTS_Downsample_DDEF(Z::AbstractMatrix{T}, target_rows::Integer, target_cols::Integer) where T
    nr, nc = size(Z)
    (nr ≤ target_rows && nc ≤ target_cols) && return Z

    row_stride = max(1, nr ÷ target_rows)
    col_stride = max(1, nc ÷ target_cols)

    row_idx = 1:row_stride:nr
    col_idx = 1:col_stride:nc

    row_idx = unique([collect(row_idx); nr])
    col_idx = unique([collect(col_idx); nc])

    FAST_Log_DDEF("ARTS", "DOWNSAMPLE",
        "Reduced $(nr)×$(nc) → $(length(row_idx))×$(length(col_idx))", "INFO")
    return Z[row_idx, col_idx]
end

"""
    ARTS_SmoothMatrix_DDEF(Z, [passes]) -> Matrix
Applies a 3x3 box blur filter to a matrix to reduce visual aliasing (staircase effect).
Automatically handles NaNs by calculating the mean of valid neighbouring pixels.
Includes boundary handling for consistent smoothing across the entire surface.
"""
function ARTS_SmoothMatrix_DDEF(Z::AbstractMatrix{Float64}, passes::Integer=1)
    nr, nc = size(Z)
    (nr < 2 || nc < 2 || passes <= 0) && return copy(Z)

    has_nan = any(isnan, Z)
    # Ping-pong preallocated buffers avoid per-pass matrix copies during iterative smoothing.
    Buf1 = Matrix{Float64}(undef, nr, nc)
    Buf2 = passes >= 2 ? Matrix{Float64}(undef, nr, nc) : Buf1
    Src  = Z
    Dst  = Buf1

    for p in 1:passes
        if !has_nan && nr >= 3 && nc >= 3
            inv9 = 1.0 / 9.0
            @inbounds for j in 2:(nc - 1)
                jm1, jp1 = j - 1, j + 1
                for i in 2:(nr - 1)
                    im1, ip1 = i - 1, i + 1
                    Dst[i, j] = (
                        Src[im1, jm1] + Src[i, jm1] + Src[ip1, jm1] +
                        Src[im1, j  ] + Src[i, j  ] + Src[ip1, j  ] +
                        Src[im1, jp1] + Src[i, jp1] + Src[ip1, jp1]
                    ) * inv9
                end
            end
            inv6 = 1.0 / 6.0
            @inbounds for j in 2:(nc - 1)
                jm1, jp1 = j - 1, j + 1
                Dst[1, j] = (Src[1, jm1] + Src[1, j] + Src[1, jp1] +
                             Src[2, jm1] + Src[2, j] + Src[2, jp1]) * inv6
                Dst[nr, j] = (Src[nr-1, jm1] + Src[nr-1, j] + Src[nr-1, jp1] +
                              Src[nr,   jm1] + Src[nr,   j] + Src[nr,   jp1]) * inv6
            end
            @inbounds for i in 2:(nr - 1)
                im1, ip1 = i - 1, i + 1
                Dst[i, 1] = (Src[im1, 1] + Src[i, 1] + Src[ip1, 1] +
                             Src[im1, 2] + Src[i, 2] + Src[ip1, 2]) * inv6
                Dst[i, nc] = (Src[im1, nc-1] + Src[i, nc-1] + Src[ip1, nc-1] +
                              Src[im1, nc  ] + Src[i, nc  ] + Src[ip1, nc  ]) * inv6
            end
            inv4 = 1.0 / 4.0
            @inbounds begin
                Dst[1, 1]   = (Src[1, 1] + Src[1, 2] + Src[2, 1] + Src[2, 2]) * inv4
                Dst[1, nc]  = (Src[1, nc-1] + Src[1, nc] + Src[2, nc-1] + Src[2, nc]) * inv4
                Dst[nr, 1]  = (Src[nr-1, 1] + Src[nr-1, 2] + Src[nr, 1] + Src[nr, 2]) * inv4
                Dst[nr, nc] = (Src[nr-1, nc-1] + Src[nr-1, nc] + Src[nr, nc-1] + Src[nr, nc]) * inv4
            end
        else
            @inbounds for j in 1:nc
                c_start, c_end = max(1, j-1), min(nc, j+1)
                for i in 1:nr
                    r_start, r_end = max(1, i-1), min(nr, i+1)
                    s_val = 0.0
                    s_cnt = 0
                    for c in c_start:c_end
                        for r in r_start:r_end
                            v = Src[r, c]
                            if !isnan(v)
                                s_val += v
                                s_cnt += 1
                            end
                        end
                    end
                    Dst[i, j] = s_cnt > 0 ? (s_val / s_cnt) : Src[i, j]
                end
            end
        end
        if p < passes
            Src = Dst
            Dst = (Dst === Buf1) ? Buf2 : Buf1
        end
    end

    return Dst
end

"""
    ARTS_PrepareMatrix_DDEF(M) -> Matrix{Float64}
Defensive matrix converter for JSON/store deserialised arrays or generic matrices.
"""
function ARTS_PrepareMatrix_DDEF(M::Matrix{Float64})
    return M
end

function ARTS_PrepareMatrix_DDEF(M::AbstractMatrix)
    return Float64.(collect(M))
end

function ARTS_PrepareMatrix_DDEF(M::AbstractVector)
    if !isempty(M) && all(m -> m isa AbstractVector, M)
        return Float64.(reduce(vcat, transpose.(collect.(M))))
    end
    return Float64.(collect(M))
end

function ARTS_PrepareMatrix_DDEF(M::Any)
    return Float64.(collect(M))
end

"""
    ARTS_PrepareStringVector_DDEF(S) -> Vector{String}
Defensive string vector converter that returns the vector directly if already Vector{String}.
"""
function ARTS_PrepareStringVector_DDEF(S::Vector{String})
    return S
end

function ARTS_PrepareStringVector_DDEF(S::AbstractVector)
    return collect(String, map(string, S))
end

"""
    ARTS_PrepareFloatVector_DDEF(V) -> Vector{Float64}
Defensive float vector converter that returns the vector directly if already Vector{Float64}.
"""
function ARTS_PrepareFloatVector_DDEF(V::Vector{Float64})
    return V
end

function ARTS_PrepareFloatVector_DDEF(V::AbstractVector)
    return collect(Float64, V)
end

"""
    ARTS_PrepareNestedVector_DDEF(N) -> Vector{Vector{Float64}}
Defensive nested float vector converter that returns the vector directly if already Vector{Vector{Float64}}.
"""
function ARTS_PrepareNestedVector_DDEF(N::Vector{Vector{Float64}})
    return N
end

function ARTS_PrepareNestedVector_DDEF(N::AbstractVector)
    return [collect(Float64, s) for s in N]
end

"""
    ARTS_HexToRGBA_DDEF(hex, alpha) -> String
Convert hex colour strings to RGBA format for Plotly transparency support.
"""
function ARTS_HexToRGBA_DDEF(hex::AbstractString, alpha::AbstractFloat)
    h = replace(hex, "#" => "")
    r = parse(Int, h[1:2], base=16)
    g = parse(Int, h[3:4], base=16)
    b = parse(Int, h[5:6], base=16)
    return "rgba($r, $g, $b, $alpha)"
end

"""
    ARTS_GenAlphaViridis_DDEF(thresh) -> Vector
Generates a custom Viridis colour scale with a smooth alpha-gradient at the threshold.
Eliminates aliasing by using fragment-level transparency instead of mesh-level NaN clipping.
"""
function ARTS_GenAlphaViridis_DDEF(thresh::AbstractFloat)
    t = clamp(Float64(thresh), 0.02, 0.99)
    fade_start = clamp(t - 0.10, 0.015, t - 0.01)
    pre_fade   = clamp(fade_start - 0.01, 0.005, fade_start - 0.002)

    base_cols = [
        C.COLOUR_SHAMAG, C.COLOUR_SHABLU, C.COLOUR_TONCYA, C.COLOUR_TONGRE, C.COLOUR_HUEYEL
    ]

    scale = Any[]
    push!(scale, [0.0,        "rgba(255,255,255,0)"])
    push!(scale, [pre_fade,   "rgba(255,255,255,0)"])
    push!(scale, [fade_start, ARTS_HexToRGBA_DDEF(base_cols[1], 0.0)])
    push!(scale, [t,          ARTS_HexToRGBA_DDEF(base_cols[1], 1.0)])

    for i in 2:5
        val = t + (1.0 - t) * ((i - 1) / 4)
        push!(scale, [val, ARTS_HexToRGBA_DDEF(base_cols[i], 1.0)])
    end

    return scale
end

# ==============================================================================
# PART B: ACADEMIC DIAGNOSTICS & PLOTTING
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 6: PARETO ANALYSIS VISUALISER (MULTIPLE DISPATCH)
# ------------------------------------------------------------------------------

"""
    ARTS_RenderPareto_DDEF(Model::AbstractDict, OutName::AbstractString, R2_Adj::AbstractFloat, R2_Pred::AbstractFloat) -> PlotlyJS.Plot
Render a horizontal Pareto bar chart ranking standardised regression factor effects by absolute t-value magnitude.
Includes a Bonferroni-corrected critical significance threshold line to highlight statistically influential experimental factors.

# Arguments
- `Model::AbstractDict`: Fitted regression model dictionary containing coefficients and term labels.
- `OutName::AbstractString`: Response variable name for chart titling.
- `R2_Adj::AbstractFloat`: Adjusted coefficient of determination for model context.
- `R2_Pred::AbstractFloat`: Predictive cross-validation coefficient of determination (Q²).

# Returns
- `PlotlyJS.Plot`: Formatted Plotly figure ready for interactive web display.
"""
function ARTS_RenderPareto_DDEF(Model::AbstractDict, OutName::AbstractString, R2_Adj::AbstractFloat, R2_Pred::AbstractFloat)
    return ARTS_Draw_DDEF(ARTS_PlotPareto_DDES(), Model, OutName, R2_Adj, R2_Pred)
end

const ARTS_ParetoQuadraticTerms_DDEC = ["X1", "X2", "X3", "X1 × X2", "X1 × X3", "X2 × X3", "X1²", "X2²", "X3²"]
const ARTS_ParetoLinearTerms_DDEC    = ["X1", "X2", "X3"]

"""
    ARTS_FormatParetoTerms_DDEF(CleanNames::AbstractVector{<:AbstractString}) -> Vector{String}
Format regression model parameter names into concise mathematical subscript notation for Pareto charts.
"""
function ARTS_FormatParetoTerms_DDEF(CleanNames::AbstractVector{<:AbstractString})::Vector{String}
    n = length(CleanNames)
    if n == 9
        return copy(ARTS_ParetoQuadraticTerms_DDEC)
    elseif n == 3
        return copy(ARTS_ParetoLinearTerms_DDEC)
    else
        return collect(String, CleanNames)
    end
end

function ARTS_Draw_DDEF(::ARTS_PlotPareto_DDES, Model::AbstractDict, OutName::AbstractString, R2_Adj::AbstractFloat, R2_Pred::AbstractFloat)
    mod_status = get(Model, "Status", "FAIL")
    if mod_status != "OK"
        # Emergency placeholder layout for failed models
        layout = ARTS_BuildBaseLayout_DDEF("Analysis Bypass: $OutName")
        return Plot(scatter(x=[0], y=[0], mode="text", text="Modelling Failure: Check Diagnostics"), layout)
    end
    
    # Defensive acquisition of model coefficients and metadata
    Coefs = get(Model, "Coefs", Float64[])
    isempty(Coefs) && return Plot(scatter(x=[0], y=[0], mode="text", text="Incomplete Data: No Coefs"), ARTS_BuildBaseLayout_DDEF(OutName))
    
    Names = get(Model, "TermNames", ["T$i" for i in eachindex(Coefs)])
    t_Stats = get(Model, "t_Stats", Coefs) 
    N_Samples = get(Model, "N_Samples", length(Coefs) + 5)

    clean_eff = @view t_Stats[2:end]
    has_t = !any(isnan, clean_eff)
    clean_nms = ARTS_FormatParetoTerms_DDEF(@view Names[2:end])
    clean_signs = has_t ? sign.(clean_eff) : sign.(@view Coefs[2:end])
    magnitudes = has_t ? abs.(clean_eff) : abs.(@view Coefs[2:end])

    perm = sortperm(magnitudes)
    sorted_mag, sorted_nms, sorted_sgn = magnitudes[perm], clean_nms[perm], clean_signs[perm]

    df, alpha = max(1, N_Samples - length(Coefs)), C.EVAL_ALPHA_SIG / length(clean_eff)
    t_crit = quantile(TDist(df), 1.0 - alpha / 2)

    sorted_nms_bold = ["<b>$nm</b>" for nm in sorted_nms]
    is_inside = [m >= 2.2 for m in sorted_mag]
    txt_colors = [inside ? ARTS_Theme_DDEC.PURWHI : ARTS_Theme_DDEC.PURBLA for inside in is_inside]

    pos_idx = findall(s -> s > 0, sorted_sgn)
    neg_idx = findall(s -> s <= 0, sorted_sgn)

    pos_txt = ["<b>$(ARTS_FormatSigned_DDEF(sorted_sgn[i] * sorted_mag[i]))</b>" for i in pos_idx]
    pos_pos = [is_inside[i] ? "inside" : "outside" for i in pos_idx]
    pos_col = [txt_colors[i] for i in pos_idx]

    t_pos = bar(;
        x = sorted_mag[pos_idx],
        y = sorted_nms_bold[pos_idx],
        orientation = "h",
        name = "<b>(+)</b>",
        marker = attr(color=ARTS_Theme_DDEC.INFORG, line=attr(width=0)),
        showlegend = true,
        text = pos_txt,
        textposition = pos_pos,
        insidetextanchor = "end",
        textfont = attr(size=ARTS_SizeParetoBarText_DDEC, family=ARTS_Theme_DDEC.FONT, color=pos_col),
        cliponaxis = false,
        hovertemplate = "<b>%{y}</b>: +%{x:.2f}<extra></extra>"
    )

    neg_txt = ["<b>$(ARTS_FormatSigned_DDEF(sorted_sgn[i] * sorted_mag[i]))</b>" for i in neg_idx]
    neg_pos = [is_inside[i] ? "inside" : "outside" for i in neg_idx]
    neg_col = [txt_colors[i] for i in neg_idx]

    t_neg = bar(;
        x = sorted_mag[neg_idx],
        y = sorted_nms_bold[neg_idx],
        orientation = "h",
        name = "<b>(−)</b>",
        marker = attr(color=ARTS_Theme_DDEC.SHABLU, line=attr(width=0)),
        showlegend = true,
        text = neg_txt,
        textposition = neg_pos,
        insidetextanchor = "end",
        textfont = attr(size=ARTS_SizeParetoBarText_DDEC, family=ARTS_Theme_DDEC.FONT, color=neg_col),
        cliponaxis = false,
        hovertemplate = "<b>%{y}</b>: \u2212%{x:.2f}<extra></extra>"
    )

    traces = if has_t
        t_bonf = scatter(;
            x = [t_crit, t_crit],
            y = [0, 1],
            yaxis = "y2",
            mode = "lines",
            name = "<b>Bonferroni Limit</b>",
            line = attr(color=ARTS_Theme_DDEC.PURBLA, width=ARTS_WidthLimitLine_DDEC, dash="dash"),
            showlegend = true,
            hovertemplate = "<b>Bonferroni Limit</b>: $(@sprintf("%.2f", t_crit))<extra></extra>"
        )
        [t_bonf, t_pos, t_neg]
    else
        [t_pos, t_neg]
    end

    layout = ARTS_BuildBaseLayout_DDEF("Pareto: $OutName")
    ARTS_SetAxisTitles_DDEF!(layout, has_t ? "|t-value|" : "|Coefficient|")
    layout[:barmode] = "overlay"
    layout[:margin] = attr(l=ARTS_MarginParetoLeft_DDEC, r=ARTS_MarginRight_DDEC, t=ARTS_MarginTop_DDEC, b=ARTS_MarginBottom_DDEC)
    layout[:yaxis][:tickangle] = ARTS_AngleParetoTick_DDEC
    layout[:yaxis][:tickfont] = attr(size=ARTS_SizeAxisTick2D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)
    layout[:yaxis][:categoryorder] = "array"
    layout[:yaxis][:categoryarray] = sorted_nms_bold
    layout[:yaxis2] = attr(
        overlaying = "y",
        side = "right",
        range = [0, 1],
        showgrid = false,
        zeroline = false,
        showline = false,
        showticklabels = false,
        fixedrange = true
    )

    return Plot(traces, layout)
end

# ------------------------------------------------------------------------------
# SECTION 7: PREDICTION ACCURACY PLOTS
# ------------------------------------------------------------------------------

"""
    ARTS_RenderFit_DDEF(Y_Real::AbstractVector{Float64}, Y_Pred::AbstractVector{Float64}, OutName::AbstractString) -> PlotlyJS.Plot
Render a scatter plot comparing experimental response observations against model-predicted values.
Overlays a diagonal 45-degree dashed reference line to visualise regression accuracy and prediction dispersion.

# Arguments
- `Y_Real::AbstractVector{Float64}`: Observed experimental response measurements.
- `Y_Pred::AbstractVector{Float64}`: Model-estimated response values.
- `OutName::AbstractString`: Response variable name.

# Returns
- `PlotlyJS.Plot`: Plotly scatter figure with diagnostic reference styling.
"""
function ARTS_RenderFit_DDEF(Y_Real::AbstractVector{Float64}, Y_Pred::AbstractVector{Float64}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotFit_DDES(), Y_Real, Y_Pred, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotFit_DDES, Y_Real::AbstractVector{Float64}, Y_Pred::AbstractVector{Float64}, OutName::AbstractString)
    mn, mx = min(minimum(Y_Real), minimum(Y_Pred)), max(maximum(Y_Real), maximum(Y_Pred))
    margin = (mx - mn) * 0.05

    t_data = scatter(; x = Y_Real, y = Y_Pred, mode = "markers",
        marker = attr(size=ARTS_SizeDataMarker_DDEC, color=ARTS_Theme_DDEC.TONCYA, opacity=0.85, line=attr(width=1, color=ARTS_Theme_DDEC.PURBLA)), 
        name = "<b>Observed Data</b>")

    t_ideal = scatter(; x = [mn - margin, mx + margin], y = [mn - margin, mx + margin],
        mode = "lines", line = attr(color=ARTS_Theme_DDEC.DARHIG, dash="dash", width=ARTS_WidthLimitLine_DDEC), 
        name = "<b>Perfect Fit</b>")

    layout = ARTS_BuildBaseLayout_DDEF("Model Fit: $OutName")
    ARTS_SetAxisTitles_DDEF!(layout, "Experimental Record", "Model Estimation")
    
    return Plot([t_ideal, t_data], layout)
end

# ==============================================================================
# PART C: RESPONSE SURFACE METHODOLOGY (RSM) ANALYTICS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 8: RSM INTERNAL PREDICTION GATEWAY
# ------------------------------------------------------------------------------

"""
    ARTS_Predict_DDEF(Model, X) -> Vector{Float64}
Internal evaluator for plotting grids (stateless design matrix expansion).
"""
function ARTS_Predict_DDEF(Model::AbstractDict, X::AbstractMatrix{Float64}, buff_Xd::Union{Nothing, AbstractMatrix{Float64}}=nothing)
    m_type = CORE_GetModelType_DDEF(string(get(Model, "ModelType", "quadratic")))
    return ARTS_Predict_DDEF(m_type, X, get(Model, "Coefs", Float64[]), buff_Xd)
end

function ARTS_Predict_DDEF(::CORE_ModelQuadratic_DDES, X::AbstractMatrix{Float64}, Beta::AbstractVector, buff_Xd)
    return ARTS_PredictQuadratic_DDEF(X, Beta, buff_Xd)
end

function ARTS_Predict_DDEF(::CORE_ModelLinear_DDES, X::AbstractMatrix{Float64}, Beta::AbstractVector, buff_Xd)
    return ARTS_PredictLinear_DDEF(X, Beta, buff_Xd)
end

function ARTS_PredictLinear_DDEF(X, Beta, buff_Xd=nothing)
    N, k = size(X)
    length(Beta) == k + 1 || throw(DimensionMismatch("Linear predictor expected $(k + 1) coefficients, got $(length(Beta))"))
    y = fill(Float64(Beta[1]), N)
    @inbounds for j in 1:k
        bj = Float64(Beta[j + 1])
        for i in 1:N
            y[i] += bj * X[i, j]
        end
    end
    return y
end

function ARTS_PredictQuadratic_DDEF(X, Beta, buff_Xd)
    N = size(X, 1)
    # Standard 10-term Quadratic (1 + 3 + 3 + 3)
    Xd = if !isnothing(buff_Xd) && size(buff_Xd, 1) >= N && size(buff_Xd, 2) >= 10
        view(buff_Xd, 1:N, 1:10)
    else
        Matrix{Float64}(undef, N, 10)
    end
    
    fill!(view(Xd, :, 1), 1.0)
    copyto!(view(Xd, :, 2:4), X)
    
    # Interactions: Optimised mapping for 3-factor system
    @inbounds @views begin
        @. Xd[:, 5] = X[:, 1] * X[:, 2]
        @. Xd[:, 6] = X[:, 1] * X[:, 3]
        @. Xd[:, 7] = X[:, 2] * X[:, 3]
        @. Xd[:, 8:10] = abs2(X)
    end
    
    return Xd * Beta
end

# ------------------------------------------------------------------------------
# SECTION 9: PREDICTION GRID CONSTRUCTOR
# ------------------------------------------------------------------------------

function ARTS_BuildGrid_DDEF(X::AbstractMatrix{Float64}, ix::Integer, iy::Integer, N_requested::Integer, buff_Grid::Union{Nothing, AbstractMatrix{Float64}}=nothing)
    N = ARTS_CalcAdaptiveGridN_DDEF(N_requested)
    x1 = range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length=N)
    x2 = range(minimum(view(X, :, iy)), maximum(view(X, :, iy)); length=N)

    Grid = if !isnothing(buff_Grid) && size(buff_Grid, 1) >= (N*N)
        view(buff_Grid, 1:(N*N), :)
    else
        repeat(mean(X; dims=1), N * N)
    end
    
    @inbounds for (k, pt) in enumerate(Iterators.product(x1, x2))
        Grid[k, ix] = pt[1]
        Grid[k, iy] = pt[2]
    end
    return x1, x2, Grid
end

# ------------------------------------------------------------------------------
# SECTION 10: 3D RESPONSE SURFACE RENDERER
# ------------------------------------------------------------------------------

"""
    ARTS_RenderSurface_DDEF(Model::AbstractDict, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString) -> PlotlyJS.Plot
Render an interactive 3D response surface mesh illustrating response behaviour across two active factors.
Holds unselected factors constant at their domain midpoint while evaluating curvature using continuous Viridis colours.

# Arguments
- `Model::AbstractDict`: Fitted response surface regression model dictionary.
- `X::AbstractMatrix{Float64}`: Experimental factor coordinate matrix.
- `Idx::AbstractVector{<:Integer}`: Pair of column indices for the x and y axes.
- `Lbls::AbstractVector{<:AbstractString}`: Human-readable factor labels for axis annotation.
- `OutName::AbstractString`: Name of the plotted response variable.

# Returns
- `PlotlyJS.Plot`: Interactive 3D Plotly surface visualisation.
"""
function ARTS_RenderSurface_DDEF(Model::AbstractDict, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotSurface_DDES(), Model, X, Idx, Lbls, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotSurface_DDES, Model::AbstractDict, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    ix, iy = Idx[1], Idx[2]
    N = ARTS_GetDynamicGridN_DDEF()
    x1, x2, Grid = ARTS_BuildGrid_DDEF(X, ix, iy, N)
    Z = reshape(ARTS_Predict_DDEF(Model, Grid), N, N)'
    
    # Apply Smoothing (Anti-aliasing)
    Z = ARTS_SmoothMatrix_DDEF(Z, 1)

    trace = surface(; x=collect(x1), y=collect(x2), z=Z, colorscale=ARTS_ViridisScale_DDEC,
        contours=attr(z=attr(show=true, usecolormap=true, project_z=true)),
        colorbar=attr(orientation="h", x=0.5, xanchor="center", y=ARTS_YCenterCard_DDEC, yanchor="middle", thickness=ARTS_ThickColourbar_DDEC, len=ARTS_LenColourbar_DDEC, tickfont=attr(size=ARTS_SizeColourbarTick_DDEC, weight="bold")))

    layout = ARTS_BuildBaseLayout_DDEF("Response Surface: $OutName")
    layout[:scene] = attr(
        xaxis=attr(title=attr(text=Lbls[1], font=attr(size=ARTS_SizeAxisTitle3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
                   tickfont=attr(size=ARTS_SizeAxisTick3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
        yaxis=attr(title=attr(text=Lbls[2], font=attr(size=ARTS_SizeAxisTitle3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
                   tickfont=attr(size=ARTS_SizeAxisTick3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
        zaxis=attr(title=attr(text=OutName, font=attr(size=ARTS_SizeAxisTitle3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
                   tickfont=attr(size=ARTS_SizeAxisTick3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
        camera=attr(eye=ARTS_CameraEye3D_DDEC, center=ARTS_CameraCenter3D_DDEC), aspectmode="cube", dragmode="turntable", uirevision=true)
    layout[:margin] = attr(l=ARTS_MarginLeft_DDEC, r=ARTS_MarginRight_DDEC, t=ARTS_MarginTop_DDEC, b=ARTS_MarginBottom_DDEC)
    layout[:xaxis] = attr(visible=false, showline=false, showgrid=false, zeroline=false, showticklabels=false)
    layout[:yaxis] = attr(visible=false, showline=false, showgrid=false, zeroline=false, showticklabels=false)

    hold_parts = String[]
    term_names = get(Model, "TermNames", String[])
    for h in 1:size(X, 2)
        if h != ix && h != iy
            fac_name = length(Lbls) >= size(X, 2) ? Lbls[h] : (h + 1 <= length(term_names) ? term_names[h + 1] : "X$h")
            val = mean(view(X, :, h))
            val_str = abs(val) < 1e-4 ? "0" : (isinteger(val) ? string(Int(round(val))) : @sprintf("%.2f", val))
            push!(hold_parts, "$fac_name = $val_str")
        end
    end

    if !isempty(hold_parts)
        ARTS_AddGapCard_DDEF!(layout)
        hold_str = join(hold_parts, ", ")
        layout[:annotations] = [
            attr(xref="paper", yref="paper", x=0.5, y=ARTS_YCenterGap_DDEC,
                 text=hold_str,
                 showarrow=false,
                 font=attr(size=ARTS_SizeGapCardText_DDEC, color=ARTS_Theme_DDEC.PURBLA, weight="bold"),
                 xanchor="center", yanchor="middle")
        ]
    end

    return Plot(trace, layout)
end

# ------------------------------------------------------------------------------
# SECTION 11: 2D CONTOUR PROJECTION RENDERER 
# ------------------------------------------------------------------------------

"""
    ARTS_RenderContour_DDEF(Model::AbstractDict, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString) -> PlotlyJS.Plot
Render a 2D contour projection index representing response surface topography across two factors.
Computes iso-response contour curves over an interpolated grid using the academic Viridis colour palette.

# Arguments
- `Model::AbstractDict`: Fitted regression model dictionary.
- `X::AbstractMatrix{Float64}`: Factor coordinate matrix.
- `Idx::AbstractVector{<:Integer}`: Indices of the two continuous factors to project.
- `Lbls::AbstractVector{<:AbstractString}`: Axis labels for the selected factors.
- `OutName::AbstractString`: Plotted response variable name.

# Returns
- `PlotlyJS.Plot`: Plotly 2D contour plot with labelled iso-lines.
"""
function ARTS_RenderContour_DDEF(Model::AbstractDict, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotContour_DDES(), Model, X, Idx, Lbls, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotContour_DDES, Model::AbstractDict, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    ix, iy = Idx[1], Idx[2]
    N = ARTS_GetDynamicGridN_DDEF()
    x1, x2, Grid = ARTS_BuildGrid_DDEF(X, ix, iy, N)
    Z = reshape(ARTS_Predict_DDEF(Model, Grid), N, N)'
    
    # Apply Smoothing (Anti-aliasing) for heatmap clarity
    Z = ARTS_SmoothMatrix_DDEF(Z, 2)

    trace = contour(; x=collect(x1), y=collect(x2), z=Z, colorscale=ARTS_ViridisScale_DDEC,
        contours=attr(coloring="heatmap", showlabels=true, labelfont=attr(size=ARTS_SizeContourText_DDEC, weight="bold")),
        colorbar=attr(orientation="h", x=0.5, xanchor="center", y=ARTS_YCenterCard_DDEC, yanchor="middle", thickness=ARTS_ThickColourbar_DDEC, len=ARTS_LenColourbar_DDEC, tickfont=attr(size=ARTS_SizeColourbarTick_DDEC, weight="bold")))

    layout = ARTS_BuildBaseLayout_DDEF("Contour: $OutName")
    ARTS_SetAxisTitles_DDEF!(layout, Lbls[1], Lbls[2])
    
    return Plot(trace, layout)
end

# ==============================================================================
# PART D: SOLUTION SPACE MAPPING & OPTIMISATION
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 12: INTERACTION SLICE ANALYSER
# ------------------------------------------------------------------------------

"""
    ARTS_RenderSlice_DDEF(Model::AbstractDict, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString) -> PlotlyJS.Plot
Render a 2D interaction slice diagram demonstrating two-factor interaction effects on a target response.
Plots the response curve across factor 1 at the minimum, mean, and maximum settings of factor 2.

# Arguments
- `Model::AbstractDict`: Fitted regression model dictionary.
- `X::AbstractMatrix{Float64}`: Experimental design factor matrix.
- `Idx::AbstractVector{<:Integer}`: Column indices of primary and moderating factors.
- `Lbls::AbstractVector{<:AbstractString}`: Descriptive labels for the evaluated factor pair.
- `OutName::AbstractString`: Response variable name.

# Returns
- `PlotlyJS.Plot`: Multi-trace interaction plot showing conditional trajectories.
"""
function ARTS_RenderSlice_DDEF(Model::AbstractDict, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotSlice_DDES(), Model, X, Idx, Lbls, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotSlice_DDES, Model::AbstractDict, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    ix, iy = Idx[1], Idx[2]
    N = ARTS_GetDynamicGridN_DDEF()

    x1 = collect(range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length=N))
    y_vals = (minimum(view(X, :, iy)), mean(view(X, :, iy)), maximum(view(X, :, iy)))
    y_names, styles = ("Min", "Mean", "Max"), ("dot", "dash", "solid")
    colours = (ARTS_Theme_DDEC.SHAMAG, ARTS_Theme_DDEC.SHABLU, ARTS_Theme_DDEC.TONCYA)

    col_means = vec(mean(X; dims=1))
    traces = GenericTrace[]

    for i in eachindex(y_vals)
        Grid = repeat(col_means', length(x1))
        Grid[:, ix] .= x1
        Grid[:, iy] .= y_vals[i]

        z = ARTS_Predict_DDEF(Model, Grid)
        push!(traces, scatter(; x=x1, y=z, mode="lines", name="<b>$(y_names[i])</b>",
            line=attr(color=colours[i], dash=styles[i], width=ARTS_WidthModelLine_DDEC)))
    end

    layout = ARTS_BuildBaseLayout_DDEF("Interaction Slices: $OutName")
    lbl_text = "$(Lbls[2]):"
    lbl_size = clamp(floor(Int, ARTS_SizeLegendText_DDEC * 14 / max(length(lbl_text), 1)), 9, ARTS_SizeLegendText_DDEC)
    layout[:annotations] = [
        attr(
            text="<b>$lbl_text</b>",
            xref="paper",
            yref="paper",
            x=0.31,
            y=ARTS_YCenterCard_DDEC,
            xanchor="right",
            yanchor="middle",
            showarrow=false,
            font=attr(
                size=lbl_size,
                family=ARTS_Theme_DDEC.FONT,
                color=ARTS_Theme_DDEC.PURBLA,
                weight="bold"
            )
        )
    ]
    layout[:legend][:x] = 0.33
    layout[:legend][:xanchor] = "left"
    layout[:legend][:y] = ARTS_YCenterCard_DDEC
    layout[:legend][:yanchor] = "middle"
    ARTS_SetAxisTitles_DDEF!(layout, Lbls[1], OutName)
    
    return Plot(traces, layout)
end

# ------------------------------------------------------------------------------
# SECTION 13: MAIN EFFECT TREND VISUALISER
# ------------------------------------------------------------------------------

"""
    ARTS_RenderTrend_DDEF(Model::AbstractDict, X::AbstractMatrix{Float64}, Y_Real::AbstractVector{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString) -> PlotlyJS.Plot
Render a main effect trend line showing predicted response variation across a single factor dimension.
Superimposes experimental observations onto the model estimation curve while holding remaining factors at their centres.

# Arguments
- `Model::AbstractDict`: Fitted regression model dictionary.
- `X::AbstractMatrix{Float64}`: Experimental factor coordinate matrix.
- `Y_Real::AbstractVector{Float64}`: Observed experimental response data.
- `Idx::AbstractVector{<:Integer}`: Single-element vector or index specifying the active factor.
- `Lbls::AbstractVector{<:AbstractString}`: Factor label for x-axis annotation.
- `OutName::AbstractString`: Response variable name.

# Returns
- `PlotlyJS.Plot`: Main effect plot with overlaid experimental observations.
"""
function ARTS_RenderTrend_DDEF(Model::AbstractDict, X::AbstractMatrix{Float64}, Y_Real::AbstractVector{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotTrend_DDES(), Model, X, Y_Real, Idx, Lbls, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotTrend_DDES, Model::AbstractDict, X::AbstractMatrix{Float64}, Y_Real::AbstractVector{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    ix = Idx[1]
    N = ARTS_GetDynamicGridN_DDEF()

    xr = collect(range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length = N))
    Grid = repeat(mean(X; dims=1), N)
    Grid[:, ix] .= xr

    y_trend = ARTS_Predict_DDEF(Model, Grid)

    t_line = scatter(; x=xr, y=y_trend, mode="lines", name="<b>Model Estimator</b>",
        line=attr(color=ARTS_Theme_DDEC.SHAMAG, dash="solid", width=ARTS_WidthModelLine_DDEC))

    t_data = scatter(; x=X[:, ix], y=Y_Real, mode="markers", name="<b>Observed Data</b>",
        marker=attr(color=ARTS_Theme_DDEC.TONCYA, size=ARTS_SizeDataMarker_DDEC, opacity=0.85, line=attr(width=1, color=ARTS_Theme_DDEC.PURBLA)))

    layout = ARTS_BuildBaseLayout_DDEF("Trend: $(Lbls[1])")
    ARTS_SetAxisTitles_DDEF!(layout, Lbls[1], OutName)
    
    return Plot([t_line, t_data], layout)
end

# ------------------------------------------------------------------------------
# SECTION 14: DESIRABILITY SPACE EXPLORER
# ------------------------------------------------------------------------------

"""
    ARTS_RenderDesignSpace_DDEF(Models, Goals, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame=DataFrame(); ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[]) -> PlotlyJS.Plot
Render multi-slice 3D desirability space surfaces representing composite multi-criteria optimisation feasibility.
Displays simultaneous horizontal planar slices through the third factor dimension with optional leader formulation markers.

# Arguments
- `Models`: Vector of active regression model dictionaries.
- `Goals`: Multi-response optimisation goal specifications.
- `X::AbstractMatrix{Float64}`: Experimental factor coordinate matrix.
- `Idx::AbstractVector{<:Integer}`: Indices of factors chosen for x and y planar projection.
- `Lbls::AbstractVector{<:AbstractString}`: Factor axis labels.
- `Leaders_DF::AbstractDataFrame`: Formulations table containing candidate leader runs (default: empty).

# Keywords
- `ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}`: Optional radiochemical decay penalty modifiers applied to composite desirability (default: empty).

# Returns
- `PlotlyJS.Plot`: 3D multi-surface desirability exploration figure.
"""
function ARTS_RenderDesignSpace_DDEF(Models, Goals, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame=DataFrame();
    ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[])
    return ARTS_Draw_DDEF(ARTS_PlotDesignSpace_DDES(), Models, Goals, X, Idx, Lbls, Leaders_DF; ModifiersDCYP=ModifiersDCYP)
end

"""
    ARTS_RenderCandidates_DDEF(Models, Goals, X::AbstractMatrix{Float64}, Idx::Union{AbstractVector{<:Integer}, Tuple{Integer, Integer}}, Lbls::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame=DataFrame(); ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[]) -> Tuple{PlotlyJS.Plot, String}
Render threshold-masked 3D candidate space slices highlighting factor regions that satisfy minimum composite desirability criteria.
Applies smooth alpha-gradient fragment masking and overlays leader formulation markers across horizontal planar slices.

# Arguments
- `Models`: Vector of active regression model dictionaries.
- `Goals`: Multi-response optimisation goal specifications.
- `X::AbstractMatrix{Float64}`: Experimental factor coordinate matrix.
- `Idx::Union{AbstractVector{<:Integer}, Tuple{Integer, Integer}}`: Pair of column indices for x and y planar projection.
- `Lbls::AbstractVector{<:AbstractString}`: Factor axis labels.
- `Leaders_DF::AbstractDataFrame`: Formulations table containing candidate leader runs (default: empty).

# Keywords
- `ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}`: Optional radiochemical decay penalty modifiers applied to composite desirability (default: empty).

# Returns
- `Tuple{PlotlyJS.Plot, String}`: Pair containing the 3D candidate space figure and the formatted volume occupancy percentage string.
"""
function ARTS_RenderCandidates_DDEF(Models, Goals, X::AbstractMatrix{Float64}, Idx::Union{AbstractVector{<:Integer}, Tuple{Integer, Integer}}, Lbls::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame=DataFrame();
    ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[])
    return ARTS_Draw_DDEF(ARTS_PlotCandidates_DDES(), Models, Goals, X, Idx, Lbls, Leaders_DF; ModifiersDCYP=ModifiersDCYP)
end

# Internal Implementation Redirect for Space/Candidates
function ARTS_Draw_DDEF(::ARTS_PlotDesignSpace_DDES, Models, Goals, X, Idx, Lbls, Leaders_DF;
    ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[], SliceData=nothing)
    p, _ = ARTS_RenderDesignSpaceInternal_DDEF(Models, Goals, X, Idx, Lbls, Leaders_DF, false; ModifiersDCYP=ModifiersDCYP, SliceData=SliceData)
    return p
end

function ARTS_Draw_DDEF(::ARTS_PlotCandidates_DDES, Models, Goals, X, Idx, Lbls, Leaders_DF;
    ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[], SliceData=nothing)
    return ARTS_RenderDesignSpaceInternal_DDEF(Models, Goals, X, Idx, Lbls, Leaders_DF, true; ModifiersDCYP=ModifiersDCYP, SliceData=SliceData)
end

function ARTS_AddLeaderMarkers_DDEF!(traces::Vector{GenericTrace}, Leaders_DF::AbstractDataFrame, ix::Int, iy::Int, iz::Int)
    th = ARTS_Theme_DDEC
    
    top_x, top_y, top_z, top_txt = Float64[], Float64[], Float64[], String[]
    var_x, var_y, var_z, var_txt = Float64[], Float64[], Float64[], String[]
    
    if nrow(Leaders_DF) > 0
        in_cols = filter(n -> startswith(uppercase(string(n)), uppercase(C.PRE_VAR)), names(Leaders_DF))
        for r in 1:nrow(Leaders_DF)
            id = hasproperty(Leaders_DF, :ID) ? string(Leaders_DF[r, :ID]) : "L$r"
            is_top = occursin("TOP", uppercase(id))
            x_val = Float64(Leaders_DF[r, Symbol(in_cols[ix])])
            y_val = Float64(Leaders_DF[r, Symbol(in_cols[iy])])
            z_val = iz > 0 ? Float64(Leaders_DF[r, Symbol(in_cols[iz])]) : 0.0
            
            if is_top
                push!(top_x, x_val); push!(top_y, y_val); push!(top_z, z_val); push!(top_txt, id)
            else
                push!(var_x, x_val); push!(var_y, y_val); push!(var_z, z_val); push!(var_txt, id)
            end
        end
    end
    
    push!(traces, scatter3d(;
        x = isempty(top_x) ? [nothing] : top_x,
        y = isempty(top_y) ? [nothing] : top_y,
        z = isempty(top_z) ? [nothing] : top_z,
        mode = "markers",
        name = "<b>Leaders</b>",
        text = isempty(top_txt) ? [""] : top_txt,
        hovertemplate = isempty(top_x) ? nothing : "<b>%{text}</b><br>X: %{x:.2f}<br>Y: %{y:.2f}<br>Z: %{z:.2f}<extra></extra>",
        marker = attr(
            size = ARTS_SizeLeaderMarker_DDEC,
            color = th.HUERED,
            symbol = "diamond",
            line = attr(color = th.PURBLA, width = 1)
        ),
        showlegend = true
    ))
    
    push!(traces, scatter3d(;
        x = isempty(var_x) ? [nothing] : var_x,
        y = isempty(var_y) ? [nothing] : var_y,
        z = isempty(var_z) ? [nothing] : var_z,
        mode = "markers",
        name = "<b>Variables</b>",
        text = isempty(var_txt) ? [""] : var_txt,
        hovertemplate = isempty(var_x) ? nothing : "<b>%{text}</b><br>X: %{x:.2f}<br>Y: %{y:.2f}<br>Z: %{z:.2f}<extra></extra>",
        marker = attr(
            size = ARTS_SizeLeaderMarker_DDEC,
            color = th.PURBLA,
            symbol = "diamond",
            line = attr(color = th.PURBLA, width = 1)
        ),
        showlegend = true
    ))
end

"""
    ARTS_ComputeSliceSpace_DDEF(Models, Goals, X, Idx; ModifiersDCYP=...)
Evaluate desirability surfaces across the three orthogonal z-slices so decision-space and candidate-space visualisations share a single grid pass.
"""
function ARTS_ComputeSliceSpace_DDEF(Models, Goals, X::AbstractMatrix{Float64}, Idx::Union{AbstractVector{<:Integer}, Tuple{Integer, Integer}};
    ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[])
    ix, iy = Idx[1], Idx[2]
    N = ARTS_GetDynamicGridN_DDEF()
    iz = first(setdiff(1:3, Idx))
    
    x1, x2 = range(minimum(view(X,:,ix)), maximum(view(X,:,ix)), length=N), range(minimum(view(X,:,iy)), maximum(view(X,:,iy)), length=N)
    col_ref = vec(mean(X; dims=1))
    z_vals = [minimum(view(X,:,iz)), col_ref[iz], maximum(view(X,:,iz))]

    all_scores = Vector{AbstractMatrix{Float64}}(undef, 3)
    parsed_goals = [CORE_ExtractGoal_DDEF(m <= length(Goals) ? Goals[m] : get(Models[m], "Goal", Dict{String, Any}())) for m in eachindex(Models)]
    k_models     = length(Models)

    # Allocated once, reused for all 3 slices
    Grid_buf  = repeat(reshape(col_ref, 1, :), N * N)
    Xd_buf    = Matrix{Float64}(undef, N * N, 10)
    Preds_buf = Matrix{Float64}(undef, N * N, k_models)

    for (s, zv) in enumerate(z_vals)
        @inbounds for (k_idx, pt) in enumerate(Iterators.product(x1, x2))
            Grid_buf[k_idx, ix], Grid_buf[k_idx, iy], Grid_buf[k_idx, iz] = pt[1], pt[2], zv
        end
        for (m, model) in enumerate(Models)
            Preds_buf[:, m] .= ARTS_Predict_DDEF(model, Grid_buf, Xd_buf)
        end
        scores_vec = CORE_CalcDesirability_DDEF(Preds_buf, parsed_goals, Grid_buf, ModifiersDCYP)
        all_scores[s] = Matrix(reshape(scores_vec, N, N)')
    end

    all_flat = vcat([vec(s) for s in all_scores]...)
    valid_sc = filter(v -> v > 1e-6, all_flat)
    thresh = isempty(valid_sc) ? 1.0 : quantile(valid_sc, 0.75)
    pct_str = @sprintf("%.2f", (length(valid_sc) * 0.25 / (3*N*N)) * 100.0)
    return (x1, x2, z_vals, all_scores, thresh, pct_str, ix, iy, iz)
end

function ARTS_RenderDesignSpaceInternal_DDEF(Models, Goals, X::AbstractMatrix{Float64}, Idx::Union{AbstractVector{<:Integer}, Tuple{Integer, Integer}}, Lbls::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame, is_candidate::Bool;
    ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[], SliceData=nothing)
    x1, x2, z_vals, all_scores, thresh, pct_str, ix, iy, iz = isnothing(SliceData) ?
        ARTS_ComputeSliceSpace_DDEF(Models, Goals, X, Idx; ModifiersDCYP=ModifiersDCYP) : SliceData
    N = length(x1)
    traces = GenericTrace[]

    for (s, zv) in enumerate(z_vals)
        Masked = is_candidate ? ARTS_SmoothMatrix_DDEF(all_scores[s], 2) : all_scores[s]
        alpha = (s == 2) ? (is_candidate ? 0.85 : 0.70) : (is_candidate ? 0.35 : 0.20)
        
        push!(traces, surface(; x=collect(x1), y=collect(x2), z=fill(zv, N, N), surfacecolor=Masked,
            colorscale = is_candidate ? ARTS_GenAlphaViridis_DDEF(thresh) : ARTS_ViridisScale_DDEC,
            cmin=0.0, cmax=1.0, opacity=alpha, showscale=(s==1), showlegend=false,
            colorbar=attr(orientation="h", x=0.5, xanchor="center", y=ARTS_YCenterCard_DDEC, yanchor="middle", thickness=ARTS_ThickColourbar_DDEC, len=ARTS_LenColourbar_DDEC, tickfont=attr(size=ARTS_SizeColourbarTick_DDEC, weight="bold")),
            contours=attr(z=attr(show=true, usecolormap=true, width=3))))
    end

    ARTS_AddLeaderMarkers_DDEF!(traces, Leaders_DF, ix, iy, iz)
    title_main = is_candidate ? "Candidate Space ($pct_str%)" : "Decision Space"
    layout = ARTS_BuildBaseLayout_DDEF(title_main)
    layout[:scene] = attr(
        xaxis=attr(title=attr(text=Lbls[1], font=attr(size=ARTS_SizeAxisTitle3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
                   tickfont=attr(size=ARTS_SizeAxisTick3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
        yaxis=attr(title=attr(text=Lbls[2], font=attr(size=ARTS_SizeAxisTitle3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
                   tickfont=attr(size=ARTS_SizeAxisTick3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
        zaxis=attr(title=attr(text=Lbls[3], font=attr(size=ARTS_SizeAxisTitle3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
                   tickfont=attr(size=ARTS_SizeAxisTick3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
        camera=attr(eye=ARTS_CameraEye3D_DDEC, center=ARTS_CameraCenter3D_DDEC), aspectmode="cube", dragmode="turntable", uirevision=true)
    layout[:margin] = attr(l=ARTS_MarginLeft_DDEC, r=ARTS_MarginRight_DDEC, t=ARTS_MarginTop_DDEC, b=ARTS_MarginBottom_DDEC)
    layout[:xaxis] = attr(visible=false, showline=false, showgrid=false, zeroline=false, showticklabels=false)
    layout[:yaxis] = attr(visible=false, showline=false, showgrid=false, zeroline=false, showticklabels=false)
    
    ARTS_AddGapCard_DDEF!(layout)
    layout[:showlegend] = true
    layout[:legend] = attr(
        orientation = "h",
        yanchor = "middle",
        y = ARTS_YCenterGap_DDEC,
        xanchor = "center",
        x = 0.5,
        bgcolor = "transparent",
        bordercolor = "transparent",
        borderwidth = 0,
        font = attr(
            family = ARTS_Theme_DDEC.FONT,
            size = ARTS_SizeGapCardText_DDEC,
            color = ARTS_Theme_DDEC.PURBLA,
            weight = "bold"
        ),
        tracegroupgap = 20
    )
    return Plot(traces, layout), pct_str
end

# ------------------------------------------------------------------------------
# SECTION 15: 3D OPTIMAL ZONE & DESIGN SPACE EVOLUTION RENDERERS
# ------------------------------------------------------------------------------

"""
    ARTS_RenderFeasibleSpace_DDEF(Models, Goals, X::AbstractMatrix{Float64}, InNames::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame=DataFrame(); ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[]) -> Tuple{PlotlyJS.Plot, String}
Render a 3D volumetric shell enclosing factor regions that simultaneously satisfy all unweighted response specification limits.
Discretises the experimental bounding box into a 3D coordinate lattice to delineate the unconstrained feasible operating domain.

# Arguments
- `Models`: Vector of active fitted regression model dictionaries.
- `Goals`: Multi-response optimisation goal specifications.
- `X::AbstractMatrix{Float64}`: Experimental factor coordinate matrix.
- `InNames::AbstractVector{<:AbstractString}`: Factor dimension names.
- `Leaders_DF::AbstractDataFrame`: Formulations table containing candidate leader runs (default: empty).

# Keywords
- `ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}`: Optional radiochemical decay penalty modifiers applied to composite desirability (default: empty).

# Returns
- `Tuple{PlotlyJS.Plot, String}`: Pair containing the 3D volume figure and the feasible space volume occupancy percentage string.
"""
function ARTS_RenderFeasibleSpace_DDEF(Models, Goals, X::AbstractMatrix{Float64}, InNames::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame=DataFrame();
    ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[])
    return ARTS_Draw_DDEF(ARTS_PlotFeasibleSpace_DDES(), Models, Goals, X, InNames, Leaders_DF; ModifiersDCYP=ModifiersDCYP)
end

"""
    ARTS_RenderOptimalZone_DDEF(Models, Goals, X::AbstractMatrix{Float64}, InNames::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame=DataFrame(); ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[]) -> Tuple{PlotlyJS.Plot, String}
Render a 3D volumetric iso-surface enclosing factor regions meeting composite multi-criteria desirability thresholds.
Discretises the experimental factor space into a 3D coordinate lattice and identifies contiguous high-desirability zones evaluating weighted multi-response trade-offs.

# Arguments
- `Models`: Vector of active fitted regression model dictionaries.
- `Goals`: Multi-response optimisation goal specifications.
- `X::AbstractMatrix{Float64}`: Experimental factor coordinate matrix.
- `InNames::AbstractVector{<:AbstractString}`: Factor dimension names.
- `Leaders_DF::AbstractDataFrame`: Formulations table containing candidate leader runs (default: empty).

# Keywords
- `ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}`: Optional radiochemical decay penalty modifiers applied to composite desirability (default: empty).

# Returns
- `Tuple{PlotlyJS.Plot, String}`: Pair containing the 3D volume figure and the optimal zone volume occupancy percentage string.
"""
function ARTS_RenderOptimalZone_DDEF(Models, Goals, X::AbstractMatrix{Float64}, InNames::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame=DataFrame();
    ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[])
    return ARTS_Draw_DDEF(ARTS_PlotOptimalZone_DDES(), Models, Goals, X, InNames, Leaders_DF; ModifiersDCYP=ModifiersDCYP)
end

"""
    ARTS_RenderSweetSpot_DDEF(Models, Goals, X::AbstractMatrix{Float64}, InNames::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame=DataFrame(); ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[]) -> Tuple{PlotlyJS.Plot, String}
Render a 3D volumetric sweet spot representing the 95% threshold of peak composite desirability.
Isolates the ultra-optimal core factor space where multi-response trade-offs attain elite desirability performance.

# Arguments
- `Models`: Vector of active fitted regression model dictionaries.
- `Goals`: Multi-response optimisation goal specifications.
- `X::AbstractMatrix{Float64}`: Experimental factor coordinate matrix.
- `InNames::AbstractVector{<:AbstractString}`: Factor dimension names.
- `Leaders_DF::AbstractDataFrame`: Formulations table containing candidate leader runs (default: empty).

# Keywords
- `ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}`: Optional radiochemical decay penalty modifiers applied to composite desirability (default: empty).

# Returns
- `Tuple{PlotlyJS.Plot, String}`: Pair containing the 3D volume figure and the sweet spot volume occupancy percentage string.
"""
function ARTS_RenderSweetSpot_DDEF(Models, Goals, X::AbstractMatrix{Float64}, InNames::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame=DataFrame();
    ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[])
    return ARTS_Draw_DDEF(ARTS_PlotSweetSpot_DDES(), Models, Goals, X, InNames, Leaders_DF; ModifiersDCYP=ModifiersDCYP)
end

"""
    ARTS_ComputeVolumeGrid_DDEF(Models, Goals, X)
Build the shared 3D experimental lattice and evaluate response predictions once for FeasibleSpace, OptimalZone, and SweetSpot plots.
"""
function ARTS_ComputeVolumeGrid_DDEF(Models, Goals, X::AbstractMatrix{Float64})
    N = ARTS_DefaultVolumeGridN_DDEC
    ranges = [range(minimum(view(X, :, i)), maximum(view(X, :, i)); length=N) for i in 1:3]
    Grid = Matrix{Float64}(undef, N^3, 3)
    idx = 1
    @inbounds for (x, y, z) in Iterators.product(ranges...)
        Grid[idx, 1], Grid[idx, 2], Grid[idx, 3] = x, y, z
        idx += 1
    end

    n_pts = size(Grid, 1)
    k_models = length(Models)
    parsed_goals = [CORE_ExtractGoal_DDEF(m <= length(Goals) ? Goals[m] : get(Models[m], "Goal", Dict{String, Any}())) for m in 1:k_models]
    Preds = Matrix{Float64}(undef, n_pts, k_models)
    Xd_buf = Matrix{Float64}(undef, n_pts, 10)
    for (m, model) in enumerate(Models)
        Preds[:, m] .= ARTS_Predict_DDEF(model, Grid, Xd_buf)
    end
    return (Grid, Preds, parsed_goals)
end

function ARTS_Draw_DDEF(
    plot_type::Union{ARTS_PlotFeasibleSpace_DDES, ARTS_PlotOptimalZone_DDES, ARTS_PlotSweetSpot_DDES},
    Models, Goals, X::AbstractMatrix{Float64}, InNames::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame;
    ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[], VolGrid=nothing, Scores=nothing
)
    is_feasible = plot_type isa ARTS_PlotFeasibleSpace_DDES
    Grid, Preds, parsed_goals = isnothing(VolGrid) ? ARTS_ComputeVolumeGrid_DDEF(Models, Goals, X) : VolGrid
    sc_vec = isnothing(Scores) ? CORE_CalcDesirability_DDEF(Preds, parsed_goals, Grid, ModifiersDCYP; Weighted=!is_feasible) : Scores
    max_sc = isempty(sc_vec) ? 0.0 : maximum(sc_vec)

    title_prefix, thresh, opacity = if is_feasible
        ("Feasible Space", max_sc > 0.05 ? 0.05 : (max_sc * 0.5), 0.28)
    elseif plot_type isa ARTS_PlotOptimalZone_DDES
        ("Optimal Zone", max_sc > 1e-4 ? (max_sc * 0.90) : 0.90, 0.3)
    else
        ("Sweet Spot", max_sc > 1e-4 ? (max_sc * 0.95) : 0.95, 0.35)
    end
    pct_str = @sprintf("%.2f", (count(>=(thresh), sc_vec) / length(sc_vec)) * 100.0)

    trace = @views volume(; x=Grid[:, 1], y=Grid[:, 2], z=Grid[:, 3], value=sc_vec, isomin=thresh, isomax=1.0,
        opacity=opacity, surface_count=5, colorscale=ARTS_ViridisScale_DDEC, cmin=0.0, cmax=1.0, showlegend=false,
        colorbar=attr(orientation="h", x=0.5, xanchor="center", y=ARTS_YCenterCard_DDEC, yanchor="middle", thickness=ARTS_ThickColourbar_DDEC, len=ARTS_LenColourbar_DDEC, tickfont=attr(size=ARTS_SizeColourbarTick_DDEC, weight="bold")))

    layout = ARTS_BuildBaseLayout_DDEF("$title_prefix ($pct_str%)")
    layout[:scene] = attr(
        xaxis=attr(title=attr(text=InNames[1], font=attr(size=ARTS_SizeAxisTitle3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
                   tickfont=attr(size=ARTS_SizeAxisTick3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
        yaxis=attr(title=attr(text=InNames[2], font=attr(size=ARTS_SizeAxisTitle3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
                   tickfont=attr(size=ARTS_SizeAxisTick3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
        zaxis=attr(title=attr(text=InNames[3], font=attr(size=ARTS_SizeAxisTitle3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
                   tickfont=attr(size=ARTS_SizeAxisTick3D_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG)),
        camera=attr(eye=ARTS_CameraEye3D_DDEC, center=ARTS_CameraCenter3D_DDEC), aspectmode="cube", dragmode="turntable", uirevision=true)
    layout[:margin] = attr(l=ARTS_MarginLeft_DDEC, r=ARTS_MarginRight_DDEC, t=ARTS_MarginTop_DDEC, b=ARTS_MarginBottom_DDEC)
    layout[:xaxis] = attr(visible=false, showline=false, showgrid=false, zeroline=false, showticklabels=false)
    layout[:yaxis] = attr(visible=false, showline=false, showgrid=false, zeroline=false, showticklabels=false)
    ARTS_AddGapCard_DDEF!(layout)
    layout[:showlegend] = true
    layout[:legend] = attr(
        orientation = "h",
        yanchor = "middle",
        y = ARTS_YCenterGap_DDEC,
        xanchor = "center",
        x = 0.5,
        bgcolor = "transparent",
        bordercolor = "transparent",
        borderwidth = 0,
        font = attr(
            family = ARTS_Theme_DDEC.FONT,
            size = ARTS_SizeGapCardText_DDEC,
            color = ARTS_Theme_DDEC.PURBLA,
            weight = "bold"
        ),
        tracegroupgap = 20
    )

    traces = GenericTrace[trace]
    ARTS_AddLeaderMarkers_DDEF!(traces, Leaders_DF, 1, 2, 3)

    return Plot(traces, layout), pct_str
end

# ------------------------------------------------------------------------------
# SECTION 16: INTERACTION LANDSCAPE HEATMAP
# ------------------------------------------------------------------------------

"""
    ARTS_RenderInteractionMatrix_DDEF(Model::AbstractDict, InNames::AbstractVector{<:AbstractString}, OutName::AbstractString, X::Union{AbstractMatrix{Float64}, Nothing}=nothing) -> PlotlyJS.Plot
Render an interaction coefficient heatmap displaying pairwise synergy and antagonism between experimental factors.
Extracts off-diagonal second-order model coefficients and normalises them to evaluate relative coupling magnitude.

# Arguments
- `Model::AbstractDict`: Fitted quadratic regression model dictionary.
- `InNames::AbstractVector{<:AbstractString}`: Factor component labels.
- `OutName::AbstractString`: Response variable name.
- `X::Union{AbstractMatrix{Float64}, Nothing}`: Optional experimental factor matrix used to scale physical coefficients by factor half-spans for unit invariance (default: `nothing`).

# Returns
- `PlotlyJS.Plot`: Heatmap figure indicating interaction magnitudes and directions.
"""
function ARTS_RenderInteractionMatrix_DDEF(Model::AbstractDict, InNames::AbstractVector{<:AbstractString}, OutName::AbstractString, X::Union{AbstractMatrix{Float64}, Nothing}=nothing)
    return ARTS_Draw_DDEF(ARTS_PlotInteractionMatrix_DDES(), Model, InNames, OutName, X)
end

function ARTS_Draw_DDEF(::ARTS_PlotInteractionMatrix_DDES, Model::AbstractDict, InNames::AbstractVector{<:AbstractString}, OutName::AbstractString, X::Union{AbstractMatrix{Float64}, Nothing}=nothing)
    # Use Multiple Dispatch to resolve matrix calculation based on model type
    m_type::CORE_AbstractModelType_DDET = CORE_GetModelType_DDEF(string(get(Model, "ModelType", "quadratic")))
    coefs = get(Model, "Coefs", Float64[])

    M = if X !== nothing && size(X, 2) >= 3 && m_type isa CORE_ModelQuadratic_DDES && length(coefs) >= 10
        # Scale physical quadratic/interaction terms by factor half-spans for unit invariance.
        M_raw = ARTS_GetInteractionMatrix_DDEF(m_type, coefs)
        deltas = [max((maximum(view(X, :, i)) - minimum(view(X, :, i))) / 2.0, 1e-12) for i in 1:3]
        for i in 1:3, j in 1:3
            M_raw[i, j] *= deltas[i] * deltas[j]
        end
        M_raw
    else
        t_stats = get(Model, "t_Stats", Float64[])
        if m_type isa CORE_ModelQuadratic_DDES && length(t_stats) >= 10 && all(isfinite, @view(t_stats[5:10]))
            ARTS_GetInteractionMatrix_DDEF(m_type, t_stats)
        else
            ARTS_GetInteractionMatrix_DDEF(m_type, coefs)
        end
    end

    max_abs = max(1e-9, maximum(abs.(M)))
    M_norm = M ./ max_abs

    InNames_bold = ["<b>$n</b>" for n in InNames]
    trace = heatmap(; z=M_norm, x=InNames_bold, y=InNames_bold, zmin=-1.0, zmax=1.0, zmid=0.0,
        colorscale=ARTS_BipolarScale_DDEC,
        colorbar=attr(
            orientation="h", x=0.5, xanchor="center", y=ARTS_YCenterCard_DDEC, yanchor="middle", 
            thickness=ARTS_ThickColourbar_DDEC, len=ARTS_LenColourbar_DDEC, tickfont=attr(size=ARTS_SizeColourbarTick_DDEC, weight="bold")
        ),
        hovertemplate="Factor A: %{x}<br>Factor B: %{y}<br>Impact: %{z:.3f}<extra></extra>")
    
    layout = ARTS_BuildBaseLayout_DDEF("Interaction Matrix: $OutName")
    layout[:yaxis][:tickangle] = ARTS_AngleIntMatrixTick_DDEC
    layout[:annotations] = [
        attr(
            x=InNames_bold[j], y=InNames_bold[i], xref="x", yref="y",
            text="<b>$(ARTS_FormatSigned_DDEF(M_norm[i, j]))</b>",
            showarrow=false,
            font=attr(
                size=ARTS_SizeContourText_DDEC,
                family=ARTS_Theme_DDEC.FONT,
                color=abs(M_norm[i, j]) >= 0.5 ? ARTS_Theme_DDEC.PURWHI : ARTS_Theme_DDEC.PURBLA,
                weight="bold"
            )
        ) for i in axes(M_norm, 1), j in axes(M_norm, 2)
    ] |> vec
    
    return Plot(trace, layout)
end

# Internal Multiple Dispatch Gateways for Interaction Landscapes
function ARTS_GetInteractionMatrix_DDEF(::CORE_ModelQuadratic_DDES, B::AbstractVector)::Matrix{Float64}
    M = zeros(3, 3)
    # Map Standard Quadratic: 1(Int), 2,3,4(Lin), 5,6,7(Inter), 8,9,10(Quad)
    if length(B) >= 10
        M[1,1], M[2,2], M[3,3] = B[8], B[9], B[10]
        M[1,2] = M[2,1] = B[5]; M[1,3] = M[3,1] = B[6]; M[2,3] = M[3,2] = B[7]
    end
    return M
end

ARTS_GetInteractionMatrix_DDEF(::CORE_ModelLinear_DDES, B::AbstractVector) = zeros(3, 3)

# ------------------------------------------------------------------------------
# SECTION 17: DIAGNOSTIC PLOTS
# ------------------------------------------------------------------------------

"""
    ARTS_RenderQQ_DDEF(Residuals::AbstractVector{Float64}, OutName::AbstractString) -> PlotlyJS.Plot
Render a normal probability Quantile-Quantile (Q-Q) diagnostic plot for model regression residuals.
Compares standardised residuals against theoretical normal distribution quantiles to verify error normality.

# Arguments
- `Residuals::AbstractVector{Float64}`: Raw regression residuals (`Y_observed - Y_predicted`).
- `OutName::AbstractString`: Response variable name.

# Returns
- `PlotlyJS.Plot`: Diagnostic Q-Q plot with theoretical reference line.
"""
function ARTS_RenderQQ_DDEF(Residuals::AbstractVector{Float64}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotQQ_DDES(), Residuals, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotQQ_DDES, Residuals::AbstractVector{Float64}, OutName::AbstractString)
    n = length(Residuals)
    z_res = (sort(Residuals) .- mean(Residuals)) ./ std(Residuals)
    theoretical = quantile.(Normal(0, 1), [(i - 0.5) / n for i in 1:n])

    t_pts = scatter(; x=theoretical, y=z_res, mode="markers", name="<b>Residuals</b>",
        marker=attr(color=ARTS_Theme_DDEC.TONCYA, size=ARTS_SizeDataMarker_DDEC, opacity=0.85, line=attr(width=1, color=ARTS_Theme_DDEC.PURBLA)))
    
    lims = [minimum([theoretical; z_res]), maximum([theoretical; z_res])]
    t_line = scatter(; x=lims, y=lims, mode="lines", name="<b>Normal Distribution</b>",
        line=attr(color=ARTS_Theme_DDEC.DARHIG, width=ARTS_WidthLimitLine_DDEC, dash="dash"))

    layout = ARTS_BuildBaseLayout_DDEF("Q-Q: $OutName")
    ARTS_SetAxisTitles_DDEF!(layout, "Theoretical Quantiles", "Standardised Residuals")
    return Plot([t_line, t_pts], layout)
end

"""
    ARTS_RenderResiduals_DDEF(Y_Pred::AbstractVector{Float64}, Residuals::AbstractVector{Float64}, OutName::AbstractString) -> PlotlyJS.Plot
Render a residuals versus predicted response values diagnostic plot to evaluate variance homogeneity.
Displays error dispersion around a zero-deviation baseline to diagnose heteroscedasticity and non-linear drift.

# Arguments
- `Y_Pred::AbstractVector{Float64}`: Model-estimated response predictions.
- `Residuals::AbstractVector{Float64}`: Model residual errors.
- `OutName::AbstractString`: Response variable name.

# Returns
- `PlotlyJS.Plot`: Scatter plot formatted for residual variance analysis.
"""
function ARTS_RenderResiduals_DDEF(Y_Pred::AbstractVector{Float64}, Residuals::AbstractVector{Float64}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotResiduals_DDES(), Y_Pred, Residuals, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotResiduals_DDES, Y_Pred::AbstractVector{Float64}, Residuals::AbstractVector{Float64}, OutName::AbstractString)
    t_pts = scatter(; x=Y_Pred, y=Residuals, mode="markers", name="<b>Residuals</b>",
        marker=attr(color=ARTS_Theme_DDEC.TONCYA, size=ARTS_SizeDataMarker_DDEC, opacity=0.85, line=attr(width=1, color=ARTS_Theme_DDEC.PURBLA)))

    t_zero = scatter(; x=[minimum(Y_Pred), maximum(Y_Pred)], y=[0, 0], mode="lines", name="<b>Zero Error (e = 0)</b>", showlegend=true,
        line=attr(color=ARTS_Theme_DDEC.DARHIG, width=ARTS_WidthLimitLine_DDEC, dash="dash"))

    layout = ARTS_BuildBaseLayout_DDEF("Errors: $OutName")
    ARTS_SetAxisTitles_DDEF!(layout, "Predicted Estimation", "Residual Error")
    return Plot([t_zero, t_pts], layout)
end

"""
    ARTS_RenderSensitivity_DDEF(Sens::AbstractVector{Float64}, InNames::AbstractVector{<:AbstractString}, OutName::AbstractString) -> PlotlyJS.Plot
Render a bar chart displaying fractional percentage contributions of experimental factors from local sensitivity analysis.
Normalises partial derivative gradient contributions to rank dominant drivers influencing the response surface.

# Arguments
- `Sens::AbstractVector{Float64}`: Fractional sensitivity values summing to 1.0.
- `InNames::AbstractVector{<:AbstractString}`: Factor labels.
- `OutName::AbstractString`: Response variable name.

# Returns
- `PlotlyJS.Plot`: Bar chart displaying relative factor influence percentages.
"""
function ARTS_RenderSensitivity_DDEF(Sens::AbstractVector{Float64}, InNames::AbstractVector{<:AbstractString}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotSensitivity_DDES(), Sens, InNames, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotSensitivity_DDES, Sens::AbstractVector{Float64}, InNames::AbstractVector{<:AbstractString}, OutName::AbstractString)
    max_s = isempty(Sens) ? 100.0 : maximum(Sens) * 100.0
    y_lim = min(100.0, ceil(max_s / 10.0) * 10.0 + 8.0)
    max_idx = isempty(Sens) ? 1 : argmax(Sens)
    bar_cols = [i == max_idx ? ARTS_Theme_DDEC.INFORG : ARTS_Theme_DDEC.SHABLU for i in eachindex(Sens)]
    trace = bar(; x=["<b>$nm</b>" for nm in InNames], y=Sens .* 100.0, text=["<b>$(@sprintf("%.1f%%", s * 100))</b>" for s in Sens], textposition="auto",
        showlegend=false,
        marker=attr(color=bar_cols, line=attr(width=ARTS_WidthFrame_DDEC, color=ARTS_Theme_DDEC.PURWHI)))

    layout = ARTS_BuildBaseLayout_DDEF("Factor Sensitivity: $OutName")
    ARTS_SetAxisTitles_DDEF!(layout, "Experimental Factor", "Contribution (%)")
    layout[:yaxis][:range] = [0, y_lim]
    layout[:showlegend] = false

    dom_fac = (isempty(InNames) || max_idx > length(InNames)) ? "N/A" : InNames[max_idx]
    dom_pct = isempty(Sens) ? "0.0%" : @sprintf("%.1f%%", Sens[max_idx] * 100)
    layout[:annotations] = [
        attr(
            xref="paper", yref="paper", x=0.5, y=ARTS_YCenterCard_DDEC,
            xanchor="center", yanchor="middle",
            text="Dominant Factor: <span style='color:$(ARTS_Theme_DDEC.INFORG);font-weight:700;'>$dom_fac ($dom_pct)</span>",
            showarrow=false,
            font=attr(size=ARTS_SizeInfoCardText_DDEC, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.PURBLA, weight="bold")
        )
    ]
    return Plot(trace, layout)
end

# ==============================================================================
# PART E: SYSTEM DISPATCH & ORCHESTRATION
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 18: PARALLEL VISUAL DISPATCH ORCHESTRATOR
# ------------------------------------------------------------------------------

"""
    ARTS_Render_DDEF(Models, X, Y, InNames, OutNames, Goals, R2s, Q2s, Opts, Leaders_DF::AbstractDataFrame=DataFrame(), Sens::AbstractVector=Vector{Vector{Float64}}[], Residuals::AbstractVector=Vector{Vector{Float64}}[]) -> Vector{Dict{String, Any}}
Execute the parallel visual rendering orchestrator generating publication-grade charts for all modelled responses.
Dispatches multi-threaded workers across Pareto charts, surface projections, residual diagnostics, and decision spaces.

# Arguments
- `Models`: Vector of regression model dictionaries.
- `X`: Factor coordinate data.
- `Y`: Response measurement data.
- `InNames`: Factor component labels.
- `OutNames`: Response variable labels.
- `Goals`: Multi-response optimisation specifications.
- `R2s`: Adjusted R² values for each response.
- `Q2s`: Cross-validated Q² values for each response.
- `Opts`: Rendering and pipeline options dictionary.
- `Leaders_DF`: Candidate leader records table (default: empty).
- `Sens`: Factor sensitivity vectors per response (default: empty).
- `Residuals`: Residual error vectors per response (default: empty).

# Returns
- `Vector{Dict{String, Any}}`: Collection of generated plot descriptors with type tags and Plotly figures.
"""
function ARTS_Render_DDEF(Models, X, Y, InNames, OutNames, Goals, R2s, Q2s, Opts,
    Leaders_DF::AbstractDataFrame=DataFrame(), Sens::AbstractVector=Vector{Vector{Float64}}[], Residuals::AbstractVector=Vector{Vector{Float64}}[])

    graphs, graphs_lock = Dict{String,Any}[], ReentrantLock()
    # Cleaner Error Reporting to prevent REPL overflows
    ARTS_SafeErrorLog_DDEF(tag, msg, e) = FAST_HandleCatch_DDEF(FAST_TierLogged_DDES(), e, "ARTS", tag, msg; MsgType="WARN", FullTrace=true)
    FAST_Log_DDEF("ARTS", "RENDER_INIT", "Parallel Visual Dispatch Initiated...", "WAIT")

    # Defensive conversion of JSON-deserialised or generic inputs
    X_f64 = ARTS_PrepareMatrix_DDEF(X)
    Y_f64 = ARTS_PrepareMatrix_DDEF(Y)
    InNames_str = ARTS_PrepareStringVector_DDEF(InNames)
    OutNames_str = ARTS_PrepareStringVector_DDEF(OutNames)
    R2s_f64 = ARTS_PrepareFloatVector_DDEF(R2s)
    Q2s_f64 = ARTS_PrepareFloatVector_DDEF(Q2s)
    Sens_f64 = ARTS_PrepareNestedVector_DDEF(Sens)
    Residuals_f64 = ARTS_PrepareNestedVector_DDEF(Residuals)

    Combos = ARTS_FactorPairs_DDEC
    tasks  = Task[]

    # ------------------------------------------------------------------------------
    # STAGED RENDERING ORCHESTRATOR (1-13 Scientific Order)
    # ------------------------------------------------------------------------------
    # Implementation of staged delivery to reduce initial feedback latency. 
    # Support for :Full, :Priority (1-5), :Deferred (6-13)
    Mode = get(Opts, "Mode", :Full) 
    
    # --- STAGE 1: PRIORITY GROUPS (1: Pareto, 2: Fit) ---
    if Mode == :Full || Mode == :Priority
        for m in eachindex(OutNames_str)
            Models[m]["Status"] != "OK" && continue
            name   = OutNames_str[m]
            y_pred = ARTS_Predict_DDEF(Models[m], X_f64)

            # [1] Pareto (QA)
            t1 = Threads.@spawn try
                p = ARTS_Draw_DDEF(ARTS_PlotPareto_DDES(), Models[m], name, R2s_f64[m], Q2s_f64[m])
                lock(graphs_lock) do
                    push!(graphs, Dict("Type"=>"Pareto", "Title"=>"Pareto: $name", "Plot"=>p, "OutputIdx"=>m, "SubIdx"=>0))
                end
            catch e; ARTS_SafeErrorLog_DDEF("ERR_P1_PARETO", "Pareto failed", e); end
            push!(tasks, t1)

            # [2] Model Fit (QA)
            t2 = Threads.@spawn try
                p = ARTS_Draw_DDEF(ARTS_PlotFit_DDES(), Y_f64[:, m], y_pred, name)
                lock(graphs_lock) do
                    push!(graphs, Dict("Type"=>"Fit", "Title"=>"Model Fit: $name", "Plot"=>p, "OutputIdx"=>m, "SubIdx"=>0))
                end
            catch e; ARTS_SafeErrorLog_DDEF("ERR_P2_FITAUDIT", "Fit failed", e); end
            push!(tasks, t2)
        end
        wait.(tasks)
        empty!(tasks)
        FAST_Log_DDEF("ARTS", "RENDER_POLL", "Packet 1 of 2 (Priority) completed.", "OK")
    end

    # --- STAGE 2: DEFERRED GROUPS (3-15: RESP, SURFACE, DIAG, SPACE) ---
    if Mode == :Full || Mode == :Deferred
        for m in eachindex(OutNames_str)
            Models[m]["Status"] != "OK" && continue
            name   = OutNames_str[m]
            y_pred = ARTS_Predict_DDEF(Models[m], X_f64)

            # [3] Response Trends (RESP)
            for v in 1:3
                tv = Threads.@spawn try
                    p = ARTS_Draw_DDEF(ARTS_PlotTrend_DDES(), Models[m], X_f64, Y_f64[:, m], [v], [InNames_str[v]], name)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type"=>"Trend", "Title"=>"Trend: $name ($(InNames_str[v]))", "Plot"=>p, "OutputIdx"=>m, "SubIdx"=>v))
                    end
                catch e; ARTS_SafeErrorLog_DDEF("ERR_P3_TREND", "Trend failed", e); end
                push!(tasks, tv)
            end

            # [4] Interaction Slices (RESP)
            for (s_idx, pair) in enumerate(ARTS_SlicePairs_DDEC)
                ts = Threads.@spawn try
                    lbls = [InNames_str[pair[1]], InNames_str[pair[2]]]
                    p = ARTS_Draw_DDEF(ARTS_PlotSlice_DDES(), Models[m], X_f64, [pair[1], pair[2]], lbls, name)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type"=>"Slice", "Title"=>"Interaction Slices: $name ($(lbls[1]) by $(lbls[2]))", "Plot"=>p, "OutputIdx"=>m, "SubIdx"=>s_idx))
                    end
                catch e; ARTS_SafeErrorLog_DDEF("ERR_P4_SLICE", "Slice failed", e); end
                push!(tasks, ts)
            end

            # [5] Interaction Matrix (RESP)
            t5 = Threads.@spawn try
                p = ARTS_Draw_DDEF(ARTS_PlotInteractionMatrix_DDES(), Models[m], InNames_str, name, X_f64)
                lock(graphs_lock) do
                    push!(graphs, Dict("Type"=>"IntMatrix", "Title"=>"Interaction Matrix: $name", "Plot"=>p, "OutputIdx"=>m, "SubIdx"=>0))
                end
            catch e; ARTS_SafeErrorLog_DDEF("ERR_P5_IMATRIX", "Interaction Matrix failed", e); end
            push!(tasks, t5)

            # [6 & 7] Surface & Contour (SURFACE)
            for (ix, c) in enumerate(Combos)
                tsury = Threads.@spawn try
                    lbls = [InNames_str[c[1]], InNames_str[c[2]]]
                    p1 = ARTS_Draw_DDEF(ARTS_PlotSurface_DDES(), Models[m], X_f64, [c[1], c[2]], lbls, name)
                    p2 = ARTS_Draw_DDEF(ARTS_PlotContour_DDES(), Models[m], X_f64, [c[1], c[2]], lbls, name)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type"=>"Surface", "Title"=>"Response Surface: $name ($(lbls[1])-$(lbls[2]))", "Plot"=>p1, "OutputIdx"=>m, "SubIdx"=>ix))
                        push!(graphs, Dict("Type"=>"Contour", "Title"=>"Contour: $name ($(lbls[1])-$(lbls[2]))", "Plot"=>p2, "OutputIdx"=>m, "SubIdx"=>ix))
                    end
                catch e; ARTS_SafeErrorLog_DDEF("ERR_P67_SURF", "Surface/Contour failed", e); end
                push!(tasks, tsury)
            end

            # [8, 9, 10] Diagnostics (QQ, Residuals, Sensitivity)
            t_diag = Threads.@spawn try
                if m <= length(Residuals_f64) && !isempty(Residuals_f64[m])
                    p_qq = ARTS_Draw_DDEF(ARTS_PlotQQ_DDES(), Residuals_f64[m], name)
                    p_res = ARTS_Draw_DDEF(ARTS_PlotResiduals_DDES(), y_pred, Residuals_f64[m], name)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type"=>"QQ", "Title"=>"Q-Q: $name", "Plot"=>p_qq, "OutputIdx"=>m, "SubIdx"=>0))
                        push!(graphs, Dict("Type"=>"Residuals", "Title"=>"Errors: $name", "Plot"=>p_res, "OutputIdx"=>m, "SubIdx"=>0))
                    end
                end
                if m <= length(Sens_f64) && !isempty(Sens_f64[m])
                    p_sens = ARTS_Draw_DDEF(ARTS_PlotSensitivity_DDES(), Sens_f64[m], InNames_str, name)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type"=>"Sensitivity", "Title"=>"Factor Sensitivity: $name", "Plot"=>p_sens, "OutputIdx"=>m, "SubIdx"=>0))
                    end
                end
            catch e; ARTS_SafeErrorLog_DDEF("ERR_P810_DIAG", "Diagnostics failed", e); end
            push!(tasks, t_diag)
        end

        # [11, 12, 13-15] Design Space & Candidates & 3-Stage Optimal Zone Evolution (SPACE - Composite Viz)
        t_space = Threads.@spawn try
            # Critical Sanity Check: Ensure all constituent models are successfully trained.
            # Composite desirability maps require a complete model portfolio.
            if all(m -> get(m, "Status", "FAIL") == "OK", Models)
                raw_mods = get(Opts, "ModifiersDCYP", CORE_ModifierDCYP_DDES[])
                mods_dcyp = raw_mods isa Vector{CORE_ModifierDCYP_DDES} ? raw_mods : CORE_ModifierDCYP_DDES[m for m in raw_mods if m isa CORE_ModifierDCYP_DDES]
                if get(Opts, "DesignSpace", true) && !isempty(Combos)
                    for (ix, c) in enumerate(Combos)
                        lbls = [InNames_str[c[1]], InNames_str[c[2]], InNames_str[first(setdiff(1:3, c))]]
                        slice_data = ARTS_ComputeSliceSpace_DDEF(Models, Goals, X_f64, [c[1], c[2]]; ModifiersDCYP=mods_dcyp)
                        p_sp = ARTS_Draw_DDEF(ARTS_PlotDesignSpace_DDES(), Models, Goals, X_f64, [c[1], c[2]], lbls, Leaders_DF; ModifiersDCYP=mods_dcyp, SliceData=slice_data)
                        p_ca, _ = ARTS_Draw_DDEF(ARTS_PlotCandidates_DDES(), Models, Goals, X_f64, [c[1], c[2]], lbls, Leaders_DF; ModifiersDCYP=mods_dcyp, SliceData=slice_data)
                        lock(graphs_lock) do
                            push!(graphs, Dict("Type"=>"DesignSpace", "Title"=>"Decision Space: $(lbls[1])-$(lbls[2])", "Plot"=>p_sp, "OutputIdx"=>length(OutNames_str)+1, "SubIdx"=>ix))
                            push!(graphs, Dict("Type"=>"Candidates", "Title"=>"Candidate Space: $(lbls[1])-$(lbls[2])", "Plot"=>p_ca, "OutputIdx"=>length(OutNames_str)+1, "SubIdx"=>ix))
                        end
                    end
                end
                if get(Opts, "OptimalZone", true)
                    vol_grid = ARTS_ComputeVolumeGrid_DDEF(Models, Goals, X_f64)
                    sc_unw   = CORE_CalcDesirability_DDEF(vol_grid[2], vol_grid[3], vol_grid[1], mods_dcyp; Weighted=false)
                    sc_wgt   = CORE_CalcDesirability_DDEF(vol_grid[2], vol_grid[3], vol_grid[1], mods_dcyp; Weighted=true)
                    p_fs, _  = ARTS_Draw_DDEF(ARTS_PlotFeasibleSpace_DDES(), Models, Goals, X_f64, InNames_str, Leaders_DF; ModifiersDCYP=mods_dcyp, VolGrid=vol_grid, Scores=sc_unw)
                    p_gz, _  = ARTS_Draw_DDEF(ARTS_PlotOptimalZone_DDES(),   Models, Goals, X_f64, InNames_str, Leaders_DF; ModifiersDCYP=mods_dcyp, VolGrid=vol_grid, Scores=sc_wgt)
                    p_cs, _  = ARTS_Draw_DDEF(ARTS_PlotSweetSpot_DDES(),     Models, Goals, X_f64, InNames_str, Leaders_DF; ModifiersDCYP=mods_dcyp, VolGrid=vol_grid, Scores=sc_wgt)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type"=>"FeasibleSpace", "Title"=>"Feasible Space", "Plot"=>p_fs, "OutputIdx"=>length(OutNames_str)+1, "SubIdx"=>0))
                        push!(graphs, Dict("Type"=>"OptimalZone",   "Title"=>"Optimal Zone",   "Plot"=>p_gz, "OutputIdx"=>length(OutNames_str)+1, "SubIdx"=>0))
                        push!(graphs, Dict("Type"=>"SweetSpot",     "Title"=>"Sweet Spot",     "Plot"=>p_cs, "OutputIdx"=>length(OutNames_str)+1, "SubIdx"=>0))
                    end
                end
            else
                FAST_Log_DDEF("ARTS", "RENDER_SKIP", "Composite visualisations bypassed due to training failure in one or more models.", "WARN")
            end
        catch e; ARTS_SafeErrorLog_DDEF("ERR_P1115_SPACE", "Space logic failed", e); end
        push!(tasks, t_space)

        wait.(tasks)
        FAST_Log_DDEF("ARTS", "RENDER_POLL", "Packet 2 of 2 (Deferred) completed.", "OK")
    end

    # 6. Results Ordering Protocol (Scientific Workflow Architecture)
    # 1-2: QA | 3-5: RESP | 6-10: DIAG & SURFACE | 11-15: SPACE EVOLUTION
    sort!(graphs, by = x -> (get(ARTS_PlotPriority_DDEC, x["Type"], 99), x["OutputIdx"], x["SubIdx"]))

    FAST_Log_DDEF("ARTS", "RENDER_COMPLETE", "Portfolio of $(length(graphs)) units ready | Mode: $Mode", length(graphs) > 0 ? "OK" : "WARN")
    return graphs
end

end