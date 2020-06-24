class SpoopiTracker
  class << self
    def add_stat(category_ids, country_code, duration, track_count)
      CSV.open("spoopi_stats.csv", "ab") do |csv|
        csv << [category_ids, country_code, duration, track_count]
      end
    end
  end
end
