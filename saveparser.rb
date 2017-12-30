#!/usr/bin/env ruby

require 'zip'
require 'strscan'

class Stellaris
  def parser_error
    File.write('parser-error-gamestate', @scanner.string)
    raise "Parser error at character #{@scanner.pos} with #{@scanner.rest_size} characters remaining:\n#{@scanner.rest[0, 100]}"
  end

  def bark
    puts "at character #{@scanner.pos} with #{@scanner.rest_size} characters remaining:\n#{@scanner.rest[0, 100]}"
  end

  #rule(:space?)     { match('\s').repeat }
  def parse_space?
    @scanner.skip(/\s*/m)
    @scanner.skip(/#.*\n/)
    @scanner.skip(/\s*/m)
  end

  #rule(:space)      { match('\s').repeat(1) }
  def parse_space
    @scanner.skip(/\s/m)
    parse_space?
  end

  #rule(:leftbrace)  { match('{') >> space? }
  #rule(:rightbrace) { match('}') >> space? }
  #rule(:integer)    { match('-').maybe >> match('[0-9]').repeat(1) }
  def parse_integer?
    integer = @scanner.scan(/-?[0-9]+/)
    return nil unless integer

    return integer.to_i
  end

  #rule(:float)     { match('-').maybe >> match('[0-9]').repeat(1) >> (match('\.') >> match('[0-9]').repeat(1)).maybe }
  def parse_float?
    float = @scanner.scan(/-?[0-9]+\.[0-9]+/)
    return nil unless float

    return float.to_f
  end

  #rule(:string)     { match('"') >> match('[^"]').repeat >> match('"') }
  def parse_string?
    return nil unless @scanner.scan(/"([^"]*)"/)
    string = @scanner[1]

    return string
  end

  #rule(:dictionary) { leftbrace >> keyvalue.repeat >> rightbrace }
  def parse_dictionary
    #puts "I think this is a dictionary:\n#{@scanner.rest}"
    parser_error unless @scanner.skip(/\{/)
    dictionary = parse_keyvalues
    parser_error unless @scanner.skip(/\}/)
    return dictionary
  end

  #rule(:array)      { leftbrace >> value.repeat >> rightbrace }
  def parse_array
    #puts "I think this is an array:\n#{@scanner.rest}"
    parser_error unless @scanner.skip(/\{/)
    array = []

    parse_space
    until @scanner.skip(/\}/) || @scanner.eos?
      value = parse_value
      array << value
      parse_space
    end

    return array
  end

  # try to tell if this is an array or dictionary by looking ahead for a key/value pair
  def parse_dictionary_array?
    found = @scanner.match?(/\{\s*([^{}="]*|"[^{}="]*")\s*=/m)
    return parse_dictionary if found
    return parse_array if @scanner.match?(/\{/)
    return nil
  end

  #rule(:identifier) { match('[a-zA-Z]') >> match('[a-zA-Z0-9_:.]').repeat }
  def parse_identifier?
    identifier = @scanner.scan(/[a-zA-Z@][a-zA-Z0-9_:.']*/)
    return nil unless identifier

    return identifier.to_sym
  end

  #rule(:value)      { (string | float | dictionary | array | identifier) >> space? }
  def parse_value?
    parse_space?

    value = nil

    value ||= parse_string?
    value ||= parse_float?
    value ||= parse_integer?
    value ||= parse_identifier?
    value ||= parse_dictionary_array?

    return value
  end

  def parse_value
    #bark
    value = parse_value?

    parser_error unless value

    return value
  end

  #rule(:equals)     { match('=') }
  def parse_equals?
    parse_space?
    return nil unless @scanner.scan(/\s*=\s*/m)
    return :'='
  end

  #rule(:key)        { identifier | float | equals }
  def parse_key?
    parse_space?

    key = nil
    key ||= parse_identifier?
    key ||= parse_float?
    key ||= parse_integer?
    key ||= parse_string?
    key ||= parse_equals?

    return key
  end

  #rule(:keyvalue)   { key >> equals >> value >> space? }
  def parse_keyvalue?
    key = parse_key?
    return nil unless key

    parser_error unless parse_equals?
    value = parse_value
    parser_error unless value

    return [ key, value ]
  end

  def parse_keyvalues
    ret = Hash.new { |h,k| h[k] = [] }

    while @scanner.rest?
      key, value = parse_keyvalue?
      break unless value
      ret[key] << value
      parse_space
    end

    return ret
  end

  #rule(:save)       { keyvalue.repeat }
  def parse_save
    return parse_keyvalues
  end

  def parse(s)
    @data = s
    @scanner = StringScanner.new(@data)

    return parse_save
    tree = parse_save
    return tree
  end
end

def parse_paradox_format(gamestate)
  return Stellaris.new.parse(gamestate)
end

def read_gamestate(save_file)
  return read_file_from_zip(save_file, 'gamestate')
end

def find_latest_save(subdirectory)
  return Dir.glob("#{ENV['USERPROFILE'].gsub('\\', '/')}/Documents/Paradox Interactive/Stellaris/save games/#{subdirectory}/*.sav").max_by {|f| File.mtime(f)}
end

def find_mod_zip_by_id(mod_id)
  mod_file_name = "#{ENV['USERPROFILE'].gsub('\\', '/')}/Documents/Paradox Interactive/Stellaris/mod/ugc_#{mod_id}.mod"
  mod_file = parse_paradox_format(File.read(mod_file_name))
  return mod_file[:archive][0].gsub('\\', '/')
end

def read_file_from_zip(zip_file_name, path_in_zip)
  Zip.warn_invalid_date = false
  Zip::File.open(zip_file_name) do |zip_file|
    entry = zip_file.get_entry(path_in_zip)
    return entry.get_input_stream.read.force_encoding("UTF-8")
  end
end

