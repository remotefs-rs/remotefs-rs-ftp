# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

`AGENTS.md` is a symlink to this file and holds the same agent contract.

## Commands

Every task runs through a [`just`](https://just.systems) recipe. Do not bypass a
recipe with an ad hoc `cargo` or tool command. If a recurring task has no
recipe, add one under `just/` before using it. Run `just` to list all recipes.

```sh
just build                     # cargo build --all-targets
just release                   # release build
just test                      # cargo test --lib, then --doc (needs Docker)
just coverage                  # cargo llvm-cov, writes lcov.info
just fmt                       # dprint fmt (Markdown, Rust, TOML, YAML)
just fmt_check                 # dprint check
just lint "-- -D warnings"     # alias of just clippy
just clippy_matrix             # clippy with no TLS backend and every sync/async TLS backend, -D warnings
just doc                       # cargo doc --no-deps with RUSTDOCFLAGS="-D warnings"
just deny                      # cargo deny check
just scan_secrets              # trufflehog filesystem
just check                     # the full local quality gate
just setup_githooks            # point core.hooksPath at .githooks
just changelog_preview 0.5.0
just changelog 0.5.0
just publish "--dry-run --allow-dirty"
```

`just check` is the required gate before declaring work done. It chains
`fmt_check`, `clippy_matrix`, `doc`, `deny`, and `test`.

Tests in `src/client/sync.rs` and `src/client/tokio.rs` spin up a
`delfer/alpine-ftp-server` container per test via `testcontainers` (see
`src/test_container.rs`), so a running Docker daemon is required. Run
`just test`, or with a specific TLS backend enabled via
`just test "--features rustls-aws-lc-rs"`. The complete sync-plus-Tokio
rustls suite is `just test "--features rustls-aws-lc-rs,tokio-rustls-aws-lc-rs"`.

If a required tool is missing, say so. Never claim a check passed or silently
swap in a weaker command.

## Architecture

remotefs-ftp is a [remotefs](https://github.com/remotefs-rs/remotefs-rs)
client implementation providing FTP/FTPS access, built on top of
[`suppaftp`](https://docs.rs/suppaftp). It is a library-only crate
(`src/lib.rs`, crate name `remotefs_ftp`) with no binaries or examples.

- **Two clients.** `FtpFs` in `src/client/sync.rs` implements
  `remotefs::RemoteFs` over `suppaftp`'s blocking `FtpStream`; `TokioFtpFs` in
  `src/client/tokio.rs` implements `remotefs::AsyncRemoteFs` over suppaftp's
  Tokio stream. Both clients wrap every FTP verb the filesystem needs (`LIST`,
  `RETR`, `STOR`, `APPE`, `DELE`, `MKD`, `RMD`, `RNFR`/`RNTO`, `SITE`). The
  shared `src/client/{error,guard,list,path}.rs` modules own error mapping,
  transfer state, LIST parsing and path validation. There is no working
  directory; every path must be a UTF-8, POSIX-rooted absolute path without
  parent components and is validated with `remotefs::path::ensure_absolute`.
  Ranged reads request FTP `REST` before `RETR` and fall back to local prefix
  skipping when the server refuses the marker or the offset is too large.
  `src/client/sync/stream.rs` and `src/client/tokio/stream.rs` wrap suppaftp
  12's self-finalizing `TransferStream` in the corresponding remotefs stream
  traits whose `finish` reads the transfer reply; `src/client/error.rs` maps
  `FtpError` (transport failures and reply codes) to typed `RemoteError` kinds
  while keeping the source.
- **Async concurrency and cancellation.** `TokioFtpFs` serializes control
  operations with an async mutex. `OperationGuard` marks a connection unusable
  when an in-flight command future is cancelled. A `TransferGuard` makes
  control operations fail with `ProtocolError` while an async data stream is
  alive. Async streams must be explicitly finished; dropping a partial read
  cannot await cleanup and therefore requires reconnecting, while completed
  downloads and uploads leave the deferred completion reply for the next
  command.
- **Path handling.** `src/utils/path.rs` normalizes FTP paths, including the
  Windows-specific quirks handled by the `path-slash` dependency.
- **TLS backends are mutually exclusive within each client family.** The sync
  backends (`native-tls`, `rustls-aws-lc-rs`, `rustls-ring`) and Tokio backends
  (`tokio-native-tls`, `tokio-rustls-aws-lc-rs`, `tokio-rustls-ring`) are
  alternative features. One sync and one Tokio backend may be enabled
  together; the sync features never pull Tokio in. `cargo build --all-features`
  and `cargo clippy --all-features` are never valid here — use `just build`/
  `just clippy` with at most one backend from each family, or
  `just clippy_matrix` to check every combination individually. `deny.toml`'s
  `all-features = true` is safe because `cargo-deny` only walks the dependency
  graph and never compiles the crate.
- **Command layer.** `Justfile` is a thin importer. Each recipe group lives in
  its own file under `just/` (`build`, `test`, `code_check`, `changelog`,
  `publish`) and carries a `[group(...)]` attribute so `just --list` stays
  organized. Recipes take an `args=""` passthrough rather than hard-coding
  flags.
- **Formatting is dprint, not cargo fmt.** `dprint.json` owns Markdown, TOML,
  and YAML, and delegates `.rs` files to nightly rustfmt through its exec
  plugin (`--edition 2024`, matching this crate's `package.edition`).
  `rustfmt.toml` uses nightly-only options (`imports_granularity`,
  `group_imports`), which is why nightly is required. Always format with
  `just fmt`.
- **Release path.** Commits follow Conventional Commits and `cliff.toml` turns
  them into `CHANGELOG.md`. Publishing goes through `just publish`
  (`cargo publish --locked`); version bumps live in `Cargo.toml`.
- **Supply-chain policy.** `deny.toml` is strict: license allowlist,
  `yanked = "deny"`, `unmaintained = "all"`, wildcard versions denied, and
  crates.io as the only allowed source.
- **CI only runs the container-backed test suite on Linux.**
  `.github/workflows/ci.yml`'s `quality-macos` and `quality-windows` jobs build
  and lint every sync and async TLS backend but do not run tests, since the FTP
  test container needs a Docker daemon that isn't available there;
  `quality-linux` builds every backend, runs the combined
  `rustls-aws-lc-rs,tokio-rustls-aws-lc-rs` test suite, and uploads coverage.

## Conventions

- Toolchain is pinned to Rust 1.98.0 (`rust-toolchain.toml`). `package.edition`
  in `Cargo.toml` is 2024 and `package.rust-version` is 1.89.0; do not bump
  either as part of unrelated changes.
- Public library items need canonical rustdoc, including a runnable example.
  `just test` runs doctests, and `just doc` denies warnings.
- Keep `Cargo.toml` dependency and feature entries alphabetically sorted, with
  bare minimal versions.
- Conventional Commits, imperative and lower-case. No agent attribution,
  session links, or agent `Co-Authored-By` lines.
- Do not stage planning state. `docs/superpowers/`, `.superpowers/`, and
  `.claude/` are gitignored and dprint-excluded.
- After editing a Markdown file that contains a table, run
  `fmt-md-tables -i <file>`.
- After any change under `.github/workflows/`, run `zizmor .github/workflows`
  until it exits clean. Pin actions to a full commit SHA with the matching tag
  in a trailing comment, declare least-privilege permissions, and set
  `persist-credentials: false` on checkout.
