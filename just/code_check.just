alias lint := clippy

# TLS backends are mutually exclusive, so `--all-features` does not build.
tls_features := "native-tls rustls-aws-lc-rs rustls-ring"

# Format Markdown, Rust, TOML, and YAML files.
[group('code-check')]
fmt args="":
  dprint fmt {{ args }}

# Check formatting without changing files.
[group('code-check')]
fmt_check args="":
  dprint check {{ args }}

# Run Clippy for every target with the given feature flags.
[group('code-check')]
clippy args="":
  cargo clippy --all-targets {{ args }}

# Run Clippy for every target and TLS backend, denying warnings each time.
[group('code-check')]
clippy_matrix:
  just clippy "-- -D warnings"
  for feature in {{ tls_features }}; do \
    just clippy "--features $feature -- -D warnings"; \
  done

# Build Rust documentation and deny warnings.
[group('code-check')]
doc args="":
  RUSTDOCFLAGS="-D warnings" cargo doc --no-deps {{ args }}

# Check advisories, licenses, bans, and dependency sources.
[group('code-check')]
deny args="":
  cargo deny check {{ args }}

# Scan paths for verified or unknown secrets.
[group('code-check')]
scan_secrets *args=".":
  trufflehog filesystem {{ args }} --results=verified,unknown --fail --fail-on-scan-errors --no-update

# Point Git at the tracked hook directory.
[group('code-check')]
setup_githooks:
  git config core.hooksPath .githooks
  @echo "git hooks installed: core.hooksPath = .githooks"

# Run the complete local quality gate.
[group('code-check')]
check:
  just fmt_check
  just clippy_matrix
  just doc
  just deny
  just test
