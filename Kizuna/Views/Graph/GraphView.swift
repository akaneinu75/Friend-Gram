import SwiftUI
import CoreData
import StoreKit

struct GraphView: View {
    let graph: Graph

    @Environment(\.managedObjectContext) private var ctx
    @EnvironmentObject private var graphManager: ActiveGraphManager
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

    @StateObject private var vm = GraphViewModel()

    private enum GesturePhase {
        case idle
        case decidingOnNode(Person)
        case creatingRelationship(Person)
        case movingNode(Person)
        case panning(lastTranslation: CGSize)
    }
    @State private var phase: GesturePhase = .idle
    @State private var pinchStart: (scale: CGFloat, offset: CGSize)?
    @State private var longPressTimer: Timer?
    @State private var didFitOnce = false
    @State private var contextRevision = 0
    @State private var showTutorial = false
    @State private var showScreenshotOptions = false
    @State private var showSettings = false
    @State private var showSearch = false
    @State private var searchText = ""
    @FocusState private var searchFieldFocused: Bool
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    @AppStorage("graphBackgroundColorHex") private var bgColorHex = "#1E242E"
    @AppStorage("hasRequestedAppReview") private var hasRequestedAppReview = false
    @Environment(\.requestReview) private var requestReview

    private var isIdle: Bool {
        if case .idle = phase { return true }
        return false
    }

