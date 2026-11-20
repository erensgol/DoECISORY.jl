# Novel Methodological Features

While classical experimental designs, Ordinary Least Squares (OLS) regression, and ANOVA procedures follow established literature (detailed in [Statistics](statistics.md) and [API Reference](api.md)), this section details the four **novel methodological features** introduced in **DoECISORY.jl**:

1. **Temporal Latency Adjustments:** Accounting for precursor preparation decay and post-reaction analytical measurement delays via half-life ($t_{1/2}$) kinetics.
2. **Decay-Coupled Yield Penalty (DCYP) & Regularisation:** Reconciling chemical conversion duration with continuous half-life loss.
3. **Candidate Pool Architecture:** Deriving a structured portfolio of operational compromises (unconstrained leaders, input conservation, and output specialisation) rather than forcing a single deterministic optimum.
4. **Interphase Knowledge Transfer (IPKT = ACTA + ASTM):** Sequentially transferring historical variance, contracting operational bounds, and transforming coordinates between successive experimental phases.

---

## 1. Temporal Latency Adjustments: Pre- and Post-Reaction Delays

In experiments involving radioisotopes or labile chemical compounds with a known half-life ($t_{1/2}$), elapsed time is an active physical variable that alters reagent mass and product yield. Precursor decay prior to reaction initiation and analytical latency following synthesis completion are managed via [`VISE_ApplyFRDecay_DDEF`](@ref) and [`MOLE_CalcRadioDecay_DDEF`](@ref):

* **Precursor Preparation Delay ($\Delta t_{\text{forw}}$):** The elapsed time between stock precursor calibration and addition to the reaction vessel at $t_0$.
* **Reaction Duration ($\Delta t_{\text{reaction}}$):** The controlled residence time in the reactor.
* **Measurement Latency ($\Delta t_{\text{reve}}$):** The post-reaction elapsed time between synthesis completion (or reaction quenching) and analytical quantification (e.g. HPLC, SPE, or dose calibrator).

### Exponential Half-Life Principle
Any decaying or labile species experiences depletion governed by its characteristic half-life ($t_{1/2}$):

```math
C(t) = C_0 \cdot \exp(-\lambda \cdot t) = C_0 \cdot 2^{-t / t_{1/2}}, \quad \text{where } \lambda = \frac{\ln 2}{t_{1/2}}
```

The half-life parameter $t_{1/2}$ operates across two primary scientific paradigms:

| Scientific Paradigm | Sensitive / Labile Entity | Physical Meaning of $t_{1/2}$ | Practical Laboratory Consequence |
| :--- | :--- | :--- | :--- |
| **Radiopharmaceutical Chemistry & Nuclear Medicine** | Short-lived radionuclide ($^{18}\text{F}$, $^{68}\text{Ga}$, $^{11}\text{C}$, $^{177}\text{Lu}$, etc.) | Physical isotope half-life (invariant nuclear constant) | Precursor radioactive decay pre-synthesis & analytical loss during HPLC waiting queue |
| **Labile Chemical Synthesis & Sensitive APIs** | Unstable reactive intermediate, photolabile or hydrolytically labile active molecule | Measured chemical degradation half-life under operating conditions | Active substrate loss prior to reactor charging & degradation during autosampler holding delay |

### 1.1. Forward Precursor Degradation Correction
Between reagent calibration and reaction initiation ($t_0$), elapsed preparation time ($\Delta t_{\text{forw}}$) leads to substrate loss.

If uncorrected, the nominal concentration or activity recorded in the design matrix introduces systematic bias into the regression model. The true starting quantity $C_{\text{actual}}$ is computed using `MOLE_CalcRadioDecay_DDEF` with `Reverse=false`:

```math
C_{\text{actual}} = C_{\text{nominal}} \cdot \exp(-\lambda \cdot \Delta t_{\text{forw}})
```

