# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial implementation of `OctaSpace::Client`
- Resources: Accounts, Nodes, Sessions, Apps, Network, Services (MR/VPN/Render), IdleJobs
- Standard HTTP transport via Faraday
- Keep-alive transport with connection pooling (`keep_alive: true`)
- URL rotation / failover via `base_urls`
- Retry with exponential backoff + jitter
- `on_request` / `on_response` hooks
- Rails integration via Railtie
- Dummy app / playground in `test/dummy`
