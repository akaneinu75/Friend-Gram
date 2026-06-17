import SwiftUI
import CoreData

struct MemoryQuizView: View {
    let graph: Graph

    @Environment(\.managedObjectContext) private var ctx
    @StateObject private var viewModel = MemoryQuizViewModel()

    @FetchRequest private var persons: FetchedResults<Person>
    @FetchRequest private var affiliations: FetchedResults<Affiliation>
    @FetchRequest private var relationships: FetchedResults<Relationship>

    init(graph: Graph) {
        self.graph = graph
        let graphPred = NSPredicate(format: "graph == %@", graph)
        _persons = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Person.createdAt, ascending: true)],
            predicate: graphPred
        )
        _affiliations = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Affiliation.name, ascending: true)],
            predicate: graphPred
        )
        _relationships = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Relationship.createdAt, ascending: true)],
            predicate: NSPredicate(format: "personA.graph == %@", graph)
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .selecting:
                    let unaffiliatedPersons = persons.filter { (($0.affiliations as? Set<Affiliation>) ?? []).isEmpty }
                    GroupSelectionView(affiliations: Array(affiliations), unaffiliatedPersons: unaffiliatedPersons) { selectedAffiliations, includeUnaffiliated in
                        viewModel.startQuiz(affiliations: selectedAffiliations, includeUnaffiliated: includeUnaffiliated, allPersons: Array(persons))
                    }
                case .playing:
                    if let question = viewModel.currentQuestion {
                        QuizPlayingView(
                            question: question,
                            currentIndex: viewModel.currentIndex,
                            total: viewModel.questions.count,
                            selectedChoice: viewModel.selectedChoice,
                            isAnswerLocked: viewModel.isAnswerLocked,
                            onSelect: { choice in viewModel.selectAnswer(choice, context: ctx) },
                            onQuit: { viewModel.reset() }
                        )
                    }
                case .revealing:
                    if let question = viewModel.currentQuestion {
                        QuizRevealView(
                            person: question.person,
                            allRelationships: Array(relationships),
                            onNext: { viewModel.proceedAfterReveal() },
                            onQuit: { viewModel.reset() }
                        )
                    }
                case .finished:
                    QuizResultView(
                        correctCount: viewModel.correctCount,
                        total: viewModel.questions.count,
                        onRetry: { viewModel.restartSameGroup(allPersons: Array(persons)) },
                        onBack: { viewModel.reset() }
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("所属グループを選択")
                        .font(.headline)
                        .padding()
                        .opacity(viewModel.phase == .selecting ? 1 : 0)
                }
            }
        }
    }
}

// MARK: - グループ選択

private struct GroupSelectionView: View {
    let affiliations: [Affiliation]
    let unaffiliatedPersons: [Person]
    let onStart: (Set<Affiliation>, Bool) -> Void

    @State private var selectedAffiliations: Set<Affiliation> = []
    @State private var includeUnaffiliated = false

    private func eligibleCount(_ affiliation: Affiliation) -> Int {
        ((affiliation.members as? Set<Person>) ?? []).filter { $0.photoData != nil }.count
    }

    private var unaffiliatedEligibleCount: Int {
        unaffiliatedPersons.filter { $0.photoData != nil }.count
    }

    private var totalEligibleCount: Int {
        var pool: Set<Person> = []
        for affiliation in selectedAffiliations {
            for person in (affiliation.members as? Set<Person>) ?? [] where person.photoData != nil {
                pool.insert(person)
            }
        }
        if includeUnaffiliated {
            for person in unaffiliatedPersons where person.photoData != nil {
                pool.insert(person)
            }
        }
        return pool.count
    }

    private var isAllSelected: Bool {
        selectedAffiliations.count == affiliations.count && includeUnaffiliated
    }

    private var hasSelection: Bool {
        !selectedAffiliations.isEmpty || includeUnaffiliated
    }

    private func toggleSelectAll() {
        if isAllSelected {
            selectedAffiliations = []
            includeUnaffiliated = false
        } else {
            selectedAffiliations = Set(affiliations)
            includeUnaffiliated = true
        }
    }

