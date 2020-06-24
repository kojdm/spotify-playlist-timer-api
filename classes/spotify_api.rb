class SpotifyApi
  def initialize(access_token)
    @access_token = access_token
  end

  def get(endpoint)
    res = HTTParty.get(SPOTIFY_API_URL + endpoint, headers: headers)

    if res.code == 429
      sleep(res.headers["retry-after"].to_i + 1)
      res = HTTParty.get(SPOTIFY_API_URL + endpoint, headers: headers)
    end

    res
  end

  def post(endpoint, body:)
    HTTParty.post(SPOTIFY_API_URL + endpoint, body: body, headers: headers)
  end

  def self.get_spoopi_token(grant_type:)
    body = { grant_type: grant_type }
    token_headers = {
      "Authorization": "Basic " + Base64.urlsafe_encode64(CLIENT_ID + ":" + CLIENT_SECRET)
    }

    HTTParty.post(SPOTIFY_ACCT_URL + "/api/token", body: body, headers: token_headers)
  end

  private

  def headers
    {
      "Authorization": "Bearer " + @access_token
    }
  end
end

