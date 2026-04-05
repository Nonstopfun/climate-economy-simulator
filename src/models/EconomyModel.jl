module EconomyModel

export EconomyState, EnergyMix, step_economy!, compute_emissions, abatement_cost

"""
    EnergyMix

Struct representing the energy supply portfolio (shares must sum ≈ 1.0).
"""
struct EnergyMix
    coal::Float64
    gas::Float64
    oil::Float64
    nuclear::Float64
    hydro::Float64
    wind::Float64
    solar::Float64
    other_renewables::Float64
end

function EnergyMix()
    EnergyMix(0.27, 0.23, 0.31, 0.05, 0.07, 0.04, 0.02, 0.01)
end

"""Emission intensity in tCO₂ per MWh for each energy source."""
const EMISSION_INTENSITY = Dict(
    :coal  => 0.82,
    :gas   => 0.49,
    :oil   => 0.65,
    :nuclear => 0.012,
    :hydro => 0.024,
    :wind  => 0.011,
    :solar => 0.045,
    :other_renewables => 0.030
)

"""
    EconomyState

Tracks macroeconomic variables alongside energy transition metrics.
"""
mutable struct EconomyState
    year::Int
    gdp::Float64               # trillion USD (2024 PPP)
    population::Float64        # billions
    energy_demand_EJ::Float64  # exajoules per year
    energy_mix::EnergyMix
    carbon_price::Float64      # USD per tCO₂
    green_investment::Float64  # fraction of GDP in clean energy
    fossil_subsidies::Float64  # billion USD/year
    unemployment_rate::Float64 # fraction
    energy_intensity::Float64  # EJ per trillion USD GDP
end

function EconomyState()
    EconomyState(
        2024,
        105.0,    # ~$105 trillion global GDP
        8.1,      # 8.1 billion people
        600.0,    # ~600 EJ global energy demand
        EnergyMix(),
        15.0,     # ~$15/tCO₂ global average carbon price
        0.025,    # 2.5% of GDP in clean energy
        5600.0,   # ~$5.6T/yr fossil fuel subsidies
        0.055,
        600.0 / 105.0
    )
end

"""
    compute_emissions(state)

Compute annual CO₂ emissions in GtCO₂ from energy consumption and mix.
"""
function compute_emissions(state::EconomyState)::Float64
    mix = state.energy_mix
    total_EJ = state.energy_demand_EJ

    weighted_intensity = (
        mix.coal  * EMISSION_INTENSITY[:coal]  +
        mix.gas   * EMISSION_INTENSITY[:gas]   +
        mix.oil   * EMISSION_INTENSITY[:oil]   +
        mix.nuclear * EMISSION_INTENSITY[:nuclear] +
        mix.hydro * EMISSION_INTENSITY[:hydro] +
        mix.wind  * EMISSION_INTENSITY[:wind]  +
        mix.solar * EMISSION_INTENSITY[:solar] +
        mix.other_renewables * EMISSION_INTENSITY[:other_renewables]
    )

    # Convert: EJ × tCO₂/MWh × 277.8 MWh/TJ → GtCO₂
    return total_EJ * 1000 * weighted_intensity * 277.8 / 1e9
end

"""
    abatement_cost(reduction_fraction, gdp)

Marginal cost of emissions abatement. Uses a convex cost curve —
early reductions are cheap, deep decarbonization gets exponentially costly.
Returns billion USD.
"""
function abatement_cost(reduction_fraction::Float64, gdp::Float64)::Float64
    @assert 0.0 <= reduction_fraction <= 1.0
    # Nordhaus-style quadratic + cubic abatement cost
    θ₁ = 0.0025
    θ₂ = 2.6
    cost_fraction = θ₁ * reduction_fraction^θ₂
    return cost_fraction * gdp * 1000  # billion USD
end

"""
    step_economy!(state, policy, dt=1.0)

Advance economic state by `dt` years under a given policy scenario.
Models GDP growth, energy transition, carbon pricing effects.
"""
function step_economy!(state::EconomyState, policy, dt::Float64=1.0)
    # Baseline GDP growth (decreasing as economy matures)
    base_growth = 0.025 * exp(-0.002 * (state.year - 2024))

    # Carbon price drag on GDP (small but real)
    carbon_drag = state.carbon_price * 0.00008

    # Green investment stimulus
    green_boost = state.green_investment * 0.15

    gdp_growth = max(0.0, base_growth - carbon_drag + green_boost)
    state.gdp *= (1.0 + gdp_growth)^dt

    # Population (logistic growth toward ~10.4B peak)
    pop_growth = 0.007 * (1.0 - state.population / 10.4)
    state.population *= (1.0 + pop_growth)^dt

    # Energy demand grows with GDP but declines with efficiency gains
    efficiency_gain = 0.012 + policy.efficiency_standard * 0.008
    demand_growth = gdp_growth * 0.6 - efficiency_gain
    state.energy_demand_EJ *= (1.0 + demand_growth)^dt

    # Update carbon price trajectory
    state.carbon_price = policy.carbon_price_path(state.year)

    # Renewable penetration driven by carbon price + subsidies
    renewable_growth = min(0.04, 0.005 + state.carbon_price * 0.0005 + state.green_investment * 2.0) * dt
    mix = state.energy_mix
    fossil_total = mix.coal + mix.gas + mix.oil

    if fossil_total > 0.05
        coal_share_loss = renewable_growth * 0.5
        gas_share_loss  = renewable_growth * 0.3
        oil_share_loss  = renewable_growth * 0.2

        state.energy_mix = EnergyMix(
            max(0.02, mix.coal - coal_share_loss),
            max(0.01, mix.gas  - gas_share_loss),
            max(0.01, mix.oil  - oil_share_loss),
            mix.nuclear,
            mix.hydro,
            min(0.45, mix.wind  + renewable_growth * 0.45),
            min(0.45, mix.solar + renewable_growth * 0.45),
            min(0.10, mix.other_renewables + renewable_growth * 0.10)
        )
    end

    state.year += Int(round(dt))
    return state
end

end # module
