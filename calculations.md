# Hand calculations

Use 4 bitmaps (one for each suit). Each bit represents 2 - A. For straights, flushes, and straight flushes. Low Ace is reserved bit 0.

Use a 52-bit bitmap for ranked cards, to count cards, and get kickers. Each set of 4 bits represents the 4 cards of that rank in suit order.

## Algorithm for straight

copy Ace bit to LowAce bit.
then 4 times, shift the bits up by 1, and & with the original mask. After this,
there should be only bits where the lower 4 cards were set. Take the highest
bit as the top rank of the straight.

## Algorithm for rank counts

All hands besides Straight Flush, Flush, and Straight use no suits or connected
cards. So we just count everything.

First, we build the bitmask, setting each bit that is given to us.

Then, we loop from highest rank to lowest, checking how many of each bit are
present in that rank.

We keep track of the highest quad, the highest 3 of a kind, the highest pair, and the second highest pair. One exception is if there are 2 sets, the second highest set is considered the first pair (for a full house).

## Kickers

For hands that need kickers, we remove the cards from the bitmask as we put them in the top card positions, from most significant to least. Then we are left with the bitmask of the remaining cards.

Each kicker is popped from the highest bit set.

## Checking each hand type

### Straight Flush

run straight algorithm on each of the 4 suit bitmasks. If any straights come back, we are done.

### Quads

Run the rank count algorithm at this point.

If highest quad is set, then we return those 4 cards + one kicker.

### Full House

If highest trip is set, and pair 1 is set, then return the 3 cards of the trip + the two cards of the pair.

### Flush

Check the bit count of each suit mask, take the top 5 bits if you have 5 or more in
the bitcount.

Compare the bitmasks if there is more than one flush.

### Straight

Run the straight algorithm on the logical Or of all suit bitmasks. If any straight comes back, pop the ranks in order from the 52-card bitmask.

### Three of a kind

If the highest trip is set, pop the 3 highest trip from the bitmask, then pop 2 kickers.

### Two pair

If both pair 1 and pair 2 are set, pop the two pair 1 ranks, then the two pair 2 ranks from the bitmask. Fill in with one kicker

### One pair

If only pair 1 is set, pop those two cards, then pop 3 kickers.

### High card

Pop 5 kickers.

## Comparing hands

Cards are stored in order of most significant card to least. First, the hand
type is compared, if there are any differences, they are ranked according to
that.

If the types are the same, the cards ranks are compared in order (No suit comparisons).

Potentially, I can build a signature of the cards into a mask that holds 13^5
values, + the high bits could be the hand type, and just compare that integer.
I'm not sure how important that is. Most rank comparisons will end in one or
two loop iterations.
