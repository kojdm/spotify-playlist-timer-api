class ApiObject
  attr_reader :api

  def initialize(api)
    @api = api
  end
end

class Category < ApiObject
  attr_reader :id, :name, :image_url

  def initialize(id, name, image_url, api)
    @id = id
    @name = name
    @image_url = image_url
    super(api)
  end

  def playlists
    limit = 5 # 1-50
    res = api.get("/browse/categories/#{id}/playlists?limit=#{limit}")

    res["playlists"]["items"].map { |pl|
      Playlist.new(
        pl["id"],
        pl["name"],
        api
      )
    }
  end
end

class Playlist < ApiObject
  def initialize(id, name, api)
    @id = id
    @name = name
    super(api)
  end

  def tracks
    limit = 10 # 1-100
    res = api.get("/playlists/#{@id}/tracks?limit=#{limit}")

    res["items"].map { |tr|
      Track.new(
        tr["track"]["id"],
        tr["track"]["name"],
        tr["track"]["album"]["images"].first["url"],
        tr["track"]["duration_ms"],
        api
      )
    }
  end
end

class Track < ApiObject
  attr_reader :id, :name, :image_url, :duration

  def initialize(id, name, image_url, duration, api)
    @id = id
    @name = name
    @image_url = image_url
    @duration = duration / 1000 # ms to seconds
    super(api)
  end
end