where:
* $C_{\text{nominal}}$ is the nominal precursor activity, mass, or concentration,
* $\lambda = \frac{\ln 2}{t_{1/2}}$ is the physical or experimental decay constant derived from the half-life ($t_{1/2}$),
* $\Delta t_{\text{forw}}$ is the preparation delay.

The training matrix column (`ACTUAL_<Precursor>`) is populated with these values, removing preparation latency variance from the model.

> [!NOTE] Primary Application: Radiopharmaceutical Benchmark
> In PET/SPECT radiotracer synthesis, elapsed time between radionuclide calibration and vessel charging ($\Delta t_{\text{forw}}$) leads to physical decay of radioactive atoms. For $^{18}\text{F}$ ($t_{1/2} = 109.77\,\text{min}$), a 15-minute bench delay causes an approximate $9.1\%$ loss of starting precursor activity. Correcting with `Reverse=false` reconstructs true starting radioactivity $A_{\text{actual}}$, removing benchtop timing noise from the design matrix.

> [!TIP] General Chemical Analogy: Labile Reagents & Reactive Intermediates
> In organic synthesis and pharmaceutical formulation, reactive intermediates (e.g. moisture-sensitive acid chlorides, diazo reagents, or short-lived free radicals) or labile active pharmaceutical ingredients (APIs) often have documented chemical degradation half-lives ($t_{1/2}$). By supplying this measured half-life to the engine, nominal amounts are adjusted to actual effective concentrations at the moment of addition.

### 1.2. Reverse Analyte Restoration (Reference State Alignment)
Following synthesis completion or reaction quenching, analytical chromatography and quantification involve variable delay ($\Delta t_{\text{reve}}$).

To compare product yields across all design runs on an equivalent baseline, raw measured quantity $C_{\text{measured}}$ is reconstructed back to the reference state (End of Synthesis - EOS, or quenching moment) using `MOLE_CalcRadioDecay_DDEF` with `Reverse=true`:

```math
C_{\text{ref}} = C_{\text{measured}} \cdot \exp(+\lambda \cdot \Delta t_{\text{reve}})
```

Updating the response column (`ACTUAL_<Output>`) isolates chemical conversion efficiency from post-synthesis analytical waiting times.

> [!NOTE] Radiopharmaceutical Benchmark
> Analytical HPLC, solid-phase extraction (SPE) purification, and dose calibration involve variable holding delays ($\Delta t_{\text{reve}}$) between sequential runs. Reconstructing measured activity back to EOS via `Reverse=true` decouples chemical radiolabelling yield from post-synthesis analytical waiting queues.

> [!TIP] General Analytical Chemistry Analogy
> When quantifying hydrolytically or photolytically unstable products, samples standing in an automated autosampler queue undergo progressive degradation. Reverse correction restores the analyte concentration back to the exact quenching time ($t_{\text{quench}}$).

---

## 2. Kinetic Trade-Off: Decay-Coupled Yield Penalty (DCYP)

### 2.1. Decay-Coupled Yield Penalty (DCYP)
During reaction execution, chemical transformation typically exhibits an asymptotic plateau or sigmoidal rise with respect to duration ($\Delta t_{\text{reaction}}$). However, exponential half-life decay concurrently diminishes the remaining active payload:

```math
Y_{\text{net}}(t) = Y_{\text{chemical}}(t) \cdot \exp(-\lambda \cdot t) = Y_{\text{chemical}}(t) \cdot 2^{-t / t_{1/2}}
```

Optimising solely for percentage conversion yield ($Y_{\text{chemical}}$) leads to artificially prolonged reaction times that produce severely degraded net active product or depleted radiotracer doses.

In DoECISORY.jl, the **Decay-Coupled Yield Penalty (DCYP)** integrates physical kinetic decay directly into the multi-criteria composite desirability function $D$:

```math
D_{\text{adjusted}} = D \cdot \exp(-\lambda \cdot \Delta t_{\text{reaction}})
```

