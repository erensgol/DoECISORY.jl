/**
 * DoECISORY - Client Callback Bridge
 * Client-side Dash callback orchestration for interactive graph navigation and responsive UI updates.
 * Architecture: Graphs live server-side in a Ref. Only metadata (count + timestamp)
 * travels through dcc_store. render_graph is server-side (single figure per request).
 */

function center_legend() {
    const graphDiv = document.getElementById("lens-graph-main");
    if (!graphDiv) return;
    const scrollbox = graphDiv.querySelector(".legend .scrollbox");
    if (!scrollbox) return;
    const traces = Array.from(scrollbox.querySelectorAll("g.traces"));
    if (traces.length <= 1) return;

    const traceData = traces.map(function(t) {
        const tr = t.getAttribute("transform") || "";
        const m = /translate\(\s*([-\d.]+)(?:[,\s]+([-\d.]+))?\s*\)/.exec(tr);
        const x = m ? parseFloat(m[1]) : 0;
        const y = (m && m[2] !== undefined) ? parseFloat(m[2]) : 0;
        const origXAttr = t.getAttribute("data-orig-x");
        const origX = origXAttr !== null ? parseFloat(origXAttr) : x;
        if (origXAttr === null) {
            t.setAttribute("data-orig-x", x);
        }
        let w = 0;
        try {
            const bbox = t.getBBox();
            w = bbox ? bbox.width : 0;
        } catch (e) {
            w = 0;
        }
        return { el: t, x: x, y: y, origX: origX, w: w };
    });

    const rows = [];
    traceData.forEach(function(item) {
        let r = rows.find(function(row) { return Math.abs(row.y - item.y) < 4; });
        if (!r) {
            r = { y: item.y, items: [] };
            rows.push(r);
        }
        r.items.push(item);
    });

    if (rows.length <= 1) return;

    rows.forEach(function(r) {
        r.items.sort(function(a, b) { return a.origX - b.origX; });
    });

    let maxRowW = 0;
    rows.forEach(function(r) {
        const first = r.items[0];
        const last = r.items[r.items.length - 1];
        r.left = first.origX;
        r.right = last.origX + last.w;
        r.width = r.right - r.left;
        if (r.width > maxRowW) maxRowW = r.width;
    });

    rows.forEach(function(r) {
        const diff = maxRowW - r.width;
        if (diff > 4) {
            const shift = diff / 2;
            r.items.forEach(function(item) {
                const newX = item.origX + shift;
                item.el.setAttribute("transform", "translate(" + newX + ", " + item.y + ")");
            });
        }
    });
}

function update_plot_scale() {
    const container = document.getElementById("lens-graph-main");
    if (!container) return;
    const refWStr = container.style.getPropertyValue("--plot-ref-width");
    const refHStr = container.style.getPropertyValue("--plot-ref-height");
    const refW = refWStr ? parseFloat(refWStr) : 480;
    const refH = refHStr ? parseFloat(refHStr) : 540;
    const parentW = container.parentElement ? container.parentElement.clientWidth : refW;
    const availW = Math.max(260, parentW - 8);
    const scale = Math.min(1.0, availW / refW);

    container.style.setProperty("--plot-scale", scale);
    container.style.width = Math.round(refW * scale) + "px";
    container.style.height = Math.round(refH * scale) + "px";
}

if (typeof window !== "undefined" && !window._plot_scale_listener) {
    window._plot_scale_listener = true;
    window.addEventListener("resize", function() {
        update_plot_scale();
        setTimeout(center_legend, 100);
    });
    window.addEventListener("orientationchange", function() {
        setTimeout(update_plot_scale, 150);
        setTimeout(center_legend, 200);
    });
}

