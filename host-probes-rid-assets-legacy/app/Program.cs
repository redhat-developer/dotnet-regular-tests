using System.Runtime.InteropServices;

// Try load the native libraries packed under the rid folders.
NativeLibrary.Load("mylib-unix", typeof(Program).Assembly, DllImportSearchPath.ApplicationDirectory);
NativeLibrary.Load("mylib-sdkrid", typeof(Program).Assembly, DllImportSearchPath.ApplicationDirectory);
