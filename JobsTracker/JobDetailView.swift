//
//  JobDetailView.swift
//  JobsTracker
//
//  Created by Marcos Leal on 3/2/26.
//

import SwiftUI
import SwiftData

struct JobDetailView: View {
    @Bindable var entry: JobEntry
    @Binding var selectedEntry: JobEntry?
    @Environment(\.modelContext) private var modelContext

    @State private var editingSkillID: UUID?
    @State private var editingSkillName: String = ""
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusBanner
                companySection
                skillsSection
                rawDescriptionSection
            }
            .padding(24)
        }
        .navigationTitle(entry.jobPosition ?? "Job Entry")
        .navigationSubtitle(entry.companyName ?? "")
        .toolbar {
            ToolbarItem {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Job", systemImage: "trash")
                }
                .help("Delete this job entry")
            }
        }
        .alert("Delete Job?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this job entry and all its skills.")
        }
    }

    // MARK: - Status Banner

    @ViewBuilder
    private var statusBanner: some View {
        switch entry.status {
        case .pending:
            Label("Waiting to analyze…", systemImage: "clock")
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        case .analyzing:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.75)
                Text("Analyzing with Ollama (llama3.1)…")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        case .done:
            EmptyView()
        case .failed:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Analysis failed")
                        .fontWeight(.semibold)
                    if let msg = entry.errorMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Re-analyze") {
                    reanalyze()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Company Section

    private var companySection: some View {
        GroupBox("Company") {
            VStack(alignment: .leading, spacing: 8) {
                EditableRow(label: "Position", text: optionalBinding(\.jobPosition), prompt: "Job position")
                EditableRow(label: "Company",  text: optionalBinding(\.companyName),  prompt: "Company name")
                EditableRow(label: "Address",  text: optionalBinding(\.companyAddress), prompt: "Company address")
                EditableRow(label: "Website",  text: optionalBinding(\.companyWebsite),  prompt: "Company website")
                DetailRow(label: "Added", value: entry.createdAt.formatted(date: .long, time: .shortened))
            }
            .padding(.vertical, 4)
        }
    }

    /// Creates a non-optional `Binding<String>` from an optional `String?` property on `entry`.
    private func optionalBinding(_ keyPath: ReferenceWritableKeyPath<JobEntry, String?>) -> Binding<String> {
        Binding(
            get: { entry[keyPath: keyPath] ?? "" },
            set: { entry[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    // MARK: - Skills Section

    @ViewBuilder
    private var skillsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                if entry.skills.isEmpty {
                    Text(
                        entry.status == .done
                            ? "No technical skills were found."
                            : "Skills will appear after analysis completes."
                    )
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding(.vertical, 8)
                } else {
                    ForEach(entry.skills) { skill in
                        SkillRowView(
                            skill: skill,
                            isEditing: editingSkillID == skill.id,
                            editingName: $editingSkillName,
                            onEdit: { beginEditing(skill) },
                            onCommit: { commitEdit(skill) },
                            onDelete: { deleteSkill(skill) }
                        )
                        if skill.id != entry.skills.last?.id {
                            Divider()
                        }
                    }

                    if entry.allSkillsKnown {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill").foregroundStyle(.yellow)
                            Text("All skills mastered!")
                                .fontWeight(.medium)
                        }
                        .padding(.top, 12)
                    }
                }
            }
        } label: {
            Text("Technical Skills")
        }
    }

    // MARK: - Raw Description

    private var rawDescriptionSection: some View {
        DisclosureGroup("Original Job Description") {
            TextEditor(text: $entry.rawJobDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                .padding(.top, 4)

            if entry.status == .done || entry.status == .failed {
                HStack {
                    Spacer()
                    Button("Re-analyze") {
                        reanalyze()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Skill Actions

    private func beginEditing(_ skill: TechnicalSkill) {
        editingSkillID = skill.id
        editingSkillName = skill.name
    }

    private func commitEdit(_ skill: TechnicalSkill) {
        let trimmed = editingSkillName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            skill.name = trimmed
        }
        editingSkillID = nil
        editingSkillName = ""
    }

    private func deleteSkill(_ skill: TechnicalSkill) {
        entry.skills.removeAll { $0.id == skill.id }
        modelContext.delete(skill)
    }

    private func deleteEntry() {
        selectedEntry = nil
        modelContext.delete(entry)
    }

    private func reanalyze() {
        let entryID = entry.id
        Task.detached {
            await JobAnalysisCoordinator.analyze(entryID: entryID)
        }
    }
}

// MARK: - Skill Row

struct SkillRowView: View {
    @Bindable var skill: TechnicalSkill
    let isEditing: Bool
    @Binding var editingName: String
    let onEdit: () -> Void
    let onCommit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $skill.isKnown)
                .labelsHidden()
                .toggleStyle(.checkbox)

            if isEditing {
                TextField("Skill name", text: $editingName)
                    .textFieldStyle(.plain)
                    .onSubmit { onCommit() }
            } else {
                Text(skill.name)
                    .strikethrough(skill.isKnown, color: .secondary)
                    .foregroundStyle(skill.isKnown ? .secondary : .primary)
                    .onTapGesture(count: 2) { onEdit() }
            }

            Spacer()

            if isEditing {
                Button("Done") { onCommit() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            } else {
                Button { onEdit() } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .font(.caption)
                .help("Rename skill (or double-click)")
            }

            Button { onDelete() } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red.opacity(0.7))
            .font(.caption)
            .help("Delete skill")
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Editable Row

struct EditableRow: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""

    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
        }
        .font(.body)
    }
}

// MARK: - Detail Row Helper

struct DetailRow: View {
    let label: String
    let value: String?

    var body: some View {
        if let value, !value.isEmpty {
            HStack(alignment: .top) {
                Text(label + ":")
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .trailing)
                Text(value)
                    .textSelection(.enabled)
            }
            .font(.body)
        }
    }
}

// MARK: - Preview

#Preview {
    let schema = Schema([JobEntry.self, TechnicalSkill.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    let entry = JobEntry(rawJobDescription: "Senior iOS Engineer at Apple…")
    entry.status = .done
    entry.companyName    = "Apple Inc."
    entry.jobPosition    = "Senior iOS Engineer"
    entry.companyAddress = "One Apple Park Way, Cupertino, CA 95014"
    entry.companyWebsite = "https://apple.com"
    container.mainContext.insert(entry)

    let skillData: [(String, Bool)] = [("Swift", true), ("SwiftUI", true), ("SwiftData", false), ("Xcode", true)]
    for (name, known) in skillData {
        let skill = TechnicalSkill(name: name)
        skill.isKnown = known
        container.mainContext.insert(skill)
        entry.skills.append(skill)
    }

    return NavigationSplitView {
        Text("Sidebar")
    } detail: {
        JobDetailView(entry: entry, selectedEntry: .constant(nil))
    }
    .modelContainer(container)
}
