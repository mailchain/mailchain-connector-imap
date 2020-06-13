# frozen_string_literal: true

require 'net/imap'
require 'mail'
require 'pry'
require 'pstore'
require_relative '../connection_configuration/imap'

# Handles the Imap configuration and connection
class ConnectionImap
  STORE_PATH = "#{ENV['HOME']}/.mailchain_connector/imap/"
  STORE_FILE = File.join(STORE_PATH, 'mailchain_connector_imap.pstore')

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

  # # Run the IMAP configuration
  def configuration_wizard
    connection_configuration = ConnectionConfigurationImap.new(@config)
    result = connection_configuration.configuration_wizard
    if result['save']
      new_config_json = JSON.pretty_generate(result['config'])
      File.write(@config_file, new_config_json)
    end
  end

  # Connect to the IMAP server, attempting 'LOGIN' then 'PLAIN'
  def connect(password = @config['imap']['password'])
    @connection ||= Net::IMAP.new(@config['imap']['server'], @config['imap']['port'], @config['imap']['ssl'])
    if @connection.disconnected?
      begin
        @connection.authenticate('LOGIN', @config['imap']['username'], password)
      rescue StandardError
        begin
          @connection.authenticate('PLAIN', @config['imap']['username'], password)
        rescue StandardError => e
          puts "IMAP failed to connect: #{e}"
        end
      end
      true
    else
      true
    end
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
    if !configuration_wizard # TODO: - wire up to connection configuration
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
      connect

      target_mailbox = get_mailbox(protocol, address, network)
      create_mailbox_path(target_mailbox)
      @connection.examine(target_mailbox)

      if @connection.search(['HEADER', 'MESSAGE-ID', message.message_id]).empty?
        @connection.append(target_mailbox, message.to_s, flags, date_time)
      end
      store_msg_appended(message_id)
    end
  end

  # Lists folders
  # Connects and disconnects at the beginning and end of the method
  #  if the connection is not defined/ connected already
  def list_folders
    connect

    folders = @connection.list('', '*')
    folders
    disconnect
  end
end
