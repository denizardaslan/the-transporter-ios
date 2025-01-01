import SwiftUI
import UniformTypeIdentifiers

struct FileListView: View {
    @State private var fileURLs: [URL] = []
    @State private var selectedURLs: Set<URL> = []
    @State private var isSharing: Bool = false

    var body: some View {
        List(selection: $selectedURLs) { 
            ForEach(fileURLs, id: \.self) { url in
                Text(url.lastPathComponent)
            }
            .onDelete(perform: deleteFiles) 
        }
        .navigationTitle("Previous Sessions")
        .onAppear(perform: loadFiles)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !selectedURLs.isEmpty {
                    ShareLink(items: Array(selectedURLs))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }

    func loadFiles() {
        do {
            let documentDirectory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let files = try FileManager.default.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)
            fileURLs = files.filter { $0.pathExtension == "json" }
        } catch {
            print("Error loading files: \(error)")
        }
    }

    func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let fileURL = fileURLs[index]
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("Deleted file: \(fileURL)")
            } catch {
                print("Error deleting file: \(error)")
            }
        }
        loadFiles() 
    }
} 