module poker.hand;
import std.range;

enum Suit : byte
{
    Spades,
    Hearts,
    Diamonds,
    Clubs,
}

enum Rank : byte
{
    Empty,
    Deuce,
    Three,
    Four,
    Five,
    Six,
    Seven,
    Eight,
    Nine,
    Ten,
    Jack,
    Queen,
    King,
    Ace,
}

static immutable string[Rank.max+1] plurals = [
    "ERROR",
    "Deuces",
    "Threes",
    "Fours",
    "Fives",
    "Sixes", // all because of this one...
    "Sevens",
    "Eights",
    "Nines",
    "Tens",
    "Jacks",
    "Queens",
    "Kings",
    "Aces"
];

@safe pure nothrow @nogc Rank getRank(char c)
{
    import std.algorithm : countUntil;
    import std.utf : byCodeUnit;
    return cast(Rank)("23456789TJQKA".byCodeUnit.countUntil(c) + 1);
}

@safe pure nothrow @nogc unittest {
    assert(getRank('A') == Rank.Ace);
    assert(getRank('5') == Rank.Five);
}

@safe pure nothrow @nogc Suit getSuit(char c)
{
    import std.algorithm : countUntil;
    import std.utf : byCodeUnit;
    auto result = "SHDC".byCodeUnit.countUntil(c);
    assert(result >= Suit.min && result <= Suit.max);
    return cast(Suit)result;
}

@safe pure nothrow @nogc unittest {
    assert(getSuit('H') == Suit.Hearts);
    assert(getSuit('S') == Suit.Spades);
    assert(getSuit('C') == Suit.Clubs);
    assert(getSuit('D') == Suit.Diamonds);
}

struct Card
{
    Rank rank;
    Suit suit;

    pure @safe nothrow @nogc {
        this(Rank r, Suit s)
        {
            rank = r;
            suit = s;
        }

        this(string card)
        {
            this(getRank(card[0]), getSuit(card[1]));
        }

        int opCmp(Card other) const
        {
            return rank - other.rank;
        }

        bool opEquals(Card other) const
        {
            return rank == other.rank;
        }
    }

    pure @safe string toString() const
    {
        import std.conv : text;
        if(rank == Rank.Empty) return "";
        return text(rank, " of ", suit);
    }

    void toString(Out)(auto ref Out output) const
    {
        import std.format : formattedWrite;
        if(rank != Rank.Empty)
            output.formattedWrite("%s of %s", rank, suit);
    }
}

enum HandType
{
    HighCard,
    Pair,
    TwoPair,
    Trips,
    Straight,
    Flush,
    FullHouse,
    Quads,
    StraightFlush,
}

struct CardMap {
    ulong mapping;

    @safe nothrow @nogc pure:
    bool addCard(Card c)
    {
        auto mask = (1UL << (c.rank * 4 + c.suit));
        scope(exit) mapping |= mask;
        return (mapping & mask) == 0;
    }

    bool removeCard(Card c)
    {
        auto mask = (1UL << (c.rank * 4 + c.suit));
        scope(exit) mapping &= ~mask;
        return (mapping & mask) != 0;
    }

    uint count(Rank r)
    {
        import core.bitop : popcnt;
        assert(r > Rank.Empty && r <= Rank.Ace);
        return popcnt((mapping >> (r * 4)) & 0xf);
    }

    Card popKicker()
    {
        import core.bitop : bsr;
        if(mapping == 0)
            return Card.init;
        auto f = bsr(mapping);
        mapping &= ~(1UL << f);
        return Card(cast(Rank)(f / 4), cast(Suit)(f % 4));
    }

    Card popRank(Rank r)
    {
        import core.bitop : bsr;
        auto cards = (mapping >> (r * 4)) & 0xf;
        assert(cards);
        auto result = Card(r, cast(Suit)bsr(cards));
        assert(removeCard(result));
        return result;
    }
}

struct PokerHand
{
    Card[5] cards;
    HandType type;

    @safe pure nothrow @nogc
    {
        int opCmp(in PokerHand other) const
        {
            import std.algorithm : cmp;
            if(other.type == type)
                // compare card ranks, they are in order from most significant to
                // least.
                return cmp(cards[], other.cards[]);
            if(type > other.type)
                return 1; // our hand better
            return -1; // their hand better
        }

        // already defined, but just to make it clear
        bool opEquals(in PokerHand other) const
        {
            return this.tupleof == other.tupleof;
        }
    }

