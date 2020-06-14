# frozen_string_literal: true

require_relative '../api/mailchain'
require_relative '../connection/mailchain'
require 'mail'
# Handles the Mailchain API configuration and connection
class ConnectionMailchain
  # Initialize configs
  def initialize(config, config_file)
    @config = config
    @config_file = config_file
    @api = MailchainApi.new(@config['mailchain'])
  end

  # Configures the Mailchain API settings then tests the connection
  def configure_and_connect
    if !configuration_wizard # TODO: - wire up to connection configuration
      exit
    else
      test_connection
    end
  end

  # # Run the Mailchain API configuration
  def configuration_wizard
    connection_configuration = ConnectionConfigurationMailchain.new(@config)
    result = connection_configuration.configuration_wizard
    if result['save']
      result['config']['imap']['password'] = nil
      new_config_json = JSON.pretty_generate(result['config'])
      File.write(@config_file, new_config_json)
    end
  end

  # Tests the connection to the Mailchain API
  def test_connection(silent = false)
    puts 'Testing API connection...' unless silent
    result = true
    begin
      res = @api.version
      res[:status_code] != 200
      puts "Connection was successful (API version: #{res[:body]['version']})" unless silent
    rescue StandardError => e
      puts "Mailchain API failed to connect with the following error: #{e}"
      puts 'Check the Mailchain client is running and configured correctly'
      result = false
    end
    result
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

  # Returns messages formatted by_network
  #  e.g. [ address, res['messages'] ]
  def messages_by_network(item)
    protocol = item['protocol']
    network = item['network']
    addresses = item['addresses']
    messages = []
    addresses.each do |address|
      res = get_messages(address, protocol, network)
      messages << [address, res['messages']] unless res['messages'].nil?
    end
    messages
  end

  # Gets messages from api and returns `body` {"messages" => [...]}
  def get_messages(addr, protocol, network)
    address = "0x#{addr}"
    @api.messages(address, protocol, network)[:body]
  end

  # Convert and call the append_message for each valid message
  def convert_messages(messages)
    cmgs = []
    messages.each do |msg|
      next unless msg['status'] == 'ok'

      cm = convert_message(msg)
      cmgs << {
        'message' => cm,
        'message_id' => msg['headers']['message-id'],
        'message_date' => cm.date.to_time
      }
    end
    cmgs
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
end
