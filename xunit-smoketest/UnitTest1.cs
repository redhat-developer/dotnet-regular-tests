using System;
using Xunit;

namespace tests
{
    public class UnitTest1
    {
        [Fact]
        public void Test1()
        {
            Assert.Equal("pass", Environment.GetEnvironmentVariable("TEST_RESULT"));
        }
    }
}
