//
// Copyright (C) 2015-2019 Virgil Security Inc.
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     (1) Redistributions of source code must retain the above copyright
//     notice, this list of conditions and the following disclaimer.
//
//     (2) Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in
//     the documentation and/or other materials provided with the
//     distribution.
//
//     (3) Neither the name of the copyright holder nor the names of its
//     contributors may be used to endorse or promote products derived from
//     this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
// IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// Lead Maintainer: Virgil Security Inc. <support@virgilsecurity.com>
//

import XCTest
@testable import VirgilE3Kit
import VirgilCrypto
import VirgilSDK
import VirgilCryptoFoundation

class VTE004_GroupTests: XCTestCase {
    var utils: TestUtils!
    let crypto = try! VirgilCrypto()

    override func setUp() {
        let consts = TestConfig.readFromBundle()

        self.utils = TestUtils(crypto: self.crypto, consts: consts)
    }

    private func setUpDevice() -> (EThree) {
        let identity = UUID().uuidString

        let tokenCallback: EThree.RenewJwtCallback = { completion in
            let token = self.utils.getTokenString(identity: identity)

            completion(token, nil)
        }

        let ethree = try! EThree.initialize(tokenCallback: tokenCallback).startSync().get()

        try! ethree.register().startSync().get()

        return ethree
    }

    func test_STE_26__create_with_invalid_participants_count__should_throw_error() {
        let ethree = self.setUpDevice()

        let groupId = try! self.crypto.generateRandomData(ofSize: 100)

        let card = try! ethree.lookupCard(of: ethree.identity).startSync().get()

        do {
            _ = try ethree.createGroup(id: groupId, with: [ethree.identity: card]).startSync().get()
            XCTFail()
        } catch EThreeError.invalidParticipantsCount {} catch {
            XCTFail()
        }

        var lookup: [String: Card] = [:]
        for _ in 0..<140 {
            let identity = UUID().uuidString
            lookup[identity] = card
        }

        do {
            _ = try ethree.createGroup(id: groupId, with: lookup).startSync().get()
            XCTFail()
        } catch EThreeError.invalidParticipantsCount {} catch {
            XCTFail()
        }

        let newLookup = Dictionary(dictionaryLiteral: lookup.first!)

        let group = try! ethree.createGroup(id: groupId, with: newLookup).startSync().get()

        XCTAssert(group.participants.count == 2)
        XCTAssert(group.participants.contains(ethree.identity))
        XCTAssert(group.participants.contains(newLookup.keys.first!))
    }

    func test_STE_27__createGroup__should_add_self() {
        let ethree1 = self.setUpDevice()
        let ethree2 = self.setUpDevice()

        let groupId = try! self.crypto.generateRandomData(ofSize: 100)

        let lookup = try! ethree1.lookupCards(of: [ethree1.identity, ethree2.identity]).startSync().get()

        let group1 = try! ethree1.createGroup(id: groupId, with: lookup).startSync().get()
        let group2 = try! ethree1.createGroup(id: groupId, with: [ethree1.identity: lookup[ethree1.identity]!]).startSync().get()

        XCTAssert(group2.participants.contains(ethree1.identity))
        XCTAssert(group1.participants == group2.participants)
    }

    func test_STE_28__groupId__should_not_be_short() {
        let ethree1 = self.setUpDevice()
        let ethree2 = self.setUpDevice()

        let groupId = try! self.crypto.generateRandomData(ofSize: 5)

        let lookup = try! ethree1.lookupCards(of: [ethree2.identity]).startSync().get()

        do {
            _ = try ethree1.createGroup(id: groupId, with: lookup).startSync().get()
            XCTFail()
        } catch EThreeError.shortGroupId {} catch {
            XCTFail()
        }
    }

    func test_STE_29__get_group() {
        let ethree1 = self.setUpDevice()
        let ethree2 = self.setUpDevice()

        let groupId = try! self.crypto.generateRandomData(ofSize: 100)

        XCTAssert(try! ethree1.getGroup(id: groupId) == nil)

        let lookup = try! ethree1.lookupCards(of: [ethree2.identity]).startSync().get()

        let group = try! ethree1.createGroup(id: groupId, with: lookup).startSync().get()

        let cachedGroup = try! ethree1.getGroup(id: groupId)!

        XCTAssert(cachedGroup.participants == group.participants)
        XCTAssert(cachedGroup.initiator == group.initiator)
    }

