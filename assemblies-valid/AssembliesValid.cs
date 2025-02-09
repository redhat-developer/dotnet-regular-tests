using System;
using System.Buffers.Binary;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;
using System.Runtime;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using Xunit;
using Xunit.Abstractions;

namespace AssembliesValid
{
    public class AssembliesValid
    {
        // https://github.com/dotnet/runtime/blob/4f9ae42d861fcb4be2fcd5d3d55d5f227d30e723/src/coreclr/src/inc/pedecoder.h#L90
        public static readonly int IMAGE_FILE_MACHINE_NATIVE_OS_OVERRIDE_LINUX = 0x7B79;

        // https://github.com/dotnet/runtime/blob/master/src/coreclr/src/inc/corcompile.h
        public static readonly int CORCOMPILE_SIGNATURE = 0x0045474E; // 'NGEN'

        // https://github.com/dotnet/runtime/blob/master/src/coreclr/src/inc/readytorun.h
        public static readonly int READYTORUN_SIGNATURE = 0x00525452; // 'RTR'

        public static string[] IgnoredFileNames =
        {
            "mscorlib.dll",
            "msdia140.dll",
            "System.Private.CoreLib.dll",
            "System.Runtime.WindowsRuntime.dll",
        };

        public static Regex[] IgnoredPaths =
        {
            new Regex(".*\\.resources\\.dll$"),
            new Regex("/sdk/"),
            new Regex("/packs/"),
        };

        private readonly ITestOutputHelper _output;

        public AssembliesValid(ITestOutputHelper output)
        {
            _output = output;
        }

        [Fact]
        public void ValidateAssemblies()
        {
            string dotnetPath = null;
            int exitCode = RunProcessAndGetOutput(new string[] { "bash", "-c", "command -v dotnet" }, out dotnetPath);
            if (exitCode != 0)
            {
                _output.WriteLine("'dotnet' command not found");
                _output.WriteLine("PATH: " + Environment.GetEnvironmentVariable("PATH"));
                Assert.True(false);
            }
            dotnetPath = dotnetPath.Trim();
            exitCode = RunProcessAndGetOutput(new string[] { "readlink", "-f", dotnetPath }, out dotnetPath);
            if (exitCode != 0)
            {
                _output.WriteLine($"Unable to run readlink -f {dotnetPath}");
                Assert.True(false);
            }
            dotnetPath = dotnetPath.Trim();

            string searchRoot = new FileInfo(dotnetPath).DirectoryName;
            var searchRootDirectory = new System.IO.DirectoryInfo(searchRoot);

            _output.WriteLine($"Searching for dotnet binaries in {searchRoot}");

            var architecture = RuntimeInformation.OSArchitecture;
            var machine = GetCurrentMachine(architecture);

            ICollection<string> assemblies = FindAssemblyFiles(searchRootDirectory);

            bool allOkay = true;
            foreach (var assembly in assemblies)
            {
                bool ignored = IgnoredFileNames.Any(basename => new FileInfo(assembly).Name == basename);

                if (!ignored) {
                    using (var file = File.Open(assembly, FileMode.Open, FileAccess.Read))
                    {
                        var reader = new PEReader(file);
                        bool hasAot = AssemblyHasAot(assembly, reader, machine);
                        bool inReleaseMode = AssemblyIfNgenIsInReleaseMode(assembly, reader);
                        bool hasMethods = AssemblyHasMethods(reader);

                        bool valid = true;
                        if (!inReleaseMode)
                        {
                            valid = false;
                        }
                        if (hasMethods && !hasAot)
                        {
                            // 32-bit arm doesn't have AOT and niehter do s390x and ppc64le (which use mono). That's okay for now.
                            if (architecture != Architecture.Arm
#if NET7_0_OR_GREATER
                                && architecture != Architecture.Ppc64le
#endif
#if NET6_0_OR_GREATER
                                && architecture != Architecture.S390x
#endif
                                )
                            {
                                valid = false;
                            }
                        }

                        if (valid)
                        {
                            _output.WriteLine($"{assembly}: OK");
                        }
                        else
                        {
                            _output.WriteLine($"error: {assembly} hasMethods: {hasMethods}, hasAot: {hasAot}, inReleaseMode: {inReleaseMode}");
                            allOkay = false;
                        }
                    }
                }
            }

            Assert.True(allOkay);
        }

