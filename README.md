# CLAUS v53 advisor and buyback review

Review the exact two flattened contracts in review-context.json and their reproduced artifacts. This pre-activation candidate adds the owner's requested advisor payment while retaining the v52 price, independent settlement, reactivation and donation protections. The exact source and build hashes are in build/manifest.json; none of these new contracts is yet deployed.

## Exact allocation

The aggregate trade fee remains 2%. Half (1% gross) funds the existing buyback/burn. The other half is treasury: while the new advisor feature is enabled, 10% of that treasury bucket (0.1% gross) accrues to fixed wallet 0x1C31B012a8565567A72F7c661D7f0d9f92182853; the founder retains 0.9% gross. Fractional tenths of a wei carry between swaps. Fee rounding remains the original integer fee calculation. Previously accrued founder fees are not reassigned. The advisor state uses a new namespace, preserving the existing proxy slots.

The administrator alone can enable or disable future advisor accrual. The address and share cannot be changed through this feature. Disabling never deletes or redirects existing advisor debt. claimAdvisorFees and claimTreasuryFees are separate, permissionless native-ETH settlements. A rejecting advisor cannot block founder settlement or buyback, and a rejecting founder cannot block advisor settlement. No external recipient is called during a user's swap. Verify all of these properties, including round-trip upgrades and reentrancy.

## Retained buyback protections

The hook records a 601-entry ring of distinct-timestamp prices. The vault enforces a 600-second time-weighted tick reference and fixed 50-bps output tolerance. Same-timestamp manipulation cannot evict the history. Every supported activation must explicitly reset history and require a fresh full warmup, including after rollback. The worker verifies that atomic batch. This remains a trusted-administrator obligation: the hook cannot detect an unobserved return to the identical implementation if an administrator omits the reset; an arbitrary upgrade can also replace all safeguards. That residual authority is unchanged and must be assessed explicitly. One successful buyback per ArbSys block, actual full-input spending, matching burns and cumulative accounting remain required. The AMM history is not an independent fair-value oracle; report sustained manipulation and price-trend limitations honestly. The owner-only donation burn has its own counter, spends no ETH and cannot inflate buyback output.

## Reproduction and evidence

Compile with solc0.8.26 using the complete build/hook.standard-input.json and build/vault.standard-input.json (Cancun, viaIR, optimizer200). Run node build/verify-hashes.mjs to verify canonical source and artifact hashes. The dependencies directory includes source and original compilation inputs for the actual chain4663 pool manager and router; reproduce non-immutable runtime bytes and verify live addresses. The baseline directory contains the prior hook/vault and administrator. Missing source or live evidence is a limitation to report, not permission to skip a requirement.

The verification directory includes standalone oracle, donation and advisor tests requiring Forge and no libraries. Main development tests and actual-chain-state fork checks also cover the complete administrator handover, original fee preservation, a user swap, exact founder/advisor ETH payouts, rollback/re-upgrade, and renewed warmup. A local fork is test evidence, not a live deployment or payment receipt.

## Activation gates

The new vault owner stays the existing administrator. The founder must register the actual deployed new vault with setTarget(newVault,true), preserving operator revocation. The exact atomic batch retires the old vault, upgrades the hook, initializes fresh oracle history, enables advisor accrual, changes the buyback destination, and recovers old fee ETH. Worker configuration changes require pause/drain and preserve all original action IDs, nonce history, receipts, cumulative burns and gas limits. Native controls must match the actual verified new runtime.

The owner publicly announced this revised allocation at https://x.com/i/status/2119198391330607591 . Earliest activation is 2026-11-07T23:45:00Z and a complete exact-context independent endorsement is additionally required. R1, R2 and R3 candidates are superseded. Their paid reports are retained but never treated as approval for this different source or new advisor allocation. LP principal, token and pool remain unchanged.
