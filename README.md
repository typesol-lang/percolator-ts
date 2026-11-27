# percolator-ts

A port of Anatoly Yakovenko's Percolator v16 (the Solana program `aeyakovenko/percolator-prog` at `7b110913` and its
risk engine `aeyakovenko/percolator` at `5e3af07`, all 50 instructions) to TypeScript, compiled to an SBF program by
the TypeSOL compiler (`@typesol/cli`, pinned to 0.50.0). This repository holds only the port and the scripts that
build it, build the Rust reference from the pinned commits, and run the author's own test suite against either binary.

> **The upstream warning stands for this port.** Percolator's engine: "Educational research project. Not production
> ready. Not audited. Do not use with real funds." Its program: "FOR EDUCATIONAL PURPOSES ONLY … This code has NOT
> been audited. Do NOT use in production or with real funds." This port is unofficial (not made, reviewed or endorsed
> by the upstream author) and equally unaudited.

## Quick start

Needs Node.js 22.12 or later, pnpm, and Docker. No Solana toolchain is used on the host.

```sh
git clone https://github.com/typesol-lang/percolator-ts.git && cd percolator-ts
pnpm install --frozen-lockfile
pnpm build        # typesol build src/percolator.ts --docker --out target
pnpm check-hash   # target/percolator.so must have the sha256 below
```

Expected: `target/percolator.so`, 1,362,912 bytes, sha256
`c6dc6b24c4f0a8cfb801eaf542e27db66357a2051b41b6012aba8ffb30f55b9c`.

`--docker` builds in a linux/amd64 container (emulated on arm64 hosts) that the package makes on your machine from its
own Dockerfile: Agave 3.1.10's platform-tools v1.52 and the 0.50.0 npm tarball, each checked by hash, the tarball
against the release record fetched from `typesol-lang/typesol` (`releases/0.50.0.json`); the build runs with no
network. The first build makes the image (about 750 MB of downloads); later builds reuse it.
`target/percolator.build.json` records the toolchain, the container and the sha256 of every source. The first build
also writes a new `target/percolator-keypair.json`; the program address only goes into the IDL, not into the binary.

## Result of the comparison

The reference is the Rust build of the pinned commits (`pnpm reference`), not a deployed program: no v16 build is
deployed. Both binaries ran the author's suite, all six cargo test targets unfiltered, in Docker on 2 CPUs with every
transaction recorded (port: 2026-11-23 to 2026-11-24; reference: 2026-11-25 to 2026-11-26). Outputs are in
[`results/full-run/`](results/full-run).

| | Reference | Port |
| --- | ---: | ---: |
| Binary | 1,375,936 bytes, sha256 `cc35fa48…` | 1,362,912 bytes, sha256 `c6dc6b24…` |
| Author's tests passed / failed (2,071) | 2,062 / 9 | 2,060 / 11 |
| `v16_cu` (1,581) | 1,573 / 8 | 1,571 / 10 |
| `v16_program_stateful_fuzz` (336) | 335 / 1 | 335 / 1 |
| The four other targets (154) | 154 / 0 | 154 / 0 |
| Transactions compared | 2,324,991 | |
| Identical (every recorded field but compute units) | 2,324,990 | |
| Different | 1 | |
| Succeeding identically in both | 2,127,486 | |
| Compute units over those | 128,297,605,017 | 67,489,438,873 |
| Of those, the port above the reference | | 0 |

**The one different transaction.** `inv_078_permissionless_recovery_coverage::v16_bpf_force_close_liveness_survives_14_stale_leg_grief_via_precrank`,
transaction 12: a one-shot ForceCloseAbandonedAsset of two portfolios with 14 stale legs each. The reference fails it
at the 1,400,000 compute-unit limit (`ProgramFailedToComplete`); the port completes it in 575,741 units. The test
asserts that the transaction fails, so it fails on the port and stops there; the reference's 35 later transactions
in that test have no counterpart. The 12 transactions before are identical.

