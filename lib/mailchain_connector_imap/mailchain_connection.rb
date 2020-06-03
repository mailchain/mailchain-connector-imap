# frozen_string_literal: true

require_relative 'mailchain_api'
require 'mail'

# Handles the Mailchain API configuration and connection
class MailchainConnection
  FOLDER_STRUCTURE = { 'by_network' => 'Protocol>Network>Address', 'by_address' => 'Address>Protocol>Network' }.freeze

  # Initialize configs
  def initialize(config, config_file)
    @config = config
    @config_file = config_file
    @api = connect
  end

  # Configures the Mailchain API settings then tests the connection
  def configure_and_connect
    if !configure_api
      exit
    else
      test_connection
    end
  end

  # Tests the connection to the Mailchain API
  def test_connection
    puts 'Testing API connection...'
    begin
      res = connect.version
      puts "Connection was successful (API version: #{res[:body]['version']})" if res[:status_code] == 200
    rescue StandardError => e
      puts "API failed to connect with the following error: #{e}"
    end
    true
  end

  # Runs the configuration wizard
  def configure_api
    prompt = TTY::Prompt.new
    result = false

    # Get Mailchain server config
    @config['mailchain_hostname'] = prompt.ask(
      'Enter your Mailchain client hostname (e.g. 127.0.0.1 or mailchain.example.com)',
      default: @config['mailchain_hostname'] || '127.0.0.1'
    )

    # Get Mailchain ssl status
    @config['mailchain_ssl'] = @config['mailchain_ssl'] != false
    ssl_val = @config['mailchain_ssl'] ? 1 : 2
    ssl_val = prompt.select('Use https (SSL)?', cycle: true) do |menu|
      menu.default ssl_val
      menu.choice 'https (SSL)', 1
      menu.choice 'http', 2
    end
    @config['mailchain_ssl'] = ssl_val == 1

    # Get Mailchain port
    custom_port = prompt.yes?('Connect to a custom port?')
    case custom_port
    when false && @config['mailchain_ssl']
      @config['mailchain_port'] = 443
    when false && !@config['mailchain_ssl']
      @config['mailchain_port'] = 80
    when true
      @config['mailchain_port'] = @config['mailchain_port'] || '8080'
      @config['mailchain_port'] = prompt.ask(
        'Enter the port to connect to the Mailchain client (e.g. 8080)',
        default: @config['mailchain_port']
      )
    end

    # Folder format
    choices = {
      1 => 'by_network',
      'by_network' => 1,

      2 => 'by_address',
      'by_address' => 2
    }
    folder_choice = prompt.select(
      'How would you like to structure your folders in IMAP?',
      cycle: true
    ) do |menu|
      menu.default choices[@config['mailchain_folders']] || 1
      menu.choice FOLDER_STRUCTURE['by_network'], 1
      menu.choice FOLDER_STRUCTURE['by_address'], 2
    end
    @config['mailchain_folders'] = choices[folder_choice]

    # Mainnet to Inbox
    @config['mailchain_mainnet_to_inbox'] = prompt.select(
      "Most email clients don't alert you when messages are delivered to your folders. Would you like 'Mainnet' messages delivered to your Inbox folder so you get new message alerts?",
      cycle: true
    ) do |menu|
      menu.choice 'Yes', true
      menu.choice 'No', false
    end

    # Polling Interval
    @config['mailchain_interval'] = @config['mailchain_interval'] || '300'
    @config['mailchain_interval'] = prompt.ask(
      'How often would you like to check for messages (in seconds)? (e.g. 300 = 5 minutes; Minimum interval is 1 minute)',
      default: @config['mailchain_interval']
    )

    # Confirm settings with user
    settings = pretty_settings(@config)
    confirm_val = prompt.select(
      "Would you like to save the following settings?\n" \
      "NOTE: Any existing configuration will be overwritten\n\n" \
      "#{settings}",
      cycle: true
    ) do |menu|
      menu.choice 'Save', true
      menu.choice 'Cancel', false
    end
    if confirm_val
      new_options_json = JSON.pretty_generate(@config)
      File.write(@config_file, new_options_json)
      result = true
    else
      result = false
    end
    result
  end

  # Connect to the Mailchain Api
  def connect
    @api = MailchainApi.new(@config)
  end

  # Converts mailchain message to regular email
  def convert_message(message)
    footer = 'Delivered by Mailchain IMAP Connector'
    c_type = get_content_type(message['headers']['content-type'])

    mail = Mail.new do
      from        message['headers']['from']
      to          message['headers']['to']
      date        message['headers']['date']
      message_id  message['headers']['message-id']
      subject     message['subject']
      if c_type == 'html'
        html_part do
          content_type message['headers']['content-type']
          body "#{message['body']} <br/><br/>#{footer}"
        end
      end
      if c_type == 'plain'
        text_part do
          content_type message['headers']['content-type']
          body "#{message['body']} \r\n#{footer}"
        end
      end
    end
    mail.header['X-Mailchain-Block-Id'] = message['block-id']
    mail.header['X-Mailchain-Block-Id-Encoding'] = message['block-id-encoding']
    mail.header['X-Mailchain-Transaction-Hash']  = message['transaction-hash']
    mail.header['X-Mailchain-Transaction-Hash-Encoding'] = message['transaction-hash-encoding']
    mail
  end

  # Returns `text` or `html`
  def get_content_type(content_type)
    case content_type
    when '"text/html; charset=\"UTF-8\""'
      'html'
    when '"text/plain; charset=\"UTF-8\""'
      'plain'
    else
      'plain'
    end
  end

  # Returns addresses formatted by_network
  # e.g. [{
  #         "protocol" => "ethereum",
  #         "network" => "kovan",
  #         "addresses"=> ["1234567890...", "d5ab4ce..."]
  #       }]
  def addresses_by_network
    protocol_networks.map do |obj|
      {
        'protocol' => obj['protocol'],
        'network' => obj['network'],
        'addresses' => @api.addresses(obj['protocol'], obj['network'])[:body]['addresses']
      }
    end
  end

  # Returns all address by display_type
  # `display_type`: "by_network" or "by_address"
  def all_addresses(display_type = 'by_network')
    case display_type
    when 'by_network'
      addresses_by_network
    when 'by_address'
      addresses_by_address
    end
  end

  # Returns messages formatted by_network
  # e.g. [{
  #         "protocol" => "ethereum",
  #         "network" => "kovan",
  #         "addresses"=> ["1234567890...", "d5ab4ce..."]
  #         "messages" => [
  #           "1234567890" => [{"headers"...},{"headers"...}...]
  #         ]
  #       }]
  def messages_by_network
    addr_by_net = addresses_by_network
    addr_by_net.each_with_index do |item, index|
      protocol = item['protocol']
      network = item['network']
      addresses = item['addresses']

      addr_by_net[index].merge!({ 'messages' => [] })

      imap_connection = ImapConnection.new(@config, @config_file)
      imap_connection.connect
      addresses.each do |address|
        res = get_messages(address, protocol, network)
        unless res['messages'].nil?
          process_and_append_messages(imap_connection, res['messages'], protocol, network, address)
        end
      end
      imap_connection.disconnect
    end
  end

  # Gets messages from api and returns `body` {"messages" => [...]}
  def get_messages(addr, protocol, network)
    address = "0x#{addr}"
    @api.messages(address, protocol, network)[:body]
  end

  # Convert and call the append_message for each valid message
  def process_and_append_messages(imap_connection, messages, protocol, network, address)
    messages.each do |msg|
      next unless msg['status'] == 'ok'

      message = convert_message(msg)
      message_id = msg['headers']['message-id']
      imap_connection.append_message(protocol, network, address, message, message_id, nil, message.date.to_time)
    end
  end

  # Returns array of each network with parent protocol
  # e.g. [{'protocol' => 'ethereum', 'network' => 'ropsten'},...]
  def protocol_networks
    output = []
    @api.protocols[:body]['protocols'].each do |proto|
      output << proto['networks'].map do |n|
        { 'protocol' => proto['name'], 'network' => n['name'] }
      end
    end
    output.flatten
  rescue StandardError => e
    puts "Error: #{e}"
  end

  # Creates a pretty output for settings
  def pretty_settings(options)
    ssl =       options['mailchain_ssl'] ? 'https' : 'http'
    hostname =  options['mailchain_hostname']
    port =      options['mailchain_port']
    folders = options['mailchain_folders']
    mainnet_inbox = options['mailchain_mainnet_to_inbox'] ? 'To Inbox' : 'To Mainnet Folder'
    interval = options['mailchain_interval'].to_i > 60 ? options['mailchain_interval'].to_i : 60

    "Mailchain Settings:\n" \
    "-------------------\n" \
    "http/https:\t#{ssl}\n" \
    "Hostname:\t#{hostname}\n" \
    "Port:\t\t#{port}\n" \
    "API URL:\t#{ssl}://#{hostname}:#{port}/api\n" \
    "Mainnet messages: #{mainnet_inbox}\n" \
    "Store messages: #{FOLDER_STRUCTURE[folders]}\n" \
    "Polling interval: #{interval} seconds #{(interval / 60).to_s + ' minutes' if interval > 60}"
  end

  # Prints the Mailchain API settings as output in a nice format
  def print_settings(options)
    puts pretty_settings(options)
  end
end
