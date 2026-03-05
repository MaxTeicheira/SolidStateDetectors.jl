# CZT Simulation: compute potentials, fields, and charge drift
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

# --- Output directory ---
outdir = joinpath(@__DIR__, "output_diffusion")
mkpath(outdir)
statefile = joinpath(outdir, "sim_state.jld2")

# --- Configuration ---
config_path = joinpath(@__DIR__, "example_config_files", "CZT_strip_detector_reduced.yaml")
weighting_contact_ids = [2, 3, 4, 6]  # neighboring anodes + cathode
T = Float32

# =========================================================================
# Step 1: Load detector
# =========================================================================
println("Loading detector configuration...")
sim = Simulation{T}(config_path)
println("  Detector: ", sim.detector.name)
println("  Number of contacts: ", length(sim.detector.contacts))

# =========================================================================
# Step 2: Calculate electric potential
# =========================================================================
println("\nCalculating electric potential...")
calculate_electric_potential!(sim,
    refinement_limits = [0.2, 0.1, 0.05, 0.01],
    max_n_iterations = 50000,
    verbose = true,
)
println("  Done. Grid size: ", size(sim.electric_potential.data))

# =========================================================================
# Step 3: Calculate electric field
# =========================================================================
println("\nCalculating electric field...")
calculate_electric_field!(sim)

center_idx = div.(size(sim.electric_field.data), 2)
E_center = sim.electric_field.data[center_idx...]
E_mag = sqrt(sum(x -> x^2, E_center))
println("  E-field at center: ", round(E_mag, digits=1), " V/m")

# =========================================================================
# Step 4: Calculate weighting potentials
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
# Step 5: Simulate charge drift
# =========================================================================
hit_position = CartesianPoint{T}(0.0, 0.0, 0.0)

nbcc = NBodyChargeCloud(hit_position, 662u"keV"; number_of_shells = n_shells)
evt = Event(nbcc)
println("\nCharge cloud: NBodyChargeCloud with $n_shells shell(s)")

println("Simulating charge drift...")
println("  Diffusion: $use_diffusion  Self-repulsion: $use_self_repulsion")
simulate!(evt, sim,
    Δt = Δt_drift,
    max_nsteps = max_drift_steps,
    diffusion = use_diffusion,
    self_repulsion = use_self_repulsion,
    verbose = true,
)
println("  Done. Number of waveforms: ", length(evt.waveforms))

# =========================================================================
# Step 6: Save state
# =========================================================================
println("\nSaving simulation state to $statefile ...")
jldsave(statefile;
    sim = sim,
    evt = evt,
    weighting_contact_ids = weighting_contact_ids,
    use_diffusion = use_diffusion,
    use_self_repulsion = use_self_repulsion,
)
println("  Done. Run plot_diffusion_results.jl to generate plots.")
