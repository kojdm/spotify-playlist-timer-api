require "dotenv/load"
require "google_drive"

GOOGLE_CLIENT_SECRET = ENV["GOOGLE_CLIENT_SECRET"]

class SpoopiTrackerWorker
  include Sidekiq::Worker

  def perform(*args)
    SpoopiTracker.add_stat(*args)
  end
end

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
  end
end
