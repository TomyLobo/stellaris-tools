#!/usr/bin/env ruby

#Encoding.default_external = Encoding::UTF_8

require_relative './saveparser.rb'
require 'json'
require 'chroma'

allowed_keys = [
  :flag,
  :map,
  :ship,
]


config = JSON.parse(File.read('config.json'))

save_raw = parse_paradox_format(read_file_from_zip(find_mod_zip_by_id(config['mod_id']), config['colors_file']))

save = save_raw[:colors][0]
  .map { |color_name, color_scheme|
    color_scheme[0]
      .select { |key, value| allowed_keys.include?(key) }
      .map { |key, value|
        type, args = value[0]
        args[0] *= 360 if type == :hsv
        color = Chroma.paint("#{type}(#{args.join(',')})").to_hex
        [
          :name => color_name,
          :color_key => key,
          :color => color,
        ]
      }
  }
  .flatten(2)

File.write('colors_raw.json', JSON.pretty_generate(save_raw))
File.write('colors.json', JSON.pretty_generate(save))

#require 'pry'; binding.pry :quiet => true
