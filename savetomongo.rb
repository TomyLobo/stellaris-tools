#!/usr/bin/env ruby

#Encoding.default_external = Encoding::UTF_8

require_relative './saveparser.rb'
require 'mongo'
require 'json'

config = JSON.parse(File.read('config.json'))

save = parse_paradox_format(read_gamestate(find_latest_save(config['save_id'])))

def filter_keys(object)
  case object
    when Hash
      object.map do |k, v|
        [k.to_s.gsub('.', '_'), filter_keys(v)]
      end.to_h
    when Array
      object.map { |v| filter_keys(v) }
    else
      object
  end
end

mongodb_host = config['mongo_host']
mongodb_port = config['mongodb_port']
mongodb_username = config['mongodb_username']
mongodb_password = config['mongodb_password']

connection = Mongo::Connection.new(mongodb_host, mongodb_port, ssl: true, user: mongodb_username, password: mongodb_password)
connection.db.collection('savegame').insert(filter_keys(save))
binding.pry
