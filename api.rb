require 'sinatra'

require 'net/http'
require 'json'
require 'rack/cors'
require 'dalli'

set :cache, Dalli::Client.new

BASE_URL = "https://api.meetup.com/"
API_KEY  = ENV.fetch('MEETUP_API_KEY')

use Rack::Cors do |config|
  config.allow do |allow|
    allow.origins '*'
    allow.resource '/lunches', headers: :any
  end
end

get '/lunches' do
  content_type :json

  lunches = settings.cache.fetch('lunches', 3600) do
    lunch_hashes = Meetup.events.map { |json| Event.new(json) }.map(&:to_h)
    lunch_hashes.to_json
  end
end

class Meetup
  def self.events(group_name: 'chadevs', status: 'upcoming')
    @events = get_json_data(
      '2/events',
      group_urlname: group_name,
      status: status,
      page: 100
    )
  end

  def self.get_json_data(resource, params)
    uri = initial_uri(resource, params)
    json = fetch_data(uri)
    json[:results]
  end

  def self.initial_uri(resource, params)
    uri = URI("#{BASE_URL}/#{resource}")
    uri.query = URI.encode_www_form(params.merge({ key: API_KEY }))
    uri
  end

  def self.fetch_data(uri)
    res  = Net::HTTP.get_response(uri)
    JSON.parse(res.body, symbolize_names: true)
  end
end

class Event
  attr_reader :id, :name, :time, :description

  def initialize(json)
    @event_json   = json
    @id           = @event_json.fetch(:id)
    @name         = @event_json.fetch(:name)
    @time         = @event_json.fetch(:time)
    @description  = @event_json.fetch(:description) { '' }
  end

  def to_h
    {
      id: @id,
      name: @name,
      time: @time,
      description: @description,
    }
  end
end