    private func toggle(_ affiliation: Affiliation) {
        if selectedAffiliations.contains(affiliation) {
            selectedAffiliations.remove(affiliation)
        } else {
            selectedAffiliations.insert(affiliation)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(isAllSelected ? "全解除" : "全選択") {
                    toggleSelectAll()
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .padding()
            List {
                ForEach(affiliations, id: \.objectID) { affiliation in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: affiliation.colorHex ?? "#3498DB"))
                            .frame(width: 14, height: 14)
                        Text(affiliation.name ?? "")
                            .font(.body)
                        Spacer()
                        Text("出題可能: \(eligibleCount(affiliation))人")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: selectedAffiliations.contains(affiliation) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedAffiliations.contains(affiliation) ? .accentColor : Color(.tertiaryLabel))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { toggle(affiliation) }
                }

                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 14, height: 14)
                    Text("未所属")
                        .font(.body)
                    Spacer()
                    Text("出題可能: \(unaffiliatedEligibleCount)人")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: includeUnaffiliated ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(includeUnaffiliated ? .accentColor : Color(.tertiaryLabel))
                }
                .contentShape(Rectangle())
                .onTapGesture { includeUnaffiliated.toggle() }
            }
            .listStyle(.plain)

            VStack(spacing: 8) {
                if hasSelection && totalEligibleCount == 0 {
                    Text("選択したグループには顔写真付きの人物がいません")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                Button {
                    onStart(selectedAffiliations, includeUnaffiliated)
                } label: {
                    Text("スタート")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(totalEligibleCount == 0)
            }
            .padding()
        }
    }
}

// MARK: - 出題中

private struct QuizPlayingView: View {
    let question: QuizQuestion
    let currentIndex: Int
    let total: Int
    let selectedChoice: String?
    let isAnswerLocked: Bool
    let onSelect: (String) -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button("やめる") { onQuit() }
                    .foregroundColor(.secondary)
                Spacer()
                Text("問題 \(currentIndex + 1) / \(total)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if let data = question.person.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 220, height: 220)
                    .clipShape(Circle())
            }

            Text("この人は誰？")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                ForEach(question.choices, id: \.self) { choice in
                    Button {
                        onSelect(choice)
                    } label: {
                        Text(choice)
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(backgroundColor(for: choice))
                            .foregroundColor(foregroundColor(for: choice))
                            .cornerRadius(12)
                    }
                    .disabled(isAnswerLocked)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private func backgroundColor(for choice: String) -> Color {
        isAnswerLocked && selectedChoice == choice ? .green : Color(.systemGray5)
    }

    private func foregroundColor(for choice: String) -> Color {
        isAnswerLocked && selectedChoice == choice ? .white : .primary
    }
}

// MARK: - 不正解時の解答表示

private struct QuizRevealView: View {
    let person: Person
    let allRelationships: [Relationship]
    let onNext: () -> Void
    let onQuit: () -> Void

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
        VStack(spacing: 0) {
            HStack {
                Button("やめる") { onQuit() }
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if let data = person.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 220, height: 220)
                    .clipShape(Circle())
                    .padding(.top, 24)
            }

            ScrollView {
                VStack(spacing: 16) {
                    Text(person.name ?? "")
                        .font(.title2.bold())
                    
                    Text("不正解...")
                        .font(.title3.bold())
                        .foregroundColor(.red)

                    if let ch = person.characteristics, !ch.isEmpty {
                        Text(ch)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if !personRelationships.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("関係")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(personRelationships, id: \.objectID) { rel in
                                QuizRelationshipRow(relationship: rel, person: person)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 16)
            }

            Button {
                onNext()
            } label: {
                Text("次へ")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}

private struct QuizRelationshipRow: View {
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

// MARK: - 結果表示

private struct QuizResultView: View {
    let correctCount: Int
    let total: Int
    let onRetry: () -> Void
    let onBack: () -> Void

    private var percentage: Int {
        guard total > 0 else { return 0 }
        return Int((Double(correctCount) / Double(total) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("結果")
                .font(.largeTitle.bold())
            Text("\(total)人中 \(correctCount)人正解")
                .font(.title2)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    onRetry()
                } label: {
                    Text("もう一度")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onBack()
                } label: {
                    Text("グループ選択に戻る")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}

#Preview {
    let ctx = PersistenceController.preview.container.viewContext
    let g = Graph(context: ctx)
    g.id = UUID(); g.name = "Preview"; g.createdAt = Date()
    return MemoryQuizView(graph: g)
        .environment(\.managedObjectContext, ctx)
        .environmentObject(ActiveGraphManager(ctx: ctx))
}