**Failing on both** (9, at the same assertion with the same message): the reference fails them itself at this pin
(six of `inv_045…authenticated_reward_handoff`, `inv_072…auto_crank_refresh_not_blocked_by_unneeded_first_asset_oracle`,
`inv_077…recovery_kf_progress_survives_stale_42_feed_tail_at_max_shape`, and
`inv_086…reference_model_matches_deployed_public_sequence` in the stateful fuzz). In two of them the message quotes a
failed transaction's logs, and only the compute-unit figures in those differ.

**Failing on the port only** (2), both assertions of the reference's compute units: the `inv_078` test above, and
`inv_077…short_side_b_budget::v16_program_max_shape_short_b_budget_has_exact_public_progress`, which asserts the
reference's peak of 554,832 units after all of its state assertions pass (the port's peak is 192,398; its 1,361
transactions are identical in both traces).

What a trace records: per transaction, hashes (not bytes) of the instructions and keys, the result and error, the
return data, the log lines (the runtime's compute-unit lines left out) and every account in the static key list after
it ran, and the compute units. Accounts loaded through an address lookup table are not hashed, and inner instructions
are not recorded apart (their effects are, through the accounts and the logs).

## Rerunning the comparison

```sh
pnpm build && pnpm check-hash                  # the port: target/percolator.so
pnpm reference                                 # the reference and the three matchers: programs/*.so, each checked by sha256

# The four quick targets, about 4 minutes of tests per binary (plus a first compile of the test crates):
QUICK="listing_oracle_scope anchor_v2_realloc_probe open_issue_regressions v16_program_fuzz_regressions"
TRACE=1 bash reference/author-suite.sh programs/percolator_v16.so runs/ref $QUICK
TRACE=1 bash reference/author-suite.sh target/percolator.so runs/port $QUICK
node reference/author-trace-compare.ts runs/ref/trace runs/port/trace --list --filtered

# The whole suite, as recorded in results/full-run (omit the targets; TARGET_TIMEOUT raised for the two long ones):
TRACE=1 TARGET_TIMEOUT=400000 bash reference/author-suite.sh programs/percolator_v16.so runs/ref-full
TRACE=1 TARGET_TIMEOUT=400000 bash reference/author-suite.sh target/percolator.so runs/port-full
node reference/author-trace-compare.ts runs/ref-full/trace runs/port-full/trace --list
```

The two long targets, `v16_program_stateful_fuzz` and `v16_cu`, took 8,574 s and 7,873 s on the port (about 4.6
hours together) and 12,206 s and 9,874 s of libtest time on the reference (about 6.1 hours), on 2 CPUs of a machine
loaded by other work. Each run writes 1,901 trace files (about 260 MB for the port, 300 MB for the reference).

The quick targets were run with the scripts of this repository on 2026-11-27 (arm64 macOS host, Docker, 2 CPUs; the
reference built from scratch in about 10 minutes, emulated). Both runs ended "as expected"; the comparison found 113
trace files, 26,490 transactions, all identical, 24,197 identical successes at 801,268,645 units in the reference and
413,968,015 in the port ([`results/quick-check/`](results/quick-check)). 110 of the 113 trace files are byte for
byte, compute units included, those of the recorded full run on each side; the other 3 are the first lines of theirs
(the same test names also run in `v16_cu`, whose lines the full run appended to the same files).

`author-suite.sh` fails unless the passes and failures are those [`reference/author-suite-expected.tsv`](reference/author-suite-expected.tsv)
lists for that binary ("reference" by its sha256, "port" otherwise). `author-trace-compare.ts` fails on any trace
difference or compute-unit excess the file does not list, and on a listed one that was not observed (`--filtered`
for a run of some targets only). Everything runs in Docker with `--cpus 2`; the containers fetch the pinned sources
over HTTPS themselves.

## Known differences and what is not verified

The port's README in `typesol-lang/typesol` at tag `v0.50.0` lists the following; they are copied here as written.
File names in them (`percolator-v16-*.test.ts`, `TESTING.md`, `NOTES.md`, `scripts/…`, `test/programs/…`) refer to
that repository, which holds the port's own differential tests against the reference (31 vitest files, not part of
this repository).

