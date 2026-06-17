import SwiftUI
import CoreData

struct RelationshipEditView: View {
    let personA: Person
    let personB: Person
    var existing: Relationship? = nil
    var initialArrowDirection: ArrowDirection = .both

    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var label = ""
    @State private var level: Int16 = 3
    @State private var arrowDirection: Int16 = 0
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationView {
            Form {
                Section("関係の人物") {
                    HStack {
                        Text(personA.name ?? "")
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Menu {
                            ForEach(ArrowDirection.allCases, id: \.rawValue) { dir in
                                Button { arrowDirection = dir.rawValue } label: {
                                    Label("", systemImage: dir.sfSymbol)
                                }
                            }
                        } label: {
                            Image(systemName: ArrowDirection.from(arrowDirection).sfSymbol)
                                .font(.title3)
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 8)
                        }
                        Spacer()
                        Text(personB.name ?? "")
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Section("関係テキスト") {
                    TextField("例: 幼なじみ、兄弟、ライバル", text: $label)
                }

                Section("関係の強さ") {
                    VStack(spacing: 12) {
                        HStack {
                            ForEach(RelationshipLevel.allCases, id: \.rawValue) { lv in
                                VStack(spacing: 4) {
                                    Group {
                                        if UIImage(named: lv.imageName) != nil {
                                            Image(lv.imageName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 36, height: 36)
                                        } else if let symbol = lv.sfSymbolName {
                                            Image(systemName: symbol)
                                                .resizable()
                                                .scaledToFit()
                                                .foregroundColor(.red)
                                                .frame(width: 36, height: 36)
                                        } else {
                                            Text(lv.icon).font(.title2)
                                        }
                                    }

                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(level == lv.rawValue ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture { level = lv.rawValue }
                            }
                        }
                    }
                }

                if existing != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("この関係を削除", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "関係を追加" : "関係を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear {
                if let e = existing {
                    label = e.label ?? ""
                    level = e.level
                    arrowDirection = e.arrowDirection
                } else {
                    arrowDirection = initialArrowDirection.rawValue
                }
            }
            .confirmationDialog("この関係を削除しますか？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) { delete() }
            }
        }
    }

    private func save() {
        if let existing {
            let newDir = ArrowDirection.from(arrowDirection)
            let oldDir = ArrowDirection.from(existing.arrowDirection)
            let allRels = (try? ctx.fetch(Relationship.fetchRequest())) ?? []
            if newDir == .both {
                // both に変更する場合: 同ペアの他の関係（重複both・片方向sibling）を削除
                for r in allRels where r.objectID != existing.objectID
                    && ((r.personA == personA && r.personB == personB) ||
                        (r.personA == personB && r.personB == personA)) {
                    ctx.delete(r)
                }
                existing.label = label
                existing.level = level
                existing.arrowDirection = arrowDirection
            } else if newDir != oldDir,
                      let sibling = allRels.first(where: { r in
                          r.objectID != existing.objectID
                          && r.personA == personB && r.personB == personA
                          && ArrowDirection.from(r.arrowDirection) != .both
                          && ArrowDirection.from(r.arrowDirection) != newDir
                      }) {
                // 矢印を反転して逆ペア側のsiblingと同じ向きになる場合:
                // この関係(existing)はそのまま残し、逆ペア側(sibling)の内容を更新する
                sibling.label = label
                sibling.level = level
            } else {
                existing.label = label
                existing.level = level
                existing.arrowDirection = arrowDirection
            }
        } else {
            // 新規追加
            let allRels = (try? ctx.fetch(Relationship.fetchRequest())) ?? []
            let newDir  = ArrowDirection.from(arrowDirection)

            if newDir == .both {
                // both を選択: 同ペアに already both があれば重複させず更新のみ
                let existingBoth = allRels.first { r in
                    r.arrowDirection == ArrowDirection.both.rawValue &&
                    ((r.personA == personA && r.personB == personB) ||
                     (r.personA == personB && r.personB == personA))
                }
                if let eb = existingBoth {
                    eb.label = label
                    eb.level = level
                    try? ctx.save()
                    dismiss()
                    return
                }
                // 同ペアの既存の片方向関係を削除し、both 単独の状態にする
                for r in allRels where
                    (r.personA == personA && r.personB == personB) ||
                    (r.personA == personB && r.personB == personA) {
                    ctx.delete(r)
                }
            } else {
                // 片方向を選択: 同ペアの既存 both を逆方向片方向に変換（逆ペア保存で hasSibling=true）
                for r in allRels where r.arrowDirection == ArrowDirection.both.rawValue
                    && ((r.personA == personA && r.personB == personB) ||
                        (r.personA == personB && r.personB == personA)) {
                    if r.personA == personB && r.personB == personA {
                        r.arrowDirection = arrowDirection
                    } else {
                        let tmp = r.personA
                        r.personA = r.personB
                        r.personB = tmp
                        r.arrowDirection = arrowDirection
                    }
                }
            }

            let rel = Relationship(context: ctx)
            rel.id             = UUID()
            rel.createdAt      = Date()
            rel.personA        = personA
            rel.personB        = personB
            rel.label          = label
            rel.level          = level
            rel.arrowDirection = arrowDirection
        }
        try? ctx.save()
        dismiss()
    }

    private func delete() {
        if let rel = existing {
            ctx.delete(rel)
            try? ctx.save()
        }
        dismiss()
    }
}
