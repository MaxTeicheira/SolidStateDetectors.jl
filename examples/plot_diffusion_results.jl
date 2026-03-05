# CZT Plotting: load saved simulation state and generate all plots
# Requires: run_diffusion_sim.jl must have been run first to create sim_state.jld2
#
# Usage: julia --project=. examples/plot_diffusion_results.jl

using SolidStateDetectors
using Unitful
using Plots
using JLD2

# --- Load state ---
outdir = joinpath(@__DIR__, "output_diffusion")
statefile = joinpath(outdir, "sim_state.jld2")
if !isfile(statefile)
    error("No simulation state found. Run run_diffusion_sim.jl first.")
end

println("Loading simulation state from $statefile ...")
state = load(statefile)
sim = state["sim"]
evt = state["evt"]
weighting_contact_ids = state["weighting_contact_ids"]
use_diffusion = state["use_diffusion"]
use_self_repulsion = state["use_self_repulsion"]
println("  Loaded. Generating plots...")

# =========================================================================
# Helpers
# =========================================================================

const m_to_mm = 1000.0

# Crystal extents (from config: 40x40x5 mm box centered at origin)
const crystal_x = (-20.0, 20.0)   # mm
const crystal_y = (-20.0, 20.0)   # mm
const crystal_z = (-2.5, 2.5)     # mm

function contact_label(id::Int)
    if 1 <= id <= 5
        return "Anode $id"
    elseif id == 6
        return "Cathode 1"
    elseif id == 7
        return "Cathode 2"
    else
        return "Contact $id"
    end
end

# Extract y=0 slice from a potential, clipped to crystal bounds, plotted in mm
function plot_potential_mm(potential, title_str; clabel = "")
    g = potential.grid
    xax_m = collect(g.axes[1])
    yax_m = collect(g.axes[2])
    zax_m = collect(g.axes[3])

    # Convert to mm
    xax = xax_m .* m_to_mm
    zax = zax_m .* m_to_mm

    # Find y=0 slice
    yidx = argmin(abs.(yax_m))

    # Clip to crystal region
    xi = findall(x -> crystal_x[1] <= x <= crystal_x[2], xax)
    zi = findall(z -> crystal_z[1] <= z <= crystal_z[2], zax)

    data_slice = potential.data[xi, yidx, zi]'

    heatmap(xax[xi], zax[zi], data_slice,
        title = title_str, xlabel = "x [mm]", ylabel = "z [mm]",
        colorbar_title = clabel, size = (700, 500), c = :viridis)
end

# =========================================================================
# Plots
# =========================================================================

# --- Electric potential (clipped to crystal) ---
p_epot = plot_potential_mm(sim.electric_potential, "Electric Potential (y=0 slice)",
    clabel = "Potential [V]")
savefig(p_epot, joinpath(outdir, "electric_potential_xz.png"))
println("  Saved electric_potential_xz.png")

# Helper: strip Unitful units for clean axis labels
using Unitful: ustrip
strip_time(wf) = ustrip.(wf.time)
strip_signal(wf) = ustrip.(wf.signal)

# --- Waveforms (inverted: multiply signal by -1) ---
p_wf = plot(title = "Induced Waveforms (diffusion + self-repulsion)",
    xlabel = "t [ns]", ylabel = "Signal [e]", size = (700, 500))
for (i, wf) in enumerate(evt.waveforms)
    if !ismissing(wf)
        plot!(p_wf, strip_time(wf), -strip_signal(wf), label = contact_label(i))
    end
end
savefig(p_wf, joinpath(outdir, "waveforms.png"))
println("  Saved waveforms.png")

# --- Anode-only waveforms (inverted) ---
anode_ids = [i for i in 1:5 if !ismissing(evt.waveforms[i])]
p_anodes = plot(title = "Anode Waveforms (diffusion + self-repulsion)",
    xlabel = "t [ns]", ylabel = "Signal [e]", size = (700, 500),
    legend = :bottomright)
for i in anode_ids
    wf = evt.waveforms[i]
    plot!(p_anodes, strip_time(wf), -strip_signal(wf), label = contact_label(i))
end
savefig(p_anodes, joinpath(outdir, "waveforms_anodes.png"))
println("  Saved waveforms_anodes.png")