**What the equivalence rests on.** The handlers and the engine code they reach follow the original's statements in
order (the same checks in the same order, the same rounding, the same layout), with stated exceptions: copies the
original makes that the port makes in place (NOTES.md section 1), checks that cannot fail and are not repeated
(NOTES.md section 9 and the port's comments), among them the engine's token-value proofs where their validation
cannot refuse (Withdraw's and the domain insurance withdrawal's are argued in NOTES.md section 17). So the evidence
is not a literal statement-by-statement identity: it is the comparison of every transaction the tests send, the
host-compiled comparison of engine functions on vectors, and those written arguments.

**What is not verified:**

- That the pin builds to the author's own bytes: he recorded no hash for it (only for older commits, which the recipe
  reproduces).
- The matcher programs: only the three the author's tests load (built here from their pinned sources, the same binaries
  in both VMs) and the tests' own rogue matcher; no deployed matcher. A matcher that answers with more than one fill
  per leg, or a matcher of another ABI version, is compared only through the refusals of its answers. The crank's Recovery and Resolved paths, the recovery and resolution instructions and the insurance,
  backing and terminal instructions are compared on real state (legs opened by trades, prices moved, portfolios
  bankrupt, Fresh backing and insurance deposited and withdrawn, markets resolved and closed by CloseSlab) except
  where noted: a market in Recovery is declared by a write of its mode and reason into both VMs in the dedicated tests
  (no crank in this repository's tests declared one; the author's tests do, below), and CureAndCancelClose runs on close ledgers written into the
  portfolio (no ported instruction leaves one without progress). Now entered by
  compared transactions on real state (`percolator-v16-paths.test.ts`): a trade's counterparty-backed initial-margin
  source lien and its backing-domain fee (TradeNoCpi and TradeCpi), the provider's utilization-fee earnings and their
  withdrawal, ReleaseSourceLiens on the flat portfolio and a source lien's release at the resolved close. Still entered
  by no transaction of this repository's tests, by the branch probes (TESTING.md "Paths driven on purpose" says why
  for each): AdvanceClose, a crank's declaration of Recovery, a leg retained as a pending obligation,
  WithdrawBackingBucket's emptied-bucket statuses (Impaired, Expired), CloseSlab's native-mint residue path. (The
  terminal scan past 256 assets is now compared, on a market of 5,682 configured slots whose scan state is written into
  it, every step of it: Continue, ScanProgress, the wait at a live Fresh bucket and LockActive from it, the expiry of a
  lapsed Fresh bucket, a nonzero recredit, and the last batch refused while a domain budget remains, then ReadyToClose:
  `percolator-v16-shapes.test.ts`. The activation fee at the top of u128, which no instruction can store, is compared
  on a fee written into the market: `percolator-v16-lifecycle.test.ts`.) Of these, the author's tests enter AdvanceClose with a pending close ledger, a crank's
  declaration of Recovery, a leg retained as a pending obligation through ForfeitRecoveryLeg (not through a trade)
  and the Expired status, in
  transactions identical in both binaries' runs (a probed port on 16 chosen tests; TESTING.md section 3 names them);
  no vitest reproduces those yet. The Impaired status and the native-mint residue were not
  reached by the tests probed (the rest of the author's suite was not probed). wire.ts's conversions are compared only as far as the 50 handlers reach them; the state mutations reach active legs, source domains and the
  close-progress ledger through `validate_with_market` only.
- The settlement of a portfolio's open legs is compared with the reference binary on generated states and on real
  state (legs opened by trades; since the crank, K deltas from moving prices and liquidations too). B chunks, impaired
  liens and a socialised loss in the walk do not arise from real instructions there (the dedicated bankruptcy tests
  book a residual into a B index; a B chunk needs a B index ahead of a leg's snapshot while the leg survives, which the
  walk's liquidations do not leave). Branches of its
  functions that the binary comparison does not reach are compared only on host vectors, and some are reached by
  neither (TESTING.md lists them with the reason).
- The crank's refresh with its price override, B chunks and lapsed-backing scan, and
  `certify_account_after_local_settlement_…`, are ported with the crank; with TopUpBackingBucket ported, the
  lapsed-backing expiry, the trade's initial-margin source liens and the terminal trade's close-progress ledger are
  now entered by compared transactions; a trade's backing-domain fee (`apply_backing_domain_fees_after_trade_view`,
  `charge_account_backing_fee_not_atomic`) is now too (above); the retention of a cleared leg as a pending
  obligation by a trade (a domain-loss barrier on its side) is still not entered, by these tests or by the author's
  tests probed; the author's tests enter the same retention kernel through ForfeitRecoveryLeg only, identically in
  both binaries (above).
- UpdateAssetLifecycle's retirement of an asset with a lapsed Fresh backing bucket: compared with the reference binary
  on buckets written into the market (the lifecycle test predates TopUpBackingBucket's port), on a Live market. Accrual is reached only through a shutdown at the asset's frozen price (so its
  price-move branch, which needs a new price, only by its checks; ConfigureHybridOracle resets an empty asset's anchor
  to the read price without accruing): its K deltas are zero there and its funding path is compared numerically; the
  crank's accrual paths are compared through the crank.
- The external reader's branches that the crank cannot reach (a Manual or managed profile, an invalid stored leg
  configuration, fewer accounts than legs) are compared only with the original's source compiled for the host, on
  vectors; the ones the crank reaches (legs that already hold observations, the fall-back to the mark, the liveness) are
  compared with the reference binary (NOTES.md section 8). The oracle accounts are
  synthetic, built from the offsets the original reads; no mainnet account snapshot was used.
- Activation at large indices: appending with the fee was compared up to index 34 (refusals at 35) and reuse at
  indices 5, 7 and 33 (the fee doubling at 32); the second doubling (64) and beyond were not run. The doubling's overflow is compared on
  base fees of u128::MAX, u128::MAX/2 + 1 and u128::MAX/2 written into the market (no instruction stores a base fee
  above u64::MAX), at indices 7, 33 and 35 only.
- Markets near the 10 MiB limit: InitMarket, ResolveMarket, ResolveStalePermissionless and CloseSlab are compared on
  markets of 1,000 and 5,682 slots (`percolator-v16-shapes.test.ts`), the grown markets' configured count, last asset
  and scan state written into the market; the other instructions were not run on markets of that size.
- The heap: the original's allocations beyond the entrypoint's account list are decode's vectors, the SPL Token
  Transfers' and the matcher calls' instructions, and the batch's vectors; most compared transactions requested the
  author's 256 KiB frame. The largest batch and matcher transactions (14 legs; TradeCpi with a tail of 32) were also
  sent with no heap request and with 32 and 64 KiB frames and agree; how close the reference comes to the end of the
  default frame was not measured. The port allocates too (CPI scratch and copies of struct arguments, NOTES.md
  section 18), within its own 32 KiB; an out-of-heap failure of either side would be a difference, and none occurred.
- The author's own suite (above): its traces hold hashes, not bytes, of the instructions, the result, the return data,
  the log lines (the compute-unit lines left out) and every account in the transaction's static key list after it ran.
  Accounts a version-0 transaction loads through an address lookup table (the `inv_006` lookup-table tests send such
  transactions) are not hashed, nor is the lookup part of the message; the inner instructions are not recorded apart
  (their effects are, through the accounts and the logs); state the tests read without sending a transaction is
  compared only through the tests' own assertions.
- A 14-leg portfolio's liquidation: the cranks that would get there in the maximum-shape test run the reference past
  its limit; those are compared with the reference's run under a raised budget, and only the first legs' liquidation
  is reached there.
- A panic of the reference itself: one is reached, CloseResolved (or the crank on a Resolved market) with the market
  passed as the portfolio (a RefCell borrow of the market's data while it is borrowed mutably,
  src/account_info.rs); the port panics there too, and only the file is logged, so the line and column it records
  (91:19 of solana-program 1.18.26) come from the source, not from a comparison. None other was reached by the ported
  instructions (the walks, the mutations and the sweeps included). The panic lines, the heap
  failures and the RefCell failures were observed on a probe built with the same entrypoint and toolchain
  (TESTING.md, section 4).

The GitHub Actions workflow of this repository (`build`) makes the same build on a GitHub-hosted x86-64 runner on every
push and checks the sha256; its first run, on the first commit, passed.

## Where the long documents are

In `typesol-lang/typesol` at tag `v0.50.0`, `showcase/mainnet/percolator-v16/`:

- [README.md](https://github.com/typesol-lang/typesol/blob/v0.50.0/showcase/mainnet/percolator-v16/README.md):
  per-instruction compute units and size, what each test file compares, the cases past the reference's compute-unit
  limit (compared with the reference run under a raised budget).
- [TESTING.md](https://github.com/typesol-lang/typesol/blob/v0.50.0/showcase/mainnet/percolator-v16/TESTING.md):
  every test run with its counts, the author's suite and the trace comparison in detail (section 3).
- [NOTES.md](https://github.com/typesol-lang/typesol/blob/v0.50.0/showcase/mainnet/percolator-v16/NOTES.md): the sites
  where the original swallows an error after changing a copy, the copies the port makes in place, and the map of the
  settlement of open legs, function by function.

The comments in `src/` refer to those documents and to that repository's test files by their paths there.

## Layout

| Path | |
| --- | --- |
| `src/` | the port, 36 files, entry `src/percolator.ts`; the same bytes as `showcase/mainnet/percolator-v16/*.ts` at `v0.50.0` |
| `scripts/check-hash.sh` | the binary's expected sha256 and size |
| `reference/` | `Dockerfile` and `build.sh` (the reference and matchers), `author-suite.sh` and `author-suite-expected.tsv` (the author's suite against a binary), `author-trace-compare.ts` (two traced runs, transaction by transaction), `trace/*.rs` (the tracing spliced into LiteSVM and the Solana SDK inside the container) |
| `results/full-run/` | the recorded full run: each binary's suite output and summary, the binaries' sha256 as the containers saw them, the trace comparison (the traces themselves, about 560 MB, are not in the repository; in the outputs, local paths are cut to file names) |
| `results/quick-check/` | the four quick targets run on both binaries with the scripts of this repository |

Upstream modules and the files that port them:

| Upstream | Port |
| --- | --- |
| `src/v16_program.rs` `mod ix` (decode, dispatch) | `percolator.ts` |
| `src/v16_program.rs` `mod state` | `state.ts` |
| `src/v16_program.rs` processor helpers | `program.ts` |
| `src/v16_program.rs` handlers | `setup.ts`, `custody.ts`, `policy.ts`, `oracle.ts`, `lifecycle.ts`, `trading.ts`, `batch.ts`, `convert.ts`, `recoveries.ts`, `resolution.ts`, `reserves.ts`, `terminal.ts`, `closeresolved.ts`, `crank.ts`, `autocrank.ts`, `liquidation.ts` |
| `src/v16_program.rs` `mod matcher_abi` | `matcher.ts` |
| `src/v16_program.rs` `mod oracle_v16` | `external.ts` |
| `PercolatorError`, `map_v16_error` | `errors.ts` |
| engine `src/v16.rs`: wire conversions | `wire.ts` |
| engine `src/v16.rs`: validation, deposits, accrual, fees and withdrawal | `engine.ts`, `accrual.ts`, `refresh.ts` |
| engine `src/v16.rs`: trade and batch, health | `trade.ts`, `health.ts` |
| engine `src/v16.rs`: recovery, resolution, resolved close | `recovery.ts`, `resolved.ts` |
| engine `src/v16.rs` and `src/wide_math.rs`: settlement of open legs | `kernels.ts`, `primitives.ts`, `impairment.ts`, `claims.ts`, `kfsettle.ts`, `settlement.ts` |

The port's README has the full table of what each file ports, function by function.

## Licence

Apache License 2.0, as upstream; see [LICENSE](LICENSE) (copied from `aeyakovenko/percolator-prog` at `7b110913`) and
[NOTICE](NOTICE).
