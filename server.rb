require "dotenv/load"
require_relative "classes/spotify_api"
require_relative "classes/api_objects"

CLIENT_ID = ENV["SPOTIFY_CLIENT_ID"]
CLIENT_SECRET = ENV["SPOTIFY_CLIENT_SECRET"]
REDIRECT_URI = ENV["SPOTIFY_REDIRECT_URI"]

AUTH_SCOPE = %w(user-read-private user-read-email).freeze
SPOTIFY_ACCT_URL = "https://accounts.spotify.com".freeze
SPOTIFY_API_URL = "https://api.spotify.com/v1".freeze

# num of objects returned by spotify api
CATEGORY_LIMIT = 50.freeze # 1-50
PLAYLIST_LIMIT = 5.freeze # 1-50
TRACK_LIMIT = 10.freeze # 1-100

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

get "/gp" do
  redirect("/") unless session_active?

  # desired_duration = params["seconds"]
  # category_ids = params["category_ids"]
  desired_duration = 1800 # 30 mins
  category_ids = ["opm", "chill", "jazz"]

  # master_hash contains all track_ids and track_durations sorted by category_id
  # for this request. track_ids are accessible by track_duration. hash pattern is:
  # { category_id => { track_duration => [ track_ids ] } }
  master_hash = category_ids.each_with_object({}) do |cat_id, h|
    Category.new(id: cat_id, api: @api).playlists.each do |pl|
      h[cat_id] = {} if h[cat_id].nil?

      pl.tracks.each do |tr|
        h[cat_id][tr.duration] = [] if h[cat_id][tr.duration].nil?

        h[cat_id][tr.duration] << tr.id
      end
    end
  end

  duration_per_category = (desired_duration / category_ids.count).round

  category_ids.each do |cat_id|
    durations = master_hash[cat_id].keys

    correct_durations = subsetsum(durations.shuffle, duration_per_category)
  end

  # need to implement a failsafe for when subsetsum returns false
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

# subset sum solution. takes an array and a sum, finds subset of array
# whose elements add up to sum. adapted from:
# https://gist.github.com/joeyates/d98835b9edc1358b8316db4aa7e7f651
def subsetsum(set, sum)
  col_count = set.count

  # create array table of nil values
  # rows -> 0..sum (all numbers in the sum)
  # columns -> 0..size of set (all numbers in the set)
  rows = Array.new(sum + 1) do
    Array.new(col_count + 1) { nil }
  end

  (rows.count).times do |i|
    (col_count + 1).times do |j|
      if i == 0
        # entire first row gets empty arrays
        rows[i][j] = []
      elsif j == 0
        # entire first column gets false
        rows[i][j] = false
      else # i >= 1 && j >= 1
        rows[i][j] = if rows[i][j - 1]
          # if cell to the left is not false/nil, take that value
          rows[i][j - 1]
        else
          false
        end

        # current_sum (i) - current_element >= 0
        current_element = set[j - 1]
        num = i - current_element
        if num >= 0
          rows[i][j] = if rows[i][j]
            # if current cell is not false/nil, take that value
            rows[i][j]
          else # current cell is false/nil
            subset_solution = rows[num][j - 1]
            if subset_solution
              subset_solution + [current_element]
            else
              false
            end
          end
        end
      end
    end
  end

  rows[sum][col_count]
end

