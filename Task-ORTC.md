# SaltyRTC ORTC Task

This task uses the end-to-end encryption techniques of SaltyRTC to set
up a secure ORTC peer-to-peer connection. It also adds another security
layer for data channels that are available to users. The signalling
channel will persist and should be handed over to a dedicated data
channel once the peer-to-peer connection has been set up. Therefore,
further signalling communication between the peers may not require a
dedicated WebSocket connection over a SaltyRTC server.

# Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in [RFC 2119
[RFC2119]](https://tools.ietf.org/html/rfc2119).

# Terminology

All terms from the
[SaltyRTC protocol specification](./Protocol.md#terminology) are valid
in this document. Furthermore, this document will reference API parts
of the [ORTC specification draft](http://draft.ortc.org).

TODO: Update specification URL once it's completed

## Message Chunking

The
[SaltyRTC chunking specification](https://github.com/saltyrtc/saltyrtc-meta/blob/master/Chunking.md)
makes it possible to split a message into chunks and reassemble the
message on the receiver's side while allowing any combination of
ordered/unordered and reliable/unreliable transport channel underneath.
Depending on the ORTC data channel implementation, message chunking may
or may not be applied to all wrapped data channels.

## Wrapped Data Channel

This protocol adds another security layer for ORTC data channels as we
want our protocol to sustain broken (D)TLS environments. A data channel
that uses this security layer will be called *Wrapped Data Channel*.
Note that the user MAY or MAY NOT choose to use wrapped data channels
for its purpose. However, the handed over signalling channel MUST use a
wrapped data channel.

# Task Protocol Name

The following protocol name SHALL be used for task negotiation:

`v0.ortc.tasks.saltyrtc.org`

TODO: Switch to `v1` as soon as the spec has been reviewed.

# Task Data

This task makes use of the *data* field of the 'auth' messages described
in the [SaltyRTC protocol specification](./Protocol.md#auth-message).
The *Outgoing* section describes what the data of this task SHALL
contain and how it MUST be generated. Whereas the *Incoming* section
describes how the task's data from the other client's 'auth' message
MUST be validated and potentially stored.

## Data Transport Types

Below is a list of data channel transport types defined by ORTC and their
corresponding string representation used to negotiate the transport type
for handing over the signalling channel:

* `RTCSctpTransport`: `sctp`

## Outgoing

The task's data SHALL be a `Map` containing the following items:

* The *exclude* field MUST contain an `Array` of WebRTC data channel ids
  (non-negative integers) that SHALL not be used for the signalling
  channel. This `Array` MUST be available to be set from user
  applications that use specific data channel ids.
* The *handover* field SHALL be set to an `Array` containing supported
  data transport types as defined in the *Data Transport Types* section.
  If the user application explicitly requests to turn off the handover
  feature or the implementation has knowledge that `RTCDataChannel`s are
  not supported, the field's value SHALL be an empty `Array`.

## Incoming

A client who receives the task's data from the other peer MUST do the
following checks:

* The *exclude* field MUST contain an `Array` of WebRTC data channel IDs
  (non-negative integers) that SHALL not be used for the signalling
  channel. The client SHALL store this list for usage during handover.
* The *handover* field MUST be an `Array`. Each element in the `Array`
  SHALL be a string. The client SHALL continue by comparing the provided
  data transport types to its own `Array` of supported data transports
  it has provided in the outgoing *handover* field. It MUST choose the
  first data transport type that is also contained in the `Array`
  provided by the other client. In case no common data transport type
  could be found or either of the `Array`s was empty, the handover
  feature SHALL be turned off.


# Wrapped Data Channel

This protocol adds another security layer to ORTC's data channels. To
allow both the user's application and the handed over signalling channel
to easily utilise this security layer, it is RECOMMENDED to provide a
wrapper/proxy to the `RTCDataChannel` interface. Underneath, the wrapped
data channel MUST use NaCl for encryption/decryption and chunk messages
as specified in the
[SaltyRTC chunking specification](https://github.com/saltyrtc/saltyrtc-meta/blob/master/Chunking.md)
if necessary.

Outgoing messages MUST be processed and encrypted by following the
*Sending a Wrapped Data Channel Message* section. The maximum message
size SHALL be determined by the following procedure:

* If the `RTCDataChannel`s transport instance is of type
  `RTCSctpTransport`, then the maximum packet size is the value of the
  `RTCSctpTransport`'s `RTCSctpCapabilities.maxMessageSize` field.

If the determined maximum packet size is greater than `0`, the message
chunking implementation SHALL use that value as the maximum chunk size.
Otherwise, the encrypted message SHALL be sent as is.

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

# Signalling Channel Handover

If the underlying implementation of ORTC supports `RTCDataChannel`s and
the other client supports it as well, it is RECOMMENDED to use this
feature.

As soon as both clients have exchanged the required messages and the ORTC
`RTCDtlsTransport` instance's state informs the user application that a
DTLS connection has been established, the user application SHOULD request
that the client hands over the signalling channel to a dedicated data
channel:

1. If the negotiated data transport type's instance is not available
   yet, the client SHALL create the necessary `RTCDataTransport`
   subclass instance. To be able to create this instance, the client MAY
   need to send additional parameters and capabilities. To be able to
   designate these for handover, the *label* field of each message SHALL
   be set to `handover`.
2. The client creates a new `RTCDataChannel` instance from the negotiated
   `RTCDataTransport` instance and the `RTCDataChannelParameters` object 
   containing only the following values:
   * *ordered* SHALL be set to `true`,
   * *protocol* and *label* SHALL be set to the same subprotocol that has
     been negotiated with the server,
   * *negotiated* MUST be set to `true`, and
   * *id* SHALL be set to the lowest possible number, starting from `0`,
     that is not excluded by both clients as negotiated.
3. The newly created `RTCDataChannel` instance shall be wrapped by
   following the *Wrapped Data Channel* section.
4. As soon as the data channel is `open`, the client SHALL send a
   'handover' message on the WebSocket-based signalling channel (*WS
   channel*) to the other client. Subsequent outgoing messages MUST be
   sent over the data channel based signalling channel (*DC channel*).
   Incoming messages on the DC channel MUST be buffered. Incoming
   messages on the WS channel SHALL be accepted until a 'handover'
   message has been received on the WS channel. Once that message has
   been received, the client SHALL process the buffered messages from
   the DC channel. Subsequent signalling messages SHALL ONLY be accepted
   over the DC channel.
5. After both clients have sent each other 'handover' messages, the
   client closes the connection to the server with a close code of
   `3003` (*Handover of the Signalling Channel*).

If the `RTCDataChannel` could not be created or the created
`RTCDataChannel` does not change its state to `open`, the client SHALL
continue using the WebSocket-based signalling channel.

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
  However, a client SHOULD check that two consecutive incoming messages
  of the same data channel do not have the exact same overflow and
  sequence number.
* A client MUST check that the data channel id field matches the data
  channel's id the message has been received on.

# Client-to-Client Messages

The following messages are new messages that will be exchanged between
two clients (initiator and responder) over the signalling channel. Note
that the signalling channel may be handed over to a data channel anytime
which SHOULD be supported by the implementation. Furthermore, the handed
over signalling channel MUST support all existing client-to-client
message types.

Other messages, general behaviour and error handling for
client-to-client messages is described in the
[SaltyRTC protocol specification](./Protocol.md#client-to-client-messages).

## Message States (Beyond 'auth')

        +--------------------------------------+
        |  ice-parameters / ice-candidates /   |
    --->+ dtls-parameters / rtp-capabilities / |
        | sctp-capabilities / dc-parameters /  +------+
        |             application              |      |
        +-----------------+--------------------+      |
                          |                           |
                          v                           v
                     +----+-----+                 +---+---+
                     | handover +---------------->+ close |
                     +----+-----+                 +---+---+
                          |                           ^
                          v                           |
        +-----------------+--------------------+      |
        |  ice-parameters / ice-candidates /   |      |
        | dtls-parameters / rtp-capabilities / +------+
        | sctp-capabilities / dc-parameters /  |
        |             application              |
        +--------------------------------------+

## Message Flow Example (Beyond 'auth')

    Initiator                 Responder
     |                               |
     |        ice-parameters         |
     |<----------------------------->|
     |   ice-candidates (n times)    |
     |<----------------------------->|
     |        dtls-parameters        |
     |<----------------------------->|
     |       rtp-capabilities        |
     |<----------------------------->|
     |       sctp-capabilities       |
     |<----------------------------->|
     |            handover           |
     |------------------------------>|
     |            handover           |
     |<------------------------------|
     |         dc-parameters         |
     |<----------------------------->|
     |             close             |
     |<----------------------------->|
     |                               |

## 'ice-parameters' Message

At any time, both clients may send an ICE parameters message.

The sender MUST set the *parameters* field to a `Map` containing the
following fields from an `RTCIceParameters` object:

* *usernameFragment* of type string.
* *password* of type string.
* *iceLite* of type boolean.

In addition, the sender MAY set the *role* field to a valid `RTCIceRole`
string. A *label* field MAY be set to a string to be able to distinguish
`RTCIceParameters` for different ICE transports.

The receiving client SHALL validate that the *parameters* field is a
`Map` containing the above mentioned fields and their types.
Furthermore, if the field *role* is set, it SHALL be a valid `RTCIceRole`
string.

The message SHALL be NaCl public-key encrypted by the client's session
key pair and the other client's session key pair.

```
{
  "type": "ice-parameters",
  "parameters": {
    "usernameFragment": "abcd...",
    "password": "efgh...",
    "iceLite": false
  },
  "role": "controlling", // optional
  "label": "echo-service" // optional
}
```

## 'ice-candidates' Message

Both clients MAY send ICE candidates at any time to each other. Clients
SHOULD bundle available candidates.

A client who sends an ICE candidate SHALL set the *candidates* field to
an `Array` of `Map`s where each `Map` SHALL contain the following
fields:

* *candidate* as described below.
* *label* SHALL be an optional field that MAY be set to a string to be
  able to distingiush `RTCIceCandidate`s for different ICE transports.

Each *candidate* field SHALL be a `Map` containing either a single field
*complete* which MUST be set to `true` or the following fields:

* *foundation* of type string.
* *priority* of type 32 bit unsigned integer.
* *ip* of type string.
* *protocol* of type string containing one of the protocol types defined
  by `RTCIceProtocol`.
* *port* of type 16 bit unsigned integer.
* *type* of type string containing one of the ICE candidate types
  defined by `RTCIceCandidateType`.
* *tcpType* of type string containing one of the ICE TCP candidate types
  defined by `RTCIceTcpCandidateType`. This field MUST be omitted in
  case the candidate's protocol is not TCP.
* *relatedAddress* of type string. This field SHALL be omitted in case
  the candidate has no related address.
* *relatedPort* of type 16 bit unsigned integer. The field MUST be
  omitted in case the candidate has no related port.

The receiving client SHALL validate that the *candidates* field is an
`Array` containing one or more `Map`s. These `Map`s SHALL contain the
above mentioned fields, sub-fields and their types.

The message SHALL be NaCl public-key encrypted by the client's session
key pair and the other client's session key pair.

```
{
  "type": "ice-candidates",
  "candidates": [{
    "candidate": {
      "foundation": "f4d3...",
      "priority": 12345,
      "ip": "192.168.1.1",
      "protocol": "udp",
      "port": 48765,
      "type": "host",
    },
    "label": "echo-service" // optional
  }, {
    "candidate": {
      "foundation": "abcd...",
      "priority": 1234,
      "ip": "1.1.1.1",
      "protocol": "udp",
      "port": 42354,
      "type": "srflx",
      "relatedAddress": "192.168.1.1",
      "relatedPort": 48766
    },
    "label": "echo-service" // optional
  }, {
    "candidate": {
      "foundation": "1111...",
      "priority": 123,
      "ip": "192.168.1.1",
      "protocol": "tcp",
      "port": 48767,
      "type": "host",
      "tcpType": "active"
    },
    "label": "echo-service" // optional
  }, {
    "candidate": {
      "complete": true
    },
    "label": "echo-service" // optional
  }]
}
```

## 'dtls-parameters' Message

At any time, both clients may send a DTLS parameters message.

The sender MUST set the *parameters* field to a `Map` containing the
following fields from an `RTCDtlsParameters` object:

* *role* of type string containing one of the roles defined by
  `RTCDtlsRole`.
* *fingerprints* SHALL be an `Array` containing one or more `Map` where
  each `Map` contains the fields *algorithm* and *value*, both of type
  string as defined by the `RTCDtlsFingerprint` object.

Furthermore, a *label* field MAY be set to a string to be able to
distinguish `RTCDtlsParameters` for different DTLS transports.

The receiving client SHALL validate that the *role* field contains a
valid `RTCDtlsRole` value. Furthermore, it MUST validate that the field
*fingerprints* contains an `Array` with at least one `Map` containing
the above mentioned `RTCDtlsFingerprint` fields and their types.

The message SHALL be NaCl public-key encrypted by the client's session
key pair and the other client's session key pair.

```
{
  "type": "dtls-parameters",
  "parameters": {
    "role": "auto",
    "fingerprints": [{
      "algorithm": "sha-256",
      "value": "00aabb..."
    }, ...]
  },
  "label": "echo-service" // optional
}
```

## 'rtp-capabilities' Message

At any time, both clients may send a RTP capabilities message.

The sender MUST set the *capabilities* field to an `Array` of `Map`s
where each `Map` SHALL contain the following fields:

* *capabilities* SHALL contain a `Map` described by the ORTC
  specification's `RTCRtpCapabilities` dictionary. The term `sequence`
  shall be interpreted as `Array`, `DOMString` and `USVString` as
  `String`, `object` and `Dictionary` as `Map`, `unsigned short` as
  unsigned 16 bit `Integer`, `unsigned long` as unsigned 32 bit
  `Integer`, `unsigned long long` as unsigned 64 bit `Integer`, `enum`
  values as `String` and `null` as `Nil`.
* *label* is an optional field that MAY be set to a string to be able to
  distinguish `RTCRtpCapabilities` for different RTP sender and receiver
  instances.

The receiving client SHALL validate that the *capabilities* field
contains an `Array` of `Map`s. Each `Map` SHALL contain the above
mentioned fields, sub-fields and their types. Note that simply passing
each *capabilities* `Map` to the corresponding ORTC implementation is
also considered a form of validation.

The message SHALL be NaCl public-key encrypted by the client's session
key pair and the other client's session key pair.

```
{
  "type": "rtp-capabilities",
  "capabilities": [{
    "capabilities": {
      "codecs": [...],
      "headerExtensions": [...],
      "fecMechanisms": [...]
    },
    "label": "echo-service-audio" // optional
  }, {
    "capabilities": {
      "codecs": [...],
      "headerExtensions": [...],
      "fecMechanisms": [...]
    },
    "label": "echo-service-video" // optional
  }, ...]
}
```

## 'sctp-capabilities' Message

At any time, both clients MAY send a SCTP capabilities message.

The sender MUST set the *capabilities* field to a `Map` containing the
following fields:

* *maxMessageSize* of type unsigned 16 bit integer.

Furthermore, a *label* field MAY be set to a string to be able to
distinguish `RTCSctpCapabilities` for different SCTP transports. The
label value `handover` is reserved and SHALL NOT be used by user
applications.

The receiving client SHALL validate that the *capabilities* field
contains the amove mentioned fields and their types.

The message SHALL be NaCl public-key encrypted by the client's session
key pair and the other client's session key pair.

```
{
  "type": "sctp-capabilities",
  "capabilities": {
    "maxMessageSize": 16384
  },
  "label": "echo-service" // optional
}
```

## 'dc-parameters' Message

Both clients MAY send data channel parameters at any time to each other
(Note that sending this message is not required to set up a
`RTCDataChannel` instance on both sides, at least not in case
`RTCSctpTransport` is being used.)

A client who sends data channel parameters SHALL set the following
fields:

* *parameters* as described below.
* *label* SHALL be an optional field that MAY be set to a string to be
  able to distingiush parameters and capabilities for different data
  channels. Note that this *label* field is not the same as the one of
  the *parameters* field.

The *parameters* field SHALL be a `Map` containing the following fields:

* *id* of type unsigned 16 bit integer.
* *label* is an optional field of type string.
* *ordered* is an optional field of type boolean.
* *maxPacketLifetime* is an optional field of type unsigned 32 bit
  integer.
* *maxRetransmits* is an optional field of type unsigned 32 bit integer.
* *protocol* is an optional field of type string.

The receiving client SHALL validate that the *parameters* field is a
`Map` containing the above mentioned fields and their types.

The message SHALL be NaCl public-key encrypted by the client's session
key pair and the other client's session key pair.

```
{
  "type": "dc-parameters",
  "parameters": {
    "id": 42,
    "label": "echo-service", // optional
    "ordered": true, // optional
    "protocol": "echo-service-protocol" // optional
  },
  "label": "echo-service-data" // optional
}
```

## 'handover' Message

Both clients SHALL send this message once the wrapped data channel
dedicated for the signalling is `open`. However, the message MUST be
sent on the signalling channel that has been established over the
SaltyRTC server. The message SHALL NOT be sent over an already handed
over signalling channel.

A client who sends a 'handover' message SHALL NOT include any additional
fields. After sending this message, the client MUST send further
signalling messages over the new signalling channel only.

After a client has received a 'handover' message, it SHALL:

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
channel used for signalling. The user application MAY continue using
`RTCDataChannel`s. However, wrapped data channels MAY or MAY NOT be
available once the signalling's data channel has been closed, depending
on the flexibility of the client's implementation.

## 'application' Message

The message itself and the client's behaviour is described in the
[SaltyRTC protocol specification](./Protocol.md#application-message).

