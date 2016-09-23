# SaltyRTC WebRTC Task

This task uses the end-to-end encryption techniques of SaltyRTC to set up a secure WebRTC peer-to-peer connection. It also adds another security layer for Data Channels that are available to users. The signalling channel will persist after being handed over to a dedicated Data Channel once the peer-to-peer connection has been set up. Therefore, further signalling communication between the peers does not require a dedicated WebSocket connection over a SaltyRTC server.

# Task Protocol Name

The following protocol name SHALL be used for task negotiation:

`v0.webrtc.tasks.saltyrtc.org`

TODO: Switch to `v1` as soon as the spec has been reviewed.

