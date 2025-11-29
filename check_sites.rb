#!/usr/bin/env ruby

require 'yaml'
require 'net/http'
require 'net/smtp'
require 'uri'
require_relative 'uptime_tracker'

class SiteChecker
  def initialize(config_file = 'config.yml')
    @config = YAML.load_file(config_file)
    @failures = []
    @results = []
    @uptime_tracker = UptimeTracker.new
  end

  def check_all_sites
    puts "Checking #{@config['sites'].length} sites..."

    @config['sites'].each do |site|
      check_site(site)
    end

    if @failures.any?
      puts "\n#{@failures.length} site(s) failed the check"
      send_notification
    else
      puts "\nAll sites passed the check!"
    end

    log_last_run
  end

  def send_test_email
    email_config = @config['email']

    unless email_config
      puts "Error: No email configuration found in config file"
      exit 1
    end

    puts "Sending test email to #{email_config['to']}..."

    subject = "Site Checker Test Email"
    body = build_test_email_body

    begin
      send_email(
        from: email_config['from'],
        to: email_config['to'],
        subject: subject,
        body: body,
        smtp_server: email_config['smtp_server'],
        smtp_port: email_config['smtp_port'],
        username: email_config['username'],
        password: email_config['password']
      )
      puts "Test email sent successfully!"
      puts "Check #{email_config['to']} for the test message."
    rescue StandardError => e
      puts "Failed to send test email: #{e.message}"
      exit 1
    end
  end

  private

  def check_site(site)
    name = site['name'] || site['url']
    url = site['url']
    expected_string = site['expected_string']

    print "Checking #{name}... "

    begin
      start_time = Time.now
      uri = URI.parse(url)
      response = fetch_with_redirects(uri)
      response_time = ((Time.now - start_time) * 1000).round # in milliseconds

      if response.is_a?(Net::HTTPSuccess)
        if response.body.include?(expected_string)
          puts "OK (#{response_time}ms)"
          @results << {
            name: name,
            status: "OK"
          }
          @uptime_tracker.record_check_with_timing(name, url, 'up', response_time)
        else
          error_msg = "Expected string not found in response"
          puts "FAILED - String '#{expected_string}' not found"
          @failures << {
            name: name,
            url: url,
            expected_string: expected_string,
            reason: error_msg
          }
          @results << {
            name: name,
            status: "FAILED - String '#{expected_string}' not found"
          }
          @uptime_tracker.record_check_with_timing(name, url, 'down', response_time, error_msg)
        end
      else
        error_msg = "HTTP error: #{response.code} #{response.message}"
        puts "FAILED - HTTP #{response.code}"
        @failures << {
          name: name,
          url: url,
          expected_string: expected_string,
          reason: error_msg
        }
        @results << {
          name: name,
          status: "FAILED - HTTP #{response.code}"
        }
        @uptime_tracker.record_check_with_timing(name, url, 'down', response_time, error_msg)
      end
    rescue StandardError => e
      error_msg = "Error: #{e.message}"
      puts "FAILED - #{e.message}"
      @failures << {
        name: name,
        url: url,
        expected_string: expected_string,
        reason: error_msg
      }
      @results << {
        name: name,
        status: "FAILED - #{e.message}"
      }
      @uptime_tracker.record_check(name, url, 'down', error_msg)
    end
  end

  def fetch_with_redirects(uri, limit = 10)
    raise 'Too many HTTP redirects' if limit == 0

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri.request_uri)
    request['User-Agent'] = 'SiteChecker/1.0'

    response = http.request(request)

    case response
    when Net::HTTPRedirection
      location = URI.parse(response['location'])
      location = uri + location if location.relative?
      fetch_with_redirects(location, limit - 1)
    else
      response
    end
  end

  def send_notification
    email_config = @config['email']

    unless email_config
      puts "No email configuration found. Skipping notification."
      return
    end

    subject = "Site Check Alert: #{@failures.length} site(s) failed"
    body = build_email_body

    begin
      send_email(
        from: email_config['from'],
        to: email_config['to'],
        subject: subject,
        body: body,
        smtp_server: email_config['smtp_server'],
        smtp_port: email_config['smtp_port'],
        username: email_config['username'],
        password: email_config['password']
      )
      puts "Notification email sent successfully"
    rescue StandardError => e
      puts "Failed to send email: #{e.message}"
    end
  end

  def build_email_body
    body = "Site Check Report\n"
    body += "=" * 50 + "\n\n"
    body += "The following sites failed the check:\n\n"

    @failures.each_with_index do |failure, index|
      body += "#{index + 1}. #{failure[:name]}\n"
      body += "   URL: #{failure[:url]}\n"
      body += "   Expected String: '#{failure[:expected_string]}'\n"
      body += "   Reason: #{failure[:reason]}\n\n"
    end

    body += "\nPlease investigate these issues.\n"
    body
  end

  def build_test_email_body
    body = "Site Checker Test Email\n"
    body += "=" * 50 + "\n\n"
    body += "This is a test email from the Site Checker script.\n\n"
    body += "Email configuration is working correctly!\n\n"
    body += "Configuration details:\n"
    body += "  SMTP Server: #{@config['email']['smtp_server']}\n"
    body += "  SMTP Port: #{@config['email']['smtp_port']}\n"
    body += "  From: #{@config['email']['from']}\n"
    body += "  To: #{@config['email']['to']}\n\n"
    body += "Monitored sites (#{@config['sites'].length}):\n"
    @config['sites'].each_with_index do |site, index|
      body += "  #{index + 1}. #{site['name'] || site['url']}\n"
    end
    body += "\nYou can now use this script to monitor your sites.\n"
    body
  end

  def send_email(from:, to:, subject:, body:, smtp_server:, smtp_port:, username:, password:)
    message = <<~MESSAGE
      From: #{from}
      To: #{to}
      Subject: #{subject}

      #{body}
    MESSAGE

    Net::SMTP.start(smtp_server, smtp_port, 'localhost', username, password, :login) do |smtp|
      smtp.send_message(message, from, to)
    end
  end

  def log_last_run
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    content = timestamp + "\n"

    @results.each do |result|
      content += "#{result[:name]}: #{result[:status]}\n"
    end

    File.write('.last_run.txt', content)
  end
end

# Main execution
if __FILE__ == $0
  # Parse command-line arguments
  test_email_mode = ARGV.include?('--test-email')
  config_file = ARGV.find { |arg| !arg.start_with?('--') } || 'config.yml'

  unless File.exist?(config_file)
    puts "Error: Configuration file '#{config_file}' not found"
    puts "Usage: ruby check_sites.rb [config_file] [--test-email]"
    puts ""
    puts "Options:"
    puts "  --test-email    Send a test email to verify email configuration"
    exit 1
  end

  checker = SiteChecker.new(config_file)

  if test_email_mode
    checker.send_test_email
  else
    checker.check_all_sites
  end
end