By embedding this penalty into both gradient-free metaheuristics and continuous landscape evaluations, DoECISORY.jl identifies the precise kinetic optimum that balances reaction completion against exponential first-order loss.

> [!NOTE] Radiopharmaceutical Application
> For short-lived radionuclides ($^{11}\text{C}$, $^{18}\text{F}$, $^{68}\text{Ga}$), a reaction taking 45 minutes to reach 90% radiochemical conversion will yield significantly less net injectable radioactivity than a 15-minute reaction reaching 75% conversion, due to continuous half-life decay. DCYP mathematically arbitrates this dilemma to maximise injectable patient dose at EOS.

> [!TIP] Labile Intermediate & Sensitive API Analogy
> When synthesising products from unstable or thermally delicate active ingredients with a known degradation half-life $t_{1/2}$, extending reaction duration past the kinetic peak degrades the isolated product. DCYP balances chemical conversion rate against compound stability to identify the true productive optimum.

### 2.2. Gaussian Neighbour-Weighting Regularisation
Standard Derringer-Suich desirability functions combine individual desirability transformations $d_i(y_i)$ via geometric averaging:

```math
D = \left( \prod_{i=1}^{k} d_i(y_i)^{w_i} \right)^{\frac{1}{\sum w_i}}
```

Sharp boundaries or disparate objective weightings can induce numerical singularities and noisy objective landscapes that trap gradient or evolutionary search engines in suboptimal local modes.

To guarantee numerical stability, DoECISORY.jl applies a **Gaussian Neighbour-Weighting Regularisation** scheme across a discrete scale of importance weights:

```math
\mathbf{w}_{\text{star}} = [0.50,\, 0.75,\, 1.00,\, 1.50,\, 2.00]
```

For each user-specified weight $w_i$, the neighbouring lower ($w_m$), current ($w_c$), and upper ($w_p$) weights are extracted. The regularised composite desirability is calculated by blending standard exponential weighting with local neighbour-smoothed averaging:

```math
u = d_i(y_i)^{\frac{w_c}{k}}, \quad e = \frac{d_i(y_i)^{\frac{w_m}{k}} + d_i(y_i)^{\frac{w_c}{k}} + d_i(y_i)^{\frac{w_p}{k}}}{3}
```

```math
\text{Score}_{\text{composite}} = 0.50 \cdot \prod_{i=1}^{k} u_i + 0.50 \cdot \prod_{i=1}^{k} e_i
```

This regularisation smoothens narrow ridges in the multi-response landscape, enabling both deterministic grid searches and metaheuristic solvers to converge reliably upon stable global solutions.

---

## 3. Candidate Pool Generation and Selection

Rather than restricting the output to a single theoretical point $x^*$, DoECISORY.jl constructs a structured **Candidate Pool** covering distinct operational compromises: global optimality, input conservation, and output specialisation.

### 3.1. Search Strategy and Deduplication
1. **Continuous Metaheuristic Optimisation:** Explores the continuous parameter space via evolutionary metaheuristics (`BlackBoxOptim.jl`), locating the global mathematical peak coordinate $\mathbf{x}_{\text{BBO}}$ and score $S_{\text{BBO}}$.
2. **Deterministic High-Density Grid:** Evaluates the 3-factor space across a dense grid ($21^3 = 9,261$ or $41^3 = 68,921$ nodes), computing deterministic multi-model predictions and desirability scores.
3. **Normalised Manhattan ($L_1$) Deduplication:** Grid points are checked against the BBO peak using coordinate-wise normalised $L_1$ distance:
   ```math
   \text{dist}(\mathbf{x}_i, \mathbf{x}_{\text{BBO}}) = \sum_{j=1}^{d} \frac{|x_{i,j} - x_{\text{BBO},j}|}{U_j - L_j} > 0.01
   ```
   Points clustering within $1\%$ of the BBO optimum are pruned to avoid redundant solutions.