if (typeof document !== "undefined" && !window._graph_badge_click_listener) {
    window._graph_badge_click_listener = true;
    document.addEventListener("click", function(e) {
        const badge = e.target.closest(".lens-graph-info-badge");
        if (!badge) return;
        const pageAttr = badge.getAttribute("data-page");
        let pageNum = pageAttr ? parseInt(pageAttr, 10) : NaN;
        if (isNaN(pageNum)) {
            const m = /\((\d+)(?:-\d+)?\)/.exec(badge.textContent || "");
            if (m) pageNum = parseInt(m[1], 10);
        }
        if (isNaN(pageNum) || pageNum < 1) return;

        const input = document.getElementById("lens-graph-input");
        if (input) {
            input.focus();
            if (input._valueTracker) {
                input._valueTracker.setValue("");
            }
            const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
            if (setter) {
                setter.call(input, pageNum);
            } else {
                input.value = pageNum;
            }
            input.dispatchEvent(new Event("input", { bubbles: true }));
            input.dispatchEvent(new Event("change", { bubbles: true }));
            input.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", code: "Enter", keyCode: 13, which: 13, bubbles: true }));
            input.dispatchEvent(new KeyboardEvent("keypress", { key: "Enter", code: "Enter", keyCode: 13, which: 13, bubbles: true }));
            input.dispatchEvent(new KeyboardEvent("keyup", { key: "Enter", code: "Enter", keyCode: 13, which: 13, bubbles: true }));
            input.blur();
        }
    });

    document.addEventListener("keydown", function(e) {
        if (e.key === "Enter" || e.key === " ") {
            const badge = e.target.closest(".lens-graph-info-badge");
            if (badge && document.activeElement === badge) {
                e.preventDefault();
                badge.click();
            }
        }
    });
}

