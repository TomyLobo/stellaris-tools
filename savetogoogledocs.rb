#!/usr/bin/env ruby

require_relative './saveparser.rb'

require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require 'fileutils'
require 'json'

def column_id(column_index)
  ('A'..'ZZZZ').first(column_index + 1).last
end

def row_id(row_index)
  row_index + 1
end

config = JSON.parse(File.read('config.json'))

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
APPLICATION_NAME = 'Google Sheets API Ruby Quickstart'
CLIENT_SECRETS_PATH = 'client_id.json'
CREDENTIALS_PATH = File.join(Dir.home, '.credentials', "sheets.googleapis.com-ruby-quickstart.yaml")
SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS#_READONLY

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

  client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts "Open the following URL in the browser and enter the resulting code after authorization"
    puts url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(user_id: user_id, code: code, base_url: OOB_URI)
  end
  credentials
end

# Initialize the API
service = Google::Apis::SheetsV4::SheetsService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

spreadsheet_id = config['spreadsheet_id']

# Parse the save
save = parse_paradox_format(read_gamestate(find_latest_save(config['save_id'])))

# Analyze the save
country_id = config['country_id']

all_planets = save[:planet][0]
  .select { |planet_id, planet| planet[0] != :none }
all_pops = save[:pop][0]
all_species = save[:species][0]

empire_planets = all_planets
  .select { |planet_id, planet| planet[0][:owner][0] == country_id }

planets_species = empire_planets
  .map do |planet_id, planet|
    [
      planet[0][:name][0],
      planet[0][:tiles][0]
        .map { |tile_id, tile| tile[0][:pop][0] }
            .map { |pop_id| all_pops[pop_id][0] }
            .reject { |pop| pop == :none }
            .select { |pop| pop != nil }
            .select { |pop| pop[:growth_state][0] != 0 }
            .map { |pop| pop[:species_index][0] }
            .map { |species_index| all_species[species_index] }
            .map { |species| species[:name][0] }
    ]
  end

empire_species = planets_species
  .map(&:last)
  .flatten
  .uniq
  .sort

# Generate report
values = [
  [ 'planet', *empire_species ],
  *(
    planets_species.map do |planet_name, planet_species|
      [
        planet_name,
        *(
          empire_species
            .map { |species| planet_species.count(species) }
        )
      ]
    end
  )
]

# Store to Google Sheet
ncolumns = values.first.length
nrows = values.length

range_name = "rubytest!A1:#{column_id(ncolumns-1)}#{row_id(nrows-1)}"

value_range_object = Google::Apis::SheetsV4::ValueRange.new(range: range_name, values: values)
result = service.update_spreadsheet_value(spreadsheet_id, range_name, value_range_object, value_input_option: :RAW)
puts "#{result.updated_cells} cells updated."


