class HotPlate

  include ActiveRecordHelper
  attr_reader :total_warmups

  def run
    Rails.cache.write(self.class.server_cache_key, ServerRuntime.get_settings["hostname"], :expires_in => 0)
    if Settings.hot_plate.enabled
      warm
    else
      Rails.logger.warn "#{self.class.name} is disabled, skipping warmup"
    end
  end

  def self.ping
    stats = Rails.cache.read(self.cache_key)
    server = Rails.cache.read(self.server_cache_key)
    if stats
      "#{self.name} Running on #{server}; #{stats[:total_warmups]} total warmups requested; #{stats[:total_time]}s total spent warming; last warmup at #{stats[:last_warmup].to_s}"
    else
      "#{self.name} Running on #{server}; Stats are not available"
    end
  end

  def self.cache_key
    'HotPlate/Stats'
  end

  def self.server_cache_key
    'HotPlate/Server'
  end

  def warm
    begin
      start_time = Time.now.to_f
      use_pooled_connection {
        today = Time.zone.today.to_time_in_current_zone.to_datetime
        cutoff = today.advance(:seconds => -1 * Settings.hot_plate.last_visit_cutoff)
        purge_cutoff = today.advance(:seconds => -1 * 2 * Settings.hot_plate.last_visit_cutoff)
        warmups = 0

        visits = UserVisit.where("last_visit_at >= :cutoff", :cutoff => cutoff.to_date)
        Rails.logger.warn "#{self.class.name} Starting to warm up #{visits.size} users; cutoff date #{cutoff}"

        visits.find_in_batches do |batch|
          batch.each do |visit|
            Calcentral::USER_CACHE_EXPIRATION.notify visit.uid
            begin
              UserCacheWarmer.do_warm visit.uid
              warmups += 1
            rescue Exception => e
              Rails.logger.error "#{self.class.name} Got exception while warming cache for user #{visit.uid}: #{e}. Backtrace: #{e.backtrace.join("\n")}"
            end
          end
        end

        end_time = Time.now.to_f
        time = end_time - start_time

        stats = Rails.cache.fetch(self.class.cache_key, :expires_in => 0) do
          {
            :total_warmups => 0,
            :total_time => 0,
            :last_warmup => ''
          }
        end

        Rails.cache.write(self.class.cache_key, {
          :total_warmups => stats[:total_warmups] + warmups,
          :total_time => stats[:total_time] + time,
          :last_warmup => Time.zone.now
        }, :expires_in => 0)

        Rails.logger.warn "#{self.class.name} Warmed up #{visits.size} users in #{time}s; cutoff date #{cutoff}"

        visits = UserVisit.where("last_visit_at < :cutoff", :cutoff => purge_cutoff.to_date)
        deleted_count = 0
        visits.find_in_batches do |batch|
          batch.each do |visit|
            Calcentral::USER_CACHE_EXPIRATION.notify visit.uid
            visit.delete
            deleted_count += 1
          end
        end
        Rails.logger.warn "#{self.class.name} Purged #{deleted_count} users who have not visited since twice the cutoff interval; date #{purge_cutoff}"
      }

    ensure
      ActiveRecord::Base.clear_active_connections!
    end

  end

end

