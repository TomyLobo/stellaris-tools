#!/usr/bin/env ruby

#Encoding.default_external = Encoding::UTF_8

require_relative './saveparser.rb'
require 'json'
require 'pp'
require 'dbi'

config = JSON.parse(File.read('config.json'))

save = parse_paradox_format(read_gamestate(find_latest_save(config['save_id'])))
json = JSON.dump(save)

odbc_datasource = config['odbc_datasource']
odbc_username = config['odbc_username']
odbc_password = config['odbc_password']

client = DBI.connect("DBI:ODBC:#{odbc_datasource}", odbc_username, odbc_password)

pstmt = client.prepare("SELECT [key], value as value_json into savegame from OPENJSON(cast(? as text))")
pstmt.execute(json)

pp pstmt.fetch_all
