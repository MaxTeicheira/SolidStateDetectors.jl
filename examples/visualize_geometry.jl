# Quick visualization of detector geometry with steering electrodes
# Usage: julia --project=. examples/visualize_geometry.jl

using Plots

outdir = joinpath(@__DIR__, "output_diffusion")
mkpath(outdir)

# Crystal dimensions
crystal_x = (-20.0, 20.0)  # mm
crystal_z = (-2.5, 2.5)    # mm

# Anode strips: 100μm wide, 1mm pitch, at z=+2.5mm
anode_positions = [-2.0, -1.0, 0.0, 1.0, 2.0]  # x centers (mm)
anode_hw = 0.05  # half-width in x (mm)

# Steering electrodes: 400μm wide, between and at ends of anodes, at z=+2.5mm
# Between each pair + outer ends
steering_positions = [-2.5, -1.5, -0.5, 0.5, 1.5, 2.5]  # x centers (mm)
steering_hw = 0.2  # half-width in x (mm)

# Cathode strips: 4.9mm wide, at z=-2.5mm
cathode_positions_y = [-2.5, 2.5]  # y centers (for reference)
cathode_hw = 2.45  # half-width in y

# --- Plot 1: Top face view (x-axis detail, zoomed) ---
p1 = plot(title = "Top Face Electrode Layout (z=+2.5mm)",
    xlabel = "x [mm]", ylabel = "",
    xlims = (-4, 4), ylims = (-0.5, 2.5),
    size = (900, 300), legend = :topright,
    yticks = [])

# Draw steering electrodes (green)
for (i, sx) in enumerate(steering_positions)
    label = i == 1 ? "Steering (-80V)" : ""
    plot!(p1, [sx - steering_hw, sx + steering_hw, sx + steering_hw, sx - steering_hw, sx - steering_hw],
        [0, 0, 1, 1, 0],
        fill = true, fillalpha = 0.4, fillcolor = :green, linecolor = :green,
        label = label)
end

# Draw anodes (blue)
for (i, ax) in enumerate(anode_positions)
    label = i == 1 ? "Anode (600V)" : ""
    plot!(p1, [ax - anode_hw, ax + anode_hw, ax + anode_hw, ax - anode_hw, ax - anode_hw],
        [0, 0, 1.5, 1.5, 0],
        fill = true, fillalpha = 0.6, fillcolor = :blue, linecolor = :blue,
        label = label)
    annotate!(p1, ax, 1.7, text("A$(i)", 7, :blue))
end

# Annotate steering
for sx in steering_positions
    annotate!(p1, sx, 1.2, text("S", 6, :green))
end

# Mark gaps
for (i, ax) in enumerate(anode_positions)
    if i < length(anode_positions)
        gap_center = (ax + anode_positions[i+1]) / 2
        gap_size = anode_positions[i+1] - ax - 2*anode_hw - 2*steering_hw
    end
end

savefig(p1, joinpath(outdir, "geometry_top_face.png"))
println("Saved geometry_top_face.png")

# --- Plot 2: Cross-section XZ view ---
p2 = plot(title = "Detector Cross-Section (y=0)",
    xlabel = "x [mm]", ylabel = "z [mm]",
    xlims = (-4, 4), ylims = (-3.5, 3.5),
    size = (900, 500), legend = :bottomright,
    aspect_ratio = :auto)

# Crystal body
plot!(p2, [-20, 20, 20, -20, -20], [-2.5, -2.5, 2.5, 2.5, -2.5],
    fill = true, fillalpha = 0.1, fillcolor = :gray, linecolor = :gray,
    label = "CZT Crystal")
# Zoomed crystal body
plot!(p2, [-3.5, 3.5, 3.5, -3.5, -3.5], [-2.5, -2.5, 2.5, 2.5, -2.5],
    fill = true, fillalpha = 0.05, fillcolor = :gray, linecolor = :lightgray,
    label = "")

# Cathode (bottom face, shown as full-width strip)
plot!(p2, [-3.5, 3.5, 3.5, -3.5, -3.5], [-2.5, -2.5, -2.7, -2.7, -2.5],
    fill = true, fillalpha = 0.4, fillcolor = :red, linecolor = :red,
    label = "Cathode (0V)")

