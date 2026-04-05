module Visualizer

using Plots, DataFrames
using ..Simulator

export plot_temperature_pathways, plot_emissions, plot_energy_transition, plot_dashboard

gr()  # Use GR backend for performance

const SCENARIO_COLORS = [:firebrick, :darkorange, :steelblue, :seagreen, :purple]

"""
    plot_temperature_pathways(results)

Multi-line temperature trajectory plot with 1.5°C and 2°C reference lines.
"""
function plot_temperature_pathways(results::Vector{SimulationResult})
    p = plot(
        title = "Global mean temperature pathways",
        xlabel = "Year",
        ylabel = "Temperature anomaly (°C)",
        legend = :topleft,
        size = (900, 550),
        dpi = 150,
        grid = true,
        gridalpha = 0.3,
        framestyle = :box
    )

    hline!(p, [1.5], linestyle=:dash, color=:orange, label="1.5°C target", linewidth=1.5)
    hline!(p, [2.0], linestyle=:dash, color=:red,    label="2.0°C target", linewidth=1.5)

    for (i, r) in enumerate(results)
        plot!(p, r.timeline.year, r.timeline.temperature,
              label = r.scenario_name,
              color = SCENARIO_COLORS[mod1(i, length(SCENARIO_COLORS))],
              linewidth = 2.5)
    end

    return p
end

"""
    plot_emissions(results)

Annual CO₂ emissions trajectory comparison across scenarios.
"""
function plot_emissions(results::Vector{SimulationResult})
    p = plot(
        title = "Annual CO₂ emissions by scenario",
        xlabel = "Year",
        ylabel = "GtCO₂/year",
        legend = :topright,
        size = (900, 500),
        dpi = 150
    )

    hline!(p, [0.0], linestyle=:dot, color=:black, label="Net zero", linewidth=1)

    for (i, r) in enumerate(results)
        plot!(p, r.timeline.year, r.timeline.annual_emissions,
              label = r.scenario_name,
              color = SCENARIO_COLORS[mod1(i, length(SCENARIO_COLORS))],
              linewidth = 2.5)
    end

    return p
end

"""
    plot_energy_transition(result)

Stacked area chart of renewable share over time for a single scenario.
"""
function plot_energy_transition(result::SimulationResult)
    df = result.timeline
    plot(df.year, df.renewable_share .* 100,
         title  = "Renewable energy share — $(result.scenario_name)",
         xlabel = "Year",
         ylabel = "Renewable share (%)",
         fill   = true,
         fillalpha = 0.3,
         color  = :seagreen,
         label  = "Renewables",
         size   = (900, 450),
         dpi    = 150,
         ylims  = (0, 100))
end

"""
    plot_dashboard(results, output_dir="output")

Generate and save all plots to disk.
"""
function plot_dashboard(results::Vector{SimulationResult}, output_dir::String="output")
    mkpath(output_dir)

    savefig(plot_temperature_pathways(results), joinpath(output_dir, "temperature_pathways.png"))
    savefig(plot_emissions(results),            joinpath(output_dir, "emissions.png"))

    for r in results
        safe_name = replace(r.scenario_name, " " => "_")
        savefig(plot_energy_transition(r), joinpath(output_dir, "energy_$(safe_name).png"))
    end

    println("✅ Plots saved to $(output_dir)/")
end

end # module
