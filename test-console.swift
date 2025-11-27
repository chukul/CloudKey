#!/usr/bin/env swift

import Foundation
import AppKit

print("Testing AWS Console URL opening...")

let testURL = "https://console.aws.amazon.com/"
if let url = URL(string: testURL) {
    let success = NSWorkspace.shared.open(url)
    print(success ? "✅ Browser opened" : "❌ Failed to open browser")
} else {
    print("❌ Invalid URL")
}

// Keep script running briefly
sleep(2)
