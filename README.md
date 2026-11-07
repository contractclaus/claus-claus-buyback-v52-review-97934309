# CLAUS v52 buyback hardening review

This is the exact hardened candidate revision 3 for the existing CLAUS pool on Robinhood (chain 4663). Required review entry files are flat/MigrationFeeHookV2.sol and flat/ClausBuybackVaultV2.sol. The prior v51 review withheld its approval marker because of keeper-controlled price limits and treasury-payout coupling. The first v52 review found stale oracle history after rollback and later re-upgrade. Revision 2 fixes that path with the existing administrator-only reset and full renewed warmup. Revision 3 also resolves the flow finding about directly donated CLAUS: the owner can burn those tokens separately without spending ETH or changing protocol buyback counters. This candidate requires a fresh independent decision bound to its new source and build hashes. It is not yet activated.

## Price and treasury behavior

The hook stores a 601-entry history, updating at every distinct swap timestamp. The vault enforces a 600-second time-weighted tick reference and a fixed 50-bps output tolerance independently of keeper input. Tick conversion and output rounding strengthen the floor. Same-timestamp swaps have no elapsed weight and cannot evict history. A successful buyback consumes its ArbSys block; a reverted buyback does not. The administrator restarts history after every proxy activation, including a return after rollback. Resetting clears the ring metadata and cumulative tick; old ring entries are ignored. Every reset enforces a fresh 600-second warmup. The keeper cannot reset history.

The AMM history is not an external fair-value oracle. Sustained manipulation, oracle availability, price trends and batch price impact must be assessed, and limitations must be reported. A legitimate price move can delay a burn until the independent price floor permits it. There is no off-chain signer or override.

The vault no longer calls claimTreasuryFees. Treasury payouts are independent and retain their owed accounting if a recipient rejects ETH. The worker can continue buybacks after a conclusively reverted treasury transaction, preserving that original row and spent gas; an unknown transaction still blocks.

The owner-only burnDonatedTokens method burns only the vault-held CLAUS. totalDonatedTokensBurned and DonatedTokensBurned keep these burns separate from totalTokensBurned and BuybackBurned. The normal buyback still checks only its new swap output, so a donation cannot satisfy or inflate its price minimum. The keeper cannot call the donation burn, and the method is blocked during an unlocked pool operation. No ETH claim, withdrawal or arbitrary token transfer is added.

## Reproduce exact builds

Use solc 0.8.26 with each complete build/*.standard-input.json. Both source units and exact optimizer, viaIR, metadata, remapping and output selections are included. Full artifact and runtime hashes are in build/manifest.json. Run node build/verify-hashes.mjs for the content-addressed source and artifact checks. The local artifacts and the network compiler artifacts match exactly, including metadata. Generic forge defaults are not a reproduction of these flattened metadata paths.

## Authority and transition

The new vault owner is the existing ClausAdministrator 0x979D5810D32292358639f25294472f01c95bDc46. The founder must register its actual deployed address using setTarget(newVault,true); the operator cannot self-register it. The original keeper is 0xAc796F7ac40c0CE9cdc0Dbe61d8bc7C98dC5CBc5 and maxBatch stays 0.5 ETH. Review review-context.json for exact constructor arguments and policy. No new private key or approval is introduced.

Activation requires independent approval, exact deployed runtime and owner checks, founder registration, and a paused/drained worker. The atomic administrator batch disables the old vault, upgrades the existing hook, calls initializeBuybackOracle to discard any prior oracle epoch, selects the new destination, and recovers old-vault fee ETH. LP principal remains untouched. Existing action IDs, nonce history, receipt records, cumulative burn counters and gas limits survive. Rollback is a new forward transaction, never a database rewind. New-vault residual ETH remains recoverable through the administrator.

Ordinary trades retain the 2% fee split equally between burn and treasury. The authenticated immediate protocol buyback is fee-exempt and must spend its complete quoted input; a partial fill reverts atomically. Token, pool, proxy and administration addresses remain the same.

## Verification and notice

42 contract tests and 94 worker tests pass; these include 2,048 fuzz cases, 64 independent 160-digit decimal vectors, same-timestamp spam, ring wrap, real-router output/partial-fill behavior, rejecting treasury recipients, and an actual chain fork at block 108747367. The fork deploys these exact artifacts, tests founder registration and operator revocation, switches and seeds the hook, burns after warmup, pays treasury separately, returns to the old implementation and burns again. The test returns once more to the new implementation, reuses the existing new vault, requires a fresh 600-second warmup, and burns again. It also transfers a real CLAUS donation and burns it through the existing administrator, preserving the buyback counter and ETH balance. Only ArbSys clock responses are mocked. All runtime evidence is a test of the candidate, not a claim of deployment.

New notice: https://x.com/i/status/2119183454378107080 . Activation is not permitted before 2026-11-07T22:45:00Z or before independent approval. Prior reports, payments and v51 evidence remain historical and are not reused as approval.