# --- Drift paths XZ ---
p_drift = if !ismissing(evt.drift_paths) && !isempty(evt.drift_paths)
    n_carriers = length(evt.drift_paths)
    plot(title = "Drift Paths - $n_carriers carriers\n(diffusion=$use_diffusion, self_repulsion=$use_self_repulsion)",
        xlabel = "x [mm]", ylabel = "z [mm]", aspect_ratio = :auto, size = (800, 600))
    for (i, dp) in enumerate(evt.drift_paths)
        e_label = i == 1 ? "Electron" : ""
        h_label = i == 1 ? "Hole" : ""
        e_path = dp.e_path
        plot!([p.x * m_to_mm for p in e_path], [p.z * m_to_mm for p in e_path],
            label = e_label, color = :blue, lw = 1, alpha = 0.4)
        h_path = dp.h_path
        plot!([p.x * m_to_mm for p in h_path], [p.z * m_to_mm for p in h_path],
            label = h_label, color = :red, lw = 1, alpha = 0.4)
    end
    hline!([2.5], label = "Anode face (z=+2.5 mm)", ls = :dash, color = :green)
    hline!([-2.5], label = "Cathode face (z=-2.5 mm)", ls = :dash, color = :orange)
    current()
else
    plot(title = "Drift Paths (not available)")
end
savefig(p_drift, joinpath(outdir, "drift_paths_all_carriers.png"))
println("  Saved drift_paths_all_carriers.png")

# --- Drift paths XY (top-down) ---
p_drift_xy = if !ismissing(evt.drift_paths) && !isempty(evt.drift_paths)
    plot(title = "Drift Paths XY (top-down, lateral spread)",
        xlabel = "x [mm]", ylabel = "y [mm]", aspect_ratio = :equal, size = (700, 600))
    for (i, dp) in enumerate(evt.drift_paths)
        e_label = i == 1 ? "Electron" : ""
        h_label = i == 1 ? "Hole" : ""
        e_path = dp.e_path
        plot!([p.x * m_to_mm for p in e_path], [p.y * m_to_mm for p in e_path],
            label = e_label, color = :blue, lw = 1, alpha = 0.4)
        h_path = dp.h_path
        plot!([p.x * m_to_mm for p in h_path], [p.y * m_to_mm for p in h_path],
            label = h_label, color = :red, lw = 1, alpha = 0.4)
    end
    current()
else
    plot(title = "Drift Paths XY (not available)")
end
savefig(p_drift_xy, joinpath(outdir, "drift_paths_xy_spread.png"))
println("  Saved drift_paths_xy_spread.png")

# --- 3D Drift paths ---
p_3d = if !ismissing(evt.drift_paths) && !isempty(evt.drift_paths)
    plot3d(title = "3D Charge Drift Through Crystal",
        xlabel = "x [mm]", ylabel = "y [mm]", zlabel = "z [mm]",
        size = (900, 700), camera = (30, 25), legend = :topright)
    for (i, dp) in enumerate(evt.drift_paths)
        e_label = i == 1 ? "Electron" : ""
        h_label = i == 1 ? "Hole" : ""
        e_path = dp.e_path
        plot3d!([p.x * m_to_mm for p in e_path],
                [p.y * m_to_mm for p in e_path],
                [p.z * m_to_mm for p in e_path],
                label = e_label, color = :blue, lw = 1, alpha = 0.5)
        h_path = dp.h_path
        plot3d!([p.x * m_to_mm for p in h_path],
                [p.y * m_to_mm for p in h_path],
                [p.z * m_to_mm for p in h_path],
                label = h_label, color = :red, lw = 1, alpha = 0.5)
    end
    # Draw anode and cathode face wireframes sized to drift region
    xr = [-1.5, 1.5]; yr = [-1.5, 1.5]
    for (zval, lbl, clr) in [(2.5, "Anode face", :green), (-2.5, "Cathode face", :orange)]
        plot3d!([xr[1], xr[2], xr[2], xr[1], xr[1]],
                [yr[1], yr[1], yr[2], yr[2], yr[1]],
                fill(zval, 5),
                label = lbl, color = clr, lw = 2, ls = :dash)
    end
    current()
else
    plot3d(title = "3D Drift Paths (not available)")
end
savefig(p_3d, joinpath(outdir, "drift_paths_3d.png"))
println("  Saved drift_paths_3d.png")

# --- Combined overview ---
p_overview = plot(p_epot, p_wf, p_drift, p_drift_xy,
    layout = (2, 2), size = (1600, 1200))
savefig(p_overview, joinpath(outdir, "simulation_overview.png"))
println("  Saved simulation_overview.png")

# --- Weighting potentials (clipped to crystal) ---
for cid in weighting_contact_ids
    pw = plot_potential_mm(sim.weighting_potentials[cid],
        "Weighting Potential - $(contact_label(cid))",
        clabel = "Weighting Potential")
    fname = "weighting_potential_$(lowercase(replace(contact_label(cid), " " => "_"))).png"
    savefig(pw, joinpath(outdir, fname))
    println("  Saved $fname")
end

println("\n=== All plots saved to: $outdir ===")
