var global = globalThis;
(() => {
  // node_modules/avr8js/dist/esm/cpu.js
  var registerSpace = 256;
  var CPU = class {
    constructor(progMem, sramBytes = 8192) {
      this.progMem = progMem;
      this.sramBytes = sramBytes;
      this.data = new Uint8Array(this.sramBytes + registerSpace);
      this.data16 = new Uint16Array(this.data.buffer);
      this.dataView = new DataView(this.data.buffer);
      this.progBytes = new Uint8Array(this.progMem.buffer);
      this.writeHooks = [];
      this.pc = 0;
      this.cycles = 0;
      this.reset();
    }
    reset() {
      this.data.fill(0);
      this.SP = this.data.length - 1;
    }
    readData(addr) {
      return this.data[addr];
    }
    writeData(addr, value) {
      const hook = this.writeHooks[addr];
      if (hook) {
        if (hook(value, this.data[addr], addr)) {
          return;
        }
      }
      this.data[addr] = value;
    }
    get SP() {
      return this.dataView.getUint16(93, true);
    }
    set SP(value) {
      this.dataView.setUint16(93, value, true);
    }
    get SREG() {
      return this.data[95];
    }
    get interruptsEnabled() {
      return this.SREG & 128 ? true : false;
    }
  };

  // node_modules/avr8js/dist/esm/instruction.js
  function isTwoWordInstruction(opcode) {
    return (
      /* LDS */
      (opcode & 65039) === 36864 || /* STS */
      (opcode & 65039) === 37376 || /* CALL */
      (opcode & 65038) === 37902 || /* JMP */
      (opcode & 65038) === 37900
    );
  }
  function avrInstruction(cpu) {
    const opcode = cpu.progMem[cpu.pc];
    if ((opcode & 64512) === 7168) {
      const d = cpu.data[(opcode & 496) >> 4];
      const r = cpu.data[opcode & 15 | (opcode & 512) >> 5];
      const sum = d + r + (cpu.data[95] & 1);
      const R = sum & 255;
      cpu.data[(opcode & 496) >> 4] = R;
      let sreg = cpu.data[95] & 192;
      sreg |= R ? 0 : 2;
      sreg |= 128 & R ? 4 : 0;
      sreg |= (R ^ r) & (d ^ R) & 128 ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      sreg |= sum & 256 ? 1 : 0;
      sreg |= 1 & (d & r | r & ~R | ~R & d) ? 32 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 64512) === 3072) {
      const d = cpu.data[(opcode & 496) >> 4];
      const r = cpu.data[opcode & 15 | (opcode & 512) >> 5];
      const R = d + r & 255;
      cpu.data[(opcode & 496) >> 4] = R;
      let sreg = cpu.data[95] & 192;
      sreg |= R ? 0 : 2;
      sreg |= 128 & R ? 4 : 0;
      sreg |= (R ^ r) & (R ^ d) & 128 ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      sreg |= d + r & 256 ? 1 : 0;
      sreg |= 1 & (d & r | r & ~R | ~R & d) ? 32 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 65280) === 38400) {
      const addr = 2 * ((opcode & 48) >> 4) + 24;
      const value = cpu.dataView.getUint16(addr, true);
      const R = value + (opcode & 15 | (opcode & 192) >> 2) & 65535;
      cpu.dataView.setUint16(addr, R, true);
      let sreg = cpu.data[95] & 224;
      sreg |= R ? 0 : 2;
      sreg |= 32768 & R ? 4 : 0;
      sreg |= ~value & R & 32768 ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      sreg |= ~R & value & 32768 ? 1 : 0;
      cpu.data[95] = sreg;
      cpu.cycles++;
    }
    if ((opcode & 64512) === 8192) {
      const R = cpu.data[(opcode & 496) >> 4] & cpu.data[opcode & 15 | (opcode & 512) >> 5];
      cpu.data[(opcode & 496) >> 4] = R;
      let sreg = cpu.data[95] & 225;
      sreg |= R ? 0 : 2;
      sreg |= 128 & R ? 4 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 61440) === 28672) {
      const R = cpu.data[((opcode & 240) >> 4) + 16] & (opcode & 15 | (opcode & 3840) >> 4);
      cpu.data[((opcode & 240) >> 4) + 16] = R;
      let sreg = cpu.data[95] & 225;
      sreg |= R ? 0 : 2;
      sreg |= 128 & R ? 4 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 65039) === 37893) {
      const value = cpu.data[(opcode & 496) >> 4];
      const R = value >>> 1 | 128 & value;
      cpu.data[(opcode & 496) >> 4] = R;
      let sreg = cpu.data[95] & 224;
      sreg |= R ? 0 : 2;
      sreg |= 128 & R ? 4 : 0;
      sreg |= value & 1;
      sreg |= sreg >> 2 & 1 ^ sreg & 1 ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 65423) === 38024) {
      cpu.data[95] &= ~(1 << ((opcode & 112) >> 4));
    }
    if ((opcode & 65032) === 63488) {
      const b = opcode & 7;
      const d = (opcode & 496) >> 4;
      cpu.data[d] = ~(1 << b) & cpu.data[d] | (cpu.data[95] >> 6 & 1) << b;
    }
    if ((opcode & 64512) === 62464) {
      if (!(cpu.data[95] & 1 << (opcode & 7))) {
        cpu.pc = cpu.pc + (((opcode & 504) >> 3) - (opcode & 512 ? 64 : 0));
        cpu.cycles++;
      }
    }
    if ((opcode & 64512) === 61440) {
      if (cpu.data[95] & 1 << (opcode & 7)) {
        cpu.pc = cpu.pc + (((opcode & 504) >> 3) - (opcode & 512 ? 64 : 0));
        cpu.cycles++;
      }
    }
    if ((opcode & 65423) === 37896) {
      cpu.data[95] |= 1 << ((opcode & 112) >> 4);
    }
    if ((opcode & 65032) === 64e3) {
      const d = cpu.data[(opcode & 496) >> 4];
      const b = opcode & 7;
      cpu.data[95] = cpu.data[95] & 191 | (d >> b & 1 ? 64 : 0);
    }
    if ((opcode & 65038) === 37902) {
      const k = cpu.progMem[cpu.pc + 1] | (opcode & 1) << 16 | (opcode & 496) << 13;
      const ret = cpu.pc + 2;
      const sp = cpu.dataView.getUint16(93, true);
      cpu.data[sp] = 255 & ret;
      cpu.data[sp - 1] = ret >> 8 & 255;
      cpu.dataView.setUint16(93, sp - 2, true);
      cpu.pc = k - 1;
      cpu.cycles += 4;
    }
    if ((opcode & 65280) === 38912) {
      const A = opcode & 248;
      const b = opcode & 7;
      const R = cpu.readData((A >> 3) + 32);
      cpu.writeData((A >> 3) + 32, R & ~(1 << b));
    }
    if ((opcode & 65039) === 37888) {
      const d = (opcode & 496) >> 4;
      const R = 255 - cpu.data[d];
      cpu.data[d] = R;
      let sreg = cpu.data[95] & 225 | 1;
      sreg |= R ? 0 : 2;
      sreg |= 128 & R ? 4 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 64512) === 5120) {
      const val1 = cpu.data[(opcode & 496) >> 4];
      const val2 = cpu.data[opcode & 15 | (opcode & 512) >> 5];
      const R = val1 - val2;
      let sreg = cpu.data[95] & 192;
      sreg |= R ? 0 : 2;
      sreg |= 128 & R ? 4 : 0;
      sreg |= 0 !== ((val1 ^ val2) & (val1 ^ R) & 128) ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      sreg |= val2 > val1 ? 1 : 0;
      sreg |= 1 & (~val1 & val2 | val2 & R | R & ~val1) ? 32 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 64512) === 1024) {
      const arg1 = cpu.data[(opcode & 496) >> 4];
      const arg2 = cpu.data[opcode & 15 | (opcode & 512) >> 5];
      let sreg = cpu.data[95];
      const r = arg1 - arg2 - (sreg & 1);
      sreg = sreg & 192 | (!r && sreg >> 1 & 1 ? 2 : 0) | (arg2 + (sreg & 1) > arg1 ? 1 : 0);
      sreg |= 128 & r ? 4 : 0;
      sreg |= (arg1 ^ arg2) & (arg1 ^ r) & 128 ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      sreg |= 1 & (~arg1 & arg2 | arg2 & r | r & ~arg1) ? 32 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 61440) === 12288) {
      const arg1 = cpu.data[((opcode & 240) >> 4) + 16];
      const arg2 = opcode & 15 | (opcode & 3840) >> 4;
      const r = arg1 - arg2;
      let sreg = cpu.data[95] & 192;
      sreg |= r ? 0 : 2;
      sreg |= 128 & r ? 4 : 0;
      sreg |= (arg1 ^ arg2) & (arg1 ^ r) & 128 ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      sreg |= arg2 > arg1 ? 1 : 0;
      sreg |= 1 & (~arg1 & arg2 | arg2 & r | r & ~arg1) ? 32 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 64512) === 4096) {
      if (cpu.data[(opcode & 496) >> 4] === cpu.data[opcode & 15 | (opcode & 512) >> 5]) {
        const nextOpcode = cpu.progMem[cpu.pc + 1];
        const skipSize = isTwoWordInstruction(nextOpcode) ? 2 : 1;
        cpu.pc += skipSize;
        cpu.cycles += skipSize;
      }
    }
    if ((opcode & 65039) === 37898) {
      const value = cpu.data[(opcode & 496) >> 4];
      const R = value - 1;
      cpu.data[(opcode & 496) >> 4] = R;
      let sreg = cpu.data[95] & 225;
      sreg |= R ? 0 : 2;
      sreg |= 128 & R ? 4 : 0;
      sreg |= 128 === value ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 64512) === 9216) {
      const R = cpu.data[(opcode & 496) >> 4] ^ cpu.data[opcode & 15 | (opcode & 512) >> 5];
      cpu.data[(opcode & 496) >> 4] = R;
      let sreg = cpu.data[95] & 225;
      sreg |= R ? 0 : 2;
      sreg |= 128 & R ? 4 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 65416) === 776) {
      const v1 = cpu.data[((opcode & 112) >> 4) + 16];
      const v2 = cpu.data[(opcode & 7) + 16];
      const R = v1 * v2 << 1;
      cpu.dataView.setUint16(0, R, true);
      cpu.data[95] = cpu.data[95] & 252 | (65535 & R ? 0 : 2) | (v1 * v2 & 32768 ? 1 : 0);
      cpu.cycles++;
    }
    if ((opcode & 65416) === 896) {
      const v1 = cpu.dataView.getInt8(((opcode & 112) >> 4) + 16);
      const v2 = cpu.dataView.getInt8((opcode & 7) + 16);
      const R = v1 * v2 << 1;
      cpu.dataView.setInt16(0, R, true);
      cpu.data[95] = cpu.data[95] & 252 | (65535 & R ? 0 : 2) | (v1 * v2 & 32768 ? 1 : 0);
      cpu.cycles++;
    }
    if ((opcode & 65416) === 904) {
      const v1 = cpu.dataView.getInt8(((opcode & 112) >> 4) + 16);
      const v2 = cpu.data[(opcode & 7) + 16];
      const R = v1 * v2 << 1;
      cpu.dataView.setInt16(0, R, true);
      cpu.data[95] = cpu.data[95] & 252 | (65535 & R ? 2 : 0) | (v1 * v2 & 32768 ? 1 : 0);
      cpu.cycles++;
    }
    if (opcode === 38153) {
      const retAddr = cpu.pc + 1;
      const sp = cpu.dataView.getUint16(93, true);
      cpu.data[sp] = retAddr & 255;
      cpu.data[sp - 1] = retAddr >> 8 & 255;
      cpu.dataView.setUint16(93, sp - 2, true);
      cpu.pc = cpu.dataView.getUint16(30, true) - 1;
      cpu.cycles += 2;
    }
    if (opcode === 37897) {
      cpu.pc = cpu.dataView.getUint16(30, true) - 1;
      cpu.cycles++;
    }
    if ((opcode & 63488) === 45056) {
      const i = cpu.readData((opcode & 15 | (opcode & 1536) >> 5) + 32);
      cpu.data[(opcode & 496) >> 4] = i;
    }
    if ((opcode & 65039) === 37891) {
      const d = cpu.data[(opcode & 496) >> 4];
      const r = d + 1 & 255;
      cpu.data[(opcode & 496) >> 4] = r;
      let sreg = cpu.data[95] & 225;
      sreg |= r ? 0 : 2;
      sreg |= 128 & r ? 4 : 0;
      sreg |= 127 === d ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 65038) === 37900) {
      cpu.pc = (cpu.progMem[cpu.pc + 1] | (opcode & 1) << 16 | (opcode & 496) << 13) - 1;
      cpu.cycles += 2;
    }
    if ((opcode & 65039) === 37382) {
      const r = (opcode & 496) >> 4;
      const clear = cpu.data[r];
      const value = cpu.readData(cpu.dataView.getUint16(30, true));
      cpu.writeData(cpu.dataView.getUint16(30, true), value & 255 - clear);
      cpu.data[r] = value;
    }
    if ((opcode & 65039) === 37381) {
      const r = (opcode & 496) >> 4;
      const set = cpu.data[r];
      const value = cpu.readData(cpu.dataView.getUint16(30, true));
      cpu.writeData(cpu.dataView.getUint16(30, true), value | set);
      cpu.data[r] = value;
    }
    if ((opcode & 65039) === 37383) {
      const r = cpu.data[(opcode & 496) >> 4];
      const R = cpu.readData(cpu.dataView.getUint16(30, true));
      cpu.writeData(cpu.dataView.getUint16(30, true), r ^ R);
      cpu.data[(opcode & 496) >> 4] = R;
    }
    if ((opcode & 61440) === 57344) {
      cpu.data[((opcode & 240) >> 4) + 16] = opcode & 15 | (opcode & 3840) >> 4;
    }
    if ((opcode & 65039) === 36864) {
      const value = cpu.readData(cpu.progMem[cpu.pc + 1]);
      cpu.data[(opcode & 496) >> 4] = value;
      cpu.pc++;
      cpu.cycles++;
    }
    if ((opcode & 65039) === 36876) {
      cpu.data[(opcode & 496) >> 4] = cpu.readData(cpu.dataView.getUint16(26, true));
    }
    if ((opcode & 65039) === 36877) {
      const x = cpu.dataView.getUint16(26, true);
      cpu.data[(opcode & 496) >> 4] = cpu.readData(x);
      cpu.dataView.setUint16(26, x + 1, true);
      cpu.cycles++;
    }
    if ((opcode & 65039) === 36878) {
      const x = cpu.dataView.getUint16(26, true) - 1;
      cpu.dataView.setUint16(26, x, true);
      cpu.data[(opcode & 496) >> 4] = cpu.readData(x);
      cpu.cycles += 2;
    }
    if ((opcode & 65039) === 32776) {
      cpu.data[(opcode & 496) >> 4] = cpu.readData(cpu.dataView.getUint16(28, true));
    }
    if ((opcode & 65039) === 36873) {
      const y = cpu.dataView.getUint16(28, true);
      cpu.data[(opcode & 496) >> 4] = cpu.readData(y);
      cpu.dataView.setUint16(28, y + 1, true);
      cpu.cycles++;
    }
    if ((opcode & 65039) === 36874) {
      const y = cpu.dataView.getUint16(28, true) - 1;
      cpu.dataView.setUint16(28, y, true);
      cpu.data[(opcode & 496) >> 4] = cpu.readData(y);
      cpu.cycles += 2;
    }
    if ((opcode & 53768) === 32776 && opcode & 7 | (opcode & 3072) >> 7 | (opcode & 8192) >> 8) {
      cpu.data[(opcode & 496) >> 4] = cpu.readData(cpu.dataView.getUint16(28, true) + (opcode & 7 | (opcode & 3072) >> 7 | (opcode & 8192) >> 8));
      cpu.cycles += 2;
    }
    if ((opcode & 65039) === 32768) {
      cpu.data[(opcode & 496) >> 4] = cpu.readData(cpu.dataView.getUint16(30, true));
    }
    if ((opcode & 65039) === 36865) {
      const z = cpu.dataView.getUint16(30, true);
      cpu.data[(opcode & 496) >> 4] = cpu.readData(z);
      cpu.dataView.setUint16(30, z + 1, true);
      cpu.cycles++;
    }
    if ((opcode & 65039) === 36866) {
      const z = cpu.dataView.getUint16(30, true) - 1;
      cpu.dataView.setUint16(30, z, true);
      cpu.data[(opcode & 496) >> 4] = cpu.readData(z);
      cpu.cycles += 2;
    }
    if ((opcode & 53768) === 32768 && opcode & 7 | (opcode & 3072) >> 7 | (opcode & 8192) >> 8) {
      cpu.data[(opcode & 496) >> 4] = cpu.readData(cpu.dataView.getUint16(30, true) + (opcode & 7 | (opcode & 3072) >> 7 | (opcode & 8192) >> 8));
      cpu.cycles += 2;
    }
    if (opcode === 38344) {
      cpu.data[0] = cpu.progBytes[cpu.dataView.getUint16(30, true)];
      cpu.cycles += 2;
    }
    if ((opcode & 65039) === 36868) {
      cpu.data[(opcode & 496) >> 4] = cpu.progBytes[cpu.dataView.getUint16(30, true)];
      cpu.cycles += 2;
    }
    if ((opcode & 65039) === 36869) {
      const i = cpu.dataView.getUint16(30, true);
      cpu.data[(opcode & 496) >> 4] = cpu.progBytes[i];
      cpu.dataView.setUint16(30, i + 1, true);
      cpu.cycles += 2;
    }
    if ((opcode & 65039) === 37894) {
      const value = cpu.data[(opcode & 496) >> 4];
      const R = value >>> 1;
      cpu.data[(opcode & 496) >> 4] = R;
      let sreg = cpu.data[95] & 224;
      sreg |= R ? 0 : 2;
      sreg |= value & 1;
      sreg |= sreg >> 2 & 1 ^ sreg & 1 ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 64512) === 11264) {
      cpu.data[(opcode & 496) >> 4] = cpu.data[opcode & 15 | (opcode & 512) >> 5];
    }
    if ((opcode & 65280) === 256) {
      const r2 = 2 * (opcode & 15);
      const d2 = 2 * ((opcode & 240) >> 4);
      cpu.data[d2] = cpu.data[r2];
      cpu.data[d2 + 1] = cpu.data[r2 + 1];
    }
    if ((opcode & 64512) === 39936) {
      const R = cpu.data[(opcode & 496) >> 4] * cpu.data[opcode & 15 | (opcode & 512) >> 5];
      cpu.dataView.setUint16(0, R, true);
      cpu.data[95] = cpu.data[95] & 252 | (65535 & R ? 0 : 2) | (32768 & R ? 1 : 0);
      cpu.cycles++;
    }
    if ((opcode & 65280) === 512) {
      const R = cpu.dataView.getInt8(((opcode & 240) >> 4) + 16) * cpu.dataView.getInt8((opcode & 15) + 16);
      cpu.dataView.setInt16(0, R, true);
      cpu.data[95] = cpu.data[95] & 252 | (65535 & R ? 0 : 2) | (32768 & R ? 1 : 0);
      cpu.cycles++;
    }
    if ((opcode & 65416) === 768) {
      const R = cpu.dataView.getInt8(((opcode & 112) >> 4) + 16) * cpu.data[(opcode & 7) + 16];
      cpu.dataView.setInt16(0, R, true);
      cpu.data[95] = cpu.data[95] & 252 | (65535 & R ? 0 : 2) | (32768 & R ? 1 : 0);
      cpu.cycles++;
    }
    if ((opcode & 65039) === 37889) {
      const d = (opcode & 496) >> 4;
      const value = cpu.data[d];
      const R = 0 - value;
      cpu.data[d] = R;
      let sreg = cpu.data[95] & 192;
      sreg |= R ? 0 : 2;
      sreg |= 128 & R ? 4 : 0;
      sreg |= 128 === R ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      sreg |= R ? 1 : 0;
      sreg |= 1 & (R | value) ? 32 : 0;
      cpu.data[95] = sreg;
    }
    if (opcode === 0) {
    }
    if ((opcode & 64512) === 10240) {
      const R = cpu.data[(opcode & 496) >> 4] | cpu.data[opcode & 15 | (opcode & 512) >> 5];
      cpu.data[(opcode & 496) >> 4] = R;
      let sreg = cpu.data[95] & 225;
      sreg |= R ? 0 : 2;
      sreg |= 128 & R ? 4 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 61440) === 24576) {
      const R = cpu.data[((opcode & 240) >> 4) + 16] | (opcode & 15 | (opcode & 3840) >> 4);
      cpu.data[((opcode & 240) >> 4) + 16] = R;
      let sreg = cpu.data[95] & 225;
      sreg |= R ? 0 : 2;
      sreg |= 128 & R ? 4 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 63488) === 47104) {
      cpu.writeData((opcode & 15 | (opcode & 1536) >> 5) + 32, cpu.data[(opcode & 496) >> 4]);
    }
    if ((opcode & 65039) === 36879) {
      const value = cpu.dataView.getUint16(93, true) + 1;
      cpu.dataView.setUint16(93, value, true);
      cpu.data[(opcode & 496) >> 4] = cpu.data[value];
      cpu.cycles++;
    }
    if ((opcode & 65039) === 37391) {
      const value = cpu.dataView.getUint16(93, true);
      cpu.data[value] = cpu.data[(opcode & 496) >> 4];
      cpu.dataView.setUint16(93, value - 1, true);
      cpu.cycles++;
    }
    if ((opcode & 61440) === 53248) {
      const k = (opcode & 2047) - (opcode & 2048 ? 2048 : 0);
      const retAddr = cpu.pc + 1;
      const sp = cpu.dataView.getUint16(93, true);
      cpu.data[sp] = 255 & retAddr;
      cpu.data[sp - 1] = retAddr >> 8 & 255;
      cpu.dataView.setUint16(93, sp - 2, true);
      cpu.pc += k;
      cpu.cycles += 3;
    }
    if (opcode === 38152) {
      const i = cpu.dataView.getUint16(93, true) + 2;
      cpu.dataView.setUint16(93, i, true);
      cpu.pc = (cpu.data[i - 1] << 8) + cpu.data[i] - 1;
      cpu.cycles += 4;
    }
    if (opcode === 38168) {
      const i = cpu.dataView.getUint16(93, true) + 2;
      cpu.dataView.setUint16(93, i, true);
      cpu.pc = (cpu.data[i - 1] << 8) + cpu.data[i] - 1;
      cpu.cycles += 4;
      cpu.data[95] |= 128;
    }
    if ((opcode & 61440) === 49152) {
      cpu.pc = cpu.pc + ((opcode & 2047) - (opcode & 2048 ? 2048 : 0));
      cpu.cycles++;
    }
    if ((opcode & 65039) === 37895) {
      const d = cpu.data[(opcode & 496) >> 4];
      const r = d >>> 1 | (cpu.data[95] & 1) << 7;
      cpu.data[(opcode & 496) >> 4] = r;
      let sreg = cpu.data[95] & 224;
      sreg |= r ? 0 : 2;
      sreg |= 128 & r ? 4 : 0;
      sreg |= 1 & d ? 1 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg & 1 ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 64512) === 2048) {
      const val1 = cpu.data[(opcode & 496) >> 4];
      const val2 = cpu.data[opcode & 15 | (opcode & 512) >> 5];
      let sreg = cpu.data[95];
      const R = val1 - val2 - (sreg & 1);
      cpu.data[(opcode & 496) >> 4] = R;
      sreg = sreg & 192 | (!R && sreg >> 1 & 1 ? 2 : 0) | (val2 + (sreg & 1) > val1 ? 1 : 0);
      sreg |= 128 & R ? 4 : 0;
      sreg |= (val1 ^ val2) & (val1 ^ R) & 128 ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      sreg |= 1 & (~val1 & val2 | val2 & R | R & ~val1) ? 32 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 61440) === 16384) {
      const val1 = cpu.data[((opcode & 240) >> 4) + 16];
      const val2 = opcode & 15 | (opcode & 3840) >> 4;
      let sreg = cpu.data[95];
      const R = val1 - val2 - (sreg & 1);
      cpu.data[((opcode & 240) >> 4) + 16] = R;
      sreg = sreg & 192 | (!R && sreg >> 1 & 1 ? 2 : 0) | (val2 + (sreg & 1) > val1 ? 1 : 0);
      sreg |= 128 & R ? 4 : 0;
      sreg |= (val1 ^ val2) & (val1 ^ R) & 128 ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      sreg |= 1 & (~val1 & val2 | val2 & R | R & ~val1) ? 32 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 65280) === 39424) {
      const target = ((opcode & 248) >> 3) + 32;
      cpu.writeData(target, cpu.readData(target) | 1 << (opcode & 7));
      cpu.cycles++;
    }
    if ((opcode & 65280) === 39168) {
      const value = cpu.readData(((opcode & 248) >> 3) + 32);
      if (!(value & 1 << (opcode & 7))) {
        const nextOpcode = cpu.progMem[cpu.pc + 1];
        const skipSize = isTwoWordInstruction(nextOpcode) ? 2 : 1;
        cpu.cycles += skipSize;
        cpu.pc += skipSize;
      }
    }
    if ((opcode & 65280) === 39680) {
      const value = cpu.readData(((opcode & 248) >> 3) + 32);
      if (value & 1 << (opcode & 7)) {
        const nextOpcode = cpu.progMem[cpu.pc + 1];
        const skipSize = isTwoWordInstruction(nextOpcode) ? 2 : 1;
        cpu.cycles += skipSize;
        cpu.pc += skipSize;
      }
    }
    if ((opcode & 65280) === 38656) {
      const i = 2 * ((opcode & 48) >> 4) + 24;
      const a = cpu.dataView.getUint16(i, true);
      const l = opcode & 15 | (opcode & 192) >> 2;
      const R = a - l;
      cpu.dataView.setUint16(i, R, true);
      let sreg = cpu.data[95] & 192;
      sreg |= R ? 0 : 2;
      sreg |= 32768 & R ? 4 : 0;
      sreg |= a & ~R & 32768 ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      sreg |= l > a ? 1 : 0;
      sreg |= 1 & (~a & l | l & R | R & ~a) ? 32 : 0;
      cpu.data[95] = sreg;
      cpu.cycles++;
    }
    if ((opcode & 65032) === 64512) {
      if (!(cpu.data[(opcode & 496) >> 4] & 1 << (opcode & 7))) {
        const nextOpcode = cpu.progMem[cpu.pc + 1];
        const skipSize = isTwoWordInstruction(nextOpcode) ? 2 : 1;
        cpu.cycles += skipSize;
        cpu.pc += skipSize;
      }
    }
    if ((opcode & 65032) === 65024) {
      if (cpu.data[(opcode & 496) >> 4] & 1 << (opcode & 7)) {
        const nextOpcode = cpu.progMem[cpu.pc + 1];
        const skipSize = isTwoWordInstruction(nextOpcode) ? 2 : 1;
        cpu.cycles += skipSize;
        cpu.pc += skipSize;
      }
    }
    if (opcode === 38280) {
    }
    if (opcode === 38376) {
    }
    if (opcode === 38392) {
    }
    if ((opcode & 65039) === 37376) {
      const value = cpu.data[(opcode & 496) >> 4];
      const addr = cpu.progMem[cpu.pc + 1];
      cpu.writeData(addr, value);
      cpu.pc++;
      cpu.cycles++;
    }
    if ((opcode & 65039) === 37388) {
      cpu.writeData(cpu.dataView.getUint16(26, true), cpu.data[(opcode & 496) >> 4]);
    }
    if ((opcode & 65039) === 37389) {
      const x = cpu.dataView.getUint16(26, true);
      cpu.writeData(x, cpu.data[(opcode & 496) >> 4]);
      cpu.dataView.setUint16(26, x + 1, true);
    }
    if ((opcode & 65039) === 37390) {
      const i = cpu.data[(opcode & 496) >> 4];
      const x = cpu.dataView.getUint16(26, true) - 1;
      cpu.dataView.setUint16(26, x, true);
      cpu.writeData(x, i);
      cpu.cycles++;
    }
    if ((opcode & 65039) === 33288) {
      cpu.writeData(cpu.dataView.getUint16(28, true), cpu.data[(opcode & 496) >> 4]);
    }
    if ((opcode & 65039) === 37385) {
      const i = cpu.data[(opcode & 496) >> 4];
      const y = cpu.dataView.getUint16(28, true);
      cpu.writeData(y, i);
      cpu.dataView.setUint16(28, y + 1, true);
    }
    if ((opcode & 65039) === 37386) {
      const i = cpu.data[(opcode & 496) >> 4];
      const y = cpu.dataView.getUint16(28, true) - 1;
      cpu.dataView.setUint16(28, y, true);
      cpu.writeData(y, i);
      cpu.cycles++;
    }
    if ((opcode & 53768) === 33288 && opcode & 7 | (opcode & 3072) >> 7 | (opcode & 8192) >> 8) {
      cpu.writeData(cpu.dataView.getUint16(28, true) + (opcode & 7 | (opcode & 3072) >> 7 | (opcode & 8192) >> 8), cpu.data[(opcode & 496) >> 4]);
      cpu.cycles++;
    }
    if ((opcode & 65039) === 33280) {
      cpu.writeData(cpu.dataView.getUint16(30, true), cpu.data[(opcode & 496) >> 4]);
    }
    if ((opcode & 65039) === 37377) {
      const z = cpu.dataView.getUint16(30, true);
      cpu.writeData(z, cpu.data[(opcode & 496) >> 4]);
      cpu.dataView.setUint16(30, z + 1, true);
    }
    if ((opcode & 65039) === 37378) {
      const i = cpu.data[(opcode & 496) >> 4];
      const z = cpu.dataView.getUint16(30, true) - 1;
      cpu.dataView.setUint16(30, z, true);
      cpu.writeData(z, i);
      cpu.cycles++;
    }
    if ((opcode & 53768) === 33280 && opcode & 7 | (opcode & 3072) >> 7 | (opcode & 8192) >> 8) {
      cpu.writeData(cpu.dataView.getUint16(30, true) + (opcode & 7 | (opcode & 3072) >> 7 | (opcode & 8192) >> 8), cpu.data[(opcode & 496) >> 4]);
      cpu.cycles++;
    }
    if ((opcode & 64512) === 6144) {
      const val1 = cpu.data[(opcode & 496) >> 4];
      const val2 = cpu.data[opcode & 15 | (opcode & 512) >> 5];
      const R = val1 - val2;
      cpu.data[(opcode & 496) >> 4] = R;
      let sreg = cpu.data[95] & 192;
      sreg |= R ? 0 : 2;
      sreg |= 128 & R ? 4 : 0;
      sreg |= (val1 ^ val2) & (val1 ^ R) & 128 ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      sreg |= val2 > val1 ? 1 : 0;
      sreg |= 1 & (~val1 & val2 | val2 & R | R & ~val1) ? 32 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 61440) === 20480) {
      const val1 = cpu.data[((opcode & 240) >> 4) + 16];
      const val2 = opcode & 15 | (opcode & 3840) >> 4;
      const R = val1 - val2;
      cpu.data[((opcode & 240) >> 4) + 16] = R;
      let sreg = cpu.data[95] & 192;
      sreg |= R ? 0 : 2;
      sreg |= 128 & R ? 4 : 0;
      sreg |= (val1 ^ val2) & (val1 ^ R) & 128 ? 8 : 0;
      sreg |= sreg >> 2 & 1 ^ sreg >> 3 & 1 ? 16 : 0;
      sreg |= val2 > val1 ? 1 : 0;
      sreg |= 1 & (~val1 & val2 | val2 & R | R & ~val1) ? 32 : 0;
      cpu.data[95] = sreg;
    }
    if ((opcode & 65039) === 37890) {
      const d = (opcode & 496) >> 4;
      const i = cpu.data[d];
      cpu.data[d] = (15 & i) << 4 | (240 & i) >>> 4;
    }
    if (opcode === 38312) {
    }
    if ((opcode & 65039) === 37380) {
      const r = (opcode & 496) >> 4;
      const val1 = cpu.data[r];
      const val2 = cpu.data[cpu.dataView.getUint16(30, true)];
      cpu.data[cpu.dataView.getUint16(30, true)] = val1;
      cpu.data[r] = val2;
    }
    cpu.pc = (cpu.pc + 1) % cpu.progMem.length;
    cpu.cycles++;
  }

  // node_modules/avr8js/dist/esm/interrupt.js
  function avrInterrupt(cpu, addr) {
    const sp = cpu.dataView.getUint16(93, true);
    cpu.data[sp] = cpu.pc & 255;
    cpu.data[sp - 1] = cpu.pc >> 8 & 255;
    cpu.dataView.setUint16(93, sp - 2, true);
    cpu.data[95] &= 127;
    cpu.cycles += 2;
    cpu.pc = addr;
  }

  // node_modules/avr8js/dist/esm/gpio.js
  var portBConfig = {
    PIN: 35,
    DDR: 36,
    PORT: 37
  };
  var portCConfig = {
    PIN: 38,
    DDR: 39,
    PORT: 40
  };
  var portDConfig = {
    PIN: 41,
    DDR: 42,
    PORT: 43
  };
  var PinState;
  (function(PinState2) {
    PinState2[PinState2["Low"] = 0] = "Low";
    PinState2[PinState2["High"] = 1] = "High";
    PinState2[PinState2["Input"] = 2] = "Input";
    PinState2[PinState2["InputPullUp"] = 3] = "InputPullUp";
  })(PinState || (PinState = {}));
  var AVRIOPort = class {
    constructor(cpu, portConfig) {
      this.cpu = cpu;
      this.portConfig = portConfig;
      this.listeners = [];
      cpu.writeHooks[portConfig.PORT] = (value, oldValue) => {
        const ddrMask = cpu.data[portConfig.DDR];
        cpu.data[portConfig.PORT] = value;
        value &= ddrMask;
        cpu.data[portConfig.PIN] = cpu.data[portConfig.PIN] & ~ddrMask | value;
        this.writeGpio(value, oldValue & ddrMask);
        return true;
      };
      cpu.writeHooks[portConfig.PIN] = (value) => {
        const oldPortValue = cpu.data[portConfig.PORT];
        const ddrMask = cpu.data[portConfig.DDR];
        const portValue = oldPortValue ^ value;
        cpu.data[portConfig.PORT] = portValue;
        cpu.data[portConfig.PIN] = cpu.data[portConfig.PIN] & ~ddrMask | portValue & ddrMask;
        this.writeGpio(portValue & ddrMask, oldPortValue & ddrMask);
        return true;
      };
    }
    addListener(listener) {
      this.listeners.push(listener);
    }
    removeListener(listener) {
      this.listeners = this.listeners.filter((l) => l !== listener);
    }
    /**
     * Get the state of a given GPIO pin
     *
     * @param index Pin index to return from 0 to 7
     * @returns PinState.Low or PinState.High if the pin is set to output, PinState.Input if the pin is set
     *   to input, and PinState.InputPullUp if the pin is set to input and the internal pull-up resistor has
     *   been enabled.
     */
    pinState(index) {
      const ddr = this.cpu.data[this.portConfig.DDR];
      const port = this.cpu.data[this.portConfig.PORT];
      const bitMask = 1 << index;
      if (ddr & bitMask) {
        return port & bitMask ? PinState.High : PinState.Low;
      } else {
        return port & bitMask ? PinState.InputPullUp : PinState.Input;
      }
    }
    writeGpio(value, oldValue) {
      for (const listener of this.listeners) {
        listener(value, oldValue);
      }
    }
  };

  // node_modules/avr8js/dist/esm/usart.js
  var usart0Config = {
    rxCompleteInterrupt: 36,
    dataRegisterEmptyInterrupt: 38,
    txCompleteInterrupt: 40,
    UCSRA: 192,
    UCSRB: 193,
    UCSRC: 194,
    UBRRL: 196,
    UBRRH: 197,
    UDR: 198
  };
  var UCSRA_TXC = 64;
  var UCSRA_UDRE = 32;
  var UCSRA_U2X = 2;
  var UCSRB_TXCIE = 64;
  var UCSRB_UDRIE = 32;
  var UCSRB_TXEN = 8;
  var UCSRB_UCSZ2 = 4;
  var UCSRC_UCSZ1 = 4;
  var UCSRC_UCSZ0 = 2;
  var AVRUSART = class {
    constructor(cpu, config, freqMHz) {
      this.cpu = cpu;
      this.config = config;
      this.freqMHz = freqMHz;
      this.onByteTransmit = null;
      this.onLineTransmit = null;
      this.lineBuffer = "";
      this.cpu.writeHooks[config.UCSRA] = (value) => {
        this.cpu.data[config.UCSRA] = value | UCSRA_UDRE | UCSRA_TXC;
        return true;
      };
      this.cpu.writeHooks[config.UCSRB] = (value, oldValue) => {
        if (value & UCSRB_TXEN && !(oldValue & UCSRB_TXEN)) {
          this.cpu.data[config.UCSRA] |= UCSRA_UDRE;
        }
      };
      this.cpu.writeHooks[config.UDR] = (value) => {
        if (this.onByteTransmit) {
          this.onByteTransmit(value);
        }
        if (this.onLineTransmit) {
          const ch = String.fromCharCode(value);
          if (ch === "\n") {
            this.onLineTransmit(this.lineBuffer);
            this.lineBuffer = "";
          } else {
            this.lineBuffer += ch;
          }
        }
        this.cpu.data[config.UCSRA] |= UCSRA_UDRE | UCSRA_TXC;
      };
    }
    tick() {
      if (this.cpu.interruptsEnabled) {
        const ucsra = this.cpu.data[this.config.UCSRA];
        const ucsrb = this.cpu.data[this.config.UCSRB];
        if (ucsra & UCSRA_UDRE && ucsrb & UCSRB_UDRIE) {
          avrInterrupt(this.cpu, this.config.dataRegisterEmptyInterrupt);
          this.cpu.data[this.config.UCSRA] &= ~UCSRA_UDRE;
        }
        if (ucsrb & UCSRA_TXC && ucsrb & UCSRB_TXCIE) {
          avrInterrupt(this.cpu, this.config.txCompleteInterrupt);
          this.cpu.data[this.config.UCSRA] &= ~UCSRA_TXC;
        }
      }
    }
    get baudRate() {
      const UBRR = this.cpu.data[this.config.UBRRH] << 8 | this.cpu.data[this.config.UBRRL];
      const multiplier = this.cpu.data[this.config.UCSRA] & UCSRA_U2X ? 8 : 16;
      return Math.floor(this.freqMHz / (multiplier * (1 + UBRR)));
    }
    get bitsPerChar() {
      const ucsz = (this.cpu.data[this.config.UCSRA] & (UCSRC_UCSZ1 | UCSRC_UCSZ0)) >> 1 | this.cpu.data[this.config.UCSRB] & UCSRB_UCSZ2;
      switch (ucsz) {
        case 0:
          return 5;
        case 1:
          return 6;
        case 2:
          return 7;
        case 3:
          return 8;
        default:
        // 4..6 are reserved
        case 7:
          return 9;
      }
    }
  };

  // RuntimeSources/robotkit-runtime.js
  var FLASH_WORDS = 32768;
  var FLASH_BYTES = FLASH_WORDS * 2;
  var PORT_CONFIGS = {
    B: portBConfig,
    C: portCConfig,
    D: portDConfig
  };
  var PIN_PORT_MAP = {
    D2: { port: "D", bit: 2 },
    D3: { port: "D", bit: 3 },
    D4: { port: "D", bit: 4 },
    D5: { port: "D", bit: 5 },
    D6: { port: "D", bit: 6 },
    D7: { port: "D", bit: 7 },
    D8: { port: "B", bit: 0 },
    D9: { port: "B", bit: 1 },
    D10: { port: "B", bit: 2 },
    D11: { port: "B", bit: 3 },
    D12: { port: "B", bit: 4 },
    D13: { port: "B", bit: 5 },
    A0: { port: "C", bit: 0 },
    A1: { port: "C", bit: 1 },
    A2: { port: "C", bit: 2 },
    A3: { port: "C", bit: 3 },
    A4: { port: "C", bit: 4 },
    A5: { port: "C", bit: 5 }
  };
  function parseHex(hexText) {
    const data = new Uint8Array(FLASH_BYTES);
    const lines = hexText.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
    for (const line of lines) {
      if (!line.startsWith(":")) {
        continue;
      }
      const byteCount = Number.parseInt(line.slice(1, 3), 16);
      const address = Number.parseInt(line.slice(3, 7), 16);
      const recordType = Number.parseInt(line.slice(7, 9), 16);
      if (recordType === 1) {
        break;
      }
      if (recordType !== 0) {
        continue;
      }
      for (let index = 0; index < byteCount; index += 1) {
        const source = 9 + index * 2;
        data[address + index] = Number.parseInt(line.slice(source, source + 2), 16);
      }
    }
    return data;
  }
  function machineCodeFromHex(hexText) {
    return new Uint16Array(parseHex(hexText).buffer);
  }
  var UnoRuntime = class {
    constructor(host) {
      this.host = host;
      this.cpu = null;
      this.ports = {};
      this.usart = null;
      this.cyclesPerTick = 4e4;
      this.frame = 0;
      this.loaded = false;
      this.pinState = /* @__PURE__ */ new Map();
      this.project = null;
      this.observedPins = [];
      this.externalPinValues = /* @__PURE__ */ new Map();
    }
    boot() {
      return {
        ok: true,
        engines: ["avr8js"],
        runtime: "Arduino Uno",
        transport: "JavaScriptCore"
      };
    }
    loadProject(payloadJSON, firmwareHex) {
      const payload = JSON.parse(payloadJSON);
      const project = payload.project;
      if (project.board.id !== "arduino-uno") {
        throw new Error(`Unsupported board '${project.board.id}'`);
      }
      const program = machineCodeFromHex(firmwareHex);
      this.project = project;
      this.observedPins = Object.keys(PIN_PORT_MAP);
      this.cpu = new CPU(program);
      this.ports = {
        B: new AVRIOPort(this.cpu, portBConfig),
        C: new AVRIOPort(this.cpu, portCConfig),
        D: new AVRIOPort(this.cpu, portDConfig)
      };
      for (const portName of Object.keys(this.ports)) {
        this.ports[portName].addListener((value) => this.handlePortChange(portName, value));
      }
      this.usart = new AVRUSART(this.cpu, usart0Config, 16e6);
      this.usart.onLineTransmit = (line) => {
        this.host.serialWrite({
          text: line.replace(/\r/g, ""),
          baudRate: this.usart ? this.usart.baudRate : 0
        });
      };
      this.loaded = true;
      this.frame = 0;
      this.pinState.clear();
      this.externalPinValues.clear();
      this.applyExternalInputs();
      this.host.log(`[js] Loaded ${project.demo.id} into avr8js from host artifact`);
      return {
        ok: true,
        board: project.board.id,
        programBytes: program.length * 2,
        demo: project.demo.id
      };
    }
    reset() {
      this.loaded = false;
      this.cpu = null;
      this.ports = {};
      this.usart = null;
      this.frame = 0;
      this.pinState.clear();
      this.project = null;
      this.observedPins = [];
      this.externalPinValues.clear();
      return { ok: true };
    }
    setInputPin(pin, value) {
      if (!PIN_PORT_MAP[pin]) {
        throw new Error(`Unsupported input pin '${pin}'`);
      }
      if (value === null || value === void 0) {
        this.externalPinValues.delete(pin);
      } else {
        this.externalPinValues.set(pin, value ? 1 : 0);
      }
      this.applyExternalInputs();
      return { ok: true };
    }
    stepFrame() {
      if (!this.loaded || !this.cpu) {
        throw new Error("Runtime has no loaded program");
      }
      for (let step = 0; step < this.cyclesPerTick; step += 1) {
        avrInstruction(this.cpu);
        this.applyExternalInputs();
        if (this.usart) {
          this.usart.tick();
        }
      }
      this.frame += 1;
      return {
        ok: true,
        frame: this.frame,
        cycles: this.cpu.cycles
      };
    }
    handlePortChange(portName, value) {
      for (const [pin, binding] of Object.entries(PIN_PORT_MAP)) {
        if (binding.port !== portName) {
          continue;
        }
        const bitMask = 1 << binding.bit;
        const pinValue = (value & bitMask) !== 0 ? 1 : 0;
        this.publishPin(pin, pinValue, this.cpu ? this.cpu.cycles : 0);
      }
    }
    applyExternalInputs() {
      if (!this.cpu) {
        return;
      }
      for (const [portName, config] of Object.entries(PORT_CONFIGS)) {
        const ddr = this.cpu.data[config.DDR];
        const port = this.cpu.data[config.PORT];
        let pinReg = port & ddr;
        for (const [pin, binding] of Object.entries(PIN_PORT_MAP)) {
          if (binding.port !== portName) {
            continue;
          }
          const bitMask = 1 << binding.bit;
          if (ddr & bitMask) {
            continue;
          }
          let value = this.externalPinValues.get(pin);
          if (value === void 0) {
            value = port & bitMask ? 1 : 0;
          }
          if (value) {
            pinReg |= bitMask;
          } else {
            pinReg &= ~bitMask;
          }
        }
        this.cpu.data[config.PIN] = pinReg;
      }
    }
    publishPin(name, value, cycles) {
      if (this.pinState.get(name) === value) {
        return;
      }
      this.pinState.set(name, value);
      this.host.pinChanged({
        boardId: this.project?.board.id ?? "arduino-uno",
        pin: name,
        value,
        cycles
      });
    }
  };
  function createHostBridge() {
    const bridge = globalThis.robotKitHost;
    if (!bridge) {
      throw new Error("robotKitHost is not installed");
    }
    return {
      log(message) {
        bridge.log(String(message));
      },
      pinChanged(event) {
        bridge.pinChanged(JSON.stringify(event));
      },
      serialWrite(event) {
        bridge.serialWrite(JSON.stringify(event));
      }
    };
  }
  var runtime = new UnoRuntime(createHostBridge());
  globalThis.robotkit = {
    version: "0.4.0",
    boot() {
      return runtime.boot();
    },
    loadProject(payloadJSON, firmwareHex) {
      return runtime.loadProject(payloadJSON, firmwareHex);
    },
    setInputPin(pin, value) {
      return runtime.setInputPin(pin, value);
    },
    reset() {
      return runtime.reset();
    },
    stepFrame() {
      return runtime.stepFrame();
    }
  };
})();
