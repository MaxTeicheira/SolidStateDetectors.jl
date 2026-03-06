# Visualize the CZT detector geometry with steering electrodes using SSD
# Usage: julia --project=. examples/visualize_ssd_geometry.jl

using SolidStateDetectors
using Plots

outdir = joinpath(@__DIR__, "output_diffusion")
mkpath(outdir)

config_path = joinpath(@__DIR__, "example_config_files", "CZT_strip_detector_steering.yaml")
println("Loading detector: $config_path")
sim = Simulation{Float32}(config_path)
println("  Detector: ", sim.detector.name)
println("  Contacts: ", length(sim.detector.contacts))

for c in sim.detector.contacts
    println("    ID=$(c.id)  $(c.name)  potential=$(c.potential)V")
end

# --- SSD built-in detector plot ---
println("\nGenerating SSD geometry plot...")
p1 = plot(sim.detector, size = (800, 600))
savefig(p1, joinpath(outdir, "ssd_geometry_3d.png"))
println("  Saved ssd_geometry_3d.png")

# --- Cross-section slices ---
println("Generating cross-section plots...")

# XZ slice at y=0
p2 = plot(sim.detector, y = 0.0, size = (900, 500),
    title = "Detector Cross-Section (y=0)")
savefig(p2, joinpath(outdir, "ssd_geometry_xz.png"))
println("  Saved ssd_geometry_xz.png")

# XY slice at z=2.5mm (top face - anode side)
p3 = plot(sim.detector, z = 0.0025, size = (900, 500),
    title = "Top Face (z=+2.5mm) - Anodes & Steering")
savefig(p3, joinpath(outdir, "ssd_geometry_top_face.png"))
println("  Saved ssd_geometry_top_face.png")

# Combined
p_all = plot(p1, p2, p3, layout = (1, 3), size = (2400, 600))
savefig(p_all, joinpath(outdir, "ssd_geometry_combined.png"))
println("  Saved ssd_geometry_combined.png")

println("\n=== Geometry visualization complete ===")
