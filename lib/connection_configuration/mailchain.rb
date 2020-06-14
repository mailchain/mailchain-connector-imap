# frozen_string_literal: true

class ConnectionConfigurationMailchain
  FOLDER_STRUCTURE = { 'by_network' => 'Protocol>Network>Address', 'by_address' => 'Address>Protocol>Network' }.freeze

  attr_reader :config
  def initialize(config)
    @config = config
  end

  # Runs the Mailchain API configuration wizard
  # Returns hash or either: { "save" => true, "config" => "{ #config }" }
  # - or -
  # { "save" => false }
  def configuration_wizard
    @prompt = TTY::Prompt.new
    prompt_hostname
    prompt_ssl
    prompt_port
    prompt_folder_format
    prompt_mainnet_to_inbox
    prompt_polling_interval
    result = prompt_confirm_save_settings
    @prompt = nil
    result
  end

  # Prints the Mailchain API settings as output in a nice format
  def print_settings
    ssl =       @config['mailchain']['ssl'] ? 'https' : 'http'
    hostname =  @config['mailchain']['hostname']
    port =      @config['mailchain']['port']
    folders = @config['mailchain']['folders']
    mainnet_inbox = @config['mailchain']['mainnet_to_inbox'] ? 'To Inbox' : 'To Mainnet Folder'
    interval = @config['mailchain']['interval'].to_i > 60 ? @config['mailchain']['interval'].to_i : 60

    puts "Mailchain Settings:\n" \
    "-------------------\n" \
    "http/https:\t#{ssl}\n" \
    "Hostname:\t#{hostname}\n" \
    "Port:\t\t#{port}\n" \
    "API URL:\t#{ssl}://#{hostname}:#{port}/api\n" \
    "Mainnet messages: #{mainnet_inbox}\n" \
    "Store messages: #{FOLDER_STRUCTURE[folders]}\n" \
    "Polling interval: #{interval} seconds #{'(' + (interval / 60).to_s + ' minutes)' if interval > 60}"
  end

  # Get Mailchain server config
  def prompt_hostname
    @config['mailchain']['hostname'] = @prompt.ask(
      'Enter your Mailchain client hostname (e.g. 127.0.0.1 or mailchain.example.com)',
      default: @config['mailchain']['hostname'] || '127.0.0.1',
      require: true
    )
  end

  # Get Mailchain ssl status
  def prompt_ssl
    @config['mailchain']['ssl'] = @config['mailchain']['ssl'] != false
    ssl_val = @config['mailchain']['ssl'] ? 1 : 2
    ssl_val = @prompt.select('Use https (SSL)?', cycle: true) do |menu|
      menu.default ssl_val
      menu.choice 'https (SSL)', 1
      menu.choice 'http', 2
    end
    @config['mailchain']['ssl'] = ssl_val == 1
  end

  # Get Mailchain port
  def prompt_port
    custom_port = @prompt.yes?('Connect to a custom port?')
    case custom_port
    when false && @config['mailchain']['ssl']
      @config['mailchain']['port'] = 443
    when false && !@config['mailchain']['ssl']
      @config['mailchain']['port'] = 80
    when true
      @config['mailchain']['port'] = @config['mailchain']['port'] || '8080'
      @config['mailchain']['port'] = @prompt.ask(
        'Enter the port to connect to the Mailchain client (e.g. 8080)',
        default: @config['mailchain']['port'],
        require: true
      )
    end
  end

  # Folder format
  def prompt_folder_format
    choices = {
      1 => 'by_network',
      'by_network' => 1,

      2 => 'by_address',
      'by_address' => 2
    }
    folder_choice = @prompt.select(
      'How would you like to structure your folders in IMAP?',
      cycle: true
    ) do |menu|
      menu.default choices[@config['mailchain']['folders']] || 1
      menu.choice FOLDER_STRUCTURE['by_network'], 1
      menu.choice FOLDER_STRUCTURE['by_address'], 2
    end
    @config['mailchain']['folders'] = choices[folder_choice]
  end

  # Mainnet to Inbox
  def prompt_mainnet_to_inbox
    @config['mailchain']['mainnet_to_inbox'] = @prompt.select(
      "Most email clients don't alert you when messages are delivered to your folders. Would you like 'Mainnet' messages delivered to your Inbox folder so you get new message alerts?",
      cycle: true
    ) do |menu|
      menu.choice 'Yes', true
      menu.choice 'No', false
    end
  end

  # Polling Interval
  def prompt_polling_interval
    @config['mailchain']['interval'] = @config['mailchain']['interval'] || '300'
    @config['mailchain']['interval'] = @prompt.ask(
      'How often would you like to check for messages (in seconds)? (e.g. 300 = 5 minutes; Minimum interval is 1 minute)',
      default: @config['mailchain']['interval'],
      require: true
    )
  end

  # Confirm settings with user
  def prompt_confirm_save_settings
    settings = print_settings
    mailchain_confirm_val = @prompt.select(
      "Would you like to save the following settings?\n" \
      "NOTE: Any existing configuration will be overwritten\n\n" \
      "#{settings}",
      cycle: true
    ) do |menu|
      menu.choice 'Save', true
      menu.choice 'Cancel', false
    end
    mailchain_confirm_val ? { 'save' => true, 'config' => @config } : { 'save' => false }
  end
end
