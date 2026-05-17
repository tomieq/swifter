//
//  SwifterTests.swift
//  SwifterTests
//
//  Copyright © 2016 Damian Kołakowski. All rights reserved.
//

import Testing

@Suite struct SwifterTestsStringExtensions {
    @Test func sha1() {
        #expect("".sha1() == "da39a3ee5e6b4b0d3255bfef95601890afd80709")
        #expect("test".sha1() == "a94a8fe5ccb19ba61c4c0873d391e987982fbbd3")

        // Values copied from OpenSSL:
        // https://github.com/openssl/openssl/blob/master/test/sha1test.c

        #expect("abc".sha1() == "a9993e364706816aba3e25717850c26c9cd0d89d")
        #expect("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".sha1() ==
            "84983e441c3bd26ebaae4aa1f95129e5e54670f1")

        #expect(
            ("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" +
                "a9993e364706816aba3e25717850c26c9cd0d89d" +
                "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" +
                "a9993e364706816aba3e25717850c26c9cd0d89d" +
                "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" +
                "a9993e364706816aba3e25717850c26c9cd0d89d" +
                "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" +
                "a9993e364706816aba3e25717850c26c9cd0d89d" +
                "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" +
                "a9993e364706816aba3e25717850c26c9cd0d89d" +
                "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" +
                "a9993e364706816aba3e25717850c26c9cd0d89d" +
                "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq").sha1() ==
                "a377b0c42d685fdc396e29a9eda7101d900947ca")
    }

    @Test func base64() {
        #expect(String.toBase64([UInt8]("".utf8)) == "")

        // Values copied from OpenSSL:
        // https://github.com/openssl/openssl/blob/995197ab84901df1cdf83509c4ce3511ea7f5ec0/test/evptests.txt

        #expect(String.toBase64([UInt8]("h".utf8)) == "aA==")
        #expect(String.toBase64([UInt8]("hello".utf8)) == "aGVsbG8=")
        #expect(String.toBase64([UInt8]("hello world!".utf8)) == "aGVsbG8gd29ybGQh")
        #expect(String.toBase64([UInt8]("OpenSSLOpenSSL\n".utf8)) == "T3BlblNTTE9wZW5TU0wK")
        #expect(String.toBase64([UInt8]("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx".utf8)) ==
            "eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eA==")
        #expect(String.toBase64([UInt8]("h".utf8)) == "aA==")
    }

    @Test func miscUnquote() {
        #expect("".unquote() == "")
        #expect("\"".unquote() == "\"")
        #expect("\"\"".unquote() == "")

        #expect("1234".unquote() == "1234")
        #expect("1234\"".unquote() == "1234\"")
        #expect("\"1234".unquote() == "\"1234")
        #expect("\"1234\"".unquote() == "1234")
        #expect("\"1234\"".unquote() == "1234")

        #expect("\"\"\"".unquote() == "\"")
        #expect("\"\" \"\"".unquote() == "\" \"")
    }

    @Test func miscTrim() {
        #expect("".trimmingCharacters(in: .whitespacesAndNewlines) == "")
        #expect(" ".trimmingCharacters(in: .whitespacesAndNewlines) == "")
        #expect("      ".trimmingCharacters(in: .whitespacesAndNewlines) == "")
        #expect("1 test     ".trimmingCharacters(in: .whitespacesAndNewlines) == "1 test")
        #expect("      test          ".trimmingCharacters(in: .whitespacesAndNewlines) == "test")
        #expect("   \t\n\rtest          ".trimmingCharacters(in: .whitespacesAndNewlines) == "test")
        #expect("   \t\n\rtest  n   \n\t asd    ".trimmingCharacters(in: .whitespacesAndNewlines) == "test  n   \n\t asd")
    }

    @Test func miscReplace() {
        #expect("".replacingOccurrences(of: "+", with: "-") == "")
        #expect("test".replacingOccurrences(of: "+", with: "-") == "test")
        #expect("+++".replacingOccurrences(of: "+", with: "-") == "---")
        #expect("t&e&s&t12%3%".replacingOccurrences(of: "&", with: "+").replacingOccurrences(of: "%", with: "+") == "t+e+s+t12+3+")
        #expect("test 1234 #$%^&*( test   ".replacingOccurrences(of: " ", with: "_") == "test_1234_#$%^&*(_test___")
    }

    @Test func miscRemovePercentEncoding() {
        #expect("".removingPercentEncoding! == "")
        #expect("%20".removingPercentEncoding! == " ")
        #expect("%22".removingPercentEncoding! == "\"")
        #expect("%25".removingPercentEncoding! == "%")
        #expect("%2d".removingPercentEncoding! == "-")
        #expect("%2e".removingPercentEncoding! == ".")
        #expect("%3C".removingPercentEncoding! == "<")
        #expect("%3E".removingPercentEncoding! == ">")
        #expect("%5C".removingPercentEncoding! == "\\")
        #expect("%5E".removingPercentEncoding! == "^")
        #expect("%5F".removingPercentEncoding! == "_")
        #expect("%60".removingPercentEncoding! == "`")
        #expect("%7B".removingPercentEncoding! == "{")
        #expect("%7C".removingPercentEncoding! == "|")
        #expect("%7D".removingPercentEncoding! == "}")
        #expect("%7E".removingPercentEncoding! == "~")
        #expect("%7e".removingPercentEncoding! == "~")
    }
}
