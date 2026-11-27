# Changelog

## Unreleased

## 2026-11-27

- The port of Percolator v16 (`aeyakovenko/percolator-prog` at `7b110913`, engine `aeyakovenko/percolator` at
  `5e3af07`, all 50 instructions) as released in `typesol-lang/typesol` `v0.50.0`, building with `@typesol/cli` 0.50.0
  from npm to `target/percolator.so`, sha256 `c6dc6b24c4f0a8cfb801eaf542e27db66357a2051b41b6012aba8ffb30f55b9c`.
- Scripts that build the Rust reference from the pinned commits in Docker, run the author's test suite against either
  binary and compare the two traced runs.
- The recorded full run of the author's suite on both binaries, and a run of its four quick targets made with the
  scripts of this repository.
