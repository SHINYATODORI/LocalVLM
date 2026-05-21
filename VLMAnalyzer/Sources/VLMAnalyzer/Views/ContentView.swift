import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppViewModel.self) private var vm
    @State private var memMonitor = MemoryMonitor()
    @State private var showReport  = false
    @State private var isDragOver  = false

    private let columns = [GridItem(.adaptive(minimum: 290, maximum: 400), spacing: 16)]

    var body: some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            commonPromptBar(binding: $vm.commonPrompt)
            Divider()
            if vm.images.isEmpty {
                dropZone
            } else {
                imageGrid
            }
            Divider()
            statusBar
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $showReport) {
            ReportView(htmlContent: vm.generateHTMLReport())
        }
        .onAppear {
            memMonitor.start()
            Task { await vm.loadModels() }
        }
        .onDisappear { memMonitor.stop() }
    }

    // MARK: - Model picker (segmented pills)

    private var modelPicker: some View {
        @Bindable var vm = vm
        let models = vm.vlModels.isEmpty ? vm.availableModels : vm.vlModels
        return HStack(spacing: 2) {
            Image(systemName: "cpu.fill")
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
                .padding(.trailing, 4)

            if models.isEmpty {
                Text(vm.selectedModel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 1) {
                    ForEach(models, id: \.self) { model in
                        let isSelected = vm.selectedModel == model
                        Button {
                            vm.selectedModel = model
                        } label: {
                            Text(shortName(model))
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(isSelected ? Color.accentColor : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(model)
                    }
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(.separatorColor).opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color(.separatorColor).opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }

    /// "qwen3-vl:8b" → "Qwen3-VL 8B" のような短い表示名
    private func shortName(_ model: String) -> String {
        let base = model.components(separatedBy: ":").first ?? model
        let tag  = model.components(separatedBy: ":").last ?? ""
        // qwen2.5vl → Q2.5VL, qwen3-vl → Q3-VL etc.
        let pretty = base
            .replacingOccurrences(of: "qwen3-vl",  with: "Q3-VL",  options: .caseInsensitive)
            .replacingOccurrences(of: "qwen2.5vl",  with: "Q2.5-VL", options: .caseInsensitive)
            .replacingOccurrences(of: "qwen3",      with: "Q3",      options: .caseInsensitive)
            .replacingOccurrences(of: "llava",       with: "LLaVA",   options: .caseInsensitive)
        return tag.isEmpty ? pretty : "\(pretty) \(tag.uppercased())"
    }

    // MARK: - Common prompt bar (enlarged)

    private func commonPromptBar(binding: Binding<String>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Label("共通プロンプト", systemImage: "text.bubble.fill")
                .font(.system(size: 13).weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize()
                .padding(.top, 6)

            TextEditor(text: binding)
                .font(.system(size: 14))
                .frame(minHeight: 64, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .background(Color(.textBackgroundColor))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if binding.wrappedValue.isEmpty {
                        Text("全画像に適用されるプロンプトを入力…")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 5)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Image grid

    private var imageGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(vm.images) { item in
                    ImageCardView(item: item)
                }
            }
            .padding()
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragOver, perform: handleDrop)
        .overlay(alignment: .bottom) {
            if isDragOver {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding()
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Drop zone (empty state)

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isDragOver ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .padding(32)

            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 56))
                    .foregroundStyle(.tertiary)
                Text("画像をここにドロップ")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Button("ファイルを選択", action: openFilePicker)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $isDragOver, perform: handleDrop)
    }

    // MARK: - Bottom status bar

    private var statusBar: some View {
        HStack(spacing: 0) {
            // Progress (only while analyzing)
            if vm.isAnalyzingAll {
                HStack(spacing: 10) {
                    ProgressView(
                        value: Double(vm.analyzedCount),
                        total: Double(max(vm.analyzeTotal, 1))
                    )
                    .frame(width: 130)
                    .tint(.accentColor)

                    Text("\(vm.analyzedCount) / \(vm.analyzeTotal) 解析中")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 14)
                .padding(.trailing, 8)

                Divider().frame(height: 24)
            }

            Spacer()

            MemoryGraphView(monitor: memMonitor)
        }
        .frame(height: 58)
        .background(.bar)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: openFilePicker) {
                Label("画像を追加", systemImage: "plus.circle.fill")
            }
            .help("画像ファイルを追加")
        }

        ToolbarItem(placement: .navigation) {
            modelPicker
        }

        ToolbarItemGroup(placement: .primaryAction) {
            if vm.isAnalyzingAll {
                ProgressView().scaleEffect(0.75).padding(.trailing, 4)
            }

            Button {
                Task { await vm.analyzeAll() }
            } label: {
                Label("全件解析", systemImage: "bolt.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.images.isEmpty || vm.isAnalyzingAll)
            .help("全画像を同時に解析")

            Button { showReport = true } label: {
                Label("レポート生成", systemImage: "doc.richtext")
            }
            .disabled(vm.images.isEmpty)
            .help("HTMLレポートを生成（画像付き）")
        }
    }

    // MARK: - File picker

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories   = false
        panel.allowedContentTypes    = [.image, .jpeg, .png, .heic, .gif, .bmp, .tiff]
        panel.message = "解析する画像を選択してください"
        if panel.runModal() == .OK { vm.addImages(urls: panel.urls) }
    }

    // MARK: - Drag & drop

    @discardableResult
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { vm.addImages(urls: urls) }
        return true
    }
}
