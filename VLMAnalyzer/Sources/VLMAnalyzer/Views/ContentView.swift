import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppViewModel.self) private var vm
    @State private var showReport = false
    @State private var isDragOver = false

    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 16)]

    var body: some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            commonPromptBar(vm: _vm)
            Divider()
            if vm.images.isEmpty {
                dropZone
            } else {
                imageGrid
            }
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $showReport) {
            ReportView(content: vm.generateReport())
        }
    }

    // MARK: - Common prompt bar

    @ViewBuilder
    private func commonPromptBar(vm: Bindable<AppViewModel>) -> some View {
        HStack(spacing: 10) {
            Label("共通プロンプト", systemImage: "text.bubble.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize()

            TextField("全画像に適用されるプロンプトを入力…", text: vm.commonPrompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
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
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Button("ファイルを選択", action: openFilePicker)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $isDragOver, perform: handleDrop)
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

        ToolbarItemGroup(placement: .primaryAction) {
            if vm.isAnalyzingAll {
                ProgressView()
                    .scaleEffect(0.75)
                    .padding(.trailing, 4)
            }

            Button {
                Task { await vm.analyzeAll() }
            } label: {
                Label("全件解析", systemImage: "bolt.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.images.isEmpty || vm.isAnalyzingAll)
            .help("全画像を同時に解析")

            Button {
                showReport = true
            } label: {
                Label("レポート生成", systemImage: "doc.plaintext")
            }
            .disabled(vm.images.isEmpty)
            .help("解析結果のレポートを生成")
        }
    }

    // MARK: - File picker

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .jpeg, .png, .heic, .gif, .bmp, .tiff]
        panel.message = "解析する画像を選択してください"
        if panel.runModal() == .OK {
            vm.addImages(urls: panel.urls)
        }
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
