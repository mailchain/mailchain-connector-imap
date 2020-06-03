# frozen_string_literal: true

require 'tty-prompt'
require 'optparse'

require_relative 'mailchain_connector_imap/connector_options'
require_relative 'mailchain_connector_imap/imap_connection'
require_relative 'mailchain_connector_imap/mailchain_api'
require_relative 'mailchain_connector_imap/mailchain_connection'

module MailchainConnectorImap
  class Error < StandardError; end

  class Connector
    def initialize
      # Get the connector options
      @run = ConnectorOptions.new
    end

    def start
      # Run OptionsParser to interpret user input
      @run.run_options_parse
    end
  end
end
