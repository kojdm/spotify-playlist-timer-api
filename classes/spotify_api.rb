class SpotifyApi
  def initialize(access_token)
    @access_token = access_token
  end

  def get(endpoint)
    HTTParty.get(SPOTIFY_API_URL + endpoint, headers: headers)
  end

  def post(endpoint)
    HTTParty.post(SPOTIFY_API_URL + endpoint, headers: headers)
  end

  def self.post_token(code, _state)
    body = {
      code: code,
      redirect_uri: REDIRECT_URI,
      grant_type: "authorization_code"
    }
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

