# SaltyRTC - Secure WebRTC/ORTC based on NaCl

# Abstract

SaltyRTC is a protocol for WebRTC and ORTC which uses end-to-end encryption techniques based on the Networking and Cryptography library (NaCl) to set up a secure peer-to-peer connection. The protocol has been designed in a way that no third party needs to be trusted. Furthermore, it offers another security layer for WebRTC and ORTC Data Channels.

This document describes the protocol for both client (a peer wanting to set up a WebRTC or ORTC connection) and server (relays signalling data from one client to another).

# Definition

## Client

TODO

## Peer

TODO

## Server

TODO

## MessagePack Object

TODO

## SaltyRTC Address

The SaltyRTC address is a single byte that identifies a specific peer on a WebSocket path. It is being used to indicate to which peer a SaltyRTC server should relay a message.  
The SaltyRTC server (`0x00`) and the initiator (`0x01`) have a static identifier. For responders, the SaltyRTC server will dynamically assign identifiers (`0x02..0xff`).

# SaltyRTC Signalling Message Structure

SaltyRTC signalling messages are encoded in binary using network-oriented format (most significant byte first, also known as *big-endian*). Unless otherwise noted, numeric constants are in decimal (base 10).

All SaltyRTC signalling messages MUST start with a 24-byte nonce followed by either...

* an NaCl public-key authenticated encrypted MessagePack object,
* an NaCl secret-key authenticated encrypted MessagePack object or
* an unencrypted MessagePack object.

Which case applies is always known by the communicating parties. In some scenarios, more than one case is possible. For these scenarios, a description will be provided how multiple cases must be handled.

```
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
```

The nonce is exactly 24 byte that SHALL only be used once per shared secret. A nonce can also be seen as the **header** of SaltyRTC messages as it is used by every single signalling message. It contains the following fields:

```
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
```

Cookie: 16 byte

This field contains 16 cryptographically secure random byte that MUST remain the same for an entire session.

Source: 1 byte

TODO

---

# Receiving a SaltyRTC Signalling Message

When a SaltyRTC peer receives a SaltyRTC signalling message, it first checks that the message contains more than 24 byte. It checks that the destination address is sane:

* For a SaltyRTC server, a valid destination address may be in the full range of `0x00..0xff`. Until the authentication process is complete, the server SHALL NOT allow message relaying to other peers (`0x01..0xff`). Furthermore, relaying is only allowed between an initiator (`0x01`) and a responder (`0x02..0xff`).
* A SaltyRTC client MUST check that the destination address targets its assigned identity (or `0x00` during authentication).

Furthermore, a peer checks that the source address is sane:

* For a SaltyRTC server, the sender SHALL use `0x00` before it has been identified or a value in the range of `0x01..0xff`. The server MUST check that the source identity is the previously assigned identity.
* A SaltyRTC client MUST check that the sender's identity is different to the one that the server has assigned to it. If the client has no identity yet, the only valid source identity is `0x00`.

In case this is the first message received from the sending peer, the peer:

* MUST check that the sequence number is `0`, and
* if the peer has already sent a message to the sender, MUST check that the sender's cookie is different than its own cookie, and
* MUST store cookie and overflow number for checks on further messages.

Afterwards, a peer MUST check that the 16 byte cookie of the sender has not changed. Furthermore, the peer MUST check that:

* in case incrementing the sequence number would not overflow that number, the sequence number MUST have been incremented and the overflow number MUST remain the same.
* in case incrementing the sequence number would overflow, the sequence number MUST be `0` and the overflow number MUST be increased by one modulus 65535.

In case that any check fails, the peer MUST close the connection with a close code of `3001` (*Protocol Error*) unless otherwise stated.

## Processing Client-to-Server Messages

The following messages are messages that will be exchanged between server and client. In case a client receives such a message from another client, the incident MUST be treated as a protocol violation error.

### Processing a 'server-hello' Message

TODO. The message SHALL only be received by SaltyRTC clients.

### Processing a 'client-hello' Message

TODO. The message SHALL only be received by SaltyRTC servers.

### Processing a 'client-auth' Message

TODO. The message SHALL only be received by SaltyRTC servers.

### Processing a 'server-auth' Message

TODO. The message SHALL only be received by SaltyRTC clients.

### Processing a 'new-initiator' Message

This message does not require any special processing. It SHALL only be received by SaltyRTC clients in the role of a responder.

### Processing a 'new-responder' Message

TODO. It SHALL only be received by SaltyRTC clients in the role of the initiator.

### Processing a 'drop-responder' Message

TODO. The message SHALL only be received by SaltyRTC servers.

### Processing a 'send-error' Message

TODO: Change 'hash' to 'nonce'. The message SHALL only be received by SaltyRTC clients.

## Processing Peer-to-Peer Messages

The following messages are messages that will be exchanged between two SaltyRTC clients (peers). In case a server receives such a message from a client, the incident MUST be treated as a protocol violation error.

### Processing a 'token' Message

TODO. The message SHALL only be received by SaltyRTC clients in the role of the initiator.

### Processing a 'key' Message

TODO.

### Processing an 'auth' Message

TODO.

### Processing a 'offer' Message

TODO. The message MUST be considered invalid in case ORTC has been negotiated and SHALL only be received by SaltyRTC clients in the role of the responder.

### Processing a 'answer' Message

TODO. The message MUST be considered invalid in case ORTC has been negotiated and SHALL only be received by SaltyRTC clients in the role of the initiator.

### Processing a 'candidates' Message

TODO: Explain difference when using WebRTC vs. ORTC.

### Processing a 'restart' Message

TODO

---

# Security Mechanisms

## Cookie

The cookie is being used for two things at the same time. It resembles a challenge that needs to be repeated by the other peer. A peer can thereby prove that he owns the private key for the public key he transmitted. Furthermore, it should contain enough randomness to ensure that a nonce is not being reused for a shared secret as long as the protocol is being followed closely. To ensure that nonces are unique per shared secret, peers communicating with one another must choose different cookies.
