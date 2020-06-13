# MailchainConnectorImap

The Mailchain Connector for IMAP makes it possible to receive Mailchain messages in your email inbox (i.e. your webmail, desktop or phone mail application).

It connects to the Mailchain API, converts messages to emails, then uploads them to your chosen IMAP mailbox.

**NOTE: Further documentation can be found here: https://docs.mailchain.xyz/mailchain-connectors/mailchain-connector-imap**

## Prerequisites

You need to have installed:
1. Ruby
1. The Mailchain API client (https://docs.mailchain.xyz/installation)

## Installation

Install by running:

```sh
  gem install mailchain_connector_imap
```

## Usage

### Getting Started & Configuration

When running mailchain_connector_imap for the first time, or to change the configuration, run:

```sh
  mailchain_connector_imap --configure
```

This will walk you through the configuration options.

NOTE: See [Mailchain Docs](https://docs.mailchain.xyz/mailchain-connectors/mailchain-connector-imap) for further information.

### Running the Mailchain Connector for IMAP

To run the connector, once you have run the configuration:

```sh
  mailchain_connector_imap
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mailchain/mailchain_connector_imap. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/mailchain/community/blob/master/code-of-conduct.md).

## Code of Conduct

Everyone interacting in the MailchainConnectorImap project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/mailchain/community/blob/master/code-of-conduct.md).
