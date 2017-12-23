#!/usr/bin/env ruby

#Encoding.default_external = Encoding::UTF_8

require_relative './saveparser.rb'
require 'json'

config = JSON.parse(File.read('config.json'))

save = parse_paradox_format(read_gamestate(find_latest_save(config['save_id'])))

File.write('save.json', JSON.dump(save))
