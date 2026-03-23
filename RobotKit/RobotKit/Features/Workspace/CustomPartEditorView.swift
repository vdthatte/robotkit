import SwiftUI

struct CustomPartEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel

    @State private var draft = CustomPartDraft()
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        baseSection
                        electricalSection
                        functionalSection
                        parametersSection
                        compatibilitySection
                    }
                    .padding(22)
                }
                Divider()
                footer
            }
            .frame(width: 980, height: 720)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        }
        .onExitCommand {
            dismiss()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Custom Part")
                    .font(.title3.weight(.semibold))
                Text("Define pins, functional behavior, parameters, and compatibility metadata.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(22)
    }

    private var baseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Identity")
            HStack(spacing: 12) {
                formField("Name", text: $draft.displayName)
                formField("Identifier", text: $draft.id, placeholder: "custom.my-part")
            }
            HStack(spacing: 12) {
                formField("Group", text: $draft.groupTitle)
                Picker("Kind", selection: $draft.kind) {
                    ForEach(PartKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 12) {
                formField("Default Label", text: $draft.defaultLabel)
                formField("SKU", text: $draft.sku)
            }
            formField("Summary", text: $draft.summary)
            formField("Wiki URL", text: $draft.wikiURL, placeholder: "https://...")
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Pins")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("SIG,VCC,GND", text: $draft.defaultPinsText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Attributes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextEditor(text: $draft.defaultAttributesText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 90)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.14))
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
        }
    }

    private var electricalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Electrical Interfaces")
                Spacer()
                Button("Add Port") {
                    draft.electricalInterfaces.append(.init(name: "", direction: .input, signalText: "digital", description: ""))
                }
            }

            ForEach($draft.electricalInterfaces) { $port in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        formField("Port", text: $port.name)
                        Picker("Direction", selection: $port.direction) {
                            ForEach(PortDirection.allCases, id: \.self) { direction in
                                Text(direction.rawValue.capitalized).tag(direction)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                    formField("Signals", text: $port.signalText, placeholder: "digital,pwm")
                    formField("Description", text: $port.description)
                }
                .padding(12)
                .background(cardBackground)
            }
        }
    }

    private var functionalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Functional Interfaces")
                Spacer()
                Button("Add Interface") {
                    draft.functionalInterfaces.append(.init(name: "", role: .sensorReading, direction: .output, description: ""))
                }
            }

            ForEach($draft.functionalInterfaces) { $interface in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        formField("Name", text: $interface.name)
                        Picker("Role", selection: $interface.role) {
                            ForEach(FunctionalRole.allCases, id: \.self) { role in
                                Text(role.rawValue).tag(role)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }
                    HStack(spacing: 12) {
                        Picker("Direction", selection: $interface.direction) {
                            ForEach(FunctionalDirection.allCases, id: \.self) { direction in
                                Text(direction.rawValue.capitalized).tag(direction)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                        formField("Description", text: $interface.description)
                    }
                }
                .padding(12)
                .background(cardBackground)
            }
        }
    }

    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Simulation Parameters")
                Spacer()
                Button("Add Parameter") {
                    draft.simulationParameters.append(.init(key: "", title: "", defaultValue: "", description: ""))
                }
            }

            ForEach($draft.simulationParameters) { $parameter in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        formField("Key", text: $parameter.key)
                        formField("Title", text: $parameter.title)
                    }
                    HStack(spacing: 12) {
                        formField("Default", text: $parameter.defaultValue)
                        formField("Description", text: $parameter.description)
                    }
                }
                .padding(12)
                .background(cardBackground)
            }
        }
    }

    private var compatibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Compatibility")
                Spacer()
                Button("Add Constraint") {
                    draft.compatibilityConstraints.append(.init(title: "", description: ""))
                }
            }

            ForEach($draft.compatibilityConstraints) { $constraint in
                VStack(alignment: .leading, spacing: 8) {
                    formField("Title", text: $constraint.title)
                    formField("Description", text: $constraint.description)
                }
                .padding(12)
                .background(cardBackground)
            }
        }
    }

    private var footer: some View {
        HStack {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save Part") {
                save()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(18)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.03))
            .stroke(Color.white.opacity(0.06), lineWidth: 1)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
    }

    private func formField(_ title: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() {
        guard draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            errorMessage = "Name is required."
            return
        }

        do {
            try appModel.saveCustomPart(draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
