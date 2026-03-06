# CZT Simulation: compute potentials once, then drift at multiple depth positions
# Saves all simulation state to output_diffusion/sim_state.jld2
# Run plot_diffusion_results.jl separately to regenerate plots without re-simulating.
#
# Usage: julia --threads=auto --project=. examples/run_diffusion_sim.jl

using SolidStateDetectors
using Unitful
using JLD2

# --- Physics Parameters ---
use_diffusion       = true
use_self_repulsion  = true
n_shells            = 2        # 2 shells = 41 carriers
Δt_drift            = 1u"ns"
max_drift_steps     = 5000

# --- Depth scan parameters ---
# Lateral position: x=0.2mm (in gap between Anode 3 and steering), y=0
lateral_x = 0.2   # mm (converted to m below)
lateral_y = 0.0   # mm

# Depth positions: z = +2.3 to +0.5 mm (top 2mm, near anode face)
# 10 steps of 0.2mm, starting nearest the anode
z_positions_mm = collect(range(2.3, 0.5, length=10))

# --- Output directory ---
outdir = joinpath(@__DIR__, "output_diffusion")
mkpath(outdir)
statefile = joinpath(outdir, "sim_state.jld2")

# --- Configuration ---
config_path = joinpath(@__DIR__, "example_config_files", "CZT_strip_detector_steering.yaml")
weighting_contact_ids = [2, 3, 4, 6]  # neighboring anodes + steering grid
T = Float32

# =========================================================================
# Step 1: Load detector
# =========================================================================
println("Loading detector configuration...")
sim = Simulation{T}(config_path)
println("  Detector: ", sim.detector.name)
println("  Number of contacts: ", length(sim.detector.contacts))

# =========================================================================
# Step 2: Calculate electric potential (once)
# =========================================================================
println("\nCalculating electric potential...")
calculate_electric_potential!(sim,
    refinement_limits = [0.2, 0.1, 0.05, 0.01],
    max_n_iterations = 50000,
    verbose = true,
)
println("  Done. Grid size: ", size(sim.electric_potential.data))

# =========================================================================
# Step 3: Calculate electric field (once)
# =========================================================================
println("\nCalculating electric field...")
calculate_electric_field!(sim)

center_idx = div.(size(sim.electric_field.data), 2)
E_center = sim.electric_field.data[center_idx...]
E_mag = sqrt(sum(x -> x^2, E_center))
println("  E-field at center: ", round(E_mag, digits=1), " V/m")

# =========================================================================
# Step 4: Calculate weighting potentials (once)
# =========================================================================
println("\nCalculating weighting potentials for contact IDs: ", weighting_contact_ids)
for cid in weighting_contact_ids
    println("  Computing weighting potential for contact $cid...")
    calculate_weighting_potential!(sim, cid,
        refinement_limits = [0.2, 0.1, 0.05],
        max_n_iterations = 50000,
        verbose = false,
    )
end
println("  Done.")

# =========================================================================
# Step 5: Depth scan — simulate charge drift at each z position
# =========================================================================
println("\n=== Starting depth scan: $(length(z_positions_mm)) positions ===")
println("  Lateral: x=$(lateral_x)mm, y=$(lateral_y)mm")
println("  Depth:   z=$(z_positions_mm[1])mm → $(z_positions_mm[end])mm")
println("  Diffusion: $use_diffusion  Self-repulsion: $use_self_repulsion\n")

# Convert mm to m for SSD (internal units are SI)
x_m = T(lateral_x * 1e-3)
y_m = T(lateral_y * 1e-3)

events = Vector{Any}(undef, length(z_positions_mm))

for (i, z_mm) in enumerate(z_positions_mm)
    z_m = T(z_mm * 1e-3)
    pos = CartesianPoint{T}(x_m, y_m, z_m)

    println("[$i/$(length(z_positions_mm))] z = $(z_mm)mm ($(round(2.5 - z_mm, digits=1))mm from anode)...")

    nbcc = NBodyChargeCloud(pos, 662u"keV"; number_of_shells = n_shells)
    evt = Event(nbcc)

    simulate!(evt, sim,
        Δt = Δt_drift,
        max_nsteps = max_drift_steps,
        diffusion = use_diffusion,
        self_repulsion = use_self_repulsion,
        verbose = false,
    )

    events[i] = evt
    println("  Done. Waveforms: $(length(evt.waveforms))")
end

println("\n=== Depth scan complete ===")

# =========================================================================
# Step 6: Save state
# =========================================================================
println("\nSaving simulation state to $statefile ...")
jldsave(statefile;
    sim = sim,
    events = events,
    z_positions_mm = z_positions_mm,
    lateral_x_mm = lateral_x,
    lateral_y_mm = lateral_y,
    weighting_contact_ids = weighting_contact_ids,
    use_diffusion = use_diffusion,
    use_self_repulsion = use_self_repulsion,
)
println("  Done. Run plot_diffusion_results.jl to generate plots.")
