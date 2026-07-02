import Combine
import Foundation

extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// Rebroadcast a nested observable's changes as this object's own, so SwiftUI views
    /// observing the parent refresh when a child ObservableObject it owns changes. Replaces the
    /// hand-rolled `child.objectWillChange.receive(on:).sink { objectWillChange.send() }` blocks.
    func forwardObjectWillChange(
        from child: some ObservableObject,
        into cancellables: inout Set<AnyCancellable>
    ) {
        child.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