    func test_STE_30__load_group() {
        let ethree1 = self.setUpDevice()
        let ethree2 = self.setUpDevice()

        let groupId = try! self.crypto.generateRandomData(ofSize: 100)

        let lookup = try! ethree1.lookupCards(of: [ethree2.identity]).startSync().get()

        let group1 = try! ethree1.createGroup(id: groupId, with: lookup).startSync().get()

        let card = try! ethree2.lookupCard(of: ethree1.identity).startSync().get()

        let group2 = try! ethree2.loadGroup(id: groupId, initiator: card).startSync().get()

        XCTAssert(group1.participants == group2.participants)
        XCTAssert(group1.initiator == group2.initiator)
    }

    func test_STE_31__load_alien_or_unexistent_group__should_throw_error() {
        let ethree1 = self.setUpDevice()
        let ethree2 = self.setUpDevice()
        let ethree3 = self.setUpDevice()

        let groupId = try! self.crypto.generateRandomData(ofSize: 100)

        let card1 = try! ethree2.lookupCard(of: ethree1.identity).startSync().get()

        do {
            _ = try ethree2.loadGroup(id: groupId, initiator: card1).startSync().get()
            XCTFail()
        } catch EThreeError.groupWasNotFound {} catch {
            XCTFail()
        }

        let lookup = try! ethree1.lookupCards(of: [ethree3.identity]).startSync().get()

        _ = try! ethree1.createGroup(id: groupId, with: lookup).startSync().get()

        do {
            _ = try ethree2.loadGroup(id: groupId, initiator: card1).startSync().get()
            XCTFail()
        } catch EThreeError.groupWasNotFound {} catch {
            XCTFail()
        }
    }

    func test_STE_32__actions_on_deleted_group__should_throw_error() {
        let ethree1 = self.setUpDevice()
        let ethree2 = self.setUpDevice()

        let groupId = try! self.crypto.generateRandomData(ofSize: 100)

        let lookup = try! ethree1.lookupCards(of: [ethree2.identity]).startSync().get()

        _ = try! ethree1.createGroup(id: groupId, with: lookup).startSync().get()

        let card1 = try! ethree2.lookupCard(of: ethree1.identity).startSync().get()

        let group2 = try! ethree2.loadGroup(id: groupId, initiator: card1).startSync().get()

        try! ethree1.deleteGroup(id: groupId).startSync().get()

        XCTAssert(try! ethree1.getGroup(id: groupId) == nil)

        do {
            _ = try ethree1.loadGroup(id: groupId, initiator: card1).startSync().get()
            XCTFail()
        } catch EThreeError.groupWasNotFound {} catch {
            XCTFail()
        }

        do {
            try group2.update().startSync().get()
            XCTFail()
        } catch EThreeError.groupWasNotFound {} catch {
            XCTFail()
        }

        do {
            _ = try ethree2.loadGroup(id: groupId, initiator: card1).startSync().get()
            XCTFail()
        } catch EThreeError.groupWasNotFound {} catch {
            XCTFail()
        }

        XCTAssert(try! ethree2.getGroup(id: groupId) == nil)
    }

    func test_STE_33__add_more_than_max__should_throw_error() {
        let ethree = self.setUpDevice()

        var participants: Set<String> = Set()

        for _ in 0..<140 {
            let identity = UUID().uuidString
            participants.insert(identity)
        }

        let sessionId = try! self.crypto.generateRandomData(ofSize: 32)

        let ticket = try! Ticket(crypto: self.crypto, sessionId: sessionId, participants: participants)
        let rawGroup = try! RawGroup(info: GroupInfo(initiator: participants.first!), tickets: [ticket])

        let group = try! Group(rawGroup: rawGroup,
                               crypto: self.crypto,
                               localKeyStorage: ethree.localKeyStorage,
                               groupManager: try! ethree.getGroupManager(),
                               lookupManager: ethree.lookupManager)

        let card = self.utils.publishCard()

        do {
            try group.add(participant: card).startSync().get()
            XCTFail()
        } catch EThreeError.invalidParticipantsCount {} catch {
            XCTFail()
        }
    }

    func test_STE_34__remove_last_participant__should_throw_error() {
        let ethree1 = self.setUpDevice()
        let ethree2 = self.setUpDevice()

        let groupId = try! self.crypto.generateRandomData(ofSize: 100)

        let lookup = try! ethree1.lookupCards(of: [ethree2.identity]).startSync().get()

        let group1 = try! ethree1.createGroup(id: groupId, with: lookup).startSync().get()

        do {
            try group1.remove(participant: lookup[ethree2.identity]!).startSync().get()
            XCTFail()
        } catch EThreeError.invalidParticipantsCount {} catch {
            XCTFail()
        }
    }

