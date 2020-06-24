class SpoopiTracker
  class << self
    def add_stat(category_ids, country_code, duration, track_count)
      CSV.open("spoopi_stats.csv", "ab") do |csv|
        csv << [category_ids, country_code, duration, track_count]
      end
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
  end
end