### 3.2. Candidate Classification
From the deduplicated search results, DoECISORY.jl builds a multi-criteria portfolio of candidates rather than forcing a single deterministic compromise:

* **1. Absolute Global Leaders (`TOP-01` to `TOP-08`):**
  The continuous metaheuristic solution ($\mathbf{x}_{\text{BBO}}$) and top discrete grid nodes are pooled together and sorted descending by composite desirability. Up to 8 unconstrained candidates (`TOP-01` through `TOP-08`) are extracted:
  * **The Asterisk (`*`) Identifier:** The candidate originating from continuous `BlackBoxOptim` carries an asterisk (e.g. `TOP-01*` or `TOP-02*`). While BBO often captures the global summit (`TOP-01*`), under tight computational time budgets or rugged multimodal surfaces, a high-density grid node may outscore it, placing BBO at `TOP-02*` or lower.
  * **Discrete Grid Leaders:** The remaining unflagged entries represent distinct discrete grid coordinates that maintain spatial diversity ($\text{dist} > 0.01$) across the peak desirability region.
* **2. Input Minimisation Leaders (`INP-<Factor>`):**
  Isolated within the top performance tier ($D(\mathbf{x}) \ge 0.90 \cdot D_{\max}$). For each active experimental factor $j \in \{1, \dots, d\}$, the algorithm extracts the coordinate that individually minimises that specific input:
  ```math
  \mathbf{x}_{\text{INP-}j} = \arg\min_{\mathbf{x} \in \text{Tier}_{90}} x_j
  ```
  * `INP-X1` (e.g. `INP-Temperature`): Formulations operating at minimal thermal load to prevent substrate decomposition, thermal side-reactions, or excessive energy consumption.
  * `INP-X2` (e.g. `INP-Time`): Formulations with minimal residence time, reducing physical radioactive decay, chemical degradation during holding, and overall cycle duration.
  * `INP-X3` (e.g. `INP-Precursor`): Green chemistry formulations conserving scarce, costly, or high-purity active pharmaceutical ingredients (APIs).
* **3. Output Specialisation Leaders (`OUT-<Response>`):**
  Identified within the same $90\%$ desirability tier by evaluating which candidate maximises or minimises individual quality attributes:
  * `OUT-Y1` (e.g. `OUT-Conversion`): Maximises overall chemical conversion or crude radiochemical incorporation.
  * `OUT-Y2` (e.g. `OUT-Yield`): Maximises net isolated product recovery or end-of-synthesis (EOS) yield.
  * `OUT-Y3` (e.g. `OUT-Impurity`): Minimises radiolytic degradation by-products, fragments, or chemical impurities.

This multi-faceted portfolio allows the research team to select a leader tailored to specific laboratory limitations (e.g. reagent scarcity, heating constraints, or impurity limits) before advancing to the next sequential phase.

---

## 4. Sequential Interphase Transfer (ASTM and ACTA)

The **Interphase Knowledge Transfer (IPKT)** framework connects sequential experimental phases through a strictly ordered two-stage pipeline: **ASTM** first projects historical coordinates and bounds into the target scale or equipment space, and **ACTA** then executes intra-space domain adaptation (contraction, automatic edge translation, or boundary seeking) within the target limits.

### 4.1. Affine Transformation (ASTM — Pre-Adaptation Mapping)
Before adapting search bounds, source bounds and leader coordinates undergo affine mapping to accommodate inter-phase scale changes, equipment migrations, or manual coordinate shifts:

```math
x_{\text{target}} = \alpha \cdot x_{\text{source}} + \beta
```