    private var searchResults: [Person] {
        guard !searchText.isEmpty else { return [] }
        return persons.filter { ($0.name ?? "").localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let isLightBg = Color.isLight(hex: bgColorHex)
            let floatBtnBg: Color  = isLightBg ? Color.white.opacity(0.88) : Color.black.opacity(0.60)
            let floatBtnFg: Color  = isLightBg ? Color(.label)        : .white
            ZStack {
                Color(hex: bgColorHex).ignoresSafeArea()

                GraphCanvasLayer(
                    persons: Array(persons),
                    relationships: Array(relationships),
                    offset: vm.offset,
                    scale: vm.scale,
                    canvasSize: vm.canvasSize,
                    viewSize: size,
                    dragSourcePerson: vm.dragSourcePerson,
                    dragCurrentPosition: vm.dragCurrentPosition,
                    draggingPerson: vm.draggingPerson,
                    draggingScreenPosition: vm.draggingScreenPosition,
                    contextRevision: contextRevision,
                    isLightBackground: isLightBg
                )

                ForEach(Array(persons), id: \.objectID) { person in
                    AnimatedPersonNode(
                        person: person,
                        isSelected: vm.selectedPerson == person,
                        offset: vm.offset,
                        scale: vm.scale,
                        canvasSize: vm.canvasSize,
                        viewSize: size,
                        draggingPerson: vm.draggingPerson,
                        draggingScreenPosition: vm.draggingScreenPosition,
                        isLightBackground: isLightBg,
                        contextRevision: contextRevision
                    )
                }

                // 左上: 最多所属パネル
                VStack {
                    HStack {
                        AffiliationLegendView(
                            persons: Array(persons),
                            offset: vm.offset,
                            scale: vm.scale,
                            canvasSize: vm.canvasSize,
                            viewSize: size,
                            isLightBackground: isLightBg
                        )
                        .opacity(isIdle && !showSearch ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isIdle)
                        .padding(.top, 16)
                        .padding(.leading, 16)
                        Spacer()
                        MinimapView(
                            persons: Array(persons),
                            relationships: Array(relationships),
                            offset: vm.offset,
                            scale: vm.scale,
                            canvasSize: vm.canvasSize,
                            viewSize: size,
                            isLightBackground: isLightBg,
                            onNavigate: { newOffset in
                                withAnimation(.easeOut(duration: 0.2)) {
                                    vm.offset = vm.clampedOffset(newOffset, for: Array(persons), in: size)
                                }
                            }
                        )
                        .opacity(showSearch ? 0 : 1)
                        .padding(.top, 16)
                        .padding(.trailing, 16)
                    }
                    Spacer()
                }

                // フローティングボタン（カメラ・設定）
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Button { showSettings = true } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(floatBtnFg)
                                    .frame(width: 44, height: 44)
                                    .background(floatBtnBg)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            }
                            Button { showScreenshotOptions = true } label: {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(floatBtnFg)
                                    .frame(width: 44, height: 44)
                                    .background(floatBtnBg)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            }
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showSearch = true }
                                searchFieldFocused = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18))
                                    .foregroundColor(floatBtnFg)
                                    .frame(width: 44, height: 44)
                                    .background(floatBtnBg)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 24)
                    }
                }
                .opacity(vm.selectedPerson == nil && isIdle && !showSearch ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: vm.selectedPerson == nil && isIdle && !showSearch)

                if showSearch {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("名前で検索", text: $searchText)
                                    .focused($searchFieldFocused)
                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.regularMaterial)
                            .cornerRadius(10)

                            Button("キャンセル") { closeSearch() }
                        }

                        if !searchText.isEmpty {
                            if searchResults.isEmpty {
                                Text("見つかりませんでした")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.regularMaterial)
                                    .cornerRadius(10)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(searchResults.enumerated()), id: \.element.objectID) { index, person in
                                        Button {
                                            jumpToSearchResult(person, in: size)
                                        } label: {
                                            SearchResultRow(person: person)
                                        }
                                        .buttonStyle(.plain)
                                        if index < searchResults.count - 1 {
                                            Divider().padding(.leading, 56)
                                        }
                                    }
                                }
                                .background(.regularMaterial)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
                }

                if let selected = vm.selectedPerson {
                    VStack {
                        Spacer()
                        PersonDetailSheet(
                            person: selected,
                            allRelationships: Array(relationships),
                            onClose: { withAnimation { vm.selectedPerson = nil } }
                        )
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            .onAppear {
                guard !didFitOnce else { return }
                didFitOnce = true
                if !hasCompletedTutorial && persons.isEmpty {
                    showTutorial = true
                } else if !persons.isEmpty {
                    vm.offset = vm.centerAllOffset(for: Array(persons), in: size)
                }
            }
            .onChange(of: persons.count) { newCount in
                guard !hasRequestedAppReview, newCount >= 10 else { return }
                hasRequestedAppReview = true
                // 追加直後のシート閉じアニメーションと重ならないよう少し待ってから表示
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    requestReview()
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: .NSManagedObjectContextObjectsDidChange, object: ctx)) { notification in
                contextRevision &+= 1
                // Affiliation の属性（色など）が変わった場合、
                // 関連 Person の objectWillChange を発火して PersonNodeView を即時再描画させる
                if let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
                    for aff in updated.compactMap({ $0 as? Affiliation }) {
                        (aff.members as? Set<Person>)?.forEach { $0.objectWillChange.send() }
                    }
                }
            }
            .gesture(buildGesture(in: size))
            .simultaneousGesture(magnificationGesture(in: size))
            .animation(.easeInOut(duration: 0.2), value: vm.selectedPerson?.objectID)
            .fullScreenCover(isPresented: $vm.showAddPerson) {
                if let pos = vm.addPersonPosition {
                    PersonEditView(initialPosition: pos)
                }
            }
            .sheet(isPresented: $vm.showAddRelationship) {
                if let src = vm.relationshipSource, let tgt = vm.relationshipTarget {
                    RelationshipEditView(personA: src, personB: tgt, initialArrowDirection: .aToB)
                }
            }
            .sheet(isPresented: $vm.showEditRelationship) {
                if let rel = vm.editingRelationship,
                   let pA = rel.personA, let pB = rel.personB {
                    RelationshipEditView(personA: pA, personB: pB, existing: rel)
                }
            }
            .sheet(isPresented: $showTutorial) {
                TutorialView(
                    onComplete: { name in
                        let p = Person(context: ctx)
                        p.id = UUID()
                        p.createdAt = Date()
                        p.positionX = 0.5
                        p.positionY = 0.5
                        p.name = name
                        p.graph = graph
                        try? ctx.save()
                        hasCompletedTutorial = true
                        showTutorial = false
                    },
                    onSkip: {
                        hasCompletedTutorial = true
                        showTutorial = false
                    }
                )
                .interactiveDismissDisabled(true)
            }
            .sheet(isPresented: $showScreenshotOptions) {
                ScreenshotOptionsSheet(
                    persons: Array(persons),
                    relationships: Array(relationships),
                    backgroundColor: Color(hex: bgColorHex)
                )
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
                    .environment(\.managedObjectContext, ctx)
                    .environmentObject(graphManager)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Gestures

    private func buildGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let loc = value.location
                let moved = hypot(value.translation.width, value.translation.height)

                switch phase {
                case .idle:
                    let hit = vm.hitTestPerson(Array(persons), at: loc, in: size)
                    if let hit {
                        phase = .decidingOnNode(hit)
                        vm.dragSourcePerson = hit
                        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                            DispatchQueue.main.async {
                                if case .decidingOnNode(let p) = phase {
                                    phase = .movingNode(p)
                                }
                            }
                        }
                    } else {
                        phase = .panning(lastTranslation: value.translation)
                    }

                case .decidingOnNode(let person):
                    if moved > 8 {
                        longPressTimer?.invalidate()
                        phase = .creatingRelationship(person)
                        vm.dragCurrentPosition = loc
                    }

                case .creatingRelationship:
                    vm.dragCurrentPosition = loc

                case .movingNode(let person):
                    vm.movePerson(person, to: loc, in: size)

                case .panning(let lastTranslation):
                    if pinchStart != nil {
                        // ピンチ中は magnificationGesture 側が offset を更新するため、
                        // ここでは translation の基準だけ更新し、offset には触れない
                        phase = .panning(lastTranslation: value.translation)
                    } else {
                        // 直前フレームからの差分のみを現在の offset に加算する。
                        // 基準オフセットをスナップショットせず毎フレーム現在値から
                        // 計算することで、ピンチ終了直後でもジャンプしない
                        let delta = CGSize(
                            width:  value.translation.width  - lastTranslation.width,
                            height: value.translation.height - lastTranslation.height
                        )
                        let raw = CGSize(
                            width:  vm.offset.width  + delta.width,
                            height: vm.offset.height + delta.height
                        )
                        vm.offset = vm.clampedOffset(raw, for: Array(persons), in: size)
                        phase = .panning(lastTranslation: value.translation)
                    }
                }
            }
            .onEnded { value in
                longPressTimer?.invalidate()
                let loc = value.location
                let dist = hypot(value.translation.width, value.translation.height)

                switch phase {
                case .idle:
                    break

                case .decidingOnNode(let person):
                    if dist < 8 {
                        let isDeselecting = vm.selectedPerson == person
                        // selectedPerson と offset を同一 withAnimation で更新してずれを防ぐ
                        withAnimation(.easeInOut(duration: 0.4)) {
                            vm.selectedPerson = isDeselecting ? nil : person
                            if !isDeselecting {
                                vm.offset = vm.centeredOffset(for: person, in: size)
                            }
                        }
                    }

                case .creatingRelationship(let src):
                    let target = vm.hitTestPerson(Array(persons), at: loc, in: size)
                    if let target, target != src {
                        // src→target 方向を表す片方向関係を探す
                        // (src,target,aToB) または (target,src,bToA)
                        let sameDirected = relationships.first { r in
                            (r.personA == src   && r.personB == target
                             && r.arrowDirection == ArrowDirection.aToB.rawValue) ||
                            (r.personA == target && r.personB == src
                             && r.arrowDirection == ArrowDirection.bToA.rawValue)
                        }
                        if let directed = sameDirected {
                            // 同方向の片方向関係が存在 → 編集
                            vm.editingRelationship = directed
                            vm.showEditRelationship = true
                        } else {
                            // 逆方向片方向・both・未作成 → 追加
                            // (both 重複防止・split は RelationshipEditView.save() で処理)
                            vm.relationshipSource = src
                            vm.relationshipTarget = target
                            vm.showAddRelationship = true
                        }
                    }

                case .movingNode(let person):
                    vm.commitPersonPosition(person, to: loc, in: size, context: ctx)

                case .panning:
                    if dist < 8 {
                        let hit = vm.hitTestPerson(Array(persons), at: loc, in: size)
                        if hit == nil {
                            if let rel = vm.hitTestRelationship(Array(relationships), at: loc, in: size) {
                                vm.editingRelationship = rel
                                vm.showEditRelationship = true
                            } else if vm.selectedPerson != nil {
                                withAnimation { vm.selectedPerson = nil }
                            } else {
                                vm.addPersonPosition = vm.screenToGraph(loc, in: size)
                                vm.showAddPerson = true
                            }
                        }
                    }
                }

                phase = .idle
                vm.dragSourcePerson = nil
                vm.dragCurrentPosition = nil
            }
    }

    private func magnificationGesture(in size: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { val in
                let start = pinchStart ?? (vm.scale, vm.offset)
                if pinchStart == nil { pinchStart = start }

                let newScale = max(0.3, min(3.0, start.scale * val))
                let ratio = newScale / start.scale
                let candidateOffset = CGSize(
                    width:  start.offset.width  * ratio,
                    height: start.offset.height * ratio
                )
                vm.scale = newScale
                vm.offset = vm.clampedOffset(candidateOffset, for: Array(persons), in: size)
            }
            .onEnded { _ in
                pinchStart = nil
            }
    }

    // MARK: - Search

    private func jumpToSearchResult(_ person: Person, in size: CGSize) {
        withAnimation(.easeInOut(duration: 0.4)) {
            vm.offset = vm.clampedOffset(vm.offsetToCenter(person, in: size), for: Array(persons), in: size)
        }
        closeSearch()
    }

    private func closeSearch() {
        searchFieldFocused = false
        searchText = ""
        withAnimation(.easeInOut(duration: 0.2)) {
            showSearch = false
        }
    }
}

