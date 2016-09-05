# SaltyRTC - Secure WebRTC/ORTC based on NaCl

# Abstract

SaltyRTC is a protocol for WebRTC and ORTC which uses end-to-end
encryption techniques based on the Networking and Cryptography library
(NaCl) and the WebSocket protocol to set up a secure peer-to-peer
connection. The protocol has been designed in a way that no third party
needs to be trusted. Furthermore, it offers another security layer for
WebRTC and ORTC Data Channels.

This document describes the protocol for both client (a peer wanting
to set up a WebRTC or ORTC connection) and server (relays signalling
data from one client to another).

# Introduction

TODO

# Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in
[RFC 2119 [RFC2119]](https://tools.ietf.org/html/rfc2119).

# Terminology

## Client

A SaltyRTC compliant client. The client uses the signalling channel to
establish a WebRTC or ORTC peer-to-peer connection.

## Server

A SaltyRTC compliant server. The server provides the signalling channel
clients may communicate with one another.

## Peer

The term *peer* is being used for protocol descriptions that need to
be followed by both SaltyRTC compliant clients and servers.

## Initiator

An initiator is a SaltyRTC compliant client who wants to establish a
WebRTC or ORTC peer-to-peer connection to a responder.

## Responder

The responder is a SaltyRTC compliant client who wants to establish a
WebRTC or ORTC peer-to-peer connection to an initiator.

## Signalling Path

A signalling path is a simple ASCII string and consists of the hex
value of the initiators public key. Initiator and responder connect
to the same WebSocket path.

## MessagePack Object

TODO

## Address

The address is a single byte that identifies a specific peer on a
WebSocket path. It is being used to indicate to which client a server
should relay a message. In this document, the byte will be represented
in hexadecimal notation (base 16) starting with `0x`.  
The server (`0x00`) and the initiator (`0x01`) have a static
identifier. For responders, the server will dynamically assign
identifiers (`0x02..0xff`).

# WebSocket

The SaltyRTC protocol has been designed to work on top of the WebSocket
protocol. For more information about the WebSocket protocol, see
RFC 6455.

## Security Recommendation

Although the SaltyRTC protocol takes many security measures to prevent eavesdropping, it is still highly RECOMMENDED to use WebSocket in its *secure* mode (e.g. provide a valid certificate). This measure will make sure that the signalling path is hidden from eavesdroppers and generally hardens the protocol against potential attacks.

## Subprotocol

It is REQUIRED to provide the following subprotocol when connecting to
a server:

`v0.saltyrtc.org`

Only if the server chose the subprotocol above, this protocol
SHALL be applied. If another shared subprotocol that is not related to 
SaltyRTC has been found, continue with that subprotocol. Otherwise, 
close the connection to the server with a close code of `1002` (No 
Shared Subprotocol Found).

TODO: Switch to `v1` as soon as the spec has been reviewed.

# Signalling Message Structure

SaltyRTC signalling messages are encoded in binary using
network-oriented format (most significant byte first, also known as
*big-endian*). Unless otherwise noted, numeric constants are in decimal
(base 10).

All signalling messages MUST start with a 24-byte nonce followed by
either:

* an NaCl public-key authenticated encrypted MessagePack object,
* an NaCl secret-key authenticated encrypted MessagePack object or
* an unencrypted MessagePack object.

Which case applies is always known by the communicating parties. In
some scenarios, more than one case is possible. For these scenarios, a
description will be provided how multiple cases must be handled.

     0                   1                   2                   3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |                                                               |
    |                                                               |
    |                            Nonce                              |
    |                                                               |
    |                                                               |
    |                                                               |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |                             Data                          ...
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

The nonce is exactly 24 byte that SHALL only be used once per shared
secret. A nonce can also be seen as the **header** of SaltyRTC messages
as it is used by every single signalling message. It contains the
following fields:

     0                   1                   2                   3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |                                                               |
    |                            Cookie                             |
    |                                                               |
    |                                                               |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |    Source     |  Destination  |        Overflow Number        |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |                        Sequence Number                        |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

Cookie: 16 byte

This field contains 16 cryptographically secure random byte that MUST
remain the same for an entire session.

Source: 1 byte

Contains the SaltyRTC address of the sender.

Destination: 1 byte

Contains the SaltyRTC address of the receiver.

Overflow Number: 2 byte

This field contains the 16 bit unsigned overflow number used in
combination with the sequence number. Starts with `0`.

Sequence Number: 4 byte

Contains the 32 bit unsigned sequence number. Starts with a
cryptographically secure random number and MUST be incremented by `1`
for each message.

Note: The overflow and the sequence number have been defined separately
considering that some programming languages do not have a native 48 bit
unsigned integer type. However, treating the overflow and the sequence
number as a single 48 bit unsigned integer is possible and supported by
this protocol. In further sections, the combined number will be called
*Combined Sequence Number*.

---

# Receiving a SaltyRTC Signalling Message

When a peer receives a SaltyRTC signalling message, it first checks
that the message contains more than 24 byte. It checks that the
destination address is sane:

* A server MUST check that the destination address is `0x00` until the
  sender is authenticated. In case that the sender is authenticated,
  relaying is allowed between an initiator (`0x01`) and a responder
  (`0x02..0xff`). A responders SHALL NOT be able to relay messages to
  another responder.
* A client MUST check that the destination address targets its
  assigned identity (or `0x00` during authentication).

Furthermore, a peer checks that the source address is sane:

* A server MUST check that the source address is `0x00` until a
  specific identity has been assigned to the sender. In case that the
  sender is authenticated, the server MUST check that the source
  address equals the sender's assigned identity.
* A client MUST check that the sender's identity is different to the
  one that the server has assigned to it. If the client has no identity
  yet, the only valid source identity is `0x00`.

In case this is the first message received from the sending peer, the
peer:

* MUST check that the overflow number is `0` (or the leading 16 bits of
  the combined sequence number are `0`, in code:
  `csn & 0xffff00000000 == 0`) and,
* if the peer has already sent a message to the sender, MUST check that
  the sender's cookie is different than its own cookie, and
* MUST store cookie, overflow number and sequence number (or the
  combined sequence number) for checks on further messages.

Afterwards, a peer MUST check that the 16 byte cookie of the sender has
not changed.  

If the message is intended for the server (the destination address is
`0x00`) or the message is being received by a client, the peer does the
following checks:

* In case that the peer does make use of the combined sequence number,
  it MUST check that the combined sequence number has not reset to `0`
  if it was greater than `0` before. Implementations that use the
  combined sequence number SHALL ignore the following three checks.
* In case incrementing the sequence number would not overflow that
  number, the sequence number MUST be incremented by `1` and the
  overflow number MUST remain the same.
* In case incrementing the sequence number would overflow, the sequence
  number MUST be `0` and the overflow number MUST be increased by `1`.
* The overflow number SHALL NOT reset to `0` if it was greater than `0`
  before.

In case that any check fails, the peer MUST close the connection with a
close code of `3001` (*Protocol Error*) unless otherwise stated.

## Processing Client-to-Server Messages

This section describes the various messages that will be exchanged
between server and client.

The messages are serialised MessagePack objects. We will provide an
example for each message in an extended JSON format where a string
value denoted with 'b' indicates that the content is binary data.
For ease of reading, binary data of the examples is represented as a
hex-encoded string. However, binary data SHALL NOT be hex-encoded in
implementations. Unless otherwise noted, all non-binary strings MUST
be interpreted as UTF-8 encoded strings. Furthermore, field values
SHALL NOT be *null*.

In case a client receives an invalid message from another client, the
incident MUST be treated as a protocol violation error.

Messages SHALL NOT be repeated.

### Message Flow

TODO

### Processing a 'server-hello' Message

This message is being sent by the server after a client connected to the server using a valid signalling path. The server MUST generate a new cryptographically secure random NaCl key pair for each client. The public key of that key pair MUST be sent in the payload of this message. This message is not end-to-end encrypted.

```
{
  "type": "server-hello",
  "key": b"debc3a6c9a630f27eae6bc3fd962925bdeb63844c09103f609bf7082bc383610"
}
```

### Processing a 'client-hello' Message

The client sends a public key (32 bytes) to the client.

The message SHALL only be received by SaltyRTC servers. It is being
sent by the server after a client connected to the server using a
valid signalling path. The message is not end-to-end encrypted.
TODO. The message SHALL only be received by SaltyRTC servers.

### Processing a 'client-auth' Message

TODO. The message SHALL only be received by SaltyRTC servers.

### Processing a 'server-auth' Message

TODO. The message SHALL only be received by SaltyRTC clients.

### Processing a 'new-initiator' Message

This message does not require any special processing. It SHALL only be
received by SaltyRTC clients in the role of a responder.

### Processing a 'new-responder' Message

TODO. It SHALL only be received by SaltyRTC clients in the role of the
initiator.

### Processing a 'drop-responder' Message

TODO. The message SHALL only be received by SaltyRTC servers.

### Processing a 'send-error' Message

TODO: Change 'hash' to 'nonce'. The message SHALL only be received by
SaltyRTC clients.

## Processing Peer-to-Peer Messages

The following messages are messages that will be exchanged between two
SaltyRTC clients (peers). A SaltyRTC server has to relay these messages.

In case a server receives such a message from a client and the destination address is set to the server's address (`0x00`), the incident MUST be treated as a protocol violation error by the server.

### Processing a 'token' Message

TODO. The message SHALL only be received by SaltyRTC clients in the
role of the initiator.

### Processing a 'key' Message

TODO.

### Processing an 'auth' Message

TODO.

### Processing a 'restart' Message

TODO

# Errors

## Protocol Violation Error

A protocol violation error MUST be treated by closing the connection 
with a close code of `3001` (*Protocol Error*) unless otherwise stated.

# Close Code Enumeration

The following close codes are being used by the protocol:

- 1001: Going Away
- 1002: No Shared Subprotocol Found
- 3000: Path Full
- 3001: Protocol Error
- 3002: Internal Error
- 3003: Handover of the Signalling Channel
- 3004: Dropped by Initiator

---

# Security Mechanisms

## Cookie

The cookie is being used for two things at the same time. It resembles
a challenge that needs to be repeated by the other peer to mitigate 
replay attacks. A peer can thereby prove that he owns the private key
for the public key he transmitted. Furthermore, it should contain
enough randomness to ensure that a nonce is not being reused for a
shared secret as long as the protocol is being followed closely. To
ensure that nonces are unique per shared secret, peers communicating
with one another must choose different cookies.

## Overflow Number and Sequence Number

Both the overflow number and the sequence number ensure that a nonce
remains a *number used once*. Furthermore, in conjunction with the
cookie, they are being used to mitigate replay attacks.

