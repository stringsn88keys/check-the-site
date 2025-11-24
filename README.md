# Site Checker

A Ruby script that monitors websites by checking if specific strings are present and sends email notifications when checks fail.

## Features

- Check multiple websites from a YAML configuration file
- Verify that expected strings are present on each site
- Handle HTTP redirects automatically
- Send email notifications when sites fail checks
- Detailed error reporting

## Requirements

- Ruby 2.5 or higher
- No external gems required (uses standard library)

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

## Usage

Run the script with the default config file:

```bash
./check_sites.rb
```

Or specify a custom config file:

```bash
ruby check_sites.rb path/to/config.yml
```

## Output

The script will:
1. Check each site in sequence
2. Print the status of each check to the console
3. Send an email notification if any sites fail
4. Exit with status 0 (all sites can also exit normally even with failures)

Example output:

```
Checking 3 sites...
Checking Example Site... OK
Checking GitHub... OK
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

## Security Notes

- Store your `config.yml` securely and don't commit passwords to version control
- Consider using environment variables for sensitive data
- Use app passwords instead of actual account passwords when possible

## License

Free to use and modify.
