abstract class OrtFlags {
  int get value;
}

enum CPUFlags implements OrtFlags {
  useNone(0x000),
  useArena(0x001);

  final int _value;

  const CPUFlags(this._value);

  @override
  int get value => _value;
}

enum NnapiFlags implements OrtFlags {
  useNone(0x000),
  useFp16(0x001),
  useNCHW(0x002),
  cpuDisabled(0x004),
  cpuOnly(0x008);

  final int _value;

  const NnapiFlags(this._value);

  @override
  int get value => _value;
}

enum CoreMLFlags implements OrtFlags {
  useNone(0x000),
  useCpuOnly(0x001),
  enableOnSubgraph(0x002),
  onlyEnableDeviceWithANE(0x004);

  final int _value;

  const CoreMLFlags(this._value);

  @override
  int get value => _value;
}