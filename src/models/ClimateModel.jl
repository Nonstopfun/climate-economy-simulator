module ClimateModel

export ClimateState, step_climate!, temperature_feedback, compute_radiative_forcing

"""
    ClimateState

Mutable struct holding the current state of the climate system.
All temperature values are in °C above pre-industrial baseline.
CO₂ in ppm, sea level in meters.
"""
mutable struct ClimateState
    year::Int
    temperature::Float64        # °C above baseline
    co2_ppm::Float64            # atmospheric CO₂ concentration
    sea_level_rise::Float64     # meters above 1990 baseline
    ocean_heat_content::Float64 # ZJ (zettajoules)
    arctic_ice_extent::Float64  # million km²
    permafrost_carbon::Float64  # GtC remaining locked
end

"""Default 2024 initial conditions."""
function ClimateState()
    ClimateState(2024, 1.2, 422.0, 0.20, 396.0, 10.8, 1500.0)
end

"""
    radiative_forcing(co2_ppm, baseline_ppm=280.0)

Compute radiative forcing (W/m²) from CO₂ concentration.
Uses the standard logarithmic formula from IPCC AR6.
"""
function radiative_forcing(co2_ppm::Float64, baseline_ppm::Float64=280.0)::Float64
    5.35 * log(co2_ppm / baseline_ppm)
end

"""
    temperature_feedback(state, climate_sensitivity=3.0)

Equilibrium Climate Sensitivity (ECS) feedback calculation.
Default ECS = 3.0°C per doubling of CO₂ (IPCC central estimate).
"""
function temperature_feedback(state::ClimateState, ecs::Float64=3.0)::Float64
    forcing = radiative_forcing(state.co2_ppm)
    ecs * forcing / (5.35 * log(2))  # normalize to ECS per doubling
end

"""
    permafrost_feedback(state)

Permafrost carbon feedback — releases additional CO₂ as temperature rises.
Returns additional GtCO₂/year released.
"""
function permafrost_feedback(state::ClimateState)::Float64
    if state.temperature < 1.5
        return 0.0
    elseif state.temperature < 2.0
        return (state.temperature - 1.5) * 0.5 * state.permafrost_carbon / 1000.0
    else
        return (0.25 + (state.temperature - 2.0) * 1.2) * state.permafrost_carbon / 1000.0
    end
end

"""
    step_climate!(state, annual_emissions_gt, dt=1.0)

Advance climate state by `dt` years given annual CO₂ emissions in GtCO₂.
Modifies state in-place for performance — avoids allocation in tight loops.
"""
function step_climate!(state::ClimateState, annual_emissions_gt::Float64, dt::Float64=1.0)
    # Airborne fraction: ~44% of emissions stay in atmosphere
    airborne_fraction = 0.44
    ppm_per_gt = 0.1286  # 1 GtCO₂ ≈ 0.1286 ppm

    pf_feedback = permafrost_feedback(state)
    total_emissions = annual_emissions_gt + pf_feedback

    # Update permafrost reservoir
    state.permafrost_carbon = max(0.0, state.permafrost_carbon - pf_feedback * dt)

    # Update CO₂
    state.co2_ppm += airborne_fraction * total_emissions * ppm_per_gt * dt

    # Temperature with thermal inertia (ocean lag ~30 years)
    target_temp = temperature_feedback(state)
    state.temperature += (target_temp - state.temperature) * 0.033 * dt

    # Sea level: thermal expansion + ice melt
    state.sea_level_rise += (0.003 + max(0.0, state.temperature - 1.0) * 0.004) * dt

    # Arctic ice decline (non-linear above 1.5°C)
    ice_loss_rate = state.temperature > 1.5 ? 0.15 : 0.06
    state.arctic_ice_extent = max(0.0, state.arctic_ice_extent - ice_loss_rate * dt)

    # Ocean heat content
    state.ocean_heat_content += 15.0 * state.temperature * dt

    state.year += Int(round(dt))
    return state
end

end # module
