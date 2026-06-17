import SwiftUI
import CoreData

struct PersonDetailSheet: View {
    @ObservedObject var person: Person
    let allRelationships: [Relationship]
    var onClose: (() -> Void)? = nil
    @State private var showEdit = false

    private var personRelationships: [Relationship] {
        allRelationships
            .filter { $0.personA == person || $0.personB == person }
            .filter { rel in
                let hasSibling = allRelationships.contains { sib in
                    sib.objectID != rel.objectID &&
                    sib.personA == rel.personB && sib.personB == rel.personA
                }
                guard hasSibling else { return true }
                let dir = ArrowDirection.from(rel.arrowDirection)
                return rel.personA == person
                    ? (dir == .aToB || dir == .both)
                    : (dir == .bToA || dir == .both)
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ハンドル
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black.opacity(0.2))
                .frame(width: 40, height: 6)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // ヘッダー
                    HStack(spacing: 12) {
                        if let data = person.photoData, let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable().scaledToFill()
                                .frame(width: 60, height: 60).clipShape(Circle())
                        } else {
                            Circle().fill(Color(.systemGray3))
                                .frame(width: 60, height: 60)
                                .overlay(Text(String((person.name ?? "").prefix(1)))
                                    .font(.title2.bold()).foregroundColor(.white))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.name ?? "").font(.headline).foregroundColor(.primary)
                        }
                        Spacer()
                        Button { showEdit = true } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2).foregroundColor(Color.black.opacity(0.4))
                        }
                    }

                    if let ch = person.characteristics, !ch.isEmpty {
                        Text(ch).font(.body).foregroundColor(.primary)
                    }

                    Divider().background(Color.black.opacity(0.15))

                    // 所属・誕生日・関係を同じセクションに表示
                    let affiliationSet = (person.affiliations as? Set<Affiliation>) ?? []
                    if !affiliationSet.isEmpty {
                        Text("所属").font(.caption).foregroundColor(.primary)
                        HStack(spacing: 6) {
                            ForEach(Array(affiliationSet), id: \.objectID) { aff in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: aff.colorHex ?? "#3498DB"))
                                        .frame(width: 8, height: 8)
                                    Text(aff.name ?? "")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.07))
                                .cornerRadius(12)
                            }
                        }
                    }

                    if let bd = person.birthday {
                        Text("誕生日").font(.caption).foregroundColor(.primary)
                        Text(bd.formatted(Date.FormatStyle().locale(Locale(identifier: "ja_JP")).year().month().day()))
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.07))
                            .cornerRadius(12)
                    }

                    if !personRelationships.isEmpty {
                        Text("関係").font(.caption).foregroundColor(.primary)
                            .padding(.top, (!affiliationSet.isEmpty || person.birthday != nil) ? 4 : 0)
                        ForEach(personRelationships, id: \.objectID) { rel in
                            RelationshipRow(relationship: rel, person: person)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color(red: 245/255, green: 245/255, blue: 245/255))
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .frame(maxHeight: UIScreen.main.bounds.height * 0.45)
        .fullScreenCover(isPresented: $showEdit) {
            PersonEditView(person: person, onDeleted: {
                onClose?()
            })
        }
    }
}

private struct RelationshipRow: View {
    let relationship: Relationship
    let person: Person

    var body: some View {
        let other = relationship.personA == person ? relationship.personB : relationship.personA
        let level = RelationshipLevel.from(relationship.level)
        HStack(spacing: 8) {
            Group {
                if UIImage(named: level.imageName) != nil {
                    Image(level.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                } else if let symbol = level.sfSymbolName {
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.red)
                        .frame(width: 28, height: 28)
                } else {
                    Text(level.icon).font(.title3)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(other?.name ?? "").font(.subheadline).foregroundColor(.primary)
                if let label = relationship.label, !label.isEmpty {
                    Text(label).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
