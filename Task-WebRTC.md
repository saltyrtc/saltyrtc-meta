# SaltyRTC WebRTC Task

This task uses the end-to-end encryption techniques of SaltyRTC to set
up a secure WebRTC peer-to-peer connection. It also adds another
security layer for data channels that are available to users. The
signalling channel will persist after being handed over to a dedicated
data channel once the peer-to-peer connection has been set up.
Therefore, further signalling communication between the peers does not
require a dedicated WebSocket connection over a SaltyRTC server.

# Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in [RFC 2119
[RFC2119]](https://tools.ietf.org/html/rfc2119).

# Terminology

All terms from the
[SaltyRTC protocol specification](./Protocol.md#terminology) are valid
in this document. Furthermore, this document will reference API parts
of the [WebRTC specification](https://www.w3.org/TR/webrtc/).

## Message Chunking

The
[SaltyRTC chunking specification](https://github.com/saltyrtc/saltyrtc-meta/blob/master/Chunking.md)
makes it possible to split a message into chunks and reassemble the
message on the receiver's side while allowing any combination of
ordered/unordered and reliable/unreliable transport channel underneath.
Depending on the WebRTC data channel implementation, message chunking
may or may not be applied to all wrapped data channels.

## Wrapped Data Channel

This protocol adds another security layer for WebRTC data channels as we
want our protocol to sustain broken (D)TLS environments. A data channel
that uses this security layer will be called *Wrapped Data Channel*.
Note that the user MAY or MAY NOT choose to use wrapped data channels
for its purpose. However, the signalling channel MUST be handed over to
a wrapped data channel.

# Task Protocol Name

The following protocol name SHALL be used for task negotiation:

`v0.webrtc.tasks.saltyrtc.org`

TODO: Switch to `v1` as soon as the spec has been reviewed.

# Detecting the Maximum Message Size

For now, all implementations SHALL use the value `16384` which seems to
be the highest amount of kilobytes that can be applied for portable
WebRTC data channel communication. An implementation MAY use another
value if it can guarantee delivery and reception for messages of that
size. A value of `0` indicates that the implementation is able to handle
messages of arbitrary length (hooray!).

# Task Data

This task makes use of the *data* field of the 'auth' messages described
in the [SaltyRTC protocol specification](./Protocol.md#auth-message).
The *Outgoing* section describes what the data of this task SHALL
contain and how it MUST be generated. Whereas the *Incoming* section
describes how the task's data from the other client's 'auth' message
MUST be validated and potentially stored.

## Outgoing

The task's data SHALL be a `Map` containing the following items:

* The *exclude* field MUST contain an `Array` of WebRTC data channel ids
  (non-negative integers) that SHALL not be used for the signalling
  channel. This `Array` MUST be available to be set from user
  applications that use specific data channel ids.
* The *max_packet_size* field MUST be set to the value described by the
  *Detecting the Maximum Message Size* section.

## Incoming

A client who receives the task's data from the other peer MUST do the
following checks:

* The *exclude* field MUST contain an `Array` of WebRTC data channel IDs
  (non-negative integers) that SHALL not be used for the signalling
  channel. The client SHALL store this list for usage during handover.
* The *max_packet_size* field MUST contain either `0` or a positive
  integer. If one client's value is `0` but the other client's value is
  greater than `0`, the larger of the two values SHALL be stored to be
  used for data channel communication. Otherwise, the minimum of both
  clients' maximum size SHALL be stored. The stored value SHALL be
  readable by user applications, so a user application can have its own
  message chunking implementation if desired.

# Wrapped Data Channel

This protocol adds another security layer to WebRTC's data channels. To
allow both the user's application and the handed over signalling channel
to easily utilise this security layer, it is RECOMMENDED to provide a
wrapper/proxy to the `RTCDataChannel` interface. Underneath, the wrapped
data channel MUST use NaCl for encryption/decryption and chunk messages
as specified in the
[SaltyRTC chunking specification](https://github.com/saltyrtc/saltyrtc-meta/blob/master/Chunking.md)
if necessary.

Outgoing messages MUST be processed and encrypted by following the
*Sending a Wrapped Data Channel Message* section. The encrypted messages
SHALL be split into chunks using SaltyRTC message chunking ONLY in case
the negotiated *max_packet_size* parameter from the task's data is
greater than `0`; in that case the message chunking implementation SHALL
use the *max_packet_size* as the maximum chunk size. Otherwise, the
encrypted message SHALL be sent as is.

Incoming messages SHALL be stitched together using SaltyRTC message
chunking if required (see the previous paragraph for details). Complete
messages MUST be processed and decrypted by following the *Receiving a
Wrapped Data Channel Message* section. The resulting complete message
SHALL raise a corresponding message event.

As described in the *Sending a Wrapped Data Channel Message* and the
*Receiving a Wrapped Data Channel Message* section, each new wrapped
data channel instance is being treated as a new peer from the nonce's
perspective and independent of the underlying data channel id. To
prevent nonce reuse, it is absolutely vital that each wrapped data
channel instance has its own cookie, sequence number and overflow
number, each for incoming and outgoing messages. Both clients SHALL use
cryptographically secure random numbers for the cookie and the sequence
number.

Due to a bug in older Chromium-based implementations, the implementation
MUST check that a newly created data channel does not use the same data
channel id of another data channel instance that is currently `open`.

# Signalling Channel Handover

As soon as both clients have exchanged the required messages and the
WebRTC `RTCPeerConnection` instance informs the user application that
the peer-to-peer connection setup is complete, the user application
SHALL request that the client hands over the signalling channel to a
dedicated data channel:

1. The client creates a new data channel on the `RTCPeerConnection`
   instance with the `RTCDataChannelInit` object containing only the
   following values:
   * *ordered* SHALL be set to `true`,
   * *protocol* SHALL be set to the same subprotocol that has been
     negotiated with the server,
   * *negotiated* MUST be set to `true`, and
   * *id* SHALL be set to the lowest possible number, starting from `0`,
     that is not excluded by both clients as negotiated.
2. The newly created `RTCDataChannel` instance shall be wrapped by
   following the *Wrapped Data Channel* section.
3. As soon as the data channel is `open`, the client SHALL send a
   'handover' message to the other client. After this message, the
   client SHALL NOT send any messages on the original signalling
   channel. The sequence number and overflow number for outgoing
   messages to the other client SHALL be transferred to the new wrapped
   data channel. The client MAY already send signalling messages over
   the new signalling channel. If the client has already received a
   'handover' message from the other client, it MUST continue with the
   next step, skipping the following sentences. Otherwise, the client
   MUST accept further messages from the other client on the original
   signalling channel only and wait for an incoming 'handover' message.
   Once that 'handover' message has been received, the client SHALL ONLY
   accept signalling messages over the wrapped data channel.
   Furthermore, it SHALL transfer the sequence number and overflow
   number for incoming messages of the other client to the wrapped data
   channel.
4. After both clients have sent each other 'handover' messages, the
   client closes the connection to the server with a close code of
   `3003` (*Handover of the Signalling Channel*).

# Message Structure

Before the signalling channel handover takes place, the same message
structure as defined in the
[SaltyRTC protocol specification](./Protocol.md#message-structure)
SHALL be used.

For all messages that are being exchanged over wrapped data channels
(such as the handed over signalling channel), the nonce/header MUST be
slightly changed:

     0                   1                   2                   3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |                                                               |
    |                            Cookie                             |
    |                                                               |
    |                                                               |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |        Data Channel ID        |        Overflow Number        |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |                        Sequence Number                        |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

Data Channel ID: 2 byte

Contains the data channel id of the data channel that is being used for
a message.

The cookie field remains the same as in the SaltyRTC protocol
specification. Each new wrapped data channel SHALL have a new
cryptographically secure random cookie, one for incoming messages and
one for outgoing messages.

Overflow Number and Sequence Number SHALL remain the same as in the
SaltyRTC protocol specification. Each new wrapped data channel instance
SHALL have its own overflow number and sequence number, each for
outgoing and incoming messages.

Note that the Source and Destination fields have been replaced by the
Data Channel ID field. As there can be only communication between the
peers that set up the peer-to-peer connection, dedicated addresses are
no longer required.

# Sending a Wrapped Data Channel Message

The same procedure as described in the
[SaltyRTC protocol specification](./Protocol.md#sending-a-signalling-message)
SHALL be followed. However, for all messages that are being exchanged
over wrapped data channels (such as the handed over signalling channel),
the following changes MUST be applied:

* Each data channel instance SHALL have its own cookie, overflow number
  and sequence number for outgoing messages.
* Source and destination addresses SHALL NOT be set, instead
* The data channel id MUST be set to the id of the data channel the
  message will be sent on.

# Receiving a Wrapped Data Channel Message

The same procedure as described in the
[SaltyRTC protocol specification](./Protocol.md#receiving-a-signalling-message)
SHALL be followed. However, for all messages that are being exchanged
over wrapped data channels (such as the handed over signalling channel),
the following changes MUST be applied:

* Each data channel instance SHALL have its own cookie, overflow number
  and sequence number for incoming messages.
* Source and destination addresses are not present in the wrapped data
  channel's nonce/header.
* Overflow number and sequence number SHALL NOT be validated to ensure
  unordered and unreliable wrapped data channels can function properly.
* A client MUST check that the data channel id field matches the data
  channel's id the message has been received on.

# Client-to-Client Messages

The following messages are new messages that will be exchanged between
two clients (initiator and responder) over the signalling channel. Note
that the signalling channel may be handed over to a data channel anytime
which is REQUIRED to be supported by the implementation. Furthermore,
the handed over signalling channel MUST support all existing
client-to-client message types.

Other messages, general behaviour and error handling for
client-to-client messages is described in the
[SaltyRTC protocol specification](./Protocol.md#client-to-client-messages).

## Message States (Beyond 'auth')

```
             +---------+    +-----------------------------+
             |         v    |                             v
        +----+---------+----+----+     +----------+    +---+---+
    --->+ offer/answer/candidates +--->+ handover +--->+ close |
        +------------------------+     +-----+----+    +---+---+
                                             |             ^
                                             v             |
                         +-------------------+-----+       |
                         | offer/answer/candidates +--------
                         +----+--------------+-----+
                              |              ^
                              +--------------+
```

## Message Flow Example (Beyond 'auth')

```
    Initiator                 Responder
     |                               |
     |             offer             |
     |------------------------------>|
     |             answer            |
     |<------------------------------|
     |      candidates (n times)     |
     |<----------------------------->|
     |            handover           |
     |------------------------------>|
     |            handover           |
     |<------------------------------|
     |      candidates (m times)     |
     |<----------------------------->|
     |             close             |
     |<----------------------------->|
     |                               |
```

## 'offer' Message

At any time, the initiator MAY send an 'offer' message to the responder.

The initiator MUST set the *offer* field to the `Map` of its WebRTC
`RTCPeerConnection`'s local description the user application has
generated with calling `createOffer` on the `RTCPeerConnection`
instance. The *offer* field SHALL be a `Map` and MUST contain:

* The *type* field containing a valid `RTCSdpType` in string
  representation.
* The *sdp* field containing a blob of SDP data in string
  representation. If the *type* field is `rollback`, the field MAY be
  omitted.

The responder SHALL validate that the *offer* field is a `Map`
containing the above mentioned fields and value types. It SHALL continue
by requesting the user application to set the value of that field as the
WebRTC `RTCPeerConnection`'s remote description and creating an answer.

The message SHALL be NaCl public-key encrypted by the client's session
key pair and the other client's session key pair.

```
{
  "type": "offer",
  "offer": {
    "type": "offer",
    "sdp": "..."
  }
}
```

## 'answer' Message

Once the user application of the responder has set the remote
description on its WebRTC `RTCPeerConnection` instance and generated an
answer by calling `createAnswer` on the instance, the user application
SHALL request sending an 'answer' message. The *answer* field SHALL be a
`Map` and MUST contain:

* The *type* field containing a valid `RTCSdpType` in string
  representation.
* The *sdp* field containing a blob of SDP data in string
  representation. If the *type* field is `rollback`, the field MAY be
  omitted.

The initiator SHALL validate that the *answer* field is a `Map`
containing the above mentioned fields and value types. It SHALL continue
by requesting the user application to set the value of that field as the
WebRTC `RTCPeerConnection`'s remote description.

The message SHALL be NaCl public-key encrypted by the client's session
key pair and the other client's session key pair.

```
{
  "type": "answer",
  "answer": {
    "type": "answer",
    "sdp": "..."
  }
}
```

## 'candidates' Message

Both clients MAY send ICE candidates at any time to each other. Clients
SHOULD bundle available candidates.

A client who sends an ICE candidate SHALL set the *candidates* field to
an `Array` of `Map`s where each `Map` SHALL contain the following
fields:

* The *candidate* field SHALL contain an SDP `candidate-attribute` as
  defined in the WebRTC specification in string representation.
* The *sdpMid* field SHALL contain the *media stream identification*
  as defined in the WebRTC specification in string representation or
  `Nil`.
* The *sdpMLineIndex* field SHALL contain the index of the media
  description the candidate is associated with as described in the
  WebRTC specification. It's value SHALL be either an unsigned integer
  (16 bits) or `Nil`.

*(Note: The naming is inconsistent with the rest of the protocol,
because it uses camelCase keys instead of under_scores. The reason for
this is ease of use in browser implementations: When using camelCase
each `candidates` entry can be passed directly to the JavaScript WebRTC
implementation.)*

The receiving client SHALL validate that the *candidates* field is an
`Array` containing one or more `Map`s. These `Map`s SHALL contain the
above mentioned fields value types. It SHALL continue by requesting the
user application to add the value of each item in the `Array` as a
remote candidate to its WebRTC `RTCPeerConnection` instance.

The message SHALL be NaCl public-key encrypted by the client's session
key pair and the other client's session key pair.

```
{
  "type": "candidate",
  "candidates": [
    {
      "candidate": "...",
      "sdpMid": "data",
      "sdpMLineIndex": 0
    }, {
      "candidate": "...",
      "sdpMid": "data",
      "sdpMLineIndex": 0
    }, ...
  ]
}
```

## 'handover' Message

Both clients SHALL send this message once the wrapped data channel
dedicated for the signalling is `open`. However, the message MUST be
sent on the signalling channel that has been established over the
SaltyRTC server. The message SHALL NOT be sent over an already handed
over signalling channel.

A client who sends a 'handover' message SHALL NOT include any additional
fields. After sending this message, the client MUST:

* Transfer the overflow number and sequence number for outgoing
  signalling messages destined at the other client to the new signalling
  channel (based on the wrapped data channel), and
* Send further signalling messages over the new signalling channel only.

After a client has received a 'handover' message, it SHALL:

* Transfer the overflow number and sequence number for incoming messages
  of the other client to the new signalling channel (based on the
  wrapped data channel),
* Receive incoming signalling messages over the new signalling channel
  only, and
* In case it receives further signalling messages over the old
  signalling channel, treat this incident as a protocol error.

The message SHALL be NaCl public-key encrypted by the client's session
key pair and the other client's session key pair.

```
{
  "type": "handover"
}
```

## 'close' Message

The message itself and the client's behaviour is described in the
[SaltyRTC protocol specification](./Protocol.md#close-message). Once the
signalling channel has been handed over to a wrapped data channel, sent
and received 'close' messages SHALL trigger closing the underlying data
channel used for signalling. The user application MAY continue using the
`RTCPeerConnection` instance and its data channels. However, wrapped
data channels MAY or MAY NOT be available once the signalling's data
channel has been closed, depending on the flexibility of the client's
implementation.
