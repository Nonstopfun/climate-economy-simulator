module ClimateEconomySimulator

using JuMP, Ipopt, GLPK
using Plots, DataFrames, CSV
using Statistics, Dates, Printf
using ProgressMeter

include("models/ClimateModel.jl")
include("models/EconomyModel.jl")
include("engine/PolicyEngine.jl")
include("engine/Optimizer.jl")
include("engine/Simulator.jl")
include("io/DataIO.jl")
include("io/Visualizer.jl")

using .ClimateModel
using .EconomyModel
using .PolicyEngine
using .Optimizer
using .Simulator
using .DataIO
using .Visualizer

export run_simulation, optimize_policy, load_scenario, save_results
export optimize_carbon_tax, optimize_energy_portfolio
export bau_scenario, paris_2c_scenario, aggressive_15c_scenario
export plot_temperature_pathways, plot_emissions, plot_energy_transition, plot_dashboard
export ClimateState, EconomyState, PolicyScenario, SimulationConfig, SimulationResult

end
