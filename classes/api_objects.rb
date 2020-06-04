class ApiObject
  attr_accessor :id, :name, :image_url, :duration, :uri, :api

  def initialize(args)
    args.each { |k,v| send("#{k}=", v) }
  end

  def init_categories!(country)
    limit = CATEGORY_LIMIT
    res = api.get("/browse/categories?country=#{country}&limit=#{limit}")

    res["categories"]["items"].each_with_object([]) { |cat, arr|
      arr << Category.new(
        id: cat["id"],
        name: cat["name"],
        image_url: cat["icons"].first["url"],
        api: api
      )
    }
  end
end

class Category < ApiObject
  def initialize(args)
    super
  end

  def playlists
    limit = PLAYLIST_LIMIT
    res = api.get("/browse/categories/#{id}/playlists?limit=#{limit}")

    res["playlists"]["items"].map { |pl|
      Playlist.new(
        id: pl["id"],
        name: pl["name"],
        api: api
      )
    }
  end
end

class Playlist < ApiObject
  def initialize(args)
    super
  end

  def tracks
    limit = TRACK_LIMIT
    res = api.get("/playlists/#{@id}/tracks?limit=#{limit}")

    res["items"].map { |tr|
      tr = tr["track"]
      Track.new(
        id: tr["id"],
        name: tr["name"],
        image_url: tr["album"]["images"].first["url"],
        duration: tr["duration_ms"] / 1000, # ms to seconds
        uri: tr["uri"],
        api: api
      )
    }
  end

  def add_tracks!(track_uris)
    body = {
      uris: track_uris
    }
    api.post("/playlists/#{@id}/tracks", body: body.to_json)
  end
end

class Track < ApiObject
  def initialize(args)
    super
  end
end

