#!/usr/bin/env ruby

require_relative './saveparser.rb'
require 'pp'
require 'json'

config = JSON.parse(File.read('config.json'))

$save = parse_paradox_format(read_gamestate(find_latest_save(config['save_id'])))

country_id = config['country_id']

$all_countries = $save[:country][0]
  .reject { |country_id, country| country[0] == :none }
$all_planets = $save[:planet][0]
  .reject { |planet_id, planet| planet[0] == :none }
$all_pops = $save[:pop][0]
$all_species = $save[:species][0]
$all_fleets = $save[:fleet][0]
  .reject { |fleet_id, fleet| fleet[0] == :none }
$all_ships = $save[:ships][0]
$all_ship_designs = $save[:ship_design][0]
$all_leaders = $save[:leaders][0]
$all_galactic_objects = $save[:galactic_object][0]
  .reject { |alliance_id, alliance| alliance[0] == :none }
$all_alliances = $save[:alliance][0]
  .reject { |alliance_id, alliance| alliance[0] == :none }

rejected_country_types = [
  'primitive',
  'global_event',
  'agency',
  'nomad',
  'enclave',
  'skorr',
  'exile',
]

regular_countries = $all_countries
  .reject { |country_id, country| rejected_country_types.include?(country[0][:type][0]) }

#### empire ####

empire = $all_countries[country_id][0]

empire_planets = $all_planets
  .select { |planet_id, planet| planet[0][:owner][0] == country_id }

empire_fleets = $all_fleets
  .select { |fleet_id, fleet| fleet[0][:owner][0] == country_id }

#### planet analysis ####
growing_pops = empire_planets
  .select { |planet_id, planet| planet[0][:pop][0] != nil }
  .map { |planet_id, planet|
    [
      planet[0][:name][0],
      planet[0][:pop][0]
        .map { |pop_id| $all_pops[pop_id][0] }
        .select { |pop| pop[:growth_state][0] == 0}
        .map { |pop| pop[:species_index][0] }
        .map { |species_index| $all_species[species_index] }
        .map { |species| species[:name][0] }
    ]
  }
  .reject { |planet_name, species_names| species_names.empty? }
  .to_h

brizeen_planets = $all_planets
  .select { |planet_id, planet|
    planet[0][:tiles][0].any? { |tile_index, tile|
        tile[0][:deposit].include?("d_sr_brizeen_14_deposit")
    }
  }

wrongly_named_stations = empire_fleets
  .select { |fleet_id, fleet| fleet[0][:station][0] == :yes }
  .reject { |fleet_id, fleet| $all_planets[fleet[0][:movement_manager][0][:orbit][0][:planet][0]] == nil }
  .reject { |fleet_id, fleet| fleet[0][:name][0].include?($all_planets[fleet[0][:movement_manager][0][:orbit][0][:planet][0]][0][:name][0]) }
  .map { |fleet_id, fleet| [
    fleet[0][:name][0],
    $all_planets[fleet[0][:movement_manager][0][:orbit][0][:planet][0]][0][:name][0],
  ] }


#### defenseless_countries ####
countries_without_direct_dependents = regular_countries
  .select { |country_id, country| country[0][:overlord][0] == nil }
  .select { |country_id, country| country[0][:war_allies][0] == nil || country[0][:war_allies][0].empty? }
  .select { |country_id, country| country[0][:subjects][0] == nil || country[0][:subjects][0].empty? }

alliance_members = $all_alliances
  .select { |alliance_id, alliance|
    next true if alliance[0][:members][0].any? { |country_id| not countries_without_direct_dependents.has_key?(country_id) } # if any members has direct dependents, skip power check
    power_score = alliance[0][:members][0]
      .inject(0) { |sum, country_id| sum + $all_countries[country_id][0][:power_score][0] }
    power_score > 1000
  }
  .map { |alliance_id, alliance| alliance[0][:members][0] }
  .flatten

defenseless_countries = countries_without_direct_dependents
  .reject { |country_id, country| alliance_members.include?(country_id) }

#### civilian_fleets ####

civilian_fleets = $all_fleets
  .select { |fleet_id, fleet| fleet[0][:civilian][0] == :yes }

def fleets_by_ship_size(fleets, ship_size)
  return fleets
    .select { |fleet_id, fleet|
      fleet[0][:ships][0].any? { |ship_id|
        ship = $all_ships[ship_id][0]
        ship_design = $all_ship_designs[ship[:ship_design][0]][0]

        next ship_design[:ship_size][0] == ship_size
      }
    }
end

science_fleets = fleets_by_ship_size(civilian_fleets, 'science')
construction_fleets = fleets_by_ship_size(civilian_fleets, 'constructor')
colony_fleets = fleets_by_ship_size(civilian_fleets, 'colonizer')

exploration_fleets = science_fleets
  .select { |fleet_id, fleet|
    fleet[0][:ships][0].any? { |ship_id|
      ship = $all_ships[ship_id][0]

      leader_id = ship[:leader][0]
      next false if leader_id == nil

      leader = $all_leaders[leader_id][0]
      next leader != nil
    }
  }

idle_exploration_fleets = exploration_fleets
  .select { |fleet_id, fleet| fleet[0][:current_order][0] == nil }