        static int RunProcessAndGetOutput(string[] processAndArguments, out string standardOutput)
        {
            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName =  processAndArguments[0];
            foreach (string arg in processAndArguments.Skip(1))
            {
                startInfo.ArgumentList.Add(arg);
            }
            startInfo.RedirectStandardOutput = true;

            using (Process p = Process.Start(startInfo))
            {
                p.WaitForExit();
                using (StreamReader r = p.StandardOutput)
                {
                    standardOutput = r.ReadToEnd();
                }
                return p.ExitCode;
            }
        }

        static Machine GetCurrentMachine(Architecture arch)
        {
            switch (arch)
            {
                case Architecture.Arm:
                    return Machine.Arm;
                case Architecture.Arm64:
                    return Machine.Arm64;
#if NET7_0_OR_GREATER
                case Architecture.Ppc64le:
                    return Machine.Unknown;
#endif
#if NET6_0_OR_GREATER
                case Architecture.S390x:
                    return Machine.Unknown;
#endif
                case Architecture.X64:
                    return Machine.Amd64;
                case Architecture.X86:
                    return Machine.I386;
                default:
                    throw new InvalidOperationException($"Unknown architecture {arch}");
            }
        }

        static ICollection<string> FindAssemblyFiles(DirectoryInfo searchRoot)
        {
            var assemblies = new List<string>();
            var directoryStack = new Stack<DirectoryInfo>();

            directoryStack.Push(searchRoot);

            while (directoryStack.TryPop(out DirectoryInfo dir))
            {
                foreach(var aDirectory in dir.EnumerateDirectories())
                {
                    directoryStack.Push(aDirectory);
                }

                foreach (var fileInfo in dir.EnumerateFiles("*.dll"))
                {
                    if (!IgnoredPaths.Any(pattern => pattern.IsMatch(fileInfo.FullName)))
                    {
                        assemblies.Add(fileInfo.FullName);
                    }
                }
            }

            assemblies.Sort(StringComparer.Ordinal);
            return assemblies;
        }

        static bool AssemblyHasAot(string assemblyPath,
                                   PEReader reader,
                                   Machine expectedArchitecture)
        {
            var managedNativeHeaderDirectory = reader.PEHeaders.CorHeader.ManagedNativeHeaderDirectory;
            if (managedNativeHeaderDirectory.Size != 0)
            {
                var rva = managedNativeHeaderDirectory.RelativeVirtualAddress;
                var data = reader.GetSectionData(rva);
                byte[] magicBytes = data.GetContent(0, 4).ToArray();
                int magic = BinaryPrimitives.ReadInt32LittleEndian(magicBytes);
                if (magic == READYTORUN_SIGNATURE)
                {
                    Machine machine = reader.PEHeaders.CoffHeader.Machine;
                    Machine actualArchitecture = (Machine)((int)machine ^ IMAGE_FILE_MACHINE_NATIVE_OS_OVERRIDE_LINUX);
                    if (expectedArchitecture != actualArchitecture)
                    {
                        return false;
                    }

                    return true;
                }
            }

            return false;
        }

        static bool AssemblyHasMethods(PEReader reader)
        {
            var metadataReader = reader.GetMetadataReader();
            return metadataReader.MethodDefinitions.Count > 0;
        }

        static bool AssemblyIfNgenIsInReleaseMode(string assemblyPath, PEReader reader)
        {
            var managedNativeHeaderDirectory = reader.PEHeaders.CorHeader.ManagedNativeHeaderDirectory;
            if (managedNativeHeaderDirectory.Size != 0)
            {
                var rva = managedNativeHeaderDirectory.RelativeVirtualAddress;
                var data = reader.GetSectionData(rva);
                byte[] magicBytes = data.GetContent(0, 4).ToArray();
                int magic = BinaryPrimitives.ReadInt32LittleEndian(magicBytes);
                if (magic == CORCOMPILE_SIGNATURE)
                {
                    // Extract CORCOMPILE_VERSION_INFO
                    byte[] versionInfoHeader = data.GetContent(40, 8).ToArray();
                    int corVersionRva = BinaryPrimitives.ReadInt32LittleEndian(versionInfoHeader);
                    var corVersionData = reader.GetSectionData(corVersionRva);

                    byte[] wBuildData = corVersionData.GetContent(16, 2).ToArray();
                    int wBuild = BinaryPrimitives.ReadInt16LittleEndian(wBuildData);

                    if (wBuild == 0)
                    {
                        return false;
                    }
                }
            }

            return true;
        }

    }
}
