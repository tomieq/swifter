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
        transferredBytes
    }

    func startCounting() {
        transferredBytes = 0
    }
    
    func countBytes(_ bytes: UInt64) {
        transferredBytes += bytes
    }
}
