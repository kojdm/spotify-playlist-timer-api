class Spoopi
  def initialize(duration, category_ids, api)
    @duration = duration
    @category_ids = category_ids
    @api = api
  end

  def tracks
    @tracks ||= get_tracks!
  end

  private

  def get_tracks!
    # master_hash contains all tracks for each @category_id. hash pattern is:
    # { category_id => { track_id1 => Track1, track_id2 => Track2, ... } }
    master_hash = @category_ids.each_with_object({}) do |cat_id, h|
      h[cat_id] = {} if h[cat_id].nil?

      cat = Category.new(id: cat_id, api: @api)
      cat.playlists.flat_map(&:tracks).each do |tr|
        h[cat_id][tr.id] = tr
      end
    end

    # durations_hash contains all track_ids and track_durations sorted by category_id
    # for this request. track_ids are accessible by track_duration. hash pattern is:
    # { category_id => { track_duration => [ track_id1, track_id2, ... ] } }
    durations_hash = @category_ids.each_with_object({}) do |cat_id, h|
      h[cat_id] = {} if h[cat_id].nil?

      tracks = master_hash[cat_id].values
      tracks.each do |tr|
        h[cat_id][tr.duration] = [] if h[cat_id][tr.duration].nil?
        h[cat_id][tr.duration] << tr.id
      end
    end

    duration_per_category = (@duration / @category_ids.count).round

    chosen_track_ids = @category_ids.flat_map do |cat_id|
      durations = durations_hash[cat_id].keys
      correct_durations = subsetsum(durations.shuffle, duration_per_category)

      #TODO: need to implement a failsafe for when subsetsum returns false

      durations_hash[cat_id].values_at(*correct_durations).map(&:sample)
    end

    master_hash.values.reduce({}, :merge).values_at(*chosen_track_ids)
  end

  # subset sum solution. takes an array and a sum, finds subset of array
  # whose elements add up to sum. adapted from:
  # https://gist.github.com/joeyates/d98835b9edc1358b8316db4aa7e7f651
  def subsetsum(set, sum)
    col_count = set.count

    # create array table of nil values
    # rows -> 0..sum (all numbers in the sum)
    # columns -> 0..size of set (all numbers in the set)
    rows = Array.new(sum + 1) do
      Array.new(col_count + 1) { nil }
    end

    (rows.count).times do |i|
      (col_count + 1).times do |j|
        if i == 0
          # entire first row gets empty arrays
          rows[i][j] = []
        elsif j == 0
          # entire first column gets false
          rows[i][j] = false
        else # i >= 1 && j >= 1
          rows[i][j] = if rows[i][j - 1]
                         # if cell to the left is not false/nil, take that value
                         rows[i][j - 1]
                       else
                         false
                       end

          # current_sum (i) - current_element >= 0
          current_element = set[j - 1]
          num = i - current_element
          if num >= 0
            rows[i][j] = if rows[i][j]
                           # if current cell is not false/nil, take that value
                           rows[i][j]
                         else # current cell is false/nil
                           subset_solution = rows[num][j - 1]
                           if subset_solution
                             subset_solution + [current_element]
                           else
                             false
                           end
                         end
          end
        end
      end
    end

    rows[sum][col_count]
  end
end
