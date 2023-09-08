using System.Runtime.InteropServices;

// Try load the native library packaged from the 'lib' class.
NativeLibrary.Load("mylib", typeof(Program).Assembly, DllImportSearchPath.ApplicationDirectory);
