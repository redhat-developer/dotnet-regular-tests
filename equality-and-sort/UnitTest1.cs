using System;
using Xunit;
using System.Collections.Generic;

namespace partTest
{
    public class UnitTest1
    {
        [Fact]
        public void Test1()
        {
            List<Part> parts = new List<Part>();

            // Add parts to the list.
            parts.Add(new Part() { PartName = "regular seat", PartId = 1434 });
            parts.Add(new Part() { PartName= "crank arm", PartId = 1234 });
            parts.Add(new Part() { PartName = "shift lever", PartId = 1634 }); ;
            // Name intentionally left null.
            parts.Add(new Part() {  PartId = 1334 });
            parts.Add(new Part() { PartName = "banana seat", PartId = 1444 });
            parts.Add(new Part() { PartName = "cassette", PartId = 1534 });
            
            parts.Sort();

            for (int i = 0; i < parts.Count - 1; i++)
                Assert.True(parts[i].CompareTo(parts[i + 1]) == -1, "");
            parts.Sort(delegate(Part x, Part y)
            {
                if (x.PartName == null && y.PartName == null) return 0;
                else if (x.PartName == null) return -1;
                else if (y.PartName == null) return 1;
                else return x.PartName.CompareTo(y.PartName);
            });
            for (int i = 0; i < parts.Count - 1; i++)
                if (parts[i].PartName != null)
                    Assert.True(parts[i].PartName.CompareTo(parts[i + 1].PartName) == -1);

        }
    }
}
