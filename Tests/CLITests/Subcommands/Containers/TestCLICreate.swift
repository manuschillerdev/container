//===----------------------------------------------------------------------===//
// Copyright © 2025 Apple Inc. and the container project authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//===----------------------------------------------------------------------===//

import Foundation
import Testing

class TestCLICreateCommand: CLITest {
    private func getTestName() -> String {
        Test.current!.name.trimmingCharacters(in: ["(", ")"]).lowercased()
    }

    @Test func testCreateArgsPassthrough() throws {
        let name = getTestName()
        #expect(throws: Never.self, "expected container create to succeed") {
            try doCreate(name: name, args: ["echo", "-n", "hello", "world"])
            try doRemove(name: name)
        }
    }

    @Test func testCreateWithMACAddress() throws {
        let name = getTestName()
        let expectedMAC = "02:42:ac:11:00:03"
        #expect(throws: Never.self, "expected container create with MAC address to succeed") {
            try doCreate(name: name, networks: ["default,mac=\(expectedMAC)"])
            try doStart(name: name)
            defer {
                try? doStop(name: name)
                try? doRemove(name: name)
            }
            try waitForContainerRunning(name)
            let inspectResp = try inspectContainer(name)
            #expect(inspectResp.networks.count > 0, "expected at least one network attachment")
            #expect(inspectResp.networks[0].macAddress == expectedMAC, "expected MAC address \(expectedMAC), got \(inspectResp.networks[0].macAddress ?? "nil")")
        }
    }

    @Test func testCreateWithCustomInitFs() throws {
        let name = getTestName()
        let customInitFs = "ghcr.io/linuxcontainers/alpine:3.20"
        #expect(throws: Never.self, "expected container create with custom init-fs to succeed") {
            var arguments = ["create", "--rm", "--name", name, "--init-fs", customInitFs, alpine, "echo", "test"]
            let (_, error, status) = try run(arguments: arguments)
            if status != 0 {
                throw CLIError.executionFailed("command failed: \(error)")
            }

            try doStart(name: name)
            defer {
                try? doStop(name: name)
                try? doRemove(name: name)
            }

            try waitForContainerRunning(name)
            let status2 = try getContainerStatus(name)
            #expect(status2 == "running", "expected container to be running with custom init-fs, instead got status \(status2)")

            let output = try doExec(name: name, cmd: ["echo", "hello"])
            #expect(output.contains("hello"), "expected to successfully exec command using custom init-fs")
        }
    }

    @Test func testCreateWithDefaultInitFs() throws {
        let name = getTestName()
        #expect(throws: Never.self, "expected container create with default init-fs to succeed") {
            try doCreate(name: name, args: ["sleep", "infinity"])
            try doStart(name: name)
            defer {
                try? doStop(name: name)
                try? doRemove(name: name)
            }

            try waitForContainerRunning(name)
            let status = try getContainerStatus(name)
            #expect(status == "running", "expected container to be running with default init-fs, instead got status \(status)")

            let output = try doExec(name: name, cmd: ["echo", "test"])
            #expect(output.contains("test"), "expected to successfully exec command using default init-fs")
        }
    }
}
