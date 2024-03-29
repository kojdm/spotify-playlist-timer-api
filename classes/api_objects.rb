class ApiObject
  attr_accessor :id, :name, :artists, :image_url, :duration, :duration_ms, :uri, :spotify_url, :api

  def initialize(args)
    args.each { |k, v| send("#{k}=", v) }
  end

  def init_categories!(country_code = nil)
    query = {
      limit: CATEGORY_LIMIT
    }
    query[:country] = country_code unless country_code.nil? || country_code.empty?
    querystring = URI.encode_www_form(query)
    res = @api.get("/browse/categories?" + querystring)

    res["categories"]["items"].each_with_object([]) do |cat, arr|
      arr << Category.new(
        id: cat["id"],
        name: cat["name"],
        image_url: cat["icons"].first["url"],
        api: @api
      )
    end
  end

  def json_friendly
    instance_variables.reject { |v| v == :@api }.each_with_object({}) do |ivar, h|
      h[ivar[1..-1]] = instance_variable_get(ivar)
    end
  end
end

class Category < ApiObject
  def initialize(args)
    super
  end

  def playlists(country_code = nil)
    return @playlists if defined?(@playlists)

    limit = PLAYLIST_LIMIT
    query = {
      limit: limit,
      offset: rand(0..20),
    }
    query[:country] = country_code unless country_code.nil? || country_code.empty?
    querystring = URI.encode_www_form(query)
    res = @api.get("/browse/categories/#{id}/playlists?" + querystring)

    playlists = if res["playlists"]["items"].empty?
                  new_offset = res["playlists"]["total"] > limit ? rand(0..res["playlists"]["total"] - limit) : 0
                  new_res = @api.get("/browse/categories/#{id}/playlists?limit=#{limit}&offset=#{new_offset}")
                  new_res["playlists"]["items"]
                else
                  res["playlists"]["items"]
                end

    @playlists = playlists.map do |pl|
      Playlist.new(
        id: pl["id"],
        name: pl["name"],
        api: @api
      )
    end
  end
end

class Playlist < ApiObject
  def initialize(args)
    super
  end

  def tracks
    return @tracks if defined?(@tracks)

    limit = TRACK_LIMIT
    offset = rand(1..50)
    res = @api.get("/playlists/#{@id}/tracks?limit=#{limit}&offset=#{offset}")

    tracks = if res["items"].empty?
               new_offset = res["total"] > limit ? rand(0..res["total"] - limit) : 0
               new_res = @api.get("/playlists/#{@id}/tracks?limit=#{limit}&offset=#{new_offset}")
               new_res["items"]
             else
               res["items"]
             end

    @tracks = tracks.filter_map do |tr|
      tr = tr["track"]
      next if tr.nil? # some tracks would be empty (spotify api problem not mine)

      Track.new(
        id: tr["id"],
        name: tr["name"],
        artists: tr.dig("album", "artists")&.map { |a| a&.dig("name")},
        image_url: tr.dig("album", "images")&.first&.dig("url"),
        duration: (tr["duration_ms"] / 1000.0).round, # ms to seconds
        duration_ms: tr["duration_ms"], # actual duration
        uri: tr["uri"],
        api: @api
      )
    end
  end

  def add_tracks!(track_uris)
    body = {
      uris: track_uris
    }
    @api.post("/playlists/#{@id}/tracks", body: body.to_json)
  end
end

class Track < ApiObject
  def initialize(args)
    super
  end
end

