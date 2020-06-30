class SpoopiTracker
  class << self
    def add_stat(date, category_ids, country_code, duration, track_count)
      gcs_io = StringIO.new(GOOGLE_CLIENT_SECRET)
      session = GoogleDrive::Session.from_service_account_key(gcs_io)

      spreadsheet = session.spreadsheet_by_title("Spoopi Stats Tracker")
      worksheet = spreadsheet.worksheets.first

      worksheet.insert_rows(worksheet.num_rows + 1, [[ date, category_ids, country_code, duration, track_count ]])
      worksheet.save
    end

    def get_stats
      stats_hash = {
        spoopi_stats: {
          total_playlists_created: 0,
          total_duration_of_playlists: 0,
          total_tracks_in_playlists: 0,
          country_stats: {},
          category_stats: {}
        }
      }
      CSV.foreach("spoopi_stats.csv") do |row|
        stats_hash[:spoopi_stats][:total_playlists_created] += 1
        stats_hash[:spoopi_stats][:total_duration_of_playlists] += row[2].to_i
        stats_hash[:spoopi_stats][:total_tracks_in_playlists] += row[3].to_i

        country_count = stats_hash[:spoopi_stats][:country_stats][row[1]] || 0
        stats_hash[:spoopi_stats][:country_stats][row[1]] = country_count + 1

        categories = row[0].split("|")
        categories.each do |cat|
          category_count = stats_hash[:spoopi_stats][:category_stats][cat] || 0
          stats_hash[:spoopi_stats][:category_stats][cat] = category_count + 1
        end
      end

      stats_hash
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
  end
end
