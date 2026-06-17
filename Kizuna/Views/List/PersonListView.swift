import SwiftUI
import CoreData

enum PersonSortOrder: String, CaseIterable {
    case affiliation  = "所属順"
    case alphabetical = "五十音順"
    case birthday     = "誕生日が近い順"
}

struct PersonListView: View {
    let graph: Graph

    @FetchRequest private var persons: FetchedResults<Person>
    @FetchRequest private var relationships: FetchedResults<Relationship>

    init(graph: Graph) {
        self.graph = graph
        _persons = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Person.createdAt, ascending: true)],
            predicate: NSPredicate(format: "graph == %@", graph)
        )
        _relationships = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Relationship.createdAt, ascending: true)],
            predicate: NSPredicate(format: "personA.graph == %@", graph)
        )
    }

    @State private var searchText = ""
    @State private var sortOrder: PersonSortOrder = .affiliation
    @State private var selectedPerson: Person?

    private var filtered: [Person] {
        guard !searchText.isEmpty else { return Array(persons) }
        return persons.filter { ($0.name ?? "").localizedCaseInsensitiveContains(searchText) }
    }

    private var sorted: [Person] {
        switch sortOrder {
        case .alphabetical:
            return filtered.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .affiliation:
            return filtered.sorted { a, b in
                let aAff = primaryAffiliationName(a)
                let bAff = primaryAffiliationName(b)
                if aAff != bAff {
                    if aAff.isEmpty { return false }
                    if bAff.isEmpty { return true }
                    return aAff < bAff
                }
                return (a.name ?? "") < (b.name ?? "")
            }
        case .birthday:
            return filtered.sorted { a, b in
                let dA = a.birthday.map { daysUntilNextBirthday($0) } ?? Int.max
                let dB = b.birthday.map { daysUntilNextBirthday($0) } ?? Int.max
                return dA < dB
            }
        }
    }

    private var affiliationSections: [(String, [Person])] {
        var sections: [String: [Person]] = [:]
        var order: [String] = []
        var noAff: [Person] = []

        for person in sorted {
            let name = primaryAffiliationName(person)
            if name.isEmpty {
                noAff.append(person)
            } else {
                if sections[name] == nil {
                    order.append(name)
                    sections[name] = []
                }
                sections[name]!.append(person)
            }
        }
        var result = order.map { (($0), sections[$0]!) }
        if !noAff.isEmpty { result.append(("所属なし", noAff)) }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortOrder == .affiliation {
                    affiliationList
                } else {
                    flatList
                }
            }
            .searchable(text: $searchText, prompt: "名前で検索")
            .navigationTitle("人物一覧")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("並び替え", selection: $sortOrder) {
                            ForEach(PersonSortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Label("並び替え", systemImage: "arrow.up.arrow.down")
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedPerson != nil },
            set: { if !$0 { selectedPerson = nil } }
        )) {
            if let person = selectedPerson {
                PersonDetailSheet(
                    person: person,
                    allRelationships: Array(relationships),
                    onClose: { selectedPerson = nil }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
            }
        }
    }

    private var flatList: some View {
        List(sorted, id: \.objectID) { person in
            PersonListRow(person: person)
                .contentShape(Rectangle())
                .onTapGesture { selectedPerson = person }
                .listRowSeparatorTint(Color(.separator).opacity(0.5))
        }
        .listStyle(.plain)
    }

    private var affiliationList: some View {
        List {
            ForEach(affiliationSections, id: \.0) { title, sectionPersons in
                Section(title) {
                    ForEach(sectionPersons, id: \.objectID) { person in
                        PersonListRow(person: person)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedPerson = person }
                            .listRowSeparatorTint(Color(.separator).opacity(0.5))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func primaryAffiliationName(_ person: Person) -> String {
        (person.affiliations as? Set<Affiliation>)?
            .min(by: { ($0.name ?? "") < ($1.name ?? "") })?.name ?? ""
    }
}

private struct PersonListRow: View {
    @ObservedObject var person: Person

    private var affiliations: [Affiliation] {
        ((person.affiliations as? Set<Affiliation>) ?? [])
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    var body: some View {
        HStack(spacing: 12) {
            if let data = person.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable().scaledToFill()
                    .frame(width: 46, height: 46).clipShape(Circle())
            } else {
                Circle().fill(Color(.systemGray3))
                    .frame(width: 46, height: 46)
                    .overlay(Text(String((person.name ?? "").prefix(1)))
                        .font(.headline).foregroundColor(.white))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(person.name ?? "")
                    .font(.body.weight(.medium))

                if !affiliations.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(affiliations, id: \.objectID) { aff in
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color(hex: aff.colorHex ?? "#3498DB"))
                                    .frame(width: 6, height: 6)
                                Text(aff.name ?? "")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if let bd = person.birthday {
                    Text(birthdayLabel(bd))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, 4)
    }

    private func birthdayLabel(_ date: Date) -> String {
        let days = daysUntilNextBirthday(date)
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日"
        let str = fmt.string(from: date)
        switch days {
        case 0:        return "誕生日: \(str)（今日！）"
        case 1...7:    return "誕生日: \(str)（あと\(days)日）"
        default:       return "誕生日: \(str)"
        }
    }
}

private func daysUntilNextBirthday(_ date: Date) -> Int {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let month = cal.component(.month, from: date)
    let day   = cal.component(.day, from: date)
    let year  = cal.component(.year, from: today)

    var comps = DateComponents()
    comps.month = month
    comps.day   = day
    comps.year  = year
    if let thisYear = cal.date(from: comps), thisYear >= today {
        return cal.dateComponents([.day], from: today, to: thisYear).day ?? 0
    }
    comps.year = year + 1
    if let nextYear = cal.date(from: comps) {
        return cal.dateComponents([.day], from: today, to: nextYear).day ?? 0
    }
    return Int.max
}
