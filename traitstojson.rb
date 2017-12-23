#!/usr/bin/env ruby

#Encoding.default_external = Encoding::UTF_8

require_relative './saveparser.rb'
require 'json'
require 'pp'

config = JSON.parse(File.read('config.json'))

save = parse_paradox_format(read_file_from_zip(find_mod_zip_by_id(config['mod_id']), config['traits_file']))

File.write('traits.json', JSON.dump(save))
