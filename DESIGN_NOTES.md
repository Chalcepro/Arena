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

**CONFIRMED 2026-09-03.** Once a team is down to one player, that player cannot be
revived and cannot self-revive; losing their shard ends the match. **No grace
timer** in the base game. Just: revive disabled at team-size 1.

*Implemented (milestone 1, `hex/scripts/arena.lua`):* single-player vs bots — no
teammates, so a shard taken ends it, which satisfies DN-1 by construction. The
explicit "revive disabled at team-size 1" branch lands with the revive system.

*Future (not base game):* "luck points" — a resource that could buy a lone last
player a reprieve. Parked; revisit post-blockout.

---

## DN-2 · Tile maps and the collapsing edge (proposed 2026-10-17)

**Idea.** Maps are assembled from grouped tiles (bricks kit, 16 m squares): a
group runs for a few tiles, picking the best-fitting tile next to the last, then
a built wall ends it and the next group starts. The seed is fixed, so it bakes
ONE map; it does not change per load. Generator: `tools/blender/tilemap.py`.
First map: `arena/blender assets/movement_map.blend`, 96 x 96 m, made for testing
movement (sprint, jump gaps 2-14 m, step heights, slide lanes, ramps, decks).

**Parked for Battle Royale.** The map floats in a void, so the shrinking zone
could be the tiles themselves dropping away, so the map literally collapses
from the edge in. Not for MP maps. MP maps stay well under half the BR map's
size.
