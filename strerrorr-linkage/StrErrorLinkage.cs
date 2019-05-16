using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using Xunit;

namespace strerror
{
    // Make sure that strerror_r is usable on *nix
    public class StrErrorLinkage
    {
        // The SocketException constructor does an strerror_r() to
        // resolve the error code into a string message. Assert that
        // it works.
        [Fact]
        public void SocketExceptionMessageIsParsedCorrectly()
        {
            var se = new SocketException((int)SocketError.InvalidArgument);
            Assert.Equal(22, se.NativeErrorCode);
            Assert.NotEmpty(se.Message);
            Assert.Equal("Invalid argument", se.Message);
        }

        // Manully duplicate the call that .NET Core internally does
        // to strerror_r
        [Fact]
        public void ManuallyInvokingSystemNative_StrErrorRWorks()
        {
            var message = StrError(22);
            Assert.NotEmpty(message);
            Assert.Equal("Invalid argument", message);
        }

        internal const string SystemNative = "System.Native";

        static unsafe string StrError(int platformErrno)
        {
            int maxBufferLength = 1024; // should be long enough for most any UNIX error
            byte* buffer = stackalloc byte[maxBufferLength];
            byte* message = StrErrorR(platformErrno, buffer, maxBufferLength);

            if (message == null)
            {
                // This means the buffer was not large enough, but still contains
                // as much of the error message as possible and is guaranteed to
                // be null-terminated. We're not currently resizing/retrying because
                // maxBufferLength is large enough in practice, but we could do
                // so here in the future if necessary.
                message = buffer;
            }

            return Marshal.PtrToStringAnsi((IntPtr)message);
        }

        [DllImport(SystemNative, EntryPoint = "SystemNative_StrErrorR")]
        private static extern unsafe byte* StrErrorR(int platformErrno, byte* buffer, int bufferSize);
    }
}
