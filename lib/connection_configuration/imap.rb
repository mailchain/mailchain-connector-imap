# frozen_string_literal: true

class ConnectionConfigurationImap
  attr_reader :config
  attr_reader :print_settings
  def initialize(config)
    @config = config
  end

  # Run the IMAP configuration wizard
  # Returns hash or either: { "save" => true, "config" => "{ #config }" }
  # - or -
  # { "save" => false }
  def configuration_wizard
    @prompt = TTY::Prompt.new

    prompt_server
    prompt_username
    prompt_port
    prompt_ssl

    result = prompt_confirm_save_settings
    @prompt = nil
    result
  end

  # Prints the IMAP server settings as output in a nice format
  def print_settings
    puts "IMAP Settings:\n" \
    "--------------\n" \
    "Server:\t\t#{@config['imap']['server']}\n" \
    "Port:\t\t#{@config['imap']['port']}\n" \
    "SSL:\t\t#{@config['imap']['ssl']}\n" \
    "Username:\t#{@config['imap']['username']}"
  end

  # Get imap server config
  def prompt_server
    @config['imap']['server'] = @prompt.ask(
      'Enter your imap server (e.g. imap.example.com)',
      default: @config['imap']['server'],
      require: true
    )
  end

  # Get imap username
  def prompt_username
    @config['imap']['username'] = @prompt.ask(
      'Enter your imap username/ email address (e.g. tim@example.com)',
      default: @config['imap']['username'],
      require: true
    )
  end

  # Get imap port
  def prompt_port
    @config['imap']['port'] = @config['imap']['port'] || '993'
    @config['imap']['port'] = @prompt.ask(
      'Enter the imap port to connect to (e.g. IMAP = 143; IMAP SSL = 993)',
      default: @config['imap']['port'],
      require: true
    )
  end

  # Get imap ssl status
  def prompt_ssl
    @config['imap']['ssl'] = @config['imap']['ssl'] != false
    imap_ssl_val = @config['imap']['ssl'] ? 1 : 2
    imap_ssl_val = @prompt.select('Use SSL?', cycle: true) do |menu|
      menu.default imap_ssl_val
      menu.choice 'Yes', 1
      menu.choice 'No', 2
    end
    @config['imap']['ssl'] = imap_ssl_val == 1
  end

  # Confirm settings with user
  def prompt_confirm_save_settings
    server_settings = print_settings
    imap_confirm_val = @prompt.select(
      "Would you like to save the following settings?\n" \
      "NOTE: Any existing configuration will be overwritten\n\n" \
      "#{server_settings}",
      cycle: true
    ) do |menu|
      menu.choice 'Save', true
      menu.choice 'Cancel', false
    end

    imap_confirm_val ? { 'save' => true, 'config' => @config } : { 'save' => false }
  end
end
