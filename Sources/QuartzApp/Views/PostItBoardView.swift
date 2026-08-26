import QuartzKit
import SwiftUI

struct PostItBoardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var newNote = ""
    @FocusState private var newNoteFocused: Bool

    private var palette: StonePalette { model.theme.palette }
    private let columns = [GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "note.text")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(model.postItMode.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(boardTitle)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.text)
                    Text(boardSubtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(palette.secondary)
                }

                Spacer()

                Button {
                    model.hidePostItShelf()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.secondary)
                .background(Circle().fill(palette.elevated.opacity(0.72)))
                .help("Masquer les post-it")
            }
            .padding(.horizontal, 14)
            .frame(height: 58)

            Divider().opacity(0.3)

            HStack(spacing: 9) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(model.postItMode.color)
                TextField(newNotePlaceholder, text: $newNote, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .focused($newNoteFocused)
                    .onSubmit(addNote)
                Button(action: addNote) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 25, height: 25)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(model.postItMode.color)
                    .controlSize(.small)
                    .disabled(newNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 46)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.elevated.opacity(0.64))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            if model.shelfPostIts.isEmpty {
                VStack(spacing: 11) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(model.postItMode.color)
                    Text(emptyTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.text)
                    Text(emptySubtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 13) {
                        ForEach(model.shelfPostIts) { note in
                            PostItCard(note: note, palette: palette)
                                .environmentObject(model)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                palette.surface
                StoneFill(palette: palette)
                    .opacity(0.10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(model.postItMode.color.opacity(0.42), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: palette.shadow.opacity(0.72), radius: 22, y: 10)
        .onHover { model.setPostItShelfHovered($0) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Post-it de Quartz")
    }

    private func addNote() {
        model.addPostIt(text: newNote)
        newNote = ""
        newNoteFocused = true
    }

    private var boardTitle: String {
        model.postItMode == .daily ? "Post-it daily" : "Post-it toujours"
    }

    private var boardSubtitle: String {
        let count = model.shelfPostIts.count
        let noun = "note\(count > 1 ? "s" : "")"
        if model.postItMode == .daily {
            return "\(count) \(noun) verte\(count > 1 ? "s" : "") pour ce jour"
        }
        return "\(count) \(noun) jaune\(count > 1 ? "s" : "") visible\(count > 1 ? "s" : "") chaque jour"
    }

    private var newNotePlaceholder: String {
        model.postItMode == .daily ? "Nouvelle note daily…" : "Nouvelle note toujours visible…"
    }

    private var emptyTitle: String {
        model.postItMode == .daily ? "Aucun daily pour ce jour" : "Aucun post-it permanent"
    }

    private var emptySubtitle: String {
        model.postItMode == .daily
            ? "Cette note verte n’apparaîtra que dans la journée sélectionnée."
            : "Cette note jaune restera visible dans toutes les journées."
    }
}

private struct PostItCard: View {
    @EnvironmentObject private var model: AppModel
    let note: PostItNote
    let palette: StonePalette
    @State private var text: String
    @State private var hoveringDelete = false
    @State private var pendingSave: Task<Void, Never>?

    init(note: PostItNote, palette: StonePalette) {
        self.note = note
        self.palette = palette
        _text = State(initialValue: note.text)
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(ink.opacity(0.5))
                Spacer()
                Text(note.updatedAt, style: .date)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(ink.opacity(0.48))
                Button {
                    model.deletePostIt(id: note.id)
                } label: {
                    Image(systemName: hoveringDelete ? "trash.circle.fill" : "trash.circle")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(hoveringDelete ? Color.red.opacity(0.78) : ink.opacity(0.52))
                .onHover { hoveringDelete = $0 }
                .help("Supprimer ce post-it")
            }

            TextEditor(text: $text)
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(ink)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 112, maxHeight: 112)
                .onChange(of: text) { _, value in
                    pendingSave?.cancel()
                    pendingSave = Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        guard !Task.isCancelled else { return }
                        model.updatePostIt(id: note.id, text: value)
                    }
                }
        }
        .padding(11)
        .frame(minHeight: 158)
        .background {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(note.tone.paperColor)
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [Color.white.opacity(0.34), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.white.opacity(0.36), lineWidth: 0.8)
                .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 7, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Post-it modifiable")
        .accessibilityActions {
            Button("Supprimer ce post-it") { model.deletePostIt(id: note.id) }
        }
        .onDisappear {
            pendingSave?.cancel()
            model.updatePostIt(id: note.id, text: text)
        }
    }

    private var ink: Color { note.tone.inkColor }
}