    void description(Out)(auto ref Out output, bool includeKickers = true) if(isOutputRange!(Out, char))
    {
        import std.format;
        import std.algorithm : map, filter;
        static genKickers(Card[] cards) {
            return cards.map!(c => c.rank).filter!(c => c != Rank.Empty);
        }
        // typeof(genKickers(null)) kickers; // this doesn't work for some reason
        auto kickers = genKickers(null);

        with(HandType) final switch(type)
        {
        case StraightFlush:
            output.formattedWrite("Straight Flush, %s to %s of %s", cards[4].rank, cards[0].rank, cards[0].suit);
            break;
        case Quads:
            output.formattedWrite("Four of a Kind, %s", plurals[cards[0].rank]);
            if(includeKickers)
                kickers = genKickers(cards[4 .. $]);
            break;
        case FullHouse:
            output.formattedWrite("Full House, %s over %s", plurals[cards[0].rank], plurals[cards[4].rank]);
            break;
        case Flush:
            output.formattedWrite("Flush, %s high %s", cards[0].rank, cards[0].suit);
            if(includeKickers)
                kickers = genKickers(cards[1 .. $]);
            break;
        case Straight:
            output.formattedWrite("Straight, %s to %s", cards[4].rank, cards[0].rank);
            break;
        case Trips:
            output.formattedWrite("Three of a Kind, %s", plurals[cards[0].rank]);
            if(includeKickers)
                kickers = genKickers(cards[3 .. $]);
            break;
        case TwoPair:
            output.formattedWrite("Two Pair %s and %s", plurals[cards[0].rank], plurals[cards[2].rank]);
            if(includeKickers)
                kickers = genKickers(cards[4 .. $]);
            break;
        case Pair:
            output.formattedWrite("Pair of %s", plurals[cards[0].rank]);
            if(includeKickers)
                kickers = genKickers(cards[2 .. $]);
            break;
        case HighCard:
            if(cards[0].rank == Rank.Empty)
                output.formattedWrite("No Hand");
            else
            {
                output.formattedWrite("High Card %s", cards[0].rank);
                if(includeKickers)
                    kickers = genKickers(cards[1 .. $]);
            }
            break;
        }
        if(!kickers.empty)
            output.formattedWrite(" (%(%s+%) kicker)", kickers);
    }

    @safe pure
    string description(bool includeKickers = true)
    {
        import std.array : Appender;
        Appender!string output;
        description(output, includeKickers);
        return output.data;
    }
}

// the straight table does not use the low ace slot, because we can just look at the ace bit. Therefore, we 
ubyte[] buildStraightTable() @safe
{
    ubyte[] result = new ubyte[1 << 12];
    // We count only high aces, so the lowest bit is actually marking a deuce.
    static immutable ushort[] masks = [
        0b1_0000_0000_1111, // wheel
        0b0_0000_0001_1111, // 2 - 6
        0b0_0000_0011_1110,
        0b0_0000_0111_1100,
        0b0_0000_1111_1000,
        0b0_0001_1111_0000,
        0b0_0011_1110_0000,
        0b0_0111_1100_0000,
        0b0_1111_1000_0000,
        0b1_1111_0000_0000,
    ];

    // the next spot where we will have to check for a different straight
    static immutable ushort[] limits = [
        1 << 4,
        1 << 5,
        1 << 6,
        1 << 7,
        1 << 8,
        1 << 9,
        1 << 10,
        1 << 11,
        1 << 12,
        1 << 13,
    ];


    // the low bit is either clear or set, as it tracks the high ace.
    ushort cur = 0;

    while(cur < result.length * 2)
    {
        import std.stdio;
        if(!__ctfe)
            writefln("starting at %b", cur);
        // At a change in the significant bits for straights. Find the appropriate straight
        byte rank = masks.length - 1;
        while(rank >= 0)
        {
            if((cur & masks[rank]) == masks[rank])
                // found it
                break;
            --rank;
        }

        if(rank == -1) // no straight
        {
            // skip to the next straight, and use that as the rank.
            bool aceMode = (cur & (1 << 12)) != 0;
            auto test = cur | (aceMode ? 0b01111 : 0b11111);
            rank = 2 - aceMode;
            while((test & masks[rank]) == masks[rank])
                ++rank;
            --rank;
            cur |= masks[rank];
        }

        if(!__ctfe)
            writefln("storing straights for %b, rank is %d", cur, rank);

        do
        {
            // TODO: we can probably combine these without storing twice.
            result[cur >> 1] |= ((rank + Rank.Five) << ((cur & 1) ? 4 : 0));
            ++cur;
        }while(!(cur & limits[rank]));
        // our current straight rank is no longer valid. restart the process.
    }

    return result;
}