window.dash_clientside = Object.assign({}, window.dash_clientside, {
    clientside: {

        update_index: function(meta, n_nxt, n_prv, val_inp, current_i) {
            const context = window.dash_clientside.callback_context;
            const trigger = context.triggered.length > 0 ? context.triggered[0].prop_id : "";
            const tot = (meta && meta.count) ? meta.count : 0;
            console.log("[DOECISORY] Graph Meta Count:", tot, "| Trigger:", trigger);

            if (trigger.includes('lens-store-graph-meta.data')) {
                if (tot === 0) return [0, 1, 1];
                let idx = (current_i === null || current_i === undefined) ? 0 : current_i;
                idx = Math.min(idx, tot - 1);
                return [idx, idx + 1, Math.max(1, tot)];
            }
            if (tot === 0) return [0, 1, 1];

            let idx = (current_i === null || current_i === undefined) ? 0 : current_i;

            if (trigger.includes('lens-btn-next.n_clicks')) {
                idx = (idx + 1) % tot;
            } else if (trigger.includes('lens-btn-prev.n_clicks')) {
                idx = (idx - 1 + tot) % tot;
            } else if (trigger.includes('lens-graph-input.value')) {
                if (val_inp === null || val_inp === undefined || isNaN(val_inp)) {
                     return window.dash_clientside.no_update;
                }
                if (val_inp >= 1 && val_inp <= tot) {
                    idx = val_inp - 1;
                } else {
                    idx = val_inp < 1 ? 0 : tot - 1;
                }
            }

            idx = Math.max(0, Math.min(idx, tot - 1));

            return [idx, idx + 1, Math.max(1, tot)];
        },

        render_graph: function(blob, idx) {
             if (!blob || blob === "") {
                 return [window.dash_clientside.no_update, "", "/ 0"];
             }
             
             try {
                 const graphs = JSON.parse(blob);
                 const count = graphs.length;
                 if (count === 0) return [window.dash_clientside.no_update, "", "/ 0"];
                 const safe_i = (idx === null || idx === undefined || isNaN(idx)) ? 0 : Math.max(0, Math.min(Number(idx), count - 1));
                 const item = graphs[safe_i] || graphs[0] || {};
                 const fig = item.figure || {};
                 
                 console.log("[DOECISORY] Rendering Plot:", item.title, "| Index:", safe_i);
                 
                 const layout = Object.assign({}, fig.layout || {});
                 const refW = layout.width || 480;
                 const refH = layout.height || 540;

                 layout.width = refW;
                 layout.height = refH;
                 layout.autosize = false;

                 const container = document.getElementById("lens-graph-main");
                 if (container) {
                     const parentW = container.parentElement ? container.parentElement.clientWidth : refW;
                     const availW = Math.max(260, parentW - 8);
                     const scale = Math.min(1.0, availW / refW);

                     container.style.setProperty("--plot-scale", scale);
                     container.style.setProperty("--plot-ref-width", refW + "px");
                     container.style.setProperty("--plot-ref-height", refH + "px");
                     container.style.width = Math.round(refW * scale) + "px";
                     container.style.height = Math.round(refH * scale) + "px";
                     container.style.margin = "0 auto";
                     container.style.overflow = "hidden";
                     container.style.position = "relative";
                 }

                 let plotData = (fig.data || []).map(function(d) { return Object.assign({}, d); });

                 if (layout.scene) {
                     layout.scene = Object.assign({}, layout.scene, {
                         dragmode: "turntable",
                         uirevision: "lens-graph-" + safe_i
                     });
                     layout.dragmode = "turntable";
                     if (container && container._saved_camera && container._saved_camera_idx === safe_i) {
                         layout.scene.camera = container._saved_camera;
                     }
                 } else {
                     layout.dragmode = "pan";
                 }
                 layout.uirevision = "lens-graph-" + safe_i;

                 if (container && container._saved_camera_idx !== safe_i) {
                     container._saved_camera = null;
                     container._saved_camera_idx = safe_i;
                 }

                 if (container && !container._has_camera_guard) {
                     container._has_camera_guard = true;

                     function syncActiveCamera() {
                         if (container._fullLayout && container._fullLayout.scene && container._fullLayout.scene.camera) {
                             const c = container._fullLayout.scene.camera;
                             if (c && c.eye) {
                                 container._saved_camera = {
                                     up: Object.assign({}, c.up || { x: 0, y: 0, z: 1 }),
                                     center: Object.assign({}, c.center || { x: 0, y: 0, z: 0 }),
                                     eye: Object.assign({}, c.eye)
                                 };
                                 if (container.layout && container.layout.scene) {
                                     container.layout.scene.camera = container._saved_camera;
                                 }
                             }
                         }
                     }

                     container.addEventListener("mouseup", function() {
                         setTimeout(syncActiveCamera, 20);
                     });
                     container.addEventListener("wheel", function() {
                         setTimeout(syncActiveCamera, 50);
                     });

                     container.addEventListener("mousedown", function(e) {
                         const btn = e.target.closest(".modebar-btn");
                         if (!btn) return;
                         const title = (btn.getAttribute("data-title") || "").toLowerCase();
                         if (title.includes("reset")) {
                             container._saved_camera = null;
                             return;
                         }
                         syncActiveCamera();
                         const preserved = container._saved_camera;
                         if (preserved) {
                             setTimeout(function() {
                                 if (container._fullLayout && container._fullLayout.scene && window.Plotly) {
                                     Plotly.relayout(container, { "scene.camera": preserved });
                                 }
                             }, 25);
                         }
                     }, true);

                     if (typeof container.on === "function") {
                         container.on("plotly_relayout", function(ed) {
                             syncActiveCamera();
                         });
                     }
                 }

                 if (container && !container._has_legend_listener) {
                     container._has_legend_listener = true;
                     if (typeof container.on === "function") {
                         container.on("plotly_afterplot", function() {
                             setTimeout(center_legend, 20);
                         });
                     }
                 }
                 setTimeout(center_legend, 40);
                 setTimeout(center_legend, 120);
                 setTimeout(center_legend, 300);
                 
                 return [
                     {
                         data: plotData,
                         layout: layout
                     },
                     "",
                     "/ " + count
                 ];
             } catch (e) {
                 console.error("[DOECISORY] Blob Parsing Failed:", e);
                 return [{}, "Data Corruption Error", "/ 0"];
             }
        },

        update_info: function(blob) {
            if (!blob || blob === "") return "";
            
            try {
                const graphs = JSON.parse(blob);
                const counts = {};
                const order = [];
                
                graphs.forEach(item => {
                    const title = item.title || "Unknown";
                    const category = title.split(":")[0];
                    if (!counts[category]) {
                        order.push(category);
                        counts[category] = 0;
                    }
                    counts[category]++;
                });
                
                const info_parts = [];
                let curr_start = 1;
                order.forEach(cat => {
                    const c = counts[cat];
                    const range_str = (c === 1) ? ("" + curr_start) : (curr_start + "-" + (curr_start + c - 1));
                    info_parts.push({
                        text: cat + " (" + range_str + ")",
                        startPage: curr_start
                    });
                    curr_start += c;
                });
                
                const badges = info_parts.map(function(item) {
                    return {
                        props: {
                            children: item.text,
                            className: "lens-graph-info-badge colourtx-v5pb",
                            "data-page": item.startPage,
                            title: "Jump to plot " + item.startPage,
                            role: "button",
                            tabIndex: 0
                        },
                        type: "Span",
                        namespace: "dash_html_components"
                    };
                });
                
                return {
                    props: {
                        children: badges,
                        className: "lens-graph-info-container",
                    },
                    type: "Div",
                    namespace: "dash_html_components"
                };
            } catch (e) {
                console.error("[DOECISORY] Info Build Failed:", e);
                return "Error building index.";
            }
        }
    }
});
