class Spoopi
  def initialize(duration, category_ids, country_code, api)
    @duration = duration
    @category_ids = category_ids
    @country_code = country_code
    @api = api
  end

  def tracks
    @tracks ||= begin
                  generate_tracks!
                rescue StandardError => e
                  puts e.message
                  puts e.backtrace
                  []
                end
  end

  private

  def generate_tracks!
    # master_hash contains all tracks for each @category_id. hash pattern is:
    # { category_id => { track_id1 => Track1, track_id2 => Track2, ... } }
    master_hash = {}
    Parallel.each(@category_ids, in_threads: @category_ids.count) do |cat_id|
      master_hash[cat_id] = {} if master_hash[cat_id].nil?

      category = Category.new(id: cat_id, api: @api)
      category.playlists(@country_code).flat_map(&:tracks).each do |tr|
        master_hash[cat_id][tr.id] = tr
      end
    end

    # durations_hash contains all track_ids and track_durations sorted by category_id
    # for this request. track_ids are accessible by track_duration. hash pattern is:
    # {
    #   category_id => {
    #     track_duration => [ track_id1, track_id2, ... ],
    #     all_durations => [ 180, 180, ... ]
    #   },
    #   totals => {
    #     category_id => total_duration
    #     grand_total => grand_total_duration
    #   }
    # }
    durations_hash = @category_ids.each_with_object({}) do |cat_id, h|
      h[cat_id] = {} if h[cat_id].nil?

      tracks = master_hash[cat_id].values
      tracks.each do |tr|
        h[cat_id][tr.duration] = [] if h[cat_id][tr.duration].nil?
        h[cat_id][tr.duration] << tr.id

        h[cat_id]["all_durations"] = [] if h[cat_id]["all_durations"].nil?
        h[cat_id]["all_durations"] << tr.duration
      end

      total_cat_duration = h[cat_id]["all_durations"].sum

      h["totals"] = {} if h["totals"].nil?
      h["totals"][cat_id] = total_cat_duration

      h["totals"]["grand_total"] = 0 if h["totals"]["grand_total"].nil?
      h["totals"]["grand_total"] += total_cat_duration
    end

    duration_per_category = @category_ids.each_with_object({}) do |cat_id, h|
      total_d = durations_hash["totals"]["grand_total"]
      total_cat_d = durations_hash["totals"][cat_id]
      weight = total_cat_d.to_f / total_d

      h[cat_id] = (@duration * weight).round
    end

    fallback_duration_per_category = (@duration / @category_ids.count).round
    use_fallback = false
    chosen_track_ids = @category_ids.flat_map do |cat_id|
      durations = durations_hash[cat_id]["all_durations"]
      subset = subsetsum(durations.shuffle, duration_per_category[cat_id])

      if subset
        correct_durations = subset
      else
        use_fallback = true
        break
      end

      correct_durations.tally.flat_map do |dur, occurrences|
        durations_hash[cat_id][dur].sample(occurrences)
      end
    end

    if use_fallback
      chosen_track_ids = @category_ids.flat_map do |cat_id|
        durations = durations_hash[cat_id]["all_durations"]
        correct_durations = subsetsum(durations.shuffle, fallback_duration_per_category)

        #TODO: need to implement a failsafe for when subsetsum returns false

        correct_durations.tally.flat_map do |dur, occurrences|
          durations_hash[cat_id][dur].sample(occurrences)
        end
      end
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
