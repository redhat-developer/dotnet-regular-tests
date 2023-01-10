using System.Globalization;
using System.Data.Odbc;

string host = Environment.GetEnvironmentVariable("PGHOST")!;
string port = Environment.GetEnvironmentVariable("PGPORT")!;

int expectedRows = int.Parse(Environment.GetEnvironmentVariable("EXPECTED_ROWS")!, CultureInfo.InvariantCulture);
int expectedColumns = int.Parse(Environment.GetEnvironmentVariable("EXPECTED_COLUMNS")!, CultureInfo.InvariantCulture);

string connectionString = $"DRIVER={{PostgreSQL}};SERVER={host}; PORT={port};DATABASE=testdb;";
Console.WriteLine(connectionString);

OdbcConnection connection = new(connectionString);
connection.Open();

using (OdbcCommand dbCommand = connection.CreateCommand())
{
    dbCommand.CommandText = "SELECT * FROM test";
    using (OdbcDataReader dbReader = dbCommand.ExecuteReader())
    {
        int fieldCount = dbReader.FieldCount;
        if (fieldCount != expectedColumns)
        {
            throw new InvalidOperationException($"Expected {expectedColumns} but got {fieldCount}");
        }

        int rows = 0;
        while (dbReader.Read())
        {
            rows++;
        }

        if (rows != expectedRows)
        {
            throw new InvalidOperationException($"Expected {expectedRows} but got {rows}");
        }
        Console.WriteLine($"Got {expectedRows} rows of output, with {expectedColumns} columns");
    }
}
connection.Close();
