import SwiftUI
import CoreData

struct QuizQuestion {
    let person: Person
    let choices: [String]
}

enum QuizPhase {
    case selecting
    case playing
    case revealing
    case finished
}

class MemoryQuizViewModel: ObservableObject {
    @Published var phase: QuizPhase = .selecting
    @Published var selectedAffiliations: Set<Affiliation> = []
    @Published var includeUnaffiliated = false
    @Published var questions: [QuizQuestion] = []
    @Published var currentIndex: Int = 0
    @Published var correctCount: Int = 0
    @Published var selectedChoice: String?
    @Published var isAnswerLocked = false

    let maxQuestions = 10

    var currentQuestion: QuizQuestion? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    func startQuiz(affiliations: Set<Affiliation>, includeUnaffiliated: Bool, allPersons: [Person]) {
        var memberSet: Set<Person> = []
        for affiliation in affiliations {
            for person in (affiliation.members as? Set<Person>) ?? [] {
                memberSet.insert(person)
            }
        }
        if includeUnaffiliated {
            for person in allPersons where ((person.affiliations as? Set<Affiliation>) ?? []).isEmpty {
                memberSet.insert(person)
            }
        }
        let candidates = Array(memberSet.filter { $0.photoData != nil })
        guard !candidates.isEmpty else { return }

        selectedAffiliations = affiliations
        self.includeUnaffiliated = includeUnaffiliated
        let members = Array(memberSet)
        let selected = weightedSample(from: candidates, count: min(maxQuestions, candidates.count))
        questions = selected.map { person in
            QuizQuestion(person: person, choices: makeChoices(for: person, groupMembers: members, allPersons: allPersons))
        }
        currentIndex = 0
        correctCount = 0
        selectedChoice = nil
        isAnswerLocked = false
        phase = .playing
    }

    // 出題回数が少ない・正解率が低い人物ほど重みが大きくなる
    private func weight(for person: Person) -> Double {
        let attempts = person.quizAttemptCount
        guard attempts > 0 else { return 1.0 }
        let accuracy = Double(person.quizCorrectCount) / Double(attempts)
        return max(0.05, 1.0 - accuracy)
    }

    private func weightedSample(from pool: [Person], count: Int) -> [Person] {
        var remaining = pool
        var result: [Person] = []
        for _ in 0..<count {
            let weights = remaining.map(weight)
            let total = weights.reduce(0, +)
            var r = Double.random(in: 0..<total)
            var index = remaining.count - 1
            for (i, w) in weights.enumerated() {
                if r < w {
                    index = i
                    break
                }
                r -= w
            }
            result.append(remaining.remove(at: index))
        }
        return result
    }

    // 正解1人＋不正解3人（グループ内優先、不足分は全人物から補充）
    private func makeChoices(for person: Person, groupMembers: [Person], allPersons: [Person]) -> [String] {
        let correctName = person.name ?? ""
        var usedNames: Set<String> = [correctName]
        var distractors: [String] = []

        for candidate in groupMembers.shuffled() {
            guard distractors.count < 3 else { break }
            guard let name = candidate.name, !name.isEmpty, !usedNames.contains(name) else { continue }
            distractors.append(name)
            usedNames.insert(name)
        }

        if distractors.count < 3 {
            for candidate in allPersons.shuffled() {
                guard distractors.count < 3 else { break }
                guard let name = candidate.name, !name.isEmpty, !usedNames.contains(name) else { continue }
                distractors.append(name)
                usedNames.insert(name)
            }
        }

        var choices = distractors + [correctName]
        choices.shuffle()
        return choices
    }

    func selectAnswer(_ choice: String, context: NSManagedObjectContext) {
        guard !isAnswerLocked, let person = currentQuestion?.person else { return }

        person.quizAttemptCount += 1
        let isCorrect = choice == (person.name ?? "")
        if isCorrect {
            person.quizCorrectCount += 1
            correctCount += 1
        }
        try? context.save()

        selectedChoice = choice

        if isCorrect {
            isAnswerLocked = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.selectedChoice = nil
                self?.isAnswerLocked = false
                self?.advance()
            }
        } else {
            phase = .revealing
        }
    }

    func proceedAfterReveal() {
        selectedChoice = nil
        isAnswerLocked = false
        advance()
    }

    private func advance() {
        if currentIndex + 1 < questions.count {
            currentIndex += 1
            phase = .playing
        } else {
            phase = .finished
        }
    }

    func restartSameGroup(allPersons: [Person]) {
        guard !selectedAffiliations.isEmpty || includeUnaffiliated else { return }
        startQuiz(affiliations: selectedAffiliations, includeUnaffiliated: includeUnaffiliated, allPersons: allPersons)
    }

    func reset() {
        phase = .selecting
        selectedAffiliations = []
        includeUnaffiliated = false
        questions = []
        currentIndex = 0
        correctCount = 0
        selectedChoice = nil
        isAnswerLocked = false
    }
}
