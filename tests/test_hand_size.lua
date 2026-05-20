-- tests/test_hand_size.lua
-- Standalone test: negative tiles don't count toward the 7-tile hand size.
-- Run with: lua tests/test_hand_size.lua  (no Love2D needed)

-- Minimal stubs so hand.lua can be loaded without Love2D
Hand = {}
function Hand.updatePositions() end

UI = {
    Layout = {
        scale = function(n) return n end,
        getHandPosition = function() return 0, 0 end,
        getHandArea = function() return 0, 0, 1000, 100 end,
    },
    Fonts = { get = function() return { getWidth = function() return 0 end, getHeight = function() return 12 end } end },
}
gameState = { screen = { width = 1000, height = 500 } }

dofile("game/hand.lua")

local passed, failed = 0, 0

local function assert_eq(label, got, expected)
    if got == expected then
        io.write("  PASS " .. label .. "\n")
        passed = passed + 1
    else
        io.write("  FAIL " .. label .. ": got " .. tostring(got) .. ", want " .. tostring(expected) .. "\n")
        failed = failed + 1
    end
end

local function tile(neg)
    return { negative = neg or false, selected = false, placed = false, id = tostring(math.random(1,1e9)) }
end

local function make_deck(total, neg_positions)
    local neg_set = {}
    for _, p in ipairs(neg_positions or {}) do neg_set[p] = true end
    local deck = {}
    for i = 1, total do
        table.insert(deck, tile(neg_set[i] == true))
    end
    return deck
end

-- ─── TEST 1 ─────────────────────────────────────────────────────────────────
-- Deck: negatives at positions 2, 5, 8 (interspersed in first 10 slots).
-- Drawing stops once 7 non-neg are in hand, so 10 tiles total are pulled
-- (7 non-neg + 3 neg encountered along the way).
io.write("TEST 1: initial draw with 3 negatives within first 10 deck slots\n")
do
    local deck = make_deck(28, {2, 5, 8})
    local hand = {}
    Hand.refillHandNegativeAware(hand, deck, 7)

    assert_eq("hand size", #hand, 10)
    assert_eq("non-neg in hand", Hand.countNonNegative(hand), 7)
    assert_eq("deck remaining", #deck, 18)
end

-- ─── TEST 2 ─────────────────────────────────────────────────────────────────
-- Deck is entirely negative. Should draw the full deck.
io.write("TEST 2: all-negative deck draws entire deck\n")
do
    local neg_pos = {}
    for i = 1, 10 do neg_pos[i] = i end
    local deck = make_deck(10, neg_pos)
    local hand = {}
    Hand.refillHandNegativeAware(hand, deck, 7)

    assert_eq("hand size == deck was 10", #hand, 10)
    assert_eq("non-neg in hand", Hand.countNonNegative(hand), 0)
    assert_eq("deck exhausted", #deck, 0)
end

-- ─── TEST 3 ─────────────────────────────────────────────────────────────────
-- Discard scenario: 1 non-neg on board, 5 non-neg in hand (discarded 2),
-- deck has all regular tiles. Should draw 1 to reach 7 total non-neg.
io.write("TEST 3: discard refill with 1 non-neg placed on board\n")
do
    local deck = make_deck(20, {})
    local hand = {}
    -- Seed hand with 5 non-neg tiles
    for i = 1, 5 do table.insert(hand, tile(false)) end

    local placedNonNeg = 1  -- 1 non-neg tile is on the board
    Hand.refillHandNegativeAware(hand, deck, 7, placedNonNeg)

    -- 5 in hand + 1 on board = 6 non-neg; need 1 more → draws 1
    assert_eq("hand size", #hand, 6)
    assert_eq("non-neg in hand", Hand.countNonNegative(hand), 6)
    assert_eq("deck remaining", #deck, 19)
end

-- ─── TEST 4 ─────────────────────────────────────────────────────────────────
-- Already at target: 5 non-neg in hand + 2 on board = 7 total. Draw 0.
-- 1 negative tile also in hand (shouldn't affect count).
io.write("TEST 4: already at 7 non-neg (hand + board), draw nothing\n")
do
    local deck = make_deck(20, {})
    local hand = {}
    for i = 1, 5 do table.insert(hand, tile(false)) end
    table.insert(hand, tile(true))  -- 1 negative in hand

    local placedNonNeg = 2  -- 2 non-neg on board
    Hand.refillHandNegativeAware(hand, deck, 7, placedNonNeg)

    assert_eq("hand size (no draw)", #hand, 6)  -- 5 non-neg + 1 neg, unchanged
    assert_eq("non-neg in hand", Hand.countNonNegative(hand), 5)
    assert_eq("deck untouched", #deck, 20)
end

-- ─── TEST 5 ─────────────────────────────────────────────────────────────────
-- Pure positive deck, empty hand: draws exactly 7.
io.write("TEST 5: normal draw from all-regular deck\n")
do
    local deck = make_deck(28, {})
    local hand = {}
    Hand.refillHandNegativeAware(hand, deck, 7)

    assert_eq("hand size", #hand, 7)
    assert_eq("non-neg in hand", Hand.countNonNegative(hand), 7)
    assert_eq("deck remaining", #deck, 21)
end

-- ─── TEST 6 ─────────────────────────────────────────────────────────────────
-- Negatives interspersed: every 3rd tile is negative (positions 3,6,9).
-- Initial draw should pull 7 non-neg + 3 neg = 10 tiles total.
io.write("TEST 6: interspersed negatives in deck\n")
do
    local deck = make_deck(28, {3, 6, 9})
    local hand = {}
    Hand.refillHandNegativeAware(hand, deck, 7)

    assert_eq("hand size", #hand, 10)
    assert_eq("non-neg in hand", Hand.countNonNegative(hand), 7)
end

-- ─── TEST 7 ─────────────────────────────────────────────────────────────────
-- Anchor tile on board must not consume a hand slot.
-- countNonNegative should return 0 for a list containing only an anchor tile.
io.write("TEST 7: anchor tile on board does not consume a hand slot\n")
do
    local placedTiles = { { negative = false, isAnchor = true } }
    local deck = make_deck(20, {})
    local hand = {}
    local placedNonNeg = Hand.countNonNegative(placedTiles)

    assert_eq("anchor not counted", placedNonNeg, 0)
    Hand.refillHandNegativeAware(hand, deck, 7, placedNonNeg)
    assert_eq("hand draws 7 despite anchor on board", #hand, 7)
    assert_eq("deck consumed 7", #deck, 13)
end

-- ─── Summary ────────────────────────────────────────────────────────────────
io.write(string.format("\n%d passed, %d failed\n", passed, failed))
os.exit(failed > 0 and 1 or 0)