// MARK: - 左上 所属パネル（Fix 4）

private struct AffiliationLegendView: View {
    let persons: [Person]
    let offset: CGSize
    let scale: CGFloat
    let canvasSize: CGSize
    let viewSize: CGSize
    var isLightBackground: Bool = false

    private func screenPos(_ person: Person) -> CGPoint {
        let x = (person.positionX * canvasSize.width  - canvasSize.width  / 2) * scale + viewSize.width  / 2 + offset.width
        let y = (person.positionY * canvasSize.height - canvasSize.height / 2) * scale + viewSize.height / 2 + offset.height
        return CGPoint(x: x, y: y)
    }

    private var dominant: Affiliation? {
        let visible = persons.filter { p in
            let pos = screenPos(p)
            return pos.x >= 0 && pos.x <= viewSize.width
                && pos.y >= 0 && pos.y <= viewSize.height
        }
        var counts: [Affiliation: Int] = [:]
        for p in visible {
            for aff in (p.affiliations as? Set<Affiliation>) ?? [] {
                counts[aff, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    var body: some View {
        if let aff = dominant {
            let panelBg     = isLightBackground ? Color.white.opacity(0.88) : Color.black.opacity(0.55)
            let labelColor  = isLightBackground ? Color(.secondaryLabel)    : Color.white.opacity(0.6)
            let nameColor   = isLightBackground ? Color(.label)             : Color.white
            let borderColor = isLightBackground ? Color(.systemGray3)       : Color.white.opacity(0.2)
            VStack(alignment: .leading, spacing: 3) {
                Text("コミュニティ")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(labelColor)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: aff.colorHex ?? "#3498DB"))
                        .frame(width: 10, height: 10)
                    Text(aff.name ?? "")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(nameColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(panelBg)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor, lineWidth: 1))
            .shadow(color: .black.opacity(isLightBackground ? 0.1 : 0), radius: 4, y: 2)
        }
    }
}

// MARK: - 検索結果の行

private struct SearchResultRow: View {
    @ObservedObject var person: Person

    var body: some View {
        HStack(spacing: 10) {
            if let data = person.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable().scaledToFill()
                    .frame(width: 36, height: 36).clipShape(Circle())
            } else {
                Circle().fill(Color(.systemGray3))
                    .frame(width: 36, height: 36)
                    .overlay(Text(String((person.name ?? "").prefix(1)))
                        .font(.subheadline.bold()).foregroundColor(.white))
            }
            Text(person.name ?? "")
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#Preview {
    let ctx = PersistenceController.preview.container.viewContext
    let g = Graph(context: ctx)
    g.id = UUID(); g.name = "Preview"; g.createdAt = Date()
    return GraphView(graph: g)
        .environment(\.managedObjectContext, ctx)
        .environmentObject(ActiveGraphManager(ctx: ctx))
}
