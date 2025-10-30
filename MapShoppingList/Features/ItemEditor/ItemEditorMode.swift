import Foundation

enum ItemEditorMode: Equatable {
    case create
    case edit(UUID)
}
