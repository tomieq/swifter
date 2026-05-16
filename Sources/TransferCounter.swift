//
//  TransferCounter.swift
//
//
//  Created by Tomasz on 16/11/2024.
//

import Foundation

class TransferCounter {
    private var transferredBytes: UInt64 = 0

    var transfer: UInt64 {
        self.transferredBytes
    }

    func startCounting() {
        self.transferredBytes = 0
    }

    func countBytes(_ bytes: UInt64) {
        self.transferredBytes += bytes
    }
}
