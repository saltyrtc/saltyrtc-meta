# SaltyRTC Relayed Data Task

This task uses the end-to-end encrypted WebSocket connection set up by
the SaltyRTC protocol to send user defined messages.

# Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in
[RFC 2119](https://tools.ietf.org/html/rfc2119).

# Terminology

All terms from the [SaltyRTC protocol
specification](./Protocol.md#terminology) are valid in this document.

# Task Protocol Name

The following protocol name SHALL be used for task negotiation:

`v0.relayed-data.tasks.saltyrtc.org`

# Task Data

This task does not currently make use of the *data* field of the 'auth'
messages described in the [SaltyRTC protocol
specification](./Protocol.md#auth-message). The task data sent by the
peers should be `Nil`.

# Message Structure

The same message structure as defined in the [SaltyRTC protocol
specification](./Protocol.md#message-structure) SHALL be used.

# Client-to-Client Messages

Once the task has taken over, user data MAY be sent using 'data'
messages.

If one of the sides wants to terminate the connection, the 'close'
message SHALL be sent as described in the [SaltyRTC protocol
specification](./Protocol.md#close-message).

The ['application' message](./Protocol.md#application-message) MAY be
used for control messages.

Other message types SHALL NOT be used in the Relayed Data task.

## Message States (Beyond 'auth')

                 +--+
                 |  v
        +--------+-----------+    +-------+
    -+->+ data / application +--->+ close |
     |  +--------------------+    +-------+
     |                                ^
     +--------------------------------+

## 'data' messages

Once the task has taken over, the user application of a client MAY
trigger sending this message.

This message MAY contain any MessagePack value type. If the user does
not wish to encode messages with MessagePack, they can be transmitted
using MessagePack binary or string value types.

A task who sends a 'data' message SHALL set the *p* field to whatever
data the user application provided. The name is an abbreviation that
stands for "payload" and has been chosen to reduce the message overhead.

A receiving task SHALL validate that the *p* field is set. It MUST pass
the payload inside that field to the user application.

```
{
  "type": "data",
  "p": ...
}
```

## 'application' Message

The message itself and the client's behaviour is described in the
[SaltyRTC protocol specification](./Protocol.md#application-message).

# Sending a Message

The task must provide a way for the user application to send 'data'
messages. It MUST validate the messages as described in the section on
['data' messages](#data-messages).

The same procedure as described in the [SaltyRTC protocol
specification](./Protocol.md#sending-a-signalling-message) SHALL be
followed to send 'data' messages.

# Receiving a Message

Incoming task messages shall be processed as follows:

* The client SHALL validate and decrypt the message according to the
  [SaltyRTC protocol specification](./Protocol.md#receiving-a-signalling-message)
* If the message type is 'close', the message MUST be handled as
  described in the
  [SaltyRTC protocol specification](./Protocol.md#close-message)
* Otherwise, if the message type is 'data', the payload MUST be passed
  to the user application.
* For all other message types, the connection MUST be closed with a
  close code of `3001` (*Protocol Error*)
