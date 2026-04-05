using ClimateEconomySimulator
using Printf

println("🌍 Climate Economy Policy Simulator")
println("=" ^ 45)

# Configure the simulation
config = SimulationConfig(
    start_year = 2024,
    end_year   = 2100,
    dt         = 1.0,
    scenarios  = [
        bau_scenario(),
        paris_2c_scenario(),
        aggressive_15c_scenario()
    ]
)

# Run all scenarios
results = run_simulation(config)

# Print summary table
println("\n📊 Summary Results (2100)")
println("-" ^ 60)
println(@sprintf("%-25s %8s %12s %10s", "Scenario", "Temp(°C)", "CO₂(GtCum)", "GDP(\$T)"))
println("-" ^ 60)
for r in results
    println(@sprintf("%-25s %8.2f %12.1f %10.1f",
        r.scenario_name, r.final_temperature,
        r.cumulative_emissions, r.gdp_2100))
end

# Save charts
plot_dashboard(results)

# Optional: run optimizer for Paris target
println("\n🔧 Running policy optimizer for 2°C pathway...")
baseline = results[1].timeline.annual_emissions
gdp_proj = results[1].timeline.gdp

optim = optimize_carbon_tax(
    76,           # 2024–2100
    1800.0,       # 1800 GtCO₂ carbon budget for 2°C
    baseline,
    gdp_proj
)

if optim.status == :optimal
    println("✅ Optimal carbon tax in 2030: \$$(round(optim.optimal_carbon_price[7], digits=1))/tCO₂")
    println("   GDP cost: $(round(optim.gdp_loss_pct, digits=2))% of cumulative GDP")
end
