class ApiObject
  attr_accessor :id, :name, :image_url, :duration, :api

  def initialize(args)
    args.each { |k,v| send("#{k}=", v) }
  end

  def init_categories!(country)
    limit = 50 # 1-50
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
    limit = 5 # 1-50
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
    limit = 10 # 1-100
    res = api.get("/playlists/#{@id}/tracks?limit=#{limit}")

    res["items"].map { |tr|
      Track.new(
        id: tr["track"]["id"],
        name: tr["track"]["name"],
        image_url: tr["track"]["album"]["images"].first["url"],
        duration: tr["track"]["duration_ms"] / 1000, # ms to seconds
        api: api
      )
    }
  end
end

class Track < ApiObject
  def initialize(args)
    super
  end
end

