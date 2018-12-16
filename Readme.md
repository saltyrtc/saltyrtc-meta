# SaltyRTC

[![Join our chat on Gitter](https://badges.gitter.im/saltyrtc/Lobby.svg)](https://gitter.im/saltyrtc/Lobby)

<img src="media/try_our_rtc_300px.png" align="right" />

SaltyRTC is an **end-to-end encrypted signalling protocol**. It offers
to freely choose from a range of signalling tasks, such as setting up a
**WebRTC** or **ORTC** peer-to-peer connection, or simply to exchange
arbitrary data over the established transport in a secure manner.
SaltyRTC is completely open to new and custom signalling tasks for
everything feasible.

In this repository, you can find...

* The [SaltyRTC Signalling Protocol](Protocol.md).
* The [SaltyRTC WebRTC Task Protocol](Task-WebRTC.md) to set up a
  secure WebRTC peer-to-peer connection by using SaltyRTC's end-to-end
  encryption techniques.
* The [SaltyRTC ORTC Task Protocol](Task-ORTC.md) to set up a secure
  ORTC peer-to-peer connection.
* The [SaltyRTC Relayed Data Task Protocol](Task-RelayedData.md) to set
  up a secure channel for exchanging arbitrary data by using SaltyRTC's
  end-to-end encryption techniques.
* The [SaltyRTC Chunking Specification](Chunking.md) used by SaltyRTC's
  WebRTC task. However, the specification can also be used as a generic
  message chunking solution.

## Implementations

If you have implemented a SaltyRTC client, task or server :+1: and you
would like to add it to this list, we will gladly accept a pull request
from you.

**Clients and Tasks**

* [saltyrtc-client-js](https://github.com/saltyrtc/saltyrtc-client-js)
    - [saltyrtc-task-webrtc-js](https://github.com/saltyrtc/saltyrtc-task-webrtc-js)
* [saltyrtc-client-java](https://github.com/saltyrtc/saltyrtc-client-java)
    - [saltyrtc-task-webrtc-java](https://github.com/saltyrtc/saltyrtc-task-webrtc-java)

**Servers**

* [saltyrtc-server-python](https://github.com/saltyrtc/saltyrtc-server-python)
* [saltyrtc-server-go](https://github.com/OguzhanE/saltyrtc-server-go) (work in progress)

## Releases

When we release a new version of the protocol, a (new) task or the
chunking specification, a tag will be added in the following format:
`protocol|chunking-<version>` or for tasks `task-<task-name>-<version>`.

Note that specification versions are independent from each other. In
case a new version of a specification breaks backwards compatibility to
another specification, it will include a section stating how
compatibility is affected.

## Credits

* Logo / icon / poster images based on a [design by Vvstudio on
  Freepik.com](http://www.freepik.com/free-vector/try-our-extra-salty-products_822392.htm)