static immutable ubyte[1 << 12] maxStraight = buildStraightTable();
//pragma(msg, maxStraight.length);

@safe pure nothrow @nogc
private Rank beststraight(bool useTable = true)(uint bits)
{
    static if(useTable)
    {
        if(bits & 2)
            return cast(Rank)(maxStraight[bits >> 2] >> 4);
        else
            return cast(Rank)(maxStraight[bits >> 2] & 0x0f);
    }
    else
    {
        import core.bitop : bsr;
        auto check = bits | (bits >> Rank.Ace);
        foreach(i; 0 .. 4)
            check = (check << 1) & bits;
        if(!check)
            return Rank.init; // no straight

        // straight, get the highest card of the straight from the bitmap
        return cast(Rank)bsr(check);
    }
}

@safe pure nothrow @nogc
unittest
{
    assert(beststraight!false(0b10000000011110) == Rank.Five);
    assert(beststraight!false(0b10101111111110) == Rank.Ten);

    foreach(b; 0 .. 1 << Rank.Ace)
        assert(beststraight!true(b << 1) == beststraight!false(b << 1));
}

PokerHand bestHand(CR)(CR cardRange) if (isInputRange!CR && is(ElementType!CR == Card))
{
    import core.bitop : popcnt, bsr;
    uint[Suit.max + 1] suits;
    CardMap ranks;
    foreach(c; cardRange.save)
    {
        suits[c.suit] |= (1U << c.rank);
        ranks.addCard(c);
    }

    // check for straight flush first
    Rank straight;
    Suit bestSuit;
    foreach(s, bits; suits)
    {
        auto sf = beststraight(bits);
        if(sf > straight)
        {
            straight = sf;
            bestSuit = cast(Suit)s;
        }
    }
    if(straight != Rank.Empty)
    {
        // straight flush
        PokerHand result;
        foreach(i; 0 .. 5)
        {
            result.cards[i] = Card(straight, bestSuit);
            if(--straight == Rank.Empty) straight = Rank.Ace;
        }
        result.type = HandType.StraightFlush;
        return result;
    }

    // check the rank map, looking for pairs, trips, quads
    Rank bestQuad;
    Rank bestTrip;
    Rank pair1;
    Rank pair2;
    HandType rankedHT = HandType.HighCard;

    static bool setRank(ref Rank cur, Rank newRank)
    {
        if(cur == Rank.Empty)
        {
            cur = newRank;
            return true;
        }
        return false;
    }

    //import std.stdio;
    for(Rank r = Rank.Ace; r > Rank.Empty; --r)
    {
        immutable n = ranks.count(r);
        if(n == 4)
        {
            // quads
            //writeln("found quad: ", r);
            bestQuad = r;
            rankedHT = HandType.Quads;
            break;
        }
        else if(n == 3)
        {
            //writeln("found trip: ", r);
            if(setRank(bestTrip, r))
                // if there's already a pair, this is a full house
                rankedHT = pair1 == Rank.Empty ? HandType.Trips : HandType.FullHouse;
            else if(setRank(pair1, r))
                // there's already a higher trip, treat this trip as the pair
                // of the full house
                rankedHT = HandType.FullHouse;
        }
        else if(n == 2)
        {
            //writeln("found pair: ", r);
            if(setRank(pair1, r))
                // if there's already a trip, full house, otherwise, just a pair
                rankedHT = bestTrip == Rank.Empty ? HandType.Pair : HandType.FullHouse;
            else if(setRank(pair2, r) && rankedHT == HandType.Pair)
                // only get here with 2 pair
                rankedHT = HandType.TwoPair;
        }
    }

    //writefln("q: %s, t: %s, p1: %s, p2: %s", bestQuad, bestTrip, pair1, pair2);
    //writeln("here, ranked type is ", rankedHT);

    // if we have a ranked hand type, and it's bigger than trips, we need to
    // return it now.
    if(rankedHT == HandType.Quads)
    {
        PokerHand result;
        result.type = HandType.Quads;
        // get all 4 cards from all 4 suits, then find the highest kicker.
        foreach(i; 0 .. 4)
            result.cards[i] = ranks.popRank(bestQuad);
        result.cards[4] = ranks.popKicker();
        return result;
    }
    if(rankedHT == HandType.FullHouse)
    {
        PokerHand result;
        result.type = HandType.FullHouse;
        foreach(i; 0 .. 3)
            result.cards[i] = ranks.popRank(bestTrip);
        foreach(i; 3 .. 5)
            result.cards[i] = ranks.popRank(pair1);
        return result;
    }
    
    // flush
    uint flush;
    foreach(s, bits; suits)
    {
        if(bits.popcnt >= 5 && bits > flush)
        {
            //writeln("found a flush in ", cast(Suit)s);
            flush = bits;
            bestSuit = cast(Suit)s;
        }
    }

    if(flush)
    {
        PokerHand result;
        foreach(i; 0 .. 5)
        {
            auto topCard = bsr(flush);
            flush &= ~(1U << topCard);
            result.cards[i] = Card(cast(Rank)topCard, bestSuit);
        }
        result.type = HandType.Flush;
        return result;
    }

    // check for straight with all suits
    straight = beststraight(suits[0] | suits[1] | suits[2] | suits[3]);
    if(straight > Rank.init)
    {
        PokerHand result;
        foreach(i; 0 .. 5)
        {
            result.cards[i] = ranks.popRank(straight);
            if(--straight == Rank.Empty)
                // low ace
                straight = Rank.Ace;
        }
        result.type = HandType.Straight;
        return result;
    }

    // Trips, 2 pair, pair, high card
    PokerHand result;
    result.type = rankedHT;
    switch(rankedHT)
    {
    case HandType.Trips:
        foreach(i; 0 .. 3)
            result.cards[i] = ranks.popRank(bestTrip);
        result.cards[3] = ranks.popKicker();
        result.cards[4] = ranks.popKicker();
        break;
    case HandType.TwoPair:
        result.cards[0] = ranks.popRank(pair1);
        result.cards[1] = ranks.popRank(pair1);
        result.cards[2] = ranks.popRank(pair2);
        result.cards[3] = ranks.popRank(pair2);
        result.cards[4] = ranks.popKicker();
        break;
    case HandType.Pair:
        result.cards[0] = ranks.popRank(pair1);
        result.cards[1] = ranks.popRank(pair1);
        foreach(i; 2 .. 5)
            result.cards[i] = ranks.popKicker();
        break;
    case HandType.HighCard:
        foreach(i; 0 .. 5)
            result.cards[i] = ranks.popKicker();
        break;
    default:
        assert(0, "Not possible!");
    }
    // final return of non-special ranked hands.
    return result;
}

