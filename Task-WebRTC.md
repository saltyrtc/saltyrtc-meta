# SaltyRTC WebRTC Task

This task uses the end-to-end encryption techniques of SaltyRTC to set up a secure WebRTC peer-to-peer connection. It also adds another security layer for Data Channels that are available to users. The signalling channel will persist after being handed over to a dedicated Data Channel once the peer-to-peer connection has been set up. Therefore, further signalling communication between the peers does not require a dedicated WebSocket connection over a SaltyRTC server.

# Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in
[RFC 2119 [RFC2119]](https://tools.ietf.org/html/rfc2119).

# Terminology

All terms from the [SaltyRTC protocol specification](./Protocol.md#terminology) are 
valid in this document.

# Task Protocol Name

The following protocol name SHALL be used for task negotiation:

`v0.webrtc.tasks.saltyrtc.org`

TODO: Switch to `v1` as soon as the spec has been reviewed.

# Task Data

TODO
TODO: Add "Cookie 2"

# Message Structure

Before the signalling channel handover takes place, the same message 
structure as defined in the [SaltyRTC protocol specification](./
Protocol.md#message-structure) will be used.

After the handover took place, the nonce/header MUST be slightly 
changed:

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
it MUST be different to the cookie used previously.

Data Channel ID: 2 byte

Contains the data channel id of the data channel that is being used for 
a message.

Overflow Number and Sequence Number SHALL remain the same as in the 
SaltyRTC protocol specification.

Note that the Source and Destination fields have been replaced by the 
Data Channel ID field. As there can be only communication between the 
peers that set up the peer-to-peer connection, dedicated addresses are 
no longer required.


