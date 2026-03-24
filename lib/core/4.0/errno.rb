module Errno
  @by_errno = {}

  def self._by_errno(num) = @by_errno[num]

  def self._define(name, num, strerror)
    if @by_errno.key?(num)
      const_set(name, @by_errno[num])
    else
      klass = Class.new(SystemCallError)
      klass.const_set(:Errno, num)
      klass.const_set(:Strerror, strerror)
      @by_errno[num] = klass
      const_set(name, klass)
    end
  end
  _define :E2BIG,          7,  "Argument list too long"
  _define :EACCES,        13,  "Permission denied"
  _define :EADDRINUSE,    98,  "Address already in use"
  _define :EADDRNOTAVAIL, 99,  "Cannot assign requested address"
  _define :EAFNOSUPPORT, 97,   "Address family not supported by protocol"
  _define :EAGAIN,        11,  "Resource temporarily unavailable"
  _define :EALREADY,     114,  "Operation already in progress"
  _define :EBADF,          9,  "Bad file descriptor"
  _define :EBUSY,         16,  "Device or resource busy"
  _define :ECHILD,        10,  "No child processes"
  _define :EILSEQ,        84,  "Invalid or incomplete multibyte or wide character"
  _define :ECONNABORTED, 103,  "Software caused connection abort"
  _define :ECONNREFUSED, 111,  "Connection refused"
  _define :ECONNRESET,   104,  "Connection reset by peer"
  _define :EDEADLK,       35,  "Resource deadlock avoided"
  _define :EDOM,          33,  "Numerical argument out of domain"
  _define :EEXIST,        17,  "File exists"
  _define :EFAULT,        14,  "Bad address"
  _define :EFBIG,         27,  "File too large"
  _define :EHOSTUNREACH,  113, "No route to host"
  _define :EINPROGRESS,  115,  "Operation now in progress"
  _define :EINTR,          4,  "Interrupted system call"
  _define :EINVAL,        22,  "Invalid argument"
  _define :EIO,            5,  "Input/output error"
  _define :EISCONN,       106, "Transport endpoint is already connected"
  _define :EISDIR,        21,  "Is a directory"
  _define :ELOOP,         40,  "Too many levels of symbolic links"
  _define :EMFILE,        24,  "Too many open files"
  _define :EMSGSIZE,      90,  "Message too long"
  _define :ENAMETOOLONG,  36,  "File name too long"
  _define :ENETDOWN,     100,  "Network is down"
  _define :ENETUNREACH,  101,  "Network is unreachable"
  _define :ENFILE,        23,  "Too many open files in system"
  _define :ENODEV,        19,  "No such device"
  _define :ENOENT,         2,  "No such file or directory"
  _define :ENOEXEC,        8,  "Exec format error"
  _define :ENOMEM,        12,  "Cannot allocate memory"
  _define :ENOSPC,        28,  "No space left on device"
  _define :ENOSYS,        38,  "Function not implemented"
  _define :ENOTCONN,     107,  "Transport endpoint is not connected"
  _define :ENOTDIR,       20,  "Not a directory"
  _define :ENOTEMPTY,     39,  "Directory not empty"
  _define :ENOTSUP,       95,  "Operation not supported"
  _define :ENOTTY,        25,  "Inappropriate ioctl for device"
  _define :ENXIO,          6,  "No such device or address"
  _define :EOPNOTSUPP,    95,  "Operation not supported"
  _define :EOVERFLOW,     75,  "Value too large for defined data type"
  _define :EPERM,          1,  "Operation not permitted"
  _define :EPIPE,         32,  "Broken pipe"
  _define :EPROTONOSUPPORT, 93,"Protocol not supported"
  _define :ERANGE,        34,  "Numerical result out of range"
  _define :EROFS,         30,  "Read-only file system"
  _define :ESPIPE,        29,  "Illegal seek"
  _define :ESRCH,          3,  "No such process"
  _define :ETIMEDOUT,    110,  "Connection timed out"
  _define :ETXTBSY,       26,  "Text file busy"
  _define :EWOULDBLOCK,   11,  "Resource temporarily unavailable"
  _define :EXDEV,         18,  "Invalid cross-device link"
end
