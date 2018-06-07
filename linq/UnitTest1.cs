using System;
using System.Collections.Generic;
using System.Linq;
using Xunit;

namespace linq
{
    public class UnitTest1
    {
        public enum Suit
        {
            Clubs,
            Diamonds,
            Hearts,
            Spades,
        }
    
        public enum Rank
        {
            Two,
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
    
        public class PlayingCard
        {
            public Suit CardSuit { get; }
            public Rank CardRank { get; }
    
            public PlayingCard(Suit s, Rank r)
            {
                CardSuit = s;
                CardRank = r;
            }
    
            public override string ToString()
            {
                return $"{CardRank} of {CardSuit}";
            }
        }
    
        public class Program
        {
            [Fact]
            public static void v()
            {
                var startingDeck = (from s in Suits()
                                    from r in Ranks()
                                    select new PlayingCard(s, r))
                                   .ToArray();
                // check length
                Assert.Equal(52, startingDeck.Length);
                // assert that all of kinds are different
                for (int i = 0;i < startingDeck.Length;i++)
                    for (int j = i + 1;j < startingDeck.Length;j++)
                        Assert.NotEqual(startingDeck[i], startingDeck[j]);
    
                var top = startingDeck.Take(26);
                var bottom = startingDeck.Skip(26);
    
                var shuffle2 = top.InterleaveSequenceWith(bottom);
    
    
                var times = 0;
                var shuffle = startingDeck;
                do
                {
                    var result = shuffle.Skip(26).InterleaveSequenceWith(shuffle.Take(26)).ToArray();
                    if( times % 2 == 0 )
                        Assert.Equal( shuffle[times/2 + result.Length/2], result[times] );
                    else Assert.Equal( shuffle[times/2], result[times] );
                    shuffle = result;
                    times++;
                } while (!startingDeck.SequenceEquals(shuffle));

                Assert.Equal(52, times);
            }
    
            static IEnumerable<Suit> Suits()
            {
                yield return Suit.Clubs;
                yield return Suit.Diamonds;
                yield return Suit.Hearts;
                yield return Suit.Spades;
            }
    
            static IEnumerable<Rank> Ranks()
            {
                yield return Rank.Two;
                yield return Rank.Three;
                yield return Rank.Four;
                yield return Rank.Five;
                yield return Rank.Six;
                yield return Rank.Seven;
                yield return Rank.Eight;
                yield return Rank.Nine;
                yield return Rank.Ten;
                yield return Rank.Jack;
                yield return Rank.Queen;
                yield return Rank.King;
                yield return Rank.Ace;
            }
        }
    }
    
    
}
public static class Extensions
{
    public static IEnumerable<T> InterleaveSequenceWith<T> (this IEnumerable<T> first, IEnumerable<T> second)
    {

        var firstIter = first.GetEnumerator();
        var secondIter = second.GetEnumerator();
        while (firstIter.MoveNext() && secondIter.MoveNext())
        {
            yield return firstIter.Current;
            yield return secondIter.Current;
        }

    }

    public static bool SequenceEquals<T>(this IEnumerable<T> first, IEnumerable<T> second)
    {
        var firstIter = first.GetEnumerator();
        var secondIter = second.GetEnumerator();
        while (firstIter.MoveNext() && secondIter.MoveNext())
        {
            if (!firstIter.Current.Equals(secondIter.Current))
                return false;
        }
        return true;
    }

}