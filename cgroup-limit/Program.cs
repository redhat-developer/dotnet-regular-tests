using System;

class Program
{
    public static void Main()
    {
        Console.WriteLine("Limits:");
        Console.WriteLine(Environment.ProcessorCount);
        Console.WriteLine(GC.GetGCMemoryInfo().TotalAvailableMemoryBytes);
    }
}
