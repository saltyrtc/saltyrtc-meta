# SaltyRTC Chunking

This specification describes the binary data chunking algorithm used by
the SaltyRTC WebRTC task. It allows the user to split up large binary
messages into multiple chunks of a certain size.

This specification has been created originally to work around the
current size limitation of WebRTC data channel messages, but it can also
be used in other, generic contexts.

## Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in
[RFC 2119](https://tools.ietf.org/html/rfc2119).

## Chunk Size

The term *chunk size* is referring to the resulting size from the
concatenation of *chunk header* and *chunk data* in bytes.

## Chunk Header

When converting data to chunks, a 9 byte header MUST be prepended to
each chunk. This allows for sending a chunk over the network in any
order.

### Length

The header is 9 bytes long.

### Format

The header is encoded in binary using network-oriented format (most
significant byte first, also known as big-endian). It is structured as
follows:

    |O|IIII|SSSS|

    - O: Options bit field (1 byte)
    - I: Message id (4 bytes)
    - S: Serial number (4 bytes)

**Options bit field**

The *options bit field* field is used to encode additional information
about a chunk. Right now, only the least significant bit is being used.
The other bits are reserved and MUST be set to `0`.

    MSB           LSB
    +---------------+
    |0 0 0 0 0 0 0 E|
    +---------------+

    - E: End-of-message, this MUST be set to 1 if this is the
         last chunk of the message. Otherwise, it MUST be set
         to 0.

**Message id**

The *message id* SHALL be any 32 bit unsigned integer. It is RECOMMENDED
to start with 0 and to increment the counter for each message. The
*message id* MAY wrap back to 0 on integer overflow.

**Serial number**

The *serial number* SHALL be a 32 bit unsigned integer. It MUST start
with 0 and MUST be incremented by 1 for every chunk.

## Chunk data

The chunk data MUST be appended to the chunk header. It MUST contain at
least 1 byte of data.

Every chunk MUST contain up to `chunk size - 9` bytes of data. Only the
last chunk of a message may contain less than `chunk size - 9` bytes of
chunk data.

The chunk data MUST be chunked in a non-overlapping sequential way.

## Example

When chunking the byte sequence `12345678` with a chunk size of 12 and
the message id 42, the data MUST be chunked into the following three
chunks:

    - First chunk:  `0b00000000 || 0x0000002a || 0x00000000 || 0x010203`
    - Second chunk: `0b00000000 || 0x0000002a || 0x00000001 || 0x040506`
    - Third chunk:  `0b00000001 || 0x0000002a || 0x00000002 || 0x0708`

## Unchunking

Implementations MUST support unchunking of chunks that arrive in arbitrary
order. This is usually done by keeping track of messages and the corresponding
chunks.

In order to prevent memory leaks when chunks are lost in transmission,
implementations SHOULD provide a way to clean up incomplete messages.
