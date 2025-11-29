require 'json'
require 'fileutils'
require 'date'

class UptimeTracker
  DATA_DIR = 'data'
  UPTIME_FILE = File.join(DATA_DIR, 'uptime.json')
  INCIDENTS_FILE = File.join(DATA_DIR, 'incidents.json')
  MAX_HISTORY_DAYS = 90

  def initialize
    FileUtils.mkdir_p(DATA_DIR)
    @uptime_data = load_uptime_data
    @incidents = load_incidents
  end

  def record_check(site_name, url, status, error_message = nil)
    timestamp = Time.now.to_i

    # Initialize site data if it doesn't exist
    @uptime_data[site_name] ||= {
      'url' => url,
      'checks' => []
    }

    # Add the check result
    check_result = {
      'timestamp' => timestamp,
      'status' => status,
      'response_time' => nil
    }
    check_result['error'] = error_message if error_message

    @uptime_data[site_name]['checks'] << check_result

    # Clean old data
    cleanup_old_data(site_name)

    # Update incidents if there's a status change
    update_incidents(site_name, status, timestamp, error_message)

    save_uptime_data
    save_incidents
  end

  def record_check_with_timing(site_name, url, status, response_time, error_message = nil)
    timestamp = Time.now.to_i

    @uptime_data[site_name] ||= {
      'url' => url,
      'checks' => []
    }

    check_result = {
      'timestamp' => timestamp,
      'status' => status,
      'response_time' => response_time
    }
    check_result['error'] = error_message if error_message

    @uptime_data[site_name]['checks'] << check_result
    cleanup_old_data(site_name)
    update_incidents(site_name, status, timestamp, error_message)

    save_uptime_data
    save_incidents
  end

  def get_status_summary
    summary = {}

    @uptime_data.each do |site_name, data|
      checks = data['checks']
      next if checks.empty?

      recent_checks = checks.last(100)
      successful_checks = recent_checks.count { |c| c['status'] == 'up' }
      uptime_percentage = (successful_checks.to_f / recent_checks.length * 100).round(2)

      latest_check = checks.last
      current_status = latest_check['status']

      # Calculate average response time
      response_times = recent_checks.map { |c| c['response_time'] }.compact
      avg_response_time = response_times.empty? ? nil : (response_times.sum / response_times.length).round(0)

      # Get site incidents
      site_incidents = @incidents.select { |i| i['site_name'] == site_name && i['resolved_at'].nil? }

      summary[site_name] = {
        'url' => data['url'],
        'status' => current_status,
        'uptime_percentage' => uptime_percentage,
        'last_checked' => latest_check['timestamp'],
        'last_error' => latest_check['error'],
        'avg_response_time' => avg_response_time,
        'total_checks' => checks.length,
        'active_incidents' => site_incidents.length
      }
    end

    summary
  end

  def get_uptime_history(site_name, days = 90)
    return [] unless @uptime_data[site_name]

    cutoff_time = Time.now.to_i - (days * 24 * 60 * 60)
    checks = @uptime_data[site_name]['checks']

    checks.select { |c| c['timestamp'] >= cutoff_time }
  end

  def get_daily_uptime(site_name, days = 90)
    history = get_uptime_history(site_name, days)
    return [] if history.empty?

    # Group checks by day
    daily_stats = {}

    history.each do |check|
      day = Time.at(check['timestamp']).strftime('%Y-%m-%d')
      daily_stats[day] ||= { 'up' => 0, 'down' => 0 }

      if check['status'] == 'up'
        daily_stats[day]['up'] += 1
      else
        daily_stats[day]['down'] += 1
      end
    end

    # Convert to array with uptime percentages
    daily_stats.map do |day, stats|
      total = stats['up'] + stats['down']
      uptime = total > 0 ? (stats['up'].to_f / total * 100).round(2) : 100.0

      {
        'date' => day,
        'uptime' => uptime,
        'total_checks' => total,
        'up_count' => stats['up'],
        'down_count' => stats['down']
      }
    end.sort_by { |d| d['date'] }
  end

  def get_uptime_bars(site_name, days = 90)
    # Generate all days in the range
    end_date = Date.today
    start_date = end_date - days

    # Get actual check data
    history = get_uptime_history(site_name, days)

    # Group checks by day
    daily_checks = {}
    history.each do |check|
      day = Time.at(check['timestamp']).strftime('%Y-%m-%d')
      daily_checks[day] ||= { 'up' => 0, 'down' => 0 }

      if check['status'] == 'up'
        daily_checks[day]['up'] += 1
      else
        daily_checks[day]['down'] += 1
      end
    end

    # Create bar for each day
    bars = []
    (start_date..end_date).each do |date|
      day_str = date.strftime('%Y-%m-%d')

      if daily_checks[day_str]
        stats = daily_checks[day_str]
        total = stats['up'] + stats['down']
        uptime = (stats['up'].to_f / total * 100).round(2)

        bars << {
          'date' => day_str,
          'status' => stats['down'] > 0 ? 'error' : 'up',
          'uptime' => uptime,
          'up_count' => stats['up'],
          'down_count' => stats['down'],
          'total_checks' => total
        }
      else
        # No data for this day
        bars << {
          'date' => day_str,
          'status' => 'no_data',
          'uptime' => nil,
          'up_count' => 0,
          'down_count' => 0,
          'total_checks' => 0
        }
      end
    end

    bars
  end

  def get_recent_incidents(limit = 10)
    @incidents.sort_by { |i| i['started_at'] }.reverse.take(limit)
  end

  def get_active_incidents
    @incidents.select { |i| i['resolved_at'].nil? }
  end

  private

  def load_uptime_data
    return {} unless File.exist?(UPTIME_FILE)
    JSON.parse(File.read(UPTIME_FILE))
  rescue JSON::ParserError
    {}
  end

  def load_incidents
    return [] unless File.exist?(INCIDENTS_FILE)
    JSON.parse(File.read(INCIDENTS_FILE))
  rescue JSON::ParserError
    []
  end

  def save_uptime_data
    File.write(UPTIME_FILE, JSON.pretty_generate(@uptime_data))
  end

  def save_incidents
    File.write(INCIDENTS_FILE, JSON.pretty_generate(@incidents))
  end

  def cleanup_old_data(site_name)
    cutoff_time = Time.now.to_i - (MAX_HISTORY_DAYS * 24 * 60 * 60)
    @uptime_data[site_name]['checks'].reject! { |c| c['timestamp'] < cutoff_time }
  end

  def update_incidents(site_name, current_status, timestamp, error_message)
    # Check if there's an active incident for this site
    active_incident = @incidents.find do |i|
      i['site_name'] == site_name && i['resolved_at'].nil?
    end

    if current_status == 'down'
      # Start a new incident if there isn't one
      unless active_incident
        @incidents << {
          'id' => generate_incident_id,
          'site_name' => site_name,
          'started_at' => timestamp,
          'resolved_at' => nil,
          'error' => error_message,
          'updates' => []
        }
      end
    elsif current_status == 'up' && active_incident
      # Resolve the active incident
      active_incident['resolved_at'] = timestamp
      duration = timestamp - active_incident['started_at']
      active_incident['duration'] = duration
    end
  end

  def generate_incident_id
    "INC-#{Time.now.to_i}-#{rand(1000..9999)}"
  end
end
