import Foundation

actor SessionDraftStore {
    typealias DTO = WorkoutSessionDTO
    
    private let url: URL
    private var draft: DTO?
    private var pending: Bool = false
    private var saveTask: Task<Void, Never>?
    private let debounce: Duration = .seconds(1)
    private let maxDebounce: Duration = .seconds(3)
    private var bursts: Int = 0
    
    private var subs: [UUID: AsyncStream<DTO?>.Continuation] = [:]
    
    init (url: URL) {
        self.url = url
    }
    
    func load () -> DTO? {
        if draft != nil { return draft }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: url)
            draft = try JSONDecoder().decode(DTO.self, from: data)
            fanout()
            return draft
        }catch {
            return nil
        }
    }
    
    func stream () -> AsyncStream<DTO?> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { c in
            Task { [weak self] in
                guard let self else { return }
                let id = UUID()
                await self.register(id: id, c)
                c.yield(await self.draft)
                c.onTermination = { @Sendable _ in
                    Task { [weak self] in
                        await self?.unregister(id: id)
                    }
                }
            }
        }
    }
    
    func replace(_ dto: DTO, persistImmediately: Bool = false) {
        draft = dto
        fanout()
        scheduleSave(immediate: persistImmediately)
    }

    func clear() {
        draft = nil
        cancelSave()
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        
        fanout()
    }
    
    private func scheduleSave(immediate: Bool) {
        pending = true
        cancelSave()
        
        if immediate {
            saveTask = Task { [weak self] in await self?.flushNow() }
            return
        }
        
        saveTask = Task { [weak self, debounce] in
            try? await Task.sleep(for: debounce)
            await self?.flushIfNeeded()
        }
        
        Task { [weak self, maxDebounce] in
            try? await Task.sleep(for: maxDebounce)
            await self?.flushIfNeeded()
        }
    }
    
    private func flushIfNeeded() {
        guard pending else { return }
        pending = false
        saveFile()
    }

    private func flushNow() {
        pending = false
        saveFile()
    }

    private func cancelSave() {
        saveTask?.cancel()
        saveTask = nil
    }
    
    private func saveFile () {
        guard let dto = draft else { return }
        
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            let data = try JSONEncoder().encode(dto)
            try data.write(to: url, options: .atomic)
            
        }catch {
            fatalError("SessionDraftStore: Failed to save file to FileManager - \(error.localizedDescription)")
        }
    }
    
    private func removeFileIfAny() {
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    private func register(id: UUID, _ c: AsyncStream<DTO?>.Continuation) {
        subs[id] = c
    }
    
    private func unregister(id: UUID) {
        subs[id] = nil
    }
    
    private func fanout() {
        for c in subs.values {
            c.yield(
                draft
            )
        }
    }
    
}
