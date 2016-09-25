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

For now, all implementations SHALL use the value `16384` which seems 
to be the highest amount of kilobytes that can be applied for portable 
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

* A client MUST set the *cookie_2* field to 16 cryptographically 
  secure random bytes. It SHALL be different to the cookie the client 
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

* A client SHALL validate that the *cookie_2* field's value contains
  16 bytes and is different to the other client's cookie it currently 
  uses, different to the client's current cookie and different to the 
  client's upcoming cookie.
* The *exclude* field MUST contain a list/an array of WebRTC data 
  channel IDs (non-negative integers) that SHALL not be used for the 
  signalling channel. The client MUST update its internal list of 
  excluded data channel ids by new values of the other client's list. 
  The resulting list MUST be stored sorted in ascending order.
* The *max_size* field MUST contain either `0` or a positive integer. 
  If one client's value is `0` but the other client's value is greater 
  than `0`, the larger of the two values SHALL be stored to be used 
  for data channel communication. Otherwise, the minimum of both 
  clients' maximum size SHALL be stored. The stored value SHALL be 
  readable by user applications, so a user application can have its 
  own message chunking implementation if desired.

# Wrapped Data Channel

This protocol adds another security layer to WebRTC's data channels. 
To allow both the user's application and the handed over signalling 
channel to easily utilise this security layer, it is RECOMMENDED to 
provide a wrapper/proxy to the `RTCDataChannel` interface. Underneath, 
the wrapped data channel MUST use NaCl for encryption/decryption and 
the `chunked-dc` message chunking implementation (if necessary) in the 
following way:

* Outgoing messages MUST be processed and encrypted by following the 
  *Sending a Wrapped Data Channel Message* section. The encrypted 
  messages SHALL be split to chunks using `chunked-dc` message 
  chunking ONLY in case the negotiated *max_size* parameter from the 
  task's data is greater than `0`; in that case the `chunked-dc` 
  implementation SHALL use the *max_size* as the maximum chunk size. 
  Otherwise, the encrypted message SHALL be sent as is.
* Incoming messages SHALL be stitched together using `chunked-dc` 
  message chunking if required (see previous bullet item for details). 
  Complete messages MUST be processed and decrypted by following the 
  *Receiving a Wrapped Data Channel Message* section. The resulting 
  complete message SHALL raise a corresponding message event.

