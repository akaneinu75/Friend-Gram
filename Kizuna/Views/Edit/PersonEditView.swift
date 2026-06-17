import SwiftUI
import PhotosUI
import CoreData

struct PersonEditView: View {
    var person: Person? = nil
    var initialPosition: CGPoint? = nil
    var onDeleted: (() -> Void)? = nil

    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Affiliation.name, ascending: true)])
    private var affiliations: FetchedResults<Affiliation>

    @State private var name = ""
    @State private var birthday: Date = {
        var c = DateComponents(); c.year = 2000; c.month = 1; c.day = 1
        return Calendar.current.date(from: c) ?? Date()
    }()
    @State private var hasBirthday = false
    @State private var characteristics = ""
    @State private var selectedAffiliations: Set<Affiliation> = []
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var imageToCrop: UIImage?
    @State private var showCropSheet = false
    @State private var showNewAffiliationSheet = false
    @State private var showDeleteConfirm = false
    @State private var editingAffiliation: Affiliation? = nil

    var body: some View {
        NavigationView {
            Form {
                photoSection
                basicInfoSection
                affiliationSection
                if person != nil {
                    Section {
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Label("この人物を削除", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(person == nil ? "人物を追加" : "編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showNewAffiliationSheet) {
                AffiliationCreateSheet(onCreated: { aff in
                    selectedAffiliations.insert(aff)
                })
            }
            .sheet(isPresented: Binding(
                get: { editingAffiliation != nil },
                set: { if !$0 { editingAffiliation = nil } }
            )) {
                if let aff = editingAffiliation {
                    AffiliationCreateSheet(existing: aff, onCreated: { _ in })
                }
            }
            .confirmationDialog("この人物を削除しますか？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) { deletePerson() }
            }
        }
        .onAppear { loadExisting() }
        .overlay {
            if showCropSheet, let image = imageToCrop {
                PhotoCropView(
                    image: image,
                    onComplete: { cropped in
                        photoData = cropped.jpegData(compressionQuality: 0.85)
                        showCropSheet = false
                        selectedPhoto = nil
                    },
                    onCancel: {
                        showCropSheet = false
                        selectedPhoto = nil
                    }
                )
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section("写真") {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                if let data = photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable().scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Label("写真を選択", systemImage: "person.crop.circle.badge.plus")
                }
            }
            .onChange(of: selectedPhoto) { newItem in
                guard let item = newItem else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let ui = UIImage(data: data) else { return }
                    imageToCrop = ui
                    showCropSheet = true
                }
            }
        }
    }

    private var basicInfoSection: some View {
        Section("基本情報") {
            TextField("名前", text: $name)
            Toggle("誕生日", isOn: $hasBirthday)
            if hasBirthday {
                DatePicker("", selection: $birthday, displayedComponents: .date)
                    .labelsHidden()
            }
            TextField("特徴", text: $characteristics, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var affiliationSection: some View {
        Section(header: Text("所属")) {
            ForEach(affiliations) { aff in
                AffiliationRow(
                    aff: aff,
                    isSelected: selectedAffiliations.contains(aff),
                    onTap: { toggleAffiliation(aff) }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button { editingAffiliation = aff } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
            Button { showNewAffiliationSheet = true } label: {
                Label("所属を新規作成", systemImage: "plus")
            }
        }
    }

    // MARK: - Helpers

    private func toggleAffiliation(_ aff: Affiliation) {
        if selectedAffiliations.contains(aff) {
            selectedAffiliations.remove(aff)
        } else {
            selectedAffiliations.insert(aff)
        }
    }

    private func loadExisting() {
        guard let p = person else { return }
        name = p.name ?? ""
        characteristics = p.characteristics ?? ""
        photoData = p.photoData
        if let bd = p.birthday { birthday = bd; hasBirthday = true }
        selectedAffiliations = (p.affiliations as? Set<Affiliation>) ?? []
    }

    private func deletePerson() {
        guard let p = person else { return }
        ctx.delete(p)
        try? ctx.save()
        dismiss()
        onDeleted?()
    }

    private func save() {
        let p = person ?? Person(context: ctx)
        if person == nil {
            p.id = UUID()
            p.createdAt = Date()
            let pos = initialPosition ?? CGPoint(x: 0.5, y: 0.5)
            p.positionX = pos.x
            p.positionY = pos.y
        }
        p.name = name.trimmingCharacters(in: .whitespaces)
        p.characteristics = characteristics
        p.photoData = photoData
        p.birthday = hasBirthday ? birthday : nil
        p.affiliations = selectedAffiliations as NSSet
        try? ctx.save()
        dismiss()
    }
}

// MARK: - 所属新規作成シート（ColorPicker付き）

struct AffiliationCreateSheet: View {
    var existing: Affiliation? = nil
    let onCreated: (Affiliation) -> Void

    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var affName = ""
    @State private var affColor = Color.blue
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationView {
            Form {
                Section("所属名") {
                    TextField("例: クラス、職場、家族", text: $affName)
                }
                Section("カラー") {
                    ColorPicker("カラーを選択", selection: $affColor, supportsOpacity: false)
                    HStack {
                        Circle().fill(affColor).frame(width: 24, height: 24)
                        Text("プレビュー")
                            .foregroundColor(.secondary)
                    }
                }
                if existing != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("この所属を削除", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "所属を作成" : "所属を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existing == nil ? "作成" : "保存") { save() }
                        .disabled(affName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let aff = existing {
                    affName = aff.name ?? ""
                    affColor = Color(hex: aff.colorHex ?? "#0000FF")
                }
            }
            .confirmationDialog(
                "「\(affName)」を削除しますか？\nこの所属を持つすべての人物から解除されます。",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) { delete() }
            }
        }
    }

    private func save() {
        let trimmed = affName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let aff = existing {
            aff.name = trimmed
            aff.colorHex = affColor.toHex()
            try? ctx.save()
        } else {
            let aff = Affiliation(context: ctx)
            aff.id = UUID()
            aff.name = trimmed
            aff.colorHex = affColor.toHex()
            try? ctx.save()
            onCreated(aff)
        }
        dismiss()
    }

    private func delete() {
        guard let aff = existing else { return }
        ctx.delete(aff)
        try? ctx.save()
        dismiss()
    }
}

// MARK: - 所属行

private struct AffiliationRow: View {
    let aff: Affiliation
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: aff.colorHex ?? "#3498DB"))
                .frame(width: 12, height: 12)
            Text(aff.name ?? "")
            Spacer()
            if isSelected {
                Image(systemName: "checkmark").foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
