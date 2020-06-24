require "dotenv/load"
require_relative "classes/spotify_api"
require_relative "classes/api_objects"
require_relative "classes/spoopi"

CLIENT_ID = ENV["SPOTIFY_CLIENT_ID"]
CLIENT_SECRET = ENV["SPOTIFY_CLIENT_SECRET"]
SPOOPI_URL = ENV["SPOOPI_URL"]
CORS_URL = ENV["CORS_URL"]

AUTH_SCOPE = %w(
  user-read-private
  user-read-email
  playlist-modify-public
  playlist-modify-private
).freeze
SPOTIFY_ACCT_URL = "https://accounts.spotify.com".freeze
SPOTIFY_API_URL = "https://api.spotify.com/v1".freeze

# num of objects returned by spotify api
# tracks per category = PLAYLIST_LIMIT * TRACK_LIMIT
CATEGORY_LIMIT = 50.freeze # 1-50
PLAYLIST_LIMIT = 20.freeze # 1-50
TRACK_LIMIT = 100.freeze # 1-100

MIN_DURATION = 900.freeze # 15 mins
MAX_DURATION = 28800.freeze # 8 hours
MAX_CATEGORIES = 5.freeze

set :server, :thin

before do
  headers("Access-Control-Allow-Origin" => CORS_URL)
  init_spoopi_token!
end

get "/" do
  redirect(SPOOPI_URL)
end

get "/authenticate_user" do
  scope = AUTH_SCOPE.join(" ")
  query = {
    response_type: "token",
    client_id: CLIENT_ID,
    scope: scope,
    redirect_uri: SPOOPI_URL,
  }
  querystring = URI.encode_www_form(query)

  redirect(SPOTIFY_ACCT_URL + "/authorize?" + querystring)
end

get "/categories" do
  country_code = params["country_code"]
  api = SpotifyApi.new(@spoopi_token)
  categories = ApiObject.new(api: api).init_categories!(country_code)

  {
    categories: categories.map(&:json_friendly)
  }.to_json
end

get "/generate_tracks" do
  begone! unless (params.keys - ["seconds", "category_ids", "country_code"]).empty? && !params.empty?

  desired_duration = params["seconds"].to_i
  category_ids = params["category_ids"].split(",")
  country_code = params["country_code"]

  begone! unless desired_duration.between?(MIN_DURATION, MAX_DURATION) &&
    category_ids.count.between?(1, MAX_CATEGORIES)

  api = SpotifyApi.new(@spoopi_token)
  spoopi = Spoopi.new(desired_duration, category_ids, country_code, api)
  tracks = spoopi.tracks

  {
    "spoopi": {
      tracks: tracks.map(&:json_friendly),
      track_uris: tracks.map(&:uri).join(","),
      duration: desired_duration,
      category_ids: category_ids.join(",")
    }
  }.to_json
end

post "/create_playlist" do
  params = JSON.parse(request.body.read)
  begone! unless (params.keys - ["access_token", "track_uris", "pl_name", "category_ids"]).empty? && !params.empty?

  access_token = params["access_token"]
  track_uris = params["track_uris"].split(",")
  pl_name = params["pl_name"]
  category_ids = params["category_ids"].split(",")

  api = SpotifyApi.new(access_token)
  user_id = api.get("/me")["id"]

  pl_obj = api.post(
    "/users/#{user_id}/playlists",
    body: {
      name: pl_name,
      description: "Created with Spoopi - Spotify Playlist Timer. [cats: #{category_ids.join(", ")}]",
      public: false
    }.to_json
  )

  new_playlist = Playlist.new(
    id: pl_obj["id"],
    name: pl_obj["name"],
    spotify_url: pl_obj["external_urls"]["spotify"],
    api: api
  )

  split_track_uris = track_uris.each_slice(100).to_a
  split_track_uris.each { |track_uris| new_playlist.add_tracks!(track_uris) }

  {
    new_playlist: new_playlist.json_friendly
  }.to_json
end

private

def random_string(length)
  text = ""
  chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

  length.times do |i|
    text += chars[rand(chars.length)]
  end

  text
end

def begone!
  return halt 400, "begone!"
end

def init_spoopi_token!
  res = SpotifyApi.get_spoopi_token(grant_type: "client_credentials")
  @spoopi_token = res["access_token"]
end

