require "dotenv/load"
require_relative "classes/spotify_api"
require_relative "classes/api_objects"
require_relative "classes/spoopi"

CLIENT_ID = ENV["SPOTIFY_CLIENT_ID"]
CLIENT_SECRET = ENV["SPOTIFY_CLIENT_SECRET"]
REDIRECT_URI = ENV["SPOTIFY_REDIRECT_URI"]

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
PLAYLIST_LIMIT = 25.freeze # 1-50
TRACK_LIMIT = 100.freeze # 1-100

MIN_DURATION = 900.freeze # 15 mins
MAX_DURATION = 43200.freeze # 12 hours
MAX_CATEGORIES = 5.freeze

before do
  headers("Access-Control-Allow-Origin" => SPOTIFY_ACCT_URL)
  headers("Access-Control-Allow-Origin" => SPOTIFY_API_URL)
  # init_session!
end

# get "/" do
#   init_categories! if session_active?

#   erb :index, locals: {
#     current_user: @current_user,
#     categories: @categories || [],
#     base_url: request.base_url
#   }
# end

get "/login" do
  state = random_string(16)
  scope = AUTH_SCOPE.join(" ")
  query = {
    response_type: "code",
    client_id: CLIENT_ID,
    scope: scope,
    redirect_uri: REDIRECT_URI,
    state: state
  }
  querystring = URI.encode_www_form(query)

  redirect(SPOTIFY_ACCT_URL + "/authorize?" + querystring)
end

get "/callback" do
  begone! unless (params.keys - ["code", "state"]).empty?

  code = params["code"]
  state = params["state"]

  res = SpotifyApi.post_token(code, state)

  access_token = res["access_token"]
  _refresh_token = res["refresh_token"]

  api = SpotifyApi.new(access_token)
  user = api.get("/me").to_h
  categories = ApiObject.new(api: api).init_categories!(user["country"])

  {
    user: user,
    categories: categories.map(&:json_friendly),
    access_token: access_token,
  }.to_json
end

get "/generate_tracks" do
  access_token = request.env["HTTP_AUTHORIZATION"]
  begone! unless (params.keys - ["seconds", "category_ids"]).empty? || access_token.nil?

  access_token = access_token.split(" ").last
  desired_duration = params["seconds"].to_i
  category_ids = params["category_ids"].split(",")

  begone! unless desired_duration.between?(MIN_DURATION, MAX_DURATION) ||
    category_ids.count.between?(1, MAX_CATEGORIES)

  api = SpotifyApi.new(access_token)
  spoopi = Spoopi.new(desired_duration, category_ids, api)
  tracks = spoopi.tracks

  {
    tracks: tracks.map(&:json_friendly),
    track_uris: tracks.map(&:uri).join(",")
  }.to_json
end

post "/create_playlist" do
  access_token = request.env["HTTP_AUTHORIZATION"]
  begone! unless (params.keys - ["user_id", "track_uris", "pl_name", "category_ids"]).empty? || access_token.nil?

  access_token = access_token.split(" ").last
  user_id = params["user_id"]
  track_uris = params["track_uris"].split(",")
  pl_name = params["pl_name"]
  category_ids = params["category_ids"]

  api = SpotifyApi.new(access_token)

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

# def session_active?
#   !session[:user].nil? && !session[:access_token].nil?
# end

# def init_session!
#   return unless session_active?

#   @current_user = session[:user]
#   @api = SpotifyApi.new(session[:access_token])
# end

# def init_categories!
#   return unless session_active?

#   @categories = ApiObject.new(api: @api).init_categories!(@current_user["country"])
# end


