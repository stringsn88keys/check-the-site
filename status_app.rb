#!/usr/bin/env ruby

require 'sinatra'
require 'json'
require_relative 'uptime_tracker'

class StatusApp < Sinatra::Base
  set :bind, '0.0.0.0'
  set :port, 4567

  def initialize
    super
    @tracker = UptimeTracker.new
  end

  # Main status page
  get '/' do
    @summary = @tracker.get_status_summary
    @active_incidents = @tracker.get_active_incidents
    @overall_status = determine_overall_status(@summary)

    erb :index
  end

  # Individual site detail page
  get '/site/:name' do
    site_name = params[:name]
    @site_data = @tracker.get_status_summary[site_name]

    halt 404, "Site not found" unless @site_data

    @site_name = site_name
    @daily_uptime = @tracker.get_daily_uptime(site_name, 90)
    @uptime_bars = @tracker.get_uptime_bars(site_name, 90)
    @history = @tracker.get_uptime_history(site_name, 7)

    erb :site_detail
  end

  # API endpoint for status summary (JSON)
  get '/api/status' do
    content_type :json
    {
      status: determine_overall_status(@tracker.get_status_summary),
      sites: @tracker.get_status_summary,
      active_incidents: @tracker.get_active_incidents,
      timestamp: Time.now.to_i
    }.to_json
  end

  # API endpoint for specific site
  get '/api/site/:name' do
    content_type :json
    site_name = params[:name]
    summary = @tracker.get_status_summary[site_name]

    halt 404, { error: "Site not found" }.to_json unless summary

    {
      name: site_name,
      summary: summary,
      daily_uptime: @tracker.get_daily_uptime(site_name, 90),
      recent_history: @tracker.get_uptime_history(site_name, 7)
    }.to_json
  end

  # Incidents page
  get '/incidents' do
    @recent_incidents = @tracker.get_recent_incidents(50)
    @active_incidents = @tracker.get_active_incidents

    erb :incidents
  end

  private

  def determine_overall_status(summary)
    return 'unknown' if summary.empty?

    down_count = summary.values.count { |s| s['status'] == 'down' }

    if down_count == 0
      'operational'
    elsif down_count == summary.length
      'major_outage'
    else
      'partial_outage'
    end
  end

  def format_duration(seconds)
    return 'N/A' unless seconds

    minutes = seconds / 60
    hours = minutes / 60
    days = hours / 24

    if days > 0
      "#{days}d #{hours % 24}h"
    elsif hours > 0
      "#{hours}h #{minutes % 60}m"
    elsif minutes > 0
      "#{minutes}m"
    else
      "#{seconds}s"
    end
  end

  def format_timestamp(timestamp)
    Time.at(timestamp).strftime('%Y-%m-%d %H:%M:%S')
  end

  def time_ago(timestamp)
    seconds = Time.now.to_i - timestamp

    if seconds < 60
      "#{seconds}s ago"
    elsif seconds < 3600
      "#{seconds / 60}m ago"
    elsif seconds < 86400
      "#{seconds / 3600}h ago"
    else
      "#{seconds / 86400}d ago"
    end
  end

  helpers do
    def format_duration(seconds)
      return 'N/A' unless seconds

      minutes = seconds / 60
      hours = minutes / 60
      days = hours / 24

      if days > 0
        "#{days}d #{hours % 24}h"
      elsif hours > 0
        "#{hours}h #{minutes % 60}m"
      elsif minutes > 0
        "#{minutes}m"
      else
        "#{seconds}s"
      end
    end

    def format_timestamp(timestamp)
      Time.at(timestamp).strftime('%Y-%m-%d %H:%M:%S')
    end

    def time_ago(timestamp)
      seconds = Time.now.to_i - timestamp

      if seconds < 60
        "#{seconds}s ago"
      elsif seconds < 3600
        "#{seconds / 60}m ago"
      elsif seconds < 86400
        "#{seconds / 3600}h ago"
      else
        "#{seconds / 86400}d ago"
      end
    end

    def status_class(status)
      case status
      when 'up', 'operational'
        'status-operational'
      when 'down', 'major_outage'
        'status-critical'
      when 'partial_outage'
        'status-degraded'
      else
        'status-unknown'
      end
    end

    def status_text(status)
      case status
      when 'operational'
        'All Systems Operational'
      when 'partial_outage'
        'Partial System Outage'
      when 'major_outage'
        'Major System Outage'
      else
        'System Status Unknown'
      end
    end

    def uptime_bar_class(uptime)
      if uptime >= 99.9
        'uptime-excellent'
      elsif uptime >= 99.0
        'uptime-good'
      elsif uptime >= 95.0
        'uptime-degraded'
      else
        'uptime-poor'
      end
    end
  end
end

# Run the app if executed directly
if __FILE__ == $0
  StatusApp.run!
end
