import SwiftUI

struct TutorialView: View {
    let onComplete: (String) -> Void
    let onSkip: () -> Void

    @State private var name = ""
    @State private var pageIndex = 0

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private var nextButtonEnabled: Bool {
        if pageIndex == 0 || pageIndex == 4 { return !trimmedName.isEmpty }
        return true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $pageIndex) {
                    WelcomePage(name: $name).tag(0)
                    PersonTutorialPage().tag(1)
                    RelationshipTutorialPage().tag(2)
                    QuizTutorialPage().tag(3)
                    LetsStartPage(name: trimmedName).tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                navigationButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("スキップ") { onSkip() }
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(i == pageIndex ? Color.accentColor : Color(.systemGray4))
                    .frame(width: i == pageIndex ? 20 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: pageIndex)
            }
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if pageIndex > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { pageIndex -= 1 }
                } label: {
                    Text("戻る")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }

            Button {
                if pageIndex == 4 {
                    onComplete(trimmedName)
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) { pageIndex += 1 }
                }
            } label: {
                Text(pageIndex == 4 ? "始める" : "次へ")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(nextButtonEnabled ? Color.accentColor : Color(.systemGray4))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(!nextButtonEnabled)
        }
    }
}

// MARK: - Page 0: Welcome

private struct WelcomePage: View {
    @Binding var name: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 36)

                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.accentColor)
                }
                .padding(.bottom, 28)

                VStack(spacing: 10) {
                    Text("Friend Gramへようこそ")
                        .font(.title.bold())
                    Text("人物と関係性を整理するアプリです。\nまずはあなた自身を登録してみましょう。")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.bottom, 40)

                VStack(alignment: .leading, spacing: 8) {
                    Text("あなたの名前")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    TextField("例: 山田 太郎", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .submitLabel(.done)
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 32)
            }
        }
    }
}

// MARK: - Page 1: Person Tutorial

private struct PersonTutorialPage: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                personNodeCard
                    .padding(.bottom, 24)

                VStack(spacing: 8) {
                    Text("人物を追加する")
                        .font(.title2.bold())
                    Text("画面上の空きエリアをタップすると\n人物追加画面が開きます。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.bottom, 24)

                TutorialFeatureList(items: [
                    TutorialFeatureItem(icon: "person.fill",    color: .blue,
                                        title: "名前",
                                        description: "グラフ上に表示される人物の名前"),
                    TutorialFeatureItem(icon: "text.alignleft", color: .green,
                                        title: "特徴",
                                        description: "特記事項や覚え書きを自由に記入"),
                    TutorialFeatureItem(icon: "circle.fill",    color: .orange,
                                        title: "所属",
                                        description: "グループをカラーのリングで表示"),
                ])
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)
            }
        }
    }

    private var personNodeCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGroupedBackground))
                .frame(height: 150)
                .padding(.horizontal, 32)

            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 62, height: 62)
                        .overlay(
                            Text("山")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        )
                }
                Text("山田 太郎")
                    .font(.footnote.bold())
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Page 2: Relationship Tutorial

private struct RelationshipTutorialPage: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                relationshipCard
                    .padding(.bottom, 24)

                VStack(spacing: 8) {
                    Text("関係を追加する")
                        .font(.title2.bold())
                    Text("一方の人物から他の人物へドラッグすると\n関係追加画面が開きます。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.bottom, 24)

                TutorialFeatureList(items: [
                    TutorialFeatureItem(icon: "arrow.right",      color: .blue,
                                        title: "矢印",
                                        description: "関係の方向"),
                    TutorialFeatureItem(icon: "text.bubble.fill", color: .purple,
                                        title: "関係テキスト",
                                        description: "「上司」「幼なじみ」などの関係名"),
                    TutorialFeatureItem(icon: "heart.fill",       color: .red,
                                        title: "アイコン",
                                        description: "関係の深さを5段階のアイコンで表示"),
                ])
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)
            }
        }
    }

    private var relationshipCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGroupedBackground))
                .frame(height: 130)
                .padding(.horizontal, 32)

            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    miniNode(initial: "山", color: .orange)

                    // 左ライン
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 2)

                    // バッジ
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 30, height: 30)
                            .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
                        Group {
                            if UIImage(named: RelationshipLevel.friendly.imageName) != nil {
                                Image(RelationshipLevel.friendly.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            } else {
                                Text(RelationshipLevel.friendly.icon)
                                    .font(.subheadline)
                            }
                        }
                    }

                    // 右ライン + 矢印
                    ZStack(alignment: .trailing) {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(height: 2)
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: 7))
                            .foregroundColor(Color(.systemGray4))
                    }

                    miniNode(initial: "鈴", color: .yellow)
                }
                .padding(.horizontal, 48)

                Text("友人")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func miniNode(initial: String, color: Color) -> some View {
        ZStack {
            Circle().fill(color).frame(width: 44, height: 44)
            Circle().fill(Color(.systemGray3)).frame(width: 36, height: 36)
                .overlay(
                    Text(initial)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                )
        }
    }
}

// MARK: - Page 3: Quiz Tutorial

private struct QuizTutorialPage: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                quizCard
                    .padding(.bottom, 24)

                VStack(spacing: 8) {
                    Text("記憶クイズ")
                        .font(.title2.bold())
                    Text("顔写真から名前を当てるクイズで\n人物の記憶を確かめましょう。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.bottom, 24)

                TutorialFeatureList(items: [
                    TutorialFeatureItem(icon: "person.2.fill",       color: .indigo,
                                        title: "グループ選択",
                                        description: "出題したい所属グループを選んでスタート"),
                    TutorialFeatureItem(icon: "questionmark.circle.fill", color: .orange,
                                        title: "4択クイズ",
                                        description: "顔写真を見て名前を4択から選ぶ"),
                    TutorialFeatureItem(icon: "chart.bar.fill",      color: .green,
                                        title: "結果確認",
                                        description: "正解率を確認してまた挑戦できる"),
                ])
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)
            }
        }
    }

    private var quizCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGroupedBackground))
                .frame(height: 150)
                .padding(.horizontal, 32)

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 72, height: 72)
                    Image(systemName: "person.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.white)
                }

                HStack(spacing: 8) {
                    ForEach(["山田 太郎", "鈴木 花子", "佐藤 健", "田中 優"], id: \.self) { name in
                        Text(name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(name == "山田 太郎" ? .white : .primary)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(name == "山田 太郎" ? Color.green : Color(.systemGray5))
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
}

// MARK: - Page 4: Let's Start

private struct LetsStartPage: View {
    let name: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "sparkles")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)
            }
            .padding(.bottom, 36)

            VStack(spacing: 12) {
                Text("準備完了！")
                    .font(.title.bold())
                Text(name.isEmpty ? "さあ、始めましょう！" : "\(name)さん、さあ始めましょう！")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                Text("あなただけの相関図を作りましょう")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Shared components

private struct TutorialFeatureItem {
    let icon: String
    let color: Color
    let title: String
    let description: String
}

private struct TutorialFeatureList: View {
    let items: [TutorialFeatureItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(item.color)
                            .frame(width: 36, height: 36)
                        Image(systemName: item.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline.bold())
                        Text(item.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if idx < items.count - 1 {
                    Divider().padding(.leading, 66)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    TutorialView(onComplete: { _ in }, onSkip: {})
}
