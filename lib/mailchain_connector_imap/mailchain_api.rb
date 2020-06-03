# frozen_string_literal: true

require 'HTTParty'

class MailchainApi
  include HTTParty
  @config = {}

  # Initialize the config
  def initialize(config)
    @config = config
  end

  # Return the base_uri as specified in the config
  def base_uri
    ssl = @config['mailchain_ssl'] ? 'https' : 'http'
    uri = @config['mailchain_hostname']
    port = @config['mailchain_port']
    "#{ssl}://#{uri}:#{port}/api"
  end

  # Get addresses endpoint
  # `protocol` = the protocol
  # `network` = the network
  def addresses(protocol, network)
    res = self.class.get("#{base_uri}/addresses?protocol=#{protocol}&network=#{network}")
    { body: JSON.parse(res.body), status_code: res.code }
  end

  # Get messages from api
  # `address`: the address (string e.g. '0x123...')
  # `protocol`: the protocol (string e.g. 'ethereum)
  # `network`: the network (string e.g. 'ropsten')
  def messages(address, protocol, network)
    res = self.class.get("#{base_uri}/messages?address=#{address}&protocol=#{protocol}&network=#{network}")
    { body: JSON.parse(res.body), status_code: res.code }
  end

  # Get protocols endpoint
  def protocols
    res = self.class.get("#{base_uri}/protocols")
    { body: JSON.parse(res.body), status_code: res.code }
  end

  # Calls the version endpoint, returns version
  def version
    res = self.class.get("#{base_uri}/version")
    { body: JSON.parse(res.body), status_code: res.code }
  end
end
