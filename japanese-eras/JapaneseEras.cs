using System;
using System.Collections.Generic;
using System.Globalization;
using Xunit;

namespace JapaneseEras
{
    public class JapaneseEras
    {
        [Theory]
        [InlineData("2019-01-01", 4)] // Heisei
        [InlineData("2019-04-30", 4)] // Heisei
        [InlineData("2019-05-01", 5)] // Reiwa
        [InlineData("2019-12-31", 5)] // Reiwa
        public void VerifyEraIds(string date, int expectedEra)
        {
            var calendar = new JapaneseCalendar();
            var time = DateTime.Parse(date);
            int era = calendar.GetEra(time);
            Assert.Equal(expectedEra, era);
        }

        [Theory]
        [InlineData("2019-01-01", "平成")] // Heisei
        [InlineData("2019-04-30", "平成")] // Heisei
        [InlineData("2019-05-01", "令和")] // Reiwa
        [InlineData("2019-12-31", "令和")] // Reiwa
        public void VerifyEraNames(string date, string expectedEra)
        {
            CultureInfo japaneseCulture = new CultureInfo("ja-JP");
            var calendar = new JapaneseCalendar();
            japaneseCulture.DateTimeFormat.Calendar = calendar;

            var eraTime = DateTime.Parse(date);

            Assert.Equal(expectedEra, eraTime.ToString("gg", japaneseCulture));
        }
    }
}
