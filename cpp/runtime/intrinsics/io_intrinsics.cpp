// Io-category intrinsic definitions. Declarations live in
// io_intrinsics.hpp; this TU compiles once per program and the
// linker resolves calls. With LTO, hot bodies inline back into callers.
//
// Not directly compilable: references program types (Integer*, String*,
// ...) declared in frozone_all.hpp. The Rakefile compiles this .cpp
// with `-I cpp/gen/box/<base>/` and routes the .o into the per-program
// gen dir.

#include "frozone_all.hpp"

// IO and the error classes used here aren't in frozone_post.hpp (which
// only pulls Integer/Float/String/NilClass etc.). Include the per-class
// hpps explicitly so we can `new IO()` and reference the error CLASSes.
#include "class/IO.hpp"
#include "class/ArgumentError.hpp"
#include "class/ArgumentError_eig.hpp"
#include "class/NotImplementedError.hpp"
#include "class/NotImplementedError_eig.hpp"

#include "io_intrinsics.hpp"
#include "../intrinsics_helpers.hpp"

#include <cstring>
#include <errno.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

namespace Ruby {

// Raw write to stdout/stderr — direct fwrite, no dispatch chain.
// Used by box-first compiled `io_write` when the receiver IOObject's
// @native_io is nil (chicken-egg: GLOBALS["$stdout"] is set at vm.rb
// bootstrap to IOObject.new(nil, …, stream_tag: :stdout), so the
// stream identity lives on the IOObject's @stream_tag ivar). The
// Ruby io_write detects native.nil? and routes here based on the tag.
// Return value: byte count written (Integer).
BasicObject* intrinsic_io_raw_write_stdout(BasicObject* /*self_*/, BasicObject* s) {
  if (!s || typeid(*s) != typeid(String)) {
    std::fprintf(stderr, "[box-first] io_raw_write_stdout: non-String arg (got %s)\n",
                 s ? s->ruby_class_name() : "(null)");
    std::abort();
  }
  auto* str = static_cast<String*>(s);
  std::size_t n = std::fwrite(str->bytes.data(), 1, str->bytes.size(), stdout);
  return boxed_int(static_cast<int64_t>(n));
}

// IO.popen — minimal fork+exec+pipe. Mode "r" only (read child's stdout);
// other modes raise NotImplementedError. cmd is String (shell exec) or
// Array of Strings (direct execvp). klass + opts are accepted but
// ignored. Returns plain IO with iv_fd set to the pipe read-end.
BasicObject* intrinsic_io_popen(BasicObject* /*klass*/, BasicObject* cmd,
                                BasicObject* mode, BasicObject* /*opts*/) {
  // Mode check: nil or "r" only.
  if (mode && mode != nil_instance()) {
    auto* m = BO::try_cast<String>(mode);
    if (!m || !(m->bytes.size() == 1 && m->bytes[0] == 'r')) {
      throw_not_implemented("io_popen: only mode 'r' supported");
    }
  }

  // Build argv. String cmd → ["sh", "-c", cmd, nullptr]. Array cmd →
  // direct argv. Hold the strings in a local vector so they outlive the
  // execvp call.
  std::vector<std::string> arg_storage;
  if (auto* s = BO::try_cast<String>(cmd)) {
    arg_storage.push_back("sh");
    arg_storage.push_back("-c");
    arg_storage.emplace_back(reinterpret_cast<const char*>(s->bytes.data()), s->bytes.size());
  } else if (auto* a = BO::try_cast<Array>(cmd)) {
    if (a->data.empty()) {
      throw static_cast<Exception*>((&ArgumentError_CLASS)->m_new(
        univ, new Array({static_cast<BO*>(new String("io_popen: empty argv array", 26))})));
    }
    // MRI accepts `IO.popen([env_hash, *argv], …)` — a leading Hash is
    // the env (key=>value pairs to set in the subprocess). Skip it so
    // exec sees the argv we actually want. We don't propagate the env
    // into the child here — that's already covered by the `env:` opt
    // path that lib/core/4.0/io.rb threads through opts_arg. This is
    // purely about not treating the env Hash as a bogus argv element.
    std::size_t _start = 0;
    if (a->data[0]->m_class(univ) == reinterpret_cast<BasicObject*>(&Hash_CLASS)) _start = 1;
    if (_start >= a->data.size()) {
      throw static_cast<Exception*>((&ArgumentError_CLASS)->m_new(
        univ, new Array({static_cast<BO*>(new String("io_popen: empty argv array", 26))})));
    }
    for (std::size_t _i = _start; _i < a->data.size(); _i++) {
      auto* e = a->data[_i];
      auto* es = BO::try_cast<String>(e);
      if (!es) {
        throw static_cast<Exception*>((&ArgumentError_CLASS)->m_new(
          univ, new Array({static_cast<BO*>(new String("io_popen: non-String argv element", 33))})));
      }
      arg_storage.emplace_back(reinterpret_cast<const char*>(es->bytes.data()), es->bytes.size());
    }
  } else {
    throw static_cast<Exception*>((&ArgumentError_CLASS)->m_new(
      univ, new Array({static_cast<BO*>(new String("io_popen: cmd must be String or Array", 37))})));
  }

  std::vector<char*> argv;
  argv.reserve(arg_storage.size() + 1);
  for (auto& s : arg_storage) argv.push_back(const_cast<char*>(s.c_str()));
  argv.push_back(nullptr);

  int pipefd[2];
  if (::pipe(pipefd) < 0) {
    throw_not_implemented("io_popen: pipe() failed");
  }

  pid_t pid = ::fork();
  if (pid < 0) {
    ::close(pipefd[0]);
    ::close(pipefd[1]);
    throw_not_implemented("io_popen: fork() failed");
  }
  if (pid == 0) {
    // Child: dup write-end to stdout, close pipe ends, exec.
    ::close(pipefd[0]);
    ::dup2(pipefd[1], 1);
    ::close(pipefd[1]);
    ::execvp(argv[0], argv.data());
    // Exec failed — exit with errno so parent sees nonzero status.
    ::_exit(127);
  }
  // Parent: close write end, return IO bound to read end. Stash the
  // child pid on the IO so IO#close can waitpid it and publish $? into
  // both the compiled tier (g_globals_storage via Process._do_waitpid)
  // and the interpreter tier (Vm::GLOBALS, bridged in the same helper).
  ::close(pipefd[1]);
  auto* io = new IO();
  io->iv_fd = new Integer(pipefd[0]);
  io->iv_closed = false_instance();
  io->iv_popen_pid = new Integer(pid);
  return io;
}

BasicObject* intrinsic_io_raw_write_stderr(BasicObject* /*self_*/, BasicObject* s) {
  if (!s || typeid(*s) != typeid(String)) {
    std::fprintf(stderr, "[box-first] io_raw_write_stderr: non-String arg (got %s)\n",
                 s ? s->ruby_class_name() : "(null)");
    std::abort();
  }
  auto* str = static_cast<String*>(s);
  std::size_t n = std::fwrite(str->bytes.data(), 1, str->bytes.size(), stderr);
  return boxed_int(static_cast<int64_t>(n));
}


}  // namespace Ruby
