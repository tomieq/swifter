import Swifter
import Testing

@Suite struct DataSizeTests {
    @Test func initFromDouble() {
        #expect(DataSize(578) == .B(578))
        #expect(DataSize(999) == .B(999))
        #expect(DataSize(1_001) == .KB(1.001))
        #expect(DataSize(56_000) == .KB(56))
        #expect(DataSize(73_000_000) == .MB(73))
        #expect(DataSize(21_000_000_000) == .GB(21))
    }

    @Test func count() {
        #expect(DataSize.B(578).count == 578)
        #expect(DataSize.KB(243).count == 243_000)
        #expect(DataSize.MB(540).count == 540_000_000)
        #expect(DataSize.GB(163).count == 163_000_000_000)
    }

    @Test func stringConvertible() {
        #expect(DataSize.B(578).description == "578 B")
        #expect(DataSize.KB(243).description == "243 KB")
        #expect(DataSize.MB(540).description == "540 MB")
        #expect(DataSize.MB(540.721).description == "540.72 MB")
        #expect(DataSize.GB(163).description == "163 GB")
        #expect(DataSize.GB(163.879).description == "163.88 GB")
    }

    @Test func comparable() {
        #expect(DataSize.B(23) < DataSize.B(27))
        #expect(DataSize.B(23) < DataSize.MB(12))
        #expect(DataSize.MB(23) < DataSize.GB(4))
        #expect(!(DataSize.TB(8) < DataSize.GB(4)))
    }
}
