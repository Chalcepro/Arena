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

---

## DN-3 · Map v2: an infinite-maze of tiles, open high ground, wall slopes (2026-10-17)

From Chalce's play-test of the first movement map. That map stays as a test of
jump and sprint limits. It's fine for that, but it has too little detail.

**The tiles are a measured kit, like Unreal's template assets.** The point of
building maps from tiles is that the sizes carry the rules: anything taller
than X can't be climbed, lower than Y can't be crouched under, wider than Z
can't be cleared even sprinting. People can swap a tile's look for their own
art, but they keep its measurements (or go smaller), or the movement and later
the animation break. That makes maps easy to make and easy to understand.
The measurements come from Hex's own movement once it's settable, NOT from
the Godot-era GDD numbers (`hex/docs/flows/movement.md`).

**The map he has in mind:** blocks used one for one, laid out like the
abstract "infinite rooms" artwork: staircases into staircases, into rooms,
out into more staircases, doors everywhere, a maze with complexity. Nearly
all of it climbable. Not the sideways or upside-down parts, which are only the
look of the reference.

**High ground is open:** shortcuts and perches above the main routes. You can
see players and they can see you. Cover no taller than a crouch, nowhere to
hide, peeking always shows you.

**Layout:** a main lane from A to B, routes round the sides, raised shortcuts
between them.

**Wall slopes:** too steep to stand on, runnable with momentum, gravity still
pulls you down. Miss and you're in the void.

**Examples:**
- `arena/blender assets/test_ground.blend`, object `obj-55.col.003`: a channel.
  Low lane down the middle, steep slopes up to ~13 m on both sides, raised
  triangle perches joined by ramps. That's the wall-slope and shortcut shape.
- `arena/scenes/node_3d.tscn` (Godot): a hand-built bricks level with tilted
  slab patches. That's the big slope and wall slope test.

Needs Hex movement v2 first (settable momentum, collision on every face, wall
slopes).

---

## DN-4 · Live-changing maps (game mode, parked 2026-10-17)

In some game modes the map changes during the match, like a maze. Closed doors
open, open ones close, a wall drops away. A route you could cross is gone, and
one you couldn't is there. Nobody gets to sit in one spot: you might be thrown
off the map, or the wall behind you opens and the other team is there.

Parked, but build so it stays possible: tiles stay separate objects that the
game can move, open and remove at runtime (not baked into one mesh), and
doors/walls are their own pieces.

---

## DN-5 · Story and feel: escaping through the game library (vision, 2026-10-17)

Chalce's direction for what Arena should feel like overall. Vision, not a
spec: nothing here is scheduled, and it doesn't change the multiplayer core.

**The feel.** A collection of games in one: whenever you open it there is
something to play, and it never feels stale. Not another AAA copy built on
the default Unreal movement, and not the "there's a bad guy, kill him,
everyone cheers" plot. It should have a real story with tension (his reference
for tension: the Ghost vs Price fight in Call of Duty: Modern Warfare).

**The story idea.** You are an AI living inside a game library (think a Steam
library) who becomes aware of where it is and tries to get out. Leaving one
game drops you into another, so each escape lands in a different world, styled
after games like Wipeout (anti-grav racing), Portal (portal puzzles), Mad Max
(wasteland driving). Crossing each boundary and breaking through each wall is
the progress. Those worlds are also **playable maps** in their own right; the
story run is the single-player side.

**Fights: Just Shapes & Beats telegraphs.** When an attack is about to hit,
you get an instant warning: a flash, a shape lighting up where it will land.
Boss fights and big fights use this so they're tense and readable, without
being overwhelming.

**The world moves to the music.** The horizon pulses on the beat, so the world
feels alive rather than copy-pasted. Music reference for the mood: *Hellbent*
by Mystery Skull ft. Snow Blood. The synth drives from low to high and then
sits on a bright, sustained high synth, over a groovy, danceable, mid-tempo
beat (not frantic).

**Look.** His own render is the target feeling (kept private). Hex needs
metallic surfaces for it (hex `docs/BACKLOG.md`, Phase 2 Look).

**What this asks of Hex.** Worlds have to be added without code ("you just add
stuff and it just works"), so the no-code nodes must be flexible enough to
build a racer, a puzzle room and a wasteland from the same parts. Beat sync
needs the music's tempo and beat times at runtime. The Tempo tool's detector
(Chalcepro/Tempo, `bpm.py`) already finds both from audio, so it could feed
an "On Beat" event later.
