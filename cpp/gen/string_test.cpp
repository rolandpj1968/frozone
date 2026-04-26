#include "../runtime/box_first.hpp"

namespace Ruby {

struct BasicObject;
struct Object;
struct Class;
struct NilClass;
struct TrueClass;
struct FalseClass;
struct Integer;
struct Float;
struct Array;
struct Symbol;
struct String;
struct Hash;
struct Proc;
struct BasicObject_BasicObject;
struct Module;
struct Numeric;
struct Refinement;
struct Method;
struct UnboundMethod;
struct Range;
struct Enumerator;
struct Enumerator_Yielder;
struct Enumerator_Generator;
struct Enumerator_Lazy;
struct Enumerator_Chain;
struct Enumerator_ArithmeticSequence;
struct Enumerator_Product;
struct Exception;
struct ScriptError;
struct LoadError;
struct SyntaxError;
struct NotImplementedError;
struct SignalException;
struct Interrupt;
struct SystemExit;
struct StandardError;
struct RuntimeError;
struct FrozenError;
struct NameError;
struct NoMethodError;
struct TypeError;
struct ArgumentError;
struct RangeError;
struct FloatDomainError;
struct ZeroDivisionError;
struct IndexError;
struct FiberError;
struct ThreadError;
struct NoMemoryError;
struct SecurityError;
struct SystemStackError;
struct NoMatchingPatternError;
struct KeyError;
struct StopIteration;
struct ClosedQueueError;
struct UncaughtThrowError;
struct LocalJumpError;
struct SystemCallError;
struct IOError;
struct EOFError;
struct EncodingError;
struct RegexpError;
struct Errno_E2BIG;
struct Errno_EACCES;
struct Errno_EADDRINUSE;
struct Errno_EADDRNOTAVAIL;
struct Errno_EAFNOSUPPORT;
struct Errno_EAGAIN;
struct Errno_EALREADY;
struct Errno_EBADF;
struct Errno_EBUSY;
struct Errno_ECHILD;
struct Errno_EILSEQ;
struct Errno_ECONNABORTED;
struct Errno_ECONNREFUSED;
struct Errno_ECONNRESET;
struct Errno_EDEADLK;
struct Errno_EDOM;
struct Errno_EEXIST;
struct Errno_EFAULT;
struct Errno_EFBIG;
struct Errno_EHOSTUNREACH;
struct Errno_EINPROGRESS;
struct Errno_EINTR;
struct Errno_EINVAL;
struct Errno_EIO;
struct Errno_EISCONN;
struct Errno_EISDIR;
struct Errno_ELOOP;
struct Errno_EMFILE;
struct Errno_EMSGSIZE;
struct Errno_ENAMETOOLONG;
struct Errno_ENETDOWN;
struct Errno_ENETUNREACH;
struct Errno_ENFILE;
struct Errno_ENODEV;
struct Errno_ENOENT;
struct Errno_ENOEXEC;
struct Errno_ENOMEM;
struct Errno_ENOSPC;
struct Errno_ENOSYS;
struct Errno_ENOTCONN;
struct Errno_ENOTDIR;
struct Errno_ENOTEMPTY;
struct Errno_ENOTSUP;
struct Errno_ENOTTY;
struct Errno_ENXIO;
struct Errno_EOPNOTSUPP;
struct Errno_EOVERFLOW;
struct Errno_EPERM;
struct Errno_EPIPE;
struct Errno_EPROTONOSUPPORT;
struct Errno_ERANGE;
struct Errno_EROFS;
struct Errno_ESPIPE;
struct Errno_ESRCH;
struct Errno_ETIMEDOUT;
struct Errno_ETXTBSY;
struct Errno_EWOULDBLOCK;
struct Errno_EXDEV;
struct Math_DomainError;
struct Encoding;
struct Encoding_CompatibilityError;
struct Encoding_ConverterNotFoundError;
struct Encoding_InvalidByteSequenceError;
struct Encoding_UndefinedConversionError;
struct Encoding_Converter;
struct MatchData;
struct Regexp;
struct Regexp_TimeoutError;
struct Rational;
struct Complex;
struct IO;
struct IO_CapturedOutput;
struct IO_EAGAINWaitReadable;
struct IO_EAGAINWaitWritable;
struct IO_EWOULDBLOCKWaitReadable;
struct IO_EWOULDBLOCKWaitWritable;
struct File;
struct File_Stat;
struct Dir;
struct Time;
struct Mutex;
struct Fiber;
struct ThreadKill;
struct Thread;
struct Thread_Blocked;
struct Thread_Mutex;
struct Thread_Backtrace;
struct Thread_Backtrace_Location;
struct ThreadGroup;
struct ConditionVariable;
struct Queue;
struct SizedQueue;
struct Process;
struct Process_Status;
struct Binding;
struct PP;
struct StringIO;
struct Struct;
struct Data;
struct Set;
struct Random;
struct ObjectSpace_WeakMap;
struct ObjectSpace_WeakKeyMap;
struct ENVClass;
struct Gem_Specification;
struct Marshal_Dumper;
struct Marshal_Loader;
struct Frozone_Vm_Vm;
struct Frozone_Vm_Parser;
struct Frozone_Vm_WqParser;
struct BasicObject_eigenclass;
struct Object_eigenclass;
struct Class_eigenclass;
struct NilClass_eigenclass;
struct TrueClass_eigenclass;
struct FalseClass_eigenclass;
struct Integer_eigenclass;
struct Float_eigenclass;
struct Array_eigenclass;
struct Symbol_eigenclass;
struct String_eigenclass;
struct Hash_eigenclass;
struct Proc_eigenclass;
struct BasicObject_BasicObject_eigenclass;
struct Module_eigenclass;
struct Numeric_eigenclass;
struct Refinement_eigenclass;
struct Method_eigenclass;
struct UnboundMethod_eigenclass;
struct Range_eigenclass;
struct Enumerator_eigenclass;
struct Enumerator_Yielder_eigenclass;
struct Enumerator_Generator_eigenclass;
struct Enumerator_Lazy_eigenclass;
struct Enumerator_Chain_eigenclass;
struct Enumerator_ArithmeticSequence_eigenclass;
struct Enumerator_Product_eigenclass;
struct Exception_eigenclass;
struct ScriptError_eigenclass;
struct LoadError_eigenclass;
struct SyntaxError_eigenclass;
struct NotImplementedError_eigenclass;
struct SignalException_eigenclass;
struct Interrupt_eigenclass;
struct SystemExit_eigenclass;
struct StandardError_eigenclass;
struct RuntimeError_eigenclass;
struct FrozenError_eigenclass;
struct NameError_eigenclass;
struct NoMethodError_eigenclass;
struct TypeError_eigenclass;
struct ArgumentError_eigenclass;
struct RangeError_eigenclass;
struct FloatDomainError_eigenclass;
struct ZeroDivisionError_eigenclass;
struct IndexError_eigenclass;
struct FiberError_eigenclass;
struct ThreadError_eigenclass;
struct NoMemoryError_eigenclass;
struct SecurityError_eigenclass;
struct SystemStackError_eigenclass;
struct NoMatchingPatternError_eigenclass;
struct KeyError_eigenclass;
struct StopIteration_eigenclass;
struct ClosedQueueError_eigenclass;
struct UncaughtThrowError_eigenclass;
struct LocalJumpError_eigenclass;
struct SystemCallError_eigenclass;
struct IOError_eigenclass;
struct EOFError_eigenclass;
struct EncodingError_eigenclass;
struct RegexpError_eigenclass;
struct Errno_E2BIG_eigenclass;
struct Errno_EACCES_eigenclass;
struct Errno_EADDRINUSE_eigenclass;
struct Errno_EADDRNOTAVAIL_eigenclass;
struct Errno_EAFNOSUPPORT_eigenclass;
struct Errno_EAGAIN_eigenclass;
struct Errno_EALREADY_eigenclass;
struct Errno_EBADF_eigenclass;
struct Errno_EBUSY_eigenclass;
struct Errno_ECHILD_eigenclass;
struct Errno_EILSEQ_eigenclass;
struct Errno_ECONNABORTED_eigenclass;
struct Errno_ECONNREFUSED_eigenclass;
struct Errno_ECONNRESET_eigenclass;
struct Errno_EDEADLK_eigenclass;
struct Errno_EDOM_eigenclass;
struct Errno_EEXIST_eigenclass;
struct Errno_EFAULT_eigenclass;
struct Errno_EFBIG_eigenclass;
struct Errno_EHOSTUNREACH_eigenclass;
struct Errno_EINPROGRESS_eigenclass;
struct Errno_EINTR_eigenclass;
struct Errno_EINVAL_eigenclass;
struct Errno_EIO_eigenclass;
struct Errno_EISCONN_eigenclass;
struct Errno_EISDIR_eigenclass;
struct Errno_ELOOP_eigenclass;
struct Errno_EMFILE_eigenclass;
struct Errno_EMSGSIZE_eigenclass;
struct Errno_ENAMETOOLONG_eigenclass;
struct Errno_ENETDOWN_eigenclass;
struct Errno_ENETUNREACH_eigenclass;
struct Errno_ENFILE_eigenclass;
struct Errno_ENODEV_eigenclass;
struct Errno_ENOENT_eigenclass;
struct Errno_ENOEXEC_eigenclass;
struct Errno_ENOMEM_eigenclass;
struct Errno_ENOSPC_eigenclass;
struct Errno_ENOSYS_eigenclass;
struct Errno_ENOTCONN_eigenclass;
struct Errno_ENOTDIR_eigenclass;
struct Errno_ENOTEMPTY_eigenclass;
struct Errno_ENOTSUP_eigenclass;
struct Errno_ENOTTY_eigenclass;
struct Errno_ENXIO_eigenclass;
struct Errno_EOPNOTSUPP_eigenclass;
struct Errno_EOVERFLOW_eigenclass;
struct Errno_EPERM_eigenclass;
struct Errno_EPIPE_eigenclass;
struct Errno_EPROTONOSUPPORT_eigenclass;
struct Errno_ERANGE_eigenclass;
struct Errno_EROFS_eigenclass;
struct Errno_ESPIPE_eigenclass;
struct Errno_ESRCH_eigenclass;
struct Errno_ETIMEDOUT_eigenclass;
struct Errno_ETXTBSY_eigenclass;
struct Errno_EWOULDBLOCK_eigenclass;
struct Errno_EXDEV_eigenclass;
struct Math_DomainError_eigenclass;
struct Encoding_eigenclass;
struct Encoding_CompatibilityError_eigenclass;
struct Encoding_ConverterNotFoundError_eigenclass;
struct Encoding_InvalidByteSequenceError_eigenclass;
struct Encoding_UndefinedConversionError_eigenclass;
struct Encoding_Converter_eigenclass;
struct MatchData_eigenclass;
struct Regexp_eigenclass;
struct Regexp_TimeoutError_eigenclass;
struct Rational_eigenclass;
struct Complex_eigenclass;
struct IO_eigenclass;
struct IO_CapturedOutput_eigenclass;
struct IO_EAGAINWaitReadable_eigenclass;
struct IO_EAGAINWaitWritable_eigenclass;
struct IO_EWOULDBLOCKWaitReadable_eigenclass;
struct IO_EWOULDBLOCKWaitWritable_eigenclass;
struct File_eigenclass;
struct File_Stat_eigenclass;
struct Dir_eigenclass;
struct Time_eigenclass;
struct Mutex_eigenclass;
struct Fiber_eigenclass;
struct ThreadKill_eigenclass;
struct Thread_eigenclass;
struct Thread_Blocked_eigenclass;
struct Thread_Mutex_eigenclass;
struct Thread_Backtrace_eigenclass;
struct Thread_Backtrace_Location_eigenclass;
struct ThreadGroup_eigenclass;
struct ConditionVariable_eigenclass;
struct Queue_eigenclass;
struct SizedQueue_eigenclass;
struct Process_eigenclass;
struct Process_Status_eigenclass;
struct Binding_eigenclass;
struct PP_eigenclass;
struct StringIO_eigenclass;
struct Struct_eigenclass;
struct Data_eigenclass;
struct Set_eigenclass;
struct Random_eigenclass;
struct ObjectSpace_WeakMap_eigenclass;
struct ObjectSpace_WeakKeyMap_eigenclass;
struct ENVClass_eigenclass;
struct Gem_Specification_eigenclass;
struct Marshal_Dumper_eigenclass;
struct Marshal_Loader_eigenclass;
struct Frozone_Vm_Vm_eigenclass;
struct Frozone_Vm_Parser_eigenclass;
struct Frozone_Vm_WqParser_eigenclass;

extern NilClass NIL_INSTANCE;
extern TrueClass TRUE_INSTANCE;
extern FalseClass FALSE_INSTANCE;
extern BasicObject_eigenclass BasicObject_CLASS;
extern Object_eigenclass Object_CLASS;
extern Class_eigenclass Class_CLASS;
extern NilClass_eigenclass NilClass_CLASS;
extern TrueClass_eigenclass TrueClass_CLASS;
extern FalseClass_eigenclass FalseClass_CLASS;
extern Integer_eigenclass Integer_CLASS;
extern Float_eigenclass Float_CLASS;
extern Array_eigenclass Array_CLASS;
extern Symbol_eigenclass Symbol_CLASS;
extern String_eigenclass String_CLASS;
extern Hash_eigenclass Hash_CLASS;
extern Proc_eigenclass Proc_CLASS;
extern BasicObject_BasicObject_eigenclass BasicObject_BasicObject_CLASS;
extern Module_eigenclass Module_CLASS;
extern Numeric_eigenclass Numeric_CLASS;
extern Refinement_eigenclass Refinement_CLASS;
extern Method_eigenclass Method_CLASS;
extern UnboundMethod_eigenclass UnboundMethod_CLASS;
extern Range_eigenclass Range_CLASS;
extern Enumerator_eigenclass Enumerator_CLASS;
extern Enumerator_Yielder_eigenclass Enumerator_Yielder_CLASS;
extern Enumerator_Generator_eigenclass Enumerator_Generator_CLASS;
extern Enumerator_Lazy_eigenclass Enumerator_Lazy_CLASS;
extern Enumerator_Chain_eigenclass Enumerator_Chain_CLASS;
extern Enumerator_ArithmeticSequence_eigenclass Enumerator_ArithmeticSequence_CLASS;
extern Enumerator_Product_eigenclass Enumerator_Product_CLASS;
extern Exception_eigenclass Exception_CLASS;
extern ScriptError_eigenclass ScriptError_CLASS;
extern LoadError_eigenclass LoadError_CLASS;
extern SyntaxError_eigenclass SyntaxError_CLASS;
extern NotImplementedError_eigenclass NotImplementedError_CLASS;
extern SignalException_eigenclass SignalException_CLASS;
extern Interrupt_eigenclass Interrupt_CLASS;
extern SystemExit_eigenclass SystemExit_CLASS;
extern StandardError_eigenclass StandardError_CLASS;
extern RuntimeError_eigenclass RuntimeError_CLASS;
extern FrozenError_eigenclass FrozenError_CLASS;
extern NameError_eigenclass NameError_CLASS;
extern NoMethodError_eigenclass NoMethodError_CLASS;
extern TypeError_eigenclass TypeError_CLASS;
extern ArgumentError_eigenclass ArgumentError_CLASS;
extern RangeError_eigenclass RangeError_CLASS;
extern FloatDomainError_eigenclass FloatDomainError_CLASS;
extern ZeroDivisionError_eigenclass ZeroDivisionError_CLASS;
extern IndexError_eigenclass IndexError_CLASS;
extern FiberError_eigenclass FiberError_CLASS;
extern ThreadError_eigenclass ThreadError_CLASS;
extern NoMemoryError_eigenclass NoMemoryError_CLASS;
extern SecurityError_eigenclass SecurityError_CLASS;
extern SystemStackError_eigenclass SystemStackError_CLASS;
extern NoMatchingPatternError_eigenclass NoMatchingPatternError_CLASS;
extern KeyError_eigenclass KeyError_CLASS;
extern StopIteration_eigenclass StopIteration_CLASS;
extern ClosedQueueError_eigenclass ClosedQueueError_CLASS;
extern UncaughtThrowError_eigenclass UncaughtThrowError_CLASS;
extern LocalJumpError_eigenclass LocalJumpError_CLASS;
extern SystemCallError_eigenclass SystemCallError_CLASS;
extern IOError_eigenclass IOError_CLASS;
extern EOFError_eigenclass EOFError_CLASS;
extern EncodingError_eigenclass EncodingError_CLASS;
extern RegexpError_eigenclass RegexpError_CLASS;
extern Errno_E2BIG_eigenclass Errno_E2BIG_CLASS;
extern Errno_EACCES_eigenclass Errno_EACCES_CLASS;
extern Errno_EADDRINUSE_eigenclass Errno_EADDRINUSE_CLASS;
extern Errno_EADDRNOTAVAIL_eigenclass Errno_EADDRNOTAVAIL_CLASS;
extern Errno_EAFNOSUPPORT_eigenclass Errno_EAFNOSUPPORT_CLASS;
extern Errno_EAGAIN_eigenclass Errno_EAGAIN_CLASS;
extern Errno_EALREADY_eigenclass Errno_EALREADY_CLASS;
extern Errno_EBADF_eigenclass Errno_EBADF_CLASS;
extern Errno_EBUSY_eigenclass Errno_EBUSY_CLASS;
extern Errno_ECHILD_eigenclass Errno_ECHILD_CLASS;
extern Errno_EILSEQ_eigenclass Errno_EILSEQ_CLASS;
extern Errno_ECONNABORTED_eigenclass Errno_ECONNABORTED_CLASS;
extern Errno_ECONNREFUSED_eigenclass Errno_ECONNREFUSED_CLASS;
extern Errno_ECONNRESET_eigenclass Errno_ECONNRESET_CLASS;
extern Errno_EDEADLK_eigenclass Errno_EDEADLK_CLASS;
extern Errno_EDOM_eigenclass Errno_EDOM_CLASS;
extern Errno_EEXIST_eigenclass Errno_EEXIST_CLASS;
extern Errno_EFAULT_eigenclass Errno_EFAULT_CLASS;
extern Errno_EFBIG_eigenclass Errno_EFBIG_CLASS;
extern Errno_EHOSTUNREACH_eigenclass Errno_EHOSTUNREACH_CLASS;
extern Errno_EINPROGRESS_eigenclass Errno_EINPROGRESS_CLASS;
extern Errno_EINTR_eigenclass Errno_EINTR_CLASS;
extern Errno_EINVAL_eigenclass Errno_EINVAL_CLASS;
extern Errno_EIO_eigenclass Errno_EIO_CLASS;
extern Errno_EISCONN_eigenclass Errno_EISCONN_CLASS;
extern Errno_EISDIR_eigenclass Errno_EISDIR_CLASS;
extern Errno_ELOOP_eigenclass Errno_ELOOP_CLASS;
extern Errno_EMFILE_eigenclass Errno_EMFILE_CLASS;
extern Errno_EMSGSIZE_eigenclass Errno_EMSGSIZE_CLASS;
extern Errno_ENAMETOOLONG_eigenclass Errno_ENAMETOOLONG_CLASS;
extern Errno_ENETDOWN_eigenclass Errno_ENETDOWN_CLASS;
extern Errno_ENETUNREACH_eigenclass Errno_ENETUNREACH_CLASS;
extern Errno_ENFILE_eigenclass Errno_ENFILE_CLASS;
extern Errno_ENODEV_eigenclass Errno_ENODEV_CLASS;
extern Errno_ENOENT_eigenclass Errno_ENOENT_CLASS;
extern Errno_ENOEXEC_eigenclass Errno_ENOEXEC_CLASS;
extern Errno_ENOMEM_eigenclass Errno_ENOMEM_CLASS;
extern Errno_ENOSPC_eigenclass Errno_ENOSPC_CLASS;
extern Errno_ENOSYS_eigenclass Errno_ENOSYS_CLASS;
extern Errno_ENOTCONN_eigenclass Errno_ENOTCONN_CLASS;
extern Errno_ENOTDIR_eigenclass Errno_ENOTDIR_CLASS;
extern Errno_ENOTEMPTY_eigenclass Errno_ENOTEMPTY_CLASS;
extern Errno_ENOTSUP_eigenclass Errno_ENOTSUP_CLASS;
extern Errno_ENOTTY_eigenclass Errno_ENOTTY_CLASS;
extern Errno_ENXIO_eigenclass Errno_ENXIO_CLASS;
extern Errno_EOPNOTSUPP_eigenclass Errno_EOPNOTSUPP_CLASS;
extern Errno_EOVERFLOW_eigenclass Errno_EOVERFLOW_CLASS;
extern Errno_EPERM_eigenclass Errno_EPERM_CLASS;
extern Errno_EPIPE_eigenclass Errno_EPIPE_CLASS;
extern Errno_EPROTONOSUPPORT_eigenclass Errno_EPROTONOSUPPORT_CLASS;
extern Errno_ERANGE_eigenclass Errno_ERANGE_CLASS;
extern Errno_EROFS_eigenclass Errno_EROFS_CLASS;
extern Errno_ESPIPE_eigenclass Errno_ESPIPE_CLASS;
extern Errno_ESRCH_eigenclass Errno_ESRCH_CLASS;
extern Errno_ETIMEDOUT_eigenclass Errno_ETIMEDOUT_CLASS;
extern Errno_ETXTBSY_eigenclass Errno_ETXTBSY_CLASS;
extern Errno_EWOULDBLOCK_eigenclass Errno_EWOULDBLOCK_CLASS;
extern Errno_EXDEV_eigenclass Errno_EXDEV_CLASS;
extern Math_DomainError_eigenclass Math_DomainError_CLASS;
extern Encoding_eigenclass Encoding_CLASS;
extern Encoding_CompatibilityError_eigenclass Encoding_CompatibilityError_CLASS;
extern Encoding_ConverterNotFoundError_eigenclass Encoding_ConverterNotFoundError_CLASS;
extern Encoding_InvalidByteSequenceError_eigenclass Encoding_InvalidByteSequenceError_CLASS;
extern Encoding_UndefinedConversionError_eigenclass Encoding_UndefinedConversionError_CLASS;
extern Encoding_Converter_eigenclass Encoding_Converter_CLASS;
extern MatchData_eigenclass MatchData_CLASS;
extern Regexp_eigenclass Regexp_CLASS;
extern Regexp_TimeoutError_eigenclass Regexp_TimeoutError_CLASS;
extern Rational_eigenclass Rational_CLASS;
extern Complex_eigenclass Complex_CLASS;
extern IO_eigenclass IO_CLASS;
extern IO_CapturedOutput_eigenclass IO_CapturedOutput_CLASS;
extern IO_EAGAINWaitReadable_eigenclass IO_EAGAINWaitReadable_CLASS;
extern IO_EAGAINWaitWritable_eigenclass IO_EAGAINWaitWritable_CLASS;
extern IO_EWOULDBLOCKWaitReadable_eigenclass IO_EWOULDBLOCKWaitReadable_CLASS;
extern IO_EWOULDBLOCKWaitWritable_eigenclass IO_EWOULDBLOCKWaitWritable_CLASS;
extern File_eigenclass File_CLASS;
extern File_Stat_eigenclass File_Stat_CLASS;
extern Dir_eigenclass Dir_CLASS;
extern Time_eigenclass Time_CLASS;
extern Mutex_eigenclass Mutex_CLASS;
extern Fiber_eigenclass Fiber_CLASS;
extern ThreadKill_eigenclass ThreadKill_CLASS;
extern Thread_eigenclass Thread_CLASS;
extern Thread_Blocked_eigenclass Thread_Blocked_CLASS;
extern Thread_Mutex_eigenclass Thread_Mutex_CLASS;
extern Thread_Backtrace_eigenclass Thread_Backtrace_CLASS;
extern Thread_Backtrace_Location_eigenclass Thread_Backtrace_Location_CLASS;
extern ThreadGroup_eigenclass ThreadGroup_CLASS;
extern ConditionVariable_eigenclass ConditionVariable_CLASS;
extern Queue_eigenclass Queue_CLASS;
extern SizedQueue_eigenclass SizedQueue_CLASS;
extern Process_eigenclass Process_CLASS;
extern Process_Status_eigenclass Process_Status_CLASS;
extern Binding_eigenclass Binding_CLASS;
extern PP_eigenclass PP_CLASS;
extern StringIO_eigenclass StringIO_CLASS;
extern Struct_eigenclass Struct_CLASS;
extern Data_eigenclass Data_CLASS;
extern Set_eigenclass Set_CLASS;
extern Random_eigenclass Random_CLASS;
extern ObjectSpace_WeakMap_eigenclass ObjectSpace_WeakMap_CLASS;
extern ObjectSpace_WeakKeyMap_eigenclass ObjectSpace_WeakKeyMap_CLASS;
extern ENVClass_eigenclass ENVClass_CLASS;
extern Gem_Specification_eigenclass Gem_Specification_CLASS;
extern Marshal_Dumper_eigenclass Marshal_Dumper_CLASS;
extern Marshal_Loader_eigenclass Marshal_Loader_CLASS;
extern Frozone_Vm_Vm_eigenclass Frozone_Vm_Vm_CLASS;
extern Frozone_Vm_Parser_eigenclass Frozone_Vm_Parser_CLASS;
extern Frozone_Vm_WqParser_eigenclass Frozone_Vm_WqParser_CLASS;

inline BasicObject* nil_instance();
inline BasicObject* true_instance();
inline BasicObject* false_instance();
inline BasicObject* boxed_bool(bool b);
inline bool truthy(BasicObject* o);
inline void ruby_puts(BasicObject* o);
inline Symbol* intern(const char* name);
inline BasicObject* array_at(Array* a, std::size_t i);
inline BasicObject* k_STDOUT();
inline BasicObject* k_STDERR();
inline BasicObject* k_STDIN();
inline BasicObject* k_ENV();
inline BasicObject* k_ARGF();

struct BasicObject {
  // All box-first allocations route through Boehm. Without
  // this, plain `new X(...)` uses libc malloc and Boehm never
  // collects — instant OOM on any allocation-heavy benchmark.
  static void* operator new(std::size_t n) { return GC_MALLOC(n); }
  static void operator delete(void*) {}  // Boehm collects
  
  virtual ~BasicObject() = default;
  virtual const char* ruby_class_name() const { return "BasicObject"; }
  // method_missing — base aborts; subclasses can override.
  virtual BasicObject* method_missing(const char* method_name) {
    std::fprintf(stderr, "[box-first] method_missing: %s#%s\n", ruby_class_name(), method_name);
    std::abort();
  }
  // Hand-coded m_eq_q / m_hash_value / m_case_eq — these need
  // sensible defaults rather than method_missing. m_hash_value
  // is C++-internal (returns size_t for std::unordered_map),
  // not a Ruby vtable method. m_eq_q and m_case_eq use the
  // universal Ruby method signature (Array*, Hash*, Proc*).
  virtual BasicObject* m_eq_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {
    return boxed_bool(this == array_at(args, 0));
  }
  virtual std::size_t m_hash_value() const { return reinterpret_cast<std::size_t>(this); }
  // m_case_eq (===) defaults to m_eq_q per Ruby semantics.
  virtual BasicObject* m_case_eq(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {
    return m_eq_q(args, kwargs, block);
  }
  // nil? defaults to false; NilClass overrides to true.
  virtual BasicObject* m_nil_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {
    return false_instance();
  }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> BasicObject(__Ts__...) {}
  // Universal method surface — one slot per name. All Ruby methods take
  // (Array* args, Hash* kwargs, Proc* block) — bodies unpack from args.
  virtual BasicObject* m_equal_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("equal?"); }
  virtual BasicObject* m_not(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("!"); }
  virtual BasicObject* m_empty_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("empty?"); }
  virtual BasicObject* m_raise(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("raise"); }
  virtual BasicObject* m_size(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("size"); }
  virtual BasicObject* m_gt(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing(">"); }
  virtual BasicObject* m_aref(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("[]"); }
  virtual BasicObject* m_is_a_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("is_a?"); }
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_s"); }
  virtual BasicObject* m_select(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("select"); }
  virtual BasicObject* m_drop(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("drop"); }
  virtual BasicObject* m_ancestors(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("ancestors"); }
  virtual BasicObject* m_values(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("values"); }
  virtual BasicObject* m_ge(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing(">="); }
  virtual BasicObject* m_last(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("last"); }
  virtual BasicObject* m_warn(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("warn"); }
  virtual BasicObject* m_first(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("first"); }
  virtual BasicObject* m_caller(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("caller"); }
  virtual BasicObject* m___coerce_to_str__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__coerce_to_str__"); }
  virtual BasicObject* m_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("name"); }
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("inspect"); }
  virtual BasicObject* m_singleton_class_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("singleton_class?"); }
  virtual BasicObject* m_class(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("class"); }
  virtual BasicObject* m___id__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__id__"); }
  virtual BasicObject* m_include_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("include?"); }
  virtual BasicObject* m_ne_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("!="); }
  virtual BasicObject* m_instance_variable_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("instance_variable_set"); }
  virtual BasicObject* m_object_id(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("object_id"); }
  virtual BasicObject* m_aset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("[]="); }
  virtual BasicObject* m_constants(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("constants"); }
  virtual BasicObject* m_lt(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("<"); }
  virtual BasicObject* m_mul(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("*"); }
  virtual BasicObject* m_minus(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("-"); }
  virtual BasicObject* m_abs(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("abs"); }
  virtual BasicObject* m_arg(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("arg"); }
  virtual BasicObject* m_to_i(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_i"); }
  virtual BasicObject* m_Complex(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("Complex"); }
  virtual BasicObject* m_zero_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("zero?"); }
  virtual BasicObject* m_neg(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("-@"); }
  virtual BasicObject* m_instance_of_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("instance_of?"); }
  virtual BasicObject* m_ceil(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("ceil"); }
  virtual BasicObject* m_to_f(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_f"); }
  virtual BasicObject* m_floor(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("floor"); }
  virtual BasicObject* m_truncate(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("truncate"); }
  virtual BasicObject* m_div(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("div"); }
  virtual BasicObject* m_modulo(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("modulo"); }
  virtual BasicObject* m_numerator(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("numerator"); }
  virtual BasicObject* m_to_r(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_r"); }
  virtual BasicObject* m_denominator(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("denominator"); }
  virtual BasicObject* m_round(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("round"); }
  virtual BasicObject* m_respond_to_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("respond_to?"); }
  virtual BasicObject* m_coerce(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("coerce"); }
  virtual BasicObject* m_mod(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("%"); }
  virtual BasicObject* m_Float(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("Float"); }
  virtual BasicObject* m_to_enum(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_enum"); }
  virtual BasicObject* m_compact(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("compact"); }
  virtual BasicObject* m_proc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("proc"); }
  virtual BasicObject* m___step_size__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__step_size__"); }
  virtual BasicObject* m_lshift(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("<<"); }
  virtual BasicObject* m__from_method(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_from_method"); }
  virtual BasicObject* m_call(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("call"); }
  virtual BasicObject* m___step_each__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__step_each__"); }
  virtual BasicObject* m_infinite_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("infinite?"); }
  virtual BasicObject* m_nan_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("nan?"); }
  virtual BasicObject* m_plus(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("+"); }
  virtual BasicObject* m_le(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("<="); }
  virtual BasicObject* m_loop(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("loop"); }
  virtual BasicObject* m_times(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("times"); }
  virtual BasicObject* m_each(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("each"); }
  virtual BasicObject* m_warn_ancestors(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("warn_ancestors"); }
  virtual BasicObject* m_instance_methods(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("instance_methods"); }
  virtual BasicObject* m_instance_method(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("instance_method"); }
  virtual BasicObject* m_curry(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("curry"); }
  virtual BasicObject* m_to_proc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_proc"); }
  virtual BasicObject* m_frozen_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("frozen?"); }
  virtual BasicObject* m_lambda_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("lambda?"); }
  virtual BasicObject* m_receiver(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("receiver"); }
  virtual BasicObject* m_owner(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("owner"); }
  virtual BasicObject* m___param_sig__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__param_sig__"); }
  virtual BasicObject* m_source_location(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("source_location"); }
  virtual BasicObject* m_singleton_class(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("singleton_class"); }
  virtual BasicObject* m_sub(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sub"); }
  virtual BasicObject* m_parameters(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("parameters"); }
  virtual BasicObject* m_join(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("join"); }
  virtual BasicObject* m_bind(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("bind"); }
  virtual BasicObject* m_dup(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("dup"); }
  virtual BasicObject* m_freeze(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("freeze"); }
  virtual BasicObject* m_spaceship(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("<=>"); }
  virtual BasicObject* m_sort(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sort"); }
  virtual BasicObject* m_to_a(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_a"); }
  virtual BasicObject* m_hash(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("hash"); }
  virtual BasicObject* m_begin(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("begin"); }
  virtual BasicObject* m_end(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("end"); }
  virtual BasicObject* m_exclude_end_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("exclude_end?"); }
  virtual BasicObject* m_inject(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("inject"); }
  virtual BasicObject* m_flatten(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("flatten"); }
  virtual BasicObject* m_map(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("map"); }
  virtual BasicObject* m_sort_by(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sort_by"); }
  virtual BasicObject* m_min_by(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("min_by"); }
  virtual BasicObject* m_max_by(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("max_by"); }
  virtual BasicObject* m_length(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("length"); }
  virtual BasicObject* m_encoding(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("encoding"); }
  virtual BasicObject* m_ord(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("ord"); }
  virtual BasicObject* m_to_sym(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_sym"); }
  virtual BasicObject* m_chr(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("chr"); }
  virtual BasicObject* m_succ(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("succ"); }
  virtual BasicObject* m___cover_value___q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__cover_value__?"); }
  virtual BasicObject* m_cover_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("cover?"); }
  virtual BasicObject* m_min(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("min"); }
  virtual BasicObject* m_max(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("max"); }
  virtual BasicObject* m_add(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("add"); }
  virtual BasicObject* m_eql_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("eql?"); }
  virtual BasicObject* m_send(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("send"); }
  virtual BasicObject* m___step_float__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__step_float__"); }
  virtual BasicObject* m___step_integer__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__step_integer__"); }
  virtual BasicObject* m___step_succ__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__step_succ__"); }
  virtual BasicObject* m___step_plus__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__step_plus__"); }
  virtual BasicObject* m_count(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("count"); }
  virtual BasicObject* m___coerce_to_int__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__coerce_to_int__"); }
  virtual BasicObject* m_step(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("step"); }
  virtual BasicObject* m___bsearch_size__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__bsearch_size__"); }
  virtual BasicObject* m___bsearch_integer__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__bsearch_integer__"); }
  virtual BasicObject* m___bsearch_float__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__bsearch_float__"); }
  virtual BasicObject* m_block_given_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("block_given?"); }
  virtual BasicObject* m_shift(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("shift"); }
  virtual BasicObject* m_each_with_index(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("each_with_index"); }
  virtual BasicObject* m___reverse_each_size__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__reverse_each_size__"); }
  virtual BasicObject* m_reverse_each(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("reverse_each"); }
  virtual BasicObject* m_split(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("split"); }
  virtual BasicObject* m_then(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("then"); }
  virtual BasicObject* m_unpack1(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("unpack1"); }
  virtual BasicObject* m_pack(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pack"); }
  virtual BasicObject* m_bit_and(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("&"); }
  virtual BasicObject* m_bit_not(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("~"); }
  virtual BasicObject* m_bit_or(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("|"); }
  virtual BasicObject* m_bit_xor(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("^"); }
  virtual BasicObject* m___step_float_unbounded__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__step_float_unbounded__"); }
  virtual BasicObject* m___step_float_positive__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__step_float_positive__"); }
  virtual BasicObject* m___step_float_negative__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__step_float_negative__"); }
  virtual BasicObject* m_pow(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("**"); }
  virtual BasicObject* m___bsearch_validate__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__bsearch_validate__"); }
  virtual BasicObject* m___bsearch_int_any__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__bsearch_int_any__"); }
  virtual BasicObject* m___bsearch_int_min__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__bsearch_int_min__"); }
  virtual BasicObject* m___float_to_ord__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__float_to_ord__"); }
  virtual BasicObject* m___ord_to_float__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__ord_to_float__"); }
  virtual BasicObject* m_allocate(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("allocate"); }
  virtual BasicObject* m___send__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__send__"); }
  virtual BasicObject* m___next_values_raw__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__next_values_raw__"); }
  virtual BasicObject* m___peek_values_raw__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__peek_values_raw__"); }
  virtual BasicObject* m_each_with_object(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("each_with_object"); }
  virtual BasicObject* m_merge(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("merge"); }
  virtual BasicObject* m___advance__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__advance__"); }
  virtual BasicObject* m_result(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("result"); }
  virtual BasicObject* m_rewind(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("rewind"); }
  virtual BasicObject* m_next(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("next"); }
  virtual BasicObject* m_peek(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("peek"); }
  virtual BasicObject* m___check_frozen__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__check_frozen__"); }
  virtual BasicObject* m_yield(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("yield"); }
  virtual BasicObject* m___ensure_fiber__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__ensure_fiber__"); }
  virtual BasicObject* m_alive_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("alive?"); }
  virtual BasicObject* m_resume(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("resume"); }
  virtual BasicObject* m_keys(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("keys"); }
  virtual BasicObject* m__lazy_eval(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_lazy_eval"); }
  virtual BasicObject* m_take(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("take"); }
  virtual BasicObject* m_key_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("key?"); }
  virtual BasicObject* m_force(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("force"); }
  virtual BasicObject* m_define_singleton_method(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("define_singleton_method"); }
  virtual BasicObject* m_chunk(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("chunk"); }
  virtual BasicObject* m___product_each__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__product_each__"); }
  virtual BasicObject* m_delete(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("delete"); }
  virtual BasicObject* m_reduce(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("reduce"); }
  virtual BasicObject* m_instance_variable_get(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("instance_variable_get"); }
  virtual BasicObject* m_each_entry(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("each_entry"); }
  virtual BasicObject* m_push(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("push"); }
  virtual BasicObject* m_pop(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pop"); }
  virtual BasicObject* m__from_string(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_from_string"); }
  virtual BasicObject* m_message(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("message"); }
  virtual BasicObject* m_backtrace(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("backtrace"); }
  virtual BasicObject* m_to_tty_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_tty?"); }
  virtual BasicObject* m___full_message_dm__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__full_message_dm__"); }
  virtual BasicObject* m_to_str(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_str"); }
  virtual BasicObject* m___format_single_full_message__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__format_single_full_message__"); }
  virtual BasicObject* m_cause(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("cause"); }
  virtual BasicObject* m_detailed_message(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("detailed_message"); }
  virtual BasicObject* m_find(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("find"); }
  virtual BasicObject* m_list(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("list"); }
  virtual BasicObject* m_upcase(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("upcase"); }
  virtual BasicObject* m_start_with_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("start_with?"); }
  virtual BasicObject* m_instance_variable_defined_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("instance_variable_defined?"); }
  virtual BasicObject* m_Integer(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("Integer"); }
  virtual BasicObject* m__by_errno(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_by_errno"); }
  virtual BasicObject* m_dummy_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("dummy?"); }
  virtual BasicObject* m_aliases(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("aliases"); }
  virtual BasicObject* m_downcase(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("downcase"); }
  virtual BasicObject* m_default_external(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("default_external"); }
  virtual BasicObject* m_default_internal(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("default_internal"); }
  virtual BasicObject* m___build_find_map__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__build_find_map__"); }
  virtual BasicObject* m_locale_charmap(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("locale_charmap"); }
  virtual BasicObject* m_bytebegin(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("bytebegin"); }
  virtual BasicObject* m_byteend(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("byteend"); }
  virtual BasicObject* m_string(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("string"); }
  virtual BasicObject* m_regexp(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("regexp"); }
  virtual BasicObject* m_captures(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("captures"); }
  virtual BasicObject* m_transform_keys(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("transform_keys"); }
  virtual BasicObject* m_flat_map(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("flat_map"); }
  virtual BasicObject* m_to_int(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_int"); }
  virtual BasicObject* m_named_captures(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("named_captures"); }
  virtual BasicObject* m_source(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("source"); }
  virtual BasicObject* m_options(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("options"); }
  virtual BasicObject* m_match(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("match"); }
  virtual BasicObject* m_to_regexp(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_regexp"); }
  virtual BasicObject* m_gcd(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("gcd"); }
  virtual BasicObject* m_Rational(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("Rational"); }
  virtual BasicObject* m___coerce_op__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__coerce_op__"); }
  virtual BasicObject* m_negative_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("negative?"); }
  virtual BasicObject* m_bit_length(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("bit_length"); }
  virtual BasicObject* m_rshift(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing(">>"); }
  virtual BasicObject* m_divmod(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("divmod"); }
  virtual BasicObject* m_even_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("even?"); }
  virtual BasicObject* m___simplest_rational__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__simplest_rational__"); }
  virtual BasicObject* m_sqrt(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sqrt"); }
  virtual BasicObject* m_abs2(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("abs2"); }
  virtual BasicObject* m_atan2(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("atan2"); }
  virtual BasicObject* m_angle(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("angle"); }
  virtual BasicObject* m___complex_coerce_op__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__complex_coerce_op__"); }
  virtual BasicObject* m_real(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("real"); }
  virtual BasicObject* m_imaginary(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("imaginary"); }
  virtual BasicObject* m_quo(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("quo"); }
  virtual BasicObject* m_real_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("real?"); }
  virtual BasicObject* m___coerce_binop__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__coerce_binop__"); }
  virtual BasicObject* m_tap(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("tap"); }
  virtual BasicObject* m_cos(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("cos"); }
  virtual BasicObject* m_sin(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sin"); }
  virtual BasicObject* m_log(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("log"); }
  virtual BasicObject* m_exp(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("exp"); }
  virtual BasicObject* m_lcm(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("lcm"); }
  virtual BasicObject* m___ensure_real_strict__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__ensure_real_strict__"); }
  virtual BasicObject* m_rationalize(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("rationalize"); }
  virtual BasicObject* m_finite_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("finite?"); }
  virtual BasicObject* m_fdiv(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("fdiv"); }
  virtual BasicObject* m___format_imag__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__format_imag__"); }
  virtual BasicObject* m__real_check(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_real_check"); }
  virtual BasicObject* m_write(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write"); }
  virtual BasicObject* m___puts_array__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__puts_array__"); }
  virtual BasicObject* m_to_ary(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_ary"); }
  virtual BasicObject* m___puts_scalar__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__puts_scalar__"); }
  virtual BasicObject* m_end_with_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("end_with?"); }
  virtual BasicObject* m_eof_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("eof?"); }
  virtual BasicObject* m_isatty(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("isatty"); }
  virtual BasicObject* m_pos(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pos"); }
  virtual BasicObject* m_closed_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("closed?"); }
  virtual BasicObject* m_chomp(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("chomp"); }
  virtual BasicObject* m_gets(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("gets"); }
  virtual BasicObject* m___parse_sep_limit__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__parse_sep_limit__"); }
  virtual BasicObject* m_external_encoding(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("external_encoding"); }
  virtual BasicObject* m_each_line(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("each_line"); }
  virtual BasicObject* m_path(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("path"); }
  virtual BasicObject* m_stat(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("stat"); }
  virtual BasicObject* m_sprintf(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sprintf"); }
  virtual BasicObject* m_fetch(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("fetch"); }
  virtual BasicObject* m_each_char(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("each_char"); }
  virtual BasicObject* m_each_byte(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("each_byte"); }
  virtual BasicObject* m_each_codepoint(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("each_codepoint"); }
  virtual BasicObject* m_to_io(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_io"); }
  virtual BasicObject* m_to_path(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_path"); }
  virtual BasicObject* m_binmode_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("binmode?"); }
  virtual BasicObject* m_internal_encoding(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("internal_encoding"); }
  virtual BasicObject* m_read(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read"); }
  virtual BasicObject* m_bytes(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("bytes"); }
  virtual BasicObject* m_seek(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("seek"); }
  virtual BasicObject* m_set_encoding(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("set_encoding"); }
  virtual BasicObject* m___coerce_to_path__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__coerce_to_path__"); }
  virtual BasicObject* m_fileno(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("fileno"); }
  virtual BasicObject* m_close(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("close"); }
  virtual BasicObject* m_sysopen(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sysopen"); }
  virtual BasicObject* m___coerce_path__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__coerce_path__"); }
  virtual BasicObject* m_open(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("open"); }
  virtual BasicObject* m_readlines(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("readlines"); }
  virtual BasicObject* m_chmod(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("chmod"); }
  virtual BasicObject* m_bytesize(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("bytesize"); }
  virtual BasicObject* m__coerce_path(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_coerce_path"); }
  virtual BasicObject* m_fnmatch(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("fnmatch"); }
  virtual BasicObject* m__join_parts(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_join_parts"); }
  virtual BasicObject* m_sub_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sub!"); }
  virtual BasicObject* m___mode_with_encoding__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__mode_with_encoding__"); }
  virtual BasicObject* m_exist_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("exist?"); }
  virtual BasicObject* m_basename(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("basename"); }
  virtual BasicObject* m_rindex(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("rindex"); }
  virtual BasicObject* m_all_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("all?"); }
  virtual BasicObject* m_chars(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("chars"); }
  virtual BasicObject* m_any_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("any?"); }
  virtual BasicObject* m_index(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("index"); }
  virtual BasicObject* m_mode(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("mode"); }
  virtual BasicObject* m_readable_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("readable?"); }
  virtual BasicObject* m_readable_real_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("readable_real?"); }
  virtual BasicObject* m_writable_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("writable?"); }
  virtual BasicObject* m_writable_real_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("writable_real?"); }
  virtual BasicObject* m_executable_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("executable?"); }
  virtual BasicObject* m_executable_real_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("executable_real?"); }
  virtual BasicObject* m_owned_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("owned?"); }
  virtual BasicObject* m_grpowned_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("grpowned?"); }
  virtual BasicObject* m_ctime(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("ctime"); }
  virtual BasicObject* m_birthtime(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("birthtime"); }
  virtual BasicObject* m_dev(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("dev"); }
  virtual BasicObject* m_ino(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("ino"); }
  virtual BasicObject* m_nlink(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("nlink"); }
  virtual BasicObject* m_uid(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("uid"); }
  virtual BasicObject* m_gid(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("gid"); }
  virtual BasicObject* m_rdev(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("rdev"); }
  virtual BasicObject* m_blksize(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("blksize"); }
  virtual BasicObject* m_blocks(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("blocks"); }
  virtual BasicObject* m_atime(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("atime"); }
  virtual BasicObject* m_mtime(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("mtime"); }
  virtual BasicObject* m_reject(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("reject"); }
  virtual BasicObject* m___load_entries__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__load_entries__"); }
  virtual BasicObject* m_pos_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pos="); }
  virtual BasicObject* m_force_encoding(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("force_encoding"); }
  virtual BasicObject* m_children(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("children"); }
  virtual BasicObject* m_entries(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("entries"); }
  virtual BasicObject* m_glob(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("glob"); }
  virtual BasicObject* m_map_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("map!"); }
  virtual BasicObject* m_mday(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("mday"); }
  virtual BasicObject* m_month(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("month"); }
  virtual BasicObject* m_utc_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("utc?"); }
  virtual BasicObject* m_dst_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("dst?"); }
  virtual BasicObject* m_usec(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("usec"); }
  virtual BasicObject* m_nsec(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("nsec"); }
  virtual BasicObject* m_utc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("utc"); }
  virtual BasicObject* m_getutc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("getutc"); }
  virtual BasicObject* m_utc_offset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("utc_offset"); }
  virtual BasicObject* m_asctime(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("asctime"); }
  virtual BasicObject* m_iso8601(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("iso8601"); }
  virtual BasicObject* m_wday(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("wday"); }
  virtual BasicObject* m_sec(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sec"); }
  virtual BasicObject* m_hour(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("hour"); }
  virtual BasicObject* m_year(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("year"); }
  virtual BasicObject* m_yday(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("yday"); }
  virtual BasicObject* m_zone(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("zone"); }
  virtual BasicObject* m_strftime(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("strftime"); }
  virtual BasicObject* m__coerce_exact_number(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_coerce_exact_number"); }
  virtual BasicObject* m_abbr(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("abbr"); }
  virtual BasicObject* m_gsub(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("gsub"); }
  virtual BasicObject* m_find_timezone(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("find_timezone"); }
  virtual BasicObject* m__coerce_tz_arg(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_coerce_tz_arg"); }
  virtual BasicObject* m_utc_to_local(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("utc_to_local"); }
  virtual BasicObject* m__utc_to_local_offset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_utc_to_local_offset"); }
  virtual BasicObject* m_subsec(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("subsec"); }
  virtual BasicObject* m_slice(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("slice"); }
  virtual BasicObject* m_instance_variables(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("instance_variables"); }
  virtual BasicObject* m__mktime_args(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_mktime_args"); }
  virtual BasicObject* m_mon(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("mon"); }
  virtual BasicObject* m_local_variable_get(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("local_variable_get"); }
  virtual BasicObject* m_binding(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("binding"); }
  virtual BasicObject* m__coerce_time_arg(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_coerce_time_arg"); }
  virtual BasicObject* m_local_to_utc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("local_to_utc"); }
  virtual BasicObject* m__local_to_utc_offset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_local_to_utc_offset"); }
  virtual BasicObject* m_match_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("match?"); }
  virtual BasicObject* m_local(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("local"); }
  virtual BasicObject* m_zone_offset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("zone_offset"); }
  virtual BasicObject* m__time_apply_offset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_time_apply_offset"); }
  virtual BasicObject* m__time_force_zone_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_time_force_zone!"); }
  virtual BasicObject* m_rfc2822(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("rfc2822"); }
  virtual BasicObject* m__time_zone_utc_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_time_zone_utc?"); }
  virtual BasicObject* m_localtime(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("localtime"); }
  virtual BasicObject* m__time_month_days(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_time_month_days"); }
  virtual BasicObject* m_current(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("current"); }
  virtual BasicObject* m___mutex_seen_count(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__mutex_seen_count"); }
  virtual BasicObject* m___mutex_skip_count(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__mutex_skip_count"); }
  virtual BasicObject* m___mutex_seen_count_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__mutex_seen_count="); }
  virtual BasicObject* m___mutex_done_count_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__mutex_done_count="); }
  virtual BasicObject* m___mutex_done_count(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__mutex_done_count"); }
  virtual BasicObject* m___add_owned_mutex(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__add_owned_mutex"); }
  virtual BasicObject* m___remove_owned_mutex(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__remove_owned_mutex"); }
  virtual BasicObject* m_lock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("lock"); }
  virtual BasicObject* m_unlock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("unlock"); }
  virtual BasicObject* m_clock_gettime(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("clock_gettime"); }
  virtual BasicObject* m_sleep(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sleep"); }
  virtual BasicObject* m_stop(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("stop"); }
  virtual BasicObject* m_blocking_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("blocking?"); }
  virtual BasicObject* m_report_on_exception(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("report_on_exception"); }
  virtual BasicObject* m_abort_on_exception(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("abort_on_exception"); }
  virtual BasicObject* m___add_thread(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__add_thread"); }
  virtual BasicObject* m___start_init(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__start_init"); }
  virtual BasicObject* m___run_block(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__run_block"); }
  virtual BasicObject* m_fail(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("fail"); }
  virtual BasicObject* m_exception(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("exception"); }
  virtual BasicObject* m_clamp(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("clamp"); }
  virtual BasicObject* m_status(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("status"); }
  virtual BasicObject* m_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("b"); }
  virtual BasicObject* m_puts(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("puts"); }
  virtual BasicObject* m___force_unlock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__force_unlock"); }
  virtual BasicObject* m___coerce_var_key(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__coerce_var_key"); }
  virtual BasicObject* m___fiber_vars(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__fiber_vars"); }
  virtual BasicObject* m_kill(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("kill"); }
  virtual BasicObject* m_caller_locations(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("caller_locations"); }
  virtual BasicObject* m___allocate_thread(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__allocate_thread"); }
  virtual BasicObject* m_new_main_thread(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("new_main_thread"); }
  virtual BasicObject* m_main(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("main"); }
  virtual BasicObject* m_clear(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("clear"); }
  virtual BasicObject* m___init_main(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__init_main"); }
  virtual BasicObject* m___raise_exception(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__raise_exception"); }
  virtual BasicObject* m___raise_cause(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__raise_cause"); }
  virtual BasicObject* m___raise_backtrace(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__raise_backtrace"); }
  virtual BasicObject* m___raise_exception_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__raise_exception="); }
  virtual BasicObject* m___raise_cause_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__raise_cause="); }
  virtual BasicObject* m___raise_backtrace_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__raise_backtrace="); }
  virtual BasicObject* m___stop_seen(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__stop_seen"); }
  virtual BasicObject* m___wakeup_count(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__wakeup_count"); }
  virtual BasicObject* m___stop_seen_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__stop_seen="); }
  virtual BasicObject* m_expand_path(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("expand_path"); }
  virtual BasicObject* m_realpath(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("realpath"); }
  virtual BasicObject* m_enclosed_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("enclosed?"); }
  virtual BasicObject* m_group(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("group"); }
  virtual BasicObject* m___remove_thread(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__remove_thread"); }
  virtual BasicObject* m___set_group(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__set_group"); }
  virtual BasicObject* m___run_next_pending(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__run_next_pending"); }
  virtual BasicObject* m_now(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("now"); }
  virtual BasicObject* m___pending_include_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__pending_include?"); }
  virtual BasicObject* m___pending_size(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__pending_size"); }
  virtual BasicObject* m_exit(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("exit"); }
  virtual BasicObject* m_abort(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("abort"); }
  virtual BasicObject* m__fork(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_fork"); }
  virtual BasicObject* m_exit_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("exit!"); }
  virtual BasicObject* m_pid(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pid"); }
  virtual BasicObject* m_wait2(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("wait2"); }
  virtual BasicObject* m_exitstatus(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("exitstatus"); }
  virtual BasicObject* m_termsig(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("termsig"); }
  virtual BasicObject* m_signaled_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("signaled?"); }
  virtual BasicObject* m_pretty_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pretty_inspect"); }
  virtual BasicObject* m_print(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("print"); }
  virtual BasicObject* m__int_mode_to_str(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_int_mode_to_str"); }
  virtual BasicObject* m__check_open(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_check_open"); }
  virtual BasicObject* m__check_readable(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_check_readable"); }
  virtual BasicObject* m_byteslice(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("byteslice"); }
  virtual BasicObject* m_encode(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("encode"); }
  virtual BasicObject* m_replace(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("replace"); }
  virtual BasicObject* m_getbyte(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("getbyte"); }
  virtual BasicObject* m_getc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("getc"); }
  virtual BasicObject* m__normalize_sep_limit(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_normalize_sep_limit"); }
  virtual BasicObject* m__unget_str(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_unget_str"); }
  virtual BasicObject* m__chomp(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_chomp"); }
  virtual BasicObject* m__check_writable(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_check_writable"); }
  virtual BasicObject* m__write_str(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_write_str"); }
  virtual BasicObject* m__puts_args(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_puts_args"); }
  virtual BasicObject* m_enum_for(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("enum_for"); }
  virtual BasicObject* m_sysread(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sysread"); }
  virtual BasicObject* m_initialize(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("initialize"); }
  virtual BasicObject* m_to_strio(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_strio"); }
  virtual BasicObject* m_members(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("members"); }
  virtual BasicObject* m_keyword_init_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("keyword_init?"); }
  virtual BasicObject* m_to_h(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_h"); }
  virtual BasicObject* m_dig(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("dig"); }
  virtual BasicObject* m_throw(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("throw"); }
  virtual BasicObject* m_catch(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("catch"); }
  virtual BasicObject* m_each_value(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("each_value"); }
  virtual BasicObject* m_define_method(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("define_method"); }
  virtual BasicObject* m_superclass(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("superclass"); }
  virtual BasicObject* m_class_exec(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("class_exec"); }
  virtual BasicObject* m_const_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("const_set"); }
  virtual BasicObject* m_zip(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("zip"); }
  virtual BasicObject* m_class_eval(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("class_eval"); }
  virtual BasicObject* m_intersect_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("intersect?"); }
  virtual BasicObject* m_compare_by_identity_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("compare_by_identity?"); }
  virtual BasicObject* m_text(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("text"); }
  virtual BasicObject* m_compare_by_identity(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("compare_by_identity"); }
  virtual BasicObject* m_keep_if(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("keep_if"); }
  virtual BasicObject* m_delete_if(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("delete_if"); }
  virtual BasicObject* m_each_key(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("each_key"); }
  virtual BasicObject* m___do_flatten__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__do_flatten__"); }
  virtual BasicObject* m_subset_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("subset?"); }
  virtual BasicObject* m_superset_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("superset?"); }
  virtual BasicObject* m_arity(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("arity"); }
  virtual BasicObject* m_classify(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("classify"); }
  virtual BasicObject* m_seed(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("seed"); }
  virtual BasicObject* m_state(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("state"); }
  virtual BasicObject* m_srand(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("srand"); }
  virtual BasicObject* m_delete_at(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("delete_at"); }
  virtual BasicObject* m__weakmap_inspect_obj(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_weakmap_inspect_obj"); }
  virtual BasicObject* m___check_key___b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__check_key__!"); }
  virtual BasicObject* m___find_index__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__find_index__"); }
  virtual BasicObject* m___ungcable___q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__ungcable__?"); }
  virtual BasicObject* m___find_pair__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__find_pair__"); }
  virtual BasicObject* m___enc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__enc"); }
  virtual BasicObject* m___coerce_key(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__coerce_key"); }
  virtual BasicObject* m_to_hash(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_hash"); }
  virtual BasicObject* m___validate_key(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__validate_key"); }
  virtual BasicObject* m___coerce_value(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__coerce_value"); }
  virtual BasicObject* m___soft_coerce_string__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__soft_coerce_string__"); }
  virtual BasicObject* m___coerce_env_string__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__coerce_env_string__"); }
  virtual BasicObject* m_write_object(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_object"); }
  virtual BasicObject* m_write_object_inner(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_object_inner"); }
  virtual BasicObject* m_write_integer(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_integer"); }
  virtual BasicObject* m_write_symbol(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_symbol"); }
  virtual BasicObject* m_write_link(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_link"); }
  virtual BasicObject* m_dispatch_obj(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("dispatch_obj"); }
  virtual BasicObject* m_isa_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("isa?"); }
  virtual BasicObject* m_track(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("track"); }
  virtual BasicObject* m_write_float(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_float"); }
  virtual BasicObject* m_write_bignum(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_bignum"); }
  virtual BasicObject* m_write_string_with_ivar(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_string_with_ivar"); }
  virtual BasicObject* m_write_array_with_wraps(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_array_with_wraps"); }
  virtual BasicObject* m_write_hash_with_wraps(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_hash_with_wraps"); }
  virtual BasicObject* m_write_regexp_with_ivar(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_regexp_with_ivar"); }
  virtual BasicObject* m_write_class(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_class"); }
  virtual BasicObject* m_write_module(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_module"); }
  virtual BasicObject* m_write_exception(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_exception"); }
  virtual BasicObject* m_write_struct_with_wraps(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_struct_with_wraps"); }
  virtual BasicObject* m_write_data_as_struct(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_data_as_struct"); }
  virtual BasicObject* m_respond_to_marshal_dump_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("respond_to_marshal_dump?"); }
  virtual BasicObject* m_write_user_marshal(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_user_marshal"); }
  virtual BasicObject* m_respond_to__dump_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("respond_to__dump?"); }
  virtual BasicObject* m_write_user_defined(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_user_defined"); }
  virtual BasicObject* m_write_range(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_range"); }
  virtual BasicObject* m_write_generic_object(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_generic_object"); }
  virtual BasicObject* m_write_long(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_long"); }
  virtual BasicObject* m_bignum_to_bytes(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("bignum_to_bytes"); }
  virtual BasicObject* m_odd_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("odd?"); }
  virtual BasicObject* m_float_to_string(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("float_to_string"); }
  virtual BasicObject* m_write_enc_ivar(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_enc_ivar"); }
  virtual BasicObject* m_extended_modules(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("extended_modules"); }
  virtual BasicObject* m_collect_ivars(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("collect_ivars"); }
  virtual BasicObject* m_encoding_ivar(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("encoding_ivar"); }
  virtual BasicObject* m_write_extension_prefix(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_extension_prefix"); }
  virtual BasicObject* m_write_uclass(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_uclass"); }
  virtual BasicObject* m_write_raw_string(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_raw_string"); }
  virtual BasicObject* m_included_modules(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("included_modules"); }
  virtual BasicObject* m_write_symbol_str(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_symbol_str"); }
  virtual BasicObject* m_real_module_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("real_module_name"); }
  virtual BasicObject* m_real_class_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("real_class_name"); }
  virtual BasicObject* m_write_raw_array(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_raw_array"); }
  virtual BasicObject* m_default_proc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("default_proc"); }
  virtual BasicObject* m_write_raw_hash(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_raw_hash"); }
  virtual BasicObject* m_default(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("default"); }
  virtual BasicObject* m_each_pair(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("each_pair"); }
  virtual BasicObject* m_write_raw_regexp(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_raw_regexp"); }
  virtual BasicObject* m_check_anonymous(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("check_anonymous"); }
  virtual BasicObject* m_write_raw_struct(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_raw_struct"); }
  virtual BasicObject* m___marshal_time_ivars__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__marshal_time_ivars__"); }
  virtual BasicObject* m_const_from_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("const_from_name"); }
  virtual BasicObject* m_check_no_singleton(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("check_no_singleton"); }
  virtual BasicObject* m_binmode(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("binmode"); }
  virtual BasicObject* m_read_byte(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_byte"); }
  virtual BasicObject* m_read_object(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_object"); }
  virtual BasicObject* m_read_object_for_ivar(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_object_for_ivar"); }
  virtual BasicObject* m_call_proc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("call_proc"); }
  virtual BasicObject* m_read_long(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_long"); }
  virtual BasicObject* m_read_bignum(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_bignum"); }
  virtual BasicObject* m_read_float(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_float"); }
  virtual BasicObject* m_read_symbol(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_symbol"); }
  virtual BasicObject* m_read_string(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_string"); }
  virtual BasicObject* m_read_array(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_array"); }
  virtual BasicObject* m_read_hash(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_hash"); }
  virtual BasicObject* m_read_object_generic(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_object_generic"); }
  virtual BasicObject* m_read_struct(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_struct"); }
  virtual BasicObject* m_read_class_ref(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_class_ref"); }
  virtual BasicObject* m_read_module_ref(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_module_ref"); }
  virtual BasicObject* m_read_ivar(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_ivar"); }
  virtual BasicObject* m_read_link(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_link"); }
  virtual BasicObject* m_read_uclass(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_uclass"); }
  virtual BasicObject* m_read_user_defined(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_user_defined"); }
  virtual BasicObject* m_read_user_marshal(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_user_marshal"); }
  virtual BasicObject* m_read_extended(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_extended"); }
  virtual BasicObject* m_read_regexp(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_regexp"); }
  virtual BasicObject* m_read_data_object(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_data_object"); }
  virtual BasicObject* m_read_old_module_ref(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_old_module_ref"); }
  virtual BasicObject* m_freeze_object(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("freeze_object"); }
  virtual BasicObject* m_read_bytes(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_bytes"); }
  virtual BasicObject* m_default_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("default="); }
  virtual BasicObject* m_read_class_by_symbol(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_class_by_symbol"); }
  virtual BasicObject* m_read_ivar_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_ivar_name"); }
  virtual BasicObject* m_delete_prefix(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("delete_prefix"); }
  virtual BasicObject* m_set_backtrace(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("set_backtrace"); }
  virtual BasicObject* m_const_get(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("const_get"); }
  virtual BasicObject* m_read_struct_body(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_struct_body"); }
  virtual BasicObject* m_read_generic_object_body(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_generic_object_body"); }
  virtual BasicObject* m_read_object_with_class(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_object_with_class"); }
  virtual BasicObject* m_read_object_with_class_ivar(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_object_with_class_ivar"); }
  virtual BasicObject* m_extend(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("extend"); }
  virtual BasicObject* m_private_instance_methods(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("private_instance_methods"); }
  virtual BasicObject* m_has_key_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("has_key_q"); }
  virtual BasicObject* m_instance_exec(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("instance_exec"); }
  virtual BasicObject* m_instance_eval(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("instance_eval"); }
  virtual BasicObject* m_respond_to_missing_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("respond_to_missing?"); }
  virtual BasicObject* m_public(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("public"); }
  virtual BasicObject* m_private(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("private"); }
  virtual BasicObject* m_protected(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("protected"); }
  virtual BasicObject* m_module_function(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("module_function"); }
  virtual BasicObject* m_include(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("include"); }
  virtual BasicObject* m_prepend(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("prepend"); }
  virtual BasicObject* m_append_features(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("append_features"); }
  virtual BasicObject* m_prepend_features(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("prepend_features"); }
  virtual BasicObject* m_included(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("included"); }
  virtual BasicObject* m_prepended(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("prepended"); }
  virtual BasicObject* m_attr_reader(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("attr_reader"); }
  virtual BasicObject* m_attr_writer(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("attr_writer"); }
  virtual BasicObject* m_attr_accessor(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("attr_accessor"); }
  virtual BasicObject* m_private_constant(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("private_constant"); }
  virtual BasicObject* m_public_constant(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("public_constant"); }
  virtual BasicObject* m_private_class_method(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("private_class_method"); }
  virtual BasicObject* m_public_class_method(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("public_class_method"); }
  virtual BasicObject* m_remove_method(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("remove_method"); }
  virtual BasicObject* m_undef_method(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("undef_method"); }
  virtual BasicObject* m_alias_method(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("alias_method"); }
  virtual BasicObject* m_const_defined_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("const_defined?"); }
  virtual BasicObject* m_undefined_instance_methods(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("undefined_instance_methods"); }
  virtual BasicObject* m_public_instance_methods(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("public_instance_methods"); }
  virtual BasicObject* m_protected_instance_methods(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("protected_instance_methods"); }
  virtual BasicObject* m_public_instance_method(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("public_instance_method"); }
  virtual BasicObject* m_method_defined_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("method_defined?"); }
  virtual BasicObject* m_public_method_defined_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("public_method_defined?"); }
  virtual BasicObject* m_private_method_defined_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("private_method_defined?"); }
  virtual BasicObject* m_protected_method_defined_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("protected_method_defined?"); }
  virtual BasicObject* m_class_variable_defined_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("class_variable_defined?"); }
  virtual BasicObject* m_class_variable_get(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("class_variable_get"); }
  virtual BasicObject* m_class_variable_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("class_variable_set"); }
  virtual BasicObject* m_class_variables(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("class_variables"); }
  virtual BasicObject* m_remove_const(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("remove_const"); }
  virtual BasicObject* m_remove_class_variable(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("remove_class_variable"); }
  virtual BasicObject* m_ruby2_keywords(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("ruby2_keywords"); }
  virtual BasicObject* m_autoload(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("autoload"); }
  virtual BasicObject* m_autoload_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("autoload?"); }
  virtual BasicObject* m_set_temporary_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("set_temporary_name"); }
  virtual BasicObject* m_const_source_location(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("const_source_location"); }
  virtual BasicObject* m_const_added(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("const_added"); }
  virtual BasicObject* m_method_added(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("method_added"); }
  virtual BasicObject* m_method_removed(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("method_removed"); }
  virtual BasicObject* m_method_undefined(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("method_undefined"); }
  virtual BasicObject* m_singleton_method_added(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("singleton_method_added"); }
  virtual BasicObject* m_singleton_method_removed(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("singleton_method_removed"); }
  virtual BasicObject* m_singleton_method_undefined(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("singleton_method_undefined"); }
  virtual BasicObject* m_deprecate_constant(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("deprecate_constant"); }
  virtual BasicObject* m_extend_object(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("extend_object"); }
  virtual BasicObject* m_extended(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("extended"); }
  virtual BasicObject* m_refinements(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("refinements"); }
  virtual BasicObject* m_attr(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("attr"); }
  virtual BasicObject* m_module_eval(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("module_eval"); }
  virtual BasicObject* m_module_exec(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("module_exec"); }
  virtual BasicObject* m_const_missing(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("const_missing"); }
  virtual BasicObject* m_refine(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("refine"); }
  virtual BasicObject* m_using(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("using"); }
  virtual BasicObject* m_nesting(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("nesting"); }
  virtual BasicObject* m_used_refinements(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("used_refinements"); }
  virtual BasicObject* m_integer_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("integer?"); }
  virtual BasicObject* m_positive_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("positive?"); }
  virtual BasicObject* m_conj(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("conj"); }
  virtual BasicObject* m_conjugate(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("conjugate"); }
  virtual BasicObject* m_imag(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("imag"); }
  virtual BasicObject* m_polar(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("polar"); }
  virtual BasicObject* m_rect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("rect"); }
  virtual BasicObject* m_rectangular(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("rectangular"); }
  virtual BasicObject* m_to_c(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_c"); }
  virtual BasicObject* m_i(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("i"); }
  virtual BasicObject* m_nonzero_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("nonzero?"); }
  virtual BasicObject* m_magnitude(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("magnitude"); }
  virtual BasicObject* m_phase(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("phase"); }
  virtual BasicObject* m_clone(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("clone"); }
  virtual BasicObject* m_remainder(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("remainder"); }
  virtual BasicObject* m_target(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("target"); }
  virtual BasicObject* m_import_methods(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("import_methods"); }
  virtual BasicObject* m_original_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("original_name"); }
  virtual BasicObject* m_unbind(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("unbind"); }
  virtual BasicObject* m_super_method(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("super_method"); }
  virtual BasicObject* m_bind_call(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("bind_call"); }
  virtual BasicObject* m_none_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("none?"); }
  virtual BasicObject* m_detect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("detect"); }
  virtual BasicObject* m_sum(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sum"); }
  virtual BasicObject* m_collect_concat(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("collect_concat"); }
  virtual BasicObject* m_member_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("member?"); }
  virtual BasicObject* m_minmax(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("minmax"); }
  virtual BasicObject* m_to_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_set"); }
  virtual BasicObject* m_overlap_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("overlap?"); }
  virtual BasicObject* m_bsearch(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("bsearch"); }
  virtual BasicObject* m_each_slice(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("each_slice"); }
  virtual BasicObject* m_each_cons(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("each_cons"); }
  virtual BasicObject* m_new(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("new"); }
  virtual BasicObject* m_next_values(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("next_values"); }
  virtual BasicObject* m_peek_values(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("peek_values"); }
  virtual BasicObject* m_with_object(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("with_object"); }
  virtual BasicObject* m_feed(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("feed"); }
  virtual BasicObject* m_collect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("collect"); }
  virtual BasicObject* m_with_index(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("with_index"); }
  virtual BasicObject* m_produce(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("produce"); }
  virtual BasicObject* m_product(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("product"); }
  virtual BasicObject* m_lazy(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("lazy"); }
  virtual BasicObject* m_eager(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("eager"); }
  virtual BasicObject* m_filter(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("filter"); }
  virtual BasicObject* m_find_all(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("find_all"); }
  virtual BasicObject* m_take_while(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("take_while"); }
  virtual BasicObject* m_drop_while(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("drop_while"); }
  virtual BasicObject* m_filter_map(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("filter_map"); }
  virtual BasicObject* m_uniq(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("uniq"); }
  virtual BasicObject* m_grep(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("grep"); }
  virtual BasicObject* m_grep_v(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("grep_v"); }
  virtual BasicObject* m_chunk_while(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("chunk_while"); }
  virtual BasicObject* m_slice_before(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("slice_before"); }
  virtual BasicObject* m_slice_after(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("slice_after"); }
  virtual BasicObject* m_slice_when(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("slice_when"); }
  virtual BasicObject* m_initialize_copy(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("initialize_copy"); }
  virtual BasicObject* m_backtrace_locations(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("backtrace_locations"); }
  virtual BasicObject* m_full_message(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("full_message"); }
  virtual BasicObject* m_signo(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("signo"); }
  virtual BasicObject* m_signm(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("signm"); }
  virtual BasicObject* m_success_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("success?"); }
  virtual BasicObject* m_args(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("args"); }
  virtual BasicObject* m_key(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("key"); }
  virtual BasicObject* m_tag(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("tag"); }
  virtual BasicObject* m_exit_value(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("exit_value"); }
  virtual BasicObject* m_reason(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("reason"); }
  virtual BasicObject* m_errno(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("errno"); }
  virtual BasicObject* m_ascii_compatible_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("ascii_compatible?"); }
  virtual BasicObject* m_ascii_only_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("ascii_only?"); }
  virtual BasicObject* m_replicate(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("replicate"); }
  virtual BasicObject* m_names(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("names"); }
  virtual BasicObject* m_compatible_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("compatible?"); }
  virtual BasicObject* m_default_external_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("default_external="); }
  virtual BasicObject* m_default_internal_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("default_internal="); }
  virtual BasicObject* m_name_list(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("name_list"); }
  virtual BasicObject* m_source_encoding_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("source_encoding_name"); }
  virtual BasicObject* m_destination_encoding_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("destination_encoding_name"); }
  virtual BasicObject* m_source_encoding(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("source_encoding"); }
  virtual BasicObject* m_destination_encoding(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("destination_encoding"); }
  virtual BasicObject* m_error_bytes(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("error_bytes"); }
  virtual BasicObject* m_readagain_bytes(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("readagain_bytes"); }
  virtual BasicObject* m_incomplete_input_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("incomplete_input?"); }
  virtual BasicObject* m_error_char(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("error_char"); }
  virtual BasicObject* m_convpath(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("convpath"); }
  virtual BasicObject* m_replacement(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("replacement"); }
  virtual BasicObject* m_convert(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("convert"); }
  virtual BasicObject* m_finish(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("finish"); }
  virtual BasicObject* m_primitive_errinfo(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("primitive_errinfo"); }
  virtual BasicObject* m_last_error(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("last_error"); }
  virtual BasicObject* m_insert_output(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("insert_output"); }
  virtual BasicObject* m_replacement_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("replacement="); }
  virtual BasicObject* m_primitive_convert(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("primitive_convert"); }
  virtual BasicObject* m_putback(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("putback"); }
  virtual BasicObject* m_asciicompat_encoding(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("asciicompat_encoding"); }
  virtual BasicObject* m_search_convpath(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("search_convpath"); }
  virtual BasicObject* m_pre_match(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pre_match"); }
  virtual BasicObject* m_post_match(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("post_match"); }
  virtual BasicObject* m_offset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("offset"); }
  virtual BasicObject* m_byteoffset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("byteoffset"); }
  virtual BasicObject* m_match_length(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("match_length"); }
  virtual BasicObject* m_deconstruct(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("deconstruct"); }
  virtual BasicObject* m_values_at(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("values_at"); }
  virtual BasicObject* m_deconstruct_keys(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("deconstruct_keys"); }
  virtual BasicObject* m_casefold_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("casefold?"); }
  virtual BasicObject* m_fixed_encoding_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("fixed_encoding?"); }
  virtual BasicObject* m_linear_time_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("linear_time?"); }
  virtual BasicObject* m_escape(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("escape"); }
  virtual BasicObject* m_quote(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("quote"); }
  virtual BasicObject* m_union(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("union"); }
  virtual BasicObject* m_last_match(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("last_match"); }
  virtual BasicObject* m_compile(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("compile"); }
  virtual BasicObject* m_timeout(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("timeout"); }
  virtual BasicObject* m_timeout_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("timeout="); }
  virtual BasicObject* m_try_convert(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("try_convert"); }
  virtual BasicObject* m_marshal_dump(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("marshal_dump"); }
  virtual BasicObject* m_marshal_load(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("marshal_load"); }
  virtual BasicObject* m_flush(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("flush"); }
  virtual BasicObject* m_sync_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sync="); }
  virtual BasicObject* m_sync(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sync"); }
  virtual BasicObject* m_autoclose_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("autoclose="); }
  virtual BasicObject* m_autoclose_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("autoclose?"); }
  virtual BasicObject* m_close_read(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("close_read"); }
  virtual BasicObject* m_close_write(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("close_write"); }
  virtual BasicObject* m_eof(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("eof"); }
  virtual BasicObject* m_close_on_exec_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("close_on_exec?"); }
  virtual BasicObject* m_close_on_exec_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("close_on_exec="); }
  virtual BasicObject* m_tty_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("tty?"); }
  virtual BasicObject* m_fsync(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("fsync"); }
  virtual BasicObject* m_ioctl(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("ioctl"); }
  virtual BasicObject* m_tell(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("tell"); }
  virtual BasicObject* m_lineno(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("lineno"); }
  virtual BasicObject* m_lineno_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("lineno="); }
  virtual BasicObject* m_readline(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("readline"); }
  virtual BasicObject* m_readbyte(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("readbyte"); }
  virtual BasicObject* m_readchar(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("readchar"); }
  virtual BasicObject* m_ungetbyte(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("ungetbyte"); }
  virtual BasicObject* m_ungetc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("ungetc"); }
  virtual BasicObject* m_syswrite(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("syswrite"); }
  virtual BasicObject* m_pread(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pread"); }
  virtual BasicObject* m_read_nonblock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_nonblock"); }
  virtual BasicObject* m_readpartial(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("readpartial"); }
  virtual BasicObject* m_printf(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("printf"); }
  virtual BasicObject* m_flock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("flock"); }
  virtual BasicObject* m_sysseek(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sysseek"); }
  virtual BasicObject* m_pwrite(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pwrite"); }
  virtual BasicObject* m_write_nonblock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_nonblock"); }
  virtual BasicObject* m_codepoints(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("codepoints"); }
  virtual BasicObject* m_putc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("putc"); }
  virtual BasicObject* m_advise(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("advise"); }
  virtual BasicObject* m_reopen(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("reopen"); }
  virtual BasicObject* m_set_encoding_by_bom(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("set_encoding_by_bom"); }
  virtual BasicObject* m_for_fd(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("for_fd"); }
  virtual BasicObject* m_pipe(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pipe"); }
  virtual BasicObject* m_popen(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("popen"); }
  virtual BasicObject* m_foreach(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("foreach"); }
  virtual BasicObject* m_binread(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("binread"); }
  virtual BasicObject* m_binwrite(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("binwrite"); }
  virtual BasicObject* m_copy_stream(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("copy_stream"); }
  virtual BasicObject* m_chown(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("chown"); }
  virtual BasicObject* m_lstat(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("lstat"); }
  virtual BasicObject* m_absolute_path(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("absolute_path"); }
  virtual BasicObject* m_absolute_path_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("absolute_path?"); }
  virtual BasicObject* m_exists_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("exists?"); }
  virtual BasicObject* m_directory_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("directory?"); }
  virtual BasicObject* m_file_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("file?"); }
  virtual BasicObject* m_size_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("size?"); }
  virtual BasicObject* m_symlink_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("symlink?"); }
  virtual BasicObject* m_blockdev_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("blockdev?"); }
  virtual BasicObject* m_chardev_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("chardev?"); }
  virtual BasicObject* m_pipe_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pipe?"); }
  virtual BasicObject* m_socket_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("socket?"); }
  virtual BasicObject* m_setuid_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("setuid?"); }
  virtual BasicObject* m_setgid_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("setgid?"); }
  virtual BasicObject* m_sticky_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sticky?"); }
  virtual BasicObject* m_identical_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("identical?"); }
  virtual BasicObject* m_ftype(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("ftype"); }
  virtual BasicObject* m_realdirpath(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("realdirpath"); }
  virtual BasicObject* m_unlink(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("unlink"); }
  virtual BasicObject* m_rename(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("rename"); }
  virtual BasicObject* m_symlink(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("symlink"); }
  virtual BasicObject* m_link(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("link"); }
  virtual BasicObject* m_readlink(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("readlink"); }
  virtual BasicObject* m_lchown(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("lchown"); }
  virtual BasicObject* m_lchmod(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("lchmod"); }
  virtual BasicObject* m_lutime(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("lutime"); }
  virtual BasicObject* m_fnmatch_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("fnmatch?"); }
  virtual BasicObject* m_mkfifo(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("mkfifo"); }
  virtual BasicObject* m_umask(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("umask"); }
  virtual BasicObject* m_utime(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("utime"); }
  virtual BasicObject* m_dirname(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("dirname"); }
  virtual BasicObject* m_extname(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("extname"); }
  virtual BasicObject* m_world_readable_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("world_readable?"); }
  virtual BasicObject* m_world_writable_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("world_writable?"); }
  virtual BasicObject* m_dev_major(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("dev_major"); }
  virtual BasicObject* m_dev_minor(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("dev_minor"); }
  virtual BasicObject* m_rdev_major(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("rdev_major"); }
  virtual BasicObject* m_rdev_minor(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("rdev_minor"); }
  virtual BasicObject* m_chdir(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("chdir"); }
  virtual BasicObject* m_each_child(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("each_child"); }
  virtual BasicObject* m_pwd(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pwd"); }
  virtual BasicObject* m_getwd(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("getwd"); }
  virtual BasicObject* m_home(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("home"); }
  virtual BasicObject* m_fchdir(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("fchdir"); }
  virtual BasicObject* m_mktmpdir(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("mktmpdir"); }
  virtual BasicObject* m_rmdir(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("rmdir"); }
  virtual BasicObject* m_chroot(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("chroot"); }
  virtual BasicObject* m_mkdir(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("mkdir"); }
  virtual BasicObject* m_day(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("day"); }
  virtual BasicObject* m_gmt_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("gmt?"); }
  virtual BasicObject* m_isdst(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("isdst"); }
  virtual BasicObject* m_tv_sec(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("tv_sec"); }
  virtual BasicObject* m_tv_usec(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("tv_usec"); }
  virtual BasicObject* m_tv_nsec(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("tv_nsec"); }
  virtual BasicObject* m_gmtime(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("gmtime"); }
  virtual BasicObject* m_getgm(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("getgm"); }
  virtual BasicObject* m_gmt_offset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("gmt_offset"); }
  virtual BasicObject* m_gmtoff(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("gmtoff"); }
  virtual BasicObject* m_xmlschema(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("xmlschema"); }
  virtual BasicObject* m_monday_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("monday?"); }
  virtual BasicObject* m_tuesday_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("tuesday?"); }
  virtual BasicObject* m_wednesday_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("wednesday?"); }
  virtual BasicObject* m_thursday_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("thursday?"); }
  virtual BasicObject* m_friday_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("friday?"); }
  virtual BasicObject* m_saturday_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("saturday?"); }
  virtual BasicObject* m_sunday_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("sunday?"); }
  virtual BasicObject* m_to_time(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("to_time"); }
  virtual BasicObject* m_httpdate(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("httpdate"); }
  virtual BasicObject* m_getlocal(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("getlocal"); }
  virtual BasicObject* m_rfc822(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("rfc822"); }
  virtual BasicObject* m__dump(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_dump"); }
  virtual BasicObject* m_mktime(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("mktime"); }
  virtual BasicObject* m_gm(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("gm"); }
  virtual BasicObject* m_at(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("at"); }
  virtual BasicObject* m__coerce_int_arg(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_coerce_int_arg"); }
  virtual BasicObject* m__load(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("_load"); }
  virtual BasicObject* m_locked_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("locked?"); }
  virtual BasicObject* m_try_lock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("try_lock"); }
  virtual BasicObject* m_synchronize(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("synchronize"); }
  virtual BasicObject* m_transfer(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("transfer"); }
  virtual BasicObject* m_storage(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("storage"); }
  virtual BasicObject* m_storage_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("storage="); }
  virtual BasicObject* m_scheduler(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("scheduler"); }
  virtual BasicObject* m_blocking(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("blocking"); }
  virtual BasicObject* m_set_scheduler(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("set_scheduler"); }
  virtual BasicObject* m___wakeup_count_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__wakeup_count="); }
  virtual BasicObject* m___mutex_skip_count_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__mutex_skip_count="); }
  virtual BasicObject* m_stop_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("stop?"); }
  virtual BasicObject* m_report_on_exception_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("report_on_exception="); }
  virtual BasicObject* m_abort_on_exception_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("abort_on_exception="); }
  virtual BasicObject* m_value(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("value"); }
  virtual BasicObject* m_terminate(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("terminate"); }
  virtual BasicObject* m_wakeup(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("wakeup"); }
  virtual BasicObject* m_run(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("run"); }
  virtual BasicObject* m_priority(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("priority"); }
  virtual BasicObject* m_native_thread_id(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("native_thread_id"); }
  virtual BasicObject* m_pending_interrupt_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pending_interrupt?"); }
  virtual BasicObject* m_add_trace_func(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("add_trace_func"); }
  virtual BasicObject* m_set_trace_func(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("set_trace_func"); }
  virtual BasicObject* m_priority_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("priority="); }
  virtual BasicObject* m_name_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("name="); }
  virtual BasicObject* m_thread_variable_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("thread_variable_set"); }
  virtual BasicObject* m_thread_variable_get(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("thread_variable_get"); }
  virtual BasicObject* m_thread_variable_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("thread_variable?"); }
  virtual BasicObject* m_thread_variables(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("thread_variables"); }
  virtual BasicObject* m_handle_interrupt(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("handle_interrupt"); }
  virtual BasicObject* m_ignore_deadlock_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("ignore_deadlock="); }
  virtual BasicObject* m_ignore_deadlock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("ignore_deadlock"); }
  virtual BasicObject* m_each_caller_location(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("each_caller_location"); }
  virtual BasicObject* m_start(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("start"); }
  virtual BasicObject* m_fork(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("fork"); }
  virtual BasicObject* m___kill_all_non_main_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("__kill_all_non_main!"); }
  virtual BasicObject* m_pass(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pass"); }
  virtual BasicObject* m_label(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("label"); }
  virtual BasicObject* m_base_label(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("base_label"); }
  virtual BasicObject* m_enclose(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("enclose"); }
  virtual BasicObject* m_signal(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("signal"); }
  virtual BasicObject* m_broadcast(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("broadcast"); }
  virtual BasicObject* m_wait(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("wait"); }
  virtual BasicObject* m_num_waiting(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("num_waiting"); }
  virtual BasicObject* m_enq(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("enq"); }
  virtual BasicObject* m_deq(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("deq"); }
  virtual BasicObject* m_max_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("max="); }
  virtual BasicObject* m_waitpid(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("waitpid"); }
  virtual BasicObject* m_waitpid2(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("waitpid2"); }
  virtual BasicObject* m_waitall(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("waitall"); }
  virtual BasicObject* m_euid(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("euid"); }
  virtual BasicObject* m_egid(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("egid"); }
  virtual BasicObject* m_groups(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("groups"); }
  virtual BasicObject* m_argv0(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("argv0"); }
  virtual BasicObject* m_spawn(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("spawn"); }
  virtual BasicObject* m_clock_getres(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("clock_getres"); }
  virtual BasicObject* m_daemon(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("daemon"); }
  virtual BasicObject* m_exec(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("exec"); }
  virtual BasicObject* m_uid_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("uid="); }
  virtual BasicObject* m_gid_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("gid="); }
  virtual BasicObject* m_euid_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("euid="); }
  virtual BasicObject* m_egid_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("egid="); }
  virtual BasicObject* m_detach(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("detach"); }
  virtual BasicObject* m_stopped_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("stopped?"); }
  virtual BasicObject* m_stopsig(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("stopsig"); }
  virtual BasicObject* m_coredump_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("coredump?"); }
  virtual BasicObject* m_exited_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("exited?"); }
  virtual BasicObject* m_local_variables(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("local_variables"); }
  virtual BasicObject* m_local_variable_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("local_variable_set"); }
  virtual BasicObject* m_local_variable_defined_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("local_variable_defined?"); }
  virtual BasicObject* m_eval(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("eval"); }
  virtual BasicObject* m_width_for(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("width_for"); }
  virtual BasicObject* m_pp(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pp"); }
  virtual BasicObject* m_string_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("string="); }
  virtual BasicObject* m_closed_read_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("closed_read?"); }
  virtual BasicObject* m_closed_write_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("closed_write?"); }
  virtual BasicObject* m_lines(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("lines"); }
  virtual BasicObject* m_fcntl(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("fcntl"); }
  virtual BasicObject* m_with(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("with"); }
  virtual BasicObject* m_define(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("define"); }
  virtual BasicObject* m_disjoint_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("disjoint?"); }
  virtual BasicObject* m_pretty_print(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pretty_print"); }
  virtual BasicObject* m_pretty_print_cycle(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("pretty_print_cycle"); }
  virtual BasicObject* m_initialize_clone(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("initialize_clone"); }
  virtual BasicObject* m_add_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("add?"); }
  virtual BasicObject* m_delete_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("delete?"); }
  virtual BasicObject* m_select_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("select!"); }
  virtual BasicObject* m_filter_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("filter!"); }
  virtual BasicObject* m_reject_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("reject!"); }
  virtual BasicObject* m_subtract(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("subtract"); }
  virtual BasicObject* m_collect_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("collect!"); }
  virtual BasicObject* m_flatten_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("flatten!"); }
  virtual BasicObject* m_intersection(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("intersection"); }
  virtual BasicObject* m_difference(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("difference"); }
  virtual BasicObject* m_proper_subset_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("proper_subset?"); }
  virtual BasicObject* m_proper_superset_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("proper_superset?"); }
  virtual BasicObject* m_divide(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("divide"); }
  virtual BasicObject* m_rand(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("rand"); }
  virtual BasicObject* m_random_number(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("random_number"); }
  virtual BasicObject* m_urandom(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("urandom"); }
  virtual BasicObject* m_new_seed(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("new_seed"); }
  virtual BasicObject* m_getkey(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("getkey"); }
  virtual BasicObject* m_rehash(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("rehash"); }
  virtual BasicObject* m_store(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("store"); }
  virtual BasicObject* m_value_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("value?"); }
  virtual BasicObject* m_has_value_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("has_value?"); }
  virtual BasicObject* m_assoc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("assoc"); }
  virtual BasicObject* m_rassoc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("rassoc"); }
  virtual BasicObject* m_update(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("update"); }
  virtual BasicObject* m_merge_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("merge!"); }
  virtual BasicObject* m_except(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("except"); }
  virtual BasicObject* m_invert(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("invert"); }
  virtual BasicObject* m_dump(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("dump"); }
  virtual BasicObject* m_write_class_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_class_name"); }
  virtual BasicObject* m_write_module_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("write_module_name"); }
  virtual BasicObject* m_load(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("load"); }
  virtual BasicObject* m_peek_byte(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("peek_byte"); }
  virtual BasicObject* m_read_class_by_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_class_by_name"); }
  virtual BasicObject* m_read_user_defined_body(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("read_user_defined_body"); }
};

struct Object : BasicObject {
  using BasicObject::BasicObject;
  const char* ruby_class_name() const override { return "Object"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Object(__Ts__...) {}
};

struct Class : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Class"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Class(__Ts__...) {}
};

struct NilClass : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "NilClass"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> NilClass(__Ts__...) {}
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_nil_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct TrueClass : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "TrueClass"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> TrueClass(__Ts__...) {}
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct FalseClass : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "FalseClass"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> FalseClass(__Ts__...) {}
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Integer : Object {
  using Object::Object;
  explicit Integer(int64_t r) : raw_(r) {}
  const char* ruby_class_name() const override { return "Integer"; }
  // m_hash_value override — value-based so Integer keys hash
  // equal regardless of box identity.
  std::size_t m_hash_value() const override { return std::hash<int64_t>()(raw_); }
  int64_t raw_;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Integer(__Ts__...) {}
  virtual BasicObject* m_plus(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_minus(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_mul(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_div(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_mod(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lt(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_gt(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_le(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_ge(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eq_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_ne_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lshift(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_rshift(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_bit_and(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_bit_or(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_bit_xor(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_neg(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_i(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Float : Object {
  using Object::Object;
  explicit Float(double r) : raw_(r) {}
  const char* ruby_class_name() const override { return "Float"; }
  std::size_t m_hash_value() const override { return std::hash<double>()(raw_); }
  double raw_;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Float(__Ts__...) {}
  virtual BasicObject* m_plus(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_minus(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_mul(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_div(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lt(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_gt(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_le(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_ge(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eq_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_ne_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_neg(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_f(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Array : Object {
  using Object::Object;
  // Vector uses GcAllocator so the buffer stays scanned by Boehm.
  std::vector<BasicObject*, GcAllocator<BasicObject*>> data;
  Array() = default;
  Array(std::initializer_list<BasicObject*> init) : data(init.begin(), init.end()) {}
  // Array.new(size) / Array.new(size, fill)
  Array(BasicObject* size, BasicObject* fill = nullptr) {
    int64_t n = static_cast<Integer*>(size)->raw_;
    data.assign(n, fill ? fill : nil_instance());
  }
  const char* ruby_class_name() const override { return "Array"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Array(__Ts__...) {}
  virtual BasicObject* m_size(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_length(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_empty_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_first(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_last(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_aref(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_aset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_push(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lshift(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Symbol : Object {
  using Object::Object;
  const char* name_;
  private:
    explicit Symbol(const char* name) : name_(name) {}
    friend Symbol* intern(const char* name);
  public:
  const char* ruby_class_name() const override { return "Symbol"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Symbol(__Ts__...) {}
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_sym(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct String : Object {
  using Object::Object;
  enum Enc { UTF8 = 0, BINARY = 1 };
  std::vector<std::uint8_t, GcAllocator<std::uint8_t>> bytes;
  Enc enc = UTF8;
  mutable std::int64_t length_cache_ = -1;
  
  String() = default;
  String(const char* s) { if (s) { auto n = std::strlen(s); bytes.assign(s, s + n); } }
  String(const char* s, std::size_t n) { bytes.assign(s, s + n); }
  String(const char* s, std::size_t n, Enc e) : enc(e) { bytes.assign(s, s + n); }
  
  const char* ruby_class_name() const override { return "String"; }
  
  // Codepoint-aware length for UTF-8 (cached); byte count for BINARY.
  std::int64_t length() const {
    if (enc == BINARY) return static_cast<std::int64_t>(bytes.size());
    if (length_cache_ < 0) {
      std::int64_t n = 0;
      for (auto b : bytes) if ((b & 0xC0) != 0x80) n++;
      length_cache_ = n;
    }
    return length_cache_;
  }
  bool has_non_ascii() const { for (auto b : bytes) if (b >= 0x80) return true; return false; }
  
  // Hash on byte sequence — equal byte sequences hash equal.
  std::size_t m_hash_value() const override {
    std::size_t h = 0xcbf29ce484222325ULL;  // FNV-1a offset
    for (auto b : bytes) { h ^= b; h *= 0x100000001b3ULL; }
    return h;
  }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> String(__Ts__...) {}
  virtual BasicObject* m_size(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_length(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_bytesize(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_empty_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eq_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_ne_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lt(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_gt(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_le(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_ge(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_plus(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lshift(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_aref(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_ord(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_dup(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Hash : Object {
  using Object::Object;
  // Vtable-aware hash + key-equality.
  struct Hasher {
    std::size_t operator()(BasicObject* v) const { return v->m_hash_value(); }
  };
  struct KeyEq {
    bool operator()(BasicObject* a, BasicObject* b) const {
      Array tmp;
      tmp.data.push_back(b);
      return a->m_eq_q(&tmp, nullptr, nullptr) == true_instance();
    }
  };
  using map_t = std::unordered_map<
    BasicObject*, BasicObject*, Hasher, KeyEq,
    GcAllocator<std::pair<BasicObject* const, BasicObject*>>>;
  map_t data;
  Hash() = default;
  Hash(std::initializer_list<std::pair<BasicObject*, BasicObject*>> init) {
    for (auto& p : init) data.insert(p);
  }
  const char* ruby_class_name() const override { return "Hash"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Hash(__Ts__...) {}
  virtual BasicObject* m_size(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_length(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_empty_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_aref(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_aset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_include_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_has_key_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Proc : Object {
  using Object::Object;
  std::function<BasicObject*(BasicObject*)> fn_;
  explicit Proc(std::function<BasicObject*(BasicObject*)> f) : fn_(std::move(f)) {}
  const char* ruby_class_name() const override { return "Proc"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Proc(__Ts__...) {}
  virtual BasicObject* m_call(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct BasicObject_BasicObject : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "BasicObject_BasicObject"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> BasicObject_BasicObject(__Ts__...) {}
  virtual BasicObject* m_not(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_ne_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_respond_to_missing_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Module : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Module"; }
  BasicObject* iv___refinements__ = nullptr;
  BasicObject* iv___refinement__ = nullptr;
  BasicObject* iv___refined_class__ = nullptr;
  BasicObject* iv___refining_module__ = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Module(__Ts__...) {}
  virtual BasicObject* m_included(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_prepended(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_case_eq(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_included_modules(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_const_added(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_method_added(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_method_removed(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_method_undefined(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_singleton_method_added(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_singleton_method_removed(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_singleton_method_undefined(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_extended(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_refinements(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_include_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lt(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_gt(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_spaceship(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_le(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_ge(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_const_missing(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Numeric : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Numeric"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Numeric(__Ts__...) {}
  virtual BasicObject* m_integer_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_real_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_zero_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_positive_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_negative_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_finite_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_infinite_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_abs2(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_pos(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_neg(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_real(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_conj(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_conjugate(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_imag(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_imaginary(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_polar(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_rect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_rectangular(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_int(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_c(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_i(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_dup(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_nonzero_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_abs(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_magnitude(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eql_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_spaceship(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_ceil(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_floor(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_truncate(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_divmod(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_modulo(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_mod(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_fdiv(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_numerator(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_denominator(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_singleton_method_added(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_div(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_quo(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_coerce(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Refinement : Module {
  using Module::Module;
  const char* ruby_class_name() const override { return "Refinement"; }
  BasicObject* iv___refined_class__ = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Refinement(__Ts__...) {}
  virtual BasicObject* m_include(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_prepend(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_target(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_warn_ancestors(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Method : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Method"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Method(__Ts__...) {}
  virtual BasicObject* m_curry(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct UnboundMethod : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "UnboundMethod"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> UnboundMethod(__Ts__...) {}
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Range : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Range"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Range(__Ts__...) {}
  virtual BasicObject* m_sort(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_drop(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_entries(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_hash(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each_with_index(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_map(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_select(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_flat_map(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_collect_concat(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_sort_by(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_min_by(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_max_by(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_a(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_include_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_member_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_minmax(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eq_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eql_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_step(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_reduce(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_inject(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_last(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_mod(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_overlap_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each_slice(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each_cons(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_reverse_each(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_split(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___bsearch_size__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___cover_value___q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___step_float__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___bsearch_integer__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___bsearch_int_min__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___bsearch_int_any__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Enumerator : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Enumerator"; }
  BasicObject* iv_receiver = nullptr;
  BasicObject* iv_method_kwargs = nullptr;
  BasicObject* iv_method_name = nullptr;
  BasicObject* iv_method_args = nullptr;
  BasicObject* iv_fiber = nullptr;
  BasicObject* iv_feed = nullptr;
  BasicObject* iv_size_block = nullptr;
  BasicObject* iv__fiber_started = nullptr;
  BasicObject* iv__feed_pending = nullptr;
  BasicObject* iv_peeked = nullptr;
  BasicObject* iv_peeked_vals = nullptr;
  BasicObject* iv_size = nullptr;
  BasicObject* iv_block = nullptr;
  BasicObject* iv__enum_result = nullptr;
  Enumerator(BasicObject* size = nil_instance(), Proc* block = nullptr);
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Enumerator(__Ts__...) {}
  virtual BasicObject* m_next_values(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_peek_values(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_next(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_peek(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_with_object(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_plus(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_count(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_feed(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_rewind(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_size(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_first(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___advance__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___next_values_raw__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___peek_values_raw__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Enumerator_Yielder : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Enumerator_Yielder"; }
  BasicObject* iv_block = nullptr;
  Enumerator_Yielder(Proc* block = nullptr);
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Enumerator_Yielder(__Ts__...) {}
  virtual BasicObject* m_lshift(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_yield(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Enumerator_Generator : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Enumerator_Generator"; }
  BasicObject* iv_block = nullptr;
  Enumerator_Generator(Proc* block = nullptr);
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Enumerator_Generator(__Ts__...) {}
};

struct Enumerator_Lazy : Enumerator {
  using Enumerator::Enumerator;
  const char* ruby_class_name() const override { return "Enumerator_Lazy"; }
  BasicObject* iv__grouped_eval = nullptr;
  BasicObject* iv__xform_factory = nullptr;
  BasicObject* iv__lazy_xform = nullptr;
  BasicObject* iv_receiver = nullptr;
  BasicObject* iv__lazy_size = nullptr;
  BasicObject* iv_method_name = nullptr;
  BasicObject* iv_method_args = nullptr;
  BasicObject* iv_method_kwargs = nullptr;
  BasicObject* iv_size_block = nullptr;
  BasicObject* iv_size = nullptr;
  BasicObject* iv_block = nullptr;
  BasicObject* iv_fiber = nullptr;
  BasicObject* iv_peeked = nullptr;
  BasicObject* iv_peeked_vals = nullptr;
  BasicObject* iv_feed = nullptr;
  BasicObject* iv__feed_pending = nullptr;
  BasicObject* iv__fiber_started = nullptr;
  Enumerator_Lazy(BasicObject* obj, BasicObject* size = nil_instance(), Proc* block = nullptr);
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Enumerator_Lazy(__Ts__...) {}
  virtual BasicObject* m_lazy(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_with_object(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eager(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_first(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_size(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_map(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_collect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_select(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_filter(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_find_all(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_reject(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_flat_map(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_collect_concat(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_take_while(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_filter_map(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_compact(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_grep(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_grep_v(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each_with_object(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each_with_index(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Enumerator_Chain : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Enumerator_Chain"; }
  BasicObject* iv_enums = nullptr;
  BasicObject* iv__iterated_count = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Enumerator_Chain(__Ts__...) {}
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_rewind(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Enumerator_ArithmeticSequence : Enumerator {
  using Enumerator::Enumerator;
  const char* ruby_class_name() const override { return "Enumerator_ArithmeticSequence"; }
  BasicObject* iv_receiver = nullptr;
  BasicObject* iv_method_kwargs = nullptr;
  BasicObject* iv_method_args = nullptr;
  BasicObject* iv_size_block = nullptr;
  BasicObject* iv_method_name = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Enumerator_ArithmeticSequence(__Ts__...) {}
  virtual BasicObject* m_exclude_end_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_begin(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_hash(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_end(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_step(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_last(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Enumerator_Product : Enumerator {
  using Enumerator::Enumerator;
  const char* ruby_class_name() const override { return "Enumerator_Product"; }
  BasicObject* iv_enumerables = nullptr;
  BasicObject* iv_block = nullptr;
  BasicObject* iv_receiver = nullptr;
  BasicObject* iv_method_name = nullptr;
  BasicObject* iv_method_args = nullptr;
  BasicObject* iv_method_kwargs = nullptr;
  BasicObject* iv_size_block = nullptr;
  BasicObject* iv_size = nullptr;
  BasicObject* iv_fiber = nullptr;
  BasicObject* iv_peeked = nullptr;
  BasicObject* iv_peeked_vals = nullptr;
  BasicObject* iv_feed = nullptr;
  BasicObject* iv__feed_pending = nullptr;
  BasicObject* iv__fiber_started = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Enumerator_Product(__Ts__...) {}
  virtual BasicObject* m_rewind(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_initialize_copy(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Exception : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Exception"; }
  BasicObject* iv_backtrace = nullptr;
  BasicObject* iv_cause = nullptr;
  BasicObject* iv_message = nullptr;
  BasicObject* iv__has_locations = nullptr;
  BasicObject* iv_backtrace_locations = nullptr;
  Exception(BasicObject* message = nil_instance());
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Exception(__Ts__...) {}
  virtual BasicObject* m_message(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_backtrace(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_cause(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_backtrace_locations(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_exception(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eq_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct ScriptError : Exception {
  using Exception::Exception;
  const char* ruby_class_name() const override { return "ScriptError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ScriptError(__Ts__...) {}
};

struct LoadError : ScriptError {
  using ScriptError::ScriptError;
  const char* ruby_class_name() const override { return "LoadError"; }
  BasicObject* iv_path = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> LoadError(__Ts__...) {}
  virtual BasicObject* m_path(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct SyntaxError : ScriptError {
  using ScriptError::ScriptError;
  const char* ruby_class_name() const override { return "SyntaxError"; }
  BasicObject* iv_path = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> SyntaxError(__Ts__...) {}
  virtual BasicObject* m_path(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct NotImplementedError : ScriptError {
  using ScriptError::ScriptError;
  const char* ruby_class_name() const override { return "NotImplementedError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> NotImplementedError(__Ts__...) {}
};

struct SignalException : Exception {
  using Exception::Exception;
  const char* ruby_class_name() const override { return "SignalException"; }
  BasicObject* iv_signo = nullptr;
  BasicObject* iv_signm = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> SignalException(__Ts__...) {}
  virtual BasicObject* m_signo(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_signm(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Interrupt : SignalException {
  using SignalException::SignalException;
  const char* ruby_class_name() const override { return "Interrupt"; }
  BasicObject* iv_signo = nullptr;
  BasicObject* iv_signm = nullptr;
  BasicObject* iv_message = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Interrupt(__Ts__...) {}
};

struct SystemExit : Exception {
  using Exception::Exception;
  const char* ruby_class_name() const override { return "SystemExit"; }
  BasicObject* iv_status = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> SystemExit(__Ts__...) {}
  virtual BasicObject* m_status(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_success_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct StandardError : Exception {
  using Exception::Exception;
  const char* ruby_class_name() const override { return "StandardError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> StandardError(__Ts__...) {}
};

struct RuntimeError : StandardError {
  using StandardError::StandardError;
  const char* ruby_class_name() const override { return "RuntimeError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> RuntimeError(__Ts__...) {}
};

struct FrozenError : RuntimeError {
  using RuntimeError::RuntimeError;
  const char* ruby_class_name() const override { return "FrozenError"; }
  BasicObject* iv_receiver = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> FrozenError(__Ts__...) {}
  virtual BasicObject* m_receiver(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct NameError : StandardError {
  using StandardError::StandardError;
  const char* ruby_class_name() const override { return "NameError"; }
  BasicObject* iv_name = nullptr;
  BasicObject* iv_receiver = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> NameError(__Ts__...) {}
  virtual BasicObject* m_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_receiver(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct NoMethodError : NameError {
  using NameError::NameError;
  const char* ruby_class_name() const override { return "NoMethodError"; }
  BasicObject* iv_args = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> NoMethodError(__Ts__...) {}
  virtual BasicObject* m_args(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct TypeError : StandardError {
  using StandardError::StandardError;
  const char* ruby_class_name() const override { return "TypeError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> TypeError(__Ts__...) {}
};

struct ArgumentError : StandardError {
  using StandardError::StandardError;
  const char* ruby_class_name() const override { return "ArgumentError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ArgumentError(__Ts__...) {}
};

struct RangeError : StandardError {
  using StandardError::StandardError;
  const char* ruby_class_name() const override { return "RangeError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> RangeError(__Ts__...) {}
};

struct FloatDomainError : RangeError {
  using RangeError::RangeError;
  const char* ruby_class_name() const override { return "FloatDomainError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> FloatDomainError(__Ts__...) {}
};

struct ZeroDivisionError : StandardError {
  using StandardError::StandardError;
  const char* ruby_class_name() const override { return "ZeroDivisionError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ZeroDivisionError(__Ts__...) {}
};

struct IndexError : StandardError {
  using StandardError::StandardError;
  const char* ruby_class_name() const override { return "IndexError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IndexError(__Ts__...) {}
};

struct FiberError : StandardError {
  using StandardError::StandardError;
  const char* ruby_class_name() const override { return "FiberError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> FiberError(__Ts__...) {}
};

struct ThreadError : StandardError {
  using StandardError::StandardError;
  const char* ruby_class_name() const override { return "ThreadError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ThreadError(__Ts__...) {}
};

struct NoMemoryError : Exception {
  using Exception::Exception;
  const char* ruby_class_name() const override { return "NoMemoryError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> NoMemoryError(__Ts__...) {}
};

struct SecurityError : Exception {
  using Exception::Exception;
  const char* ruby_class_name() const override { return "SecurityError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> SecurityError(__Ts__...) {}
};

struct SystemStackError : Exception {
  using Exception::Exception;
  const char* ruby_class_name() const override { return "SystemStackError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> SystemStackError(__Ts__...) {}
};

struct NoMatchingPatternError : StandardError {
  using StandardError::StandardError;
  const char* ruby_class_name() const override { return "NoMatchingPatternError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> NoMatchingPatternError(__Ts__...) {}
};

struct KeyError : IndexError {
  using IndexError::IndexError;
  const char* ruby_class_name() const override { return "KeyError"; }
  BasicObject* iv_receiver = nullptr;
  BasicObject* iv_key = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> KeyError(__Ts__...) {}
  virtual BasicObject* m_receiver(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_key(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct StopIteration : IndexError {
  using IndexError::IndexError;
  const char* ruby_class_name() const override { return "StopIteration"; }
  BasicObject* iv_result = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> StopIteration(__Ts__...) {}
  virtual BasicObject* m_result(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct ClosedQueueError : StopIteration {
  using StopIteration::StopIteration;
  const char* ruby_class_name() const override { return "ClosedQueueError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ClosedQueueError(__Ts__...) {}
};

struct UncaughtThrowError : ArgumentError {
  using ArgumentError::ArgumentError;
  const char* ruby_class_name() const override { return "UncaughtThrowError"; }
  BasicObject* iv_tag = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> UncaughtThrowError(__Ts__...) {}
  virtual BasicObject* m_tag(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct LocalJumpError : StandardError {
  using StandardError::StandardError;
  const char* ruby_class_name() const override { return "LocalJumpError"; }
  BasicObject* iv_exit_value = nullptr;
  BasicObject* iv_reason = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> LocalJumpError(__Ts__...) {}
  virtual BasicObject* m_exit_value(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_reason(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct SystemCallError : StandardError {
  using StandardError::StandardError;
  const char* ruby_class_name() const override { return "SystemCallError"; }
  BasicObject* iv_errno = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> SystemCallError(__Ts__...) {}
  virtual BasicObject* m_errno(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct IOError : StandardError {
  using StandardError::StandardError;
  const char* ruby_class_name() const override { return "IOError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IOError(__Ts__...) {}
};

struct EOFError : IOError {
  using IOError::IOError;
  const char* ruby_class_name() const override { return "EOFError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> EOFError(__Ts__...) {}
};

struct EncodingError : StandardError {
  using StandardError::StandardError;
  const char* ruby_class_name() const override { return "EncodingError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> EncodingError(__Ts__...) {}
};

struct RegexpError : StandardError {
  using StandardError::StandardError;
  const char* ruby_class_name() const override { return "RegexpError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> RegexpError(__Ts__...) {}
};

struct Errno_E2BIG : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_E2BIG"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_E2BIG(__Ts__...) {}
};

struct Errno_EACCES : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EACCES"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EACCES(__Ts__...) {}
};

struct Errno_EADDRINUSE : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EADDRINUSE"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EADDRINUSE(__Ts__...) {}
};

struct Errno_EADDRNOTAVAIL : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EADDRNOTAVAIL"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EADDRNOTAVAIL(__Ts__...) {}
};

struct Errno_EAFNOSUPPORT : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EAFNOSUPPORT"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EAFNOSUPPORT(__Ts__...) {}
};

struct Errno_EAGAIN : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EAGAIN"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EAGAIN(__Ts__...) {}
};

struct Errno_EALREADY : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EALREADY"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EALREADY(__Ts__...) {}
};

struct Errno_EBADF : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EBADF"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EBADF(__Ts__...) {}
};

struct Errno_EBUSY : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EBUSY"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EBUSY(__Ts__...) {}
};

struct Errno_ECHILD : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ECHILD"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ECHILD(__Ts__...) {}
};

struct Errno_EILSEQ : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EILSEQ"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EILSEQ(__Ts__...) {}
};

struct Errno_ECONNABORTED : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ECONNABORTED"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ECONNABORTED(__Ts__...) {}
};

struct Errno_ECONNREFUSED : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ECONNREFUSED"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ECONNREFUSED(__Ts__...) {}
};

struct Errno_ECONNRESET : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ECONNRESET"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ECONNRESET(__Ts__...) {}
};

struct Errno_EDEADLK : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EDEADLK"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EDEADLK(__Ts__...) {}
};

struct Errno_EDOM : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EDOM"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EDOM(__Ts__...) {}
};

struct Errno_EEXIST : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EEXIST"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EEXIST(__Ts__...) {}
};

struct Errno_EFAULT : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EFAULT"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EFAULT(__Ts__...) {}
};

struct Errno_EFBIG : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EFBIG"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EFBIG(__Ts__...) {}
};

struct Errno_EHOSTUNREACH : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EHOSTUNREACH"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EHOSTUNREACH(__Ts__...) {}
};

struct Errno_EINPROGRESS : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EINPROGRESS"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EINPROGRESS(__Ts__...) {}
};

struct Errno_EINTR : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EINTR"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EINTR(__Ts__...) {}
};

struct Errno_EINVAL : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EINVAL"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EINVAL(__Ts__...) {}
};

struct Errno_EIO : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EIO"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EIO(__Ts__...) {}
};

struct Errno_EISCONN : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EISCONN"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EISCONN(__Ts__...) {}
};

struct Errno_EISDIR : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EISDIR"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EISDIR(__Ts__...) {}
};

struct Errno_ELOOP : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ELOOP"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ELOOP(__Ts__...) {}
};

struct Errno_EMFILE : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EMFILE"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EMFILE(__Ts__...) {}
};

struct Errno_EMSGSIZE : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EMSGSIZE"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EMSGSIZE(__Ts__...) {}
};

struct Errno_ENAMETOOLONG : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENAMETOOLONG"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENAMETOOLONG(__Ts__...) {}
};

struct Errno_ENETDOWN : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENETDOWN"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENETDOWN(__Ts__...) {}
};

struct Errno_ENETUNREACH : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENETUNREACH"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENETUNREACH(__Ts__...) {}
};

struct Errno_ENFILE : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENFILE"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENFILE(__Ts__...) {}
};

struct Errno_ENODEV : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENODEV"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENODEV(__Ts__...) {}
};

struct Errno_ENOENT : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENOENT"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOENT(__Ts__...) {}
};

struct Errno_ENOEXEC : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENOEXEC"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOEXEC(__Ts__...) {}
};

struct Errno_ENOMEM : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENOMEM"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOMEM(__Ts__...) {}
};

struct Errno_ENOSPC : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENOSPC"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOSPC(__Ts__...) {}
};

struct Errno_ENOSYS : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENOSYS"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOSYS(__Ts__...) {}
};

struct Errno_ENOTCONN : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENOTCONN"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOTCONN(__Ts__...) {}
};

struct Errno_ENOTDIR : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENOTDIR"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOTDIR(__Ts__...) {}
};

struct Errno_ENOTEMPTY : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENOTEMPTY"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOTEMPTY(__Ts__...) {}
};

struct Errno_ENOTSUP : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENOTSUP"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOTSUP(__Ts__...) {}
};

struct Errno_ENOTTY : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENOTTY"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOTTY(__Ts__...) {}
};

struct Errno_ENXIO : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ENXIO"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENXIO(__Ts__...) {}
};

struct Errno_EOPNOTSUPP : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EOPNOTSUPP"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EOPNOTSUPP(__Ts__...) {}
};

struct Errno_EOVERFLOW : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EOVERFLOW"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EOVERFLOW(__Ts__...) {}
};

struct Errno_EPERM : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EPERM"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EPERM(__Ts__...) {}
};

struct Errno_EPIPE : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EPIPE"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EPIPE(__Ts__...) {}
};

struct Errno_EPROTONOSUPPORT : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EPROTONOSUPPORT"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EPROTONOSUPPORT(__Ts__...) {}
};

struct Errno_ERANGE : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ERANGE"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ERANGE(__Ts__...) {}
};

struct Errno_EROFS : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EROFS"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EROFS(__Ts__...) {}
};

struct Errno_ESPIPE : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ESPIPE"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ESPIPE(__Ts__...) {}
};

struct Errno_ESRCH : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ESRCH"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ESRCH(__Ts__...) {}
};

struct Errno_ETIMEDOUT : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ETIMEDOUT"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ETIMEDOUT(__Ts__...) {}
};

struct Errno_ETXTBSY : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_ETXTBSY"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ETXTBSY(__Ts__...) {}
};

struct Errno_EWOULDBLOCK : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EWOULDBLOCK"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EWOULDBLOCK(__Ts__...) {}
};

struct Errno_EXDEV : SystemCallError {
  using SystemCallError::SystemCallError;
  const char* ruby_class_name() const override { return "Errno_EXDEV"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EXDEV(__Ts__...) {}
};

struct Math_DomainError : ArgumentError {
  using ArgumentError::ArgumentError;
  const char* ruby_class_name() const override { return "Math_DomainError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Math_DomainError(__Ts__...) {}
};

struct Encoding : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Encoding"; }
  BasicObject* iv_name = nullptr;
  Encoding(BasicObject* name);
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Encoding(__Ts__...) {}
  virtual BasicObject* m_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eq_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eql_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_ascii_only_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_replicate(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Encoding_CompatibilityError : EncodingError {
  using EncodingError::EncodingError;
  const char* ruby_class_name() const override { return "Encoding_CompatibilityError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Encoding_CompatibilityError(__Ts__...) {}
};

struct Encoding_ConverterNotFoundError : EncodingError {
  using EncodingError::EncodingError;
  const char* ruby_class_name() const override { return "Encoding_ConverterNotFoundError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Encoding_ConverterNotFoundError(__Ts__...) {}
};

struct Encoding_InvalidByteSequenceError : EncodingError {
  using EncodingError::EncodingError;
  const char* ruby_class_name() const override { return "Encoding_InvalidByteSequenceError"; }
  BasicObject* iv_source_encoding_name = nullptr;
  BasicObject* iv_destination_encoding_name = nullptr;
  BasicObject* iv_source_encoding = nullptr;
  BasicObject* iv_destination_encoding = nullptr;
  BasicObject* iv_error_bytes = nullptr;
  BasicObject* iv_readagain_bytes = nullptr;
  BasicObject* iv_incomplete_input = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Encoding_InvalidByteSequenceError(__Ts__...) {}
  virtual BasicObject* m_source_encoding_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_destination_encoding_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_source_encoding(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_destination_encoding(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_error_bytes(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_readagain_bytes(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_incomplete_input_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Encoding_UndefinedConversionError : EncodingError {
  using EncodingError::EncodingError;
  const char* ruby_class_name() const override { return "Encoding_UndefinedConversionError"; }
  BasicObject* iv_source_encoding_name = nullptr;
  BasicObject* iv_destination_encoding_name = nullptr;
  BasicObject* iv_source_encoding = nullptr;
  BasicObject* iv_destination_encoding = nullptr;
  BasicObject* iv_error_char = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Encoding_UndefinedConversionError(__Ts__...) {}
  virtual BasicObject* m_source_encoding_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_destination_encoding_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_source_encoding(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_destination_encoding(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_error_char(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Encoding_Converter : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Encoding_Converter"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Encoding_Converter(__Ts__...) {}
};

struct MatchData : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "MatchData"; }
  BasicObject* iv_string = nullptr;
  BasicObject* iv_regexp = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> MatchData(__Ts__...) {}
  virtual BasicObject* m_length(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_offset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_byteoffset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_hash(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_deconstruct(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_match(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eq_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eql_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Regexp : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Regexp"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Regexp(__Ts__...) {}
  virtual BasicObject* m_dup(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Regexp_TimeoutError : RegexpError {
  using RegexpError::RegexpError;
  const char* ruby_class_name() const override { return "Regexp_TimeoutError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Regexp_TimeoutError(__Ts__...) {}
};

struct Rational : Numeric {
  using Numeric::Numeric;
  const char* ruby_class_name() const override { return "Rational"; }
  BasicObject* iv_numerator = nullptr;
  BasicObject* iv_denominator = nullptr;
  Rational(BasicObject* numerator, BasicObject* denominator = (new Integer(1LL)));
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Rational(__Ts__...) {}
  virtual BasicObject* m_numerator(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_denominator(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_i(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_r(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_c(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_dup(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_divmod(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_abs(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_negative_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_positive_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_zero_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_nonzero_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_hash(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eql_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_quo(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_plus(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_minus(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_mul(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_div(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_pow(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eq_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_coerce(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_f(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_floor(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_ceil(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_truncate(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_mod(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_modulo(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_remainder(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_rationalize(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_marshal_dump(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___simplest_rational__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_marshal_load(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Complex : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Complex"; }
  BasicObject* iv_real = nullptr;
  BasicObject* iv_imaginary = nullptr;
  Complex(BasicObject* real, BasicObject* imaginary = (new Integer(0LL)));
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Complex(__Ts__...) {}
  virtual BasicObject* m_real(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_imaginary(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_imag(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_real_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_abs2(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_rect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_rectangular(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_conj(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_conjugate(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_c(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_dup(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_integer_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_zero_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_nonzero_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_quo(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_hash(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_neg(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_polar(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_plus(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_minus(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_mul(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_div(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eq_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_spaceship(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_numerator(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_denominator(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_rationalize(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_f(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_i(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_r(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_finite_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_infinite_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_coerce(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_fdiv(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eql_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_marshal_dump(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___ensure_real_strict__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___complex_coerce_op__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct IO : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "IO"; }
  BasicObject* iv_lineno = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IO(__Ts__...) {}
  virtual BasicObject* m_puts(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___puts_scalar__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lshift(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eof(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_tty_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_tell(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_path(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_io(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_size(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_printf(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each_codepoint(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_bytes(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_chars(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_codepoints(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_putc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct IO_CapturedOutput : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "IO_CapturedOutput"; }
  BasicObject* iv_str = nullptr;
  IO_CapturedOutput(BasicObject* str);
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IO_CapturedOutput(__Ts__...) {}
  virtual BasicObject* m_read(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_gets(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_close(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct IO_EAGAINWaitReadable : Errno_EAGAIN {
  using Errno_EAGAIN::Errno_EAGAIN;
  const char* ruby_class_name() const override { return "IO_EAGAINWaitReadable"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IO_EAGAINWaitReadable(__Ts__...) {}
};

struct IO_EAGAINWaitWritable : Errno_EAGAIN {
  using Errno_EAGAIN::Errno_EAGAIN;
  const char* ruby_class_name() const override { return "IO_EAGAINWaitWritable"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IO_EAGAINWaitWritable(__Ts__...) {}
};

struct IO_EWOULDBLOCKWaitReadable : Errno_EAGAIN {
  using Errno_EAGAIN::Errno_EAGAIN;
  const char* ruby_class_name() const override { return "IO_EWOULDBLOCKWaitReadable"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IO_EWOULDBLOCKWaitReadable(__Ts__...) {}
};

struct IO_EWOULDBLOCKWaitWritable : Errno_EAGAIN {
  using Errno_EAGAIN::Errno_EAGAIN;
  const char* ruby_class_name() const override { return "IO_EWOULDBLOCKWaitWritable"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IO_EWOULDBLOCKWaitWritable(__Ts__...) {}
};

struct File : IO {
  using IO::IO;
  const char* ruby_class_name() const override { return "File"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> File(__Ts__...) {}
  virtual BasicObject* m_chown(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lstat(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct File_Stat : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "File_Stat"; }
  BasicObject* iv_path = nullptr;
  BasicObject* iv_native_stat = nullptr;
  BasicObject* iv_lstat = nullptr;
  BasicObject* iv_stat = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> File_Stat(__Ts__...) {}
  virtual BasicObject* m_file_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_directory_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_symlink_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_pipe_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_socket_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_blockdev_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_chardev_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_setuid_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_setgid_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_sticky_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_zero_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_empty_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_size_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_readable_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_readable_real_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_writable_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_writable_real_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_executable_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_executable_real_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_owned_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_grpowned_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_ftype(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_world_readable_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_world_writable_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Dir : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Dir"; }
  BasicObject* iv_path = nullptr;
  BasicObject* iv_encoding = nullptr;
  BasicObject* iv_dir = nullptr;
  BasicObject* iv_closed = nullptr;
  BasicObject* iv_entries = nullptr;
  BasicObject* iv_pos = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Dir(__Ts__...) {}
  virtual BasicObject* m_path(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_path(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_closed_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_children(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_entries(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_pos(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_tell(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each_child(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___load_entries__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Time : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Time"; }
  BasicObject* iv_frozone_timezone = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Time(__Ts__...) {}
  virtual BasicObject* m_day(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_mon(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_gmt_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_isdst(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_hash(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_tv_sec(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_tv_usec(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_tv_nsec(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_gmtime(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_getgm(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_gmt_offset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_gmtoff(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_ctime(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_xmlschema(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_monday_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_tuesday_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_wednesday_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_thursday_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_friday_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_saturday_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_sunday_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_a(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eql_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_time(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_httpdate(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_deconstruct_keys(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_spaceship(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_rfc2822(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_rfc822(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m__coerce_exact_number(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Mutex : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Mutex"; }
  BasicObject* iv_locked = nullptr;
  BasicObject* iv_owner = nullptr;
  BasicObject* iv_owner_fiber = nullptr;
  Mutex();
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Mutex(__Ts__...) {}
  virtual BasicObject* m_locked_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_owned_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_unlock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___force_unlock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_try_lock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_synchronize(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Fiber : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Fiber"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Fiber(__Ts__...) {}
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct ThreadKill : Exception {
  using Exception::Exception;
  const char* ruby_class_name() const override { return "ThreadKill"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ThreadKill(__Ts__...) {}
};

struct Thread : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Thread"; }
  BasicObject* iv_stop_seen = nullptr;
  BasicObject* iv_wakeup_count = nullptr;
  BasicObject* iv_mutex_skip_count = nullptr;
  BasicObject* iv_mutex_seen_count = nullptr;
  BasicObject* iv_mutex_done_count = nullptr;
  BasicObject* iv_raise_exception = nullptr;
  BasicObject* iv_raise_cause = nullptr;
  BasicObject* iv_raise_backtrace = nullptr;
  BasicObject* iv_done = nullptr;
  BasicObject* iv_aborting = nullptr;
  BasicObject* iv_executing = nullptr;
  BasicObject* iv_run_yielded = nullptr;
  BasicObject* iv_report_on_exception = nullptr;
  BasicObject* iv_abort_on_exception = nullptr;
  BasicObject* iv_exception = nullptr;
  BasicObject* iv_source_location_str = nullptr;
  BasicObject* iv_block = nullptr;
  BasicObject* iv_result = nullptr;
  BasicObject* iv_name = nullptr;
  BasicObject* iv_thread_vars = nullptr;
  BasicObject* iv_fiber_vars = nullptr;
  BasicObject* iv_owned_mutexes = nullptr;
  BasicObject* iv_group = nullptr;
  BasicObject* iv___initialized__ = nullptr;
  BasicObject* iv_self_killed = nullptr;
  BasicObject* iv_priority = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Thread(__Ts__...) {}
  virtual BasicObject* m___stop_seen(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___stop_seen_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___wakeup_count(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___wakeup_count_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___mutex_skip_count(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___mutex_skip_count_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___mutex_seen_count(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___mutex_seen_count_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___mutex_done_count(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___mutex_done_count_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___raise_exception(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___raise_exception_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___raise_cause(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___raise_cause_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___raise_backtrace(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___raise_backtrace_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_alive_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_stop_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_report_on_exception_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_report_on_exception(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_abort_on_exception_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_abort_on_exception(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_status(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_wakeup(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_run(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_priority(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_native_thread_id(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_group(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___set_group(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_pending_interrupt_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_add_trace_func(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_set_trace_func(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_priority_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___init_main(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___add_owned_mutex(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___remove_owned_mutex(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_thread_variable_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_thread_variable_get(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_thread_variable_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_thread_variables(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_aref(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_aset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_key_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_keys(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Thread_Blocked : Exception {
  using Exception::Exception;
  const char* ruby_class_name() const override { return "Thread_Blocked"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Thread_Blocked(__Ts__...) {}
};

struct Thread_Mutex : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Thread_Mutex"; }
  BasicObject* iv_locked = nullptr;
  BasicObject* iv_owner = nullptr;
  BasicObject* iv_owner_fiber = nullptr;
  Thread_Mutex();
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Thread_Mutex(__Ts__...) {}
  virtual BasicObject* m_locked_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_owned_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_unlock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___force_unlock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_try_lock(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_synchronize(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Thread_Backtrace : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Thread_Backtrace"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Thread_Backtrace(__Ts__...) {}
};

struct Thread_Backtrace_Location : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Thread_Backtrace_Location"; }
  BasicObject* iv_path = nullptr;
  BasicObject* iv_lineno = nullptr;
  BasicObject* iv_label = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Thread_Backtrace_Location(__Ts__...) {}
  virtual BasicObject* m_path(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lineno(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_label(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct ThreadGroup : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "ThreadGroup"; }
  BasicObject* iv_threads = nullptr;
  BasicObject* iv_enclosed = nullptr;
  ThreadGroup();
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ThreadGroup(__Ts__...) {}
  virtual BasicObject* m_enclosed_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___add_thread(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___remove_thread(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_enclose(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_add(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct ConditionVariable : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "ConditionVariable"; }
  BasicObject* iv_waiters = nullptr;
  ConditionVariable();
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ConditionVariable(__Ts__...) {}
  virtual BasicObject* m_signal(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_broadcast(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_marshal_dump(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_wait(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Queue : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Queue"; }
  BasicObject* iv_data = nullptr;
  BasicObject* iv_waiters = nullptr;
  BasicObject* iv_closed = nullptr;
  BasicObject* iv_deadlines = nullptr;
  Queue(BasicObject* enumerable = nil_instance());
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Queue(__Ts__...) {}
  virtual BasicObject* m_empty_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_size(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_length(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_clear(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_num_waiting(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_closed_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_freeze(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_close(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_push(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_enq(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lshift(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct SizedQueue : Queue {
  using Queue::Queue;
  const char* ruby_class_name() const override { return "SizedQueue"; }
  BasicObject* iv_max = nullptr;
  BasicObject* iv_waiters = nullptr;
  BasicObject* iv_push_waiters = nullptr;
  BasicObject* iv_push_deadlines = nullptr;
  BasicObject* iv_closed = nullptr;
  BasicObject* iv_data = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> SizedQueue(__Ts__...) {}
  virtual BasicObject* m_max(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_num_waiting(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_max_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Process : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Process"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Process(__Ts__...) {}
};

struct Process_Status : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Process_Status"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Process_Status(__Ts__...) {}
  virtual BasicObject* m_success_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_signaled_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_stopped_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_stopsig(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_coredump_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_exited_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_i(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Binding : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Binding"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Binding(__Ts__...) {}
};

struct PP : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "PP"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> PP(__Ts__...) {}
};

struct StringIO : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "StringIO"; }
  BasicObject* iv_lineno = nullptr;
  BasicObject* iv_readable = nullptr;
  BasicObject* iv_writable = nullptr;
  BasicObject* iv_append = nullptr;
  BasicObject* iv_truncate = nullptr;
  BasicObject* iv_string = nullptr;
  BasicObject* iv_pos = nullptr;
  BasicObject* iv_closed_r = nullptr;
  BasicObject* iv_closed_w = nullptr;
  BasicObject* iv_binary = nullptr;
  BasicObject* iv_sync = nullptr;
  BasicObject* iv_external_encoding = nullptr;
  BasicObject* iv_internal_encoding = nullptr;
  BasicObject* iv_explicit_encoding = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> StringIO(__Ts__...) {}
  virtual BasicObject* m_lineno(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lineno_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_string(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_string_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_size(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_length(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_pos(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_pos_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_tell(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_rewind(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eof_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eof(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_binmode_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_external_encoding(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_internal_encoding(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_closed_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_closed_read_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_closed_write_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_close(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_close_read(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_close_write(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_readbyte(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_readchar(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_getc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_getbyte(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lshift(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_putc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_truncate(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_bytes(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_chars(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lines(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_codepoints(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each_byte(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each_char(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each_codepoint(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_readpartial(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_flush(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_sync(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_sync_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_fsync(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_fileno(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_isatty(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_tty_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_pid(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_fcntl(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_ioctl(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_stat(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_io(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_readable_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_writable_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_readable_real_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_writable_real_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m__check_open(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m__check_readable(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m__check_writable(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m__chomp(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Struct : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Struct"; }
  BasicObject* iv_struct_values = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Struct(__Ts__...) {}
  virtual BasicObject* m_members(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_a(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_values(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_size(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_length(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_deconstruct(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_aref(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_aset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each_pair(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_dig(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Data : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Data"; }
  BasicObject* iv_data_values = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Data(__Ts__...) {}
  virtual BasicObject* m_members(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_deconstruct(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eql_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Set : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Set"; }
  BasicObject* iv_hash = nullptr;
  BasicObject* iv_iterating = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Set(__Ts__...) {}
  virtual BasicObject* m_include_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_member_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_case_eq(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_size(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_length(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_empty_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_to_a(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eql_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_disjoint_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_join(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_compare_by_identity_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_pretty_print(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_pretty_print_cycle(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_add(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lshift(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_add_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_delete(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_delete_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_delete_if(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_keep_if(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_select_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_filter_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_reject_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_clear(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_collect_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_map_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_flatten(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_flatten_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eq_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_spaceship(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_bit_and(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_intersection(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_bit_or(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_union(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_plus(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_minus(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_difference(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_bit_xor(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_subset_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_proper_subset_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_superset_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_proper_superset_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_intersect_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_compare_by_identity(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_dup(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___do_flatten__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Random : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Random"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Random(__Ts__...) {}
  virtual BasicObject* m_eq_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct ObjectSpace_WeakMap : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "ObjectSpace_WeakMap"; }
  BasicObject* iv_pairs = nullptr;
  ObjectSpace_WeakMap();
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ObjectSpace_WeakMap(__Ts__...) {}
  virtual BasicObject* m_size(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_length(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m__weakmap_inspect_obj(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct ObjectSpace_WeakKeyMap : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "ObjectSpace_WeakKeyMap"; }
  BasicObject* iv_pairs = nullptr;
  ObjectSpace_WeakKeyMap();
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ObjectSpace_WeakKeyMap(__Ts__...) {}
  virtual BasicObject* m_inspect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_aset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_aref(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_key_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_delete(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_getkey(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_clear(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___ungcable___q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct ENVClass : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "ENVClass"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ENVClass(__Ts__...) {}
  virtual BasicObject* m_to_s(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_rehash(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_eq_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_dup(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Gem_Specification : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Gem_Specification"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Gem_Specification(__Ts__...) {}
};

struct Marshal_Dumper : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Marshal_Dumper"; }
  BasicObject* iv_limit = nullptr;
  BasicObject* iv_depth = nullptr;
  BasicObject* iv_symbols = nullptr;
  BasicObject* iv_objects = nullptr;
  BasicObject* iv_out = nullptr;
  Marshal_Dumper(BasicObject* limit);
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Marshal_Dumper(__Ts__...) {}
  virtual BasicObject* m_dump(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_respond_to_marshal_dump_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_respond_to__dump_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_real_class_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_real_module_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_write_object(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_isa_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_track(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_bignum_to_bytes(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_encoding_ivar(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_collect_ivars(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_extended_modules(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_write_class_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_write_module_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_check_anonymous(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Marshal_Loader : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Marshal_Loader"; }
  BasicObject* iv_data = nullptr;
  BasicObject* iv_pos = nullptr;
  BasicObject* iv_symbols = nullptr;
  BasicObject* iv_objects = nullptr;
  BasicObject* iv_proc = nullptr;
  BasicObject* iv_freeze = nullptr;
  BasicObject* iv_no_link_proc = nullptr;
  BasicObject* iv_completed = nullptr;
  BasicObject* iv_string_dedup = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Marshal_Loader(__Ts__...) {}
  virtual BasicObject* m_read_ivar(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_byte(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_bytes(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_peek_byte(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_long(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_track(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_call_proc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_freeze_object(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_symbol(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_array(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_hash(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_class_ref(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_module_ref(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_old_module_ref(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_class_by_name(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_class_by_symbol(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_user_defined_body(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_struct_body(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_generic_object_body(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_link(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_uclass(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_user_defined(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_user_marshal(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_extended(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_read_data_object(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Frozone_Vm_Vm : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Frozone_Vm_Vm"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Frozone_Vm_Vm(__Ts__...) {}
};

struct Frozone_Vm_Parser : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Frozone_Vm_Parser"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Frozone_Vm_Parser(__Ts__...) {}
};

struct Frozone_Vm_WqParser : Object {
  using Object::Object;
  const char* ruby_class_name() const override { return "Frozone_Vm_WqParser"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Frozone_Vm_WqParser(__Ts__...) {}
};

struct BasicObject_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "BasicObject"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> BasicObject_eigenclass(__Ts__...) {}
};

struct Object_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Object"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Object_eigenclass(__Ts__...) {}
};

struct Class_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Class"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Class_eigenclass(__Ts__...) {}
};

struct NilClass_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "NilClass"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> NilClass_eigenclass(__Ts__...) {}
};

struct TrueClass_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "TrueClass"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> TrueClass_eigenclass(__Ts__...) {}
};

struct FalseClass_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "FalseClass"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> FalseClass_eigenclass(__Ts__...) {}
};

struct Integer_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Integer"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Integer_eigenclass(__Ts__...) {}
};

struct Float_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Float"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Float_eigenclass(__Ts__...) {}
};

struct Array_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Array"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Array_eigenclass(__Ts__...) {}
};

struct Symbol_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Symbol"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Symbol_eigenclass(__Ts__...) {}
};

struct String_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "String"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> String_eigenclass(__Ts__...) {}
};

struct Hash_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Hash"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Hash_eigenclass(__Ts__...) {}
};

struct Proc_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Proc"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Proc_eigenclass(__Ts__...) {}
};

struct BasicObject_BasicObject_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "BasicObject_BasicObject"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> BasicObject_BasicObject_eigenclass(__Ts__...) {}
};

struct Module_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Module"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Module_eigenclass(__Ts__...) {}
};

struct Numeric_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Numeric"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Numeric_eigenclass(__Ts__...) {}
};

struct Refinement_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Refinement"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Refinement_eigenclass(__Ts__...) {}
};

struct Method_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Method"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Method_eigenclass(__Ts__...) {}
};

struct UnboundMethod_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "UnboundMethod"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> UnboundMethod_eigenclass(__Ts__...) {}
};

struct Range_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Range"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Range_eigenclass(__Ts__...) {}
  virtual BasicObject* m_new(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Enumerator_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Enumerator"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Enumerator_eigenclass(__Ts__...) {}
  virtual BasicObject* m__from_method(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_produce(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Enumerator_Yielder_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Enumerator_Yielder"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Enumerator_Yielder_eigenclass(__Ts__...) {}
};

struct Enumerator_Generator_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Enumerator_Generator"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Enumerator_Generator_eigenclass(__Ts__...) {}
};

struct Enumerator_Lazy_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Enumerator_Lazy"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Enumerator_Lazy_eigenclass(__Ts__...) {}
};

struct Enumerator_Chain_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Enumerator_Chain"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Enumerator_Chain_eigenclass(__Ts__...) {}
};

struct Enumerator_ArithmeticSequence_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Enumerator_ArithmeticSequence"; }
  BasicObject* iv__internal_allocate = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Enumerator_ArithmeticSequence_eigenclass(__Ts__...) {}
};

struct Enumerator_Product_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Enumerator_Product"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Enumerator_Product_eigenclass(__Ts__...) {}
};

struct Exception_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Exception"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Exception_eigenclass(__Ts__...) {}
  virtual BasicObject* m_exception(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct ScriptError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "ScriptError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ScriptError_eigenclass(__Ts__...) {}
};

struct LoadError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "LoadError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> LoadError_eigenclass(__Ts__...) {}
};

struct SyntaxError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "SyntaxError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> SyntaxError_eigenclass(__Ts__...) {}
};

struct NotImplementedError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "NotImplementedError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> NotImplementedError_eigenclass(__Ts__...) {}
};

struct SignalException_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "SignalException"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> SignalException_eigenclass(__Ts__...) {}
};

struct Interrupt_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Interrupt"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Interrupt_eigenclass(__Ts__...) {}
};

struct SystemExit_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "SystemExit"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> SystemExit_eigenclass(__Ts__...) {}
};

struct StandardError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "StandardError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> StandardError_eigenclass(__Ts__...) {}
};

struct RuntimeError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "RuntimeError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> RuntimeError_eigenclass(__Ts__...) {}
};

struct FrozenError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "FrozenError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> FrozenError_eigenclass(__Ts__...) {}
};

struct NameError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "NameError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> NameError_eigenclass(__Ts__...) {}
};

struct NoMethodError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "NoMethodError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> NoMethodError_eigenclass(__Ts__...) {}
};

struct TypeError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "TypeError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> TypeError_eigenclass(__Ts__...) {}
};

struct ArgumentError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "ArgumentError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ArgumentError_eigenclass(__Ts__...) {}
};

struct RangeError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "RangeError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> RangeError_eigenclass(__Ts__...) {}
};

struct FloatDomainError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "FloatDomainError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> FloatDomainError_eigenclass(__Ts__...) {}
};

struct ZeroDivisionError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "ZeroDivisionError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ZeroDivisionError_eigenclass(__Ts__...) {}
};

struct IndexError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "IndexError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IndexError_eigenclass(__Ts__...) {}
};

struct FiberError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "FiberError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> FiberError_eigenclass(__Ts__...) {}
};

struct ThreadError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "ThreadError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ThreadError_eigenclass(__Ts__...) {}
};

struct NoMemoryError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "NoMemoryError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> NoMemoryError_eigenclass(__Ts__...) {}
};

struct SecurityError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "SecurityError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> SecurityError_eigenclass(__Ts__...) {}
};

struct SystemStackError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "SystemStackError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> SystemStackError_eigenclass(__Ts__...) {}
};

struct NoMatchingPatternError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "NoMatchingPatternError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> NoMatchingPatternError_eigenclass(__Ts__...) {}
};

struct KeyError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "KeyError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> KeyError_eigenclass(__Ts__...) {}
};

struct StopIteration_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "StopIteration"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> StopIteration_eigenclass(__Ts__...) {}
};

struct ClosedQueueError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "ClosedQueueError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ClosedQueueError_eigenclass(__Ts__...) {}
};

struct UncaughtThrowError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "UncaughtThrowError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> UncaughtThrowError_eigenclass(__Ts__...) {}
};

struct LocalJumpError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "LocalJumpError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> LocalJumpError_eigenclass(__Ts__...) {}
};

struct SystemCallError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "SystemCallError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> SystemCallError_eigenclass(__Ts__...) {}
};

struct IOError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "IOError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IOError_eigenclass(__Ts__...) {}
};

struct EOFError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "EOFError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> EOFError_eigenclass(__Ts__...) {}
};

struct EncodingError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "EncodingError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> EncodingError_eigenclass(__Ts__...) {}
};

struct RegexpError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "RegexpError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> RegexpError_eigenclass(__Ts__...) {}
};

struct Errno_E2BIG_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_E2BIG"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_E2BIG_eigenclass(__Ts__...) {}
};

struct Errno_EACCES_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EACCES"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EACCES_eigenclass(__Ts__...) {}
};

struct Errno_EADDRINUSE_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EADDRINUSE"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EADDRINUSE_eigenclass(__Ts__...) {}
};

struct Errno_EADDRNOTAVAIL_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EADDRNOTAVAIL"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EADDRNOTAVAIL_eigenclass(__Ts__...) {}
};

struct Errno_EAFNOSUPPORT_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EAFNOSUPPORT"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EAFNOSUPPORT_eigenclass(__Ts__...) {}
};

struct Errno_EAGAIN_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EAGAIN"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EAGAIN_eigenclass(__Ts__...) {}
};

struct Errno_EALREADY_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EALREADY"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EALREADY_eigenclass(__Ts__...) {}
};

struct Errno_EBADF_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EBADF"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EBADF_eigenclass(__Ts__...) {}
};

struct Errno_EBUSY_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EBUSY"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EBUSY_eigenclass(__Ts__...) {}
};

struct Errno_ECHILD_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ECHILD"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ECHILD_eigenclass(__Ts__...) {}
};

struct Errno_EILSEQ_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EILSEQ"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EILSEQ_eigenclass(__Ts__...) {}
};

struct Errno_ECONNABORTED_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ECONNABORTED"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ECONNABORTED_eigenclass(__Ts__...) {}
};

struct Errno_ECONNREFUSED_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ECONNREFUSED"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ECONNREFUSED_eigenclass(__Ts__...) {}
};

struct Errno_ECONNRESET_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ECONNRESET"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ECONNRESET_eigenclass(__Ts__...) {}
};

struct Errno_EDEADLK_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EDEADLK"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EDEADLK_eigenclass(__Ts__...) {}
};

struct Errno_EDOM_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EDOM"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EDOM_eigenclass(__Ts__...) {}
};

struct Errno_EEXIST_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EEXIST"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EEXIST_eigenclass(__Ts__...) {}
};

struct Errno_EFAULT_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EFAULT"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EFAULT_eigenclass(__Ts__...) {}
};

struct Errno_EFBIG_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EFBIG"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EFBIG_eigenclass(__Ts__...) {}
};

struct Errno_EHOSTUNREACH_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EHOSTUNREACH"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EHOSTUNREACH_eigenclass(__Ts__...) {}
};

struct Errno_EINPROGRESS_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EINPROGRESS"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EINPROGRESS_eigenclass(__Ts__...) {}
};

struct Errno_EINTR_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EINTR"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EINTR_eigenclass(__Ts__...) {}
};

struct Errno_EINVAL_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EINVAL"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EINVAL_eigenclass(__Ts__...) {}
};

struct Errno_EIO_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EIO"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EIO_eigenclass(__Ts__...) {}
};

struct Errno_EISCONN_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EISCONN"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EISCONN_eigenclass(__Ts__...) {}
};

struct Errno_EISDIR_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EISDIR"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EISDIR_eigenclass(__Ts__...) {}
};

struct Errno_ELOOP_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ELOOP"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ELOOP_eigenclass(__Ts__...) {}
};

struct Errno_EMFILE_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EMFILE"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EMFILE_eigenclass(__Ts__...) {}
};

struct Errno_EMSGSIZE_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EMSGSIZE"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EMSGSIZE_eigenclass(__Ts__...) {}
};

struct Errno_ENAMETOOLONG_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENAMETOOLONG"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENAMETOOLONG_eigenclass(__Ts__...) {}
};

struct Errno_ENETDOWN_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENETDOWN"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENETDOWN_eigenclass(__Ts__...) {}
};

struct Errno_ENETUNREACH_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENETUNREACH"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENETUNREACH_eigenclass(__Ts__...) {}
};

struct Errno_ENFILE_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENFILE"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENFILE_eigenclass(__Ts__...) {}
};

struct Errno_ENODEV_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENODEV"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENODEV_eigenclass(__Ts__...) {}
};

struct Errno_ENOENT_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENOENT"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOENT_eigenclass(__Ts__...) {}
};

struct Errno_ENOEXEC_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENOEXEC"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOEXEC_eigenclass(__Ts__...) {}
};

struct Errno_ENOMEM_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENOMEM"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOMEM_eigenclass(__Ts__...) {}
};

struct Errno_ENOSPC_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENOSPC"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOSPC_eigenclass(__Ts__...) {}
};

struct Errno_ENOSYS_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENOSYS"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOSYS_eigenclass(__Ts__...) {}
};

struct Errno_ENOTCONN_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENOTCONN"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOTCONN_eigenclass(__Ts__...) {}
};

struct Errno_ENOTDIR_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENOTDIR"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOTDIR_eigenclass(__Ts__...) {}
};

struct Errno_ENOTEMPTY_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENOTEMPTY"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOTEMPTY_eigenclass(__Ts__...) {}
};

struct Errno_ENOTSUP_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENOTSUP"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOTSUP_eigenclass(__Ts__...) {}
};

struct Errno_ENOTTY_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENOTTY"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENOTTY_eigenclass(__Ts__...) {}
};

struct Errno_ENXIO_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ENXIO"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ENXIO_eigenclass(__Ts__...) {}
};

struct Errno_EOPNOTSUPP_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EOPNOTSUPP"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EOPNOTSUPP_eigenclass(__Ts__...) {}
};

struct Errno_EOVERFLOW_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EOVERFLOW"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EOVERFLOW_eigenclass(__Ts__...) {}
};

struct Errno_EPERM_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EPERM"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EPERM_eigenclass(__Ts__...) {}
};

struct Errno_EPIPE_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EPIPE"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EPIPE_eigenclass(__Ts__...) {}
};

struct Errno_EPROTONOSUPPORT_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EPROTONOSUPPORT"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EPROTONOSUPPORT_eigenclass(__Ts__...) {}
};

struct Errno_ERANGE_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ERANGE"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ERANGE_eigenclass(__Ts__...) {}
};

struct Errno_EROFS_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EROFS"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EROFS_eigenclass(__Ts__...) {}
};

struct Errno_ESPIPE_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ESPIPE"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ESPIPE_eigenclass(__Ts__...) {}
};

struct Errno_ESRCH_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ESRCH"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ESRCH_eigenclass(__Ts__...) {}
};

struct Errno_ETIMEDOUT_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ETIMEDOUT"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ETIMEDOUT_eigenclass(__Ts__...) {}
};

struct Errno_ETXTBSY_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_ETXTBSY"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_ETXTBSY_eigenclass(__Ts__...) {}
};

struct Errno_EWOULDBLOCK_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EWOULDBLOCK"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EWOULDBLOCK_eigenclass(__Ts__...) {}
};

struct Errno_EXDEV_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Errno_EXDEV"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Errno_EXDEV_eigenclass(__Ts__...) {}
};

struct Math_DomainError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Math_DomainError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Math_DomainError_eigenclass(__Ts__...) {}
};

struct Encoding_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Encoding"; }
  BasicObject* iv_default_external = nullptr;
  BasicObject* iv_default_internal = nullptr;
  BasicObject* iv_find_map = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Encoding_eigenclass(__Ts__...) {}
  virtual BasicObject* m_default_internal(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_find(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Encoding_CompatibilityError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Encoding_CompatibilityError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Encoding_CompatibilityError_eigenclass(__Ts__...) {}
};

struct Encoding_ConverterNotFoundError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Encoding_ConverterNotFoundError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Encoding_ConverterNotFoundError_eigenclass(__Ts__...) {}
};

struct Encoding_InvalidByteSequenceError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Encoding_InvalidByteSequenceError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Encoding_InvalidByteSequenceError_eigenclass(__Ts__...) {}
};

struct Encoding_UndefinedConversionError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Encoding_UndefinedConversionError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Encoding_UndefinedConversionError_eigenclass(__Ts__...) {}
};

struct Encoding_Converter_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Encoding_Converter"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Encoding_Converter_eigenclass(__Ts__...) {}
};

struct MatchData_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "MatchData"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> MatchData_eigenclass(__Ts__...) {}
  virtual BasicObject* m_allocate(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Regexp_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Regexp"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Regexp_eigenclass(__Ts__...) {}
  virtual BasicObject* m_try_convert(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Regexp_TimeoutError_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Regexp_TimeoutError"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Regexp_TimeoutError_eigenclass(__Ts__...) {}
};

struct Rational_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Rational"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Rational_eigenclass(__Ts__...) {}
  virtual BasicObject* m_new(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Complex_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Complex"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Complex_eigenclass(__Ts__...) {}
  virtual BasicObject* m_rect(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_rectangular(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m__real_check(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct IO_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "IO"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IO_eigenclass(__Ts__...) {}
  virtual BasicObject* m_binread(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___coerce_path__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct IO_CapturedOutput_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "IO_CapturedOutput"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IO_CapturedOutput_eigenclass(__Ts__...) {}
};

struct IO_EAGAINWaitReadable_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "IO_EAGAINWaitReadable"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IO_EAGAINWaitReadable_eigenclass(__Ts__...) {}
};

struct IO_EAGAINWaitWritable_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "IO_EAGAINWaitWritable"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IO_EAGAINWaitWritable_eigenclass(__Ts__...) {}
};

struct IO_EWOULDBLOCKWaitReadable_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "IO_EWOULDBLOCKWaitReadable"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IO_EWOULDBLOCKWaitReadable_eigenclass(__Ts__...) {}
};

struct IO_EWOULDBLOCKWaitWritable_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "IO_EWOULDBLOCKWaitWritable"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> IO_EWOULDBLOCKWaitWritable_eigenclass(__Ts__...) {}
};

struct File_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "File"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> File_eigenclass(__Ts__...) {}
  virtual BasicObject* m_lchown(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_lchmod(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_fnmatch_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_chown(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_path(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m__coerce_path(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct File_Stat_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "File_Stat"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> File_Stat_eigenclass(__Ts__...) {}
};

struct Dir_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Dir"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Dir_eigenclass(__Ts__...) {}
};

struct Time_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Time"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Time_eigenclass(__Ts__...) {}
  virtual BasicObject* m_mktime(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_utc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_gm(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_local(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m__local_to_utc_offset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m__utc_to_local_offset(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m__coerce_tz_arg(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m__coerce_int_arg(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m__time_force_zone_b(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Mutex_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Mutex"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Mutex_eigenclass(__Ts__...) {}
};

struct Fiber_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Fiber"; }
  BasicObject* iv___scheduler__ = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Fiber_eigenclass(__Ts__...) {}
  virtual BasicObject* m_scheduler(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_set_scheduler(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct ThreadKill_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "ThreadKill"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ThreadKill_eigenclass(__Ts__...) {}
};

struct Thread_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Thread"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Thread_eigenclass(__Ts__...) {}
  virtual BasicObject* m_handle_interrupt(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_pending_interrupt_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_exit(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each_caller_location(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_allocate(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_new_main_thread(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Thread_Blocked_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Thread_Blocked"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Thread_Blocked_eigenclass(__Ts__...) {}
};

struct Thread_Mutex_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Thread_Mutex"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Thread_Mutex_eigenclass(__Ts__...) {}
};

struct Thread_Backtrace_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Thread_Backtrace"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Thread_Backtrace_eigenclass(__Ts__...) {}
};

struct Thread_Backtrace_Location_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Thread_Backtrace_Location"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Thread_Backtrace_Location_eigenclass(__Ts__...) {}
};

struct ThreadGroup_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "ThreadGroup"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ThreadGroup_eigenclass(__Ts__...) {}
};

struct ConditionVariable_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "ConditionVariable"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ConditionVariable_eigenclass(__Ts__...) {}
};

struct Queue_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Queue"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Queue_eigenclass(__Ts__...) {}
};

struct SizedQueue_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "SizedQueue"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> SizedQueue_eigenclass(__Ts__...) {}
};

struct Process_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Process"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Process_eigenclass(__Ts__...) {}
  virtual BasicObject* m__fork(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_fork(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_uid_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_gid_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_euid_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_egid_set(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_detach(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Process_Status_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Process_Status"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Process_Status_eigenclass(__Ts__...) {}
};

struct Binding_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Binding"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Binding_eigenclass(__Ts__...) {}
};

struct PP_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "PP"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> PP_eigenclass(__Ts__...) {}
  virtual BasicObject* m_width_for(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct StringIO_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "StringIO"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> StringIO_eigenclass(__Ts__...) {}
};

struct Struct_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Struct"; }
  BasicObject* iv_members = nullptr;
  BasicObject* iv_keyword_init = nullptr;
  BasicObject* iv_struct_values = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Struct_eigenclass(__Ts__...) {}
  virtual BasicObject* m_members(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Data_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Data"; }
  BasicObject* iv_data_members = nullptr;
  BasicObject* iv_data_values = nullptr;
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Data_eigenclass(__Ts__...) {}
  virtual BasicObject* m_members(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_define(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Set_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Set"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Set_eigenclass(__Ts__...) {}
  virtual BasicObject* m_aref(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Random_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Random"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Random_eigenclass(__Ts__...) {}
};

struct ObjectSpace_WeakMap_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "ObjectSpace_WeakMap"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ObjectSpace_WeakMap_eigenclass(__Ts__...) {}
};

struct ObjectSpace_WeakKeyMap_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "ObjectSpace_WeakKeyMap"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ObjectSpace_WeakKeyMap_eigenclass(__Ts__...) {}
};

struct ENVClass_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "ENVClass"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> ENVClass_eigenclass(__Ts__...) {}
  virtual BasicObject* m___coerce_key(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___coerce_value(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___coerce_env_string__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___validate_key(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___enc(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m___soft_coerce_string__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Gem_Specification_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Gem_Specification"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Gem_Specification_eigenclass(__Ts__...) {}
  virtual BasicObject* m_flat_map(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
  virtual BasicObject* m_each(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;
};

struct Marshal_Dumper_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Marshal_Dumper"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Marshal_Dumper_eigenclass(__Ts__...) {}
};

struct Marshal_Loader_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Marshal_Loader"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Marshal_Loader_eigenclass(__Ts__...) {}
};

struct Frozone_Vm_Vm_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Frozone_Vm_Vm"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Frozone_Vm_Vm_eigenclass(__Ts__...) {}
};

struct Frozone_Vm_Parser_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Frozone_Vm_Parser"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Frozone_Vm_Parser_eigenclass(__Ts__...) {}
};

struct Frozone_Vm_WqParser_eigenclass : Class {
  using Class::Class;
  const char* ruby_class_name() const override { return "Frozone_Vm_WqParser"; }
  template<class... __Ts__, std::enable_if_t<(... && std::is_pointer_v<__Ts__>), int> = 0> Frozone_Vm_WqParser_eigenclass(__Ts__...) {}
};

inline NilClass NIL_INSTANCE;
inline TrueClass TRUE_INSTANCE;
inline FalseClass FALSE_INSTANCE;
inline BasicObject_eigenclass BasicObject_CLASS;
inline Object_eigenclass Object_CLASS;
inline Class_eigenclass Class_CLASS;
inline NilClass_eigenclass NilClass_CLASS;
inline TrueClass_eigenclass TrueClass_CLASS;
inline FalseClass_eigenclass FalseClass_CLASS;
inline Integer_eigenclass Integer_CLASS;
inline Float_eigenclass Float_CLASS;
inline Array_eigenclass Array_CLASS;
inline Symbol_eigenclass Symbol_CLASS;
inline String_eigenclass String_CLASS;
inline Hash_eigenclass Hash_CLASS;
inline Proc_eigenclass Proc_CLASS;
inline BasicObject_BasicObject_eigenclass BasicObject_BasicObject_CLASS;
inline Module_eigenclass Module_CLASS;
inline Numeric_eigenclass Numeric_CLASS;
inline Refinement_eigenclass Refinement_CLASS;
inline Method_eigenclass Method_CLASS;
inline UnboundMethod_eigenclass UnboundMethod_CLASS;
inline Range_eigenclass Range_CLASS;
inline Enumerator_eigenclass Enumerator_CLASS;
inline Enumerator_Yielder_eigenclass Enumerator_Yielder_CLASS;
inline Enumerator_Generator_eigenclass Enumerator_Generator_CLASS;
inline Enumerator_Lazy_eigenclass Enumerator_Lazy_CLASS;
inline Enumerator_Chain_eigenclass Enumerator_Chain_CLASS;
inline Enumerator_ArithmeticSequence_eigenclass Enumerator_ArithmeticSequence_CLASS;
inline Enumerator_Product_eigenclass Enumerator_Product_CLASS;
inline Exception_eigenclass Exception_CLASS;
inline ScriptError_eigenclass ScriptError_CLASS;
inline LoadError_eigenclass LoadError_CLASS;
inline SyntaxError_eigenclass SyntaxError_CLASS;
inline NotImplementedError_eigenclass NotImplementedError_CLASS;
inline SignalException_eigenclass SignalException_CLASS;
inline Interrupt_eigenclass Interrupt_CLASS;
inline SystemExit_eigenclass SystemExit_CLASS;
inline StandardError_eigenclass StandardError_CLASS;
inline RuntimeError_eigenclass RuntimeError_CLASS;
inline FrozenError_eigenclass FrozenError_CLASS;
inline NameError_eigenclass NameError_CLASS;
inline NoMethodError_eigenclass NoMethodError_CLASS;
inline TypeError_eigenclass TypeError_CLASS;
inline ArgumentError_eigenclass ArgumentError_CLASS;
inline RangeError_eigenclass RangeError_CLASS;
inline FloatDomainError_eigenclass FloatDomainError_CLASS;
inline ZeroDivisionError_eigenclass ZeroDivisionError_CLASS;
inline IndexError_eigenclass IndexError_CLASS;
inline FiberError_eigenclass FiberError_CLASS;
inline ThreadError_eigenclass ThreadError_CLASS;
inline NoMemoryError_eigenclass NoMemoryError_CLASS;
inline SecurityError_eigenclass SecurityError_CLASS;
inline SystemStackError_eigenclass SystemStackError_CLASS;
inline NoMatchingPatternError_eigenclass NoMatchingPatternError_CLASS;
inline KeyError_eigenclass KeyError_CLASS;
inline StopIteration_eigenclass StopIteration_CLASS;
inline ClosedQueueError_eigenclass ClosedQueueError_CLASS;
inline UncaughtThrowError_eigenclass UncaughtThrowError_CLASS;
inline LocalJumpError_eigenclass LocalJumpError_CLASS;
inline SystemCallError_eigenclass SystemCallError_CLASS;
inline IOError_eigenclass IOError_CLASS;
inline EOFError_eigenclass EOFError_CLASS;
inline EncodingError_eigenclass EncodingError_CLASS;
inline RegexpError_eigenclass RegexpError_CLASS;
inline Errno_E2BIG_eigenclass Errno_E2BIG_CLASS;
inline Errno_EACCES_eigenclass Errno_EACCES_CLASS;
inline Errno_EADDRINUSE_eigenclass Errno_EADDRINUSE_CLASS;
inline Errno_EADDRNOTAVAIL_eigenclass Errno_EADDRNOTAVAIL_CLASS;
inline Errno_EAFNOSUPPORT_eigenclass Errno_EAFNOSUPPORT_CLASS;
inline Errno_EAGAIN_eigenclass Errno_EAGAIN_CLASS;
inline Errno_EALREADY_eigenclass Errno_EALREADY_CLASS;
inline Errno_EBADF_eigenclass Errno_EBADF_CLASS;
inline Errno_EBUSY_eigenclass Errno_EBUSY_CLASS;
inline Errno_ECHILD_eigenclass Errno_ECHILD_CLASS;
inline Errno_EILSEQ_eigenclass Errno_EILSEQ_CLASS;
inline Errno_ECONNABORTED_eigenclass Errno_ECONNABORTED_CLASS;
inline Errno_ECONNREFUSED_eigenclass Errno_ECONNREFUSED_CLASS;
inline Errno_ECONNRESET_eigenclass Errno_ECONNRESET_CLASS;
inline Errno_EDEADLK_eigenclass Errno_EDEADLK_CLASS;
inline Errno_EDOM_eigenclass Errno_EDOM_CLASS;
inline Errno_EEXIST_eigenclass Errno_EEXIST_CLASS;
inline Errno_EFAULT_eigenclass Errno_EFAULT_CLASS;
inline Errno_EFBIG_eigenclass Errno_EFBIG_CLASS;
inline Errno_EHOSTUNREACH_eigenclass Errno_EHOSTUNREACH_CLASS;
inline Errno_EINPROGRESS_eigenclass Errno_EINPROGRESS_CLASS;
inline Errno_EINTR_eigenclass Errno_EINTR_CLASS;
inline Errno_EINVAL_eigenclass Errno_EINVAL_CLASS;
inline Errno_EIO_eigenclass Errno_EIO_CLASS;
inline Errno_EISCONN_eigenclass Errno_EISCONN_CLASS;
inline Errno_EISDIR_eigenclass Errno_EISDIR_CLASS;
inline Errno_ELOOP_eigenclass Errno_ELOOP_CLASS;
inline Errno_EMFILE_eigenclass Errno_EMFILE_CLASS;
inline Errno_EMSGSIZE_eigenclass Errno_EMSGSIZE_CLASS;
inline Errno_ENAMETOOLONG_eigenclass Errno_ENAMETOOLONG_CLASS;
inline Errno_ENETDOWN_eigenclass Errno_ENETDOWN_CLASS;
inline Errno_ENETUNREACH_eigenclass Errno_ENETUNREACH_CLASS;
inline Errno_ENFILE_eigenclass Errno_ENFILE_CLASS;
inline Errno_ENODEV_eigenclass Errno_ENODEV_CLASS;
inline Errno_ENOENT_eigenclass Errno_ENOENT_CLASS;
inline Errno_ENOEXEC_eigenclass Errno_ENOEXEC_CLASS;
inline Errno_ENOMEM_eigenclass Errno_ENOMEM_CLASS;
inline Errno_ENOSPC_eigenclass Errno_ENOSPC_CLASS;
inline Errno_ENOSYS_eigenclass Errno_ENOSYS_CLASS;
inline Errno_ENOTCONN_eigenclass Errno_ENOTCONN_CLASS;
inline Errno_ENOTDIR_eigenclass Errno_ENOTDIR_CLASS;
inline Errno_ENOTEMPTY_eigenclass Errno_ENOTEMPTY_CLASS;
inline Errno_ENOTSUP_eigenclass Errno_ENOTSUP_CLASS;
inline Errno_ENOTTY_eigenclass Errno_ENOTTY_CLASS;
inline Errno_ENXIO_eigenclass Errno_ENXIO_CLASS;
inline Errno_EOPNOTSUPP_eigenclass Errno_EOPNOTSUPP_CLASS;
inline Errno_EOVERFLOW_eigenclass Errno_EOVERFLOW_CLASS;
inline Errno_EPERM_eigenclass Errno_EPERM_CLASS;
inline Errno_EPIPE_eigenclass Errno_EPIPE_CLASS;
inline Errno_EPROTONOSUPPORT_eigenclass Errno_EPROTONOSUPPORT_CLASS;
inline Errno_ERANGE_eigenclass Errno_ERANGE_CLASS;
inline Errno_EROFS_eigenclass Errno_EROFS_CLASS;
inline Errno_ESPIPE_eigenclass Errno_ESPIPE_CLASS;
inline Errno_ESRCH_eigenclass Errno_ESRCH_CLASS;
inline Errno_ETIMEDOUT_eigenclass Errno_ETIMEDOUT_CLASS;
inline Errno_ETXTBSY_eigenclass Errno_ETXTBSY_CLASS;
inline Errno_EWOULDBLOCK_eigenclass Errno_EWOULDBLOCK_CLASS;
inline Errno_EXDEV_eigenclass Errno_EXDEV_CLASS;
inline Math_DomainError_eigenclass Math_DomainError_CLASS;
inline Encoding_eigenclass Encoding_CLASS;
inline Encoding_CompatibilityError_eigenclass Encoding_CompatibilityError_CLASS;
inline Encoding_ConverterNotFoundError_eigenclass Encoding_ConverterNotFoundError_CLASS;
inline Encoding_InvalidByteSequenceError_eigenclass Encoding_InvalidByteSequenceError_CLASS;
inline Encoding_UndefinedConversionError_eigenclass Encoding_UndefinedConversionError_CLASS;
inline Encoding_Converter_eigenclass Encoding_Converter_CLASS;
inline MatchData_eigenclass MatchData_CLASS;
inline Regexp_eigenclass Regexp_CLASS;
inline Regexp_TimeoutError_eigenclass Regexp_TimeoutError_CLASS;
inline Rational_eigenclass Rational_CLASS;
inline Complex_eigenclass Complex_CLASS;
inline IO_eigenclass IO_CLASS;
inline IO_CapturedOutput_eigenclass IO_CapturedOutput_CLASS;
inline IO_EAGAINWaitReadable_eigenclass IO_EAGAINWaitReadable_CLASS;
inline IO_EAGAINWaitWritable_eigenclass IO_EAGAINWaitWritable_CLASS;
inline IO_EWOULDBLOCKWaitReadable_eigenclass IO_EWOULDBLOCKWaitReadable_CLASS;
inline IO_EWOULDBLOCKWaitWritable_eigenclass IO_EWOULDBLOCKWaitWritable_CLASS;
inline File_eigenclass File_CLASS;
inline File_Stat_eigenclass File_Stat_CLASS;
inline Dir_eigenclass Dir_CLASS;
inline Time_eigenclass Time_CLASS;
inline Mutex_eigenclass Mutex_CLASS;
inline Fiber_eigenclass Fiber_CLASS;
inline ThreadKill_eigenclass ThreadKill_CLASS;
inline Thread_eigenclass Thread_CLASS;
inline Thread_Blocked_eigenclass Thread_Blocked_CLASS;
inline Thread_Mutex_eigenclass Thread_Mutex_CLASS;
inline Thread_Backtrace_eigenclass Thread_Backtrace_CLASS;
inline Thread_Backtrace_Location_eigenclass Thread_Backtrace_Location_CLASS;
inline ThreadGroup_eigenclass ThreadGroup_CLASS;
inline ConditionVariable_eigenclass ConditionVariable_CLASS;
inline Queue_eigenclass Queue_CLASS;
inline SizedQueue_eigenclass SizedQueue_CLASS;
inline Process_eigenclass Process_CLASS;
inline Process_Status_eigenclass Process_Status_CLASS;
inline Binding_eigenclass Binding_CLASS;
inline PP_eigenclass PP_CLASS;
inline StringIO_eigenclass StringIO_CLASS;
inline Struct_eigenclass Struct_CLASS;
inline Data_eigenclass Data_CLASS;
inline Set_eigenclass Set_CLASS;
inline Random_eigenclass Random_CLASS;
inline ObjectSpace_WeakMap_eigenclass ObjectSpace_WeakMap_CLASS;
inline ObjectSpace_WeakKeyMap_eigenclass ObjectSpace_WeakKeyMap_CLASS;
inline ENVClass_eigenclass ENVClass_CLASS;
inline Gem_Specification_eigenclass Gem_Specification_CLASS;
inline Marshal_Dumper_eigenclass Marshal_Dumper_CLASS;
inline Marshal_Loader_eigenclass Marshal_Loader_CLASS;
inline Frozone_Vm_Vm_eigenclass Frozone_Vm_Vm_CLASS;
inline Frozone_Vm_Parser_eigenclass Frozone_Vm_Parser_CLASS;
inline Frozone_Vm_WqParser_eigenclass Frozone_Vm_WqParser_CLASS;

inline BasicObject* NilClass::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  return new String("", 0);
}

inline BasicObject* NilClass::m_nil_q(Array* args, Hash* kwargs, Proc* block) {
  return true_instance();
}

inline BasicObject* TrueClass::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  return new String("true", 4);
}

inline BasicObject* FalseClass::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  return new String("false", 5);
}

inline BasicObject* Integer::m_plus(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return new Integer(raw_ + static_cast<Integer*>(other)->raw_);
}

inline BasicObject* Integer::m_minus(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return new Integer(raw_ - static_cast<Integer*>(other)->raw_);
}

inline BasicObject* Integer::m_mul(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return new Integer(raw_ * static_cast<Integer*>(other)->raw_);
}

inline BasicObject* Integer::m_div(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return new Integer(raw_ / static_cast<Integer*>(other)->raw_);
}

inline BasicObject* Integer::m_mod(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return new Integer(raw_ % static_cast<Integer*>(other)->raw_);
}

inline BasicObject* Integer::m_lt(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return boxed_bool(raw_ <  static_cast<Integer*>(other)->raw_);
}

inline BasicObject* Integer::m_gt(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return boxed_bool(raw_ >  static_cast<Integer*>(other)->raw_);
}

inline BasicObject* Integer::m_le(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return boxed_bool(raw_ <= static_cast<Integer*>(other)->raw_);
}

inline BasicObject* Integer::m_ge(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return boxed_bool(raw_ >= static_cast<Integer*>(other)->raw_);
}

inline BasicObject* Integer::m_eq_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  auto* o = dynamic_cast<Integer*>(other); return boxed_bool(o && raw_ == o->raw_);
}

inline BasicObject* Integer::m_ne_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  auto* o = dynamic_cast<Integer*>(other); return boxed_bool(!o || raw_ != o->raw_);
}

inline BasicObject* Integer::m_lshift(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return new Integer(raw_ << static_cast<Integer*>(other)->raw_);
}

inline BasicObject* Integer::m_rshift(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return new Integer(raw_ >> static_cast<Integer*>(other)->raw_);
}

inline BasicObject* Integer::m_bit_and(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return new Integer(raw_ &  static_cast<Integer*>(other)->raw_);
}

inline BasicObject* Integer::m_bit_or(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return new Integer(raw_ |  static_cast<Integer*>(other)->raw_);
}

inline BasicObject* Integer::m_bit_xor(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return new Integer(raw_ ^  static_cast<Integer*>(other)->raw_);
}

inline BasicObject* Integer::m_neg(Array* args, Hash* kwargs, Proc* block) {
  return new Integer(-raw_);
}

inline BasicObject* Integer::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  char buf[32];
  int n = std::snprintf(buf, sizeof(buf), "%lld", static_cast<long long>(raw_));
  return new String(buf, static_cast<std::size_t>(n));
}

inline BasicObject* Integer::m_to_i(Array* args, Hash* kwargs, Proc* block) {
  return this;
}

inline BasicObject* Float::m_plus(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return new Float(raw_ + static_cast<Float*>(other)->raw_);
}

inline BasicObject* Float::m_minus(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return new Float(raw_ - static_cast<Float*>(other)->raw_);
}

inline BasicObject* Float::m_mul(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return new Float(raw_ * static_cast<Float*>(other)->raw_);
}

inline BasicObject* Float::m_div(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return new Float(raw_ / static_cast<Float*>(other)->raw_);
}

inline BasicObject* Float::m_lt(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return boxed_bool(raw_ <  static_cast<Float*>(other)->raw_);
}

inline BasicObject* Float::m_gt(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return boxed_bool(raw_ >  static_cast<Float*>(other)->raw_);
}

inline BasicObject* Float::m_le(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return boxed_bool(raw_ <= static_cast<Float*>(other)->raw_);
}

inline BasicObject* Float::m_ge(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return boxed_bool(raw_ >= static_cast<Float*>(other)->raw_);
}

inline BasicObject* Float::m_eq_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  auto* o = dynamic_cast<Float*>(other); return boxed_bool(o && raw_ == o->raw_);
}

inline BasicObject* Float::m_ne_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  auto* o = dynamic_cast<Float*>(other); return boxed_bool(!o || raw_ != o->raw_);
}

inline BasicObject* Float::m_neg(Array* args, Hash* kwargs, Proc* block) {
  return new Float(-raw_);
}

inline BasicObject* Float::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  char buf[32];
  int n = std::snprintf(buf, sizeof(buf), "%g", raw_);
  return new String(buf, static_cast<std::size_t>(n));
}

inline BasicObject* Float::m_to_f(Array* args, Hash* kwargs, Proc* block) {
  return this;
}

inline BasicObject* Array::m_size(Array* args, Hash* kwargs, Proc* block) {
  return new Integer(static_cast<int64_t>(data.size()));
}

inline BasicObject* Array::m_length(Array* args, Hash* kwargs, Proc* block) {
  return new Integer(static_cast<int64_t>(data.size()));
}

inline BasicObject* Array::m_empty_q(Array* args, Hash* kwargs, Proc* block) {
  return boxed_bool(data.empty());
}

inline BasicObject* Array::m_first(Array* args, Hash* kwargs, Proc* block) {
  return data.empty() ? nil_instance() : data.front();
}

inline BasicObject* Array::m_last(Array* args, Hash* kwargs, Proc* block) {
  return data.empty() ? nil_instance() : data.back();
}

inline BasicObject* Array::m_aref(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* idx = array_at(args, 0);
  int64_t i = static_cast<Integer*>(idx)->raw_;
  if (i < 0) i += static_cast<int64_t>(data.size());
  if (i < 0 || i >= static_cast<int64_t>(data.size())) return nil_instance();
  return data[i];
}

inline BasicObject* Array::m_aset(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* idx = array_at(args, 0);
  BasicObject* val = array_at(args, 1);
  int64_t i = static_cast<Integer*>(idx)->raw_;
  if (i < 0) i += static_cast<int64_t>(data.size());
  if (i >= static_cast<int64_t>(data.size())) data.resize(i + 1, nil_instance());
  data[i] = val;
  return val;
}

inline BasicObject* Array::m_push(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* val = array_at(args, 0);
  data.push_back(val); return this;
}

inline BasicObject* Array::m_lshift(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* val = array_at(args, 0);
  data.push_back(val); return this;
}

inline BasicObject* Symbol::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  return new String(name_);
}

inline BasicObject* Symbol::m_to_sym(Array* args, Hash* kwargs, Proc* block) {
  return this;
}

inline BasicObject* String::m_size(Array* args, Hash* kwargs, Proc* block) {
  return new Integer(length());
}

inline BasicObject* String::m_length(Array* args, Hash* kwargs, Proc* block) {
  return new Integer(length());
}

inline BasicObject* String::m_bytesize(Array* args, Hash* kwargs, Proc* block) {
  return new Integer(static_cast<std::int64_t>(bytes.size()));
}

inline BasicObject* String::m_empty_q(Array* args, Hash* kwargs, Proc* block) {
  return boxed_bool(bytes.empty());
}

inline BasicObject* String::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  return this;
}

inline BasicObject* String::m_eq_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  auto* o = dynamic_cast<String*>(other); return boxed_bool(o && bytes == o->bytes);
}

inline BasicObject* String::m_ne_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  auto* o = dynamic_cast<String*>(other); return boxed_bool(!o || bytes != o->bytes);
}

inline BasicObject* String::m_lt(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return boxed_bool(bytes <  static_cast<String*>(other)->bytes);
}

inline BasicObject* String::m_gt(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return boxed_bool(bytes >  static_cast<String*>(other)->bytes);
}

inline BasicObject* String::m_le(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return boxed_bool(bytes <= static_cast<String*>(other)->bytes);
}

inline BasicObject* String::m_ge(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  return boxed_bool(bytes >= static_cast<String*>(other)->bytes);
}

inline BasicObject* String::m_plus(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  auto* o = static_cast<String*>(other);
  String* r = new String();
  r->enc = (enc == BINARY && o->enc == UTF8 && o->has_non_ascii()) ? UTF8 : enc;
  r->bytes.reserve(bytes.size() + o->bytes.size());
  r->bytes.insert(r->bytes.end(), bytes.begin(), bytes.end());
  r->bytes.insert(r->bytes.end(), o->bytes.begin(), o->bytes.end());
  return r;
}

inline BasicObject* String::m_lshift(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  auto* o = static_cast<String*>(other);
  // MRI encoding promotion: BINARY + UTF-8 non-ASCII → UTF-8.
  if (enc == BINARY && o->enc == UTF8 && o->has_non_ascii()) enc = UTF8;
  bytes.insert(bytes.end(), o->bytes.begin(), o->bytes.end());
  length_cache_ = -1;
  return this;
}

inline BasicObject* String::m_aref(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* idx = array_at(args, 0);
  std::int64_t i = static_cast<Integer*>(idx)->raw_;
  if (i < 0) i += static_cast<std::int64_t>(bytes.size());
  if (i < 0 || i >= static_cast<std::int64_t>(bytes.size())) return nil_instance();
  return new String(reinterpret_cast<const char*>(&bytes[i]), 1, enc);
}

inline BasicObject* String::m_ord(Array* args, Hash* kwargs, Proc* block) {
  return new Integer(bytes.empty() ? 0 : static_cast<std::int64_t>(bytes[0]));
}

inline BasicObject* String::m_dup(Array* args, Hash* kwargs, Proc* block) {
  String* r = new String();
  r->bytes = bytes;
  r->enc = enc;
  return r;
}

inline BasicObject* String::m_b(Array* args, Hash* kwargs, Proc* block) {
  String* r = new String();
  r->bytes = bytes;
  r->enc = BINARY;
  return r;
}

inline BasicObject* Hash::m_size(Array* args, Hash* kwargs, Proc* block) {
  return new Integer(static_cast<int64_t>(data.size()));
}

inline BasicObject* Hash::m_length(Array* args, Hash* kwargs, Proc* block) {
  return new Integer(static_cast<int64_t>(data.size()));
}

inline BasicObject* Hash::m_empty_q(Array* args, Hash* kwargs, Proc* block) {
  return boxed_bool(data.empty());
}

inline BasicObject* Hash::m_aref(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* k = array_at(args, 0);
  auto it = data.find(k);
  return (it == data.end()) ? nil_instance() : it->second;
}

inline BasicObject* Hash::m_aset(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* k = array_at(args, 0);
  BasicObject* v = array_at(args, 1);
  data[k] = v; return v;
}

inline BasicObject* Hash::m_include_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* k = array_at(args, 0);
  return boxed_bool(data.find(k) != data.end());
}

inline BasicObject* Hash::m_has_key_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* k = array_at(args, 0);
  return boxed_bool(data.find(k) != data.end());
}

inline BasicObject* Proc::m_call(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* arg = array_at(args, 0);
  return fn_(arg);
}

inline BasicObject* BasicObject_BasicObject::m_not(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = false_instance()->m_equal_q((new Array({this})), nullptr, nullptr); return truthy(_l) ? _l : (nil_instance()->m_equal_q((new Array({this})), nullptr, nullptr)); }());
  return nil_instance();
}

inline BasicObject* BasicObject_BasicObject::m_ne_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* v = array_at(args, 0);
  Proc* _block = block;
  return (this->m_eq_q((new Array({v})), nullptr, nullptr))->m_not((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* BasicObject_BasicObject::m_respond_to_missing_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* name = array_at(args, 0);
  BasicObject* include_private = (args->data.size() > 1) ? args->data[1] : (false_instance());
  Proc* _block = block;
  return false_instance();
  return nil_instance();
}

inline BasicObject* Module::m_included(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Module::m_prepended(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Module::m_case_eq(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return other->m_is_a_q((new Array({this})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Module::m_inspect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_s((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Module::m_included_modules(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_ancestors((new Array({})), nullptr, nullptr)->m_drop((new Array({(new Integer(1LL))})), nullptr, nullptr)->m_select((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* m = arg; return ([&]() -> BasicObject* { auto* _l = m->m_is_a_q((new Array({(&Module_CLASS)})), nullptr, nullptr); return truthy(_l) ? (m->m_is_a_q((new Array({(&Class_CLASS)})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr)) : _l; }()); })));
  return nil_instance();
}

inline BasicObject* Module::m_const_added(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* name = array_at(args, 0);
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Module::m_method_added(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* name = array_at(args, 0);
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Module::m_method_removed(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* name = array_at(args, 0);
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Module::m_method_undefined(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* name = array_at(args, 0);
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Module::m_singleton_method_added(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* name = array_at(args, 0);
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Module::m_singleton_method_removed(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* name = array_at(args, 0);
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Module::m_singleton_method_undefined(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* name = array_at(args, 0);
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Module::m_extended(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Module::m_refinements(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = (this->iv___refinements__->m_values((new Array({})), nullptr, nullptr)); return truthy(_l) ? _l : ((new Array({}))); }());
  return nil_instance();
}

inline BasicObject* Module::m_include_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* mod = array_at(args, 0);
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = mod->m_is_a_q((new Array({(&Module_CLASS)})), nullptr, nullptr); return truthy(_l) ? (mod->m_is_a_q((new Array({(&Class_CLASS)})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr)) : _l; }()))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("wrong argument type ", 20))})), nullptr, nullptr)->m_plus((new Array({(mod->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" (expected Module)", 18))})), nullptr, nullptr)))); }());
  }
  return this->m_ancestors((new Array({})), nullptr, nullptr)->m_drop((new Array({(new Integer(1LL))})), nullptr, nullptr)->m_include_q((new Array({mod})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Module::m_lt(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&Module_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError((new String("compared with non class/module", 30)))); }());
  }
  if (truthy(this->m_equal_q((new Array({other})), nullptr, nullptr))) {
    return false_instance();
  }
  return (truthy(this->m_ancestors((new Array({})), nullptr, nullptr)->m_include_q((new Array({other})), nullptr, nullptr)) ? ((true_instance())) : ((((truthy(other->m_ancestors((new Array({})), nullptr, nullptr)->m_include_q((new Array({this})), nullptr, nullptr)) ? ((false_instance())) : ((nil_instance())))))));
  return nil_instance();
}

inline BasicObject* Module::m_gt(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&Module_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError((new String("compared with non class/module", 30)))); }());
  }
  if (truthy(this->m_equal_q((new Array({other})), nullptr, nullptr))) {
    return false_instance();
  }
  return (truthy(other->m_ancestors((new Array({})), nullptr, nullptr)->m_include_q((new Array({this})), nullptr, nullptr)) ? ((true_instance())) : ((((truthy(this->m_ancestors((new Array({})), nullptr, nullptr)->m_include_q((new Array({other})), nullptr, nullptr)) ? ((false_instance())) : ((nil_instance())))))));
  return nil_instance();
}

inline BasicObject* Module::m_spaceship(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&Module_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return nil_instance();
  }
  if (truthy(this->m_equal_q((new Array({other})), nullptr, nullptr))) {
    return (new Integer(0LL));
  }
  if (truthy(this->m_ancestors((new Array({})), nullptr, nullptr)->m_include_q((new Array({other})), nullptr, nullptr))) {
    return (new Integer(-1LL));
  }
  if (truthy(other->m_ancestors((new Array({})), nullptr, nullptr)->m_include_q((new Array({this})), nullptr, nullptr))) {
    return (new Integer(1LL));
  }
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Module::m_le(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&Module_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError((new String("compared with non class/module", 30)))); }());
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = this->m_equal_q((new Array({other})), nullptr, nullptr); return truthy(_l) ? _l : (this->m_ancestors((new Array({})), nullptr, nullptr)->m_include_q((new Array({other})), nullptr, nullptr)); }()))) {
    return true_instance();
  }
  return (truthy(other->m_ancestors((new Array({})), nullptr, nullptr)->m_include_q((new Array({this})), nullptr, nullptr)) ? ((false_instance())) : ((nil_instance())));
  return nil_instance();
}

inline BasicObject* Module::m_ge(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&Module_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError((new String("compared with non class/module", 30)))); }());
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = this->m_equal_q((new Array({other})), nullptr, nullptr); return truthy(_l) ? _l : (other->m_ancestors((new Array({})), nullptr, nullptr)->m_include_q((new Array({this})), nullptr, nullptr)); }()))) {
    return true_instance();
  }
  return (truthy(this->m_ancestors((new Array({})), nullptr, nullptr)->m_include_q((new Array({other})), nullptr, nullptr)) ? ((false_instance())) : ((nil_instance())));
  return nil_instance();
}

inline BasicObject* Module::m_const_missing(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* name = array_at(args, 0);
  Proc* _block = block;
  BasicObject* n = nil_instance();
  BasicObject* label = nil_instance();
  BasicObject* e = nil_instance();
  n = this->m_name((new Array({})), nullptr, nullptr);
  label = (truthy(([&]() -> BasicObject* { auto* _l = n; return truthy(_l) ? (n->m_ne_q((new Array({(new String("Object", 6))})), nullptr, nullptr)) : _l; }())) ? ((((new String("", 0))->m_plus((new Array({(n)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String("::", 2))})), nullptr, nullptr)->m_plus((new Array({(name)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))) : ((truthy(n->m_nil_q((new Array({})), nullptr, nullptr)) ? ((((new String("", 0))->m_plus((new Array({(this->m_inspect((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String("::", 2))})), nullptr, nullptr)->m_plus((new Array({(name)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))) : ((name->m_to_s((new Array({})), nullptr, nullptr))))));
  e = (new NameError(static_cast<BasicObject*>(((new String("", 0))->m_plus((new Array({(new String("uninitialized constant ", 23))})), nullptr, nullptr)->m_plus((new Array({(label)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr))), static_cast<BasicObject*>(name)));
  e->m_instance_variable_set((new Array({intern("@receiver"), this})), nullptr, nullptr);
  return ([&]() -> BasicObject* { throw static_cast<Exception*>(e); }());
  return nil_instance();
}

inline BasicObject* Numeric::m_integer_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return false_instance();
  return nil_instance();
}

inline BasicObject* Numeric::m_real_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return true_instance();
  return nil_instance();
}

inline BasicObject* Numeric::m_zero_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_positive_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_gt((new Array({(new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_negative_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_finite_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return true_instance();
  return nil_instance();
}

inline BasicObject* Numeric::m_infinite_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Numeric::m_abs2(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_mul((new Array({this})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_pos(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* Numeric::m_neg(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Integer(0LL))->m_minus((new Array({this})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_real(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* Numeric::m_conj(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* Numeric::m_conjugate(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* Numeric::m_imag(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Integer(0LL));
  return nil_instance();
}

inline BasicObject* Numeric::m_imaginary(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Integer(0LL));
  return nil_instance();
}

inline BasicObject* Numeric::m_polar(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Array({this->m_abs((new Array({})), nullptr, nullptr), this->m_arg((new Array({})), nullptr, nullptr)}));
  return nil_instance();
}

inline BasicObject* Numeric::m_rect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Array({this, (new Integer(0LL))}));
  return nil_instance();
}

inline BasicObject* Numeric::m_rectangular(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Array({this, (new Integer(0LL))}));
  return nil_instance();
}

inline BasicObject* Numeric::m_to_int(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_i((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_to_c(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_Complex((new Array({this, (new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_i(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_Complex((new Array({(new Integer(0LL)), this})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_dup(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* Numeric::m_nonzero_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->m_zero_q((new Array({})), nullptr, nullptr)) ? ((nil_instance())) : ((this)));
  return nil_instance();
}

inline BasicObject* Numeric::m_abs(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((this->m_neg((new Array({})), nullptr, nullptr))) : ((this)));
  return nil_instance();
}

inline BasicObject* Numeric::m_magnitude(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((this->m_neg((new Array({})), nullptr, nullptr))) : ((this)));
  return nil_instance();
}

inline BasicObject* Numeric::m_eql_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = other->m_instance_of_q((new Array({this->m_class((new Array({})), nullptr, nullptr)})), nullptr, nullptr); return truthy(_l) ? (this->m_eq_q((new Array({other})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* Numeric::m_spaceship(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return (truthy(this->m_equal_q((new Array({other})), nullptr, nullptr)) ? (((new Integer(0LL)))) : ((nil_instance())));
  return nil_instance();
}

inline BasicObject* Numeric::m_ceil(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* ndigits = (args->data.size() > 0) ? args->data[0] : ((new Integer(0LL)));
  Proc* _block = block;
  return this->m_to_f((new Array({})), nullptr, nullptr)->m_ceil((new Array({ndigits})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_floor(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* ndigits = (args->data.size() > 0) ? args->data[0] : ((new Integer(0LL)));
  Proc* _block = block;
  return this->m_to_f((new Array({})), nullptr, nullptr)->m_floor((new Array({ndigits})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_truncate(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* ndigits = (args->data.size() > 0) ? args->data[0] : ((new Integer(0LL)));
  Proc* _block = block;
  return this->m_to_f((new Array({})), nullptr, nullptr)->m_truncate((new Array({ndigits})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_divmod(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return (new Array({this->m_div((new Array({other})), nullptr, nullptr), this->m_modulo((new Array({other})), nullptr, nullptr)}));
  return nil_instance();
}

inline BasicObject* Numeric::m_modulo(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return this->m_minus((new Array({other->m_mul((new Array({this->m_div((new Array({other})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_mod(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return this->m_minus((new Array({other->m_mul((new Array({this->m_div((new Array({other})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_fdiv(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return this->m_to_f((new Array({})), nullptr, nullptr)->m_div((new Array({other->m_to_f((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_numerator(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_r((new Array({})), nullptr, nullptr)->m_numerator((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_denominator(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_r((new Array({})), nullptr, nullptr)->m_denominator((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_singleton_method_added(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* id = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { throw (new TypeError((new String("can't define singleton", 22)))); }());
  return nil_instance();
}

inline BasicObject* Numeric::m_div(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = other->m_respond_to_q((new Array({intern("zero?")})), nullptr, nullptr); return truthy(_l) ? (other->m_zero_q((new Array({})), nullptr, nullptr)) : _l; }()))) {
    ([&]() -> BasicObject* { throw (new ZeroDivisionError((new String("divided by 0", 12)))); }());
  }
  return (this->m_div((new Array({other})), nullptr, nullptr))->m_floor((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_quo(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  BasicObject* r = nil_instance();
  if (truthy(other->m_is_a_q((new Array({(&Numeric_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(other->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" can't be coerced into Rational", 31))})), nullptr, nullptr)))); }());
  }
  r = this->m_to_r((new Array({})), nullptr, nullptr);
  if (truthy(r->m_is_a_q((new Array({(&Rational_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(r->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" is not a Rational", 18))})), nullptr, nullptr)))); }());
  }
  return r->m_div((new Array({other})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Numeric::m_coerce(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  BasicObject* result = nil_instance();
  return (truthy(other->m_instance_of_q((new Array({this->m_class((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) ? (((new Array({other, this})))) : ((truthy(other->m_is_a_q((new Array({(&Numeric_CLASS)})), nullptr, nullptr)) ? (((new Array({other->m_to_f((new Array({})), nullptr, nullptr), this->m_to_f((new Array({})), nullptr, nullptr)})))) : ((truthy(other->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)) ? ((([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return (new Array({this->m_Float((new Array({other})), nullptr, nullptr), this->m_to_f((new Array({})), nullptr, nullptr)}));  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<ArgumentError*>(e_) != nullptr) { return [&]() -> BasicObject* { return ([&]() -> BasicObject* { throw (new ArgumentError(((new String("", 0))->m_plus((new Array({(new String("invalid value for Float(): ", 27))})), nullptr, nullptr)->m_plus((new Array({(other->m_inspect((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))); }());  return nil_instance(); }(); } throw; } }()))) : ((truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = other->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr); return truthy(_l) ? (other->m_ne_q((new Array({true_instance()})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (other->m_ne_q((new Array({false_instance()})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (other->m_is_a_q((new Array({(&Symbol_CLASS)})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (other->m_respond_to_q((new Array({intern("to_f")})), nullptr, nullptr)) : _l; }())) ? (((result = other->m_to_f((new Array({})), nullptr, nullptr)), (truthy(result->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)) ? (nil_instance()) : ((([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(other->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" can't be coerced into ", 23))})), nullptr, nullptr)->m_plus((new Array({(this->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))); }())))), (new Array({result, this->m_to_f((new Array({})), nullptr, nullptr)})))) : ((([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(other->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" can't be coerced into ", 23))})), nullptr, nullptr)->m_plus((new Array({(this->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))); }()))))))))));
  return nil_instance();
}

inline BasicObject* Refinement::m_include(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* mods = args;  // *rest = whole args
  Proc* _block = block;
  return ([&]() -> BasicObject* { throw (new TypeError((new String("Refinement#include has been removed", 35)))); }());
  return nil_instance();
}

inline BasicObject* Refinement::m_prepend(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* mods = args;  // *rest = whole args
  Proc* _block = block;
  return ([&]() -> BasicObject* { throw (new TypeError((new String("Refinement#prepend has been removed", 35)))); }());
  return nil_instance();
}

inline BasicObject* Refinement::m_target(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv___refined_class__;
  return nil_instance();
}

inline BasicObject* Refinement::m_warn_ancestors(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* modules = array_at(args, 0);
  Proc* _block = block;
  return modules->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* mod = arg; return (truthy(mod->m_ancestors((new Array({})), nullptr, nullptr)->m_drop((new Array({(new Integer(1LL))})), nullptr, nullptr)->m_select((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* a = arg; return ([&]() -> BasicObject* { auto* _l = a->m_is_a_q((new Array({(&Module_CLASS)})), nullptr, nullptr); return truthy(_l) ? (a->m_is_a_q((new Array({(&Class_CLASS)})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr)) : _l; }()); })))->m_empty_q((new Array({})), nullptr, nullptr)) ? (nil_instance()) : ((this->m_warn((new Array({((new String("", 0))->m_plus((new Array({(new String("warning: ", 9))})), nullptr, nullptr)->m_plus((new Array({(mod)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" has ancestors, but Refinement#import_methods doesn't import their methods", 74))})), nullptr, nullptr))})), nullptr, nullptr)))); })));
  return nil_instance();
}

inline BasicObject* Method::m_curry(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* arity = (args->data.size() > 0) ? args->data[0] : (nil_instance());
  Proc* _block = block;
  return this->m_to_proc((new Array({})), nullptr, nullptr)->m_curry((new Array({arity})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* UnboundMethod::m_inspect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* own = nil_instance();
  BasicObject* own_name = nil_instance();
  BasicObject* loc = nil_instance();
  own = this->m_owner((new Array({})), nullptr, nullptr);
  own_name = (truthy(own) ? (((([&]() -> BasicObject* { auto* _l = own->m_name((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (own->m_inspect((new Array({})), nullptr, nullptr)); }())))) : ((nil_instance())));
  loc = (truthy(this->m_source_location((new Array({})), nullptr, nullptr)) ? ((((new String("", 0))->m_plus((new Array({(new String(" ", 1))})), nullptr, nullptr)->m_plus((new Array({(this->m_source_location((new Array({})), nullptr, nullptr)->m_aref((new Array({(new Integer(0LL))})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(":", 1))})), nullptr, nullptr)->m_plus((new Array({(this->m_source_location((new Array({})), nullptr, nullptr)->m_aref((new Array({(new Integer(1LL))})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))) : (((new String("", 0)))));
  return ((new String("", 0))->m_plus((new Array({(new String("#<UnboundMethod: ", 17))})), nullptr, nullptr)->m_plus((new Array({(own_name)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String("#", 1))})), nullptr, nullptr)->m_plus((new Array({(this->m_name((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(loc)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(">", 1))})), nullptr, nullptr));
  return nil_instance();
}

inline BasicObject* UnboundMethod::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* own = nil_instance();
  BasicObject* own_name = nil_instance();
  BasicObject* loc = nil_instance();
  own = this->m_owner((new Array({})), nullptr, nullptr);
  own_name = (truthy(own) ? (((([&]() -> BasicObject* { auto* _l = own->m_name((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (own->m_inspect((new Array({})), nullptr, nullptr)); }())))) : ((nil_instance())));
  loc = (truthy(this->m_source_location((new Array({})), nullptr, nullptr)) ? ((((new String("", 0))->m_plus((new Array({(new String(" ", 1))})), nullptr, nullptr)->m_plus((new Array({(this->m_source_location((new Array({})), nullptr, nullptr)->m_aref((new Array({(new Integer(0LL))})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(":", 1))})), nullptr, nullptr)->m_plus((new Array({(this->m_source_location((new Array({})), nullptr, nullptr)->m_aref((new Array({(new Integer(1LL))})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))) : (((new String("", 0)))));
  return ((new String("", 0))->m_plus((new Array({(new String("#<UnboundMethod: ", 17))})), nullptr, nullptr)->m_plus((new Array({(own_name)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String("#", 1))})), nullptr, nullptr)->m_plus((new Array({(this->m_name((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(loc)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(">", 1))})), nullptr, nullptr));
  return nil_instance();
}

inline BasicObject* Range::m_sort(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_a((new Array({})), nullptr, nullptr)->m_sort((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Range::m_drop(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = array_at(args, 0);
  Proc* _block = block;
  return this->m_to_a((new Array({})), nullptr, nullptr)->m_drop((new Array({n})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Range::m_entries(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_a((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Range::m_hash(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Array({this->m_begin((new Array({})), nullptr, nullptr), this->m_end((new Array({})), nullptr, nullptr), this->m_exclude_end_q((new Array({})), nullptr, nullptr)}))->m_hash((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Range::m_each_with_index(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* i = nil_instance();
  i = (new Integer(0LL));
  this->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; _block->m_call((new Array({x, i})), nullptr, nullptr); return (i = i->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr)); })));
  return this;
  return nil_instance();
}

inline BasicObject* Range::m_map(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* r = nil_instance();
  r = (new Array({}));
  this->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return r->m_lshift((new Array({_block->m_call((new Array({x})), nullptr, nullptr)})), nullptr, nullptr); })));
  return r;
  return nil_instance();
}

inline BasicObject* Range::m_select(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* r = nil_instance();
  r = (new Array({}));
  this->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return (truthy(_block->m_call((new Array({x})), nullptr, nullptr)) ? ((r->m_lshift((new Array({x})), nullptr, nullptr))) : (nil_instance())); })));
  return r;
  return nil_instance();
}

inline BasicObject* Range::m_flat_map(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_map((new Array({})), nullptr, static_cast<Proc*>(block))->m_flatten((new Array({(new Integer(1LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Range::m_collect_concat(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_map((new Array({})), nullptr, static_cast<Proc*>(block))->m_flatten((new Array({(new Integer(1LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Range::m_sort_by(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_a((new Array({})), nullptr, nullptr)->m_sort_by((new Array({})), nullptr, static_cast<Proc*>(block));
  return nil_instance();
}

inline BasicObject* Range::m_min_by(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_a((new Array({})), nullptr, nullptr)->m_min_by((new Array({})), nullptr, static_cast<Proc*>(block));
  return nil_instance();
}

inline BasicObject* Range::m_max_by(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_a((new Array({})), nullptr, nullptr)->m_max_by((new Array({})), nullptr, static_cast<Proc*>(block));
  return nil_instance();
}

inline BasicObject* Range::m_to_a(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* r = nil_instance();
  if (truthy(this->m_end((new Array({})), nullptr, nullptr)->m_nil_q((new Array({})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new RangeError((new String("cannot convert endless range to an array", 40)))); }());
  }
  if (truthy(this->m_begin((new Array({})), nullptr, nullptr)->m_nil_q((new Array({})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new TypeError((new String("cannot convert beginless range to an array", 42)))); }());
  }
  r = (new Array({}));
  this->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return r->m_lshift((new Array({x})), nullptr, nullptr); })));
  return r;
  return nil_instance();
}

inline BasicObject* Range::m_include_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* val = array_at(args, 0);
  Proc* _block = block;
  BasicObject* b = nil_instance();
  BasicObject* e = nil_instance();
  BasicObject* begin_len = nil_instance();
  BasicObject* i = nil_instance();
  BasicObject* cmp = nil_instance();
  BasicObject* s = nil_instance();
  b = this->m_begin((new Array({})), nullptr, nullptr);
  e = this->m_end((new Array({})), nullptr, nullptr);
  if (truthy(([&]() -> BasicObject* { auto* _l = b->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (b->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)); }()))) {
    return this->m_cover_q((new Array({val})), nullptr, nullptr);
  }
  if (truthy(b->m_respond_to_q((new Array({intern("succ")})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return this->m_cover_q((new Array({val})), nullptr, nullptr);
  }
  if (truthy(this->m_cover_q((new Array({val})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return false_instance();
  }
  begin_len = (truthy(b->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)) ? ((b->m_length((new Array({})), nullptr, nullptr))) : ((nil_instance())));
  i = b;
  while (truthy(true_instance())) {
    cmp = i->m_spaceship((new Array({val})), nullptr, nullptr);
    if (truthy(cmp->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
      return true_instance();
    }
    if (truthy(cmp->m_gt((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
      return false_instance();
    }
    if (truthy(([&]() -> BasicObject* { auto* _l = e->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr); return truthy(_l) ? ((i->m_spaceship((new Array({e})), nullptr, nullptr))->m_ge((new Array({((truthy(this->m_exclude_end_q((new Array({})), nullptr, nullptr)) ? (((new Integer(0LL)))) : (((new Integer(1LL))))))})), nullptr, nullptr)) : _l; }()))) {
      break;
    }
    s = i->m_succ((new Array({})), nullptr, nullptr);
    if (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = begin_len; return truthy(_l) ? (s->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (s->m_length((new Array({})), nullptr, nullptr)->m_gt((new Array({begin_len})), nullptr, nullptr)) : _l; }()))) {
      return false_instance();
    }
    if (truthy(s->m_eq_q((new Array({i})), nullptr, nullptr))) {
      return false_instance();
    }
    i = s;
  }
  return false_instance();
  return nil_instance();
}

inline BasicObject* Range::m_member_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* val = array_at(args, 0);
  Proc* _block = block;
  BasicObject* b = nil_instance();
  BasicObject* e = nil_instance();
  BasicObject* begin_len = nil_instance();
  BasicObject* i = nil_instance();
  BasicObject* cmp = nil_instance();
  BasicObject* s = nil_instance();
  b = this->m_begin((new Array({})), nullptr, nullptr);
  e = this->m_end((new Array({})), nullptr, nullptr);
  if (truthy(([&]() -> BasicObject* { auto* _l = b->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (b->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)); }()))) {
    return this->m_cover_q((new Array({val})), nullptr, nullptr);
  }
  if (truthy(b->m_respond_to_q((new Array({intern("succ")})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return this->m_cover_q((new Array({val})), nullptr, nullptr);
  }
  if (truthy(this->m_cover_q((new Array({val})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return false_instance();
  }
  begin_len = (truthy(b->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)) ? ((b->m_length((new Array({})), nullptr, nullptr))) : ((nil_instance())));
  i = b;
  while (truthy(true_instance())) {
    cmp = i->m_spaceship((new Array({val})), nullptr, nullptr);
    if (truthy(cmp->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
      return true_instance();
    }
    if (truthy(cmp->m_gt((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
      return false_instance();
    }
    if (truthy(([&]() -> BasicObject* { auto* _l = e->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr); return truthy(_l) ? ((i->m_spaceship((new Array({e})), nullptr, nullptr))->m_ge((new Array({((truthy(this->m_exclude_end_q((new Array({})), nullptr, nullptr)) ? (((new Integer(0LL)))) : (((new Integer(1LL))))))})), nullptr, nullptr)) : _l; }()))) {
      break;
    }
    s = i->m_succ((new Array({})), nullptr, nullptr);
    if (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = begin_len; return truthy(_l) ? (s->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (s->m_length((new Array({})), nullptr, nullptr)->m_gt((new Array({begin_len})), nullptr, nullptr)) : _l; }()))) {
      return false_instance();
    }
    if (truthy(s->m_eq_q((new Array({i})), nullptr, nullptr))) {
      return false_instance();
    }
    i = s;
  }
  return false_instance();
  return nil_instance();
}

inline BasicObject* Range::m_minmax(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* b = nil_instance();
  BasicObject* e = nil_instance();
  BasicObject* a = nil_instance();
  return (truthy(block) ? (((b = this->m_begin((new Array({})), nullptr, nullptr)), (e = this->m_end((new Array({})), nullptr, nullptr)), (truthy(b->m_nil_q((new Array({})), nullptr, nullptr)) ? ((([&]() -> BasicObject* { throw (new RangeError((new String("cannot get the minimum of beginless range", 41)))); }()))) : (nil_instance())), (truthy(e->m_nil_q((new Array({})), nullptr, nullptr)) ? ((([&]() -> BasicObject* { throw (new RangeError((new String("cannot get the maximum of endless range", 39)))); }()))) : (nil_instance())), (a = this->m_to_a((new Array({})), nullptr, nullptr)), (new Array({a->m_min((new Array({})), nullptr, static_cast<Proc*>(block)), a->m_max((new Array({})), nullptr, static_cast<Proc*>(block))})))) : (((new Array({this->m_min((new Array({})), nullptr, nullptr), this->m_max((new Array({})), nullptr, nullptr)})))));
  return nil_instance();
}

inline BasicObject* Range::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* b = nil_instance();
  BasicObject* e = nil_instance();
  BasicObject* sep = nil_instance();
  b = this->m_begin((new Array({})), nullptr, nullptr);
  e = this->m_end((new Array({})), nullptr, nullptr);
  sep = (truthy(this->m_exclude_end_q((new Array({})), nullptr, nullptr)) ? (((new String("...", 3)))) : (((new String("..", 2)))));
  return (truthy(([&]() -> BasicObject* { auto* _l = b->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? (e->m_nil_q((new Array({})), nullptr, nullptr)) : _l; }())) ? ((((new String("", 0))->m_plus((new Array({(new String("nil", 3))})), nullptr, nullptr)->m_plus((new Array({(sep)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String("nil", 3))})), nullptr, nullptr)))) : ((truthy(b->m_nil_q((new Array({})), nullptr, nullptr)) ? ((((new String("", 0))->m_plus((new Array({(sep)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(e)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))) : ((truthy(e->m_nil_q((new Array({})), nullptr, nullptr)) ? ((((new String("", 0))->m_plus((new Array({(b)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(sep)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))) : ((((new String("", 0))->m_plus((new Array({(b)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(sep)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(e)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))))))));
  return nil_instance();
}

inline BasicObject* Range::m_inspect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* b = nil_instance();
  BasicObject* e = nil_instance();
  BasicObject* sep = nil_instance();
  b = this->m_begin((new Array({})), nullptr, nullptr);
  e = this->m_end((new Array({})), nullptr, nullptr);
  sep = (truthy(this->m_exclude_end_q((new Array({})), nullptr, nullptr)) ? (((new String("...", 3)))) : (((new String("..", 2)))));
  return (truthy(([&]() -> BasicObject* { auto* _l = b->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? (e->m_nil_q((new Array({})), nullptr, nullptr)) : _l; }())) ? ((((new String("", 0))->m_plus((new Array({(new String("nil", 3))})), nullptr, nullptr)->m_plus((new Array({(sep)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String("nil", 3))})), nullptr, nullptr)))) : ((truthy(b->m_nil_q((new Array({})), nullptr, nullptr)) ? ((((new String("", 0))->m_plus((new Array({(sep)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(e->m_inspect((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))) : ((truthy(e->m_nil_q((new Array({})), nullptr, nullptr)) ? ((((new String("", 0))->m_plus((new Array({(b->m_inspect((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(sep)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))) : ((((new String("", 0))->m_plus((new Array({(b->m_inspect((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(sep)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(e->m_inspect((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))))))));
  return nil_instance();
}

inline BasicObject* Range::m_eq_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = other->m_is_a_q((new Array({(&Range_CLASS)})), nullptr, nullptr); return truthy(_l) ? (this->m_begin((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_begin((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (this->m_end((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_end((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (this->m_exclude_end_q((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_exclude_end_q((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* Range::m_eql_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = other->m_is_a_q((new Array({(&Range_CLASS)})), nullptr, nullptr); return truthy(_l) ? (this->m_begin((new Array({})), nullptr, nullptr)->m_eql_q((new Array({other->m_begin((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (this->m_end((new Array({})), nullptr, nullptr)->m_eql_q((new Array({other->m_end((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (this->m_exclude_end_q((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_exclude_end_q((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* Range::m_step(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = (args->data.size() > 0) ? args->data[0] : (intern("__unset__"));
  Proc* _block = block;
  BasicObject* n_given = nil_instance();
  BasicObject* b = nil_instance();
  BasicObject* e = nil_instance();
  BasicObject* excl = nil_instance();
  BasicObject* b_numeric = nil_instance();
  BasicObject* e_numeric_val = nil_instance();
  BasicObject* e_numeric = nil_instance();
  BasicObject* numeric = nil_instance();
  BasicObject* arithmetic = nil_instance();
  BasicObject* rng = nil_instance();
  BasicObject* as_args = nil_instance();
  BasicObject* coerced = nil_instance();
  BasicObject* use_float = nil_instance();
  n_given = n->m_equal_q((new Array({intern("__unset__")})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr);
  if (truthy(n_given)) {
    nil_instance();
  } else {
    n = (new Integer(1LL));
  }
  b = this->m_begin((new Array({})), nullptr, nullptr);
  e = this->m_end((new Array({})), nullptr, nullptr);
  excl = this->m_exclude_end_q((new Array({})), nullptr, nullptr);
  if (truthy(([&]() -> BasicObject* { auto* _l = b->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? (e->m_nil_q((new Array({})), nullptr, nullptr)) : _l; }()))) {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("cannot step endless beginless range", 35)))); }());
  }
  b_numeric = ([&]() -> BasicObject* { auto* _l = b->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (b->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)); }());
  e_numeric_val = ([&]() -> BasicObject* { auto* _l = e->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (e->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)); }());
  e_numeric = ([&]() -> BasicObject* { auto* _l = e->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (e_numeric_val); }());
  numeric = ([&]() -> BasicObject* { auto* _l = b_numeric; return truthy(_l) ? (e_numeric) : _l; }());
  arithmetic = ([&]() -> BasicObject* { auto* _l = numeric; return truthy(_l) ? _l : ((([&]() -> BasicObject* { auto* _l = b->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? (e_numeric_val) : _l; }()))); }());
  if (truthy(block)) {
    nil_instance();
  } else {
    if (truthy(([&]() -> BasicObject* { auto* _l = numeric; return truthy(_l) ? ((([&]() -> BasicObject* { auto* _l = n->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr); return truthy(_l) ? _l : (n->m_eq_q((new Array({(new Float(0.0))})), nullptr, nullptr)); }()))) : _l; }()))) {
      ([&]() -> BasicObject* { throw (new ArgumentError((new String("step can't be 0", 15)))); }());
    }
    rng = this;
    if (truthy(arithmetic)) {
      as_args = (truthy(n_given) ? (((new Array({n})))) : (((new Array({})))));
      return (&Enumerator_ArithmeticSequence_CLASS)->m__from_method((new Array({this, intern("step"), as_args, this->m_proc((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { return rng->m_send((new Array({intern("__step_size__"), n})), nullptr, nullptr); })))})), nullptr, nullptr);
    }
    return this->m_to_enum((new Array({intern("step"), n})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { return this->m___step_size__((new Array({n})), nullptr, nullptr); })));
  }
  if (truthy(numeric)) {
    if (truthy(([&]() -> BasicObject* { auto* _l = n->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (n->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)); }()))) {
      nil_instance();
    } else {
      if (truthy(n->m_respond_to_q((new Array({intern("coerce")})), nullptr, nullptr))) {
        coerced = n->m_coerce((new Array({b->m_to_f((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
        n = coerced->m_aref((new Array({(new Integer(1LL))})), nullptr, nullptr);
      } else {
        ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of ", 26))})), nullptr, nullptr)->m_plus((new Array({(n->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into Float", 11))})), nullptr, nullptr)))); }());
      }
    }
    if (truthy(([&]() -> BasicObject* { auto* _l = n->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr); return truthy(_l) ? _l : (n->m_eq_q((new Array({(new Float(0.0))})), nullptr, nullptr)); }()))) {
      ([&]() -> BasicObject* { throw (new ArgumentError((new String("step can't be 0", 15)))); }());
    }
  }
  if (truthy(numeric)) {
    use_float = ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = n->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (b->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)); }()); return truthy(_l) ? _l : ((([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = e->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr); return truthy(_l) ? (e_numeric_val) : _l; }()); return truthy(_l) ? (e->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)) : _l; }()))); }());
    if (truthy(use_float)) {
      this->m___step_float__((new Array({b->m_to_f((new Array({})), nullptr, nullptr), (truthy(e->m_nil_q((new Array({})), nullptr, nullptr)) ? ((nil_instance())) : ((e->m_to_f((new Array({})), nullptr, nullptr)))), n->m_to_f((new Array({})), nullptr, nullptr), excl})), nullptr, static_cast<Proc*>(block));
    } else {
      this->m___step_integer__((new Array({b, e, n, excl})), nullptr, static_cast<Proc*>(block));
    }
  } else {
    if (truthy(n->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr))) {
      if (truthy(b->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr))) {
        ([&]() -> BasicObject* { throw (new TypeError((new String("no implicit conversion of Float into String", 43)))); }());
      }
      ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of Float into ", 37))})), nullptr, nullptr)->m_plus((new Array({(b->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))); }());
    } else {
      if (truthy(n->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr))) {
        this->m___step_succ__((new Array({b, e, n, excl})), nullptr, static_cast<Proc*>(block));
      } else {
        this->m___step_plus__((new Array({b, e, n, excl})), nullptr, static_cast<Proc*>(block));
      }
    }
  }
  return this;
  return nil_instance();
}

inline BasicObject* Range::m_reduce(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* init = (args->data.size() > 0) ? args->data[0] : (nil_instance());
  Proc* _block = block;
  BasicObject* acc = nil_instance();
  BasicObject* first = nil_instance();
  if (truthy(init->m_nil_q((new Array({})), nullptr, nullptr))) {
    acc = nil_instance();
    first = true_instance();
    this->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return (truthy(first) ? ((((acc = x), (first = false_instance())))) : ((((acc = block->m_call((new Array({acc, x})), nullptr, nullptr)))))); })));
  } else {
    acc = init;
    this->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return (acc = block->m_call((new Array({acc, x})), nullptr, nullptr)); })));
  }
  return acc;
  return nil_instance();
}

inline BasicObject* Range::m_inject(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* init = (args->data.size() > 0) ? args->data[0] : (nil_instance());
  Proc* _block = block;
  BasicObject* acc = nil_instance();
  BasicObject* first = nil_instance();
  if (truthy(init->m_nil_q((new Array({})), nullptr, nullptr))) {
    acc = nil_instance();
    first = true_instance();
    this->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return (truthy(first) ? ((((acc = x), (first = false_instance())))) : ((((acc = block->m_call((new Array({acc, x})), nullptr, nullptr)))))); })));
  } else {
    acc = init;
    this->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return (acc = block->m_call((new Array({acc, x})), nullptr, nullptr)); })));
  }
  return acc;
  return nil_instance();
}

inline BasicObject* Range::m_last(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* n = nil_instance();
  if (truthy(args->m_empty_q((new Array({})), nullptr, nullptr))) {
    if (truthy(this->m_end((new Array({})), nullptr, nullptr)->m_nil_q((new Array({})), nullptr, nullptr))) {
      ([&]() -> BasicObject* { throw (new RangeError((new String("cannot get the last element of endless range", 44)))); }());
    }
    return this->m_end((new Array({})), nullptr, nullptr);
  }
  n = this->m___coerce_to_int__((new Array({args->m_aref((new Array({(new Integer(0LL))})), nullptr, nullptr)})), nullptr, nullptr);
  if (truthy(this->m_end((new Array({})), nullptr, nullptr)->m_nil_q((new Array({})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new RangeError((new String("cannot get the last element of endless range", 44)))); }());
  }
  if (truthy(n->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("negative array size (or exceeds maximum)", 40)))); }());
  }
  return this->m_to_a((new Array({})), nullptr, nullptr)->m_last((new Array({n})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Range::m_mod(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = array_at(args, 0);
  Proc* _block = block;
  BasicObject* b = nil_instance();
  BasicObject* e = nil_instance();
  BasicObject* b_numeric = nil_instance();
  BasicObject* e_numeric = nil_instance();
  BasicObject* numeric = nil_instance();
  BasicObject* arithmetic = nil_instance();
  BasicObject* rng = nil_instance();
  if (truthy(block)) {
    return this->m_step((new Array({n})), nullptr, static_cast<Proc*>(block));
  }
  b = this->m_begin((new Array({})), nullptr, nullptr);
  e = this->m_end((new Array({})), nullptr, nullptr);
  b_numeric = ([&]() -> BasicObject* { auto* _l = b->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (b->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)); }());
  e_numeric = ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = e->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (e->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr)); }()); return truthy(_l) ? _l : (e->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)); }());
  numeric = ([&]() -> BasicObject* { auto* _l = b_numeric; return truthy(_l) ? (e_numeric) : _l; }());
  arithmetic = ([&]() -> BasicObject* { auto* _l = numeric; return truthy(_l) ? _l : ((([&]() -> BasicObject* { auto* _l = b->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? ((([&]() -> BasicObject* { auto* _l = e->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (e->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)); }()))) : _l; }()))); }());
  if (truthy(([&]() -> BasicObject* { auto* _l = numeric; return truthy(_l) ? ((([&]() -> BasicObject* { auto* _l = n->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr); return truthy(_l) ? _l : (n->m_eq_q((new Array({(new Float(0.0))})), nullptr, nullptr)); }()))) : _l; }()))) {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("step can't be 0", 15)))); }());
  }
  rng = this;
  if (truthy(arithmetic)) {
    return (&Enumerator_ArithmeticSequence_CLASS)->m__from_method((new Array({this, intern("%"), (new Array({n})), this->m_proc((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { return rng->m_send((new Array({intern("__step_size__"), n})), nullptr, nullptr); })))})), nullptr, nullptr);
  }
  return this->m_to_enum((new Array({intern("%"), n})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { return this->m___step_size__((new Array({n})), nullptr, nullptr); })));
  return nil_instance();
}

inline BasicObject* Range::m_overlap_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  BasicObject* a_begin = nil_instance();
  BasicObject* a_end = nil_instance();
  BasicObject* a_excl = nil_instance();
  BasicObject* b_begin = nil_instance();
  BasicObject* b_end = nil_instance();
  BasicObject* b_excl = nil_instance();
  BasicObject* cmp = nil_instance();
  if (truthy(other->m_is_a_q((new Array({(&Range_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("wrong argument type ", 20))})), nullptr, nullptr)->m_plus((new Array({(other->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" (expected Range)", 17))})), nullptr, nullptr)))); }());
  }
  a_begin = this->m_begin((new Array({})), nullptr, nullptr);
  a_end = this->m_end((new Array({})), nullptr, nullptr);
  a_excl = this->m_exclude_end_q((new Array({})), nullptr, nullptr);
  b_begin = other->m_begin((new Array({})), nullptr, nullptr);
  b_end = other->m_end((new Array({})), nullptr, nullptr);
  b_excl = other->m_exclude_end_q((new Array({})), nullptr, nullptr);
  if (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = a_begin->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr); return truthy(_l) ? (a_end->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (((truthy(a_excl) ? ((a_begin->m_ge((new Array({a_end})), nullptr, nullptr))) : ((a_begin->m_gt((new Array({a_end})), nullptr, nullptr)))))) : _l; }()))) {
    return false_instance();
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = b_begin->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr); return truthy(_l) ? (b_end->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (((truthy(b_excl) ? ((b_begin->m_ge((new Array({b_end})), nullptr, nullptr))) : ((b_begin->m_gt((new Array({b_end})), nullptr, nullptr)))))) : _l; }()))) {
    return false_instance();
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = a_end->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr); return truthy(_l) ? (b_begin->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr)) : _l; }()))) {
    cmp = a_end->m_spaceship((new Array({b_begin})), nullptr, nullptr);
    if (truthy(cmp->m_nil_q((new Array({})), nullptr, nullptr))) {
      return false_instance();
    }
    if (truthy((truthy(a_excl) ? ((cmp->m_le((new Array({(new Integer(0LL))})), nullptr, nullptr))) : ((cmp->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr)))))) {
      return false_instance();
    }
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = b_end->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr); return truthy(_l) ? (a_begin->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr)) : _l; }()))) {
    cmp = b_end->m_spaceship((new Array({a_begin})), nullptr, nullptr);
    if (truthy(cmp->m_nil_q((new Array({})), nullptr, nullptr))) {
      return false_instance();
    }
    if (truthy((truthy(b_excl) ? ((cmp->m_le((new Array({(new Integer(0LL))})), nullptr, nullptr))) : ((cmp->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr)))))) {
      return false_instance();
    }
  }
  return true_instance();
  return nil_instance();
}

inline BasicObject* Range::m_each_slice(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = array_at(args, 0);
  Proc* _block = block;
  BasicObject* slice = nil_instance();
  if (truthy(this->m_block_given_q((new Array({})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("each_slice"), n})), nullptr, nullptr);
  }
  slice = (new Array({}));
  this->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; slice->m_lshift((new Array({x})), nullptr, nullptr); return (truthy(slice->m_length((new Array({})), nullptr, nullptr)->m_eq_q((new Array({n})), nullptr, nullptr)) ? ((_block->m_call((new Array({slice})), nullptr, nullptr), (slice = (new Array({}))))) : (nil_instance())); })));
  if (truthy(slice->m_empty_q((new Array({})), nullptr, nullptr))) {
    nil_instance();
  } else {
    _block->m_call((new Array({slice})), nullptr, nullptr);
  }
  return this;
  return nil_instance();
}

inline BasicObject* Range::m_each_cons(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = array_at(args, 0);
  Proc* _block = block;
  BasicObject* buf = nil_instance();
  if (truthy(this->m_block_given_q((new Array({})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("each_cons"), n})), nullptr, nullptr);
  }
  buf = (new Array({}));
  this->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; buf->m_lshift((new Array({x})), nullptr, nullptr); return (truthy(buf->m_length((new Array({})), nullptr, nullptr)->m_eq_q((new Array({n})), nullptr, nullptr)) ? ((_block->m_call((new Array({buf->m_dup((new Array({})), nullptr, nullptr)})), nullptr, nullptr), buf->m_shift((new Array({})), nullptr, nullptr))) : (nil_instance())); })));
  return this;
  return nil_instance();
}

inline BasicObject* Range::m_reverse_each(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* b = nil_instance();
  BasicObject* e = nil_instance();
  BasicObject* excl = nil_instance();
  BasicObject* i = nil_instance();
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("reverse_each")})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { return this->m___reverse_each_size__((new Array({})), nullptr, nullptr); })));
  }
  b = this->m_begin((new Array({})), nullptr, nullptr);
  e = this->m_end((new Array({})), nullptr, nullptr);
  excl = this->m_exclude_end_q((new Array({})), nullptr, nullptr);
  if (truthy(e->m_nil_q((new Array({})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new TypeError((new String("can't iterate from NilClass", 27)))); }());
  }
  if (truthy(b->m_nil_q((new Array({})), nullptr, nullptr))) {
    if (truthy(e->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr))) {
      nil_instance();
    } else {
      ([&]() -> BasicObject* { throw (new TypeError((new String("can't iterate from NilClass", 27)))); }());
    }
    i = (truthy(excl) ? ((e->m_minus((new Array({(new Integer(1LL))})), nullptr, nullptr))) : ((e)));
    this->m_loop((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { block->m_call((new Array({i})), nullptr, nullptr); return (i = i->m_minus((new Array({(new Integer(1LL))})), nullptr, nullptr)); })));
  } else {
    if (truthy(b->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr))) {
      if (truthy(e->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr))) {
        nil_instance();
      } else {
        ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("can't iterate from ", 19))})), nullptr, nullptr)->m_plus((new Array({(e->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))); }());
      }
      i = (truthy(excl) ? ((e->m_minus((new Array({(new Integer(1LL))})), nullptr, nullptr))) : ((e)));
      while (truthy(i->m_ge((new Array({b})), nullptr, nullptr))) {
        block->m_call((new Array({i})), nullptr, nullptr);
        i = i->m_minus((new Array({(new Integer(1LL))})), nullptr, nullptr);
      }
    } else {
      this->m_to_a((new Array({})), nullptr, nullptr)->m_reverse_each((new Array({})), nullptr, static_cast<Proc*>(block));
    }
  }
  return this;
  return nil_instance();
}

inline BasicObject* Range::m_split(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* sep = (args->data.size() > 0) ? args->data[0] : (nil_instance());
  BasicObject* limit = (args->data.size() > 1) ? args->data[1] : (nil_instance());
  Proc* _block = block;
  BasicObject* v = nil_instance();
  v = this->m_end((new Array({})), nullptr, nullptr);
  v = (truthy(v->m_nil_q((new Array({})), nullptr, nullptr)) ? (((new String("", 0)))) : ((v->m_to_s((new Array({})), nullptr, nullptr))));
  return (truthy(limit->m_nil_q((new Array({})), nullptr, nullptr)) ? ((v->m_split((new Array({sep})), nullptr, nullptr))) : ((v->m_split((new Array({sep, limit})), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* Range::m___bsearch_size__(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Range::m___cover_value___q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* val = array_at(args, 0);
  Proc* _block = block;
  BasicObject* b = nil_instance();
  BasicObject* e = nil_instance();
  BasicObject* cmp = nil_instance();
  BasicObject* cmp2 = nil_instance();
  b = this->m_begin((new Array({})), nullptr, nullptr);
  e = this->m_end((new Array({})), nullptr, nullptr);
  if (truthy(([&]() -> BasicObject* { auto* _l = b->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr); return truthy(_l) ? ((([&]() -> BasicObject* { auto* _l = ((cmp = b->m_spaceship((new Array({val})), nullptr, nullptr)))->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (cmp->m_gt((new Array({(new Integer(0LL))})), nullptr, nullptr)); }()))) : _l; }()))) {
    return false_instance();
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = e->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr); return truthy(_l) ? ((([&]() -> BasicObject* { auto* _l = ((cmp2 = val->m_spaceship((new Array({e})), nullptr, nullptr)))->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (((truthy(this->m_exclude_end_q((new Array({})), nullptr, nullptr)) ? ((cmp2->m_ge((new Array({(new Integer(0LL))})), nullptr, nullptr))) : ((cmp2->m_gt((new Array({(new Integer(0LL))})), nullptr, nullptr)))))); }()))) : _l; }()))) {
    return false_instance();
  }
  return true_instance();
  return nil_instance();
}

inline BasicObject* Range::m___step_float__(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* b_f = array_at(args, 0);
  BasicObject* e_f = array_at(args, 1);
  BasicObject* step_f = array_at(args, 2);
  BasicObject* excl = array_at(args, 3);
  Proc* _block = block;
  return (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = e_f->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : ((([&]() -> BasicObject* { auto* _l = e_f->m_respond_to_q((new Array({intern("infinite?")})), nullptr, nullptr); return truthy(_l) ? (e_f->m_infinite_q((new Array({})), nullptr, nullptr)) : _l; }()))); }()); return truthy(_l) ? _l : ((([&]() -> BasicObject* { auto* _l = b_f->m_respond_to_q((new Array({intern("infinite?")})), nullptr, nullptr); return truthy(_l) ? (b_f->m_infinite_q((new Array({})), nullptr, nullptr)) : _l; }()))); }())) ? ((this->m___step_float_unbounded__((new Array({b_f, e_f, step_f, excl})), nullptr, static_cast<Proc*>(block)))) : ((truthy(step_f->m_gt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((this->m___step_float_positive__((new Array({b_f, e_f, step_f, excl})), nullptr, static_cast<Proc*>(block)))) : ((this->m___step_float_negative__((new Array({b_f, e_f, step_f, excl})), nullptr, static_cast<Proc*>(block)))))));
  return nil_instance();
}

inline BasicObject* Range::m___bsearch_integer__(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* lo = array_at(args, 0);
  BasicObject* hi = array_at(args, 1);
  BasicObject* excl = array_at(args, 2);
  Proc* _block = block;
  BasicObject* lo_val = nil_instance();
  BasicObject* hi_val = nil_instance();
  BasicObject* r0 = nil_instance();
  lo_val = (truthy(lo->m_nil_q((new Array({})), nullptr, nullptr)) ? (((((new Integer(2LL))->m_pow((new Array({(new Integer(62LL))})), nullptr, nullptr))->m_neg((new Array({})), nullptr, nullptr)))) : ((lo)));
  hi_val = (truthy(hi->m_nil_q((new Array({})), nullptr, nullptr)) ? ((((new Integer(2LL))->m_pow((new Array({(new Integer(62LL))})), nullptr, nullptr)))) : ((((truthy(excl) ? ((hi->m_minus((new Array({(new Integer(1LL))})), nullptr, nullptr))) : ((hi)))))));
  if (truthy(lo_val->m_gt((new Array({hi_val})), nullptr, nullptr))) {
    return nil_instance();
  }
  r0 = block->m_call((new Array({lo_val})), nullptr, nullptr);
  this->m___bsearch_validate__((new Array({r0})), nullptr, nullptr);
  return (truthy(r0->m_is_a_q((new Array({(&Numeric_CLASS)})), nullptr, nullptr)) ? ((this->m___bsearch_int_any__((new Array({lo_val, hi_val, r0})), nullptr, static_cast<Proc*>(block)))) : ((this->m___bsearch_int_min__((new Array({lo_val, hi_val, r0})), nullptr, static_cast<Proc*>(block)))));
  return nil_instance();
}

inline BasicObject* Range::m___bsearch_int_min__(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* lo = array_at(args, 0);
  BasicObject* hi = array_at(args, 1);
  BasicObject* r0 = array_at(args, 2);
  Proc* _block = block;
  BasicObject* result = nil_instance();
  BasicObject* left = nil_instance();
  BasicObject* right = nil_instance();
  BasicObject* mid = nil_instance();
  BasicObject* r = nil_instance();
  result = (truthy(r0) ? ((lo)) : ((nil_instance())));
  left = (truthy(r0) ? ((lo)) : ((lo->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr))));
  right = hi;
  while (truthy(left->m_le((new Array({right})), nullptr, nullptr))) {
    mid = left->m_plus((new Array({(right->m_minus((new Array({left})), nullptr, nullptr))->m_div((new Array({(new Integer(2LL))})), nullptr, nullptr)})), nullptr, nullptr);
    r = block->m_call((new Array({mid})), nullptr, nullptr);
    if (truthy(r->m_is_a_q((new Array({(&Numeric_CLASS)})), nullptr, nullptr))) {
      ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("wrong argument type ", 20))})), nullptr, nullptr)->m_plus((new Array({(r->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" (must be true, false or nil)", 29))})), nullptr, nullptr)))); }());
    }
    this->m___bsearch_validate__((new Array({r})), nullptr, nullptr);
    if (truthy(r)) {
      result = mid;
      right = mid->m_minus((new Array({(new Integer(1LL))})), nullptr, nullptr);
    } else {
      left = mid->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr);
    }
  }
  return result;
  return nil_instance();
}

inline BasicObject* Range::m___bsearch_int_any__(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* lo = array_at(args, 0);
  BasicObject* hi = array_at(args, 1);
  BasicObject* r0 = array_at(args, 2);
  Proc* _block = block;
  BasicObject* n0 = nil_instance();
  BasicObject* left = nil_instance();
  BasicObject* right = nil_instance();
  BasicObject* mid = nil_instance();
  BasicObject* r = nil_instance();
  BasicObject* n = nil_instance();
  n0 = (truthy(r0->m_is_a_q((new Array({(&Numeric_CLASS)})), nullptr, nullptr)) ? ((r0)) : ((((truthy(r0) ? (((new Integer(1LL)))) : (((new Integer(-1LL)))))))));
  if (truthy(n0->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
    return lo;
  }
  if (truthy(n0->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
    return nil_instance();
  }
  left = lo->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr);
  right = hi;
  while (truthy(left->m_le((new Array({right})), nullptr, nullptr))) {
    mid = left->m_plus((new Array({(right->m_minus((new Array({left})), nullptr, nullptr))->m_div((new Array({(new Integer(2LL))})), nullptr, nullptr)})), nullptr, nullptr);
    r = block->m_call((new Array({mid})), nullptr, nullptr);
    this->m___bsearch_validate__((new Array({r})), nullptr, nullptr);
    n = (truthy(r->m_is_a_q((new Array({(&Numeric_CLASS)})), nullptr, nullptr)) ? ((r)) : ((((truthy(r) ? (((new Integer(1LL)))) : (((new Integer(-1LL)))))))));
    if (truthy(n->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
      return mid;
    } else {
      if (truthy(n->m_gt((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
        left = mid->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr);
      } else {
        right = mid->m_minus((new Array({(new Integer(1LL))})), nullptr, nullptr);
      }
    }
  }
  return nil_instance();
  return nil_instance();
}

inline Enumerator::Enumerator(BasicObject* size, Proc* block) {
  this->m___check_frozen__((new Array({})), nullptr, nullptr);
  (this->iv_block = block);
  (this->iv_size = size);
  (this->iv_receiver = nil_instance());
  (this->iv_method_name = nil_instance());
  (this->iv_method_args = (new Array({})));
  (this->iv_method_kwargs = (new Hash({})));
  (this->iv_size_block = nil_instance());
  (this->iv_fiber = nil_instance());
  (this->iv_peeked = false_instance());
  (this->iv_peeked_vals = nil_instance());
  (this->iv_feed = nil_instance());
  (this->iv__feed_pending = false_instance());
  (this->iv__fiber_started = false_instance());
  this;
}

inline BasicObject* Enumerator::m_next_values(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m___next_values_raw__((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Enumerator::m_peek_values(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m___peek_values_raw__((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Enumerator::m_next(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* vals = nil_instance();
  return (truthy(((vals = this->m___next_values_raw__((new Array({})), nullptr, nullptr)))->m_empty_q((new Array({})), nullptr, nullptr)) ? ((nil_instance())) : ((((truthy(vals->m_length((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(1LL))})), nullptr, nullptr)) ? ((vals->m_aref((new Array({(new Integer(0LL))})), nullptr, nullptr))) : ((vals)))))));
  return nil_instance();
}

inline BasicObject* Enumerator::m_peek(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* vals = nil_instance();
  return (truthy(((vals = this->m___peek_values_raw__((new Array({})), nullptr, nullptr)))->m_empty_q((new Array({})), nullptr, nullptr)) ? ((nil_instance())) : ((((truthy(vals->m_length((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(1LL))})), nullptr, nullptr)) ? ((vals->m_aref((new Array({(new Integer(0LL))})), nullptr, nullptr))) : ((vals)))))));
  return nil_instance();
}

inline BasicObject* Enumerator::m_with_object(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  return this->m_each_with_object((new Array({obj})), nullptr, static_cast<Proc*>(block));
  return nil_instance();
}

inline BasicObject* Enumerator::m_plus(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return (new Enumerator_Chain(static_cast<BasicObject*>(this), static_cast<BasicObject*>(other)));
  return nil_instance();
}

inline BasicObject* Enumerator::m_count(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* s = nil_instance();
  return (truthy(((s = this->m_size((new Array({})), nullptr, nullptr)))->m_nil_q((new Array({})), nullptr, nullptr)) ? ((this->m_to_a((new Array({})), nullptr, nullptr)->m_length((new Array({})), nullptr, nullptr))) : ((s)));
  return nil_instance();
}

inline BasicObject* Enumerator::m_feed(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* val = array_at(args, 0);
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = this->iv__fiber_started; return truthy(_l) ? (this->iv__feed_pending) : _l; }()))) {
    ([&]() -> BasicObject* { throw (new TypeError((new String("feed value already set", 22)))); }());
  }
  (this->iv_feed = val);
  (this->iv__feed_pending = true_instance());
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Enumerator::m_rewind(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv_receiver->m_respond_to_q((new Array({intern("rewind")})), nullptr, nullptr))) {
    this->iv_receiver->m_rewind((new Array({})), nullptr, nullptr);
  }
  (this->iv_fiber = nil_instance());
  (this->iv_peeked = false_instance());
  (this->iv_peeked_vals = nil_instance());
  (this->iv_feed = nil_instance());
  (this->iv__feed_pending = false_instance());
  (this->iv__fiber_started = false_instance());
  return this;
  return nil_instance();
}

inline BasicObject* Enumerator::m_size(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->iv_size_block) ? ((this->iv_size_block->m_call((new Array({})), nullptr, nullptr))) : ((truthy(this->iv_size->m_respond_to_q((new Array({intern("call")})), nullptr, nullptr)) ? ((this->iv_size->m_call((new Array({})), nullptr, nullptr))) : ((this->iv_size)))));
  return nil_instance();
}

inline BasicObject* Enumerator::m_first(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = (args->data.size() > 0) ? args->data[0] : (nil_instance());
  Proc* _block = block;
  BasicObject* result = nil_instance();
  return (truthy(n->m_nil_q((new Array({})), nullptr, nullptr)) ? (((truthy(([&]() -> BasicObject* { auto* _l = this->iv_receiver; return truthy(_l) ? _l : (this->iv_block); }())) ? ((([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return this->m_next((new Array({})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StopIteration*>(e_) != nullptr) { return [&]() -> BasicObject* { return nil_instance();  return nil_instance(); }(); } throw; } }()))) : (nil_instance())), this->m_peek((new Array({})), nullptr, nullptr))) : (((result = (new Array({}))), ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return n->m_times((new Array({})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StopIteration*>(e_) != nullptr) { return [&]() -> BasicObject* { return nil_instance();  return nil_instance(); }(); } throw; } }()), this->m_rewind((new Array({})), nullptr, nullptr), result)));
  return nil_instance();
}

inline BasicObject* Enumerator::m___advance__(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* exc = nil_instance();
  BasicObject* vals = nil_instance();
  BasicObject* feed_val = nil_instance();
  this->m___ensure_fiber__((new Array({})), nullptr, nullptr);
  if (truthy(this->iv_fiber->m_alive_q((new Array({})), nullptr, nullptr))) {
    nil_instance();
  } else {
    exc = (new StopIteration(static_cast<BasicObject*>((new String("iteration reached an end", 24)))));
    exc->m_instance_variable_set((new Array({intern("@result"), this->iv__enum_result})), nullptr, nullptr);
    ([&]() -> BasicObject* { throw static_cast<Exception*>(exc); }());
  }
  if (truthy(this->iv__fiber_started)) {
    feed_val = this->iv_feed;
    (this->iv_feed = nil_instance());
    (this->iv__feed_pending = false_instance());
    vals = this->iv_fiber->m_resume((new Array({feed_val})), nullptr, nullptr);
  } else {
    (this->iv__fiber_started = true_instance());
    vals = this->iv_fiber->m_resume((new Array({nil_instance()})), nullptr, nullptr);
  }
  if (truthy(vals->m_nil_q((new Array({})), nullptr, nullptr))) {
    exc = (new StopIteration(static_cast<BasicObject*>((new String("iteration reached an end", 24)))));
    exc->m_instance_variable_set((new Array({intern("@result"), this->iv__enum_result})), nullptr, nullptr);
    ([&]() -> BasicObject* { throw static_cast<Exception*>(exc); }());
  }
  return vals;
  return nil_instance();
}

inline BasicObject* Enumerator::m___next_values_raw__(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* vals = nil_instance();
  BasicObject* e = nil_instance();
  if (truthy(this->iv_peeked)) {
    (this->iv_peeked = false_instance());
    vals = this->iv_peeked_vals;
    (this->iv_peeked_vals = nil_instance());
    return vals;
  }
  return ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return this->m___advance__((new Array({})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StopIteration*>(e_) != nullptr) { return [&]() -> BasicObject* { return ([&]() -> BasicObject* { throw; }());  return nil_instance(); }(); } if (dynamic_cast<StandardError*>(e_) != nullptr) { BasicObject* e = e_; return [&]() -> BasicObject* { (this->iv_fiber = nil_instance()); return ([&]() -> BasicObject* { throw; }());  return nil_instance(); }(); } throw; } }());
  return nil_instance();
}

inline BasicObject* Enumerator::m___peek_values_raw__(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv_peeked)) {
    nil_instance();
  } else {
    (this->iv_peeked_vals = this->m___advance__((new Array({})), nullptr, nullptr));
    (this->iv_peeked = true_instance());
  }
  return this->iv_peeked_vals;
  return nil_instance();
}

inline Enumerator_Yielder::Enumerator_Yielder(Proc* block) {
  (this->iv_block = block);
  this;
}

inline BasicObject* Enumerator_Yielder::m_lshift(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* arg = array_at(args, 0);
  Proc* _block = block;
  this->m_yield((new Array({arg})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Enumerator_Yielder::m_yield(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->iv_block) ? ((this->iv_block->m_call(static_cast<Array*>(args), nullptr, nullptr))) : (((&Fiber_CLASS)->m_yield((new Array({args})), nullptr, nullptr))));
  return nil_instance();
}

inline Enumerator_Generator::Enumerator_Generator(Proc* block) {
  this->m___check_frozen__((new Array({})), nullptr, nullptr);
  if (truthy(block)) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new LocalJumpError((new String("no block given", 14)))); }());
  }
  (this->iv_block = block);
  this;
}

inline Enumerator_Lazy::Enumerator_Lazy(BasicObject* obj, BasicObject* size, Proc* block) {
  this->m___check_frozen__((new Array({})), nullptr, nullptr);
  if (truthy(block)) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("tried to create Proc object without a block", 43)))); }());
  }
  (this->iv_receiver = obj);
  (this->iv__lazy_xform = block);
  (this->iv__xform_factory = nil_instance());
  (this->iv__grouped_eval = nil_instance());
  (this->iv__lazy_size = size);
  (this->iv_method_name = nil_instance());
  (this->iv_method_args = (new Array({})));
  (this->iv_method_kwargs = (new Hash({})));
  (this->iv_size_block = nil_instance());
  (this->iv_size = size);
  (this->iv_block = nil_instance());
  (this->iv_fiber = nil_instance());
  (this->iv_peeked = false_instance());
  (this->iv_peeked_vals = nil_instance());
  (this->iv_feed = nil_instance());
  (this->iv__feed_pending = false_instance());
  (this->iv__fiber_started = false_instance());
  this;
}

inline BasicObject* Enumerator_Lazy::m_lazy(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_with_object(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  return this->m_each_with_object((new Array({obj})), nullptr, static_cast<Proc*>(block));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_eager(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Enumerator());
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_first(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = (args->data.size() > 0) ? args->data[0] : (nil_instance());
  Proc* _block = block;
  return (truthy(n->m_nil_q((new Array({})), nullptr, nullptr)) ? ((this->m_take((new Array({(new Integer(1LL))})), nullptr, nullptr)->m_to_a((new Array({})), nullptr, nullptr)->m_aref((new Array({(new Integer(0LL))})), nullptr, nullptr))) : ((this->m_take((new Array({n})), nullptr, nullptr)->m_to_a((new Array({})), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_size(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv__lazy_size->m_respond_to_q((new Array({intern("call")})), nullptr, nullptr))) {
    return this->iv__lazy_size->m_call((new Array({})), nullptr, nullptr);
  }
  return this->iv__lazy_size;
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_map(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("map")})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { return this->m_size((new Array({})), nullptr, nullptr); })));
  }
  return (new Enumerator_Lazy(static_cast<BasicObject*>(this), static_cast<BasicObject*>(this->m_size((new Array({})), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_collect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("map")})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { return this->m_size((new Array({})), nullptr, nullptr); })));
  }
  return (new Enumerator_Lazy(static_cast<BasicObject*>(this), static_cast<BasicObject*>(this->m_size((new Array({})), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_select(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("tried to create Proc object without a block", 43)))); }());
  }
  return (new Enumerator_Lazy(static_cast<BasicObject*>(this)));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_filter(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("tried to create Proc object without a block", 43)))); }());
  }
  return (new Enumerator_Lazy(static_cast<BasicObject*>(this)));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_find_all(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("tried to create Proc object without a block", 43)))); }());
  }
  return (new Enumerator_Lazy(static_cast<BasicObject*>(this)));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_reject(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("tried to create Proc object without a block", 43)))); }());
  }
  return (new Enumerator_Lazy(static_cast<BasicObject*>(this)));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_flat_map(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("tried to create Proc object without a block", 43)))); }());
  }
  return (new Enumerator_Lazy(static_cast<BasicObject*>(this)));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_collect_concat(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("tried to create Proc object without a block", 43)))); }());
  }
  return (new Enumerator_Lazy(static_cast<BasicObject*>(this)));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_take_while(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("tried to create Proc object without a block", 43)))); }());
  }
  return (new Enumerator_Lazy(static_cast<BasicObject*>(this)));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_filter_map(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("tried to create Proc object without a block", 43)))); }());
  }
  return (new Enumerator_Lazy(static_cast<BasicObject*>(this)));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_compact(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Enumerator_Lazy(static_cast<BasicObject*>(this)));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_grep(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* pattern = array_at(args, 0);
  Proc* _block = block;
  return (truthy(block) ? (((new Enumerator_Lazy(static_cast<BasicObject*>(this))))) : (((new Enumerator_Lazy(static_cast<BasicObject*>(this))))));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_grep_v(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* pattern = array_at(args, 0);
  Proc* _block = block;
  return (truthy(block) ? (((new Enumerator_Lazy(static_cast<BasicObject*>(this))))) : (((new Enumerator_Lazy(static_cast<BasicObject*>(this))))));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_each_with_object(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("each_with_object"), obj})), nullptr, nullptr);
  }
  this->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* v = arg; return block->m_call((new Array({v, obj})), nullptr, nullptr); })));
  return obj;
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_each_with_index(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* i = nil_instance();
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("each_with_index")})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { return this->m_size((new Array({})), nullptr, nullptr); })));
  }
  i = (new Integer(0LL));
  return this->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* v = arg; block->m_call((new Array({v, i})), nullptr, nullptr); return (i = i->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr)); })));
  return nil_instance();
}

inline BasicObject* Enumerator_Lazy::m_inspect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(([&]() -> BasicObject* { auto* _l = this->iv_receiver->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? (this->iv__lazy_xform->m_nil_q((new Array({})), nullptr, nullptr)) : _l; }())) ? (((new String("#<Enumerator::Lazy: uninitialized>", 34)))) : ((truthy(this->iv_receiver) ? ((((new String("", 0))->m_plus((new Array({(new String("#<Enumerator::Lazy: ", 20))})), nullptr, nullptr)->m_plus((new Array({(this->iv_receiver->m_inspect((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(">", 1))})), nullptr, nullptr)))) : (((new String("#<Enumerator::Lazy: generator>", 30)))))));
  return nil_instance();
}

inline BasicObject* Enumerator_Chain::m_inspect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv_enums->m_nil_q((new Array({})), nullptr, nullptr))) {
    return (new String("#<Enumerator::Chain: uninitialized>", 35));
  }
  return ((new String("", 0))->m_plus((new Array({(new String("#<Enumerator::Chain: ", 21))})), nullptr, nullptr)->m_plus((new Array({(this->iv_enums->m_inspect((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(">", 1))})), nullptr, nullptr));
  return nil_instance();
}

inline BasicObject* Enumerator_Chain::m_each(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("each")})), nullptr, nullptr);
  }
  (this->iv__iterated_count = (new Integer(0LL)));
  this->iv_enums->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* e = arg; (this->iv__iterated_count = this->iv__iterated_count->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr)); return e->m_each((new Array({})), nullptr, static_cast<Proc*>(block)); })));
  return this;
  return nil_instance();
}

inline BasicObject* Enumerator_Chain::m_rewind(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* count = nil_instance();
  count = ([&]() -> BasicObject* { auto* _l = this->iv__iterated_count; return truthy(_l) ? _l : ((new Integer(0LL))); }());
  this->iv_enums->m_first((new Array({count})), nullptr, nullptr)->m_reverse_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* e = arg; return (truthy(e->m_respond_to_q((new Array({intern("rewind")})), nullptr, nullptr)) ? ((e->m_rewind((new Array({})), nullptr, nullptr))) : (nil_instance())); })));
  (this->iv__iterated_count = (new Integer(0LL)));
  return this;
  return nil_instance();
}

inline BasicObject* Enumerator_ArithmeticSequence::m_exclude_end_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv_receiver->m_is_a_q((new Array({(&Range_CLASS)})), nullptr, nullptr))) {
    this->iv_receiver->m_exclude_end_q((new Array({})), nullptr, nullptr);
  } else {
    false_instance();
  }
  return nil_instance();
}

inline BasicObject* Enumerator_ArithmeticSequence::m_begin(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->iv_receiver->m_is_a_q((new Array({(&Range_CLASS)})), nullptr, nullptr)) ? ((this->iv_receiver->m_begin((new Array({})), nullptr, nullptr))) : ((this->iv_receiver)));
  return nil_instance();
}

inline BasicObject* Enumerator_ArithmeticSequence::m_hash(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Array({this->m_begin((new Array({})), nullptr, nullptr), this->m_end((new Array({})), nullptr, nullptr), this->m_step((new Array({})), nullptr, nullptr), this->m_exclude_end_q((new Array({})), nullptr, nullptr)}))->m_hash((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Enumerator_ArithmeticSequence::m_end(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* kw = nil_instance();
  return (truthy(this->iv_receiver->m_is_a_q((new Array({(&Range_CLASS)})), nullptr, nullptr)) ? ((this->iv_receiver->m_end((new Array({})), nullptr, nullptr))) : (((kw = ([&]() -> BasicObject* { auto* _l = this->iv_method_kwargs; return truthy(_l) ? _l : ((new Hash({}))); }())), (truthy(kw->m_key_q((new Array({intern("to")})), nullptr, nullptr)) ? ((kw->m_aref((new Array({intern("to")})), nullptr, nullptr))) : ((this->iv_method_args->m_aref((new Array({(new Integer(0LL))})), nullptr, nullptr)))))));
  return nil_instance();
}

inline BasicObject* Enumerator_ArithmeticSequence::m_step(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* kw = nil_instance();
  return (truthy(this->iv_receiver->m_is_a_q((new Array({(&Range_CLASS)})), nullptr, nullptr)) ? ((([&]() -> BasicObject* { auto* _l = this->iv_method_args->m_first((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : ((new Integer(1LL))); }()))) : (((kw = ([&]() -> BasicObject* { auto* _l = this->iv_method_kwargs; return truthy(_l) ? _l : ((new Hash({}))); }())), (truthy(kw->m_key_q((new Array({intern("by")})), nullptr, nullptr)) ? ((kw->m_aref((new Array({intern("by")})), nullptr, nullptr))) : ((truthy(this->iv_method_args->m_length((new Array({})), nullptr, nullptr)->m_ge((new Array({(new Integer(2LL))})), nullptr, nullptr)) ? ((this->iv_method_args->m_aref((new Array({(new Integer(1LL))})), nullptr, nullptr))) : (((new Integer(1LL))))))))));
  return nil_instance();
}

inline BasicObject* Enumerator_ArithmeticSequence::m_last(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* b = nil_instance();
  BasicObject* e = nil_instance();
  BasicObject* s = nil_instance();
  BasicObject* n = nil_instance();
  b = this->m_begin((new Array({})), nullptr, nullptr);
  e = this->m_end((new Array({})), nullptr, nullptr);
  s = this->m_step((new Array({})), nullptr, nullptr);
  if (truthy(e->m_nil_q((new Array({})), nullptr, nullptr))) {
    return nil_instance();
  }
  n = (truthy(this->m_exclude_end_q((new Array({})), nullptr, nullptr)) ? ((((e->m_minus((new Array({b})), nullptr, nullptr))->m_div((new Array({s->m_to_f((new Array({})), nullptr, nullptr)})), nullptr, nullptr))->m_ceil((new Array({})), nullptr, nullptr)->m_minus((new Array({(new Integer(1LL))})), nullptr, nullptr))) : ((((e->m_minus((new Array({b})), nullptr, nullptr))->m_div((new Array({s->m_to_f((new Array({})), nullptr, nullptr)})), nullptr, nullptr))->m_floor((new Array({})), nullptr, nullptr))));
  return (truthy(n->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((nil_instance())) : ((b->m_plus((new Array({n->m_mul((new Array({s})), nullptr, nullptr)})), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* Enumerator_Product::m_rewind(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  this->iv_enumerables->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* e = arg; return (truthy(e->m_respond_to_q((new Array({intern("rewind")})), nullptr, nullptr)) ? ((e->m_rewind((new Array({})), nullptr, nullptr))) : (nil_instance())); })));
  return this;
  return nil_instance();
}

inline BasicObject* Enumerator_Product::m_each(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("each")})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { return this->m_size((new Array({})), nullptr, nullptr); })));
  }
  if (truthy(this->iv_enumerables->m_empty_q((new Array({})), nullptr, nullptr))) {
    block->m_call((new Array({(new Array({}))})), nullptr, nullptr);
  } else {
    this->m___product_each__((new Array({(new Integer(0LL)), (new Array({})), block})), nullptr, nullptr);
  }
  return this;
  return nil_instance();
}

inline BasicObject* Enumerator_Product::m_initialize_copy(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* source = array_at(args, 0);
  Proc* _block = block;
  if (truthy(source->m_equal_q((new Array({this})), nullptr, nullptr))) {
    return this;
  }
  this->m___check_frozen__((new Array({})), nullptr, nullptr);
  if (truthy(source->m_class((new Array({})), nullptr, nullptr)->m_eq_q((new Array({this->m_class((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError((new String("initialize_copy should take same class object", 45)))); }());
  }
  if (truthy(source->m_instance_variable_get((new Array({intern("@enumerables")})), nullptr, nullptr)->m_nil_q((new Array({})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("uninitialized product", 21)))); }());
  }
  (this->iv_enumerables = source->m_instance_variable_get((new Array({intern("@enumerables")})), nullptr, nullptr)->m_dup((new Array({})), nullptr, nullptr));
  (this->iv_fiber = nil_instance());
  (this->iv_peeked = false_instance());
  (this->iv_peeked_vals = nil_instance());
  (this->iv_feed = nil_instance());
  (this->iv__feed_pending = false_instance());
  (this->iv__fiber_started = false_instance());
  return this;
  return nil_instance();
}

inline Exception::Exception(BasicObject* message) {
  (this->iv_message = message);
}

inline BasicObject* Exception::m_message(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_s((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Exception::m_backtrace(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_backtrace;
  return nil_instance();
}

inline BasicObject* Exception::m_cause(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_cause;
  return nil_instance();
}

inline BasicObject* Exception::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->iv_message) ? ((this->iv_message->m_to_s((new Array({})), nullptr, nullptr))) : ((this->m_class((new Array({})), nullptr, nullptr)->m_to_s((new Array({})), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* Exception::m_backtrace_locations(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv__has_locations)) {
    nil_instance();
  } else {
    return nil_instance();
  }
  if (truthy(this->iv_backtrace->m_nil_q((new Array({})), nullptr, nullptr))) {
    return nil_instance();
  }
  return ([&]() -> BasicObject* { auto* _l = this->iv_backtrace_locations; return truthy(_l) ? _l : ((this->iv_backtrace_locations = this->iv_backtrace->m_map((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* s = arg; return (&Thread_Backtrace_Location_CLASS)->m__from_string((new Array({s->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr); }))))); }());
  return nil_instance();
}

inline BasicObject* Exception::m_exception(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* message = (args->data.size() > 0) ? args->data[0] : (nil_instance());
  Proc* _block = block;
  BasicObject* copy = nil_instance();
  if (truthy(([&]() -> BasicObject* { auto* _l = message->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (message->m_equal_q((new Array({this})), nullptr, nullptr)); }()))) {
    return this;
  }
  copy = this->m_class((new Array({})), nullptr, nullptr)->m_allocate((new Array({})), nullptr, nullptr);
  copy->m_send((new Array({intern("initialize_copy"), this})), nullptr, nullptr);
  copy->m_instance_variable_set((new Array({intern("@message"), message})), nullptr, nullptr);
  return copy;
  return nil_instance();
}

inline BasicObject* Exception::m_eq_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(this->m_equal_q((new Array({other})), nullptr, nullptr))) {
    return true_instance();
  }
  if (truthy(other->m_is_a_q((new Array({(&Exception_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return false_instance();
  }
  if (truthy(other->m_class((new Array({})), nullptr, nullptr)->m_eq_q((new Array({this->m_class((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return false_instance();
  }
  if (truthy(other->m_message((new Array({})), nullptr, nullptr)->m_eq_q((new Array({this->m_message((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return false_instance();
  }
  if (truthy(other->m_backtrace((new Array({})), nullptr, nullptr)->m_eq_q((new Array({this->m_backtrace((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return false_instance();
  }
  return true_instance();
  return nil_instance();
}

inline BasicObject* Exception::m_inspect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* msg = nil_instance();
  msg = this->m_to_s((new Array({})), nullptr, nullptr);
  return (truthy(([&]() -> BasicObject* { auto* _l = msg->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (msg->m_empty_q((new Array({})), nullptr, nullptr)); }())) ? ((([&]() -> BasicObject* { auto* _l = this->m_class((new Array({})), nullptr, nullptr)->m_name((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (this->m_class((new Array({})), nullptr, nullptr)->m_to_s((new Array({})), nullptr, nullptr)); }()))) : ((((new String("", 0))->m_plus((new Array({(new String("#<", 2))})), nullptr, nullptr)->m_plus((new Array({(([&]() -> BasicObject* { auto* _l = this->m_class((new Array({})), nullptr, nullptr)->m_name((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (this->m_class((new Array({})), nullptr, nullptr)->m_to_s((new Array({})), nullptr, nullptr)); }()))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(": ", 2))})), nullptr, nullptr)->m_plus((new Array({(msg)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(">", 1))})), nullptr, nullptr)))));
  return nil_instance();
}

inline BasicObject* LoadError::m_path(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_path;
  return nil_instance();
}

inline BasicObject* SyntaxError::m_path(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_path;
  return nil_instance();
}

inline BasicObject* SignalException::m_signo(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_signo;
  return nil_instance();
}

inline BasicObject* SignalException::m_signm(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_signm;
  return nil_instance();
}

inline BasicObject* SystemExit::m_status(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_status;
  return nil_instance();
}

inline BasicObject* SystemExit::m_success_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_status->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* FrozenError::m_receiver(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_receiver;
  return nil_instance();
}

inline BasicObject* NameError::m_name(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_name;
  return nil_instance();
}

inline BasicObject* NameError::m_receiver(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->m_instance_variable_defined_q((new Array({intern("@receiver")})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("no receiver is available", 24)))); }());
  }
  return this->iv_receiver;
  return nil_instance();
}

inline BasicObject* NoMethodError::m_args(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->iv_args; return truthy(_l) ? _l : ((new Array({}))); }());
  return nil_instance();
}

inline BasicObject* KeyError::m_receiver(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_receiver;
  return nil_instance();
}

inline BasicObject* KeyError::m_key(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_key;
  return nil_instance();
}

inline BasicObject* StopIteration::m_result(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_result;
  return nil_instance();
}

inline BasicObject* UncaughtThrowError::m_tag(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_tag;
  return nil_instance();
}

inline BasicObject* LocalJumpError::m_exit_value(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_exit_value;
  return nil_instance();
}

inline BasicObject* LocalJumpError::m_reason(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_reason;
  return nil_instance();
}

inline BasicObject* SystemCallError::m_errno(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_errno;
  return nil_instance();
}

inline Encoding::Encoding(BasicObject* name) {
  (this->iv_name = name);
}

inline BasicObject* Encoding::m_name(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_name;
  return nil_instance();
}

inline BasicObject* Encoding::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_name;
  return nil_instance();
}

inline BasicObject* Encoding::m_eq_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = other->m_is_a_q((new Array({(&Encoding_CLASS)})), nullptr, nullptr); return truthy(_l) ? (other->m_name((new Array({})), nullptr, nullptr)->m_eq_q((new Array({this->iv_name})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* Encoding::m_eql_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = other->m_is_a_q((new Array({(&Encoding_CLASS)})), nullptr, nullptr); return truthy(_l) ? (other->m_name((new Array({})), nullptr, nullptr)->m_eq_q((new Array({this->iv_name})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* Encoding::m_ascii_only_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_name->m_eq_q((new Array({(new String("US-ASCII", 8))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Encoding::m_replicate(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* new_name = array_at(args, 0);
  Proc* _block = block;
  return (new Encoding(static_cast<BasicObject*>(new_name)));
  return nil_instance();
}

inline BasicObject* Encoding::m_inspect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->iv_name->m_eq_q((new Array({(new String("ASCII-8BIT", 10))})), nullptr, nullptr)) ? (((new String("#<Encoding:BINARY (ASCII-8BIT)>", 31)))) : ((truthy(this->m_dummy_q((new Array({})), nullptr, nullptr)) ? ((((new String("", 0))->m_plus((new Array({(new String("#<Encoding:", 11))})), nullptr, nullptr)->m_plus((new Array({(this->iv_name)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" (dummy)>", 9))})), nullptr, nullptr)))) : ((((new String("", 0))->m_plus((new Array({(new String("#<Encoding:", 11))})), nullptr, nullptr)->m_plus((new Array({(this->iv_name)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(">", 1))})), nullptr, nullptr)))))));
  return nil_instance();
}

inline BasicObject* Encoding_InvalidByteSequenceError::m_source_encoding_name(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_source_encoding_name->m_to_s((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Encoding_InvalidByteSequenceError::m_destination_encoding_name(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_destination_encoding_name->m_to_s((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Encoding_InvalidByteSequenceError::m_source_encoding(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_source_encoding;
  return nil_instance();
}

inline BasicObject* Encoding_InvalidByteSequenceError::m_destination_encoding(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_destination_encoding;
  return nil_instance();
}

inline BasicObject* Encoding_InvalidByteSequenceError::m_error_bytes(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_error_bytes;
  return nil_instance();
}

inline BasicObject* Encoding_InvalidByteSequenceError::m_readagain_bytes(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_readagain_bytes;
  return nil_instance();
}

inline BasicObject* Encoding_InvalidByteSequenceError::m_incomplete_input_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_incomplete_input;
  return nil_instance();
}

inline BasicObject* Encoding_UndefinedConversionError::m_source_encoding_name(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_source_encoding_name->m_to_s((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Encoding_UndefinedConversionError::m_destination_encoding_name(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_destination_encoding_name->m_to_s((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Encoding_UndefinedConversionError::m_source_encoding(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_source_encoding;
  return nil_instance();
}

inline BasicObject* Encoding_UndefinedConversionError::m_destination_encoding(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_destination_encoding;
  return nil_instance();
}

inline BasicObject* Encoding_UndefinedConversionError::m_error_char(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_error_char;
  return nil_instance();
}

inline BasicObject* MatchData::m_length(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_size((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* MatchData::m_offset(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = array_at(args, 0);
  Proc* _block = block;
  return (new Array({this->m_begin((new Array({n})), nullptr, nullptr), this->m_end((new Array({n})), nullptr, nullptr)}));
  return nil_instance();
}

inline BasicObject* MatchData::m_byteoffset(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = array_at(args, 0);
  Proc* _block = block;
  return (new Array({this->m_bytebegin((new Array({n})), nullptr, nullptr), this->m_byteend((new Array({n})), nullptr, nullptr)}));
  return nil_instance();
}

inline BasicObject* MatchData::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_aref((new Array({(new Integer(0LL))})), nullptr, nullptr)->m_to_s((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* MatchData::m_hash(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Array({this->m_string((new Array({})), nullptr, nullptr), this->m_regexp((new Array({})), nullptr, nullptr), this->m_to_a((new Array({})), nullptr, nullptr)}))->m_hash((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* MatchData::m_deconstruct(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_captures((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* MatchData::m_match(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = array_at(args, 0);
  Proc* _block = block;
  BasicObject* v = nil_instance();
  v = this->m_aref((new Array({n})), nullptr, nullptr);
  return (truthy(v->m_nil_q((new Array({})), nullptr, nullptr)) ? ((nil_instance())) : ((v)));
  return nil_instance();
}

inline BasicObject* MatchData::m_eq_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&MatchData_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return false_instance();
  }
  return ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = this->m_string((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_string((new Array({})), nullptr, nullptr)})), nullptr, nullptr); return truthy(_l) ? (this->m_regexp((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_regexp((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (this->m_to_a((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_to_a((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* MatchData::m_eql_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&MatchData_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return false_instance();
  }
  return ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = this->m_string((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_string((new Array({})), nullptr, nullptr)})), nullptr, nullptr); return truthy(_l) ? (this->m_regexp((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_regexp((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (this->m_to_a((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_to_a((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* Regexp::m_dup(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Regexp(static_cast<BasicObject*>(this->m_source((new Array({})), nullptr, nullptr)), static_cast<BasicObject*>(this->m_options((new Array({})), nullptr, nullptr))));
  return nil_instance();
}

inline Rational::Rational(BasicObject* numerator, BasicObject* denominator) {
  BasicObject* g = nil_instance();
  if (truthy(denominator->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new ZeroDivisionError((new String("divided by 0", 12)))); }());
  }
  g = numerator->m_gcd((new Array({denominator})), nullptr, nullptr);
  (this->iv_numerator = numerator->m_div((new Array({g})), nullptr, nullptr));
  (this->iv_denominator = denominator->m_div((new Array({g})), nullptr, nullptr));
  if (truthy(this->iv_denominator->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
    (this->iv_numerator = this->iv_numerator->m_neg((new Array({})), nullptr, nullptr));
    (this->iv_denominator = this->iv_denominator->m_neg((new Array({})), nullptr, nullptr));
  }
  this->m_freeze((new Array({})), nullptr, nullptr);
}

inline BasicObject* Rational::m_numerator(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_numerator;
  return nil_instance();
}

inline BasicObject* Rational::m_denominator(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_denominator;
  return nil_instance();
}

inline BasicObject* Rational::m_to_i(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->iv_numerator->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? (((this->iv_numerator->m_neg((new Array({})), nullptr, nullptr)->m_div((new Array({this->iv_denominator})), nullptr, nullptr))->m_neg((new Array({})), nullptr, nullptr))) : ((this->iv_numerator->m_div((new Array({this->iv_denominator})), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* Rational::m_to_r(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* Rational::m_to_c(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_Complex((new Array({this, (new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Rational::m_dup(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* Rational::m_divmod(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return (new Array({this->m_div((new Array({other})), nullptr, nullptr), this->m_minus((new Array({other->m_mul((new Array({this->m_div((new Array({other})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr)}));
  return nil_instance();
}

inline BasicObject* Rational::m_abs(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->iv_numerator->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((this->m_Rational((new Array({this->iv_numerator->m_neg((new Array({})), nullptr, nullptr), this->iv_denominator})), nullptr, nullptr))) : ((this)));
  return nil_instance();
}

inline BasicObject* Rational::m_negative_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_numerator->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Rational::m_positive_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_numerator->m_gt((new Array({(new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Rational::m_zero_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_numerator->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Rational::m_nonzero_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->iv_numerator->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((nil_instance())) : ((this)));
  return nil_instance();
}

inline BasicObject* Rational::m_hash(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Array({this->iv_numerator, this->iv_denominator}))->m_hash((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Rational::m_eql_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = other->m_is_a_q((new Array({(&Rational_CLASS)})), nullptr, nullptr); return truthy(_l) ? (this->iv_numerator->m_eq_q((new Array({other->m_numerator((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (this->iv_denominator->m_eq_q((new Array({other->m_denominator((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* Rational::m_quo(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return this->m_div((new Array({other})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Rational::m_inspect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ((new String("", 0))->m_plus((new Array({(new String("(", 1))})), nullptr, nullptr)->m_plus((new Array({(this->iv_numerator)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String("/", 1))})), nullptr, nullptr)->m_plus((new Array({(this->iv_denominator)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(")", 1))})), nullptr, nullptr));
  return nil_instance();
}

inline BasicObject* Rational::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ((new String("", 0))->m_plus((new Array({(this->iv_numerator)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String("/", 1))})), nullptr, nullptr)->m_plus((new Array({(this->iv_denominator)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr));
  return nil_instance();
}

inline BasicObject* Rational::m_plus(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _subj = other; if (truthy((&Rational_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (this->m_Rational((new Array({this->iv_numerator->m_mul((new Array({other->m_denominator((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({other->m_numerator((new Array({})), nullptr, nullptr)->m_mul((new Array({this->iv_denominator})), nullptr, nullptr)})), nullptr, nullptr), this->iv_denominator->m_mul((new Array({other->m_denominator((new Array({})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr)); if (truthy((&Integer_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (this->m_Rational((new Array({this->iv_numerator->m_plus((new Array({other->m_mul((new Array({this->iv_denominator})), nullptr, nullptr)})), nullptr, nullptr), this->iv_denominator})), nullptr, nullptr)); if (truthy((&Float_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (this->m_to_f((new Array({})), nullptr, nullptr)->m_plus((new Array({other})), nullptr, nullptr)); return (this->m___coerce_op__((new Array({other, intern("+")})), nullptr, nullptr)); }());
  return nil_instance();
}

inline BasicObject* Rational::m_minus(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _subj = other; if (truthy((&Rational_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (this->m_Rational((new Array({this->iv_numerator->m_mul((new Array({other->m_denominator((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_minus((new Array({other->m_numerator((new Array({})), nullptr, nullptr)->m_mul((new Array({this->iv_denominator})), nullptr, nullptr)})), nullptr, nullptr), this->iv_denominator->m_mul((new Array({other->m_denominator((new Array({})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr)); if (truthy((&Integer_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (this->m_Rational((new Array({this->iv_numerator->m_minus((new Array({other->m_mul((new Array({this->iv_denominator})), nullptr, nullptr)})), nullptr, nullptr), this->iv_denominator})), nullptr, nullptr)); if (truthy((&Float_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (this->m_to_f((new Array({})), nullptr, nullptr)->m_minus((new Array({other})), nullptr, nullptr)); return (this->m___coerce_op__((new Array({other, intern("-")})), nullptr, nullptr)); }());
  return nil_instance();
}

inline BasicObject* Rational::m_mul(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _subj = other; if (truthy((&Rational_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (this->m_Rational((new Array({this->iv_numerator->m_mul((new Array({other->m_numerator((new Array({})), nullptr, nullptr)})), nullptr, nullptr), this->iv_denominator->m_mul((new Array({other->m_denominator((new Array({})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr)); if (truthy((&Integer_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (this->m_Rational((new Array({this->iv_numerator->m_mul((new Array({other})), nullptr, nullptr), this->iv_denominator})), nullptr, nullptr)); if (truthy((&Float_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (this->m_to_f((new Array({})), nullptr, nullptr)->m_mul((new Array({other})), nullptr, nullptr)); return (this->m___coerce_op__((new Array({other, intern("*")})), nullptr, nullptr)); }());
  return nil_instance();
}

inline BasicObject* Rational::m_div(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = other->m_respond_to_q((new Array({intern("zero?")})), nullptr, nullptr); return truthy(_l) ? (other->m_zero_q((new Array({})), nullptr, nullptr)) : _l; }()))) {
    ([&]() -> BasicObject* { throw (new ZeroDivisionError((new String("divided by 0", 12)))); }());
  }
  return (this->m_div((new Array({other})), nullptr, nullptr))->m_floor((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Rational::m_pow(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _subj = other; if (truthy((&Integer_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((truthy(other->m_ge((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((this->m_Rational((new Array({this->iv_numerator->m_pow((new Array({other})), nullptr, nullptr), this->iv_denominator->m_pow((new Array({other})), nullptr, nullptr)})), nullptr, nullptr))) : (((truthy(this->iv_numerator->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((([&]() -> BasicObject* { throw (new ZeroDivisionError((new String("divided by 0", 12)))); }()))) : (nil_instance())), this->m_Rational((new Array({this->iv_denominator->m_pow((new Array({(other->m_neg((new Array({})), nullptr, nullptr))})), nullptr, nullptr), this->iv_numerator->m_pow((new Array({(other->m_neg((new Array({})), nullptr, nullptr))})), nullptr, nullptr)})), nullptr, nullptr))))); if (truthy((&Float_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (this->m_to_f((new Array({})), nullptr, nullptr)->m_pow((new Array({other})), nullptr, nullptr)); if (truthy((&Rational_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((truthy(([&]() -> BasicObject* { auto* _l = this->iv_numerator->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr); return truthy(_l) ? (other->m_negative_q((new Array({})), nullptr, nullptr)) : _l; }())) ? ((([&]() -> BasicObject* { throw (new ZeroDivisionError((new String("divided by 0", 12)))); }()))) : (nil_instance())), (truthy(other->m_denominator((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(1LL))})), nullptr, nullptr)) ? ((this->m_pow((new Array({other->m_numerator((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) : ((this->m_to_f((new Array({})), nullptr, nullptr)->m_pow((new Array({other->m_to_f((new Array({})), nullptr, nullptr)})), nullptr, nullptr))))); return (this->m___coerce_op__((new Array({other, intern("**")})), nullptr, nullptr)); }());
  return nil_instance();
}

inline BasicObject* Rational::m_eq_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _subj = other; if (truthy((&Rational_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (([&]() -> BasicObject* { auto* _l = this->iv_numerator->m_eq_q((new Array({other->m_numerator((new Array({})), nullptr, nullptr)})), nullptr, nullptr); return truthy(_l) ? (this->iv_denominator->m_eq_q((new Array({other->m_denominator((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }())); if (truthy((&Integer_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (([&]() -> BasicObject* { auto* _l = this->iv_denominator->m_eq_q((new Array({(new Integer(1LL))})), nullptr, nullptr); return truthy(_l) ? (this->iv_numerator->m_eq_q((new Array({other})), nullptr, nullptr)) : _l; }())); if (truthy((&Float_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (this->m_to_f((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other})), nullptr, nullptr)); return (([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return other->m_eq_q((new Array({this})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return false_instance();  return nil_instance(); }(); } throw; } }())); }());
  return nil_instance();
}

inline BasicObject* Rational::m_coerce(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _subj = other; if (truthy((&Float_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new Array({other, this->m_to_f((new Array({})), nullptr, nullptr)}))); if (truthy((&Integer_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new Array({this->m_Rational((new Array({other})), nullptr, nullptr), this}))); if (truthy((&Rational_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new Array({other, this}))); return (([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("can't coerce ", 13))})), nullptr, nullptr)->m_plus((new Array({(other->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into Rational", 14))})), nullptr, nullptr)))); }())); }());
  return nil_instance();
}

inline BasicObject* Rational::m_to_f(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* n_bits = nil_instance();
  BasicObject* d_bits = nil_instance();
  BasicObject* max_bits = nil_instance();
  BasicObject* shift = nil_instance();
  n_bits = this->iv_numerator->m_abs((new Array({})), nullptr, nullptr)->m_bit_length((new Array({})), nullptr, nullptr);
  d_bits = this->iv_denominator->m_bit_length((new Array({})), nullptr, nullptr);
  max_bits = (truthy(n_bits->m_gt((new Array({d_bits})), nullptr, nullptr)) ? ((n_bits)) : ((d_bits)));
  return (truthy(max_bits->m_gt((new Array({(new Integer(1022LL))})), nullptr, nullptr)) ? (((shift = max_bits->m_minus((new Array({(new Integer(1022LL))})), nullptr, nullptr)), (this->iv_numerator->m_rshift((new Array({shift})), nullptr, nullptr))->m_to_f((new Array({})), nullptr, nullptr)->m_div((new Array({(this->iv_denominator->m_rshift((new Array({shift})), nullptr, nullptr))->m_to_f((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) : ((this->iv_numerator->m_to_f((new Array({})), nullptr, nullptr)->m_div((new Array({this->iv_denominator->m_to_f((new Array({})), nullptr, nullptr)})), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* Rational::m_floor(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = (args->data.size() > 0) ? args->data[0] : ((new Integer(0LL)));
  Proc* _block = block;
  BasicObject* f = nil_instance();
  n = this->m___coerce_to_int__((new Array({n})), nullptr, nullptr);
  return (truthy(n->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((this->iv_numerator->m_div((new Array({this->iv_denominator})), nullptr, nullptr))) : ((truthy(n->m_gt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? (((f = (new Integer(10LL))->m_pow((new Array({n})), nullptr, nullptr)), this->m_Rational((new Array({this->iv_numerator->m_mul((new Array({f})), nullptr, nullptr)->m_div((new Array({this->iv_denominator})), nullptr, nullptr), f})), nullptr, nullptr))) : (((f = (new Integer(10LL))->m_pow((new Array({(n->m_neg((new Array({})), nullptr, nullptr))})), nullptr, nullptr)), (this->iv_numerator->m_div((new Array({(this->iv_denominator->m_mul((new Array({f})), nullptr, nullptr))})), nullptr, nullptr))->m_mul((new Array({f})), nullptr, nullptr))))));
  return nil_instance();
}

inline BasicObject* Rational::m_ceil(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = (args->data.size() > 0) ? args->data[0] : ((new Integer(0LL)));
  Proc* _block = block;
  BasicObject* f = nil_instance();
  n = this->m___coerce_to_int__((new Array({n})), nullptr, nullptr);
  return (truthy(n->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? (((this->iv_numerator->m_neg((new Array({})), nullptr, nullptr)->m_div((new Array({this->iv_denominator})), nullptr, nullptr))->m_neg((new Array({})), nullptr, nullptr))) : ((truthy(n->m_gt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? (((f = (new Integer(10LL))->m_pow((new Array({n})), nullptr, nullptr)), this->m_Rational((new Array({(this->iv_numerator->m_neg((new Array({})), nullptr, nullptr)->m_mul((new Array({f})), nullptr, nullptr)->m_div((new Array({this->iv_denominator})), nullptr, nullptr))->m_neg((new Array({})), nullptr, nullptr), f})), nullptr, nullptr))) : (((f = (new Integer(10LL))->m_pow((new Array({(n->m_neg((new Array({})), nullptr, nullptr))})), nullptr, nullptr)), ((this->iv_numerator->m_neg((new Array({})), nullptr, nullptr)->m_div((new Array({(this->iv_denominator->m_mul((new Array({f})), nullptr, nullptr))})), nullptr, nullptr))->m_neg((new Array({})), nullptr, nullptr))->m_mul((new Array({f})), nullptr, nullptr))))));
  return nil_instance();
}

inline BasicObject* Rational::m_truncate(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = (args->data.size() > 0) ? args->data[0] : ((new Integer(0LL)));
  Proc* _block = block;
  n = this->m___coerce_to_int__((new Array({n})), nullptr, nullptr);
  return (truthy(this->iv_numerator->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((this->m_ceil((new Array({n})), nullptr, nullptr))) : ((this->m_floor((new Array({n})), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* Rational::m_mod(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = other->m_respond_to_q((new Array({intern("zero?")})), nullptr, nullptr); return truthy(_l) ? (other->m_zero_q((new Array({})), nullptr, nullptr)) : _l; }()))) {
    ([&]() -> BasicObject* { throw (new ZeroDivisionError((new String("divided by 0", 12)))); }());
  }
  return this->m_minus((new Array({other->m_mul((new Array({(this->m_div((new Array({other})), nullptr, nullptr))->m_floor((new Array({})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Rational::m_modulo(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = other->m_respond_to_q((new Array({intern("zero?")})), nullptr, nullptr); return truthy(_l) ? (other->m_zero_q((new Array({})), nullptr, nullptr)) : _l; }()))) {
    ([&]() -> BasicObject* { throw (new ZeroDivisionError((new String("divided by 0", 12)))); }());
  }
  return this->m_minus((new Array({other->m_mul((new Array({(this->m_div((new Array({other})), nullptr, nullptr))->m_floor((new Array({})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Rational::m_remainder(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  BasicObject* r = nil_instance();
  r = this->m_mod((new Array({other})), nullptr, nullptr);
  if (truthy(r->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
    return r;
  }
  return (truthy(this->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? (((truthy(other->m_gt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((r->m_minus((new Array({other})), nullptr, nullptr))) : ((r))))) : ((truthy(this->m_gt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? (((truthy(other->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((r->m_minus((new Array({other})), nullptr, nullptr))) : ((r))))) : ((r)))));
  return nil_instance();
}

inline BasicObject* Rational::m_rationalize(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* eps = (args->data.size() > 0) ? args->data[0] : (nil_instance());
  Proc* _block = block;
  BasicObject* lo = nil_instance();
  BasicObject* hi = nil_instance();
  if (truthy(eps->m_nil_q((new Array({})), nullptr, nullptr))) {
    return this;
  }
  eps = (truthy(eps->m_is_a_q((new Array({(&Rational_CLASS)})), nullptr, nullptr)) ? ((eps->m_abs((new Array({})), nullptr, nullptr))) : ((this->m_Rational((new Array({eps->m_abs((new Array({})), nullptr, nullptr)})), nullptr, nullptr))));
  lo = this->m_minus((new Array({eps})), nullptr, nullptr);
  hi = this->m_plus((new Array({eps})), nullptr, nullptr);
  return this->m___simplest_rational__((new Array({lo, hi})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Rational::m_marshal_dump(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Array({this->iv_numerator, this->iv_denominator}));
  return nil_instance();
}

inline BasicObject* Rational::m___simplest_rational__(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* lo = array_at(args, 0);
  BasicObject* hi = array_at(args, 1);
  Proc* _block = block;
  BasicObject* lo_ceil = nil_instance();
  BasicObject* k = nil_instance();
  BasicObject* lo2 = nil_instance();
  BasicObject* hi2 = nil_instance();
  BasicObject* y = nil_instance();
  if (truthy(([&]() -> BasicObject* { auto* _l = lo->m_le((new Array({(new Integer(0LL))})), nullptr, nullptr); return truthy(_l) ? (hi->m_ge((new Array({(new Integer(0LL))})), nullptr, nullptr)) : _l; }()))) {
    return this->m_Rational((new Array({(new Integer(0LL)), (new Integer(1LL))})), nullptr, nullptr);
  }
  if (truthy(hi->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
    return this->m___simplest_rational__((new Array({hi->m_neg((new Array({})), nullptr, nullptr), lo->m_neg((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_neg((new Array({})), nullptr, nullptr);
  }
  lo_ceil = lo->m_ceil((new Array({})), nullptr, nullptr);
  if (truthy(lo_ceil->m_le((new Array({hi})), nullptr, nullptr))) {
    return this->m_Rational((new Array({lo_ceil, (new Integer(1LL))})), nullptr, nullptr);
  }
  k = lo->m_floor((new Array({})), nullptr, nullptr);
  lo2 = this->m_Rational((new Array({(new Integer(1LL)), (new Integer(1LL))})), nullptr, nullptr)->m_div((new Array({(hi->m_minus((new Array({k})), nullptr, nullptr))})), nullptr, nullptr);
  hi2 = this->m_Rational((new Array({(new Integer(1LL)), (new Integer(1LL))})), nullptr, nullptr)->m_div((new Array({(lo->m_minus((new Array({k})), nullptr, nullptr))})), nullptr, nullptr);
  y = this->m___simplest_rational__((new Array({lo2, hi2})), nullptr, nullptr);
  return this->m_Rational((new Array({k->m_mul((new Array({y->m_numerator((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({y->m_denominator((new Array({})), nullptr, nullptr)})), nullptr, nullptr), y->m_numerator((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Rational::m_marshal_load(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* ary = array_at(args, 0);
  Proc* _block = block;
  BasicObject* g = nil_instance();
  g = ary->m_aref((new Array({(new Integer(0LL))})), nullptr, nullptr)->m_gcd((new Array({ary->m_aref((new Array({(new Integer(1LL))})), nullptr, nullptr)})), nullptr, nullptr);
  (this->iv_numerator = ary->m_aref((new Array({(new Integer(0LL))})), nullptr, nullptr)->m_div((new Array({g})), nullptr, nullptr));
  return (this->iv_denominator = ary->m_aref((new Array({(new Integer(1LL))})), nullptr, nullptr)->m_div((new Array({g})), nullptr, nullptr));
  return nil_instance();
}

inline Complex::Complex(BasicObject* real, BasicObject* imaginary) {
  (this->iv_real = real);
  (this->iv_imaginary = imaginary);
  this->m_freeze((new Array({})), nullptr, nullptr);
}

inline BasicObject* Complex::m_real(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_real;
  return nil_instance();
}

inline BasicObject* Complex::m_imaginary(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_imaginary;
  return nil_instance();
}

inline BasicObject* Complex::m_imag(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_imaginary;
  return nil_instance();
}

inline BasicObject* Complex::m_real_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return false_instance();
  return nil_instance();
}

inline BasicObject* Complex::m_abs2(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_real->m_mul((new Array({this->iv_real})), nullptr, nullptr)->m_plus((new Array({this->iv_imaginary->m_mul((new Array({this->iv_imaginary})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Complex::m_rect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Array({this->iv_real, this->iv_imaginary}));
  return nil_instance();
}

inline BasicObject* Complex::m_rectangular(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Array({this->iv_real, this->iv_imaginary}));
  return nil_instance();
}

inline BasicObject* Complex::m_conj(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_Complex((new Array({this->iv_real, this->iv_imaginary->m_neg((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Complex::m_conjugate(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_Complex((new Array({this->iv_real, this->iv_imaginary->m_neg((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Complex::m_to_c(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* Complex::m_dup(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* Complex::m_integer_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return false_instance();
  return nil_instance();
}

inline BasicObject* Complex::m_zero_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->iv_real->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr); return truthy(_l) ? (this->iv_imaginary->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* Complex::m_nonzero_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->m_zero_q((new Array({})), nullptr, nullptr)) ? ((nil_instance())) : ((this)));
  return nil_instance();
}

inline BasicObject* Complex::m_quo(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return this->m_div((new Array({other})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Complex::m_hash(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Array({this->iv_real, this->iv_imaginary}))->m_hash((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Complex::m_neg(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_Complex((new Array({this->iv_real->m_neg((new Array({})), nullptr, nullptr), this->iv_imaginary->m_neg((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Complex::m_polar(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Array({this->m_abs((new Array({})), nullptr, nullptr), this->m_angle((new Array({})), nullptr, nullptr)}));
  return nil_instance();
}

inline BasicObject* Complex::m_plus(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return this->m___complex_coerce_op__((new Array({other, intern("+")})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* v = arg; return (truthy(v->m_is_a_q((new Array({(&Complex_CLASS)})), nullptr, nullptr)) ? ((this->m_Complex((new Array({this->iv_real->m_plus((new Array({v->m_real((new Array({})), nullptr, nullptr)})), nullptr, nullptr), this->iv_imaginary->m_plus((new Array({v->m_imaginary((new Array({})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr))) : ((this->m_Complex((new Array({this->iv_real->m_plus((new Array({v})), nullptr, nullptr), this->iv_imaginary})), nullptr, nullptr)))); })));
  return nil_instance();
}

inline BasicObject* Complex::m_minus(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return this->m___complex_coerce_op__((new Array({other, intern("-")})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* v = arg; return (truthy(v->m_is_a_q((new Array({(&Complex_CLASS)})), nullptr, nullptr)) ? ((this->m_Complex((new Array({this->iv_real->m_minus((new Array({v->m_real((new Array({})), nullptr, nullptr)})), nullptr, nullptr), this->iv_imaginary->m_minus((new Array({v->m_imaginary((new Array({})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr))) : ((this->m_Complex((new Array({this->iv_real->m_minus((new Array({v})), nullptr, nullptr), this->iv_imaginary})), nullptr, nullptr)))); })));
  return nil_instance();
}

inline BasicObject* Complex::m_mul(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return this->m___complex_coerce_op__((new Array({other, intern("*")})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* v = arg; return (truthy(v->m_is_a_q((new Array({(&Complex_CLASS)})), nullptr, nullptr)) ? ((this->m_Complex((new Array({this->iv_real->m_mul((new Array({v->m_real((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_minus((new Array({this->iv_imaginary->m_mul((new Array({v->m_imaginary((new Array({})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr), this->iv_real->m_mul((new Array({v->m_imaginary((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({this->iv_imaginary->m_mul((new Array({v->m_real((new Array({})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr))) : ((this->m_Complex((new Array({this->iv_real->m_mul((new Array({v})), nullptr, nullptr), this->iv_imaginary->m_mul((new Array({v})), nullptr, nullptr)})), nullptr, nullptr)))); })));
  return nil_instance();
}

inline BasicObject* Complex::m_div(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  BasicObject* denom = nil_instance();
  BasicObject* real_q = nil_instance();
  return (truthy(other->m_is_a_q((new Array({(&Complex_CLASS)})), nullptr, nullptr)) ? (((denom = other->m_real((new Array({})), nullptr, nullptr)->m_mul((new Array({other->m_real((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({other->m_imaginary((new Array({})), nullptr, nullptr)->m_mul((new Array({other->m_imaginary((new Array({})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr)), this->m_Complex((new Array({(this->iv_real->m_mul((new Array({other->m_real((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({this->iv_imaginary->m_mul((new Array({other->m_imaginary((new Array({})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr))->m_quo((new Array({denom})), nullptr, nullptr), (this->iv_imaginary->m_mul((new Array({other->m_real((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_minus((new Array({this->iv_real->m_mul((new Array({other->m_imaginary((new Array({})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr))->m_quo((new Array({denom})), nullptr, nullptr)})), nullptr, nullptr))) : (((real_q = (truthy(other->m_respond_to_q((new Array({intern("real?")})), nullptr, nullptr)) ? ((other->m_real_q((new Array({})), nullptr, nullptr))) : ((nil_instance())))), (truthy(real_q->m_eq_q((new Array({false_instance()})), nullptr, nullptr)) ? ((this->m___coerce_binop__((new Array({other, intern("quo")})), nullptr, nullptr))) : ((truthy(([&]() -> BasicObject* { auto* _l = other->m_is_a_q((new Array({(&Numeric_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (real_q); }())) ? ((this->m_Complex((new Array({this->iv_real->m_quo((new Array({other})), nullptr, nullptr), this->iv_imaginary->m_quo((new Array({other})), nullptr, nullptr)})), nullptr, nullptr))) : ((this->m___coerce_binop__((new Array({other, intern("/")})), nullptr, nullptr)))))))));
  return nil_instance();
}

inline BasicObject* Complex::m_eq_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _subj = other; if (truthy((&Complex_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (([&]() -> BasicObject* { auto* _l = this->iv_real->m_eq_q((new Array({other->m_real((new Array({})), nullptr, nullptr)})), nullptr, nullptr); return truthy(_l) ? (this->iv_imaginary->m_eq_q((new Array({other->m_imaginary((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }())); if (truthy((&Numeric_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (([&]() -> BasicObject* { auto* _l = this->iv_imaginary->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr); return truthy(_l) ? (this->iv_real->m_eq_q((new Array({other})), nullptr, nullptr)) : _l; }())); return (([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return other->m_eq_q((new Array({this})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return false_instance();  return nil_instance(); }(); } throw; } }())); }());
  return nil_instance();
}

inline BasicObject* Complex::m_spaceship(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = this->iv_imaginary->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr); return truthy(_l) ? (other->m_respond_to_q((new Array({intern("imaginary")})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (other->m_imaginary((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr)) : _l; }())) ? ((this->iv_real->m_spaceship((new Array({other->m_real((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) : ((truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = this->iv_imaginary->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr); return truthy(_l) ? (other->m_is_a_q((new Array({(&Numeric_CLASS)})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (other->m_is_a_q((new Array({(&Complex_CLASS)})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr)) : _l; }())) ? ((this->iv_real->m_spaceship((new Array({other})), nullptr, nullptr))) : ((nil_instance())))));
  return nil_instance();
}

inline BasicObject* Complex::m_numerator(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* cd = nil_instance();
  cd = this->m_denominator((new Array({})), nullptr, nullptr);
  return this->m_Complex((new Array({(truthy(this->iv_real->m_is_a_q((new Array({(&Rational_CLASS)})), nullptr, nullptr)) ? ((this->iv_real->m_numerator((new Array({})), nullptr, nullptr)->m_mul((new Array({(cd->m_div((new Array({this->iv_real->m_denominator((new Array({})), nullptr, nullptr)})), nullptr, nullptr))})), nullptr, nullptr))) : ((this->iv_real->m_mul((new Array({cd})), nullptr, nullptr)))), (truthy(this->iv_imaginary->m_is_a_q((new Array({(&Rational_CLASS)})), nullptr, nullptr)) ? ((this->iv_imaginary->m_numerator((new Array({})), nullptr, nullptr)->m_mul((new Array({(cd->m_div((new Array({this->iv_imaginary->m_denominator((new Array({})), nullptr, nullptr)})), nullptr, nullptr))})), nullptr, nullptr))) : ((this->iv_imaginary->m_mul((new Array({cd})), nullptr, nullptr))))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Complex::m_denominator(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* rd = nil_instance();
  BasicObject* id = nil_instance();
  rd = (truthy(this->iv_real->m_is_a_q((new Array({(&Rational_CLASS)})), nullptr, nullptr)) ? ((this->iv_real->m_denominator((new Array({})), nullptr, nullptr))) : (((new Integer(1LL)))));
  id = (truthy(this->iv_imaginary->m_is_a_q((new Array({(&Rational_CLASS)})), nullptr, nullptr)) ? ((this->iv_imaginary->m_denominator((new Array({})), nullptr, nullptr))) : (((new Integer(1LL)))));
  return rd->m_lcm((new Array({id})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Complex::m_rationalize(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* eps = (args->data.size() > 0) ? args->data[0] : (nil_instance());
  Proc* _block = block;
  this->m___ensure_real_strict__((new Array({(new String("Rational", 8))})), nullptr, nullptr);
  return this->iv_real->m_rationalize((new Array({eps})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Complex::m_to_f(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  this->m___ensure_real_strict__((new Array({(new String("Float", 5))})), nullptr, nullptr);
  return this->iv_real->m_to_f((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Complex::m_to_i(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  this->m___ensure_real_strict__((new Array({(new String("Integer", 7))})), nullptr, nullptr);
  return this->iv_real->m_to_i((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Complex::m_to_r(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv_imaginary->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new RangeError(((new String("", 0))->m_plus((new Array({(new String("can't convert ", 14))})), nullptr, nullptr)->m_plus((new Array({(this->m_to_s((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into Rational", 14))})), nullptr, nullptr)))); }());
  }
  return this->iv_real->m_to_r((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Complex::m_finite_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = this->iv_real->m_respond_to_q((new Array({intern("finite?")})), nullptr, nullptr); return truthy(_l) ? (this->iv_real->m_finite_q((new Array({})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (this->iv_imaginary->m_respond_to_q((new Array({intern("finite?")})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (this->iv_imaginary->m_finite_q((new Array({})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* Complex::m_infinite_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* r_inf = nil_instance();
  BasicObject* i_inf = nil_instance();
  r_inf = (truthy(this->iv_real->m_respond_to_q((new Array({intern("infinite?")})), nullptr, nullptr)) ? ((this->iv_real->m_infinite_q((new Array({})), nullptr, nullptr))) : ((nil_instance())));
  i_inf = (truthy(this->iv_imaginary->m_respond_to_q((new Array({intern("infinite?")})), nullptr, nullptr)) ? ((this->iv_imaginary->m_infinite_q((new Array({})), nullptr, nullptr))) : ((nil_instance())));
  return (truthy(([&]() -> BasicObject* { auto* _l = (([&]() -> BasicObject* { auto* _l = r_inf; return truthy(_l) ? (r_inf->m_ne_q((new Array({(new Integer(0LL))})), nullptr, nullptr)) : _l; }())); return truthy(_l) ? _l : ((([&]() -> BasicObject* { auto* _l = i_inf; return truthy(_l) ? (i_inf->m_ne_q((new Array({(new Integer(0LL))})), nullptr, nullptr)) : _l; }()))); }())) ? (((new Integer(1LL)))) : ((nil_instance())));
  return nil_instance();
}

inline BasicObject* Complex::m_coerce(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  BasicObject* real_q = nil_instance();
  return (truthy(other->m_is_a_q((new Array({(&Complex_CLASS)})), nullptr, nullptr)) ? (((new Array({other, this})))) : ((truthy(other->m_is_a_q((new Array({(&Numeric_CLASS)})), nullptr, nullptr)) ? (((real_q = (truthy(other->m_respond_to_q((new Array({intern("real?")})), nullptr, nullptr)) ? ((other->m_real_q((new Array({})), nullptr, nullptr))) : ((true_instance())))), (truthy(real_q->m_eq_q((new Array({false_instance()})), nullptr, nullptr)) ? ((([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(other->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" can't be coerced into Complex", 30))})), nullptr, nullptr)))); }()))) : (nil_instance())), (new Array({this->m_Complex((new Array({other, (new Integer(0LL))})), nullptr, nullptr), this})))) : ((([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(other->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" can't be coerced into Complex", 30))})), nullptr, nullptr)))); }()))))));
  return nil_instance();
}

inline BasicObject* Complex::m_fdiv(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&Numeric_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(other->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" can't be coerced into Complex", 30))})), nullptr, nullptr)))); }());
  }
  return this->m_Complex((new Array({this->iv_real->m_fdiv((new Array({other})), nullptr, nullptr), this->iv_imaginary->m_fdiv((new Array({other})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Complex::m_eql_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_instance_of_q((new Array({(&Complex_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return false_instance();
  }
  return ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = this->iv_real->m_class((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_real((new Array({})), nullptr, nullptr)->m_class((new Array({})), nullptr, nullptr)})), nullptr, nullptr); return truthy(_l) ? (this->iv_imaginary->m_class((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_imaginary((new Array({})), nullptr, nullptr)->m_class((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (this->m_eq_q((new Array({other})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* Complex::m_marshal_dump(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Array({this->iv_real, this->iv_imaginary}));
  return nil_instance();
}

inline BasicObject* Complex::m___ensure_real_strict__(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* type = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { throw (new RangeError(((new String("", 0))->m_plus((new Array({(new String("can't convert ", 14))})), nullptr, nullptr)->m_plus((new Array({(this->m_inspect((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into ", 6))})), nullptr, nullptr)->m_plus((new Array({(type)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))); }());
  return nil_instance();
}

inline BasicObject* Complex::m___complex_coerce_op__(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  BasicObject* op = array_at(args, 1);
  Proc* _block = block;
  BasicObject* real_q = nil_instance();
  return (truthy(other->m_is_a_q((new Array({(&Complex_CLASS)})), nullptr, nullptr)) ? ((_block->m_call((new Array({other})), nullptr, nullptr))) : (((real_q = (truthy(other->m_respond_to_q((new Array({intern("real?")})), nullptr, nullptr)) ? ((other->m_real_q((new Array({})), nullptr, nullptr))) : ((nil_instance())))), (truthy(real_q->m_eq_q((new Array({false_instance()})), nullptr, nullptr)) ? ((this->m___coerce_binop__((new Array({other, op})), nullptr, nullptr))) : ((truthy(([&]() -> BasicObject* { auto* _l = other->m_is_a_q((new Array({(&Numeric_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (real_q); }())) ? ((_block->m_call((new Array({other})), nullptr, nullptr))) : ((this->m___coerce_binop__((new Array({other, op})), nullptr, nullptr)))))))));
  return nil_instance();
}

inline BasicObject* IO::m_puts(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(args->m_empty_q((new Array({})), nullptr, nullptr))) {
    this->m_write((new Array({(new String("\n", 1))})), nullptr, nullptr);
  } else {
    args->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { return (truthy(arg->m_nil_q((new Array({})), nullptr, nullptr)) ? ((this->m_write((new Array({(new String("\n", 1))})), nullptr, nullptr))) : ((truthy(arg->m_is_a_q((new Array({(&Array_CLASS)})), nullptr, nullptr)) ? ((this->m___puts_array__((new Array({arg})), nullptr, nullptr))) : ((([&]() -> BasicObject* { try { return [&]() -> BasicObject* { BasicObject* ary = arg->m_to_ary((new Array({})), nullptr, nullptr); return (truthy(ary->m_nil_q((new Array({})), nullptr, nullptr)) ? ((this->m___puts_scalar__((new Array({arg})), nullptr, nullptr))) : ((truthy(ary->m_is_a_q((new Array({(&Array_CLASS)})), nullptr, nullptr)) ? ((this->m___puts_array__((new Array({ary})), nullptr, nullptr))) : ((this->m___puts_scalar__((new Array({arg})), nullptr, nullptr))))));  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<NoMethodError*>(e_) != nullptr) { return [&]() -> BasicObject* { return this->m___puts_scalar__((new Array({arg})), nullptr, nullptr);  return nil_instance(); }(); } throw; } }())))))); })));
  }
  return nil_instance();
  return nil_instance();
}

inline BasicObject* IO::m___puts_scalar__(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* arg = array_at(args, 0);
  Proc* _block = block;
  BasicObject* str = nil_instance();
  str = arg->m_to_s((new Array({})), nullptr, nullptr);
  if (truthy(str->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    str = ((new String("", 0))->m_plus((new Array({(new String("#<", 2))})), nullptr, nullptr)->m_plus((new Array({(arg->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(":0x", 3))})), nullptr, nullptr)->m_plus((new Array({(arg->m___id__((new Array({})), nullptr, nullptr)->m_to_s((new Array({(new Integer(16LL))})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(">", 1))})), nullptr, nullptr));
  }
  this->m_write((new Array({str})), nullptr, nullptr);
  return (truthy(str->m_end_with_q((new Array({(new String("\n", 1))})), nullptr, nullptr)) ? (nil_instance()) : ((this->m_write((new Array({(new String("\n", 1))})), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* IO::m_lshift(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* str = array_at(args, 0);
  Proc* _block = block;
  this->m_write((new Array({(truthy(str->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)) ? ((str)) : ((str->m_to_s((new Array({})), nullptr, nullptr))))})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* IO::m_eof(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_eof_q((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* IO::m_tty_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_isatty((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* IO::m_tell(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_pos((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* IO::m_to_path(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_path((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* IO::m_to_io(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* IO::m_size(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_stat((new Array({})), nullptr, nullptr)->m_size((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* IO::m_printf(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  this->m_write((new Array({this->m_sprintf(static_cast<Array*>(args), nullptr, nullptr)})), nullptr, nullptr);
  nil_instance();
  return nil_instance();
}

inline BasicObject* IO::m_each_codepoint(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("each_codepoint")})), nullptr, nullptr);
  }
  return this->m_each_char((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* c = arg; return block->m_call((new Array({c->m_ord((new Array({})), nullptr, nullptr)})), nullptr, nullptr); })));
  return nil_instance();
}

inline BasicObject* IO::m_bytes(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("each_byte")})), nullptr, nullptr);
  }
  return this->m_each_byte((new Array({})), nullptr, static_cast<Proc*>(block));
  return nil_instance();
}

inline BasicObject* IO::m_chars(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("each_char")})), nullptr, nullptr);
  }
  return this->m_each_char((new Array({})), nullptr, static_cast<Proc*>(block));
  return nil_instance();
}

inline BasicObject* IO::m_codepoints(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("each_codepoint")})), nullptr, nullptr);
  }
  return this->m_each_codepoint((new Array({})), nullptr, static_cast<Proc*>(block));
  return nil_instance();
}

inline BasicObject* IO::m_putc(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* c = array_at(args, 0);
  Proc* _block = block;
  if (truthy(c->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr))) {
    this->m_write((new Array({([&]() -> BasicObject* { auto* _l = c->m_aref((new Array({(new Integer(0LL))})), nullptr, nullptr); return truthy(_l) ? _l : ((new String("", 0))); }())})), nullptr, nullptr);
  } else {
    if (truthy(c->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr))) {
      this->m_write((new Array({(c->m_bit_and((new Array({(new Integer(255LL))})), nullptr, nullptr))->m_chr((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
    } else {
      if (truthy(c->m_respond_to_q((new Array({intern("to_int")})), nullptr, nullptr))) {
        this->m_write((new Array({(c->m_to_int((new Array({})), nullptr, nullptr)->m_bit_and((new Array({(new Integer(255LL))})), nullptr, nullptr))->m_chr((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
      } else {
        ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of ", 26))})), nullptr, nullptr)->m_plus((new Array({(c->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into Integer", 13))})), nullptr, nullptr)))); }());
      }
    }
  }
  return c;
  return nil_instance();
}

inline IO_CapturedOutput::IO_CapturedOutput(BasicObject* str) {
  (this->iv_str = str);
}

inline BasicObject* IO_CapturedOutput::m_read(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* len = (args->data.size() > 0) ? args->data[0] : (nil_instance());
  Proc* _block = block;
  return (truthy(len) ? ((this->iv_str->m_aref((new Array({(new Integer(0LL)), len})), nullptr, nullptr))) : ((this->iv_str)));
  return nil_instance();
}

inline BasicObject* IO_CapturedOutput::m_gets(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_str;
  return nil_instance();
}

inline BasicObject* IO_CapturedOutput::m_close(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* File::m_chown(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* uid = array_at(args, 0);
  BasicObject* gid = array_at(args, 1);
  Proc* _block = block;
  return (new Integer(0LL));
  return nil_instance();
}

inline BasicObject* File::m_lstat(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new File_Stat(static_cast<BasicObject*>(this->m_path((new Array({})), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* File_Stat::m_file_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (this->m_mode((new Array({})), nullptr, nullptr)->m_bit_and((new Array({(new Integer(61440LL))})), nullptr, nullptr))->m_eq_q((new Array({(new Integer(32768LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_directory_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (this->m_mode((new Array({})), nullptr, nullptr)->m_bit_and((new Array({(new Integer(61440LL))})), nullptr, nullptr))->m_eq_q((new Array({(new Integer(16384LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_symlink_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (this->m_mode((new Array({})), nullptr, nullptr)->m_bit_and((new Array({(new Integer(61440LL))})), nullptr, nullptr))->m_eq_q((new Array({(new Integer(40960LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_pipe_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (this->m_mode((new Array({})), nullptr, nullptr)->m_bit_and((new Array({(new Integer(61440LL))})), nullptr, nullptr))->m_eq_q((new Array({(new Integer(4096LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_socket_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (this->m_mode((new Array({})), nullptr, nullptr)->m_bit_and((new Array({(new Integer(61440LL))})), nullptr, nullptr))->m_eq_q((new Array({(new Integer(49152LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_blockdev_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (this->m_mode((new Array({})), nullptr, nullptr)->m_bit_and((new Array({(new Integer(61440LL))})), nullptr, nullptr))->m_eq_q((new Array({(new Integer(24576LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_chardev_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (this->m_mode((new Array({})), nullptr, nullptr)->m_bit_and((new Array({(new Integer(61440LL))})), nullptr, nullptr))->m_eq_q((new Array({(new Integer(8192LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_setuid_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (this->m_mode((new Array({})), nullptr, nullptr)->m_bit_and((new Array({(new Integer(2048LL))})), nullptr, nullptr))->m_ne_q((new Array({(new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_setgid_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (this->m_mode((new Array({})), nullptr, nullptr)->m_bit_and((new Array({(new Integer(1024LL))})), nullptr, nullptr))->m_ne_q((new Array({(new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_sticky_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (this->m_mode((new Array({})), nullptr, nullptr)->m_bit_and((new Array({(new Integer(512LL))})), nullptr, nullptr))->m_ne_q((new Array({(new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_zero_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_size((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_empty_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_size((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_size_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->m_size((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((nil_instance())) : ((this->m_size((new Array({})), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* File_Stat::m_readable_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (&File_CLASS)->m_readable_q((new Array({this->iv_path})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_readable_real_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (&File_CLASS)->m_readable_real_q((new Array({this->iv_path})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_writable_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (&File_CLASS)->m_writable_q((new Array({this->iv_path})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_writable_real_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (&File_CLASS)->m_writable_real_q((new Array({this->iv_path})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_executable_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (&File_CLASS)->m_executable_q((new Array({this->iv_path})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_executable_real_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (&File_CLASS)->m_executable_real_q((new Array({this->iv_path})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_owned_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (&File_CLASS)->m_owned_q((new Array({this->iv_path})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_grpowned_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (&File_CLASS)->m_grpowned_q((new Array({this->iv_path})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_Stat::m_inspect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ((new String("", 0))->m_plus((new Array({(new String("#<File::Stat dev=0x", 19))})), nullptr, nullptr)->m_plus((new Array({(this->m_dev((new Array({})), nullptr, nullptr)->m_to_s((new Array({(new Integer(16LL))})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(", ino=", 6))})), nullptr, nullptr)->m_plus((new Array({(this->m_ino((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(", mode=0", 8))})), nullptr, nullptr)->m_plus((new Array({(this->m_mode((new Array({})), nullptr, nullptr)->m_to_s((new Array({(new Integer(8LL))})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(", nlink=", 8))})), nullptr, nullptr)->m_plus((new Array({(this->m_nlink((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(", uid=", 6))})), nullptr, nullptr)->m_plus((new Array({(this->m_uid((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(", gid=", 6))})), nullptr, nullptr)->m_plus((new Array({(this->m_gid((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(", rdev=0x", 9))})), nullptr, nullptr)->m_plus((new Array({(this->m_rdev((new Array({})), nullptr, nullptr)->m_to_s((new Array({(new Integer(16LL))})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(", size=", 7))})), nullptr, nullptr)->m_plus((new Array({(this->m_size((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(", blksize=", 10))})), nullptr, nullptr)->m_plus((new Array({(this->m_blksize((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(", blocks=", 9))})), nullptr, nullptr)->m_plus((new Array({(this->m_blocks((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(", atime=", 8))})), nullptr, nullptr)->m_plus((new Array({(this->m_atime((new Array({})), nullptr, nullptr)->m_inspect((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(", mtime=", 8))})), nullptr, nullptr)->m_plus((new Array({(this->m_mtime((new Array({})), nullptr, nullptr)->m_inspect((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(", ctime=", 8))})), nullptr, nullptr)->m_plus((new Array({(this->m_ctime((new Array({})), nullptr, nullptr)->m_inspect((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(">", 1))})), nullptr, nullptr));
  return nil_instance();
}

inline BasicObject* File_Stat::m_ftype(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _subj = this->m_mode((new Array({})), nullptr, nullptr)->m_bit_and((new Array({(new Integer(61440LL))})), nullptr, nullptr); if (truthy((new Integer(32768LL))->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("file", 4))); if (truthy((new Integer(16384LL))->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("directory", 9))); if (truthy((new Integer(40960LL))->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("link", 4))); if (truthy((new Integer(4096LL))->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("fifo", 4))); if (truthy((new Integer(49152LL))->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("socket", 6))); if (truthy((new Integer(24576LL))->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("blockSpecial", 12))); if (truthy((new Integer(8192LL))->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("characterSpecial", 16))); return ((new String("unknown", 7))); }());
  return nil_instance();
}

inline BasicObject* File_Stat::m_world_readable_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* m = nil_instance();
  m = this->m_mode((new Array({})), nullptr, nullptr);
  return (truthy((m->m_bit_and((new Array({(new Integer(4LL))})), nullptr, nullptr))->m_ne_q((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((m->m_bit_and((new Array({(new Integer(511LL))})), nullptr, nullptr))) : ((nil_instance())));
  return nil_instance();
}

inline BasicObject* File_Stat::m_world_writable_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* m = nil_instance();
  m = this->m_mode((new Array({})), nullptr, nullptr);
  return (truthy((m->m_bit_and((new Array({(new Integer(2LL))})), nullptr, nullptr))->m_ne_q((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((m->m_bit_and((new Array({(new Integer(511LL))})), nullptr, nullptr))) : ((nil_instance())));
  return nil_instance();
}

inline BasicObject* Dir::m_path(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_path;
  return nil_instance();
}

inline BasicObject* Dir::m_to_path(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_path;
  return nil_instance();
}

inline BasicObject* Dir::m_inspect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ((new String("", 0))->m_plus((new Array({(new String("#<Dir:", 6))})), nullptr, nullptr)->m_plus((new Array({(this->iv_path)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(">", 1))})), nullptr, nullptr));
  return nil_instance();
}

inline BasicObject* Dir::m_closed_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_closed;
  return nil_instance();
}

inline BasicObject* Dir::m_children(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m___load_entries__((new Array({})), nullptr, nullptr)->m_reject((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* e = arg; return ([&]() -> BasicObject* { auto* _l = e->m_eq_q((new Array({(new String(".", 1))})), nullptr, nullptr); return truthy(_l) ? _l : (e->m_eq_q((new Array({(new String("..", 2))})), nullptr, nullptr)); }()); })));
  return nil_instance();
}

inline BasicObject* Dir::m_entries(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m___load_entries__((new Array({})), nullptr, nullptr)->m_dup((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Dir::m_pos(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv_closed)) {
    ([&]() -> BasicObject* { throw (new IOError((new String("closed directory", 16)))); }());
  }
  return this->iv_pos;
  return nil_instance();
}

inline BasicObject* Dir::m_tell(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv_closed)) {
    ([&]() -> BasicObject* { throw (new IOError((new String("closed directory", 16)))); }());
  }
  return this->iv_pos;
  return nil_instance();
}

inline BasicObject* Dir::m_each(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* entry = nil_instance();
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("each")})), nullptr, nullptr);
  }
  this->m_rewind((new Array({})), nullptr, nullptr);
  while (truthy(((entry = this->m_read((new Array({})), nullptr, nullptr))))) {
    block->m_call((new Array({entry})), nullptr, nullptr);
  }
  return this;
  return nil_instance();
}

inline BasicObject* Dir::m_each_child(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("each_child")})), nullptr, nullptr);
  }
  this->m_children((new Array({})), nullptr, nullptr)->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* e = arg; return block->m_call((new Array({e})), nullptr, nullptr); })));
  return this;
  return nil_instance();
}

inline BasicObject* Dir::m___load_entries__(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  ([&]() -> BasicObject* { auto* _l = this->iv_entries; return truthy(_l) ? _l : ((this->iv_entries = (&Dir_CLASS)->m_entries((new Array({this->iv_path})), nullptr, nullptr))); }());
  return nil_instance();
}

inline BasicObject* Time::m_day(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_mday((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_mon(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_month((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_gmt_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_utc_q((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_isdst(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_dst_q((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_hash(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_r((new Array({})), nullptr, nullptr)->m_hash((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_tv_sec(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_i((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_tv_usec(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_usec((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_tv_nsec(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_nsec((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_gmtime(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_utc((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_getgm(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_getutc((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_gmt_offset(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_utc_offset((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_gmtoff(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_utc_offset((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_ctime(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_asctime((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_xmlschema(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* fraction_digits = (args->data.size() > 0) ? args->data[0] : ((new Integer(0LL)));
  Proc* _block = block;
  return this->m_iso8601((new Array({fraction_digits})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_monday_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_wday((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(1LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_tuesday_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_wday((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(2LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_wednesday_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_wday((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(3LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_thursday_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_wday((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(4LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_friday_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_wday((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(5LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_saturday_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_wday((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(6LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_sunday_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_wday((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_to_a(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Array({this->m_sec((new Array({})), nullptr, nullptr), this->m_min((new Array({})), nullptr, nullptr), this->m_hour((new Array({})), nullptr, nullptr), this->m_mday((new Array({})), nullptr, nullptr), this->m_month((new Array({})), nullptr, nullptr), this->m_year((new Array({})), nullptr, nullptr), this->m_wday((new Array({})), nullptr, nullptr), this->m_yday((new Array({})), nullptr, nullptr), this->m_dst_q((new Array({})), nullptr, nullptr), this->m_zone((new Array({})), nullptr, nullptr)}));
  return nil_instance();
}

inline BasicObject* Time::m_eql_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = other->m_is_a_q((new Array({(&Time_CLASS)})), nullptr, nullptr); return truthy(_l) ? (this->m_to_r((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_to_r((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* Time::m_to_time(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* Time::m_httpdate(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_getutc((new Array({})), nullptr, nullptr)->m_strftime((new Array({(new String("%a, %d %b %Y %T GMT", 19))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_deconstruct_keys(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* keys = array_at(args, 0);
  Proc* _block = block;
  BasicObject* h = nil_instance();
  if (truthy(([&]() -> BasicObject* { auto* _l = keys->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (keys->m_is_a_q((new Array({(&Array_CLASS)})), nullptr, nullptr)); }()))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("wrong argument type ", 20))})), nullptr, nullptr)->m_plus((new Array({(keys->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" (expected Array or nil)", 24))})), nullptr, nullptr)))); }());
  }
  h = (new Hash({{intern("year"), this->m_year((new Array({})), nullptr, nullptr)}, {intern("month"), this->m_month((new Array({})), nullptr, nullptr)}, {intern("day"), this->m_mday((new Array({})), nullptr, nullptr)}, {intern("yday"), this->m_yday((new Array({})), nullptr, nullptr)}, {intern("wday"), this->m_wday((new Array({})), nullptr, nullptr)}, {intern("hour"), this->m_hour((new Array({})), nullptr, nullptr)}, {intern("min"), this->m_min((new Array({})), nullptr, nullptr)}, {intern("sec"), this->m_sec((new Array({})), nullptr, nullptr)}, {intern("subsec"), this->m_subsec((new Array({})), nullptr, nullptr)}, {intern("dst"), this->m_dst_q((new Array({})), nullptr, nullptr)}, {intern("zone"), this->m_zone((new Array({})), nullptr, nullptr)}}));
  return (truthy(keys->m_nil_q((new Array({})), nullptr, nullptr)) ? ((h)) : ((h->m_slice(static_cast<Array*>(keys), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* Time::m_spaceship(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  BasicObject* cmp = nil_instance();
  return (truthy(other->m_is_a_q((new Array({(&Time_CLASS)})), nullptr, nullptr)) ? ((this->m_to_r((new Array({})), nullptr, nullptr)->m_spaceship((new Array({other->m_to_r((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) : ((([&]() -> BasicObject* { try { return [&]() -> BasicObject* { cmp = other->m_spaceship((new Array({this})), nullptr, nullptr); if (truthy(cmp->m_nil_q((new Array({})), nullptr, nullptr))) {   return nil_instance(); } return (truthy(cmp->m_gt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? (((new Integer(-1LL)))) : ((((truthy(cmp->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? (((new Integer(1LL)))) : (((new Integer(0LL)))))))));  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return nil_instance();  return nil_instance(); }(); } throw; } }()))));
  return nil_instance();
}

inline BasicObject* Time::m_rfc2822(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_strftime((new Array({(new String("%a, %d %b %Y %T ", 16))})), nullptr, nullptr)->m_lshift((new Array({((truthy(this->m_utc_q((new Array({})), nullptr, nullptr)) ? (((new String("-0000", 5)))) : ((this->m_strftime((new Array({(new String("%z", 2))})), nullptr, nullptr)))))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m_rfc822(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_strftime((new Array({(new String("%a, %d %b %Y %T ", 16))})), nullptr, nullptr)->m_lshift((new Array({((truthy(this->m_utc_q((new Array({})), nullptr, nullptr)) ? (((new String("-0000", 5)))) : ((this->m_strftime((new Array({(new String("%z", 2))})), nullptr, nullptr)))))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time::m__coerce_exact_number(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* val = array_at(args, 0);
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = val->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (val->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)); }()))) {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("can't convert ", 14))})), nullptr, nullptr)->m_plus((new Array({(val->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into an exact number", 21))})), nullptr, nullptr)))); }());
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = val->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (val->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)); }()); return truthy(_l) ? _l : (val->m_is_a_q((new Array({(&Rational_CLASS)})), nullptr, nullptr)); }()))) {
    return val;
  }
  if (truthy(val->m_respond_to_q((new Array({intern("to_r")})), nullptr, nullptr))) {
    return val->m_to_r((new Array({})), nullptr, nullptr);
  }
  if (truthy(val->m_respond_to_q((new Array({intern("to_int")})), nullptr, nullptr))) {
    return val->m_to_int((new Array({})), nullptr, nullptr);
  }
  return ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("can't convert ", 14))})), nullptr, nullptr)->m_plus((new Array({(val->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into an exact number", 21))})), nullptr, nullptr)))); }());
  return nil_instance();
}

inline Mutex::Mutex() {
  (this->iv_locked = false_instance());
  (this->iv_owner = nil_instance());
  (this->iv_owner_fiber = nil_instance());
}

inline BasicObject* Mutex::m_locked_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_locked;
  return nil_instance();
}

inline BasicObject* Mutex::m_owned_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv_locked)) {
    nil_instance();
  } else {
    return false_instance();
  }
  return ([&]() -> BasicObject* { auto* _l = this->iv_owner->m_equal_q((new Array({(&Thread_CLASS)->m_current((new Array({})), nullptr, nullptr)})), nullptr, nullptr); return truthy(_l) ? (this->iv_owner_fiber->m_equal_q((new Array({(&Fiber_CLASS)->m_current((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* Mutex::m_lock(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* current = nil_instance();
  BasicObject* seen = nil_instance();
  BasicObject* skip_n = nil_instance();
  current = (&Thread_CLASS)->m_current((new Array({})), nullptr, nullptr);
  seen = current->m___mutex_seen_count((new Array({})), nullptr, nullptr);
  skip_n = current->m___mutex_skip_count((new Array({})), nullptr, nullptr);
  if (truthy(seen->m_lt((new Array({skip_n})), nullptr, nullptr))) {
    current->m___mutex_seen_count_set((new Array({seen->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr)})), nullptr, nullptr);
    current->m___mutex_done_count_set((new Array({current->m___mutex_done_count((new Array({})), nullptr, nullptr)->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr)})), nullptr, nullptr);
    (this->iv_locked = true_instance());
    (this->iv_owner = current);
    (this->iv_owner_fiber = (&Fiber_CLASS)->m_current((new Array({})), nullptr, nullptr));
    current->m___add_owned_mutex((new Array({this})), nullptr, nullptr);
    return this;
  }
  if (truthy(this->iv_locked)) {
    if (truthy(this->m_owned_q((new Array({})), nullptr, nullptr))) {
      ([&]() -> BasicObject* { throw (new ThreadError((new String("deadlock; recursive locking", 27)))); }());
    }
    ([&]() -> BasicObject* { throw (new Thread_Blocked()); }());
  }
  (this->iv_locked = true_instance());
  (this->iv_owner = current);
  (this->iv_owner_fiber = (&Fiber_CLASS)->m_current((new Array({})), nullptr, nullptr));
  current->m___add_owned_mutex((new Array({this})), nullptr, nullptr);
  current->m___mutex_done_count_set((new Array({current->m___mutex_done_count((new Array({})), nullptr, nullptr)->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr)})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Mutex::m_unlock(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* owner = nil_instance();
  if (truthy(this->iv_locked)) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ThreadError((new String("Attempt to unlock a mutex which is not locked", 45)))); }());
  }
  if (truthy(this->m_owned_q((new Array({})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ThreadError((new String("Attempt to unlock a mutex which is locked by another thread/fiber", 65)))); }());
  }
  owner = this->iv_owner;
  (this->iv_locked = false_instance());
  (this->iv_owner = nil_instance());
  (this->iv_owner_fiber = nil_instance());
  owner->m___remove_owned_mutex((new Array({this})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Mutex::m___force_unlock(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  (this->iv_locked = false_instance());
  (this->iv_owner = nil_instance());
  (this->iv_owner_fiber = nil_instance());
  return this;
  return nil_instance();
}

inline BasicObject* Mutex::m_try_lock(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv_locked)) {
    return false_instance();
  }
  (this->iv_locked = true_instance());
  (this->iv_owner = (&Thread_CLASS)->m_current((new Array({})), nullptr, nullptr));
  (this->iv_owner_fiber = (&Fiber_CLASS)->m_current((new Array({})), nullptr, nullptr));
  (&Thread_CLASS)->m_current((new Array({})), nullptr, nullptr)->m___add_owned_mutex((new Array({this})), nullptr, nullptr);
  return true_instance();
  return nil_instance();
}

inline BasicObject* Mutex::m_synchronize(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* blocked = nil_instance();
  this->m_lock((new Array({})), nullptr, nullptr);
  blocked = false_instance();
  return ([&]() -> BasicObject* { EnsureGuard _eg([&]() { if (truthy(blocked)) {   nil_instance(); } else {   this->m_unlock((new Array({})), nullptr, nullptr); }  return nil_instance(); }); try { return [&]() -> BasicObject* { return block->m_call((new Array({})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<Thread_Blocked*>(e_) != nullptr) { return [&]() -> BasicObject* { blocked = true_instance(); return ([&]() -> BasicObject* { throw; }());  return nil_instance(); }(); } throw; } }());
  return nil_instance();
}

inline BasicObject* Fiber::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_inspect((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Thread::m___stop_seen(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_stop_seen;
  return nil_instance();
}

inline BasicObject* Thread::m___stop_seen_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* v = array_at(args, 0);
  Proc* _block = block;
  return (this->iv_stop_seen = v);
  return nil_instance();
}

inline BasicObject* Thread::m___wakeup_count(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_wakeup_count;
  return nil_instance();
}

inline BasicObject* Thread::m___wakeup_count_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* v = array_at(args, 0);
  Proc* _block = block;
  return (this->iv_wakeup_count = v);
  return nil_instance();
}

inline BasicObject* Thread::m___mutex_skip_count(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->iv_mutex_skip_count; return truthy(_l) ? _l : ((new Integer(0LL))); }());
  return nil_instance();
}

inline BasicObject* Thread::m___mutex_skip_count_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* v = array_at(args, 0);
  Proc* _block = block;
  return (this->iv_mutex_skip_count = v);
  return nil_instance();
}

inline BasicObject* Thread::m___mutex_seen_count(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->iv_mutex_seen_count; return truthy(_l) ? _l : ((new Integer(0LL))); }());
  return nil_instance();
}

inline BasicObject* Thread::m___mutex_seen_count_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* v = array_at(args, 0);
  Proc* _block = block;
  return (this->iv_mutex_seen_count = v);
  return nil_instance();
}

inline BasicObject* Thread::m___mutex_done_count(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->iv_mutex_done_count; return truthy(_l) ? _l : ((new Integer(0LL))); }());
  return nil_instance();
}

inline BasicObject* Thread::m___mutex_done_count_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* v = array_at(args, 0);
  Proc* _block = block;
  return (this->iv_mutex_done_count = v);
  return nil_instance();
}

inline BasicObject* Thread::m___raise_exception(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_raise_exception;
  return nil_instance();
}

inline BasicObject* Thread::m___raise_exception_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* v = array_at(args, 0);
  Proc* _block = block;
  return (this->iv_raise_exception = v);
  return nil_instance();
}

inline BasicObject* Thread::m___raise_cause(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_raise_cause;
  return nil_instance();
}

inline BasicObject* Thread::m___raise_cause_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* v = array_at(args, 0);
  Proc* _block = block;
  return (this->iv_raise_cause = v);
  return nil_instance();
}

inline BasicObject* Thread::m___raise_backtrace(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_raise_backtrace;
  return nil_instance();
}

inline BasicObject* Thread::m___raise_backtrace_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* v = array_at(args, 0);
  Proc* _block = block;
  return (this->iv_raise_backtrace = v);
  return nil_instance();
}

inline BasicObject* Thread::m_alive_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->iv_done->m_not((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : ((([&]() -> BasicObject* { auto* _l = this->iv_aborting; return truthy(_l) ? ((([&]() -> BasicObject* { auto* _l = this->iv_executing; return truthy(_l) ? _l : (this->iv_run_yielded); }()))) : _l; }()))); }());
  return nil_instance();
}

inline BasicObject* Thread::m_stop_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->m_alive_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : ((([&]() -> BasicObject* { auto* _l = this->iv_executing->m_not((new Array({})), nullptr, nullptr); return truthy(_l) ? (this->iv_run_yielded->m_not((new Array({})), nullptr, nullptr)) : _l; }()))); }());
  return nil_instance();
}

inline BasicObject* Thread::m_report_on_exception_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* val = array_at(args, 0);
  Proc* _block = block;
  return (this->iv_report_on_exception = val);
  return nil_instance();
}

inline BasicObject* Thread::m_report_on_exception(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->iv_report_on_exception->m_nil_q((new Array({})), nullptr, nullptr)) ? (((&Thread_CLASS)->m_report_on_exception((new Array({})), nullptr, nullptr))) : ((this->iv_report_on_exception)));
  return nil_instance();
}

inline BasicObject* Thread::m_abort_on_exception_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* val = array_at(args, 0);
  Proc* _block = block;
  return (this->iv_abort_on_exception = val->m_not((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr));
  return nil_instance();
}

inline BasicObject* Thread::m_abort_on_exception(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->iv_abort_on_exception->m_nil_q((new Array({})), nullptr, nullptr)) ? (((&Thread_CLASS)->m_abort_on_exception((new Array({})), nullptr, nullptr))) : ((this->iv_abort_on_exception)));
  return nil_instance();
}

inline BasicObject* Thread::m_status(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = this->iv_done; return truthy(_l) ? (this->iv_exception) : _l; }()))) {
    return nil_instance();
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = this->iv_aborting; return truthy(_l) ? ((([&]() -> BasicObject* { auto* _l = this->iv_executing; return truthy(_l) ? _l : (this->iv_run_yielded); }()))) : _l; }()))) {
    return (new String("aborting", 8));
  }
  if (truthy(this->iv_done)) {
    return false_instance();
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = this->iv_executing; return truthy(_l) ? _l : (this->iv_run_yielded); }()))) {
    return (new String("run", 3));
  }
  return (new String("sleep", 5));
  return nil_instance();
}

inline BasicObject* Thread::m_wakeup(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv_done)) {
    this->m_fail((new Array({(&ThreadError_CLASS), (new String("dead thread called wakeup", 25))})), nullptr, nullptr);
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = this->iv_run_yielded; return truthy(_l) ? _l : (this->iv_executing); }()))) {
    nil_instance();
  } else {
    (this->iv_wakeup_count = (([&]() -> BasicObject* { auto* _l = this->iv_wakeup_count; return truthy(_l) ? _l : ((new Integer(0LL))); }()))->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr));
  }
  this->m___run_block((new Array({})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Thread::m_run(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv_done)) {
    this->m_fail((new Array({(&ThreadError_CLASS), (new String("dead thread called wakeup", 25))})), nullptr, nullptr);
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = this->iv_run_yielded; return truthy(_l) ? _l : (this->iv_executing); }()))) {
    nil_instance();
  } else {
    (this->iv_wakeup_count = (([&]() -> BasicObject* { auto* _l = this->iv_wakeup_count; return truthy(_l) ? _l : ((new Integer(0LL))); }()))->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr));
  }
  this->m___run_block((new Array({})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Thread::m_priority(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  ([&]() -> BasicObject* { auto* _l = this->iv_priority; return truthy(_l) ? _l : ((new Integer(0LL))); }());
  return nil_instance();
}

inline BasicObject* Thread::m_native_thread_id(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->m_alive_q((new Array({})), nullptr, nullptr)) ? ((this->m_object_id((new Array({})), nullptr, nullptr))) : ((nil_instance())));
  return nil_instance();
}

inline BasicObject* Thread::m_name(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_name;
  return nil_instance();
}

inline BasicObject* Thread::m_group(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_group;
  return nil_instance();
}

inline BasicObject* Thread::m___set_group(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* g = array_at(args, 0);
  Proc* _block = block;
  (this->iv_group = g);
  return nil_instance();
}

inline BasicObject* Thread::m_pending_interrupt_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* exc = (args->data.size() > 0) ? args->data[0] : (nil_instance());
  Proc* _block = block;
  return false_instance();
  return nil_instance();
}

inline BasicObject* Thread::m_add_trace_func(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* f = array_at(args, 0);
  Proc* _block = block;
  return f;
  return nil_instance();
}

inline BasicObject* Thread::m_set_trace_func(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* f = array_at(args, 0);
  Proc* _block = block;
  return f;
  return nil_instance();
}

inline BasicObject* Thread::m_priority_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* v = array_at(args, 0);
  Proc* _block = block;
  v = this->m___coerce_to_int__((new Array({v})), nullptr, nullptr);
  (this->iv_priority = v->m_clamp((new Array({(new Integer(-3LL)), (new Integer(3LL))})), nullptr, nullptr));
  return v;
  return nil_instance();
}

inline BasicObject* Thread::m_inspect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* id_str = nil_instance();
  BasicObject* status_str = nil_instance();
  BasicObject* loc = nil_instance();
  id_str = ((new String("0x%016x", 7))->m_mod((new Array({(this->m___id__((new Array({})), nullptr, nullptr)->m_mul((new Array({(new Integer(2LL))})), nullptr, nullptr))})), nullptr, nullptr));
  status_str = ([&]() -> BasicObject* { auto* _subj = this->m_status((new Array({})), nullptr, nullptr); if (truthy((new String("run", 3))->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("run", 3))); if (truthy((new String("sleep", 5))->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("sleep", 5))); if (truthy((new String("aborting", 8))->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("aborting", 8))); if (truthy(false_instance()->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("dead", 4))); if (truthy(nil_instance()->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("dead", 4))); return ((new String("dead", 4))); }());
  loc = (truthy(this->iv_source_location_str) ? ((((new String("", 0))->m_plus((new Array({(new String(" ", 1))})), nullptr, nullptr)->m_plus((new Array({(this->iv_source_location_str)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))) : (((new String("", 0)))));
  return ((new String("", 0))->m_plus((new Array({(new String("#<Thread:", 9))})), nullptr, nullptr)->m_plus((new Array({(id_str)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(loc)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" ", 1))})), nullptr, nullptr)->m_plus((new Array({(status_str)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(">", 1))})), nullptr, nullptr))->m_b((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Thread::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* id_str = nil_instance();
  BasicObject* status_str = nil_instance();
  BasicObject* loc = nil_instance();
  id_str = ((new String("0x%016x", 7))->m_mod((new Array({(this->m___id__((new Array({})), nullptr, nullptr)->m_mul((new Array({(new Integer(2LL))})), nullptr, nullptr))})), nullptr, nullptr));
  status_str = ([&]() -> BasicObject* { auto* _subj = this->m_status((new Array({})), nullptr, nullptr); if (truthy((new String("run", 3))->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("run", 3))); if (truthy((new String("sleep", 5))->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("sleep", 5))); if (truthy((new String("aborting", 8))->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("aborting", 8))); if (truthy(false_instance()->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("dead", 4))); if (truthy(nil_instance()->m_case_eq((new Array({_subj})), nullptr, nullptr))) return ((new String("dead", 4))); return ((new String("dead", 4))); }());
  loc = (truthy(this->iv_source_location_str) ? ((((new String("", 0))->m_plus((new Array({(new String(" ", 1))})), nullptr, nullptr)->m_plus((new Array({(this->iv_source_location_str)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))) : (((new String("", 0)))));
  return ((new String("", 0))->m_plus((new Array({(new String("#<Thread:", 9))})), nullptr, nullptr)->m_plus((new Array({(id_str)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(loc)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" ", 1))})), nullptr, nullptr)->m_plus((new Array({(status_str)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(">", 1))})), nullptr, nullptr))->m_b((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Thread::m___init_main(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  (this->iv_block = nil_instance());
  (this->iv_result = nil_instance());
  (this->iv_exception = nil_instance());
  (this->iv_done = false_instance());
  (this->iv_executing = false_instance());
  (this->iv_run_yielded = false_instance());
  (this->iv_aborting = false_instance());
  (this->iv_wakeup_count = (new Integer(0LL)));
  (this->iv_stop_seen = (new Integer(0LL)));
  (this->iv_mutex_skip_count = (new Integer(0LL)));
  (this->iv_mutex_seen_count = (new Integer(0LL)));
  (this->iv_mutex_done_count = (new Integer(0LL)));
  (this->iv_raise_exception = nil_instance());
  (this->iv_raise_cause = nil_instance());
  (this->iv_raise_backtrace = nil_instance());
  (this->iv_report_on_exception = nil_instance());
  (this->iv_name = nil_instance());
  (this->iv_thread_vars = (new Hash({})));
  (this->iv_fiber_vars = (new Hash({})));
  (this->iv_owned_mutexes = (new Array({})));
  (this->iv_source_location_str = nil_instance());
  return (this->iv_group = nil_instance());
  return nil_instance();
}

inline BasicObject* Thread::m___add_owned_mutex(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* m = array_at(args, 0);
  Proc* _block = block;
  ([&]() -> BasicObject* { auto* _l = this->iv_owned_mutexes; return truthy(_l) ? _l : ((this->iv_owned_mutexes = (new Array({})))); }());
  return (truthy(this->iv_owned_mutexes->m_include_q((new Array({m})), nullptr, nullptr)) ? (nil_instance()) : ((this->iv_owned_mutexes->m_lshift((new Array({m})), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* Thread::m___remove_owned_mutex(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* m = array_at(args, 0);
  Proc* _block = block;
  ([&]() -> BasicObject* { auto* _l = this->iv_owned_mutexes; return truthy(_l) ? _l : ((this->iv_owned_mutexes = (new Array({})))); }());
  return this->iv_owned_mutexes->m_delete((new Array({m})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Thread::m_thread_variable_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* key = array_at(args, 0);
  BasicObject* value = array_at(args, 1);
  Proc* _block = block;
  BasicObject* k = nil_instance();
  this->m___check_frozen__((new Array({})), nullptr, nullptr);
  k = this->m___coerce_var_key((new Array({key})), nullptr, nullptr);
  ([&]() -> BasicObject* { auto* _l = this->iv_thread_vars; return truthy(_l) ? _l : ((this->iv_thread_vars = (new Hash({})))); }());
  if (truthy(value->m_nil_q((new Array({})), nullptr, nullptr))) {
    this->iv_thread_vars->m_delete((new Array({k})), nullptr, nullptr);
  } else {
    this->iv_thread_vars->m_aset((new Array({k, value})), nullptr, nullptr);
  }
  return value;
  return nil_instance();
}

inline BasicObject* Thread::m_thread_variable_get(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* key = array_at(args, 0);
  Proc* _block = block;
  return (([&]() -> BasicObject* { auto* _l = this->iv_thread_vars; return truthy(_l) ? _l : ((new Hash({}))); }()))->m_aref((new Array({this->m___coerce_var_key((new Array({key})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Thread::m_thread_variable_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* key = array_at(args, 0);
  Proc* _block = block;
  return (([&]() -> BasicObject* { auto* _l = this->iv_thread_vars; return truthy(_l) ? _l : ((new Hash({}))); }()))->m_key_q((new Array({this->m___coerce_var_key((new Array({key})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Thread::m_thread_variables(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (([&]() -> BasicObject* { auto* _l = this->iv_thread_vars; return truthy(_l) ? _l : ((new Hash({}))); }()))->m_keys((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Thread::m_aref(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* key = array_at(args, 0);
  Proc* _block = block;
  BasicObject* k = nil_instance();
  BasicObject* f = nil_instance();
  BasicObject* fv = nil_instance();
  k = this->m___coerce_var_key((new Array({key})), nullptr, nullptr);
  f = (&Fiber_CLASS)->m_current((new Array({})), nullptr, nullptr);
  fv = ([&]() -> BasicObject* { auto* _l = this->iv_fiber_vars; return truthy(_l) ? (this->iv_fiber_vars->m_aref((new Array({f})), nullptr, nullptr)) : _l; }());
  return (truthy(fv) ? ((fv->m_aref((new Array({k})), nullptr, nullptr))) : ((nil_instance())));
  return nil_instance();
}

inline BasicObject* Thread::m_aset(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* key = array_at(args, 0);
  BasicObject* value = array_at(args, 1);
  Proc* _block = block;
  this->m___check_frozen__((new Array({})), nullptr, nullptr);
  return this->m___fiber_vars((new Array({})), nullptr, nullptr)->m_aset((new Array({this->m___coerce_var_key((new Array({key})), nullptr, nullptr), value})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Thread::m_key_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* key = array_at(args, 0);
  Proc* _block = block;
  BasicObject* k = nil_instance();
  BasicObject* f = nil_instance();
  BasicObject* fv = nil_instance();
  k = this->m___coerce_var_key((new Array({key})), nullptr, nullptr);
  f = (&Fiber_CLASS)->m_current((new Array({})), nullptr, nullptr);
  fv = ([&]() -> BasicObject* { auto* _l = this->iv_fiber_vars; return truthy(_l) ? (this->iv_fiber_vars->m_aref((new Array({f})), nullptr, nullptr)) : _l; }());
  return (truthy(fv) ? ((fv->m_key_q((new Array({k})), nullptr, nullptr))) : ((false_instance())));
  return nil_instance();
}

inline BasicObject* Thread::m_keys(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* f = nil_instance();
  BasicObject* fv = nil_instance();
  f = (&Fiber_CLASS)->m_current((new Array({})), nullptr, nullptr);
  fv = ([&]() -> BasicObject* { auto* _l = this->iv_fiber_vars; return truthy(_l) ? (this->iv_fiber_vars->m_aref((new Array({f})), nullptr, nullptr)) : _l; }());
  return (truthy(fv) ? ((fv->m_keys((new Array({})), nullptr, nullptr))) : (((new Array({})))));
  return nil_instance();
}

inline Thread_Mutex::Thread_Mutex() {
  (this->iv_locked = false_instance());
  (this->iv_owner = nil_instance());
  (this->iv_owner_fiber = nil_instance());
}

inline BasicObject* Thread_Mutex::m_locked_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_locked;
  return nil_instance();
}

inline BasicObject* Thread_Mutex::m_owned_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv_locked)) {
    nil_instance();
  } else {
    return false_instance();
  }
  return ([&]() -> BasicObject* { auto* _l = this->iv_owner->m_equal_q((new Array({(&Thread_CLASS)->m_current((new Array({})), nullptr, nullptr)})), nullptr, nullptr); return truthy(_l) ? (this->iv_owner_fiber->m_equal_q((new Array({(&Fiber_CLASS)->m_current((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* Thread_Mutex::m_lock(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* current = nil_instance();
  BasicObject* seen = nil_instance();
  BasicObject* skip_n = nil_instance();
  current = (&Thread_CLASS)->m_current((new Array({})), nullptr, nullptr);
  seen = current->m___mutex_seen_count((new Array({})), nullptr, nullptr);
  skip_n = current->m___mutex_skip_count((new Array({})), nullptr, nullptr);
  if (truthy(seen->m_lt((new Array({skip_n})), nullptr, nullptr))) {
    current->m___mutex_seen_count_set((new Array({seen->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr)})), nullptr, nullptr);
    current->m___mutex_done_count_set((new Array({current->m___mutex_done_count((new Array({})), nullptr, nullptr)->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr)})), nullptr, nullptr);
    (this->iv_locked = true_instance());
    (this->iv_owner = current);
    (this->iv_owner_fiber = (&Fiber_CLASS)->m_current((new Array({})), nullptr, nullptr));
    current->m___add_owned_mutex((new Array({this})), nullptr, nullptr);
    return this;
  }
  if (truthy(this->iv_locked)) {
    if (truthy(this->m_owned_q((new Array({})), nullptr, nullptr))) {
      ([&]() -> BasicObject* { throw (new ThreadError((new String("deadlock; recursive locking", 27)))); }());
    }
    ([&]() -> BasicObject* { throw (new Thread_Blocked()); }());
  }
  (this->iv_locked = true_instance());
  (this->iv_owner = current);
  (this->iv_owner_fiber = (&Fiber_CLASS)->m_current((new Array({})), nullptr, nullptr));
  current->m___add_owned_mutex((new Array({this})), nullptr, nullptr);
  current->m___mutex_done_count_set((new Array({current->m___mutex_done_count((new Array({})), nullptr, nullptr)->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr)})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Thread_Mutex::m_unlock(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* owner = nil_instance();
  if (truthy(this->iv_locked)) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ThreadError((new String("Attempt to unlock a mutex which is not locked", 45)))); }());
  }
  if (truthy(this->m_owned_q((new Array({})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ThreadError((new String("Attempt to unlock a mutex which is locked by another thread/fiber", 65)))); }());
  }
  owner = this->iv_owner;
  (this->iv_locked = false_instance());
  (this->iv_owner = nil_instance());
  (this->iv_owner_fiber = nil_instance());
  owner->m___remove_owned_mutex((new Array({this})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Thread_Mutex::m___force_unlock(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  (this->iv_locked = false_instance());
  (this->iv_owner = nil_instance());
  (this->iv_owner_fiber = nil_instance());
  return this;
  return nil_instance();
}

inline BasicObject* Thread_Mutex::m_try_lock(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv_locked)) {
    return false_instance();
  }
  (this->iv_locked = true_instance());
  (this->iv_owner = (&Thread_CLASS)->m_current((new Array({})), nullptr, nullptr));
  (this->iv_owner_fiber = (&Fiber_CLASS)->m_current((new Array({})), nullptr, nullptr));
  (&Thread_CLASS)->m_current((new Array({})), nullptr, nullptr)->m___add_owned_mutex((new Array({this})), nullptr, nullptr);
  return true_instance();
  return nil_instance();
}

inline BasicObject* Thread_Mutex::m_synchronize(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* blocked = nil_instance();
  this->m_lock((new Array({})), nullptr, nullptr);
  blocked = false_instance();
  return ([&]() -> BasicObject* { EnsureGuard _eg([&]() { if (truthy(blocked)) {   nil_instance(); } else {   this->m_unlock((new Array({})), nullptr, nullptr); }  return nil_instance(); }); try { return [&]() -> BasicObject* { return block->m_call((new Array({})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<Thread_Blocked*>(e_) != nullptr) { return [&]() -> BasicObject* { blocked = true_instance(); return ([&]() -> BasicObject* { throw; }());  return nil_instance(); }(); } throw; } }());
  return nil_instance();
}

inline BasicObject* Thread_Backtrace_Location::m_path(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_path;
  return nil_instance();
}

inline BasicObject* Thread_Backtrace_Location::m_lineno(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_lineno;
  return nil_instance();
}

inline BasicObject* Thread_Backtrace_Location::m_label(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->iv_label; return truthy(_l) ? _l : ((new String("<main>", 6))); }());
  return nil_instance();
}

inline BasicObject* Thread_Backtrace_Location::m_inspect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_s((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Thread_Backtrace_Location::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (truthy(this->iv_label) ? ((((new String("", 0))->m_plus((new Array({(this->iv_path)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(":", 1))})), nullptr, nullptr)->m_plus((new Array({(this->iv_lineno)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(":in '", 5))})), nullptr, nullptr)->m_plus((new Array({(this->iv_label)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String("'", 1))})), nullptr, nullptr)))) : ((((new String("", 0))->m_plus((new Array({(this->iv_path)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(":", 1))})), nullptr, nullptr)->m_plus((new Array({(this->iv_lineno)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))));
  return nil_instance();
}

inline ThreadGroup::ThreadGroup() {
  (this->iv_threads = (new Array({})));
  (this->iv_enclosed = false_instance());
}

inline BasicObject* ThreadGroup::m_enclosed_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_enclosed;
  return nil_instance();
}

inline BasicObject* ThreadGroup::m___add_thread(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* thread = array_at(args, 0);
  Proc* _block = block;
  if (truthy(this->iv_threads->m_include_q((new Array({thread})), nullptr, nullptr))) {
    nil_instance();
  } else {
    this->iv_threads->m_lshift((new Array({thread})), nullptr, nullptr);
  }
  return nil_instance();
}

inline BasicObject* ThreadGroup::m___remove_thread(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* thread = array_at(args, 0);
  Proc* _block = block;
  return this->iv_threads->m_delete((new Array({thread})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* ThreadGroup::m_enclose(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  (this->iv_enclosed = true_instance());
  return this;
  return nil_instance();
}

inline BasicObject* ThreadGroup::m_add(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* thread = array_at(args, 0);
  Proc* _block = block;
  if (truthy(thread->m_group((new Array({})), nullptr, nullptr)->m_enclosed_q((new Array({})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new ThreadError((new String("can't move from the enclosed thread group", 41)))); }());
  }
  if (truthy(this->iv_enclosed)) {
    ([&]() -> BasicObject* { throw (new ThreadError((new String("can't move to the enclosed thread group", 39)))); }());
  }
  if (truthy(thread->m_group((new Array({})), nullptr, nullptr))) {
    thread->m_group((new Array({})), nullptr, nullptr)->m___remove_thread((new Array({thread})), nullptr, nullptr);
  }
  thread->m___set_group((new Array({this})), nullptr, nullptr);
  if (truthy(this->iv_threads->m_include_q((new Array({thread})), nullptr, nullptr))) {
    nil_instance();
  } else {
    this->iv_threads->m_lshift((new Array({thread})), nullptr, nullptr);
  }
  return this;
  return nil_instance();
}

inline ConditionVariable::ConditionVariable() {
  (this->iv_waiters = (new Integer(0LL)));
}

inline BasicObject* ConditionVariable::m_signal(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* ConditionVariable::m_broadcast(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* ConditionVariable::m_marshal_dump(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { throw (new TypeError((new String("can't dump ConditionVariable", 28)))); }());
  return nil_instance();
}

inline BasicObject* ConditionVariable::m_wait(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* mutex = array_at(args, 0);
  BasicObject* timeout = (args->data.size() > 1) ? args->data[1] : (nil_instance());
  Proc* _block = block;
  mutex->m_unlock((new Array({})), nullptr, nullptr);
  (&Thread_CLASS)->m___run_next_pending((new Array({})), nullptr, nullptr);
  mutex->m_lock((new Array({})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline Queue::Queue(BasicObject* enumerable) {
  BasicObject* arr = nil_instance();
  (this->iv_data = (new Array({})));
  (this->iv_closed = false_instance());
  (this->iv_waiters = (new Set()));
  (this->iv_deadlines = (new Hash({})));
  if (truthy(enumerable->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr))) {
    if (truthy(enumerable->m_respond_to_q((new Array({intern("to_a")})), nullptr, nullptr))) {
      nil_instance();
    } else {
      ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("can't convert ", 14))})), nullptr, nullptr)->m_plus((new Array({(enumerable->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into Array", 11))})), nullptr, nullptr)))); }());
    }
    arr = enumerable->m_to_a((new Array({})), nullptr, nullptr);
    if (truthy(arr->m_is_a_q((new Array({(&Array_CLASS)})), nullptr, nullptr))) {
      nil_instance();
    } else {
      ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("can't convert ", 14))})), nullptr, nullptr)->m_plus((new Array({(enumerable->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into Array (", 13))})), nullptr, nullptr)->m_plus((new Array({(enumerable->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String("#to_a gives ", 12))})), nullptr, nullptr)->m_plus((new Array({(arr->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(")", 1))})), nullptr, nullptr)))); }());
    }
    arr->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* item = arg; return this->iv_data->m_push((new Array({item})), nullptr, nullptr); })));
  }
}

inline BasicObject* Queue::m_empty_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_data->m_empty_q((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Queue::m_size(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_data->m_size((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Queue::m_length(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_data->m_size((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Queue::m_clear(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  this->iv_data->m_clear((new Array({})), nullptr, nullptr);
  this;
  return nil_instance();
}

inline BasicObject* Queue::m_num_waiting(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_waiters->m_size((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Queue::m_closed_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_closed;
  return nil_instance();
}

inline BasicObject* Queue::m_freeze(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("cannot freeze ", 14))})), nullptr, nullptr)->m_plus((new Array({(this)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))); }());
  return nil_instance();
}

inline BasicObject* Queue::m_close(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  (this->iv_closed = true_instance());
  return this;
  return nil_instance();
}

inline BasicObject* Queue::m_push(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  if (truthy(this->iv_closed)) {
    ([&]() -> BasicObject* { throw (new ClosedQueueError((new String("queue closed", 12)))); }());
  }
  this->iv_data->m_push((new Array({obj})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Queue::m_enq(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  if (truthy(this->iv_closed)) {
    ([&]() -> BasicObject* { throw (new ClosedQueueError((new String("queue closed", 12)))); }());
  }
  this->iv_data->m_push((new Array({obj})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Queue::m_lshift(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  if (truthy(this->iv_closed)) {
    ([&]() -> BasicObject* { throw (new ClosedQueueError((new String("queue closed", 12)))); }());
  }
  this->iv_data->m_push((new Array({obj})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* SizedQueue::m_max(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_max;
  return nil_instance();
}

inline BasicObject* SizedQueue::m_num_waiting(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_waiters->m_size((new Array({})), nullptr, nullptr)->m_plus((new Array({this->iv_push_waiters->m_size((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* SizedQueue::m_max_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* v = array_at(args, 0);
  Proc* _block = block;
  v = this->m___coerce_to_int__((new Array({v})), nullptr, nullptr);
  if (truthy(v->m_le((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("queue size must be positive", 27)))); }());
  }
  return (this->iv_max = v);
  return nil_instance();
}

inline BasicObject* Process_Status::m_success_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_exitstatus((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Process_Status::m_signaled_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_termsig((new Array({})), nullptr, nullptr)->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Process_Status::m_stopped_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return false_instance();
  return nil_instance();
}

inline BasicObject* Process_Status::m_stopsig(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Process_Status::m_coredump_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return false_instance();
  return nil_instance();
}

inline BasicObject* Process_Status::m_exited_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_signaled_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Process_Status::m_to_i(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_exitstatus((new Array({})), nullptr, nullptr)->m_to_i((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Process_Status::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ((new String("", 0))->m_plus((new Array({(new String("#<Process::Status: pid ", 23))})), nullptr, nullptr)->m_plus((new Array({(this->m_pid((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" exit ", 6))})), nullptr, nullptr)->m_plus((new Array({(this->m_exitstatus((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(">", 1))})), nullptr, nullptr));
  return nil_instance();
}

inline BasicObject* Process_Status::m_inspect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_s((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* StringIO::m_lineno(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_lineno;
  return nil_instance();
}

inline BasicObject* StringIO::m_lineno_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* __anon_req__ = array_at(args, 0);
  Proc* _block = block;
  return (this->iv_lineno = __anon_req__);
  return nil_instance();
}

inline BasicObject* StringIO::m_string(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_string;
  return nil_instance();
}

inline BasicObject* StringIO::m_string_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* str = array_at(args, 0);
  Proc* _block = block;
  if (truthy(str->m_respond_to_q((new Array({intern("to_str")})), nullptr, nullptr))) {
    str = str->m_to_str((new Array({})), nullptr, nullptr);
  }
  (this->iv_string = str);
  (this->iv_pos = (new Integer(0LL)));
  (this->iv_lineno = (new Integer(0LL)));
  return str;
  return nil_instance();
}

inline BasicObject* StringIO::m_size(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_string->m_bytesize((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* StringIO::m_length(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_string->m_bytesize((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* StringIO::m_pos(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_pos;
  return nil_instance();
}

inline BasicObject* StringIO::m_pos_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = array_at(args, 0);
  Proc* _block = block;
  n = this->m___coerce_to_int__((new Array({n})), nullptr, nullptr);
  if (truthy(n->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new Errno_EINVAL((new String("Invalid argument", 16)))); }());
  }
  return (this->iv_pos = n);
  return nil_instance();
}

inline BasicObject* StringIO::m_tell(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_pos;
  return nil_instance();
}

inline BasicObject* StringIO::m_rewind(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  (this->iv_pos = (new Integer(0LL)));
  (this->iv_lineno = (new Integer(0LL)));
  return (new Integer(0LL));
  return nil_instance();
}

inline BasicObject* StringIO::m_eof_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  this->m__check_readable((new Array({})), nullptr, nullptr);
  return this->iv_pos->m_ge((new Array({this->iv_string->m_bytesize((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* StringIO::m_eof(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  this->m__check_readable((new Array({})), nullptr, nullptr);
  return this->iv_pos->m_ge((new Array({this->iv_string->m_bytesize((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* StringIO::m_binmode_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_binary;
  return nil_instance();
}

inline BasicObject* StringIO::m_external_encoding(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->iv_external_encoding; return truthy(_l) ? _l : (this->iv_string->m_encoding((new Array({})), nullptr, nullptr)); }());
  return nil_instance();
}

inline BasicObject* StringIO::m_internal_encoding(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_internal_encoding;
  return nil_instance();
}

inline BasicObject* StringIO::m_closed_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->iv_closed_r; return truthy(_l) ? (this->iv_closed_w) : _l; }());
  return nil_instance();
}

inline BasicObject* StringIO::m_closed_read_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->iv_closed_r; return truthy(_l) ? _l : (this->iv_readable->m_not((new Array({})), nullptr, nullptr)); }());
  return nil_instance();
}

inline BasicObject* StringIO::m_closed_write_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->iv_closed_w; return truthy(_l) ? _l : (this->iv_writable->m_not((new Array({})), nullptr, nullptr)); }());
  return nil_instance();
}

inline BasicObject* StringIO::m_close(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  (this->iv_closed_r = true_instance());
  (this->iv_closed_w = true_instance());
  return nil_instance();
  return nil_instance();
}

inline BasicObject* StringIO::m_close_read(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = this->iv_readable; return truthy(_l) ? _l : (this->iv_closed_r); }()))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new IOError((new String("closing non-duplex IO for reading", 33)))); }());
  }
  (this->iv_closed_r = true_instance());
  return nil_instance();
  return nil_instance();
}

inline BasicObject* StringIO::m_close_write(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = this->iv_writable; return truthy(_l) ? _l : (this->iv_closed_w); }()))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new IOError((new String("closing non-duplex IO for writing", 33)))); }());
  }
  (this->iv_closed_w = true_instance());
  return nil_instance();
  return nil_instance();
}

inline BasicObject* StringIO::m_readbyte(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* b = nil_instance();
  this->m__check_readable((new Array({})), nullptr, nullptr);
  if (truthy(this->m_eof_q((new Array({})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new EOFError((new String("end of file reached", 19)))); }());
  }
  b = this->iv_string->m_getbyte((new Array({this->iv_pos})), nullptr, nullptr);
  (this->iv_pos = this->iv_pos->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr));
  return b;
  return nil_instance();
}

inline BasicObject* StringIO::m_readchar(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  this->m__check_readable((new Array({})), nullptr, nullptr);
  if (truthy(this->m_eof_q((new Array({})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new EOFError((new String("end of file reached", 19)))); }());
  }
  return this->m_getc((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* StringIO::m_getc(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* ch = nil_instance();
  BasicObject* byte = nil_instance();
  BasicObject* width = nil_instance();
  this->m__check_readable((new Array({})), nullptr, nullptr);
  if (truthy(this->iv_pos->m_ge((new Array({this->iv_string->m_bytesize((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) {
    return nil_instance();
  }
  ch = ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return this->iv_string->m_aref((new Array({this->iv_pos->m_div((new Array({(new Integer(1LL))})), nullptr, nullptr)})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return nil_instance();  return nil_instance(); }(); } throw; } }());
  byte = this->iv_string->m_getbyte((new Array({this->iv_pos})), nullptr, nullptr);
  if (truthy(byte->m_nil_q((new Array({})), nullptr, nullptr))) {
    return nil_instance();
  }
  width = (truthy(byte->m_lt((new Array({(new Integer(128LL))})), nullptr, nullptr)) ? (((new Integer(1LL)))) : ((truthy(byte->m_lt((new Array({(new Integer(224LL))})), nullptr, nullptr)) ? (((new Integer(2LL)))) : ((truthy(byte->m_lt((new Array({(new Integer(240LL))})), nullptr, nullptr)) ? (((new Integer(3LL)))) : (((new Integer(4LL)))))))));
  ch = ([&]() -> BasicObject* { auto* _l = this->iv_string->m_byteslice((new Array({this->iv_pos, width})), nullptr, nullptr); return truthy(_l) ? _l : ((new String("", 0))); }());
  (this->iv_pos = this->iv_pos->m_plus((new Array({ch->m_bytesize((new Array({})), nullptr, nullptr)})), nullptr, nullptr));
  return ch;
  return nil_instance();
}

inline BasicObject* StringIO::m_getbyte(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* b = nil_instance();
  this->m__check_readable((new Array({})), nullptr, nullptr);
  if (truthy(this->iv_pos->m_ge((new Array({this->iv_string->m_bytesize((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) {
    return nil_instance();
  }
  b = this->iv_string->m_getbyte((new Array({this->iv_pos})), nullptr, nullptr);
  if (truthy(b)) {
    (this->iv_pos = this->iv_pos->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr));
  }
  return b;
  return nil_instance();
}

inline BasicObject* StringIO::m_lshift(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  BasicObject* str = nil_instance();
  this->m__check_writable((new Array({})), nullptr, nullptr);
  str = (truthy(obj->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)) ? ((obj)) : ((obj->m_to_s((new Array({})), nullptr, nullptr))));
  this->m__write_str((new Array({str})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* StringIO::m_putc(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  BasicObject* ch = nil_instance();
  this->m__check_writable((new Array({})), nullptr, nullptr);
  ch = (truthy(obj->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr)) ? (((obj->m_mod((new Array({(new Integer(256LL))})), nullptr, nullptr))->m_chr((new Array({})), nullptr, nullptr))) : ((truthy(obj->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)) ? ((obj->m_aref((new Array({(new Integer(0LL))})), nullptr, nullptr))) : ((truthy(obj->m_respond_to_q((new Array({intern("to_int")})), nullptr, nullptr)) ? (((obj->m_to_int((new Array({})), nullptr, nullptr)->m_mod((new Array({(new Integer(256LL))})), nullptr, nullptr))->m_chr((new Array({})), nullptr, nullptr))) : ((truthy(obj->m_respond_to_q((new Array({intern("to_str")})), nullptr, nullptr)) ? ((obj->m_to_str((new Array({})), nullptr, nullptr)->m_aref((new Array({(new Integer(0LL))})), nullptr, nullptr))) : ((([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of ", 26))})), nullptr, nullptr)->m_plus((new Array({(obj->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into Integer", 13))})), nullptr, nullptr)))); }()))))))))));
  this->m__write_str((new Array({ch})), nullptr, nullptr);
  return obj;
  return nil_instance();
}

inline BasicObject* StringIO::m_truncate(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* len = array_at(args, 0);
  Proc* _block = block;
  BasicObject* cur = nil_instance();
  this->m__check_writable((new Array({})), nullptr, nullptr);
  len = this->m___coerce_to_int__((new Array({len})), nullptr, nullptr);
  if (truthy(len->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new Errno_EINVAL((new String("Invalid argument - negative length", 34)))); }());
  }
  cur = this->iv_string->m_bytesize((new Array({})), nullptr, nullptr);
  if (truthy(len->m_lt((new Array({cur})), nullptr, nullptr))) {
    this->iv_string->m_replace((new Array({([&]() -> BasicObject* { auto* _l = this->iv_string->m_byteslice((new Array({(new Integer(0LL)), len})), nullptr, nullptr); return truthy(_l) ? _l : ((new String("", 0))); }())})), nullptr, nullptr);
  } else {
    if (truthy(len->m_gt((new Array({cur})), nullptr, nullptr))) {
      this->iv_string->m_lshift((new Array({((new String("\0", 1))->m_mul((new Array({(len->m_minus((new Array({cur})), nullptr, nullptr))})), nullptr, nullptr))})), nullptr, nullptr);
    }
  }
  return len;
  return nil_instance();
}

inline BasicObject* StringIO::m_bytes(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_each_byte((new Array({})), nullptr, nullptr)->m_to_a((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* StringIO::m_chars(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_each_char((new Array({})), nullptr, nullptr)->m_to_a((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* StringIO::m_lines(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_each_line(static_cast<Array*>(args), nullptr, nullptr)->m_to_a((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* StringIO::m_codepoints(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_each_codepoint((new Array({})), nullptr, nullptr)->m_to_a((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* StringIO::m_each_byte(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* b = nil_instance();
  this->m__check_readable((new Array({})), nullptr, nullptr);
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_enum_for((new Array({intern("each_byte")})), nullptr, nullptr);
  }
  while (truthy(((b = this->m_getbyte((new Array({})), nullptr, nullptr))))) {
    block->m_call((new Array({b})), nullptr, nullptr);
  }
  return this;
  return nil_instance();
}

inline BasicObject* StringIO::m_each_char(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* ch = nil_instance();
  this->m__check_readable((new Array({})), nullptr, nullptr);
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_enum_for((new Array({intern("each_char")})), nullptr, nullptr);
  }
  while (truthy(((ch = this->m_getc((new Array({})), nullptr, nullptr))))) {
    block->m_call((new Array({ch})), nullptr, nullptr);
  }
  return this;
  return nil_instance();
}

inline BasicObject* StringIO::m_each_codepoint(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  this->m__check_readable((new Array({})), nullptr, nullptr);
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_enum_for((new Array({intern("each_codepoint")})), nullptr, nullptr);
  }
  this->m_each_char((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* ch = arg; return block->m_call((new Array({ch->m_ord((new Array({})), nullptr, nullptr)})), nullptr, nullptr); })));
  return this;
  return nil_instance();
}

inline BasicObject* StringIO::m_readpartial(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* length = array_at(args, 0);
  BasicObject* buffer = (args->data.size() > 1) ? args->data[1] : (nil_instance());
  Proc* _block = block;
  BasicObject* buf_enc = nil_instance();
  BasicObject* ret = nil_instance();
  BasicObject* data = nil_instance();
  BasicObject* saved_enc = nil_instance();
  this->m__check_readable((new Array({})), nullptr, nullptr);
  if (truthy(([&]() -> BasicObject* { auto* _l = length->m_respond_to_q((new Array({intern("to_int")})), nullptr, nullptr); return truthy(_l) ? (length->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr)) : _l; }()))) {
    length = length->m_to_int((new Array({})), nullptr, nullptr);
  } else {
    if (truthy(length->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr))) {
      ([&]() -> BasicObject* { throw (new TypeError((new String("no implicit conversion into Integer", 35)))); }());
    }
  }
  if (truthy(length->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new ArgumentError(((new String("", 0))->m_plus((new Array({(new String("negative length ", 16))})), nullptr, nullptr)->m_plus((new Array({(length)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" given", 6))})), nullptr, nullptr)))); }());
  }
  buf_enc = nil_instance();
  if (truthy(buffer)) {
    if (truthy(buffer->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr))) {
      buf_enc = ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return buffer->m_encoding((new Array({})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return nil_instance();  return nil_instance(); }(); } throw; } }());
    } else {
      if (truthy(buffer->m_respond_to_q((new Array({intern("to_str")})), nullptr, nullptr))) {
        buffer = buffer->m_to_str((new Array({})), nullptr, nullptr);
        buf_enc = ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return buffer->m_encoding((new Array({})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return nil_instance();  return nil_instance(); }(); } throw; } }());
      } else {
        ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of ", 26))})), nullptr, nullptr)->m_plus((new Array({(buffer->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into String", 12))})), nullptr, nullptr)))); }());
      }
    }
  }
  if (truthy(length->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
    if (truthy(buffer)) {
      ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return buffer->m_replace((new Array({(new String("", 0))})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return nil_instance();  return nil_instance(); }(); } throw; } }());
    }
    ret = ([&]() -> BasicObject* { auto* _l = buffer; return truthy(_l) ? _l : ((new String("", 0))); }());
    if (truthy(([&]() -> BasicObject* { auto* _l = buf_enc; return truthy(_l) ? (ret->m_respond_to_q((new Array({intern("force_encoding")})), nullptr, nullptr)) : _l; }()))) {
      ret->m_force_encoding((new Array({buf_enc})), nullptr, nullptr);
    }
    return ret;
  }
  if (truthy(this->iv_pos->m_ge((new Array({this->iv_string->m_bytesize((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) {
    if (truthy(buffer)) {
      ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return buffer->m_replace((new Array({(new String("", 0))})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return nil_instance();  return nil_instance(); }(); } throw; } }());
    }
    ([&]() -> BasicObject* { throw (new EOFError((new String("end of file reached", 19)))); }());
  }
  data = ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return (([&]() -> BasicObject* { auto* _l = this->iv_string->m_byteslice((new Array({this->iv_pos, length})), nullptr, nullptr); return truthy(_l) ? _l : ((new String("", 0))); }()))->m_b((new Array({})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return ([&]() -> BasicObject* { auto* _l = this->iv_string->m_byteslice((new Array({this->iv_pos, length})), nullptr, nullptr); return truthy(_l) ? _l : ((new String("", 0))); }());  return nil_instance(); }(); } throw; } }());
  (this->iv_pos = this->iv_pos->m_plus((new Array({data->m_bytesize((new Array({})), nullptr, nullptr)})), nullptr, nullptr));
  if (truthy(buffer)) {
    saved_enc = buf_enc;
    ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return buffer->m_replace((new Array({data})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return nil_instance();  return nil_instance(); }(); } throw; } }());
    if (truthy(([&]() -> BasicObject* { auto* _l = saved_enc; return truthy(_l) ? (buffer->m_respond_to_q((new Array({intern("force_encoding")})), nullptr, nullptr)) : _l; }()))) {
      buffer->m_force_encoding((new Array({saved_enc})), nullptr, nullptr);
    }
    return buffer;
  }
  return data;
  return nil_instance();
}

inline BasicObject* StringIO::m_flush(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* StringIO::m_sync(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return true_instance();
  return nil_instance();
}

inline BasicObject* StringIO::m_sync_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* _v = array_at(args, 0);
  Proc* _block = block;
  return true_instance();
  return nil_instance();
}

inline BasicObject* StringIO::m_fsync(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Integer(0LL));
  return nil_instance();
}

inline BasicObject* StringIO::m_fileno(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* StringIO::m_isatty(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return false_instance();
  return nil_instance();
}

inline BasicObject* StringIO::m_tty_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return false_instance();
  return nil_instance();
}

inline BasicObject* StringIO::m_pid(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* StringIO::m_fcntl(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* _ = args;  // *rest = whole args
  Proc* _block = block;
  return ([&]() -> BasicObject* { throw (new NotImplementedError((new String("fcntl not supported", 19)))); }());
  return nil_instance();
}

inline BasicObject* StringIO::m_ioctl(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* _ = args;  // *rest = whole args
  Proc* _block = block;
  return ([&]() -> BasicObject* { throw (new Errno_EBADF((new String("Bad file descriptor", 19)))); }());
  return nil_instance();
}

inline BasicObject* StringIO::m_stat(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { throw (new Errno_EBADF((new String("Bad file descriptor", 19)))); }());
  return nil_instance();
}

inline BasicObject* StringIO::m_to_io(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this;
  return nil_instance();
}

inline BasicObject* StringIO::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ((new String("", 0))->m_plus((new Array({(new String("#<StringIO:0x", 13))})), nullptr, nullptr)->m_plus((new Array({(this->m_object_id((new Array({})), nullptr, nullptr)->m_to_s((new Array({(new Integer(16LL))})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(">", 1))})), nullptr, nullptr));
  return nil_instance();
}

inline BasicObject* StringIO::m_inspect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_s((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* StringIO::m_readable_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->iv_readable; return truthy(_l) ? (this->iv_closed_r->m_not((new Array({})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* StringIO::m_writable_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->iv_writable; return truthy(_l) ? (this->iv_closed_w->m_not((new Array({})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline BasicObject* StringIO::m_readable_real_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_readable_q((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* StringIO::m_writable_real_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_writable_q((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* StringIO::m__check_open(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->m_closed_q((new Array({})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new IOError((new String("closed stream", 13)))); }());
  }
  return nil_instance();
}

inline BasicObject* StringIO::m__check_readable(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = this->iv_closed_r; return truthy(_l) ? _l : (this->iv_readable->m_not((new Array({})), nullptr, nullptr)); }()))) {
    ([&]() -> BasicObject* { throw (new IOError((new String("not opened for reading", 22)))); }());
  }
  return nil_instance();
}

inline BasicObject* StringIO::m__check_writable(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = this->iv_closed_w; return truthy(_l) ? _l : (this->iv_writable->m_not((new Array({})), nullptr, nullptr)); }()))) {
    ([&]() -> BasicObject* { throw (new IOError((new String("not opened for writing", 22)))); }());
  }
  return (truthy(this->iv_string->m_frozen_q((new Array({})), nullptr, nullptr)) ? ((([&]() -> BasicObject* { throw (new Errno_EACCES((new String("Permission denied", 17)))); }()))) : (nil_instance()));
  return nil_instance();
}

inline BasicObject* StringIO::m__chomp(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* str = array_at(args, 0);
  BasicObject* sep = array_at(args, 1);
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = sep->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (sep->m_eq_q((new Array({(new String("", 0))})), nullptr, nullptr)); }()); return truthy(_l) ? _l : (sep->m_eq_q((new Array({(new String("\n", 1))})), nullptr, nullptr)); }()))) {
    return str->m_chomp((new Array({})), nullptr, nullptr);
  }
  return (truthy(str->m_end_with_q((new Array({sep})), nullptr, nullptr)) ? ((str->m_aref((new Array({(new Integer(0LL)), str->m_length((new Array({})), nullptr, nullptr)->m_minus((new Array({sep->m_length((new Array({})), nullptr, nullptr)})), nullptr, nullptr)})), nullptr, nullptr))) : ((str)));
  return nil_instance();
}

inline BasicObject* Struct::m_members(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->m_class((new Array({})), nullptr, nullptr)->m_members((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : ((new Array({}))); }());
  return nil_instance();
}

inline BasicObject* Struct::m_to_a(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_members((new Array({})), nullptr, nullptr)->m_map((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* m = arg; return this->iv_struct_values->m_fetch((new Array({m, nil_instance()})), nullptr, nullptr); })));
  return nil_instance();
}

inline BasicObject* Struct::m_values(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_to_a((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Struct::m_size(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_members((new Array({})), nullptr, nullptr)->m_size((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Struct::m_length(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_members((new Array({})), nullptr, nullptr)->m_size((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Struct::m_deconstruct(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_members((new Array({})), nullptr, nullptr)->m_map((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* m = arg; return this->iv_struct_values->m_fetch((new Array({m, nil_instance()})), nullptr, nullptr); })));
  return nil_instance();
}

inline BasicObject* Struct::m_aref(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* name_or_idx = array_at(args, 0);
  Proc* _block = block;
  BasicObject* mems = nil_instance();
  BasicObject* idx = nil_instance();
  BasicObject* name = nil_instance();
  mems = this->m_members((new Array({})), nullptr, nullptr);
  return (truthy(name_or_idx->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr)) ? (((idx = (truthy(name_or_idx->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((mems->m_size((new Array({})), nullptr, nullptr)->m_plus((new Array({name_or_idx})), nullptr, nullptr))) : ((name_or_idx)))), (truthy(idx->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((([&]() -> BasicObject* { throw (new IndexError(((new String("", 0))->m_plus((new Array({(new String("offset ", 7))})), nullptr, nullptr)->m_plus((new Array({(name_or_idx)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" too small for struct(size:", 27))})), nullptr, nullptr)->m_plus((new Array({(mems->m_size((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(")", 1))})), nullptr, nullptr)))); }()))) : (nil_instance())), (truthy(idx->m_ge((new Array({mems->m_size((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) ? ((([&]() -> BasicObject* { throw (new IndexError(((new String("", 0))->m_plus((new Array({(new String("offset ", 7))})), nullptr, nullptr)->m_plus((new Array({(name_or_idx)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" too large for struct(size:", 27))})), nullptr, nullptr)->m_plus((new Array({(mems->m_size((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(")", 1))})), nullptr, nullptr)))); }()))) : (nil_instance())), this->iv_struct_values->m_fetch((new Array({mems->m_aref((new Array({idx})), nullptr, nullptr), nil_instance()})), nullptr, nullptr))) : ((truthy(([&]() -> BasicObject* { auto* _l = name_or_idx->m_is_a_q((new Array({(&Symbol_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (name_or_idx->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)); }())) ? (((name = name_or_idx->m_to_sym((new Array({})), nullptr, nullptr)), (truthy(mems->m_include_q((new Array({name})), nullptr, nullptr)) ? (nil_instance()) : ((([&]() -> BasicObject* { throw (new NameError(((new String("", 0))->m_plus((new Array({(new String("no member '", 11))})), nullptr, nullptr)->m_plus((new Array({(name_or_idx)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String("' in struct", 11))})), nullptr, nullptr)))); }())))), this->iv_struct_values->m_fetch((new Array({name, nil_instance()})), nullptr, nullptr))) : ((([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of ", 26))})), nullptr, nullptr)->m_plus((new Array({(name_or_idx->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into Integer", 13))})), nullptr, nullptr)))); }()))))));
  return nil_instance();
}

inline BasicObject* Struct::m_aset(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* name_or_idx = array_at(args, 0);
  BasicObject* val = array_at(args, 1);
  Proc* _block = block;
  BasicObject* mems = nil_instance();
  BasicObject* idx = nil_instance();
  BasicObject* name = nil_instance();
  this->m___check_frozen__((new Array({})), nullptr, nullptr);
  mems = this->m_members((new Array({})), nullptr, nullptr);
  if (truthy(name_or_idx->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr))) {
    idx = (truthy(name_or_idx->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? ((mems->m_size((new Array({})), nullptr, nullptr)->m_plus((new Array({name_or_idx})), nullptr, nullptr))) : ((name_or_idx)));
    if (truthy(idx->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
      ([&]() -> BasicObject* { throw (new IndexError(((new String("", 0))->m_plus((new Array({(new String("offset ", 7))})), nullptr, nullptr)->m_plus((new Array({(name_or_idx)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" too small for struct(size:", 27))})), nullptr, nullptr)->m_plus((new Array({(mems->m_size((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(")", 1))})), nullptr, nullptr)))); }());
    }
    if (truthy(idx->m_ge((new Array({mems->m_size((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) {
      ([&]() -> BasicObject* { throw (new IndexError(((new String("", 0))->m_plus((new Array({(new String("offset ", 7))})), nullptr, nullptr)->m_plus((new Array({(name_or_idx)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" too large for struct(size:", 27))})), nullptr, nullptr)->m_plus((new Array({(mems->m_size((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(")", 1))})), nullptr, nullptr)))); }());
    }
    (([&]() -> BasicObject* { auto* _l = this->iv_struct_values; return truthy(_l) ? _l : ((this->iv_struct_values = (new Hash({})))); }()))->m_aset((new Array({mems->m_aref((new Array({idx})), nullptr, nullptr), val})), nullptr, nullptr);
  } else {
    if (truthy(([&]() -> BasicObject* { auto* _l = name_or_idx->m_is_a_q((new Array({(&Symbol_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (name_or_idx->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)); }()))) {
      name = name_or_idx->m_to_sym((new Array({})), nullptr, nullptr);
      if (truthy(mems->m_include_q((new Array({name})), nullptr, nullptr))) {
        nil_instance();
      } else {
        ([&]() -> BasicObject* { throw (new NameError(((new String("", 0))->m_plus((new Array({(new String("no member '", 11))})), nullptr, nullptr)->m_plus((new Array({(name_or_idx)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String("' in struct", 11))})), nullptr, nullptr)))); }());
      }
      (([&]() -> BasicObject* { auto* _l = this->iv_struct_values; return truthy(_l) ? _l : ((this->iv_struct_values = (new Hash({})))); }()))->m_aset((new Array({name, val})), nullptr, nullptr);
    } else {
      ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of ", 26))})), nullptr, nullptr)->m_plus((new Array({(name_or_idx->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into Integer", 13))})), nullptr, nullptr)))); }());
    }
  }
  return val;
  return nil_instance();
}

inline BasicObject* Struct::m_each(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("each")})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { return this->m_size((new Array({})), nullptr, nullptr); })));
  }
  this->m_to_a((new Array({})), nullptr, nullptr)->m_each((new Array({})), nullptr, static_cast<Proc*>(block));
  return this;
  return nil_instance();
}

inline BasicObject* Struct::m_each_pair(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("each_pair")})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { return this->m_size((new Array({})), nullptr, nullptr); })));
  }
  this->m_members((new Array({})), nullptr, nullptr)->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* m = arg; return block->m_call((new Array({(new Array({m, this->iv_struct_values->m_fetch((new Array({m, nil_instance()})), nullptr, nullptr)}))})), nullptr, nullptr); })));
  return this;
  return nil_instance();
}

inline BasicObject* Struct::m_dig(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* key = array_at(args, 0);
  Array* rest = new Array();
  for (std::size_t _i = 1; _i < args->data.size(); _i++) {
    rest->data.push_back(args->data[_i]);
  }
  Proc* _block = block;
  BasicObject* val = nil_instance();
  val = ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return this->m_aref((new Array({key})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<NameError*>(e_) != nullptr || dynamic_cast<TypeError*>(e_) != nullptr) { return [&]() -> BasicObject* { return nil_instance();  return nil_instance(); }(); } throw; } }());
  if (truthy(([&]() -> BasicObject* { auto* _l = rest->m_empty_q((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (val->m_nil_q((new Array({})), nullptr, nullptr)); }()))) {
    return val;
  }
  if (truthy(val->m_respond_to_q((new Array({intern("dig")})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(val->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" does not have #dig method", 26))})), nullptr, nullptr)))); }());
  }
  return val->m_dig(static_cast<Array*>(rest), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Data::m_members(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_class((new Array({})), nullptr, nullptr)->m_members((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Data::m_deconstruct(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_class((new Array({})), nullptr, nullptr)->m_members((new Array({})), nullptr, nullptr)->m_map((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* m = arg; return this->iv_data_values->m_aref((new Array({m})), nullptr, nullptr); })));
  return nil_instance();
}

inline BasicObject* Data::m_eql_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({this->m_class((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return false_instance();
  }
  return this->m_class((new Array({})), nullptr, nullptr)->m_members((new Array({})), nullptr, nullptr)->m_all_q((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* m = arg; return this->iv_data_values->m_aref((new Array({m})), nullptr, nullptr)->m_eql_q((new Array({other->m___send__((new Array({m})), nullptr, nullptr)})), nullptr, nullptr); })));
  return nil_instance();
}

inline BasicObject* Set::m_include_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  return this->iv_hash->m_key_q((new Array({obj})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_member_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  return this->iv_hash->m_key_q((new Array({obj})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_case_eq(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  return this->iv_hash->m_key_q((new Array({obj})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_size(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_hash->m_size((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_length(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_hash->m_size((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_empty_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_hash->m_empty_q((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_to_a(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_hash->m_keys((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_eql_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return this->m_eq_q((new Array({other})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_disjoint_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  return this->m_intersect_q((new Array({other})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_join(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* sep = (args->data.size() > 0) ? args->data[0] : (nil_instance());
  Proc* _block = block;
  return this->m_to_a((new Array({})), nullptr, nullptr)->m_join((new Array({sep})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_compare_by_identity_q(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_hash->m_compare_by_identity_q((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_pretty_print(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* pp = array_at(args, 0);
  Proc* _block = block;
  return pp->m_text((new Array({this->m_inspect((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_pretty_print_cycle(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* pp = array_at(args, 0);
  Proc* _block = block;
  return pp->m_text((new Array({(new String("Set[...]", 8))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_add(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  if (truthy(this->iv_iterating)) {
    ([&]() -> BasicObject* { throw (new RuntimeError((new String("can't add to set during iteration", 33)))); }());
  }
  this->iv_hash->m_aset((new Array({obj, true_instance()})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Set::m_lshift(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  if (truthy(this->iv_iterating)) {
    ([&]() -> BasicObject* { throw (new RuntimeError((new String("can't add to set during iteration", 33)))); }());
  }
  this->iv_hash->m_aset((new Array({obj, true_instance()})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Set::m_add_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  if (truthy(this->m_include_q((new Array({obj})), nullptr, nullptr))) {
    return nil_instance();
  }
  this->m_add((new Array({obj})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Set::m_delete(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  this->iv_hash->m_delete((new Array({obj})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Set::m_delete_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  if (truthy(this->m_include_q((new Array({obj})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return nil_instance();
  }
  this->m_delete((new Array({obj})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Set::m_delete_if(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->m_block_given_q((new Array({})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("delete_if")})), nullptr, nullptr);
  }
  this->m_to_a((new Array({})), nullptr, nullptr)->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return (truthy(_block->m_call((new Array({x})), nullptr, nullptr)) ? ((this->m_delete((new Array({x})), nullptr, nullptr))) : (nil_instance())); })));
  return this;
  return nil_instance();
}

inline BasicObject* Set::m_keep_if(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->m_block_given_q((new Array({})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("keep_if")})), nullptr, nullptr);
  }
  this->m_to_a((new Array({})), nullptr, nullptr)->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return (truthy(_block->m_call((new Array({x})), nullptr, nullptr)) ? (nil_instance()) : ((this->m_delete((new Array({x})), nullptr, nullptr)))); })));
  return this;
  return nil_instance();
}

inline BasicObject* Set::m_select_b(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* n = nil_instance();
  if (truthy(this->m_block_given_q((new Array({})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("select!")})), nullptr, nullptr);
  }
  n = this->m_size((new Array({})), nullptr, nullptr);
  this->m_keep_if((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return _block->m_call((new Array({x})), nullptr, nullptr); })));
  return (truthy(this->m_size((new Array({})), nullptr, nullptr)->m_eq_q((new Array({n})), nullptr, nullptr)) ? ((nil_instance())) : ((this)));
  return nil_instance();
}

inline BasicObject* Set::m_filter_b(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* n = nil_instance();
  if (truthy(this->m_block_given_q((new Array({})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("select!")})), nullptr, nullptr);
  }
  n = this->m_size((new Array({})), nullptr, nullptr);
  this->m_keep_if((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return _block->m_call((new Array({x})), nullptr, nullptr); })));
  return (truthy(this->m_size((new Array({})), nullptr, nullptr)->m_eq_q((new Array({n})), nullptr, nullptr)) ? ((nil_instance())) : ((this)));
  return nil_instance();
}

inline BasicObject* Set::m_reject_b(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* n = nil_instance();
  if (truthy(this->m_block_given_q((new Array({})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("reject!")})), nullptr, nullptr);
  }
  n = this->m_size((new Array({})), nullptr, nullptr);
  this->m_delete_if((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return _block->m_call((new Array({x})), nullptr, nullptr); })));
  return (truthy(this->m_size((new Array({})), nullptr, nullptr)->m_eq_q((new Array({n})), nullptr, nullptr)) ? ((nil_instance())) : ((this)));
  return nil_instance();
}

inline BasicObject* Set::m_each(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(block)) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("each")})), nullptr, nullptr);
  }
  if (truthy(this->m_frozen_q((new Array({})), nullptr, nullptr))) {
    this->iv_hash->m_each_key((new Array({})), nullptr, static_cast<Proc*>(block));
    return this;
  }
  (this->iv_iterating = true_instance());
  ([&]() -> BasicObject* { EnsureGuard _eg([&]() { (this->iv_iterating = false_instance());  return nil_instance(); }); try { return [&]() -> BasicObject* { return this->iv_hash->m_each_key((new Array({})), nullptr, static_cast<Proc*>(block));  return nil_instance(); }(); } catch (Exception* e_) { throw; } }());
  return this;
  return nil_instance();
}

inline BasicObject* Set::m_clear(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  this->iv_hash->m_clear((new Array({})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Set::m_collect_b(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* new_vals = nil_instance();
  if (truthy(this->m_block_given_q((new Array({})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("collect!")})), nullptr, nullptr);
  }
  new_vals = this->m_to_a((new Array({})), nullptr, nullptr)->m_map((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return _block->m_call((new Array({x})), nullptr, nullptr); })));
  this->m_clear((new Array({})), nullptr, nullptr);
  new_vals->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return this->m_add((new Array({x})), nullptr, nullptr); })));
  return this;
  return nil_instance();
}

inline BasicObject* Set::m_map_b(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* new_vals = nil_instance();
  if (truthy(this->m_block_given_q((new Array({})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return this->m_to_enum((new Array({intern("collect!")})), nullptr, nullptr);
  }
  new_vals = this->m_to_a((new Array({})), nullptr, nullptr)->m_map((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return _block->m_call((new Array({x})), nullptr, nullptr); })));
  this->m_clear((new Array({})), nullptr, nullptr);
  new_vals->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return this->m_add((new Array({x})), nullptr, nullptr); })));
  return this;
  return nil_instance();
}

inline BasicObject* Set::m_flatten(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* result = nil_instance();
  result = this->m_class((new Array({})), nullptr, nullptr)->m_new((new Array({})), nullptr, nullptr);
  this->m___do_flatten__((new Array({result, (new Hash({}))})), nullptr, nullptr);
  return result;
  return nil_instance();
}

inline BasicObject* Set::m_flatten_b(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->m_any_q((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return x->m_is_a_q((new Array({(&Set_CLASS)})), nullptr, nullptr); }))))) {
    nil_instance();
  } else {
    return nil_instance();
  }
  this->m_replace((new Array({this->m_flatten((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Set::m_eq_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&Set_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return false_instance();
  }
  if (truthy(this->m_equal_q((new Array({other})), nullptr, nullptr))) {
    return true_instance();
  }
  if (truthy(this->m_compare_by_identity_q((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_compare_by_identity_q((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return false_instance();
  }
  if (truthy(this->m_size((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_size((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return false_instance();
  }
  return this->m_all_q((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return other->m_include_q((new Array({x})), nullptr, nullptr); })));
  return nil_instance();
}

inline BasicObject* Set::m_spaceship(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&Set_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return nil_instance();
  }
  return (truthy(this->m_size((new Array({})), nullptr, nullptr)->m_lt((new Array({other->m_size((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) ? (((truthy(this->m_subset_q((new Array({other})), nullptr, nullptr)) ? (((new Integer(-1LL)))) : ((nil_instance()))))) : ((truthy(this->m_size((new Array({})), nullptr, nullptr)->m_gt((new Array({other->m_size((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) ? (((truthy(this->m_superset_q((new Array({other})), nullptr, nullptr)) ? (((new Integer(1LL)))) : ((nil_instance()))))) : (((truthy(this->m_eq_q((new Array({other})), nullptr, nullptr)) ? (((new Integer(0LL)))) : ((nil_instance()))))))));
  return nil_instance();
}

inline BasicObject* Set::m_bit_and(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_respond_to_q((new Array({intern("each")})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("value must be a set", 19)))); }());
  }
  return this->m_class((new Array({})), nullptr, nullptr)->m_new((new Array({this->m_select((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return other->m_include_q((new Array({x})), nullptr, nullptr); })))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_intersection(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_respond_to_q((new Array({intern("each")})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("value must be a set", 19)))); }());
  }
  return this->m_class((new Array({})), nullptr, nullptr)->m_new((new Array({this->m_select((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return other->m_include_q((new Array({x})), nullptr, nullptr); })))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_bit_or(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  BasicObject* r = nil_instance();
  if (truthy(other->m_respond_to_q((new Array({intern("each")})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("value must be a set", 19)))); }());
  }
  r = this->m_dup((new Array({})), nullptr, nullptr);
  other->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return r->m_add((new Array({x})), nullptr, nullptr); })));
  return r;
  return nil_instance();
}

inline BasicObject* Set::m_union(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  BasicObject* r = nil_instance();
  if (truthy(other->m_respond_to_q((new Array({intern("each")})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("value must be a set", 19)))); }());
  }
  r = this->m_dup((new Array({})), nullptr, nullptr);
  other->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return r->m_add((new Array({x})), nullptr, nullptr); })));
  return r;
  return nil_instance();
}

inline BasicObject* Set::m_plus(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  BasicObject* r = nil_instance();
  if (truthy(other->m_respond_to_q((new Array({intern("each")})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("value must be a set", 19)))); }());
  }
  r = this->m_dup((new Array({})), nullptr, nullptr);
  other->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return r->m_add((new Array({x})), nullptr, nullptr); })));
  return r;
  return nil_instance();
}

inline BasicObject* Set::m_minus(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_respond_to_q((new Array({intern("each")})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("value must be a set", 19)))); }());
  }
  return this->m_class((new Array({})), nullptr, nullptr)->m_new((new Array({this->m_reject((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return other->m_include_q((new Array({x})), nullptr, nullptr); })))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_difference(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_respond_to_q((new Array({intern("each")})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("value must be a set", 19)))); }());
  }
  return this->m_class((new Array({})), nullptr, nullptr)->m_new((new Array({this->m_reject((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return other->m_include_q((new Array({x})), nullptr, nullptr); })))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_bit_xor(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_respond_to_q((new Array({intern("each")})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("value must be a set", 19)))); }());
  }
  return (this->m_bit_or((new Array({other})), nullptr, nullptr))->m_minus((new Array({(this->m_bit_and((new Array({other})), nullptr, nullptr))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Set::m_subset_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&Set_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("value must be a set", 19)))); }());
  }
  return ([&]() -> BasicObject* { auto* _l = this->m_size((new Array({})), nullptr, nullptr)->m_le((new Array({other->m_size((new Array({})), nullptr, nullptr)})), nullptr, nullptr); return truthy(_l) ? (this->m_all_q((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return other->m_include_q((new Array({x})), nullptr, nullptr); })))) : _l; }());
  return nil_instance();
}

inline BasicObject* Set::m_proper_subset_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&Set_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("value must be a set", 19)))); }());
  }
  return ([&]() -> BasicObject* { auto* _l = this->m_size((new Array({})), nullptr, nullptr)->m_lt((new Array({other->m_size((new Array({})), nullptr, nullptr)})), nullptr, nullptr); return truthy(_l) ? (this->m_all_q((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return other->m_include_q((new Array({x})), nullptr, nullptr); })))) : _l; }());
  return nil_instance();
}

inline BasicObject* Set::m_superset_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&Set_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("value must be a set", 19)))); }());
  }
  return ([&]() -> BasicObject* { auto* _l = this->m_size((new Array({})), nullptr, nullptr)->m_ge((new Array({other->m_size((new Array({})), nullptr, nullptr)})), nullptr, nullptr); return truthy(_l) ? (other->m_all_q((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return this->m_include_q((new Array({x})), nullptr, nullptr); })))) : _l; }());
  return nil_instance();
}

inline BasicObject* Set::m_proper_superset_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&Set_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("value must be a set", 19)))); }());
  }
  return ([&]() -> BasicObject* { auto* _l = this->m_size((new Array({})), nullptr, nullptr)->m_gt((new Array({other->m_size((new Array({})), nullptr, nullptr)})), nullptr, nullptr); return truthy(_l) ? (other->m_all_q((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return this->m_include_q((new Array({x})), nullptr, nullptr); })))) : _l; }());
  return nil_instance();
}

inline BasicObject* Set::m_intersect_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&Set_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("value must be a set", 19)))); }());
  }
  return (truthy(this->m_size((new Array({})), nullptr, nullptr)->m_lt((new Array({other->m_size((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) ? ((this->m_any_q((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return other->m_include_q((new Array({x})), nullptr, nullptr); }))))) : ((other->m_any_q((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return this->m_include_q((new Array({x})), nullptr, nullptr); }))))));
  return nil_instance();
}

inline BasicObject* Set::m_compare_by_identity(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  this->m___check_frozen__((new Array({})), nullptr, nullptr);
  this->iv_hash->m_compare_by_identity((new Array({})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* Set::m_dup(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* s = nil_instance();
  s = this->m_class((new Array({})), nullptr, nullptr)->m_new((new Array({this})), nullptr, nullptr);
  if (truthy(this->m_compare_by_identity_q((new Array({})), nullptr, nullptr))) {
    s->m_compare_by_identity((new Array({})), nullptr, nullptr);
  }
  return s;
  return nil_instance();
}

inline BasicObject* Set::m___do_flatten__(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* result = array_at(args, 0);
  BasicObject* seen = array_at(args, 1);
  Proc* _block = block;
  if (truthy(seen->m_key_q((new Array({this->m_object_id((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("tried to flatten recursive Set", 30)))); }());
  }
  seen->m_aset((new Array({this->m_object_id((new Array({})), nullptr, nullptr), true_instance()})), nullptr, nullptr);
  this->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* x = arg; return (truthy(x->m_is_a_q((new Array({(&Set_CLASS)})), nullptr, nullptr)) ? ((x->m___do_flatten__((new Array({result, seen})), nullptr, nullptr))) : ((result->m_add((new Array({x})), nullptr, nullptr)))); })));
  return seen->m_delete((new Array({this->m_object_id((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Random::m_eq_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&Random_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return false_instance();
  }
  return ([&]() -> BasicObject* { auto* _l = this->m_seed((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_seed((new Array({})), nullptr, nullptr)})), nullptr, nullptr); return truthy(_l) ? (this->m_state((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_state((new Array({})), nullptr, nullptr)})), nullptr, nullptr)) : _l; }());
  return nil_instance();
}

inline ObjectSpace_WeakMap::ObjectSpace_WeakMap() {
  (this->iv_pairs = (new Array({})));
}

inline BasicObject* ObjectSpace_WeakMap::m_size(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_pairs->m_size((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* ObjectSpace_WeakMap::m_length(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_pairs->m_size((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* ObjectSpace_WeakMap::m__weakmap_inspect_obj(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  return ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return obj->m_inspect((new Array({})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<NoMethodError*>(e_) != nullptr) { return [&]() -> BasicObject* { return ((new String("", 0))->m_plus((new Array({(new String("#<BasicObject:0x", 16))})), nullptr, nullptr)->m_plus((new Array({(obj->m___id__((new Array({})), nullptr, nullptr)->m_to_s((new Array({(new Integer(16LL))})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(">", 1))})), nullptr, nullptr));  return nil_instance(); }(); } throw; } }());
  return nil_instance();
}

inline ObjectSpace_WeakKeyMap::ObjectSpace_WeakKeyMap() {
  (this->iv_pairs = (new Array({})));
}

inline BasicObject* ObjectSpace_WeakKeyMap::m_inspect(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ((new String("", 0))->m_plus((new Array({(new String("#<ObjectSpace::WeakKeyMap:0x", 28))})), nullptr, nullptr)->m_plus((new Array({(this->m_object_id((new Array({})), nullptr, nullptr)->m_to_s((new Array({(new Integer(16LL))})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" size=", 6))})), nullptr, nullptr)->m_plus((new Array({(this->iv_pairs->m_size((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(">", 1))})), nullptr, nullptr));
  return nil_instance();
}

inline BasicObject* ObjectSpace_WeakKeyMap::m_aset(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* key = array_at(args, 0);
  BasicObject* value = array_at(args, 1);
  Proc* _block = block;
  BasicObject* idx = nil_instance();
  this->m___check_key___b((new Array({key})), nullptr, nullptr);
  idx = this->m___find_index__((new Array({key})), nullptr, nullptr);
  if (truthy(idx)) {
    this->iv_pairs->m_aref((new Array({idx})), nullptr, nullptr)->m_aset((new Array({(new Integer(1LL)), value})), nullptr, nullptr);
  } else {
    this->iv_pairs->m_lshift((new Array({(new Array({key, value}))})), nullptr, nullptr);
  }
  return value;
  return nil_instance();
}

inline BasicObject* ObjectSpace_WeakKeyMap::m_aref(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* key = array_at(args, 0);
  Proc* _block = block;
  BasicObject* pair = nil_instance();
  if (truthy(this->m___ungcable___q((new Array({key})), nullptr, nullptr))) {
    return nil_instance();
  }
  pair = this->m___find_pair__((new Array({key})), nullptr, nullptr);
  return (truthy(pair) ? ((pair->m_aref((new Array({(new Integer(1LL))})), nullptr, nullptr))) : ((nil_instance())));
  return nil_instance();
}

inline BasicObject* ObjectSpace_WeakKeyMap::m_key_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* key = array_at(args, 0);
  Proc* _block = block;
  if (truthy(this->m___ungcable___q((new Array({key})), nullptr, nullptr))) {
    return false_instance();
  }
  return this->m___find_pair__((new Array({key})), nullptr, nullptr)->m_nil_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* ObjectSpace_WeakKeyMap::m_delete(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* key = array_at(args, 0);
  Proc* _block = block;
  BasicObject* idx = nil_instance();
  if (truthy(this->m___ungcable___q((new Array({key})), nullptr, nullptr))) {
    return nil_instance();
  }
  idx = this->m___find_index__((new Array({key})), nullptr, nullptr);
  return (truthy(idx) ? ((this->iv_pairs->m_delete_at((new Array({idx})), nullptr, nullptr)->m_aref((new Array({(new Integer(1LL))})), nullptr, nullptr))) : ((truthy(this->m_block_given_q((new Array({})), nullptr, nullptr)) ? ((_block->m_call((new Array({key})), nullptr, nullptr))) : ((nil_instance())))));
  return nil_instance();
}

inline BasicObject* ObjectSpace_WeakKeyMap::m_getkey(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* key = array_at(args, 0);
  Proc* _block = block;
  BasicObject* pair = nil_instance();
  if (truthy(this->m___ungcable___q((new Array({key})), nullptr, nullptr))) {
    return nil_instance();
  }
  pair = this->m___find_pair__((new Array({key})), nullptr, nullptr);
  return (truthy(pair) ? ((pair->m_aref((new Array({(new Integer(0LL))})), nullptr, nullptr))) : ((nil_instance())));
  return nil_instance();
}

inline BasicObject* ObjectSpace_WeakKeyMap::m_clear(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  this->iv_pairs->m_clear((new Array({})), nullptr, nullptr);
  return this;
  return nil_instance();
}

inline BasicObject* ObjectSpace_WeakKeyMap::m___ungcable___q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* key = array_at(args, 0);
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = key->m_equal_q((new Array({nil_instance()})), nullptr, nullptr); return truthy(_l) ? _l : (key->m_equal_q((new Array({true_instance()})), nullptr, nullptr)); }()); return truthy(_l) ? _l : (key->m_equal_q((new Array({false_instance()})), nullptr, nullptr)); }()))) {
    return true_instance();
  }
  return ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = key->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (key->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)); }()); return truthy(_l) ? _l : (key->m_is_a_q((new Array({(&Symbol_CLASS)})), nullptr, nullptr)); }());  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<NoMethodError*>(e_) != nullptr) { return [&]() -> BasicObject* { return false_instance();  return nil_instance(); }(); } throw; } }());
  return nil_instance();
}

inline BasicObject* ENVClass::m_to_s(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new String("ENV", 3));
  return nil_instance();
}

inline BasicObject* ENVClass::m_rehash(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* ENVClass::m_eq_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* other = array_at(args, 0);
  Proc* _block = block;
  if (truthy(other->m_is_a_q((new Array({(&ENVClass_CLASS)})), nullptr, nullptr))) {
    return this->m_to_hash((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other->m_to_hash((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  }
  if (truthy(other->m_is_a_q((new Array({(&Hash_CLASS)})), nullptr, nullptr))) {
    return this->m_to_hash((new Array({})), nullptr, nullptr)->m_eq_q((new Array({other})), nullptr, nullptr);
  }
  return false_instance();
  return nil_instance();
}

inline BasicObject* ENVClass::m_dup(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { throw (new TypeError((new String("Cannot dup ENV, use ENV.to_h to get a copy of ENV as a hash", 59)))); }());
  return nil_instance();
}

inline Marshal_Dumper::Marshal_Dumper(BasicObject* limit) {
  (this->iv_limit = limit);
  (this->iv_depth = (new Integer(0LL)));
  (this->iv_symbols = (new Hash({})));
  (this->iv_objects = (new Hash({})));
  (this->iv_out = (new String("", 0))->m_b((new Array({})), nullptr, nullptr));
}

inline BasicObject* Marshal_Dumper::m_dump(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  this->iv_out->m_lshift((new Array({(new String("\004\010", 2))})), nullptr, nullptr);
  this->m_write_object((new Array({obj})), nullptr, nullptr);
  return this->iv_out;
  return nil_instance();
}

inline BasicObject* Marshal_Dumper::m_respond_to_marshal_dump_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  return obj->m_respond_to_q((new Array({intern("marshal_dump"), true_instance()})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Dumper::m_respond_to__dump_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  return obj->m_respond_to_q((new Array({intern("_dump"), true_instance()})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Dumper::m_real_class_name(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* klass = array_at(args, 0);
  Proc* _block = block;
  return (&Module_CLASS)->m_instance_method((new Array({intern("name")})), nullptr, nullptr)->m_bind((new Array({klass})), nullptr, nullptr)->m_call((new Array({})), nullptr, nullptr)->m_to_s((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Dumper::m_real_module_name(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* mod = array_at(args, 0);
  Proc* _block = block;
  return (&Module_CLASS)->m_instance_method((new Array({intern("name")})), nullptr, nullptr)->m_bind((new Array({mod})), nullptr, nullptr)->m_call((new Array({})), nullptr, nullptr)->m_to_s((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Dumper::m_write_object(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  BasicObject* result = nil_instance();
  return (truthy(this->iv_limit->m_ge((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? (((truthy(this->iv_depth->m_ge((new Array({this->iv_limit})), nullptr, nullptr)) ? ((([&]() -> BasicObject* { throw (new ArgumentError((new String("exceed depth limit", 18)))); }()))) : (nil_instance())), (this->iv_depth = this->iv_depth->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr)), (result = this->m_write_object_inner((new Array({obj})), nullptr, nullptr)), (this->iv_depth = this->iv_depth->m_minus((new Array({(new Integer(1LL))})), nullptr, nullptr)), result)) : ((this->m_write_object_inner((new Array({obj})), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* Marshal_Dumper::m_isa_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  BasicObject* klass = array_at(args, 1);
  Proc* _block = block;
  return ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return obj->m_is_a_q((new Array({klass})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<NoMethodError*>(e_) != nullptr) { return [&]() -> BasicObject* { return false_instance();  return nil_instance(); }(); } throw; } }());
  return nil_instance();
}

inline BasicObject* Marshal_Dumper::m_track(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  BasicObject* oid = nil_instance();
  oid = ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return obj->m_object_id((new Array({})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<NoMethodError*>(e_) != nullptr) { return [&]() -> BasicObject* { return obj->m___id__((new Array({})), nullptr, nullptr);  return nil_instance(); }(); } throw; } }());
  return this->iv_objects->m_aset((new Array({oid, this->iv_objects->m_size((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Dumper::m_bignum_to_bytes(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = array_at(args, 0);
  Proc* _block = block;
  BasicObject* bytes = nil_instance();
  bytes = (new String("", 0))->m_b((new Array({})), nullptr, nullptr);
  while (truthy(n->m_gt((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
    bytes->m_lshift((new Array({(n->m_bit_and((new Array({(new Integer(255LL))})), nullptr, nullptr))->m_chr((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
    n = n->m_rshift((new Array({(new Integer(8LL))})), nullptr, nullptr);
  }
  return bytes;
  return nil_instance();
}

inline BasicObject* Marshal_Dumper::m_encoding_ivar(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* enc = array_at(args, 0);
  Proc* _block = block;
  BasicObject* name = nil_instance();
  name = enc->m_name((new Array({})), nullptr, nullptr);
  return (truthy(name->m_eq_q((new Array({(new String("UTF-8", 5))})), nullptr, nullptr)) ? (((new Array({intern("E"), true_instance()})))) : ((truthy(([&]() -> BasicObject* { auto* _l = name->m_eq_q((new Array({(new String("US-ASCII", 8))})), nullptr, nullptr); return truthy(_l) ? _l : (name->m_eq_q((new Array({(new String("ASCII", 5))})), nullptr, nullptr)); }())) ? (((new Array({intern("E"), false_instance()})))) : ((truthy(([&]() -> BasicObject* { auto* _l = name->m_eq_q((new Array({(new String("ASCII-8BIT", 10))})), nullptr, nullptr); return truthy(_l) ? _l : (name->m_eq_q((new Array({(new String("BINARY", 6))})), nullptr, nullptr)); }())) ? ((nil_instance())) : (((new Array({intern("encoding"), name})))))))));
  return nil_instance();
}

inline BasicObject* Marshal_Dumper::m_collect_ivars(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  BasicObject* ivs = nil_instance();
  BasicObject* result = nil_instance();
  ivs = ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return obj->m_instance_variables((new Array({})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<NoMethodError*>(e_) != nullptr) { return [&]() -> BasicObject* { return (new Array({}));  return nil_instance(); }(); } throw; } }());
  result = (new Array({}));
  ivs->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* iv = arg; result->m_lshift((new Array({iv})), nullptr, nullptr); return result->m_lshift((new Array({obj->m_instance_variable_get((new Array({iv})), nullptr, nullptr)})), nullptr, nullptr); })));
  return result;
  return nil_instance();
}

inline BasicObject* Marshal_Dumper::m_extended_modules(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  BasicObject* can_singleton = nil_instance();
  BasicObject* sc = nil_instance();
  BasicObject* mods = nil_instance();
  BasicObject* klass_mods = nil_instance();
  can_singleton = (([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return obj->m_respond_to_q((new Array({intern("singleton_class"), true_instance()})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return false_instance();  return nil_instance(); }(); } throw; } }()));
  if (truthy(can_singleton)) {
    nil_instance();
  } else {
    return (new Array({}));
  }
  return ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { sc = obj->m_singleton_class((new Array({})), nullptr, nullptr); mods = sc->m_included_modules((new Array({})), nullptr, nullptr); klass_mods = obj->m_class((new Array({})), nullptr, nullptr)->m_ancestors((new Array({})), nullptr, nullptr)->m_select((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* a = arg; return ([&]() -> BasicObject* { auto* _l = a->m_is_a_q((new Array({(&Module_CLASS)})), nullptr, nullptr); return truthy(_l) ? (a->m_is_a_q((new Array({(&Class_CLASS)})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr)) : _l; }()); }))); return mods->m_minus((new Array({klass_mods})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return (new Array({}));  return nil_instance(); }(); } throw; } }());
  return nil_instance();
}

inline BasicObject* Marshal_Dumper::m_write_class_name(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* klass = array_at(args, 0);
  Proc* _block = block;
  BasicObject* name = nil_instance();
  this->m_check_anonymous((new Array({klass})), nullptr, nullptr);
  name = this->m_real_class_name((new Array({klass})), nullptr, nullptr);
  this->m_write_long((new Array({name->m_bytesize((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return this->iv_out->m_lshift((new Array({name->m_b((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Dumper::m_write_module_name(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* mod = array_at(args, 0);
  Proc* _block = block;
  BasicObject* name = nil_instance();
  this->m_check_anonymous((new Array({mod})), nullptr, nullptr);
  name = this->m_real_module_name((new Array({mod})), nullptr, nullptr);
  this->m_write_long((new Array({name->m_bytesize((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return this->iv_out->m_lshift((new Array({name->m_b((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Dumper::m_check_anonymous(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* mod = array_at(args, 0);
  Proc* _block = block;
  BasicObject* name = nil_instance();
  BasicObject* kind = nil_instance();
  name = ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return this->m_real_class_name((new Array({mod})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return this->m_real_module_name((new Array({mod})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return nil_instance();  return nil_instance(); }(); } throw; } }());  return nil_instance(); }(); } throw; } }());
  return (truthy(([&]() -> BasicObject* { auto* _l = name->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (name->m_empty_q((new Array({})), nullptr, nullptr)); }())) ? (((kind = (truthy(mod->m_is_a_q((new Array({(&Class_CLASS)})), nullptr, nullptr)) ? (((new String("class", 5)))) : (((new String("module", 6)))))), ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("can't dump anonymous ", 21))})), nullptr, nullptr)->m_plus((new Array({(kind)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" ", 1))})), nullptr, nullptr)->m_plus((new Array({(mod->m_inspect((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))); }()))) : (nil_instance()));
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_ivar(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_read_object_for_ivar((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_byte(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* b = nil_instance();
  if (truthy(this->iv_pos->m_ge((new Array({this->iv_data->m_bytesize((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("marshal data too short", 22)))); }());
  }
  b = this->iv_data->m_getbyte((new Array({this->iv_pos})), nullptr, nullptr);
  (this->iv_pos = this->iv_pos->m_plus((new Array({(new Integer(1LL))})), nullptr, nullptr));
  return b;
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_bytes(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* n = array_at(args, 0);
  Proc* _block = block;
  BasicObject* s = nil_instance();
  if (truthy(this->iv_pos->m_plus((new Array({n})), nullptr, nullptr)->m_gt((new Array({this->iv_data->m_bytesize((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("marshal data too short", 22)))); }());
  }
  s = this->iv_data->m_byteslice((new Array({this->iv_pos, n})), nullptr, nullptr);
  (this->iv_pos = this->iv_pos->m_plus((new Array({n})), nullptr, nullptr));
  return s;
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_peek_byte(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  if (truthy(this->iv_pos->m_ge((new Array({this->iv_data->m_bytesize((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("marshal data too short", 22)))); }());
  }
  return this->iv_data->m_getbyte((new Array({this->iv_pos})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_long(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* b = nil_instance();
  BasicObject* a = nil_instance();
  BasicObject* bb = nil_instance();
  BasicObject* c = nil_instance();
  BasicObject* d = nil_instance();
  b = this->m_read_byte((new Array({})), nullptr, nullptr);
  return (truthy(b->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr)) ? (((new Integer(0LL)))) : ((truthy(b->m_eq_q((new Array({(new Integer(1LL))})), nullptr, nullptr)) ? ((this->m_read_byte((new Array({})), nullptr, nullptr))) : ((truthy(b->m_eq_q((new Array({(new Integer(2LL))})), nullptr, nullptr)) ? (((a = this->m_read_byte((new Array({})), nullptr, nullptr)), (bb = this->m_read_byte((new Array({})), nullptr, nullptr)), a->m_bit_or((new Array({(bb->m_lshift((new Array({(new Integer(8LL))})), nullptr, nullptr))})), nullptr, nullptr))) : ((truthy(b->m_eq_q((new Array({(new Integer(3LL))})), nullptr, nullptr)) ? (((a = this->m_read_byte((new Array({})), nullptr, nullptr)), (bb = this->m_read_byte((new Array({})), nullptr, nullptr)), (c = this->m_read_byte((new Array({})), nullptr, nullptr)), a->m_bit_or((new Array({(bb->m_lshift((new Array({(new Integer(8LL))})), nullptr, nullptr))})), nullptr, nullptr)->m_bit_or((new Array({(c->m_lshift((new Array({(new Integer(16LL))})), nullptr, nullptr))})), nullptr, nullptr))) : ((truthy(b->m_eq_q((new Array({(new Integer(4LL))})), nullptr, nullptr)) ? (((a = this->m_read_byte((new Array({})), nullptr, nullptr)), (bb = this->m_read_byte((new Array({})), nullptr, nullptr)), (c = this->m_read_byte((new Array({})), nullptr, nullptr)), (d = this->m_read_byte((new Array({})), nullptr, nullptr)), a->m_bit_or((new Array({(bb->m_lshift((new Array({(new Integer(8LL))})), nullptr, nullptr))})), nullptr, nullptr)->m_bit_or((new Array({(c->m_lshift((new Array({(new Integer(16LL))})), nullptr, nullptr))})), nullptr, nullptr)->m_bit_or((new Array({(d->m_lshift((new Array({(new Integer(24LL))})), nullptr, nullptr))})), nullptr, nullptr))) : ((truthy(b->m_lt((new Array({(new Integer(128LL))})), nullptr, nullptr)) ? ((b->m_minus((new Array({(new Integer(5LL))})), nullptr, nullptr))) : ((truthy(b->m_lt((new Array({(new Integer(252LL))})), nullptr, nullptr)) ? ((b->m_minus((new Array({(new Integer(251LL))})), nullptr, nullptr))) : ((truthy(b->m_eq_q((new Array({(new Integer(252LL))})), nullptr, nullptr)) ? (((a = this->m_read_byte((new Array({})), nullptr, nullptr)), (bb = this->m_read_byte((new Array({})), nullptr, nullptr)), (c = this->m_read_byte((new Array({})), nullptr, nullptr)), (d = this->m_read_byte((new Array({})), nullptr, nullptr)), (a->m_bit_or((new Array({(bb->m_lshift((new Array({(new Integer(8LL))})), nullptr, nullptr))})), nullptr, nullptr)->m_bit_or((new Array({(c->m_lshift((new Array({(new Integer(16LL))})), nullptr, nullptr))})), nullptr, nullptr)->m_bit_or((new Array({(d->m_lshift((new Array({(new Integer(24LL))})), nullptr, nullptr))})), nullptr, nullptr))->m_minus((new Array({(new Integer(4294967296LL))})), nullptr, nullptr))) : ((truthy(b->m_eq_q((new Array({(new Integer(253LL))})), nullptr, nullptr)) ? (((a = this->m_read_byte((new Array({})), nullptr, nullptr)), (bb = this->m_read_byte((new Array({})), nullptr, nullptr)), (c = this->m_read_byte((new Array({})), nullptr, nullptr)), (a->m_bit_or((new Array({(bb->m_lshift((new Array({(new Integer(8LL))})), nullptr, nullptr))})), nullptr, nullptr)->m_bit_or((new Array({(c->m_lshift((new Array({(new Integer(16LL))})), nullptr, nullptr))})), nullptr, nullptr))->m_minus((new Array({(new Integer(16777216LL))})), nullptr, nullptr))) : ((truthy(b->m_eq_q((new Array({(new Integer(254LL))})), nullptr, nullptr)) ? (((a = this->m_read_byte((new Array({})), nullptr, nullptr)), (bb = this->m_read_byte((new Array({})), nullptr, nullptr)), (a->m_bit_or((new Array({(bb->m_lshift((new Array({(new Integer(8LL))})), nullptr, nullptr))})), nullptr, nullptr))->m_minus((new Array({(new Integer(65536LL))})), nullptr, nullptr))) : ((truthy(b->m_eq_q((new Array({(new Integer(255LL))})), nullptr, nullptr)) ? (((a = this->m_read_byte((new Array({})), nullptr, nullptr)), a->m_minus((new Array({(new Integer(256LL))})), nullptr, nullptr))) : ((([&]() -> BasicObject* { throw (new ArgumentError((new String("marshal data too short", 22)))); }()))))))))))))))))))))))));
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_track(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  BasicObject* idx = nil_instance();
  idx = this->iv_objects->m_size((new Array({})), nullptr, nullptr);
  this->iv_objects->m_lshift((new Array({obj})), nullptr, nullptr);
  return idx;
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_call_proc(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  BasicObject* tracked_idx = (args->data.size() > 1) ? args->data[1] : (nil_instance());
  Proc* _block = block;
  BasicObject* result = nil_instance();
  if (truthy(this->iv_freeze)) {
    this->m_freeze_object((new Array({obj})), nullptr, nullptr);
  }
  return (truthy(this->iv_proc) ? (((result = this->iv_proc->m_call((new Array({obj})), nullptr, nullptr)), (truthy(tracked_idx) ? ((this->iv_completed->m_aset((new Array({tracked_idx, true_instance()})), nullptr, nullptr))) : (nil_instance())), result)) : ((obj)));
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_freeze_object(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = obj->m_nil_q((new Array({})), nullptr, nullptr); return truthy(_l) ? _l : (obj->m_equal_q((new Array({true_instance()})), nullptr, nullptr)); }()); return truthy(_l) ? _l : (obj->m_equal_q((new Array({false_instance()})), nullptr, nullptr)); }()))) {
    return obj;
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = obj->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (obj->m_is_a_q((new Array({(&Symbol_CLASS)})), nullptr, nullptr)); }()); return truthy(_l) ? _l : (obj->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)); }()))) {
    return obj;
  }
  if (truthy(obj->m_is_a_q((new Array({(&Module_CLASS)})), nullptr, nullptr))) {
    return obj;
  }
  ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return obj->m_freeze((new Array({})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return nil_instance();  return nil_instance(); }(); } throw; } }());
  return obj;
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_symbol(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* len = nil_instance();
  BasicObject* str = nil_instance();
  BasicObject* sym = nil_instance();
  len = this->m_read_long((new Array({})), nullptr, nullptr);
  str = this->m_read_bytes((new Array({len})), nullptr, nullptr);
  sym = str->m_to_sym((new Array({})), nullptr, nullptr);
  this->iv_symbols->m_lshift((new Array({sym})), nullptr, nullptr);
  return this->m_call_proc((new Array({sym})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_array(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* len = nil_instance();
  BasicObject* arr = nil_instance();
  BasicObject* idx = nil_instance();
  len = this->m_read_long((new Array({})), nullptr, nullptr);
  arr = (new Array(static_cast<BasicObject*>(len)));
  idx = this->m_track((new Array({arr})), nullptr, nullptr);
  for (int64_t __i_raw__ = 0; __i_raw__ < static_cast<Integer*>(len)->raw_; __i_raw__++) {
    BasicObject* i = new Integer(__i_raw__);
    arr->m_aset((new Array({i, this->m_read_object((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  }
  return this->m_call_proc((new Array({arr, idx})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_hash(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* has_default = array_at(args, 0);
  Proc* _block = block;
  BasicObject* len = nil_instance();
  BasicObject* h = nil_instance();
  BasicObject* idx = nil_instance();
  len = this->m_read_long((new Array({})), nullptr, nullptr);
  h = (new Hash({}));
  idx = this->m_track((new Array({h})), nullptr, nullptr);
  for (int64_t ___i_raw__ = 0; ___i_raw__ < static_cast<Integer*>(len)->raw_; ___i_raw__++) {
    BasicObject* _i = new Integer(___i_raw__);
    BasicObject* k = this->m_read_object((new Array({})), nullptr, nullptr);
    BasicObject* v = this->m_read_object((new Array({})), nullptr, nullptr);
    h->m_aset((new Array({k, v})), nullptr, nullptr);
  }
  if (truthy(has_default)) {
    h->m_default_set((new Array({this->m_read_object((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  }
  return this->m_call_proc((new Array({h, idx})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_class_ref(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* len = nil_instance();
  BasicObject* name = nil_instance();
  BasicObject* klass = nil_instance();
  BasicObject* obj_idx = nil_instance();
  BasicObject* obj = nil_instance();
  len = this->m_read_long((new Array({})), nullptr, nullptr);
  name = this->m_read_bytes((new Array({len})), nullptr, nullptr);
  klass = this->m_const_from_name((new Array({name})), nullptr, nullptr);
  if (truthy(klass->m_is_a_q((new Array({(&Class_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError(((new String("", 0))->m_plus((new Array({(name)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" does not refer to a Class", 26))})), nullptr, nullptr)))); }());
  }
  obj_idx = this->iv_objects->m_size((new Array({})), nullptr, nullptr);
  this->iv_objects->m_lshift((new Array({klass})), nullptr, nullptr);
  obj = this->m_call_proc((new Array({klass, obj_idx})), nullptr, nullptr);
  this->iv_objects->m_aset((new Array({obj_idx, obj})), nullptr, nullptr);
  return obj;
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_module_ref(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* len = nil_instance();
  BasicObject* name = nil_instance();
  BasicObject* mod = nil_instance();
  BasicObject* obj_idx = nil_instance();
  BasicObject* obj = nil_instance();
  len = this->m_read_long((new Array({})), nullptr, nullptr);
  name = this->m_read_bytes((new Array({len})), nullptr, nullptr);
  mod = this->m_const_from_name((new Array({name})), nullptr, nullptr);
  if (truthy(([&]() -> BasicObject* { auto* _l = mod->m_is_a_q((new Array({(&Module_CLASS)})), nullptr, nullptr); return truthy(_l) ? (mod->m_is_a_q((new Array({(&Class_CLASS)})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr)) : _l; }()))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new ArgumentError(((new String("", 0))->m_plus((new Array({(name)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" does not refer to a Module", 27))})), nullptr, nullptr)))); }());
  }
  obj_idx = this->iv_objects->m_size((new Array({})), nullptr, nullptr);
  this->iv_objects->m_lshift((new Array({mod})), nullptr, nullptr);
  obj = this->m_call_proc((new Array({mod, obj_idx})), nullptr, nullptr);
  this->iv_objects->m_aset((new Array({obj_idx, obj})), nullptr, nullptr);
  return obj;
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_old_module_ref(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* len = nil_instance();
  BasicObject* name = nil_instance();
  BasicObject* mod = nil_instance();
  BasicObject* obj_idx = nil_instance();
  BasicObject* obj = nil_instance();
  len = this->m_read_long((new Array({})), nullptr, nullptr);
  name = this->m_read_bytes((new Array({len})), nullptr, nullptr);
  mod = this->m_const_from_name((new Array({name})), nullptr, nullptr);
  obj_idx = this->iv_objects->m_size((new Array({})), nullptr, nullptr);
  this->iv_objects->m_lshift((new Array({mod})), nullptr, nullptr);
  obj = this->m_call_proc((new Array({mod, obj_idx})), nullptr, nullptr);
  this->iv_objects->m_aset((new Array({obj_idx, obj})), nullptr, nullptr);
  return obj;
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_class_by_name(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* sym = nil_instance();
  BasicObject* name = nil_instance();
  sym = this->m_read_object((new Array({})), nullptr, nullptr);
  name = (truthy(sym->m_is_a_q((new Array({(&Symbol_CLASS)})), nullptr, nullptr)) ? ((sym->m_to_s((new Array({})), nullptr, nullptr))) : ((sym->m_to_s((new Array({})), nullptr, nullptr))));
  return this->m_const_from_name((new Array({name})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_class_by_symbol(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* sym = nil_instance();
  sym = this->m_read_ivar_name((new Array({})), nullptr, nullptr);
  return this->m_const_from_name((new Array({sym->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_user_defined_body(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* klass = nil_instance();
  BasicObject* len = nil_instance();
  BasicObject* data = nil_instance();
  BasicObject* obj = nil_instance();
  klass = this->m_read_class_by_symbol((new Array({})), nullptr, nullptr);
  len = this->m_read_long((new Array({})), nullptr, nullptr);
  data = this->m_read_bytes((new Array({len})), nullptr, nullptr);
  obj = klass->m_send((new Array({intern("_load"), data})), nullptr, nullptr);
  return obj;
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_struct_body(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* klass = nil_instance();
  BasicObject* num_members = nil_instance();
  BasicObject* obj = nil_instance();
  klass = this->m_read_class_by_symbol((new Array({})), nullptr, nullptr);
  num_members = this->m_read_long((new Array({})), nullptr, nullptr);
  obj = klass->m_allocate((new Array({})), nullptr, nullptr);
  for (int64_t ___i_raw__ = 0; ___i_raw__ < static_cast<Integer*>(num_members)->raw_; ___i_raw__++) {
    BasicObject* _i = new Integer(___i_raw__);
    BasicObject* name = this->m_read_ivar_name((new Array({})), nullptr, nullptr);
    BasicObject* val = this->m_read_object((new Array({})), nullptr, nullptr);
    obj->m_aset((new Array({name, ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return val;  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return obj->m_send((new Array({((new String("", 0))->m_plus((new Array({(name)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String("=", 1))})), nullptr, nullptr))->m_to_sym((new Array({})), nullptr, nullptr), val})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return nil_instance();  return nil_instance(); }(); } throw; } }());  return nil_instance(); }(); } throw; } }())})), nullptr, nullptr);
  }
  return obj;
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_generic_object_body(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* klass = nil_instance();
  BasicObject* num_ivars = nil_instance();
  BasicObject* obj = nil_instance();
  klass = this->m_read_class_by_symbol((new Array({})), nullptr, nullptr);
  num_ivars = this->m_read_long((new Array({})), nullptr, nullptr);
  obj = klass->m_allocate((new Array({})), nullptr, nullptr);
  for (int64_t ___i_raw__ = 0; ___i_raw__ < static_cast<Integer*>(num_ivars)->raw_; ___i_raw__++) {
    BasicObject* _i = new Integer(___i_raw__);
    BasicObject* name = this->m_read_ivar_name((new Array({})), nullptr, nullptr);
    BasicObject* val = this->m_read_object((new Array({})), nullptr, nullptr);
    obj->m_instance_variable_set((new Array({name, val})), nullptr, nullptr);
  }
  return obj;
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_link(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* idx = nil_instance();
  BasicObject* obj = nil_instance();
  idx = this->m_read_long((new Array({})), nullptr, nullptr);
  if (truthy(([&]() -> BasicObject* { auto* _l = idx->m_lt((new Array({(new Integer(0LL))})), nullptr, nullptr); return truthy(_l) ? _l : (idx->m_ge((new Array({this->iv_objects->m_size((new Array({})), nullptr, nullptr)})), nullptr, nullptr)); }()))) {
    ([&]() -> BasicObject* { throw (new ArgumentError((new String("bad link", 8)))); }());
  }
  obj = this->iv_objects->m_aref((new Array({idx})), nullptr, nullptr);
  return (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = this->iv_proc; return truthy(_l) ? (this->iv_completed->m_aref((new Array({idx})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? (this->iv_no_link_proc->m_aref((new Array({idx})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr)) : _l; }())) ? ((this->iv_proc->m_call((new Array({obj})), nullptr, nullptr))) : ((obj)));
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_uclass(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* klass = nil_instance();
  BasicObject* compare_by_id = nil_instance();
  BasicObject* obj = nil_instance();
  BasicObject* obj_idx = nil_instance();
  klass = this->m_read_class_by_symbol((new Array({})), nullptr, nullptr);
  compare_by_id = (klass->m_eq_q((new Array({(&Hash_CLASS)})), nullptr, nullptr));
  obj = this->m_read_object_with_class((new Array({klass})), nullptr, nullptr);
  return (truthy(([&]() -> BasicObject* { auto* _l = compare_by_id; return truthy(_l) ? (obj->m_is_a_q((new Array({(&Hash_CLASS)})), nullptr, nullptr)) : _l; }())) ? ((obj->m_compare_by_identity((new Array({})), nullptr, nullptr), (obj_idx = this->iv_objects->m_size((new Array({})), nullptr, nullptr)->m_minus((new Array({(new Integer(1LL))})), nullptr, nullptr)), this->m_call_proc((new Array({obj, obj_idx})), nullptr, nullptr))) : ((obj)));
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_user_defined(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* klass = nil_instance();
  BasicObject* len = nil_instance();
  BasicObject* data = nil_instance();
  BasicObject* obj = nil_instance();
  BasicObject* idx = nil_instance();
  klass = this->m_read_class_by_symbol((new Array({})), nullptr, nullptr);
  len = this->m_read_long((new Array({})), nullptr, nullptr);
  data = this->m_read_bytes((new Array({len})), nullptr, nullptr);
  obj = klass->m_send((new Array({intern("_load"), data})), nullptr, nullptr);
  idx = this->iv_objects->m_size((new Array({})), nullptr, nullptr);
  this->iv_objects->m_lshift((new Array({obj})), nullptr, nullptr);
  this->iv_no_link_proc->m_aset((new Array({idx, true_instance()})), nullptr, nullptr);
  return this->m_call_proc((new Array({obj})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_user_marshal(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* klass = nil_instance();
  BasicObject* data = nil_instance();
  BasicObject* placeholder_idx = nil_instance();
  BasicObject* obj = nil_instance();
  BasicObject* idx = nil_instance();
  klass = this->m_read_class_by_symbol((new Array({})), nullptr, nullptr);
  data = nil_instance();
  if (truthy(klass->m_eq_q((new Array({(&Rational_CLASS)})), nullptr, nullptr))) {
    placeholder_idx = this->iv_objects->m_size((new Array({})), nullptr, nullptr);
    this->iv_objects->m_lshift((new Array({nil_instance()})), nullptr, nullptr);
    this->iv_no_link_proc->m_aset((new Array({placeholder_idx, true_instance()})), nullptr, nullptr);
    data = this->m_read_object((new Array({})), nullptr, nullptr);
    obj = this->m_Rational(static_cast<Array*>(data), nullptr, nullptr);
    this->iv_objects->m_aset((new Array({placeholder_idx, obj})), nullptr, nullptr);
    return this->m_call_proc((new Array({obj})), nullptr, nullptr);
  }
  if (truthy(klass->m_eq_q((new Array({(&Complex_CLASS)})), nullptr, nullptr))) {
    placeholder_idx = this->iv_objects->m_size((new Array({})), nullptr, nullptr);
    this->iv_objects->m_lshift((new Array({nil_instance()})), nullptr, nullptr);
    this->iv_no_link_proc->m_aset((new Array({placeholder_idx, true_instance()})), nullptr, nullptr);
    data = this->m_read_object((new Array({})), nullptr, nullptr);
    obj = this->m_Complex(static_cast<Array*>(data), nullptr, nullptr);
    this->iv_objects->m_aset((new Array({placeholder_idx, obj})), nullptr, nullptr);
    return this->m_call_proc((new Array({obj})), nullptr, nullptr);
  }
  obj = klass->m_allocate((new Array({})), nullptr, nullptr);
  idx = this->iv_objects->m_size((new Array({})), nullptr, nullptr);
  this->m_track((new Array({obj})), nullptr, nullptr);
  this->iv_no_link_proc->m_aset((new Array({idx, true_instance()})), nullptr, nullptr);
  data = this->m_read_object((new Array({})), nullptr, nullptr);
  obj->m___send__((new Array({intern("marshal_load"), data})), nullptr, nullptr);
  return this->m_call_proc((new Array({obj})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_extended(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* mod = nil_instance();
  BasicObject* obj = nil_instance();
  mod = this->m_read_class_by_symbol((new Array({})), nullptr, nullptr);
  obj = this->m_read_object((new Array({})), nullptr, nullptr);
  ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return obj->m_extend((new Array({mod})), nullptr, nullptr);  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return nil_instance();  return nil_instance(); }(); } throw; } }());
  return obj;
  return nil_instance();
}

inline BasicObject* Marshal_Loader::m_read_data_object(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* klass = nil_instance();
  BasicObject* obj = nil_instance();
  BasicObject* idx = nil_instance();
  BasicObject* data = nil_instance();
  klass = this->m_read_class_by_symbol((new Array({})), nullptr, nullptr);
  obj = klass->m_allocate((new Array({})), nullptr, nullptr);
  idx = this->m_track((new Array({obj})), nullptr, nullptr);
  data = this->m_read_object((new Array({})), nullptr, nullptr);
  if (truthy(obj->m_respond_to_q((new Array({intern("_load_data"), true_instance()})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("class ", 6))})), nullptr, nullptr)->m_plus((new Array({(klass)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" needs to have method '_load_data'", 34))})), nullptr, nullptr)))); }());
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = obj->m_is_a_q((new Array({klass})), nullptr, nullptr); return truthy(_l) ? (klass->m_instance_methods((new Array({false_instance()})), nullptr, nullptr)->m_include_q((new Array({intern("_load_data")})), nullptr, nullptr)) : _l; }()); return truthy(_l) ? _l : (klass->m_private_instance_methods((new Array({false_instance()})), nullptr, nullptr)->m_include_q((new Array({intern("_load_data")})), nullptr, nullptr)); }()))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("class ", 6))})), nullptr, nullptr)->m_plus((new Array({(klass)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" needs to have method '_load_data'", 34))})), nullptr, nullptr)))); }());
  }
  obj->m___send__((new Array({intern("_load_data"), data})), nullptr, nullptr);
  return this->m_call_proc((new Array({obj, idx})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Range_eigenclass::m_new(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* b = array_at(args, 0);
  BasicObject* e = array_at(args, 1);
  BasicObject* excl = (args->data.size() > 2) ? args->data[2] : (false_instance());
  Proc* _block = block;
  BasicObject* r = nil_instance();
  r = this->m_allocate((new Array({})), nullptr, nullptr);
  r->m___send__((new Array({intern("initialize"), b, e, excl})), nullptr, nullptr);
  return r;
  return nil_instance();
}

inline BasicObject* Enumerator_eigenclass::m__from_method(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* receiver = array_at(args, 0);
  BasicObject* method_name = array_at(args, 1);
  BasicObject* method_args = array_at(args, 2);
  BasicObject* size_block = (args->data.size() > 3) ? args->data[3] : (nil_instance());
  BasicObject* method_kwargs = (args->data.size() > 4) ? args->data[4] : ((new Hash({})));
  Proc* _block = block;
  BasicObject* e = nil_instance();
  e = this->m_allocate((new Array({})), nullptr, nullptr);
  e->m_instance_variable_set((new Array({intern("@receiver"), receiver})), nullptr, nullptr);
  e->m_instance_variable_set((new Array({intern("@method_name"), method_name})), nullptr, nullptr);
  e->m_instance_variable_set((new Array({intern("@method_args"), ([&]() -> BasicObject* { auto* _l = method_args; return truthy(_l) ? _l : ((new Array({}))); }())})), nullptr, nullptr);
  e->m_instance_variable_set((new Array({intern("@method_kwargs"), ([&]() -> BasicObject* { auto* _l = method_kwargs; return truthy(_l) ? _l : ((new Hash({}))); }())})), nullptr, nullptr);
  e->m_instance_variable_set((new Array({intern("@size_block"), size_block})), nullptr, nullptr);
  e->m_instance_variable_set((new Array({intern("@block"), nil_instance()})), nullptr, nullptr);
  e->m_instance_variable_set((new Array({intern("@size"), nil_instance()})), nullptr, nullptr);
  e->m_instance_variable_set((new Array({intern("@fiber"), nil_instance()})), nullptr, nullptr);
  e->m_instance_variable_set((new Array({intern("@peeked"), false_instance()})), nullptr, nullptr);
  e->m_instance_variable_set((new Array({intern("@peeked_vals"), nil_instance()})), nullptr, nullptr);
  e->m_instance_variable_set((new Array({intern("@feed"), nil_instance()})), nullptr, nullptr);
  e->m_instance_variable_set((new Array({intern("@_feed_pending"), false_instance()})), nullptr, nullptr);
  e->m_instance_variable_set((new Array({intern("@_fiber_started"), false_instance()})), nullptr, nullptr);
  return e;
  return nil_instance();
}

inline BasicObject* Enumerator_eigenclass::m_produce(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* initial_args = args;  // *rest = whole args
  Proc* _block = block;
  BasicObject* has_initial = nil_instance();
  if (truthy(initial_args->m_size((new Array({})), nullptr, nullptr)->m_gt((new Array({(new Integer(1LL))})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new ArgumentError(((new String("", 0))->m_plus((new Array({(new String("wrong number of arguments (given ", 33))})), nullptr, nullptr)->m_plus((new Array({(initial_args->m_size((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(", expected 0..1)", 16))})), nullptr, nullptr)))); }());
  }
  has_initial = initial_args->m_empty_q((new Array({})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr);
  return (new Enumerator());
  return nil_instance();
}

inline BasicObject* Exception_eigenclass::m_exception(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* message = (args->data.size() > 0) ? args->data[0] : (nil_instance());
  Proc* _block = block;
  return (truthy(message->m_nil_q((new Array({})), nullptr, nullptr)) ? ((this->m_new((new Array({})), nullptr, nullptr))) : ((this->m_new((new Array({message})), nullptr, nullptr))));
  return nil_instance();
}

inline BasicObject* Encoding_eigenclass::m_default_internal(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv_default_internal;
  return nil_instance();
}

inline BasicObject* Encoding_eigenclass::m_find(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* name = array_at(args, 0);
  Proc* _block = block;
  BasicObject* name_s = nil_instance();
  BasicObject* name_lower = nil_instance();
  if (truthy(name->m_is_a_q((new Array({(&Symbol_CLASS)})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of ", 26))})), nullptr, nullptr)->m_plus((new Array({(name->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into String", 12))})), nullptr, nullptr)))); }());
  }
  if (truthy(name->m_is_a_q((new Array({(&Encoding_CLASS)})), nullptr, nullptr))) {
    return name;
  }
  name_s = (truthy(name->m_respond_to_q((new Array({intern("to_str")})), nullptr, nullptr)) ? ((name->m_to_str((new Array({})), nullptr, nullptr))) : ((name->m_to_s((new Array({})), nullptr, nullptr))));
  name_lower = name_s->m_downcase((new Array({})), nullptr, nullptr);
  if (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = name_lower->m_eq_q((new Array({(new String("locale", 6))})), nullptr, nullptr); return truthy(_l) ? _l : (name_lower->m_eq_q((new Array({(new String("external", 8))})), nullptr, nullptr)); }()); return truthy(_l) ? _l : (name_lower->m_eq_q((new Array({(new String("filesystem", 10))})), nullptr, nullptr)); }()))) {
    return this->m_default_external((new Array({})), nullptr, nullptr);
  }
  if (truthy(name_lower->m_eq_q((new Array({(new String("internal", 8))})), nullptr, nullptr))) {
    return this->m_default_internal((new Array({})), nullptr, nullptr);
  }
  ([&]() -> BasicObject* { auto* _l = this->iv_find_map; return truthy(_l) ? _l : ((this->iv_find_map = this->m___build_find_map__((new Array({})), nullptr, nullptr))); }());
  return ([&]() -> BasicObject* { auto* _l = this->iv_find_map->m_aref((new Array({name_lower})), nullptr, nullptr); return truthy(_l) ? _l : (([&]() -> BasicObject* { throw (new ArgumentError(((new String("", 0))->m_plus((new Array({(new String("unknown encoding name - ", 24))})), nullptr, nullptr)->m_plus((new Array({(name_s)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))); }())); }());
  return nil_instance();
}

inline BasicObject* MatchData_eigenclass::m_allocate(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { throw (new NoMethodError((new String("undefined method 'allocate' for class 'MatchData'", 49)))); }());
  return nil_instance();
}

inline BasicObject* Regexp_eigenclass::m_try_convert(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* obj = array_at(args, 0);
  Proc* _block = block;
  BasicObject* result = nil_instance();
  if (truthy(obj->m_is_a_q((new Array({(&Regexp_CLASS)})), nullptr, nullptr))) {
    return obj;
  }
  if (truthy(obj->m_respond_to_q((new Array({intern("to_regexp")})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return nil_instance();
  }
  result = obj->m_to_regexp((new Array({})), nullptr, nullptr);
  if (truthy(result->m_is_a_q((new Array({(&Regexp_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("can't convert ", 14))})), nullptr, nullptr)->m_plus((new Array({(obj->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into Regexp (", 14))})), nullptr, nullptr)->m_plus((new Array({(obj->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String("#to_regexp gives ", 17))})), nullptr, nullptr)->m_plus((new Array({(result->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(")", 1))})), nullptr, nullptr)))); }());
  }
  return result;
  return nil_instance();
}

inline BasicObject* Rational_eigenclass::m_new(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* __anon_rest__ = args;  // *rest = whole args
  Proc* _block = block;
  return ([&]() -> BasicObject* { throw (new NoMethodError(((new String("", 0))->m_plus((new Array({(new String("undefined method 'new' for class ", 33))})), nullptr, nullptr)->m_plus((new Array({(this)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))); }());
  return nil_instance();
}

inline BasicObject* Complex_eigenclass::m_rect(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* real = array_at(args, 0);
  BasicObject* imag = (args->data.size() > 1) ? args->data[1] : ((new Integer(0LL)));
  Proc* _block = block;
  real = this->m__real_check((new Array({real})), nullptr, nullptr);
  imag = this->m__real_check((new Array({imag})), nullptr, nullptr);
  return this->m_new((new Array({real, imag})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Complex_eigenclass::m_rectangular(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* real = array_at(args, 0);
  BasicObject* imag = (args->data.size() > 1) ? args->data[1] : ((new Integer(0LL)));
  Proc* _block = block;
  real = this->m__real_check((new Array({real})), nullptr, nullptr);
  imag = this->m__real_check((new Array({imag})), nullptr, nullptr);
  return this->m_new((new Array({real, imag})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Complex_eigenclass::m__real_check(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* v = array_at(args, 0);
  Proc* _block = block;
  if (truthy(v->m_is_a_q((new Array({(&Complex_CLASS)})), nullptr, nullptr))) {
    if (truthy(v->m_imaginary((new Array({})), nullptr, nullptr)->m_eq_q((new Array({(new Integer(0LL))})), nullptr, nullptr))) {
      nil_instance();
    } else {
      ([&]() -> BasicObject* { throw (new TypeError((new String("not a real", 10)))); }());
    }
    return v->m_real((new Array({})), nullptr, nullptr);
  }
  if (truthy(v->m_is_a_q((new Array({(&Numeric_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError((new String("not a real", 10)))); }());
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = v->m_respond_to_q((new Array({intern("real?")})), nullptr, nullptr); return truthy(_l) ? (v->m_real_q((new Array({})), nullptr, nullptr)->m_eq_q((new Array({false_instance()})), nullptr, nullptr)) : _l; }()))) {
    ([&]() -> BasicObject* { throw (new TypeError((new String("not a real", 10)))); }());
  }
  return v;
  return nil_instance();
}

inline BasicObject* IO_eigenclass::m_binread(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* path = array_at(args, 0);
  BasicObject* length = (args->data.size() > 1) ? args->data[1] : (nil_instance());
  BasicObject* offset = (args->data.size() > 2) ? args->data[2] : (nil_instance());
  Proc* _block = block;
  return this->m_open((new Array({path, (new String("rb", 2))})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* f = arg; (truthy(offset) ? ((f->m_seek((new Array({offset})), nullptr, nullptr))) : (nil_instance())); return (truthy(length) ? ((f->m_read((new Array({length})), nullptr, nullptr))) : ((f->m_read((new Array({})), nullptr, nullptr)))); })));
  return nil_instance();
}

inline BasicObject* IO_eigenclass::m___coerce_path__(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* path = array_at(args, 0);
  Proc* _block = block;
  return (truthy(path->m_nil_q((new Array({})), nullptr, nullptr)) ? ((([&]() -> BasicObject* { throw (new TypeError((new String("no implicit conversion of nil into String", 41)))); }()))) : ((truthy(path->m_respond_to_q((new Array({intern("to_path")})), nullptr, nullptr)) ? ((path->m_to_path((new Array({})), nullptr, nullptr))) : ((truthy(path->m_respond_to_q((new Array({intern("to_str")})), nullptr, nullptr)) ? ((path->m_to_str((new Array({})), nullptr, nullptr))) : ((([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of ", 26))})), nullptr, nullptr)->m_plus((new Array({(path->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into String", 12))})), nullptr, nullptr)))); }()))))))));
  return nil_instance();
}

inline BasicObject* File_eigenclass::m_lchown(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* uid = array_at(args, 0);
  BasicObject* gid = array_at(args, 1);
  Array* paths = new Array();
  for (std::size_t _i = 2; _i < args->data.size(); _i++) {
    paths->data.push_back(args->data[_i]);
  }
  Proc* _block = block;
  return paths->m_length((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_eigenclass::m_lchmod(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* mode = array_at(args, 0);
  Array* paths = new Array();
  for (std::size_t _i = 1; _i < args->data.size(); _i++) {
    paths->data.push_back(args->data[_i]);
  }
  Proc* _block = block;
  return paths->m_length((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_eigenclass::m_fnmatch_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* pattern = array_at(args, 0);
  BasicObject* path = array_at(args, 1);
  BasicObject* flags = (args->data.size() > 2) ? args->data[2] : ((new Integer(0LL)));
  Proc* _block = block;
  return this->m_fnmatch((new Array({pattern, path, flags})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_eigenclass::m_chown(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* uid = array_at(args, 0);
  BasicObject* gid = array_at(args, 1);
  Array* paths = new Array();
  for (std::size_t _i = 2; _i < args->data.size(); _i++) {
    paths->data.push_back(args->data[_i]);
  }
  Proc* _block = block;
  paths->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* p = arg; return (truthy(this->m_exist_q((new Array({this->m__coerce_path((new Array({p})), nullptr, nullptr)})), nullptr, nullptr)) ? (nil_instance()) : ((([&]() -> BasicObject* { throw (new Errno_ENOENT(this->m__coerce_path((new Array({p})), nullptr, nullptr))); }())))); })));
  return paths->m_length((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* File_eigenclass::m_path(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* path = array_at(args, 0);
  Proc* _block = block;
  BasicObject* result = nil_instance();
  return (truthy(path->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)) ? (((truthy(path->m_include_q((new Array({(new String("\0", 1))})), nullptr, nullptr)) ? ((([&]() -> BasicObject* { throw (new ArgumentError((new String("path name contains null byte", 28)))); }()))) : (nil_instance())), path)) : ((truthy(path->m_respond_to_q((new Array({intern("to_path")})), nullptr, nullptr)) ? (((result = path->m_to_path((new Array({})), nullptr, nullptr)), (truthy(result->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)) ? (nil_instance()) : ((([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of ", 26))})), nullptr, nullptr)->m_plus((new Array({(path->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into String", 12))})), nullptr, nullptr)))); }())))), (truthy(result->m_include_q((new Array({(new String("\0", 1))})), nullptr, nullptr)) ? ((([&]() -> BasicObject* { throw (new ArgumentError((new String("path name contains null byte", 28)))); }()))) : (nil_instance())), result)) : ((truthy(path->m_is_a_q((new Array({(&IO_CLASS)})), nullptr, nullptr)) ? ((path->m_path((new Array({})), nullptr, nullptr))) : ((([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of ", 26))})), nullptr, nullptr)->m_plus((new Array({(path->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into String", 12))})), nullptr, nullptr)))); }()))))))));
  return nil_instance();
}

inline BasicObject* File_eigenclass::m__coerce_path(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* arg = array_at(args, 0);
  Proc* _block = block;
  BasicObject* r = nil_instance();
  if (truthy(arg->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr))) {
    return arg;
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = arg->m_respond_to_q((new Array({intern("to_path")})), nullptr, nullptr)->m_not((new Array({})), nullptr, nullptr); return truthy(_l) ? (arg->m_respond_to_q((new Array({intern("to_io")})), nullptr, nullptr)) : _l; }()))) {
    arg = arg->m_to_io((new Array({})), nullptr, nullptr);
  }
  if (truthy(arg->m_respond_to_q((new Array({intern("to_path")})), nullptr, nullptr))) {
    r = arg->m_to_path((new Array({})), nullptr, nullptr);
    if (truthy(r->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr))) {
      return r;
    }
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of ", 26))})), nullptr, nullptr)->m_plus((new Array({(arg->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into String", 12))})), nullptr, nullptr)))); }());
  }
  if (truthy(arg->m_respond_to_q((new Array({intern("to_str")})), nullptr, nullptr))) {
    r = arg->m_to_str((new Array({})), nullptr, nullptr);
    if (truthy(r->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr))) {
      return r;
    }
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of ", 26))})), nullptr, nullptr)->m_plus((new Array({(arg->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into String", 12))})), nullptr, nullptr)))); }());
  }
  return ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of ", 26))})), nullptr, nullptr)->m_plus((new Array({(arg->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into String", 12))})), nullptr, nullptr)))); }());
  return nil_instance();
}

inline BasicObject* Time_eigenclass::m_mktime(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m__mktime_args((new Array({args, false_instance()})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time_eigenclass::m_utc(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m__mktime_args((new Array({args, true_instance()})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time_eigenclass::m_gm(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m__mktime_args((new Array({args, true_instance()})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time_eigenclass::m_local(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m__mktime_args((new Array({args, false_instance()})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time_eigenclass::m__local_to_utc_offset(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* tentative = array_at(args, 0);
  BasicObject* utc_result = array_at(args, 1);
  Proc* _block = block;
  return tentative->m_to_i((new Array({})), nullptr, nullptr)->m_minus((new Array({((truthy(utc_result->m_respond_to_q((new Array({intern("to_i")})), nullptr, nullptr)) ? ((utc_result->m_to_i((new Array({})), nullptr, nullptr))) : ((tentative->m_to_i((new Array({})), nullptr, nullptr)))))})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Time_eigenclass::m__utc_to_local_offset(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* local_t = array_at(args, 0);
  BasicObject* utc_t = array_at(args, 1);
  Proc* _block = block;
  return (truthy(local_t->m_is_a_q((new Array({(&Time_CLASS)})), nullptr, nullptr)) ? (((&Time_CLASS)->m_utc((new Array({local_t->m_year((new Array({})), nullptr, nullptr), local_t->m_mon((new Array({})), nullptr, nullptr), local_t->m_mday((new Array({})), nullptr, nullptr), local_t->m_hour((new Array({})), nullptr, nullptr), local_t->m_min((new Array({})), nullptr, nullptr), local_t->m_sec((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_to_i((new Array({})), nullptr, nullptr)->m_minus((new Array({utc_t->m_to_i((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) : (((truthy(local_t->m_respond_to_q((new Array({intern("to_i")})), nullptr, nullptr)) ? ((local_t->m_to_i((new Array({})), nullptr, nullptr)->m_minus((new Array({utc_t->m_to_i((new Array({})), nullptr, nullptr)})), nullptr, nullptr))) : (((new Integer(0LL))))))));
  return nil_instance();
}

inline BasicObject* Time_eigenclass::m__coerce_tz_arg(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* tz = array_at(args, 0);
  Proc* _block = block;
  if (truthy(tz->m_nil_q((new Array({})), nullptr, nullptr))) {
    return nil_instance();
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = tz->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (tz->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)); }()); return truthy(_l) ? _l : (tz->m_is_a_q((new Array({(&Rational_CLASS)})), nullptr, nullptr)); }()); return truthy(_l) ? _l : (tz->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)); }()))) {
    return tz;
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = tz->m_respond_to_q((new Array({intern("utc_to_local")})), nullptr, nullptr); return truthy(_l) ? _l : (tz->m_respond_to_q((new Array({intern("local_to_utc")})), nullptr, nullptr)); }()))) {
    return tz;
  }
  if (truthy(tz->m_respond_to_q((new Array({intern("to_str")})), nullptr, nullptr))) {
    return tz->m_to_str((new Array({})), nullptr, nullptr);
  }
  if (truthy(tz->m_respond_to_q((new Array({intern("to_r")})), nullptr, nullptr))) {
    return tz->m_to_r((new Array({})), nullptr, nullptr);
  }
  if (truthy(tz->m_respond_to_q((new Array({intern("to_int")})), nullptr, nullptr))) {
    return tz->m_to_int((new Array({})), nullptr, nullptr);
  }
  return ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("can't convert ", 14))})), nullptr, nullptr)->m_plus((new Array({(tz->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into an exact number", 21))})), nullptr, nullptr)))); }());
  return nil_instance();
}

inline BasicObject* Time_eigenclass::m__coerce_int_arg(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* a = array_at(args, 0);
  Proc* _block = block;
  if (truthy(a->m_nil_q((new Array({})), nullptr, nullptr))) {
    return nil_instance();
  }
  if (truthy(([&]() -> BasicObject* { auto* _l = ([&]() -> BasicObject* { auto* _l = a->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (a->m_is_a_q((new Array({(&Float_CLASS)})), nullptr, nullptr)); }()); return truthy(_l) ? _l : (a->m_is_a_q((new Array({(&Rational_CLASS)})), nullptr, nullptr)); }()))) {
    return a->m_to_i((new Array({})), nullptr, nullptr);
  }
  if (truthy(a->m_respond_to_q((new Array({intern("to_int")})), nullptr, nullptr))) {
    return a->m_to_int((new Array({})), nullptr, nullptr);
  }
  return ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("can't convert ", 14))})), nullptr, nullptr)->m_plus((new Array({(a->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into Integer", 13))})), nullptr, nullptr)))); }());
  return nil_instance();
}

inline BasicObject* Time_eigenclass::m__time_force_zone_b(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* t = array_at(args, 0);
  BasicObject* zone = array_at(args, 1);
  BasicObject* offset = (args->data.size() > 2) ? args->data[2] : (nil_instance());
  Proc* _block = block;
  return (truthy(this->m__time_zone_utc_q((new Array({zone})), nullptr, nullptr)) ? ((t->m_utc((new Array({})), nullptr, nullptr))) : ((truthy(([&]() -> BasicObject* { auto* _l = offset; return truthy(_l) ? _l : ((offset = this->m_zone_offset((new Array({zone})), nullptr, nullptr))); }())) ? ((t->m_localtime((new Array({})), nullptr, nullptr), (truthy(t->m_utc_offset((new Array({})), nullptr, nullptr)->m_ne_q((new Array({offset})), nullptr, nullptr)) ? ((t->m_localtime((new Array({offset})), nullptr, nullptr))) : (nil_instance())))) : ((t->m_localtime((new Array({})), nullptr, nullptr))))));
  return nil_instance();
}

inline BasicObject* Fiber_eigenclass::m_scheduler(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->iv___scheduler__;
  return nil_instance();
}

inline BasicObject* Fiber_eigenclass::m_set_scheduler(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* scheduler = array_at(args, 0);
  Proc* _block = block;
  if (truthy(scheduler->m_nil_q((new Array({})), nullptr, nullptr))) {
    (this->iv___scheduler__ = nil_instance());
    return nil_instance();
  }
  (new Array({intern("block"), intern("unblock"), intern("kernel_sleep"), intern("io_wait")}))->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* m = arg; return (truthy(scheduler->m_respond_to_q((new Array({m})), nullptr, nullptr)) ? (nil_instance()) : ((([&]() -> BasicObject* { throw (new ArgumentError(((new String("", 0))->m_plus((new Array({(new String("Scheduler must implement #", 26))})), nullptr, nullptr)->m_plus((new Array({(m)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))); }())))); })));
  return (this->iv___scheduler__ = scheduler);
  return nil_instance();
}

inline BasicObject* Thread_eigenclass::m_handle_interrupt(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* _config = array_at(args, 0);
  Proc* _block = block;
  return block->m_call((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Thread_eigenclass::m_pending_interrupt_q(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* _exc = (args->data.size() > 0) ? args->data[0] : (nil_instance());
  Proc* _block = block;
  return false_instance();
  return nil_instance();
}

inline BasicObject* Thread_eigenclass::m_exit(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (&Thread_CLASS)->m_current((new Array({})), nullptr, nullptr)->m_kill((new Array({})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* Thread_eigenclass::m_each_caller_location(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* locs = nil_instance();
  if (truthy(block)) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new LocalJumpError((new String("no block given", 14)))); }());
  }
  locs = this->m_caller_locations((new Array({(new Integer(2LL))})), nullptr, nullptr);
  locs->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* loc = arg; return block->m_call((new Array({loc})), nullptr, nullptr); })));
  return nil_instance();
  return nil_instance();
}

inline BasicObject* Thread_eigenclass::m_allocate(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { throw (new TypeError((new String("allocating Thread is not allowed", 32)))); }());
  return nil_instance();
}

inline BasicObject* Thread_eigenclass::m_new_main_thread(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* t = nil_instance();
  t = this->m___allocate_thread((new Array({})), nullptr, nullptr);
  t->m___init_main((new Array({})), nullptr, nullptr);
  return t;
  return nil_instance();
}

inline BasicObject* Process_eigenclass::m__fork(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { throw (new NotImplementedError((new String("fork() function is unimplemented on this machine", 48)))); }());
  return nil_instance();
}

inline BasicObject* Process_eigenclass::m_fork(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  BasicObject* pid = nil_instance();
  pid = this->m__fork((new Array({})), nullptr, nullptr);
  if (truthy(pid->m_nil_q((new Array({})), nullptr, nullptr))) {
    if (truthy(block)) {
      block->m_call((new Array({})), nullptr, nullptr);
    }
    this->m_exit_b((new Array({(new Integer(0LL))})), nullptr, nullptr);
  }
  return pid;
  return nil_instance();
}

inline BasicObject* Process_eigenclass::m_uid_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* id = array_at(args, 0);
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = id->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (id->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)); }()))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("can't convert ", 14))})), nullptr, nullptr)->m_plus((new Array({(id->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into Integer", 13))})), nullptr, nullptr)))); }());
  }
  return ([&]() -> BasicObject* { throw (new Errno_EPERM((new String("Operation not permitted", 23)))); }());
  return nil_instance();
}

inline BasicObject* Process_eigenclass::m_gid_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* id = array_at(args, 0);
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = id->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (id->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)); }()))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("can't convert ", 14))})), nullptr, nullptr)->m_plus((new Array({(id->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into Integer", 13))})), nullptr, nullptr)))); }());
  }
  return ([&]() -> BasicObject* { throw (new Errno_EPERM((new String("Operation not permitted", 23)))); }());
  return nil_instance();
}

inline BasicObject* Process_eigenclass::m_euid_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* id = array_at(args, 0);
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = id->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (id->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)); }()))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("can't convert ", 14))})), nullptr, nullptr)->m_plus((new Array({(id->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into Integer", 13))})), nullptr, nullptr)))); }());
  }
  return ([&]() -> BasicObject* { throw (new Errno_EPERM((new String("Operation not permitted", 23)))); }());
  return nil_instance();
}

inline BasicObject* Process_eigenclass::m_egid_set(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* id = array_at(args, 0);
  Proc* _block = block;
  if (truthy(([&]() -> BasicObject* { auto* _l = id->m_is_a_q((new Array({(&Integer_CLASS)})), nullptr, nullptr); return truthy(_l) ? _l : (id->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)); }()))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("can't convert ", 14))})), nullptr, nullptr)->m_plus((new Array({(id->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into Integer", 13))})), nullptr, nullptr)))); }());
  }
  return ([&]() -> BasicObject* { throw (new Errno_EPERM((new String("Operation not permitted", 23)))); }());
  return nil_instance();
}

inline BasicObject* Process_eigenclass::m_detach(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* pid = array_at(args, 0);
  Proc* _block = block;
  pid = this->m___coerce_to_int__((new Array({pid})), nullptr, nullptr);
  return (new Thread(static_cast<BasicObject*>(pid)));
  return nil_instance();
}

inline BasicObject* PP_eigenclass::m_width_for(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* _out = array_at(args, 0);
  Proc* _block = block;
  return (new Integer(80LL));
  return nil_instance();
}

inline BasicObject* Struct_eigenclass::m_members(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return (new Array({}));
  return nil_instance();
}

inline BasicObject* Data_eigenclass::m_members(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return ([&]() -> BasicObject* { auto* _l = this->iv_data_members; return truthy(_l) ? _l : ((new Array({}))); }());
  return nil_instance();
}

inline BasicObject* Data_eigenclass::m_define(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* members = args;  // *rest = whole args
  Proc* _block = block;
  BasicObject* syms = nil_instance();
  BasicObject* seen = nil_instance();
  BasicObject* klass = nil_instance();
  syms = members->m_map((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* m = arg; return ([&]() -> BasicObject* { auto* _subj = m; if (truthy((&Symbol_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (m); if (truthy((&String_CLASS)->m_case_eq((new Array({_subj})), nullptr, nullptr))) return (m->m_to_sym((new Array({})), nullptr, nullptr)); return (([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(m->m_inspect((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" is not a Symbol", 16))})), nullptr, nullptr)))); }())); }()); })));
  seen = (new Hash({}));
  syms->m_each((new Array({})), nullptr, (new Proc([&](BasicObject* arg) -> BasicObject* { BasicObject* s = arg; (truthy(seen->m_aref((new Array({s})), nullptr, nullptr)) ? ((([&]() -> BasicObject* { throw (new ArgumentError(((new String("", 0))->m_plus((new Array({(new String("duplicate member: ", 18))})), nullptr, nullptr)->m_plus((new Array({(s)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))); }()))) : (nil_instance())); return seen->m_aset((new Array({s, true_instance()})), nullptr, nullptr); })));
  klass = (new Class(static_cast<BasicObject*>(this)));
  if (truthy(block)) {
    klass->m_class_eval((new Array({})), nullptr, static_cast<Proc*>(block));
  }
  return klass;
  return nil_instance();
}

inline BasicObject* Set_eigenclass::m_aref(Array* args, Hash* kwargs, Proc* block) {
  Proc* _block = block;
  return this->m_new((new Array({args})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* ENVClass_eigenclass::m___coerce_key(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* key = array_at(args, 0);
  Proc* _block = block;
  return this->m___coerce_env_string__((new Array({key, intern("key")})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* ENVClass_eigenclass::m___coerce_value(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* val = array_at(args, 0);
  Proc* _block = block;
  return this->m___coerce_env_string__((new Array({val, intern("value")})), nullptr, nullptr);
  return nil_instance();
}

inline BasicObject* ENVClass_eigenclass::m___coerce_env_string__(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* val = array_at(args, 0);
  BasicObject* role = array_at(args, 1);
  Proc* _block = block;
  BasicObject* result = nil_instance();
  if (truthy(val->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr))) {
    return val;
  }
  if (truthy(val->m_respond_to_q((new Array({intern("to_str")})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of ", 26))})), nullptr, nullptr)->m_plus((new Array({(val->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into String", 12))})), nullptr, nullptr)))); }());
  }
  result = val->m_to_str((new Array({})), nullptr, nullptr);
  if (truthy(result->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr))) {
    nil_instance();
  } else {
    ([&]() -> BasicObject* { throw (new TypeError(((new String("", 0))->m_plus((new Array({(new String("no implicit conversion of ", 26))})), nullptr, nullptr)->m_plus((new Array({(result->m_class((new Array({})), nullptr, nullptr))->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)->m_plus((new Array({(new String(" into String", 12))})), nullptr, nullptr)))); }());
  }
  return result;
  return nil_instance();
}

inline BasicObject* ENVClass_eigenclass::m___validate_key(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* key = array_at(args, 0);
  Proc* _block = block;
  if (truthy(key->m_empty_q((new Array({})), nullptr, nullptr))) {
    ([&]() -> BasicObject* { throw (new Errno_EINVAL(((new String("", 0))->m_plus((new Array({(new String("Invalid argument - ", 19))})), nullptr, nullptr)->m_plus((new Array({(key)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))); }());
  }
  return (truthy(key->m_include_q((new Array({(new String("=", 1))})), nullptr, nullptr)) ? ((([&]() -> BasicObject* { throw (new Errno_EINVAL(((new String("", 0))->m_plus((new Array({(new String("Invalid argument - ", 19))})), nullptr, nullptr)->m_plus((new Array({(key)->m_to_s((new Array({})), nullptr, nullptr)})), nullptr, nullptr)))); }()))) : (nil_instance()));
  return nil_instance();
}

inline BasicObject* ENVClass_eigenclass::m___enc(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* str = array_at(args, 0);
  Proc* _block = block;
  BasicObject* locale_enc = nil_instance();
  BasicObject* internal = nil_instance();
  if (truthy(str->m_nil_q((new Array({})), nullptr, nullptr))) {
    return str;
  }
  locale_enc = (&Encoding_CLASS)->m_find((new Array({(new String("locale", 6))})), nullptr, nullptr);
  ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return (str = str->m_encode((new Array({locale_enc})), nullptr, nullptr));  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return (str = str->m_dup((new Array({})), nullptr, nullptr)->m_force_encoding((new Array({locale_enc})), nullptr, nullptr));  return nil_instance(); }(); } throw; } }());
  internal = (&Encoding_CLASS)->m_default_internal((new Array({})), nullptr, nullptr);
  if (truthy(internal)) {
    ([&]() -> BasicObject* { try { return [&]() -> BasicObject* { return (str = str->m_encode((new Array({internal})), nullptr, nullptr));  return nil_instance(); }(); } catch (Exception* e_) { if (dynamic_cast<StandardError*>(e_) != nullptr) { return [&]() -> BasicObject* { return nil_instance();  return nil_instance(); }(); } throw; } }());
  }
  return str;
  return nil_instance();
}

inline BasicObject* ENVClass_eigenclass::m___soft_coerce_string__(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* val = array_at(args, 0);
  Proc* _block = block;
  BasicObject* result = nil_instance();
  if (truthy(val->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr))) {
    return val;
  }
  if (truthy(val->m_respond_to_q((new Array({intern("to_str")})), nullptr, nullptr))) {
    nil_instance();
  } else {
    return nil_instance();
  }
  result = val->m_to_str((new Array({})), nullptr, nullptr);
  return (truthy(result->m_is_a_q((new Array({(&String_CLASS)})), nullptr, nullptr)) ? ((result)) : ((nil_instance())));
  return nil_instance();
}

inline BasicObject* Gem_Specification_eigenclass::m_flat_map(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* __anon_rest__ = args;  // *rest = whole args
  Proc* _block = block;
  return (new Array({}));
  return nil_instance();
}

inline BasicObject* Gem_Specification_eigenclass::m_each(Array* args, Hash* kwargs, Proc* block) {
  BasicObject* __anon_rest__ = args;  // *rest = whole args
  Proc* _block = block;
  return nil_instance();
  return nil_instance();
}

inline BasicObject* nil_instance() {
  return static_cast<BasicObject*>(&NIL_INSTANCE);
}

inline BasicObject* true_instance() {
  return static_cast<BasicObject*>(&TRUE_INSTANCE);
}

inline BasicObject* false_instance() {
  return static_cast<BasicObject*>(&FALSE_INSTANCE);
}

inline BasicObject* boxed_bool(bool b) {
  return b ? true_instance() : false_instance();
}

inline bool truthy(BasicObject* o) {
  return o != nil_instance() && o != false_instance();
}

inline void ruby_puts(BasicObject* o) {
  if (auto* i = dynamic_cast<Integer*>(o))      { std::printf("%lld\n", static_cast<long long>(i->raw_)); return; }
  if (auto* f = dynamic_cast<Float*>(o))        { std::printf("%g\n", f->raw_); return; }
  if (auto* s = dynamic_cast<Symbol*>(o))       { std::printf("%s\n", s->name_); return; }
  if (auto* str = dynamic_cast<String*>(o))     { std::fwrite(str->bytes.data(), 1, str->bytes.size(), stdout); std::putchar('\n'); return; }
  if (o == true_instance())                      { std::printf("true\n"); return; }
  if (o == false_instance())                     { std::printf("false\n"); return; }
  if (o == nil_instance())                       { std::printf("\n"); return; }
  std::printf("(unprintable: %s)\n", o->ruby_class_name());
}

inline Symbol* intern(const char* name) {
  using Tab = std::unordered_map<std::string, Symbol*,
    std::hash<std::string>, std::equal_to<std::string>,
    GcAllocator<std::pair<const std::string, Symbol*>>>;
  static Tab table;
  auto it = table.find(name);
  if (it != table.end()) return it->second;
  Symbol* s = new Symbol(name);
  table[std::string(name)] = s;
  return s;
}

inline BasicObject* array_at(Array* a, std::size_t i) {
  return a->data[i];
}

inline BasicObject* k_STDOUT() {
  static BasicObject* val = new IO(); return val;
}

inline BasicObject* k_STDERR() {
  static BasicObject* val = new IO(); return val;
}

inline BasicObject* k_STDIN() {
  static BasicObject* val = new IO(); return val;
}

inline BasicObject* k_ENV() {
  static BasicObject* val = new ENVClass(); return val;
}

inline BasicObject* k_ARGF() {
  static BasicObject* val = new IO(); return val;
}

struct MainObject : Object {
  const char* ruby_class_name() const override { return "MainObject"; }

  virtual BasicObject* m_run_benchmark(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {
    BasicObject* __anon_rest__ = args;  // *rest = whole args
    Proc* _block = block;
    Proc* __anon_block__ = block;
    return nil_instance();
    return nil_instance();
  }

  void __top_level__() {
    BasicObject* a = (new String("hello", 5));
    BasicObject* b = (new String("world", 5));
    BasicObject* c = a->m_plus((new Array({(new String(" ", 1))})), nullptr, nullptr)->m_plus((new Array({b})), nullptr, nullptr);
    (ruby_puts(c), nil_instance());
    a->m_lshift((new Array({(new String(" there", 6))})), nullptr, nullptr);
    (ruby_puts(a), nil_instance());
    (ruby_puts((new String("abc", 3))->m_length((new Array({})), nullptr, nullptr)), nil_instance());
    (ruby_puts((new String("abc", 3))->m_bytesize((new Array({})), nullptr, nullptr)), nil_instance());
    (ruby_puts((new String("abc", 3))->m_eq_q((new Array({(new String("abc", 3))})), nullptr, nullptr)), nil_instance());
    (ruby_puts((new String("abc", 3))->m_eq_q((new Array({(new String("abd", 3))})), nullptr, nullptr)), nil_instance());
    (ruby_puts((new String("abc", 3))->m_lt((new Array({(new String("abd", 3))})), nullptr, nullptr)), nil_instance());
    (ruby_puts((new String("hello", 5))->m_aref((new Array({(new Integer(0LL))})), nullptr, nullptr)), nil_instance());
    (ruby_puts((new String("hello", 5))->m_aref((new Array({(new Integer(-1LL))})), nullptr, nullptr)), nil_instance());
    BasicObject* h = (new Hash({{(new String("foo", 3)), (new Integer(1LL))}, {(new String("bar", 3)), (new Integer(2LL))}}));
    (ruby_puts(h->m_aref((new Array({(new String("foo", 3))})), nullptr, nullptr)), nil_instance());
    (ruby_puts(h->m_aref((new Array({(new String("bar", 3))})), nullptr, nullptr)), nil_instance());
    (ruby_puts((new String("", 0))->m_empty_q((new Array({})), nullptr, nullptr)), nil_instance());
    (ruby_puts((new String("x", 1))->m_empty_q((new Array({})), nullptr, nullptr)), nil_instance());
  }
};

}  // namespace Ruby

int main() {
  FROZONE_GC_INIT();
  Ruby::MainObject mo;
  mo.__top_level__();
  return 0;
}
