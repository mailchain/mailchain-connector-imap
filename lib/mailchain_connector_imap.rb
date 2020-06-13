# frozen_string_literal: true

require 'tty-prompt'
require 'optparse'

require_relative 'connection/imap'
require_relative 'connection/mailchain'
require_relative 'connection_configuration/imap'
require_relative 'connection_configuration/mailchain'

module MailchainConnectorImap
  class Error < StandardError; end

  class Connector
    STORE_PATH = "#{ENV['HOME']}/.mailchain_connector/imap/"
    CONFIG_FILE = File.join(STORE_PATH, 'config.json')
    LOG_FILE = File.join(STORE_PATH, 'mailchain_connector_imap.log')
    attr_reader :imap_conn
    attr_reader :mailchain_conn
    attr_reader :config

    def initialize
      parse_config_file
      @imap_conn = ConnectionImap.new(@config, CONFIG_FILE)
      @mailchain_conn = ConnectionMailchain.new(@config, CONFIG_FILE)
      @config_json = {}
    end

    def start
      # Run OptionsParser to interpret user input
      run_options_parse
    end

    # Handle missing config file error
    def missing_config_file
      puts "Invalid or missing config.\n" \
        'Run `mailchain_connector_imap --configure`'
    end

    # Run the script and parse input arguments
    def run_options_parse
      OptionParser.new do |opts|
        ARGV << '-r' if ARGV.empty?

        opts.banner = 'Usage: mailchain_connector_imap [options]'

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
      # TODO: fix this
      ConnectionConfigurationImap.new(@config).print_settings
      puts "\n"
      # TODO: fix this
      ConnectionConfigurationMailchain.new(@config).print_settings
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
      (FileUtils.mkdir_p(STORE_PATH) unless File.exist?(CONFIG_FILE))
      File.write(CONFIG_FILE, '{"imap": {}, "mailchain": {}}') unless File.exist?(CONFIG_FILE)
    end

    # sync_messages calls ConnectionMailchain.messages_by_network, before setting a timer to run again.
    # Minimum timer interval is 60 seconds.
    # It logs at the beginning and end of each polling interval.
    def sync_messages
      if @imap_conn.connect
        puts 'Connected to IMAP'
        if mailchain_conn.test_connection(true)
          puts 'Connected to Mailchain client'
          loop do
            if @imap_conn.connect && mailchain_conn.test_connection(true)
              interval = @config['mailchain']['interval'].to_i > 60 ? @config['mailchain']['interval'].to_i : 60
              log_to_file('Checking messages')
              @mailchain_conn.addresses_by_network.each do |abn|
                protocol = abn['protocol']
                network = abn['network']
                # TODO: - Simplify this:
                addr_with_messages = @mailchain_conn.messages_by_network(abn)
                addr_with_messages.each do |addr_msg|
                  addr = addr_msg[0]
                  msg = addr_msg[1]
                  converted_messages = @mailchain_conn.convert_messages(msg)
                  converted_messages.each do |cm|
                    @imap_conn.append_message(protocol, network, addr, cm['message'], cm['message_id'], nil, cm['message_date'])
                  end
                end
              end
            end

            log_to_file('Done')
            sleep interval
          end
        end
      end
    rescue StandardError => e
      log_to_file("Error: #{e}")
      puts "Error: #{e}"
    end

    # Checks values are present for config options
    # Returns true if valid; false if invalid
    def valid_config
      [
        @config['imap']['server'],
        @config['imap']['username'],
        @config['imap']['port'],
        @config['imap']['ssl'],
        @config['mailchain']['hostname'],
        @config['mailchain']['ssl'],
        @config['mailchain']['port'],
        @config['mailchain']['folders'],
        @config['mailchain']['mainnet_to_inbox'],
        @config['mailchain']['interval']
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
end