nonevasive_civilian_fleets = civilian_fleets
  .reject { |fleet_id, fleet| fleet[0][:station][0] == :yes }
  .reject { |fleet_id, fleet| fleet[0][:fleet_stance][0] == :evasive }

#### planets_without_complete_starbases ####

required_spaceport_modules = [
  :module_micro_fusion,
  :module_orbital_hydroponics,
]

  #.reject { |planet_id, planet| planet[0][:spaceport][0].nil? }
planets_without_complete_starbases = empire_planets
  .select { |planet_id, planet|
    spaceport = planet[0][:spaceport][0]
    next true if spaceport.nil?
    spaceport_construction = spaceport[:construction][0]
    next false unless spaceport_construction.nil?
    spaceport_level = spaceport[:level][0]
    spaceport_modules = spaceport[:modules][0].values.flatten
    spaceport_queue = spaceport[:build_queue_item]
      .map { |build_queue_item| build_queue_item[:item][0] }
    spaceport_queued_modules = spaceport_queue
      .select { |item| item[:type][0] == :spaceport_module }
      .map { |item| item[:spaceport_module][0].to_sym }
    spaceport_all_modules = spaceport_modules + spaceport_queued_modules
    spaceport_queued_upgrades = spaceport_queue
      .select { |item| item[:type][0] == :spaceport_upgrade }
      .map { |item| item[:level][0] }

    next true unless spaceport_level == 6 or spaceport_queued_upgrades.include?(6)
    next true unless (required_spaceport_modules - spaceport_all_modules).empty? || spaceport_all_modules.length == spaceport_level + 1
  }

planets_without_complete_starbases_report = planets_without_complete_starbases
  .map { |planet_id, planet|
    spaceport = planet[0][:spaceport][0]
    if spaceport
      spaceport_construction = spaceport[:construction][0]
      spaceport_level = spaceport[:level][0]
      spaceport_modules = spaceport[:modules][0].values.flatten
      spaceport_queue = spaceport[:build_queue_item]
        .map { |build_queue_item| build_queue_item[:item][0] }
      spaceport_queued_modules = spaceport_queue
        .select { |item| item[:type][0] == :spaceport_module }
        .map { |item| item[:spaceport_module][0].to_sym }
      spaceport_all_modules = spaceport_modules + spaceport_queued_modules
      spaceport_queued_upgrades = spaceport_queue
        .select { |item| item[:type][0] == :spaceport_upgrade }
        .map { |item| item[:level][0] }

      missing_upgrades = 6 - [ spaceport_level, *spaceport_queued_upgrades ].max

      todo = []
      todo << "#{missing_upgrades} upgrades" unless missing_upgrades.zero?
      todo += required_spaceport_modules - spaceport_all_modules
      todo = [:construct] if spaceport_level.nil?
    else
      todo = [:construct]
    end
    [
      planet[0][:name][0],
      $all_galactic_objects[planet[0][:coordinate][0][:origin][0]][0][:name][0],
      todo
    ]
  }
  .sort_by { |result| result[1] }

#### missing_stations ####
possibly_owned_stars = $all_galactic_objects
  .select { |galactic_objects_id, galactic_object| galactic_object[0][:type][0] == :star }
  .select { |galactic_objects_id, galactic_object|
    fleet_presence = galactic_object[0][:fleet_presence][0]
    unless fleet_presence.nil? then
      stations = fleet_presence
        .map { |fleet_id| $all_fleets[fleet_id][0] }
        .select { |fleet| fleet[:station][0] == :yes }

      next true if stations.any? { |fleet| fleet[:owner][0] == country_id }
    end

    planets = galactic_object[0][:planet]
    next true if planets && planets.any? { |planet_id| $all_planets[planet_id][0][:owner][0] == country_id }

    false
  }

impossible_station_deposits = [
  'd_farmland_deposit', 'd_rich_farmland_deposit',
  'd_sr_brizeen_14_deposit',
]

def tile_id_from_orbital_deposit_tile(orbital_deposit_tile)
  tile_y = (orbital_deposit_tile & 0x0000ffff00000000) >> (8*4)
  tile_x = (orbital_deposit_tile & 0xffff000000000000) >> (12*4)

  return tile_y * 5 + tile_x
end

missing_stations = $all_planets
  .select { |planet_id, planet| planet[0][:owner][0].nil? }
  .reject { |planet_id, planet| possibly_owned_stars[planet[0][:coordinate][0][:origin][0]].nil? }
  .select { |planet_id, planet| planet[0][:shipclass_orbital_station][0].nil? }
  .reject { |planet_id, planet|
    tile_id = tile_id_from_orbital_deposit_tile(planet[0][:orbital_deposit_tile][0])
    tile = planet[0][:tiles][0][tile_id][0]
    station_deposits = tile[:deposit] - impossible_station_deposits

    station_deposits.empty?
  }

missing_station_report = missing_stations
  .map { |planet_id, planet|
    tile_id = tile_id_from_orbital_deposit_tile(planet[0][:orbital_deposit_tile][0])
    tile = planet[0][:tiles][0][tile_id][0]
    station_deposits = tile[:deposit] - impossible_station_deposits

    [
      planet[0][:name][0],
      $all_galactic_objects[planet[0][:coordinate][0][:origin][0]][0][:name][0],
      station_deposits,
    ]
  }

require 'pry'; binding.pry :quiet => true
