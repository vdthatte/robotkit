# RobotKit Implementation Plan

## Product Direction

RobotKit is a macOS-first electronics simulator for internal use. The host app is native, but the first simulator runtime is embedded JavaScript so the project can reuse mature open-source parts such as `avr8js` and `rp2040js` before a later migration to a native core.

The product goal is not "a website on the desktop." The goal is a native macOS tool with:

- a native workspace shell
- a native schematic editor
- deterministic simulation controls
- embeddable JavaScript runtimes for MCU execution
- a project format that we fully own

## Architecture

### App Shell

- Language: Swift
- UI: SwiftUI for the workspace shell
- Native canvas: AppKit-backed editor once wire editing begins
- Window layout: navigator, canvas, inspector, console, runtime status

### Runtime Layer

- Host runtime: `JavaScriptCore`
- First adapters:
  - `avr8js` for Arduino Uno / ATmega328P
  - `rp2040js` for Raspberry Pi Pico / RP2040
- Boundary:
  - Swift owns files, windows, selection, inspector, undo, persistence
  - JavaScript owns CPU stepping, MCU state, peripheral callbacks
- Communication:
  - pin read/write bridge
  - serial output bridge
  - timer/event bridge
  - trace/log bridge

### Project Model

- Store a `RobotProject` model in Swift
- Define our own diagram format early instead of inheriting Wokwi's schema wholesale
- Keep board definitions and part definitions as JSON-backed data
- Maintain a stable intermediate representation so the runtime and editor are decoupled

### Persistence

- Save a project bundle directory
- Suggested first layout:

```text
Project.robotkit/
  project.json
  diagram.robotkit.json
  sketch.ino
  assets/
```

## Phase Plan

### Phase 0: Foundation

- Reset the repository and create the new app shell
- Add runtime host abstraction around `JavaScriptCore`
- Define board, part, wire, and document models
- Decide on project bundle layout

### Phase 1: Uno MVP

- Integrate `avr8js`
- Load a compiled AVR binary or hex file
- Add a simple board view and parts palette
- Implement pin graph evaluation for digital IO
- Add serial monitor and run/stop/reset controls
- Support LED, resistor, button, and breadboard-free direct wiring

### Phase 2: Native Canvas

- Replace the placeholder canvas with an AppKit-backed editor
- Add snapping, wire segments, selection, drag handles, and undo
- Introduce pin hit-testing and connection validation
- Add a part inspector and attributes editor

### Phase 3: RP2040

- Integrate `rp2040js`
- Add Pico board support
- Support UART and a first debugging surface
- Expand the board definition system

### Phase 4: Native Runtime Migration

- Start replacing hot paths with a native Rust or C++ core
- Keep the Swift-side host contracts stable
- Migrate one peripheral family at a time

## Immediate Next Steps

1. Add `JavaScriptCore` runtime tests and a simple host-to-JS message API.
2. Choose how the OSS JS runtimes will be bundled:
   - prebuilt local JS bundle checked into the repo
   - generated bundle via a separate build step
3. Define the first `diagram.robotkit.json` schema for parts, positions, pins, and wires.
4. Replace the placeholder canvas with an AppKit `NSViewRepresentable`.
5. Load a compiled Uno sample and drive a blinking LED through the runtime bridge.
