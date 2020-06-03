#!/usr/bin/ruby
# frozen_string_literal: true

require 'tty-prompt'
require 'optparse'

require_relative 'connector_options'
require_relative 'imap_connection'
require_relative 'mailchain_api'
require_relative 'mailchain_connection'

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
