# Site Checker

A Ruby script that monitors websites by checking if specific strings are present and sends email notifications when checks fail. Includes a beautiful status page interface similar to Atlassian Statuspage.

## Features

- Check multiple websites from a YAML configuration file
- Verify that expected strings are present on each site
- Handle HTTP redirects automatically
- Send email notifications when sites fail checks
- **Track uptime history and response times**
- **Web-based status page with uptime graphs**
- **Incident tracking and reporting**
- **JSON API for programmatic access**
- Detailed error reporting

## Requirements

- Ruby 2.5 or higher
- Bundler for managing dependencies

## Configuration

Edit `config.yml` to set up your sites and email settings:

```yaml
email:
  from: "monitor@example.com"
  to: "admin@example.com"
  smtp_server: "smtp.gmail.com"
  smtp_port: 587
  username: "your-email@gmail.com"
  password: "your-app-password"

sites:
  - name: "My Website"
    url: "https://www.mysite.com"
    expected_string: "Welcome"
```

### Email Configuration

For Gmail:
1. Enable 2-factor authentication
2. Generate an app password at https://myaccount.google.com/apppasswords
3. Use the app password in the `password` field

For other SMTP servers, adjust the `smtp_server` and `smtp_port` accordingly.

### Site Configuration

Each site entry requires:
- `name`: Friendly name for the site
- `url`: Full URL to check (including http:// or https://)
- `expected_string`: String that must be present in the response

## Installation

Install dependencies:

```bash
bundle install
```

## Usage

### Running Site Checks

Run the script with the default config file:

```bash
./check_sites.rb
```

Or specify a custom config file:

```bash
ruby check_sites.rb path/to/config.yml
```

### Status Page

The status page provides a web interface to view uptime history, incidents, and current status of all monitored sites.

Start the status page server:

```bash
./start_status_page.sh
```

Or run directly:

```bash
ruby status_app.rb
```

The status page will be available at `http://localhost:4567`

#### Status Page Features

- **Dashboard**: Overview of all services with uptime percentages and current status
- **90-Day Uptime History**: Visual bar chart showing daily uptime for each service
- **Incident Tracking**: View active and historical incidents
- **Response Time Monitoring**: Average response times for each service
- **Site Details**: Click on any service to view detailed metrics and check history

#### API Endpoints

The status page also provides JSON API endpoints:

- `GET /api/status` - Overall system status and all sites
- `GET /api/site/:name` - Detailed information for a specific site

Example:
```bash
curl http://localhost:4567/api/status
```

## Output

The script will:
1. Check each site in sequence
2. Print the status of each check to the console with response time
3. Record uptime data to `data/uptime.json`
4. Track incidents in `data/incidents.json`
5. Send an email notification if any sites fail
6. Exit with status 0 (all sites can also exit normally even with failures)

Example output:

```
Checking 3 sites...
Checking Example Site... OK (234ms)
Checking GitHub... OK (156ms)
Checking Google... FAILED - String 'Google' not found

1 site(s) failed the check
Notification email sent successfully
```

## Automation

To run the script on a schedule, add it to cron:

```bash
# Check every 5 minutes
*/5 * * * * cd /path/to/check-the-site && ./check_sites.rb

# Check every hour
0 * * * * cd /path/to/check-the-site && ./check_sites.rb

# Check daily at 9 AM
0 9 * * * cd /path/to/check-the-site && ./check_sites.rb
```

## Error Handling

The script handles various failure scenarios:
- Network errors (timeout, connection refused, etc.)
- HTTP errors (404, 500, etc.)
- Missing expected strings
- Too many redirects

All errors are logged and included in the email notification.

## Data Storage

The uptime tracker stores data in JSON files:

- `data/uptime.json` - Check results and response times for each site
- `data/incidents.json` - Incident history (start/end times, errors)

Data is retained for 90 days and automatically cleaned up.

## Recommended Workflow

1. Set up your `config.yml` with sites to monitor
2. Run `./check_sites.rb` manually to test
3. Set up a cron job to run checks every 5-15 minutes
4. Start the status page server: `./start_status_page.sh`
5. Access the status page at `http://localhost:4567`

## Security Notes

- Store your `config.yml` securely and don't commit passwords to version control
- Consider using environment variables for sensitive data
- Use app passwords instead of actual account passwords when possible
- The status page runs on localhost by default - configure a reverse proxy (nginx/Apache) for public access

## License

Free to use and modify.