# Steering electrodes on top face
for (i, sx) in enumerate(steering_positions)
    label = i == 1 ? "Steering (-80V)" : ""
    plot!(p2, [sx - steering_hw, sx + steering_hw, sx + steering_hw, sx - steering_hw, sx - steering_hw],
        [2.5, 2.5, 2.7, 2.7, 2.5],
        fill = true, fillalpha = 0.5, fillcolor = :green, linecolor = :green,
        label = label)
end

# Anodes on top face
for (i, ax) in enumerate(anode_positions)
    label = i == 1 ? "Anode (600V)" : ""
    plot!(p2, [ax - anode_hw, ax + anode_hw, ax + anode_hw, ax - anode_hw, ax - anode_hw],
        [2.5, 2.5, 2.8, 2.8, 2.5],
        fill = true, fillalpha = 0.6, fillcolor = :blue, linecolor = :blue,
        label = label)
end

# Annotate
for (i, ax) in enumerate(anode_positions)
    annotate!(p2, ax, 3.1, text("A$(i)", 7, :blue))
end
for sx in steering_positions
    annotate!(p2, sx, 3.0, text("S", 6, :darkgreen))
end

savefig(p2, joinpath(outdir, "geometry_cross_section.png"))
println("Saved geometry_cross_section.png")

# --- Plot 3: Detailed pitch diagram ---
p3 = plot(title = "Electrode Pitch Detail (center region)",
    xlabel = "x [mm]", ylabel = "",
    xlims = (-2.0, 2.0), ylims = (-0.5, 3),
    size = (900, 400), legend = :topright,
    yticks = [])

# Steering
for (i, sx) in enumerate(steering_positions)
    if abs(sx) <= 2.0
        label = i == 1 || sx == -1.5 ? "Steering 400μm" : ""
        plot!(p3, [sx - steering_hw, sx + steering_hw, sx + steering_hw, sx - steering_hw, sx - steering_hw],
            [0, 0, 1, 1, 0],
            fill = true, fillalpha = 0.4, fillcolor = :green, linecolor = :green,
            label = label)
        annotate!(p3, sx, 1.15, text("$(Int(steering_hw*2*1000))μm", 7, :darkgreen))
    end
end

# Anodes
for (i, ax) in enumerate(anode_positions)
    if abs(ax) <= 1.5
        label = ax == -1.0 ? "Anode 100μm" : ""
        plot!(p3, [ax - anode_hw, ax + anode_hw, ax + anode_hw, ax - anode_hw, ax - anode_hw],
            [0, 0, 1.5, 1.5, 0],
            fill = true, fillalpha = 0.6, fillcolor = :blue, linecolor = :blue,
            label = label)
        annotate!(p3, ax, 1.65, text("$(Int(anode_hw*2*1000))μm", 7, :blue))
    end
end

# Gap annotations
# Gap between anode edge and steering edge
gap = 0.5 - anode_hw - steering_hw  # = 0.5 - 0.05 - 0.2 = 0.25 mm
annotate!(p3, -0.625, 0.5, text("gap\n$(Int(gap*1000))μm", 6, :black))
annotate!(p3, -0.375, 0.5, text("gap\n$(Int(gap*1000))μm", 6, :black))

# Pitch annotation
plot!(p3, [-1.0, 0.0], [2.3, 2.3], color = :black, lw = 1, label = "")
plot!(p3, [-1.0, -1.0], [2.2, 2.4], color = :black, lw = 1, label = "")
plot!(p3, [0.0, 0.0], [2.2, 2.4], color = :black, lw = 1, label = "")
annotate!(p3, -0.5, 2.5, text("1mm pitch", 8, :black))

savefig(p3, joinpath(outdir, "geometry_pitch_detail.png"))
println("Saved geometry_pitch_detail.png")

# --- Combined ---
p_all = plot(p2, p1, p3, layout = (3, 1), size = (900, 1200))
savefig(p_all, joinpath(outdir, "geometry_steering_layout.png"))
println("Saved geometry_steering_layout.png")

println("\n=== Geometry visualization complete ===")
println("Steering electrode positions (x centers): $steering_positions mm")
println("Steering width: $(steering_hw*2) mm ($(Int(steering_hw*2*1000)) μm)")
println("Anode width: $(anode_hw*2) mm ($(Int(anode_hw*2*1000)) μm)")
println("Gap (anode edge to steering edge): $(gap) mm ($(Int(gap*1000)) μm)")
