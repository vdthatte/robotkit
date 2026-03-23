import {
  CPU,
  avrInstruction,
  AVRIOPort,
  AVRTimer,
  AVRUSART,
  portBConfig,
  portCConfig,
  portDConfig,
  timer0Config,
  timer1Config,
  timer2Config,
  usart0Config
} from "avr8js";

const FLASH_WORDS = 32768;
const FLASH_BYTES = FLASH_WORDS * 2;
const CPU_HZ = 16_000_000;
const TARGET_FPS = 30;
const PORT_CONFIGS = {
  B: portBConfig,
  C: portCConfig,
  D: portDConfig
};
const PIN_PORT_MAP = {
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
  const lines = hexText
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  for (const line of lines) {
    if (!line.startsWith(":")) {
      continue;
    }

    const byteCount = Number.parseInt(line.slice(1, 3), 16);
    const address = Number.parseInt(line.slice(3, 7), 16);
    const recordType = Number.parseInt(line.slice(7, 9), 16);

    if (recordType === 0x01) {
      break;
    }

    if (recordType !== 0x00) {
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

class UnoRuntime {
  constructor(host) {
    this.host = host;
    this.cpu = null;
    this.ports = {};
    this.timers = {};
    this.usart = null;
    this.cyclesPerTick = Math.floor(CPU_HZ / TARGET_FPS);
    this.frame = 0;
    this.loaded = false;
    this.pinState = new Map();
    this.project = null;
    this.observedPins = [];
    this.externalPinValues = new Map();
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
    this.timers = {
      timer0: new AVRTimer(this.cpu, timer0Config),
      timer1: new AVRTimer(this.cpu, timer1Config),
      timer2: new AVRTimer(this.cpu, timer2Config)
    };
    for (const portName of Object.keys(this.ports)) {
      this.ports[portName].addListener((value) => this.handlePortChange(portName, value));
    }
    this.usart = new AVRUSART(this.cpu, usart0Config, 16_000_000);
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
    this.timers = {};
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

    if (value === null || value === undefined) {
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
      for (const timer of Object.values(this.timers)) {
        timer.tick();
      }
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
        if (value === undefined) {
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
}

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

const runtime = new UnoRuntime(createHostBridge());

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
