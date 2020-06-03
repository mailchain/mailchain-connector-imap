# frozen_string_literal: true

require 'net/imap'
require 'pry'
require 'mail'
require 'pstore'

# Handles the Imap configuration and connection
class ImapConnection
  STORE_PATH = "#{ENV['HOME']}/.mailchain_connector/"
  STORE_FILE = File.join(STORE_PATH, 'mailchain_connector.pstore')

  # reads the config file and sets `@config`
  def initialize(config, config_file)
    get_or_create_pstore
    @config = config
    @config_file = config_file
  end

  # Check for pstore, and create if not exist
  def get_or_create_pstore
    (FileUtils.mkdir_p(STORE_PATH) unless File.exist?(STORE_FILE))
    @pstore = PStore.new(STORE_FILE, true)
  end

  # Records in pstore with the MD5 hexdigest of message_id as key, with prefix 'append_'  and value as true.
  # Stored as md5 hash to obfuscate message ids.
  def store_msg_appended(message_id)
    message_id_hash = Digest::MD5.hexdigest(message_id)
    @pstore.transaction { @pstore['append_' + message_id_hash] = true }
  end

  # Checks if MD5 hexdigest of message_id as key, with prefix 'append_' returns a true value from the database.
  # Stored as md5 hash to obfuscate message ids.
  # Returns true or false
  def msg_appended?(message_id)
    message_id_hash = Digest::MD5.hexdigest(message_id)
    @pstore.transaction { @pstore['append_' + message_id_hash] } == true
  end
  
  # Creates a pretty output for settings
  def pretty_settings(options)
    "IMAP Settings:\n" \
           "--------------\n" \
           "Server:\t\t#{options['imap_server']}\n" \
           "Port:\t\t#{options['imap_port']}\n" \
           "SSL:\t\t#{options['imap_ssl']}\n" \
           "Username:\t#{options['imap_username']}"
  end

  # Prints the IMAP server settings as output in a nice format
  def print_settings(options)
    puts pretty_settings(options)
  end

  # Run the IMAP configuration
  def configure_server
    prompt = TTY::Prompt.new
    result = false

    # Get imap server config
    @config['imap_server'] = prompt.ask(
      'Enter your imap server (e.g. imap.example.com)',
      default: @config['imap_server']
    )

    # Get imap username
    @config['imap_username'] = prompt.ask(
      'Enter your imap username/ email address (e.g. tim@example.com)',
      default: @config['imap_username']
    )

    # Get imap password
    @config['imap_password'] = prompt.mask(
      'Enter your imap password',
      default: @config['imap_password']
    )

    # Get imap port
    @config['imap_port'] = @config['imap_port'] || '993'
    @config['imap_port'] = prompt.ask(
      'Enter the imap port to connect to (e.g. IMAP = 143; IMAP SSL = 993)',
      default: @config['imap_port']
    )

    # Get imap ssl status
    @config['imap_ssl'] = @config['imap_ssl'] != false
    imap_ssl_val = @config['imap_ssl'] ? 1 : 2
    imap_ssl_val = prompt.select('Use SSL?', cycle: true) do |menu|
      menu.default imap_ssl_val
      menu.choice 'Yes', 1
      menu.choice 'No', 2
    end
    @config['imap_ssl'] = imap_ssl_val == 1

    # Confirm settings with user
    server_settings = pretty_settings(@config)
    imap_confirm_val = prompt.select(
      "Would you like to save the following settings?\n" \
      "NOTE: Any existing configuration will be overwritten\n\n" \
      "#{server_settings}",
      cycle: true
    ) do |menu|
      menu.choice 'Save', true
      menu.choice 'Cancel', false
    end
    if imap_confirm_val
      new_options_json = JSON.pretty_generate(@config)
      File.write(@config_file, new_options_json)
      result = true
    else
      # Exit the application
      result = false
    end

    result
  end

  # Connect to the IMAP server, attempting 'LOGIN' then 'PLAIN'
  def connect
    @connection = Net::IMAP.new(@config['imap_server'], @config['imap_port'], @config['imap_ssl'])

    begin
      @connection.authenticate('LOGIN', @config['imap_username'], @config['imap_password'])
    rescue StandardError
      begin
        @connection.authenticate('PLAIN', @config['imap_username'], @config['imap_password'])
      rescue StandardError => e
        puts "IMAP failed to connect: #{e}"
      end
    end
    true
  end

  # Sets the connection delimiter
  def delimiter
    if @delimiter.nil?
      folders = list_folders
      @delimiter = folders[0][:delim]
    end
    @delimiter
  end

  # Disconnects from the server
  def disconnect
    @connection.disconnect unless @connection.nil? || @connection.disconnected?
  end

  # Configures the IMAP server settings then tests the connection
  def configure_and_connect
    if !configure_server
      exit
    else
      test_connection
    end
  end

  # Tests the connection to the IMAP server
  def test_connection
    puts 'Testing IMAP connection...'
    puts 'IMAP connection was successful' if connect
    disconnect unless @connection.disconnected?
    true
  end

  # Returns the target mailbox for the message according to the folder structre and Inbox preferences
  def get_mailbox(protocol, address, network)
    if @config['mailchain_mainnet_to_inbox'] && network.downcase == 'mainnet'
      'Inbox'
    else
      case @config['mailchain_folders']
      when 'by_address'
        # 'Address>Protocol>Network'
        "Inbox#{delimiter}#{address}#{delimiter}#{protocol}#{delimiter}#{network}"
      when 'by_network'
        # 'Protocol>Network>Address'
        "Inbox#{delimiter}#{protocol}#{delimiter}#{network}#{delimiter}#{address}"
      end
    end
  end

  # Create the folder path for the mailbox according to chosen folder format
  def create_mailbox_path(target_mailbox)
    return if @connection.list('', target_mailbox)

    folders = target_mailbox.split(delimiter)
    mbox = []
    (0...folders.length).each_with_index do |_folder, index|
      mbox.push(folders[index])
      mbox_as_str = mbox.join(delimiter)
      @connection.create(mbox_as_str) unless @connection.list('', mbox_as_str)
    end
  end

  # Appends message to mailbox
  # `date_time`: Time
  # Connects and disconnects at the beginning and end of the method
  #  if the connection is not defined/ connected already
  def append_message(protocol, network, address, message, message_id, flags = nil, date_time = nil)
    unless msg_appended?(message_id)
      if @connection.nil? || @connection.disconnected?
        connect
        local_connection = true
      end

      target_mailbox = get_mailbox(protocol, address, network)
      create_mailbox_path(target_mailbox)
      @connection.examine(target_mailbox)

      if @connection.search(['HEADER', 'MESSAGE-ID', message.message_id]).empty?
        @connection.append(target_mailbox, message.to_s, flags, date_time)
      end
      store_msg_appended(message_id)

      disconnect if local_connection
    end
  end

  # Lists folders
  # Connects and disconnects at the beginning and end of the method
  #  if the connection is not defined/ connected already
  def list_folders
    if @connection.nil? || @connection.disconnected?
      connect
      local_connection = true
    end
    folders = @connection.list('', '*')
    disconnect if local_connection
    folders
  end
end
