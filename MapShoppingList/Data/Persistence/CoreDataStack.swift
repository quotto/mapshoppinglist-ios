import CoreData

/// Core Dataスタックをまとめて管理するクラス。
final class CoreDataStack {
    /// デフォルト共有インスタンス。
    static let shared = CoreDataStack()

    /// モデルファイル名。
    private static let modelName = "MapShoppingList"

    /// 永続コンテナ。
    let container: NSPersistentContainer

    /// イニシャライザ。
    /// - Parameter inMemory: テスト向けにインメモリストアを使う場合は `true`。
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: Self.modelName)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            description.shouldAddStoreAsynchronously = false
            description.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [description]
        } else if let description = container.persistentStoreDescriptions.first {
            // 履歴追跡と自動マイグレーションを有効化。
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data store failed to load: \(error)")
            }
        }

        CoreDataStack.configureContext(container.viewContext)
    }

    /// 画面用のメインコンテキスト。
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// 新しいバックグラウンドコンテキストを生成する。
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        CoreDataStack.configureContext(context)
        return context
    }

    /// バックグラウンドタスクを実行する。
    /// - Parameter block: 処理クロージャ。
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            CoreDataStack.configureContext(context)
            block(context)
        }
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                CoreDataStack.configureContext(context)
                do {
                    try block(context)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// インメモリ構成のスタックを生成するヘルパー（テスト用）。
    static func makeInMemory() -> CoreDataStack {
        CoreDataStack(inMemory: true)
    }

    /// コンテキスト共通設定。
    private static func configureContext(_ context: NSManagedObjectContext) {
        context.mergePolicy = NSErrorMergePolicy
        context.automaticallyMergesChangesFromParent = true
        context.undoManager = nil
    }
}
