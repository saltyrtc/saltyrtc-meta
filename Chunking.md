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
document are to be interpreted as described in [RFC
2119](https://tools.ietf.org/html/rfc2119).

## Modes

This specification defines the following two modes:

* **Reliable/Ordered**: Intended for reliable and ordered transmission
  of chunks. The application that is reassembling chunks into a message
  MUST ensure that chunks of a message are not reordered. Furthermore,
  chunks of different messages SHALL NOT be interleaved.
* **Unreliable/Unordered**: Intended for transmission of chunks where
  chunks MAY be lost or reordered. Additionally, an implementation MAY
  optionally be able to handle duplicated chunks.

## Chunk Size

The term *chunk size* is referring to the resulting size from the
concatenation of *chunk header* and *chunk data* in bytes.

## Chunk Header

When converting data to chunks, a header MUST be prepended to each
chunk of the following byte size:

* 1 byte **short header** for reliable/ordered mode, and
* 9 byte **long header** for unreliable/unordered mode.

Both header variants are encoded in binary using network-oriented format
(most significant byte first, also known as big-endian).

### Short Header

The short header contains a single byte called the *options bit field*:

**Options bit field**

The *options bit field* field is used to encode additional information
about a chunk.

    MSB           LSB
    +---------------+
    |R R R R R M M E|
    +---------------+

    - R: Reserved, MUST be 0.

    - M: Mode with the following values:

         11 - reliable/ordered
         10 - reserved
         01 - reserved
         00 - unreliable/unordered

    - E: End-of-message, this MUST be set to 1 if this is the
         last chunk of the message. Otherwise, it MUST be set
         to 0.

### Long Header

The long header contains a total of 9 bytes and is structured in the
following way:

    |O|IIII|SSSS|

    - O: Options bit field (1 byte)
    - I: Message id (4 bytes)
    - S: Serial number (4 bytes)

**Options bit field**

Identical to the *options bit field* of the
[Short Header](#short-header) format.

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

Every chunk MUST contain up to `chunk size - header size` bytes of
data unless it is the last chunk of a message in which case it MAY
contain less than `chunk size - header size` bytes of data.

The chunk data MUST be chunked in a non-overlapping, sequential way.

## Example

### Reliable/Ordered Mode

When chunking the byte sequence `12345678` (where each digit is an 8
bit unsigned integer) with a chunk size of 6, the data is being chunked
into the following two chunks:

    - First chunk:  `0b00000110 || 0x0102030405`
    - Second chunk: `0b00000111 || 0x060708`

### Unreliable/Unordered Mode

When chunking the byte sequence `12345678` (where each digit is an 8
bit unsigned integer) with a chunk size of 12 and the message id 42,
the data is being chunked into the following three chunks:

    - First chunk:  `0b00000000 || 0x0000002a || 0x00000000 || 0x010203`
    - Second chunk: `0b00000000 || 0x0000002a || 0x00000001 || 0x040506`
    - Third chunk:  `0b00000001 || 0x0000002a || 0x00000002 || 0x0708`

## Unchunking

In unordered/unreliable mode, implementations MUST support unchunking of
chunks that arrive in arbitrary order. This is usually done by keeping
track of messages and the corresponding chunks.
In order to prevent memory leaks when chunks are lost in transmission,
implementations SHOULD provide a way to clean up incomplete messages.

Implementations of the *unreliable/unordered* mode MAY optionally be
able to handle duplicated chunks.

## Changelog

### 2019-02-06

Version 1.1

**Important**: Backwards compatibility to 1.0 can only be ensured by
using the unreliable/unordered mode.

* Add reliable/ordered mode with 1 byte header

### 2016-09-29

Version 1.0

* Define unreliable/unordered mode with 9 byte header

