module Optimizer

using JuMP, Ipopt, GLPK

export optimize_carbon_tax, optimize_energy_portfolio, PolicyOptimResult

"""
    PolicyOptimResult

Holds the output of a policy optimization run.
"""
struct PolicyOptimResult
    optimal_carbon_price::Vector{Float64}
    optimal_renewable_share::Vector{Float64}
    total_abatement_cost::Float64
    temperature_outcome::Float64
    gdp_loss_pct::Float64
    status::Symbol
end

"""
    optimize_carbon_tax(years, emissions_target, baseline_emissions, gdp_projection)

Solve for the optimal carbon tax trajectory that meets an emissions cap
at minimum economic cost. Uses JuMP with Ipopt (interior point method).

# Arguments
- `years`: number of simulation years
- `emissions_target`: target cumulative GtCO₂ over horizon
- `baseline_emissions`: Vector of baseline annual emissions (GtCO₂)
- `gdp_projection`: Vector of projected GDP (trillion USD)

# Returns `PolicyOptimResult`
"""
function optimize_carbon_tax(
    years::Int,
    emissions_target::Float64,
    baseline_emissions::Vector{Float64},
    gdp_projection::Vector{Float64}
)::PolicyOptimResult

    model = Model(Ipopt.Optimizer)
    set_silent(model)
    set_optimizer_attribute(model, "max_iter", 3000)
    set_optimizer_attribute(model, "tol", 1e-8)

    # Decision variables
    @variable(model, 0 <= tau[1:years] <= 1000)  # carbon tax USD/tCO₂
    @variable(model, 0 <= abate[1:years] <= 1)   # abatement fraction

    # Objective: minimize total discounted abatement cost
    discount_rate = 0.04
    @objective(model, Min, sum(
        (1 / (1 + discount_rate)^t) *
        gdp_projection[t] * 1000 * 0.0025 * abate[t]^2.6
        for t in 1:years
    ))

    # Constraint: meet cumulative emissions target
    @constraint(model, sum(
        baseline_emissions[t] * (1 - abate[t]) for t in 1:years
    ) <= emissions_target)

    # Constraint: carbon tax must be consistent with abatement (no-regret)
    for t in 1:years
        @constraint(model, tau[t] >= 5.35 * abate[t]^1.6)
    end

    # Smoothness constraint — tax shouldn't jump more than 30% year over year
    for t in 2:years
        @constraint(model, tau[t] <= tau[t-1] * 1.30)
        @constraint(model, tau[t] >= tau[t-1] * 0.85)
    end

    optimize!(model)

    if termination_status(model) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
        tau_vals   = value.(tau)
        abate_vals = value.(abate)
        total_cost = objective_value(model)
        gdp_loss   = total_cost / sum(gdp_projection) * 100

        return PolicyOptimResult(
            tau_vals,
            abate_vals,
            total_cost,
            1.8,  # placeholder — would be computed by full simulation
            gdp_loss,
            :optimal
        )
    else
        @warn "Optimizer did not converge: $(termination_status(model))"
        return PolicyOptimResult(
            zeros(years), zeros(years), Inf, Inf, Inf, :infeasible
        )
    end
end

"""
    optimize_energy_portfolio(budget, energy_demand, costs, emissions_factors, target_share)

Linear program: minimize total energy system cost subject to
renewable share constraint and budget limit. Uses GLPK for speed.
"""
function optimize_energy_portfolio(
    budget::Float64,
    energy_demand::Float64,
    costs::Dict{Symbol, Float64},        # USD/MWh
    emissions_factors::Dict{Symbol, Float64},  # tCO₂/MWh
    target_renewable_share::Float64
)
    sources = collect(keys(costs))
    n = length(sources)

    model = Model(GLPK.Optimizer)
    set_silent(model)

    @variable(model, 0 <= x[i=1:n])  # capacity fraction for each source

    # Minimize cost
    @objective(model, Min, sum(costs[sources[i]] * x[i] for i in 1:n))

    # Meet total demand
    @constraint(model, sum(x) == energy_demand)

    # Budget constraint
    @constraint(model, sum(costs[sources[i]] * x[i] for i in 1:n) <= budget)

    # Renewable share constraint
    renewable_sources = [:wind, :solar, :hydro, :nuclear, :other_renewables]
    @constraint(model,
        sum(x[i] for i in 1:n if sources[i] in renewable_sources) >=
        target_renewable_share * energy_demand
    )

    optimize!(model)
    return value.(x), sources, objective_value(model)
end

end # module
