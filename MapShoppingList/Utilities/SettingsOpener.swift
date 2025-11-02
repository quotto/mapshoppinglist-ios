import Foundation
import UIKit

protocol SettingsOpening {
    func openAppSettings()
}

struct SystemSettingsOpener: SettingsOpening {
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        DispatchQueue.main.async {
            guard UIApplication.shared.canOpenURL(url) else { return }
            UIApplication.shared.open(url)
        }
    }
}
