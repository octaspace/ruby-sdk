# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-12

### Added

- Initial release of the official OctaSpace Ruby SDK.
- Support for core resources: Accounts, Nodes, Sessions, Apps, Network, and Idle Jobs.
- Resource-oriented client: `client.nodes.list`, `client.services.session(uuid).stop`.
- Persistent HTTP connections (keep-alive mode) via `ConnectionPool`.
- Automatic URL rotation and failover for high availability.
- Retry with exponential backoff and jitter for transient errors.
- Typed error hierarchy based on HTTP status codes.
- Rails integration with automatic client sharing and graceful shutdown.
- Interactive Playground app for manual testing and diagnostics.

[0.1.0]: https://github.com/octaspace/ruby-sdk/compare/v0.1.0...HEAD
