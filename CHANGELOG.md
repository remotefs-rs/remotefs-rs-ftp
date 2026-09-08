# Changelog

All notable changes to this project are documented in this file.

## 0.5.0

Released on 2026-09-08

### Added

- implement exec via the FTP SITE command

> exec() was a stub returning UnsupportedFeature. Implement it on top of
> suppaftp's site(), which is the closest FTP primitive to a generic
> exec: it only runs commands the server exposes as SITE subcommands
> (e.g. CHMOD, HELP), not arbitrary shell commands.

## 0.4.1

Released on 2026-08-31

### Build

- bump suppaftp to 11.0.0 (#2)

## 0.4.0

Released on 2026-01-18

### Breaking changes

- Replaced `rustls` feature with `rustls-aws-lc-rs` and `rustls-ring` features to choose the desired rustls backend

> `rustls` feature has been removed. Use `rustls-aws-lc-rs` or `rustls-ring` instead

### Build

- Breaking: Replaced `rustls` feature with `rustls-aws-lc-rs` and `rustls-ring` features to choose the desired rustls backend
- msrv 1.88

## 0.3.0

Released on 2025-08-31

### Breaking changes

- SuppaFTP 7

> Renamed features

### Added

- Added the `passive_stream_builder` option

### Fixed

- test is sync and send
- path_slash 0.2 fixup

### Build

- Breaking: SuppaFTP 7

> Edition 2024
> MSRV 1.85.1
> Removed `secure` feature
> Renamed `vendored` feature to `native-tls-vendored`

## 0.2.2

Released on 2024-10-18

### Fixed

- rustls 0.23 compatibility

## 0.2.1

Released on 2024-10-07

### Fixed

- removed users dep

## 0.2.0

Released on 2024-09-30

### Added

- remotefs 0.3

### Fixed

- bump `suppaftp` to `6.0.0`
- revert webkpi
- tests
- ci
- lint

## 0.1.1

Released on 2022-01-04