The 
[`chunked-dc` message chunking format](https://github.com/saltyrtc/chunked-dc-js#format) 
allows the use of any combination of ordered/unordered and 
reliable/unreliable data channels while guaranteeing complete messages 
in any case.

Each wrapped data channel id has its own overflow number and sequence 
number. The overflow and sequence number SHALL persist once a data 
channel has been stored. The numbers MUST be restored once a data 
channel id is being reused. This is absolutely vital to prevent 
reusing a nonce!  
Due to a bug in older Chromium-based implementations, the 
implementation MUST check that a newly created data channel does not 
use a data channel id of another data channel instance that is 
currently *open*.

# Signalling Channel Handover

As soon as both clients have exchanged the required messages and the 
WebRTC `RTCPeerConnection` instance informs the client that the peer-
to-peer connection setup is complete, the client SHALL hand over the 
signalling channel to a dedicated data channel:

1. The client creates a new data channel on the `RTCPeerConnection` 
   instance with the `RTCDataChannelInit` dictionary/object set 
   containing only the following values:
   * *ordered* SHALL be set to `true`,
   * *protocol* SHALL be set to the same subprotocol that has been 
     negotiated with the server,
   * *negotiated* MUST be set to `true`, and
   * *id* SHALL be set to by counting upwards from `0` and using the 
     first number that is NOT present in the internal list of excluded 
     data channel ids (exchanged in the task's data).
2. The newly created `RTCDataChannel` instance shall be wrapped by 
   following the *Wrapped Data Channel* section.
3. As soon as the data channel is *open*, the client SHALL send a 
   'handover' message to the other client. After this message, the 
   client SHALL NOT send any messages on the original signalling 
   channel. The sequence number and overflow number for outgoing 
   messages to the other client SHALL be transferred to the new 
   wrapped data channel. The client MAY already send signalling 
   messages over the new signalling channel. If the client has already 
   received a 'handover' message from the other client, it MUST 
   continue with the next step, skipping the following sentences. 
   Otherwise, the client MUST accept further messages from the other 
   client on the original signalling channel only and wait for an 
   incoming 'handover' message. Once that 'handover' message has been 
   received, the client SHALL ONLY accept signalling messages over the 
   wrapped data channel. Furthermore, it SHALL transfer the sequence 
   number and overflow number for incoming messages of the other 
   client to the wrapped data channel.
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
difference to the cookie of the SaltyRTC protocol specification is 
that it MUST be different to the cookies of both clients used 
previously. The new cookie will be received when exchanging the task's 
data takes place.

Data Channel ID: 2 byte

Contains the data channel id of the data channel that is being used 
for a message.

Overflow Number and Sequence Number SHALL remain the same as in the 
SaltyRTC protocol specification. However, they are tied to the Data 
Channel ID and MUST be reused (e.g. SHALL NOT reset) in case a data 
channel's id is being reused after the former data channel that used 
to have the id has been closed.

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
         +-------------+------------------------------+
         |             v                              v
    -----+-------------+-----+    +----------+    +---+---+
    | offer/answer/candidate +--->+ handover +--->+ close |
    -------------------------+    +-----+----+    +---+---+
                                        |             ^
                                        v             |
                    +-------------------+----+        |
                    | offer/answer/candidate +---------
                    +------------------------+
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
     |            handover           |
     |------------------------------>|
     |            handover           |
     |<------------------------------|
     |             close             |
     |<----------------------------->|
     |                               |
```

## 'offer' Message

At any time, the initiator MAY send an 'offer' message to the 
responder.

The initiator MUST set the *offer* field to the dictionary/object of 
its WebRTC `RTCPeerConnection`'s local description it has generated 
with calling `createOffer` on the `RTCPeerConnection` instance. The 
*offer* field SHALL be a dictionary/object and MUST contain:

* The *type* field containing a valid `RTCSdpType` in string 
  representation.
* The *sdp* field containing a blob of SDP data in string 
  representation. If the *type* field is `rollback`, the field MAY be 
  omitted.

The responder SHALL validate that the *offer* field is a dictionary/
object containing the above mentioned fields and value types. It SHALL 
continue by setting the value of that field as the WebRTC 
`RTCPeerConnection`'s remote description and creating an answer.

The message SHALL be NaCl public-key encrypted by the client's 
session key pair and the other client's session key pair.

## 'answer' Message

Once the responder has set the remote description on its WebRTC 
`RTCPeerConnection` instance and generated an answer by calling 
`createAnswer` on the instance, it SHALL send an 'answer' message. The 
*answer* field SHALL be a dictionary/object and MUST contain:

* The *type* field containing a valid `RTCSdpType` in string 
  representation.
* The *sdp* field containing a blob of SDP data in string 
  representation. If the *type* field is `rollback`, the field MAY be 
  omitted.
  
The initiator SHALL validate that the *answer* field is a dictionary/
object containing the above mentioned fields and value types. It SHALL 
continue by setting the value of that field as the WebRTC 
`RTCPeerConnection`'s remote description.

The message SHALL be NaCl public-key encrypted by the client's 
session key pair and the other client's session key pair.

## 'candidate' Message

Both clients MAY send ICE candidates at any time to each other. 
Clients SHOULD bundle available candidates.

A client who sends an ICE candidate SHALL set the *candidate* field to 
a list/an array of dictionaries/objects where each dictionary/object 
SHALL contain the following fields:

* The *candidate* field SHALL contain an SDP `candidate-attribute` as 
  defined in the WebRTC specification in string representation.
* The *sdpMid* field SHALL contain the *media stream identification* 
  as defined in the WebRTC specification in string representation or 
  `null`.
* The *sdpMLineIndex* field SHALL contain the index of the media 
  description the candidate is associated with as described in the 
  WebRTC specification. It's value SHALL be either an unsigned integer 
  (16 bits) or `null`.

The receiving client SHALL validate that the *candidate* field is a 
list/an array containing one or more dictionaries/objects. These 
dictionaries/objects SHALL contain the above mentioned fields value 
types. It shall continue by adding the value of each item in the list 
as a remote candidate to its WebRTC `RTCPeerConnection` instance.

The message SHALL be NaCl public-key encrypted by the client's 
session key pair and the other client's session key pair.

## 'handover' Message

Both clients SHALL send this message once the wrapped data channel's 
state for the handed over signalling is `open` on the signalling channel that has been established over the SaltyRTC server. The message SHALL NOT ever be sent over an already handed over signalling channel.

A client who sends a 'handover' message SHALL NOT include any 
additional fields. After this message, the client MUST:

* Transfer the overflow number and sequence number for outgoing 
  signalling messages destined at the other client to the new 
  signalling channel (based on the wrapped data channel), and
* Send further signalling messages over the new signalling channel 
  only.

After a client has received a 'handover' message, it SHALL:

* Transfer the overflow number and sequence number for incoming 
  messages of the other client to the new signalling channel (based on 
  the wrapped data channel),
* Receive incoming signalling messages over the new signalling channel 
  only, and
* In case it receives further signalling messages over the old 
  signalling channel, treat this incident as a protocol error.

The message SHALL be NaCl public-key encrypted by the client's 
session key pair and the other client's session key pair.

## 'close' Message

The message itself and the client's behaviour is described in the 
[SaltyRTC protocol specification](./Protocol.md#close-message). Once 
the signalling channel has been handed over to a wrapped data channel, 
sent and received 'close' messages SHALL trigger closing the 
underlying data channel used for signalling. The user application MAY 
continue using the `RTCPeerConnection` instance and its data channels. 
However, wrapped data channels MAY or MAY NOT be available once the 
signalling's data channel has been closed, depending on the 
flexibility of the client's implementation.

