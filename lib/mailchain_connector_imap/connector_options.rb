# frozen_string_literal: true

class ConnectorOptions
  CONFIG_FILE = 'config.json'
  LOG_FILE = 'mailchain_connector_log.txt'
  attr_reader :imap_conn
  attr_reader :mailchain_conn
  attr_reader :config
  def initialize
    parse_config_file
    @imap_conn = ImapConnection.new(@config, CONFIG_FILE)
    @mailchain_conn = MailchainConnection.new(@config, CONFIG_FILE)
    @config_json = {}
  end

  # Handle missing config file error
  def missing_config_file
    puts "Invalid or missing config.\n" \
      'Run `mailchain_connector --configure` or mailchain_connector --help` for more options.'
  end

  # Run the script and parse input arguments
  def run_options_parse
    OptionParser.new do |opts|
      ARGV << '-r' if ARGV.empty?

      opts.banner = 'Usage: mailchain_connector.rb [options]'

      opts.on('-r', '--run', 'Run and sync messages') do
        unless valid_config
          missing_config_file
          exit
        end
        sync_messages
      end

      opts.on('-c', '--configure', 'Configure connector settings') do
        op_configure
        exit
      end

      opts.on('-t', '--test-connection', 'Test connection to IMAP server and Mailchain API') do
        op_test_connection
        exit
      end

      opts.on('-p', '--print-config', 'Print connector settings to screen') do
        op_print_configuration
        exit
      end

      opts.on_tail('-h', '--help', 'Show this message') do
        puts opts
        exit
      end
    end.parse!
  end

  # Runs the configuration wizards and tests connections
  def op_configure
    @imap_conn.configure_and_connect
    @mailchain_conn.configure_and_connect
    exit
  end

  # Run connection tests
  def op_test_connection
    begin
      @imap_conn.test_connection
    rescue StandardError => e
      puts "IMAP error: #{e}"
    end
    begin
      @mailchain_conn.test_connection
    rescue StandardError => e
      puts "API error: #{e}"
    end
  end

  # Outputs the configuration to screen
  def op_print_configuration
    @imap_conn.print_settings(@config)
    puts "\n"
    @mailchain_conn.print_settings(@config)
  end

  # Parse the config file as JSON
  def parse_config_file
    check_or_create_config_file
    config_json = File.read(CONFIG_FILE)
    @config = JSON.parse(config_json)
    true
  rescue StandardError => e
    puts "Error parsing configuration: #{e}"
    missing_config_file
    exit
  end

  # Check for an existing config file, otherwise create a new one with minimum requirements to be parsed.
  def check_or_create_config_file
    File.write(CONFIG_FILE, '{}') unless File.exist?(CONFIG_FILE)
  end

  # sync_messages calls MailchainConnection.messages_by_network, before setting a timer to run again.
  # Minimum timer interval is 60 seconds.
  # It logs at the beginning and end of each polling interval.
  def sync_messages
    loop do
      interval = @config['mailchain_interval'].to_i < 60 ? @config['mailchain_interval'].to_i : 60
      log_to_file('Checking messages')
      @mailchain_conn.messages_by_network
      log_to_file('Done')
      sleep interval
    end
  rescue StandardError => e
    log_to_file("Error: #{e}")
    puts "Error: #{e}"
  end

  # Checks values are present for config options
  # Returns true if valid; false if invalid
  def valid_config
    [
      @config['imap_server'],
      @config['imap_username'],
      @config['imap_password'],
      @config['imap_port'],
      @config['imap_ssl'],
      @config['mailchain_hostname'],
      @config['mailchain_ssl'],
      @config['mailchain_port'],
      @config['mailchain_folders'],
      @config['mailchain_mainnet_to_inbox'],
      @config['mailchain_interval']
    ].none? { |e| e.to_s.empty? }
  end

  # Output message to the log file, adding the date and time
  # `message` (String): the message text
  def log_to_file(message)
    open(LOG_FILE, 'a') do |f|
      f << "\n"
      f << "#{Time.now} #{message}"
    end
  end
end
