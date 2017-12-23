#!/usr/bin/env ruby

#Encoding.default_external = Encoding::UTF_8

require_relative './saveparser.rb'
require 'json'
require 'pp'
require 'pg'

config = JSON.parse(File.read('config.json'))

save = parse_paradox_format(read_gamestate(find_latest_save(config['save_id'])))
json = JSON.dump(save)

connstring = config['postgres_connection_string']

client = PG.connect(connstring)

pstmt = client.exec("drop table if exists jsonb")
pstmt = client.exec_params("SELECT $1::jsonb as contents into jsonb", [ json ])

binding.pry
