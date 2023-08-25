
// Run some loops to get the JIT compiler to optimize this code

int iterations = (int.MaxValue / 100);
if (args.Length >= 1)
{
    iterations = int.Parse(args[0]);
}

Console.WriteLine($"Running {iterations} iterations.");

for (int i = 0; i < iterations; i++)
{
    if (i % 10000 == 0)
    {
        Console.Error.Write(".");
    }
}

Console.Error.WriteLine();
