# ARENA — Design Notes (open)

Evolving gameplay ideas not yet folded into `GDD.txt`. Each is a proposal with a
rationale and any open questions. Promote to the GDD once resolved.

---

## DN-1 · Last-player endgame (proposed 2026-09-03)

**Idea.** When a team is reduced to **one** player, if that player is "killed"
(their shard taken) and does not recover — grab a shard and return it to their
base — before some short condition, **the match ends** rather than letting them
re-enter a respawn loop.

**Why.** A lone last player who keeps respawning at a known spot gets
spawn-camped / stun-locked. It is not fun for them and it drags the match out
with no real tension. Ending decisively when it is down to 1-vs-many makes the
endgame quick and clean.

**Open questions — reconcile with the current GDD.**
- `GDD.txt` already says "If there are no teammates left, then the match is over"
  and "Only the shard owner's teammate can return it to revive them." So a true
  *last* player with a stolen shard is **already** eliminated (no teammate to
  revive). DN-1 may be describing a slightly different moment:
  - the last player still alive but shard-less, being farmed while trying to
    self-retrieve? → DN-1 = "no self-retrieve when you're the last one; taking
    your shard ends it."
  - or a grace timer: last player has N seconds to reach a shard or the match
    calls it.
- Which reading does the pillar want? Decide before implementing.

**Design-lens take.** The instinct is right — anti-spawn-lock, faster decisive
endgame. Cleanest rule that fits the existing system: **once a team is down to
one, that player cannot be revived and cannot self-revive; losing their shard
ends the match.** No new timer, no new state — just "revive is disabled at
team-size 1." Confirm this matches the intent.