    func test_STE_35__remove() {
        let ethree1 = self.setUpDevice()
        let ethree2 = self.setUpDevice()
        let ethree3 = self.setUpDevice()

        let groupId = try! self.crypto.generateRandomData(ofSize: 100)

        let lookup = try! ethree1.lookupCards(of: [ethree2.identity, ethree3.identity]).startSync().get()

        let group1 = try! ethree1.createGroup(id: groupId, with: lookup).startSync().get()

        let card1 = try! ethree2.lookupCard(of: ethree1.identity).startSync().get()
        let group2 = try! ethree2.loadGroup(id: groupId, initiator: card1).startSync().get()
        let group3 = try! ethree3.loadGroup(id: groupId, initiator: card1).startSync().get()

        try! group1.remove(participant: lookup[ethree2.identity]!).startSync().get()

        XCTAssert(!group1.participants.contains(ethree2.identity))

        try! group3.update().startSync().get()

        XCTAssert(!group3.participants.contains(ethree2.identity))

        do {
            try group2.update().startSync().get()
            XCTFail()
        } catch EThreeError.groupWasNotFound {} catch {
            XCTFail()
        }

        do {
            _ = try ethree2.loadGroup(id: groupId, initiator: card1).startSync().get()
            XCTFail()
        } catch EThreeError.groupWasNotFound {} catch {
            XCTFail()
        }

        XCTAssert(try! ethree2.getGroup(id: groupId) == nil)
    }

    func test_36__change_group_by_noninitiator__should_throw_error() {
        let ethree1 = self.setUpDevice()
        let ethree2 = self.setUpDevice()
        let ethree3 = self.setUpDevice()
        let ethree4 = self.setUpDevice()

        let identities = [ethree2.identity, ethree3.identity]

        let groupId = try! self.crypto.generateRandomData(ofSize: 100)

        let lookup = try! ethree1.lookupCards(of: identities).startSync().get()
        _ = try! ethree1.createGroup(id: groupId, with: lookup).startSync().get()

        let ethree1Card = try! ethree2.lookupCard(of: ethree1.identity).startSync().get()
        let group2 = try! ethree2.loadGroup(id: groupId, initiator: ethree1Card).startSync().get()

        do {
            try ethree2.deleteGroup(id: groupId).startSync().get()
            XCTFail()
        } catch EThreeError.groupPermissionDenied {} catch {
            XCTFail()
        }

        do {
            try group2.remove(participant: lookup[ethree3.identity]!).startSync().get()
            XCTFail()
        } catch EThreeError.groupPermissionDenied {} catch {
            XCTFail()
        }

        do {
            let ethree4Card = try! ethree2.lookupCard(of: ethree4.identity).startSync().get()
            try group2.add(participant: ethree4Card).startSync().get()
            XCTFail()
        } catch EThreeError.groupPermissionDenied {} catch {
            XCTFail()
        }
    }


    // FIXME

    func test_1__encrypt_decrypt__should_succeed() {
        let ethree1 = self.setUpDevice()
        let ethree2 = self.setUpDevice()

        let identities = [ethree2.identity]

        let groupId = try! self.crypto.generateRandomData(ofSize: 100)

        // User1 creates group, encrypts
        let lookup = try! ethree1.lookupCards(of: identities).startSync().get()
        let group1 = try! ethree1.createGroup(id: groupId, with: lookup).startSync().get()

        let participants = Set(identities).union([ethree1.identity])
        XCTAssert(group1.participants == participants)

        let message = "Hello, \(ethree2.identity))!"
        let encrypted = try! group1.encrypt(text: message)

        // User2 updates group, decrypts
        let ethree1Card = try! ethree2.lookupCard(of: ethree1.identity).startSync().get()
        let group2 = try! ethree2.loadGroup(id: groupId, initiator: ethree1Card).startSync().get()
        XCTAssert(group2.participants == participants)

        let card = try! ethree2.lookupCard(of: ethree1.identity).startSync().get()

        let decrypted = try! group2.decrypt(text: encrypted, from: card)

        XCTAssert(message == decrypted)
    }

