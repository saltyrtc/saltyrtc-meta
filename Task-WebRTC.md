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
document are to be interpreted as described in
[RFC 2119 [RFC2119]](https://tools.ietf.org/html/rfc2119).

# Terminology

All terms from the 
[SaltyRTC protocol specification](./Protocol.md#terminology) are valid 
in this document. Furthermore, this document will reference API parts 
of the [WebRTC specification](https://www.w3.org/TR/webrtc/).

## Wrapped Data Channel

This protocol adds another security layer for WebRTC data channels as 
we want our protocol to sustain broken (D)TLS environments. A data 
channel that uses this security layer will be called *Wrapped Data 
Channel*. Note that the user MAY or MAY NOT choose to use wrapped data 
channels for its purpose. However, the signalling channel MUST be 
handed over to a wrapped data channel.

# Task Protocol Name

The following protocol name SHALL be used for task negotiation:

`v0.webrtc.tasks.saltyrtc.org`

TODO: Switch to `v1` as soon as the spec has been reviewed.

# Detecting the Maximum Message Size

For now, all implementations SHALL use the value `16384` which seems to 
be the highest amount of kilobytes that can be applied for portable 
WebRTC data channel communication. An implementation MAY use another 
value if it can guarantee delivery and reception for messages of that 
size. A value of `0` indicates that the implementation is able to 
handle messages of arbitrary length (hooray!).

# Task Data

This task makes use of the *data* field of the 'auth' messages 
described in the 
[SaltyRTC protocol specification](./Protocol.md#auth-message).  
The *Outgoing* section describes what the data of this task SHALL 
contain and how it MUST be generated. Whereas the *Incoming* section 
describes how the task's data from the other client's 'auth' message 
MUST be validated and potentially stored.

## Outgoing

The task's data SHALL be a dictionary/an object containing the 
following items:

* A client MUST set the *cookie_2* field to 16 cryptographically secure 
  random bytes. It SHALL be different to the cookie the client 
  currently uses, the other client currently uses and, for initiators, 
  the *cookie_2* the responder has sent in its task's data.
* The *exclude* field MUST contain a list/an array of WebRTC data 
  channel ids (non-negative integers) that SHALL not be used for the 
  signalling channel. This list MUST be available to be set from user 
  applications that use specific data channel ids.
* The *max_size* field MUST be set to the value described by the 
  *Detecting the Maximum Message Size* section.

## Incoming

A client who receives the task's data from the other peer MUST do the 
following checks:

* A client SHALL validate that the *cookie_2* field's value contains 16 
  bytes and is different to the other client's cookie it currently 
  uses, different to the client's current cookie and different to the 
  client's upcoming cookie.
* The *exclude* field MUST contain a list/an array of WebRTC data 
  channel IDs (non-negative integers) that SHALL not be used for the 
  signalling channel. The client MUST update its internal list of 
  excluded data channel ids by new values of the other client's list.
* The *max_size* field MUST contain either `0` or a positive integer. 
  If one client's value is `0` but the other client's value is greater 
  than `0`, the larger of the two values SHALL be stored to be used for 
  data channel communication. Otherwise, the minimum of both clients' 
  maximum size SHALL be stored. The stored value SHALL be readable by 
  user applications, so a user application can have its own message 
  chunking implementation if desired.

# Message Structure

Before the signalling channel handover takes place, the same message 
structure as defined in the [SaltyRTC protocol specification](./
Protocol.md#message-structure) SHALL be used.

For all messages that are being exchanged over wrapped data channels 
(such as the handed over signalling channel), the nonce/header MUST be 
slightly changed:

     0                   1                   2                   3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |                                                               |
    |                           Cookie 2                            |
    |                                                               |
    |                                                               |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |        Data Channel ID        |        Overflow Number        |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |                        Sequence Number                        |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

Cookie 2: 16 byte

This field contains 16 cryptographically secure random bytes. The only 
difference to the cookie of the SaltyRTC protocol specification is that 
it MUST be different to the cookies of both clients used previously. 
The new cookie will be received when exchanging the task's data takes 
place.

Data Channel ID: 2 byte

Contains the data channel id of the data channel that is being used 
for a message.

Overflow Number and Sequence Number SHALL remain the same as in the 
SaltyRTC protocol specification.

Note that the Source and Destination fields have been replaced by the 
Data Channel ID field. As there can be only communication between the 
peers that set up the peer-to-peer connection, dedicated addresses are 
no longer required.

# Sending a Wrapped Data Channel Message

The same procedure as described in the
[SaltyRTC protocol specification](./Protocol.md#sending-a-signalling-message)
SHALL be followed. However, for all messages that are being exchanged 
over wrapped data channels (such as the handed over signalling 
channel), the following changes MUST be applied:

* All references to the *cookie* SHALL be interpreted as references to 
  *cookie 2*.
* Source and destination addresses SHALL NOT be set.
* The data channel id MUST be set to the id of the data channel the 
  message will be sent on.
* A signalling channel that is being handed over SHALL continue using 
  the overflow number and sequence number counters from the WebSocket-
  based implementation.

# Receiving a Wrapped Data Channel Message

The same procedure as described in the
[SaltyRTC protocol specification](./Protocol.md#receiving-a-signalling-message)
SHALL be followed. However, for all messages that are being exchanged 
over wrapped data channels (such as the handed over signalling 
channel), the following changes MUST be applied:

* All references to the *cookie* SHALL be interpreted as references to 
  *cookie 2*.
* Source and destination addresses SHALL NOT processed or validated.
* A client MUST check that the data channel id field matches the data 
  channel's id the message has been received on.
* A signalling channel that is being handed over SHALL continue using 
  the overflow number and sequence number counters from the WebSocket-
  based implementation.

# Client-to-Client Messages

The following messages are new messages that will be exchanged between 
two clients (initiator and responder) over the signalling channel. 
Note that the signalling channel may be handed over to a data channel 
anytime which is REQUIRED to be supported by the implementation. 
Furthermore, the handed over signalling channel MUST support all 
existing client-to-client message types.

Other messages, general behaviour and error handling for 
client-to-client messages is described in the 
[SaltyRTC protocol specification](./Protocol.md#client-to-client-messages).

## Message States (Beyond 'auth')

```
           +----------+
           |          |
    +------+----------v------+    +-------+
    | offer/answer/candidate +--->+ close |
    +------------------------+    +-------+
```

## Message Flow Example (Beyond 'auth')

```
    Initiator                 Responder
     |                               |
     |             offer             |
     |------------------------------>|
     |             answer            |
     |<------------------------------|
     |      candidate (n times)      |
     |<----------------------------->|
     |             close             |
     |<----------------------------->|
     |                               |
```

## 'offer' Message

TODO

## 'answer' Message

TODO

## 'candidate' Message

TODO


TODO, rubbish below:

* A responder SHALL set the *offer* field to the *sdp* field of its 
  WebRTC `RTCPeerConnection`'s local description it has generated with 
  calling `createOffer` on the `RTCPeerConnection` instance.
* An initiator SHALL set the *answer* field to the *sdp* field of its 
  WebRTC `RTCPeerConnection`'s local description it has generated with 
  calling `createAnswer` on the `RTCPeerConnection` instance.

* An initiator SHALL validate that the *offer* field contains an SDP 
  string. It SHALL continue by setting the value of that field as the 
  WebRTC `RTCPeerConnection`'s remote description.
* A responder SHALL validate that the *answer* field contains an SDP 
  string. Furthermore, it SHALL set the value of that field as the 
  WebRTC `RTCPeerConnection`'s remote description.