Mapping via ASTM *before* ACTA ensures that physical limit clipping and boundary-seeking margins operate directly in the target physical units. This operator supports four distinct experimental scenarios:
1. **Thermodynamic Invariance ($\alpha = 1.0, \beta = 0.0$):** Factors such as temperature or pH that maintain identical physical boundaries across experimental scales are transferred directly.
2. **Kinetic & Volumetric Scaling ($\alpha \neq 1.0, \beta = 0.0$):** When transitioning from a 1 mL micro-reactor to a 10 mL preparative vessel, flow rates or reaction times are multiplied by scaling ratio $\alpha$.
3. **Systematic Offset / Manual Shift ($\alpha = 1.0, \beta \neq 0.0$):** Applies systematic calibration offsets or deliberate researcher-specified coordinate shifts ($\beta$) when changing instruments or shifting operating windows.
4. **Space Regeneration & Factor Replacement:** When a solvent or catalyst is substituted between phases, common continuous factors retain their historical knowledge and peak positions through IPKT, while the novel factor is initialised with new physical levels. This avoids resetting the entire experimental campaign.

### 4.2. Domain Adaptation (ACTA)
Within the ASTM-mapped domain $[L_i, U_i]$ (span $\Delta_i = U_i - L_i$), the leader coordinate $x_i^*$ is evaluated via its normalised relative position:

```math
p_i = \frac{x_i^* - L_i}{U_i - L_i}
```

* **Contraction ($0.05 \le p_i \le 0.95$, `FLOW_ModeContract_DDES`):**
  When the optimum lies safely in the interior (outside the $5\%$ boundary margin), ACTA contracts the search window symmetrically around $x_i^*$:
  ```math
  \Delta_{\text{new}} = c \cdot \Delta_i, \qquad L_i^{\text{new}} = x_i^* - \frac{\Delta_{\text{new}}}{2}, \quad U_i^{\text{new}} = x_i^* + \frac{\Delta_{\text{new}}}{2}
  ```
  In the graphical interface, $c \in \{1.0, 0.75, 0.50\text{ [default]}, 0.25, 0.10\}$ is the only user-selected ACTA parameter (`Global Contraction`); programmatic callers can choose any $c \in [0.05, 1.0]$.

* **Automatic Edge Translation ($p_i < 0.05$ or $p_i > 0.95$, `FLOW_ModeTranslateLower_DDES` / `FLOW_ModeTranslateUpper_DDES`):**
  When the leader approaches within $5\%$ of a domain edge or moves outside $[L_i, U_i]$, ACTA **automatically** transitions into edge-translation mode—no manual translation slider is required in the UI. Between the $5\%$ margin and $\pm 0.50\,\Delta_i$ beyond the old boundary, the span widens linearly from $c \cdot \Delta_i$ to $\Delta_i$ while anchoring the inner edge to retain overlap with explored data; beyond $\pm 0.50\,\Delta_i$, a full-span window ($\Delta_i$) is centred on $x_i^*$. (Programmatic callers of `FLOW_CalcACTA_DDEF` may optionally pass a `Translation` offset $\delta$ to pre-shift $x_i^*$ before classification.)

* **Boundary Seeking (`FLOW_ModeSeekLower_DDES` / `FLOW_ModeSeekUpper_DDES`) & Window Sliding:**
  When candidate bounds encounter physical, thermodynamic, or equipment limits $[L_i^{\text{abs}}, U_i^{\text{abs}}]$, DoECISORY prevents domain collapse:
  - *Boundary Seeking (`FLOW_SeekFloor_DDEF` / `FLOW_SeekCeiling_DDEF`)*: When candidate bounds clip against $[L_i^{\text{abs}}, U_i^{\text{abs}}]$, ACTA enforces a minimum span of $10\%$ of $\Delta_i$ and pins the active endpoint cleanly to the physical limit ($L_1$ floor or $L_3$ ceiling), preventing matrix singularity $\kappa(X^T X) \to \infty$.
  - *Window Sliding (`FLOW_ShiftWindow_DDEF`)*: Helper routine that shifts a full target window inside finite bounds without collapsing its span when boundary limits are encountered.