    func test_2__add_remove_participants__should_succeed() {
        let ethree1 = self.setUpDevice()
        let ethree2 = self.setUpDevice()
        let ethree3 = self.setUpDevice()
        let ethree4 = self.setUpDevice()

        // User 1 creates group
        let identities = [ethree2.identity, ethree3.identity]
        let groupId = try! self.crypto.generateRandomData(ofSize: 100)

        let lookup = try! ethree1.lookupCards(of: identities).startSync().get()

        let group1 = try! ethree1.createGroup(id: groupId, with: lookup).startSync().get()

        // User 2 and User 3 update it
        let ethree1Card = try! ethree2.lookupCard(of: ethree1.identity).startSync().get()

        let group2 = try! ethree2.loadGroup(id: groupId, initiator: ethree1Card).startSync().get()

        let group3 = try! ethree3.loadGroup(id: groupId, initiator: ethree1Card).startSync().get()

        // User 1 removes User3 and adds User 4
        let ethree4Card = try! ethree1.lookupCard(of: ethree4.identity).startSync().get()

        try! group1.add(participant: ethree4Card).startSync().get()
        try! group1.remove(participant: lookup[ethree3.identity]!).startSync().get()

        let newIdentities = [ethree2.identity, ethree4.identity]
        let participants = Set(newIdentities).union([ethree1.identity])
        XCTAssert(group1.participants == participants)

        // Other Users update groups
        try! group2.update().startSync().get()

        do {
            try group3.update().startSync().get()
            XCTFail()
        } catch {
            // FIXME
        }

        XCTAssert(group2.participants == participants)

        let group4 = try! ethree4.loadGroup(id: groupId, initiator: ethree1Card).startSync().get()
        XCTAssert(group4.participants == participants)

        // User 1 encrypts message for group
        let message = "Hello, \(ethree2.identity)!"

        let encrypted = try! group1.encrypt(text: message)

        // Other Users try! to decrypt
        let decrypted2 = try! group2.decrypt(text: encrypted, from: ethree1Card)

        let notDecrypted3 = try? group3.decrypt(text: encrypted, from: ethree1Card)

        let decrypted4 = try! group4.decrypt(text: encrypted, from: ethree1Card)

        XCTAssert(decrypted2 == message)
        XCTAssert(notDecrypted3 == nil)
        XCTAssert(decrypted4 == message)
    }

    func test__10__decrypt_with_old_card__should_throw_error() {
        let ethree1 = self.setUpDevice()
        let ethree2 = self.setUpDevice()
        let ethree3 = self.setUpDevice()

        let groupId = try! self.crypto.generateRandomData(ofSize: 100)

        let lookup = try! ethree1.lookupCards(of: [ethree2.identity, ethree3.identity]).startSync().get()
        _ = try! ethree1.createGroup(id: groupId, with: lookup).startSync().get()

        let card1 = try! ethree2.lookupCard(of: ethree1.identity).startSync().get()
        let group2 = try! ethree2.loadGroup(id: groupId, initiator: card1).startSync().get()
        let group3 = try! ethree3.loadGroup(id: groupId, initiator: card1).startSync().get()

        let encrypted = try! group3.encrypt(text: "Some text")

        do {
            _ = try group2.decrypt(text: encrypted, from: card1)
        } catch FoundationError.errorInvalidSignature {} catch {
            XCTFail()
        }
    }

    func test__10_1__decrypt_with_old_card__should_throw_error() {
        let ethree1 = self.setUpDevice()
        let ethree2 = self.setUpDevice()

        let groupId = try! self.crypto.generateRandomData(ofSize: 100)

        let lookup = try! ethree1.lookupCards(of: [ethree2.identity]).startSync().get()
        let group1 = try! ethree1.createGroup(id: groupId, with: lookup).startSync().get()

        let card1 = try! ethree2.lookupCard(of: ethree1.identity).startSync().get()

        let group2 = try! ethree2.loadGroup(id: groupId, initiator: card1).startSync().get()

        let card2 = try! ethree1.lookupCard(of: ethree2.identity).startSync().get()

        try! ethree2.cleanUp()
        try! ethree2.rotatePrivateKey().startSync().get()

        let encrypted = try! group2.encrypt(text: "Some text")

        do {
            _ = try group1.decrypt(text: encrypted, from: card2)
            XCTFail()
        } catch FoundationError.errorInvalidSignature {} catch {
            XCTFail()
        }
    }

    func test__11__decrypt_with_old_card__should_throw_error() {
        let ethree1 = self.setUpDevice()
        let ethree2 = self.setUpDevice()

        let card1 = try! ethree2.lookupCard(of: ethree1.identity).startSync().get()

        let encrypted = try! ethree2.encrypt(text: "Some text", for: card1)

        try! ethree2.cleanUp()
        try! ethree2.rotatePrivateKey().startSync().get()

        let card2 = try! ethree1.lookupCard(of: ethree2.identity).startSync().get()

        do {
            _ = try ethree1.decrypt(text: encrypted, from: card2)

            XCTFail()
        } catch VirgilCryptoError.signatureNotVerified {} catch {
            XCTFail()
        }
    }
}