@safe unittest {
    import std.conv : to;
    import std.algorithm : map;
    import std.meta : ApplyLeft;
    alias mc = ApplyLeft!(map, ApplyLeft!(to, Card));
    PokerHand log(PokerHand p)
    {
        version(logPokerHands)
        {
            import std.stdio;
            writeln(p.description);
        }
        return p;
    }
    assert(log(bestHand(mc(["AC", "2C", "3C", "4C", "5C"]))).type == HandType.StraightFlush);
    assert(log(bestHand(mc(["AC", "AH", "AS", "AD", "5C"]))).type == HandType.Quads);
    assert(log(bestHand(mc(["3C", "3D", "3S", "4C", "4D"]))).type == HandType.FullHouse);
    assert(log(bestHand(mc(["9C", "TC", "4C", "2C", "KC"]))).type == HandType.Flush);
    assert(log(bestHand(mc(["8C", "JD", "7C", "TC", "9C"]))).type == HandType.Straight);
    assert(log(bestHand(mc(["9D", "9C", "9H", "QC", "KC"]))).type == HandType.Trips);
    assert(log(bestHand(mc(["4C", "3C", "AH", "3D", "AC"]))).type == HandType.TwoPair);
    assert(log(bestHand(mc(["7D", "TC", "4S", "7C", "KC"]))).type == HandType.Pair);
    assert(log(bestHand(mc(["7D", "TC", "4S", "3C", "KC"]))).type == HandType.HighCard);
    assert(log(bestHand(mc(["AC", "AH", "AS", "AD", "2C", "3C", "4C", "5C"]))).type == HandType.StraightFlush);
    assert(log(bestHand(mc(["3C", "3D", "3S", "4C", "4D", "4S"]))).type == HandType.FullHouse);
}
