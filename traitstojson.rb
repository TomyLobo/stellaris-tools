#!/usr/bin/env ruby

#Encoding.default_external = Encoding::UTF_8

require_relative './saveparser.rb'
require 'json'
require 'pp'

config = JSON.parse(File.read('config.json'))

save_raw = parse_paradox_format(read_file_from_zip(find_mod_zip_by_id(config['mod_id']), config['traits_file']))
save = save_raw
  .map { |trait_name, trait|
    trait[0][:modifier][0]
      .map{ |modifier, amount|
        {
          :name => trait_name,
          :modifier => modifier,
          :amount => amount[0],
        }
      }
  }
  .flatten(1)

File.write('traits_raw.json', JSON.pretty_generate(save_raw))
File.write('traits.json', JSON.pretty_generate(save))
