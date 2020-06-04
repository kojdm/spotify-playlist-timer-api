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
PLAYLIST_LIMIT = 50.freeze # 1-50
TRACK_LIMIT = 100.freeze # 1-100

enable :sessions

before do
  headers("Access-Control-Allow-Origin" => SPOTIFY_ACCT_URL)
  init_session!
end

get "/" do
  init_categories! if session_active?

  erb :index, locals: {
    current_user: @current_user,
    categories: @categories || [],
    base_url: request.base_url
  }
end

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
  code = params["code"]
  state = params["state"]

  res = SpotifyApi.post_token(code, state)

  access_token = res["access_token"]
  refresh_token = res["refresh_token"]

  api = SpotifyApi.new(access_token)
  user = api.get("/me")

  session[:user] = user.to_h
  session[:access_token] = access_token
  redirect("/")
end

get "/generate_tracks" do
  redirect("/") unless session_active?

  desired_duration = params["seconds"].to_i
  category_ids = params["category_ids"].split(",")

  spoopi = Spoopi.new(desired_duration, category_ids, @api)
  track_uris = spoopi.tracks.map(&:uri)

  p = {
    :track_uris => track_uris.join(","),
    :pl_name => params["playlist_name"]
  }

  redirect("/create_playlist?" + URI.encode_www_form(p))
  # HTTParty.post(
  #   request.base_url + "/create_playlist",
  #   body: p
  # )
end

post "/create_playlist" do
  binding.pry
  redirect("/") unless session_active?

  binding.pry
  track_uris = params["track_uris"].split(",")
  pl_name = params["pl_name"]

  binding.pry
  pl_obj = @api.post(
    "/users/#{@current_user["id"]}/playlists",
    body: {
      name: pl_name,
      description: "Created with Spoopi - Spotify Playlist Timer",
      public: false
    }.to_json
  )
  binding.pry

  new_playlist = Playlist.new(
    id: pl_obj["id"],
    name: pl_obj["name"],
    api: @api
  )

  binding.pry
  new_playlist.add_tracks!(track_uris)
  redirect("/")
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

def session_active?
  !session[:user].nil? && !session[:access_token].nil?
end

def init_session!
  return unless session_active?

  @current_user = session[:user]
  @api = SpotifyApi.new(session[:access_token])
end

def init_categories!
  return unless session_active?

  @categories = ApiObject.new(api: @api).init_categories!(@current_user["country"])
end

