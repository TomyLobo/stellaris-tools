#!/usr/bin/env ruby

require 'json'
require 'pp'

root_key = ARGV[0] || 'tech_gene_tailoring'
subnodes_key = ARGV[1] || 'prerequisites'

techs = JSON.load(File.read('techs.json'))
known_techs = File.read('known_techs.txt')
                .lines
                .map(&:chomp)

$tech_hash = {}
techs.each do |tech|
  $tech_hash[tech['key']] = tech
  root_key = tech['key'] if tech['name'] == root_key
  tech['known'] = true if known_techs.include?(tech['key']) || known_techs.include?(tech['name'])
end
techs.each do |tech|
  tech['prerequisites'].each do |prerequisite_key|
    prerequisite = $tech_hash[prerequisite_key]
    prerequisite['unlocks'] ||= []
    prerequisite['unlocks'] << tech['key']
  end
end

$iterated = {}

def print_tech_tree(key, subnodes_key, indent = '', last_child = true)
  node = $tech_hash[key]
  subnodes = node[subnodes_key] || []
  feature_unlocks = node['feature_unlocks'] || []

  if node['known'] then
    status = ' ✓'
  else
    status = ''
  end

  if last_child then
    puts "#{indent}└─ #{node['name']}#{status}"
    next_indent = "#{indent}    "
  else
    puts "#{indent}├─ #{node['name']}#{status}"
    next_indent = "#{indent}│   "
  end

  #return if node['known']

  if !subnodes.empty? && $iterated.include?(key) then
    puts "#{next_indent}└─ ↑↑↑ See above ↑↑↑"
    return
  end

  $iterated[key] = true

  unless node['known']
    feature_unlocks.each_with_index do |feature, index|
      subnode_is_last_child = index == feature_unlocks.size - 1

      if subnodes.empty? then
        double_indent = "#{next_indent}  "
      else
        double_indent = "#{next_indent}│ "
      end

      if subnode_is_last_child then
        puts "#{double_indent}└─ #{feature}"
      else
        puts "#{double_indent}├─ #{feature}"
      end
    end
  end

  subnodes.each_with_index do |prerequisite_key, index|
    subnode_is_last_child = index == subnodes.size - 1
    print_tech_tree(prerequisite_key, subnodes_key, next_indent, subnode_is_last_child)
  end
end

print_tech_tree(root_key, subnodes_key)
