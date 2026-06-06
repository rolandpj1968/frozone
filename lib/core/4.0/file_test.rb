module FileTest
  DELEGATED = %i[
    blockdev? chardev? directory? executable? executable_real?
    exist? file? grpowned? identical? owned? pipe? readable?
    readable_real? setgid? setuid? size size? socket? sticky?
    symlink? world_readable? world_writable? writable? writable_real? zero?
  ].freeze

  DELEGATED.each do |m|
    define_method(m) { |*args| File.send(m, *args) }
  end
  module_function(*DELEGATED)
end
