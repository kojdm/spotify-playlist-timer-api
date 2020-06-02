require "dotenv/load"
require_relative "classes/spotify_api"
require_relative "classes/api_objects"

CLIENT_ID = ENV["SPOTIFY_CLIENT_ID"]
CLIENT_SECRET = ENV["SPOTIFY_CLIENT_SECRET"]
REDIRECT_URI = ENV["SPOTIFY_REDIRECT_URI"]

AUTH_SCOPE = %w(user-read-private user-read-email).freeze
SPOTIFY_ACCT_URL = "https://accounts.spotify.com".freeze
SPOTIFY_API_URL = "https://api.spotify.com/v1".freeze

enable :sessions

before do
  headers("Access-Control-Allow-Origin" => SPOTIFY_ACCT_URL)
  init_session!
end

get "/" do
  init_categories! if session_active?

  erb :index, locals: {
    current_user: @current_user,
    categories: @categories || []
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

get "/generate_playlist" do
  return 404 unless session_active?

  time_in_seconds = params["seconds"]
  category_ids = params["category_ids"]
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

  limit = 50 # 1-50
  res = @api.get("/browse/categories?country=#{@current_user["country"]}&limit=#{limit}")

  @categories = []
  res["categories"]["items"].each { |cat|
    @categories << Category.new(
      cat["id"],
      cat["name"],
      cat["icons"].first["url"],
      @api
    )
  }
end

