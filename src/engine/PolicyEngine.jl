module PolicyEngine

export PolicyScenario, carbon_price_linear, carbon_price_exponential,
       carbon_price_step, apply_policy!, bau_scenario, paris_2c_scenario, aggressive_15c_scenario

"""
    PolicyScenario

Container for all policy levers available to the simulator.
Each field maps to a real-world climate policy instrument.
"""
struct PolicyScenario
    name::String
    description::String

    # Carbon pricing
    carbon_price_path::Function    # year → USD/tCO₂
    carbon_border_adjustment::Bool  # CBAM-style mechanism

    # Standards & regulations
    efficiency_standard::Float64   # 0–1, stringency of energy efficiency mandates
    renewable_portfolio_standard::Float64  # minimum renewable share required

    # Subsidies & investment
    clean_energy_subsidy::Float64  # fraction of GDP
    fossil_fuel_phase_out_year::Int

    # Sectoral policies
    ev_mandate_year::Int          # year ICE vehicles banned
    building_retrofit_rate::Float64  # fraction of buildings retrofitted/year
    industrial_decarbonization::Float64  # stringency 0–1

    # International
    global_cooperation_level::Float64  # 0=unilateral, 1=full global coordination
end

"""Prebuilt scenario: Business as Usual."""
function bau_scenario()
    PolicyScenario(
        "Business as Usual",
        "No new climate policies beyond current commitments",
        carbon_price_linear(15.0, 20.0, 2024, 2100),
        false, 0.1, 0.25, 0.025, 2100,
        2100, 0.005, 0.1, 0.2
    )
end

"""Prebuilt scenario: Paris Agreement 2°C pathway."""
function paris_2c_scenario()
    PolicyScenario(
        "Paris 2°C",
        "Policies consistent with limiting warming to 2°C",
        carbon_price_exponential(25.0, 250.0, 2024, 2050),
        true, 0.6, 0.70, 0.08, 2060,
        2040, 0.025, 0.7, 0.75
    )
end

"""Prebuilt scenario: 1.5°C stretch goal."""
function aggressive_15c_scenario()
    PolicyScenario(
        "Aggressive 1.5°C",
        "Rapid decarbonization targeting 1.5°C warming limit",
        carbon_price_exponential(50.0, 500.0, 2024, 2045),
        true, 0.9, 0.95, 0.15, 2040,
        2030, 0.05, 0.95, 0.95
    )
end

"""Linear carbon price ramp: from `p_start` to `p_end` between `y_start` and `y_end`."""
function carbon_price_linear(p_start, p_end, y_start, y_end)
    return year -> begin
        t = clamp((year - y_start) / (y_end - y_start), 0.0, 1.0)
        p_start + t * (p_end - p_start)
    end
end

"""Exponential carbon price growth."""
function carbon_price_exponential(p_start, p_end, y_start, y_end)
    return year -> begin
        t = clamp((year - y_start) / (y_end - y_start), 0.0, 1.0)
        p_start * (p_end / p_start)^t
    end
end

"""Step function carbon price (e.g., fixed price then jump)."""
function carbon_price_step(levels::Vector{Tuple{Int,Float64}})
    return year -> begin
        price = levels[1][2]
        for (yr, p) in levels
            if year >= yr
                price = p
            end
        end
        price
    end
end

end # module
