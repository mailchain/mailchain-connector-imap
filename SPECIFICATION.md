# **Mailchain Connector for IMAP Specification**

The Mailchain Connector for IMAP enables users to receive Mailchain messages in their email client inbox by using the IMAP protocol to append messages to a new or existing email account via the email server (the email provider/ server must support IMAP).

The following requirements set out how the Mailchain Connector for IMAP can be implemented:

## **Requirements Notation**

This document occasionally uses terms that appear in capital letters. When the terms “MUST”, “SHOULD”, “RECOMMENDED”, “MUST NOT”, “SHOULD NOT”, and “MAY” appear capitalised, they are being used to indicate particular requirements of this specification. A discussion of the meanings of these terms appears in [RFC2119](https://tools.ietf.org/html/rfc2119).

### **Definitions for the purpose of these requirements**

| Term       | Definition |
| ----------- | ----------- |
| Centralized resource | A single entity or group of entities could be said to have control of the resource. Responsibility for the integrity or availability or the resource falls on entity or entities.
| Decentralized resource | No single entity or group of entities could be said to have control of the resource. Responsibility for the integrity or availability or the resource falls on the participants in the decentralized system according to the set of rules that govern the system.
| Mailbox | The email account or mailbox that 1. supports IMAP, and 2. is where the Mailchain messages will be delivered.
| Mailchain Client | The Mailchain API Client, available from [https://github.com/mailchain/mailchain]
| the Connector | The Mailchain Connector for IMAP.
| Message | A Mailchain message.
| Email | A Mailchain message converted to an email message.

## **Message Handling**

### Mailchain Client

The Connector SHOULD interact with the Mailchain Client for Message retrieval.

### Message Storage & Logging

Messages SHOULD not be stored on disk by the Connector.

Message metadata SHOULD not be stored on disk unless it has been encrypted or hashed.

A hash of the Message ID MAY be stored on disk to track which messages have been appended to the Mailbox.

Credentials SHOULD not be stored on disk by the Connector unless encrypted.

The Connector MAY log connection attempts.

### IMAP Support

The Connector MUST support HTTPS and HTTP connections to the Mailbox.

The Connector MUST support PLAIN and LOGIN Mailbox authentication types.

The Connector SHOULD prompt the user for credentials at runtime.

The Connector SHOULD not append messages that already exist in the Mailbox.

The Connector SHOULD not append messages that have been deleted from the Mailbox.

Email state MUST be handled by the Mailbox server (or IMAP server). I.e. it is out of scope.

### Appending Messages & Folder Structure

A folder hierarchy SHOULD support either: `Protocol > Network > Address`, or `Address > Protocol > Network`.

The Connector SHOULD append each Email according to the folder hierarchy.

A user MAY indicate a preference for the folder hierarchy.

The Connector SHOULD support delivering Mainnet (or equivalent) Emails to the primary inbox folder that alerts the user of a new emails.

A user MAY indicate a preference for storing Mainnet Emails in the primary inbox or in a folder in the folder hierarchy.

The Connector MAY poll for new Messages at regular intervals.

A user MAY indicate a preference for the duration between polling for new Messages.

### **Mailchain Addressing Format**

Addressing SHOULD follow the standard mailchain format.

For example:

`recipient_public_address`@`network`.`protocol`, where:

- `recipient_public_address` SHOULD be a public address for the recipient.
- `@` MUST be the delimiter to separate address from protocol and network details.
- `network`, an optional parameter MAY be included to specify the network the transaction is broadcast to, for example a testnet or a mainnet.
- `protocol` SHOULD specify the blockchain protocol for the message, for example, bitcoin or ethereum.
- `.` (dot) MUST be the delimiter to separate the protocol from network details.

The address MAY append a resolvable FQDN to the Mailchain address when appending to the Mailbox, e.g. `recipient_public_address`@`network.protocol.example.com`.

## **Private Keys**

The Connector MUST not handle private keys. This SHOULD be handled by the Mailchain Client.

## **Message Format**

The Connector MUST convert the Message to RFC5322 Internet Message Format.

The Connector MUST not alter the Message subject and body.

The Connector SHOULD support plaintext and html message content types.

The Connector MAY add a footer to the Email prior to appending it to the Mailbox.

The Connector MUST add Mailchain message headers in the format 'X-Mailchain-' + 'Dash-Separated-Capitalised-Header', e.g. Mailchain message header: 'block-id-encoding' = email header 'X-Mailchain-Block-Id-Encoding'.

The Connector SHOULD include transaction details in the Email headers.

The Email body MUST be included after the headers.

An Email body MUST follow the content-type specified in Content-Type header.

An Email body MUST be encoded with the content-transfer-encoding specified in Content-Transfer-Encoding header.

An Email body MAY be empty.

An Email MUST have the following fields:

| Field       | Description |
| ----------- | ----------- |
| To: | The recipient public address formatted according to the Mailchain Addressing Format
| From: | The sender public address formatted according to the Mailchain Addressing Format
| Message-ID: | The Message header message-id field value
| Date: | The RFC5322 date format
| Content-Type: | As per RFC6532 content type for the contents of the message.
| Content-Transfer-Encoding: | How the message body SHOULD encoded
| Subject: | The message subject
| Body: | The message body

Email headers SHOULD contain the following fields:

| Field       | Description |
| ----------- | ----------- |
| X-Mailchain-Block-Id | Corresponding Message header field: block-id
| X-Mailchain-Transaction-Hash | Corresponding Message header field: transaction-hash
| X-Mailchain-Transaction-Hash-Encoding | Corresponding Message header field: transaction-hash-encoding
| X-Mailchain-Block-Id-Encoding | Corresponding Message header field: block-id-encoding

An Email MAY contain the following header fields:

| Field       | Description |
| ----------- | ----------- |
| Reply-To: | The public address responses should be sent to
| Reply-To-Public-Key: | The public key that should be used to encrypt a reply
