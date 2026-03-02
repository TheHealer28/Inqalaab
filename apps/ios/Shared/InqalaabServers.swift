//
//  InqalaabServers.swift
//  Inqalaab (iOS)
//
//  Server hardcoding and configuration for Inqalaab.
//

import Foundation
import SimpleXChat

class InqalaabServers {
    static let shared = InqalaabServers()

    private let INQALAAB_SMP = "smp://4CfWwei1oOFAhmfUkmpsrSRELYLCvKBPgQIJlOT5z8I=@smp.suchkitalash.info"
    private let INQALAAB_XFTP = "xftp://fX3KznAU-_QoLQzaMs9w0gKFySj0nleLTb0T2ysEPJI=@xftp.suchkitalash.info"
    private let INQALAAB_HOST = "suchkitalash.info"

    private let KEY_SERVERS_CONFIGURED = "inqalaab_servers_configured"
    private let KEY_CONTACTS_CLEANED = "inqalaab_contacts_cleaned"
    private let KEY_ADDRESS_CREATED = "inqalaab_address_created"

    private let PRESET_CONTACTS_TO_DELETE: Set<String> = ["SimpleX Status", "Ask SimpleX Team"]

    /// Guard against concurrent execution
    private var isConfiguring = false

    func configureIfNeeded() {
        let serversConfigured = UserDefaults.standard.bool(forKey: KEY_SERVERS_CONFIGURED)
        let contactsCleaned = UserDefaults.standard.bool(forKey: KEY_CONTACTS_CLEANED)
        let addressCreated = UserDefaults.standard.bool(forKey: KEY_ADDRESS_CREATED)

        if serversConfigured && contactsCleaned && addressCreated {
            print("Inqalaab: Already fully configured, skipping")
            return
        }

        guard !isConfiguring else {
            print("Inqalaab: Configuration already in progress, skipping duplicate call")
            return
        }
        isConfiguring = true

        Task {
            defer { isConfiguring = false }
            do {
                guard ChatModel.shared.chatRunning == true else {
                    print("Inqalaab: Chat not running yet")
                    return
                }

                // Part 1: Replace servers
                if !serversConfigured {
                    await replaceServers()
                }

                // Part 2: Delete preset contacts
                if !contactsCleaned {
                    await deletePresetContacts()
                }

                // Part 3: Auto-create user address
                if !addressCreated {
                    await createUserAddress()
                }
            } catch {
                print("Inqalaab: Exception: \(error.localizedDescription)")
            }
        }
    }

    private func replaceServers() async {
        print("Inqalaab: Starting server replacement...")

        do {
            let currentServers = try await getUserServers()

            // Check if already done
            let alreadyDone = currentServers.flatMap { $0.smpServers }.contains { $0.enabled && $0.server.contains(INQALAAB_HOST) }
            if alreadyDone {
                print("Inqalaab: Servers already configured")
                UserDefaults.standard.set(true, forKey: KEY_SERVERS_CONFIGURED)
                return
            }

            print("Inqalaab: Found \(currentServers.count) server groups")

            var smpDone = false
            var xftpDone = false

            let modified: [UserOperatorServers] = currentServers.map { group in
                let newSmp = group.smpServers.map { srv -> UserServer in
                    if !smpDone && srv.serverId != nil {
                        smpDone = true
                        print("Inqalaab: Repurposing SMP id=\(srv.serverId ?? 0)")
                        var copy = srv
                        copy.server = INQALAAB_SMP
                        copy.preset = false
                        copy.tested = nil
                        copy.enabled = true
                        return copy
                    } else {
                        var copy = srv
                        copy.enabled = false
                        return copy
                    }
                }
                let newXftp = group.xftpServers.map { srv -> UserServer in
                    if !xftpDone && srv.serverId != nil {
                        xftpDone = true
                        print("Inqalaab: Repurposing XFTP id=\(srv.serverId ?? 0)")
                        var copy = srv
                        copy.server = INQALAAB_XFTP
                        copy.preset = false
                        copy.tested = nil
                        copy.enabled = true
                        return copy
                    } else {
                        var copy = srv
                        copy.enabled = false
                        return copy
                    }
                }
                return UserOperatorServers(operator: group.operator_, smpServers: newSmp, xftpServers: newXftp)
            }

            guard smpDone && xftpDone else {
                print("Inqalaab: ERROR - No donor servers (smp=\(smpDone) xftp=\(xftpDone))")
                return
            }

            print("Inqalaab: Calling setUserServers...")
            try await setUserServers(userServers: modified)
            print("Inqalaab: setUserServers success")

            // Disable all operators
            let conditions = ChatModel.shared.conditions
            let disabledOps = conditions.serverOperators.map { op -> ServerOperator in
                var copy = op
                copy.enabled = false
                return copy
            }
            print("Inqalaab: Disabling \(disabledOps.count) operators...")
            let result = try await setServerOperators(operators: disabledOps)
            await MainActor.run {
                ChatModel.shared.conditions = result
            }
            print("Inqalaab: Operators disabled")

            UserDefaults.standard.set(true, forKey: KEY_SERVERS_CONFIGURED)
            print("Inqalaab: Server replacement complete")
        } catch {
            print("Inqalaab: Server replacement error: \(error)")
        }
    }

    private func deletePresetContacts() async {
        print("Inqalaab: Cleaning preset contacts...")

        // Try up to 3 times with delay — preset contacts may not be loaded yet
        // when this runs shortly after chat initialization
        for attempt in 1...3 {
            let chats = await MainActor.run { ChatModel.shared.chats }
            var deleted = 0
            var found = 0

            for chat in chats {
                // Check both .direct contacts and any chat whose display name matches
                let displayName: String?
                switch chat.chatInfo {
                case let .direct(contact):
                    displayName = contact.displayName
                default:
                    displayName = nil
                }

                if let name = displayName, PRESET_CONTACTS_TO_DELETE.contains(name) {
                    found += 1
                    print("Inqalaab: Deleting contact: \(name) (attempt \(attempt))")
                    do {
                        try await apiDeleteChat(type: chat.chatInfo.chatType, id: chat.chatInfo.apiId)
                        await MainActor.run {
                            ChatModel.shared.removeChat(chat.chatInfo.id)
                        }
                        print("Inqalaab: Deleted \(name)")
                        deleted += 1
                    } catch {
                        print("Inqalaab: Failed to delete \(name): \(error)")
                    }
                }
            }

            print("Inqalaab: Attempt \(attempt): found \(found) preset contacts, deleted \(deleted)")

            if found > 0 && found == deleted {
                // Successfully found and deleted all preset contacts
                UserDefaults.standard.set(true, forKey: KEY_CONTACTS_CLEANED)
                print("Inqalaab: Contacts cleanup marked complete")
                return
            } else if found > 0 {
                // Found some but failed to delete — will retry next launch
                print("Inqalaab: Contacts cleanup incomplete, will retry next launch")
                return
            }

            // found == 0: contacts not loaded yet, wait and retry
            if attempt < 3 {
                print("Inqalaab: No preset contacts found yet, retrying in 3s...")
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }

        // After all retries, if still not found, the contacts likely don't exist
        // (e.g. they were never created, or this is a fresh DB without them)
        let totalChats = await MainActor.run { ChatModel.shared.chats.count }
        if totalChats > 0 {
            // Chats are loaded but preset contacts aren't among them — mark as done
            UserDefaults.standard.set(true, forKey: KEY_CONTACTS_CLEANED)
            print("Inqalaab: No preset contacts found after 3 attempts (\(totalChats) chats loaded), marking complete")
        } else {
            print("Inqalaab: Chats not loaded, will retry next launch")
        }
    }

    private func createUserAddress() async {
        if ChatModel.shared.userAddress != nil {
            print("Inqalaab: User address already exists in model")
            UserDefaults.standard.set(true, forKey: KEY_ADDRESS_CREATED)
            await enableAutoAccept()
            return
        }

        print("Inqalaab: Creating user address...")
        do {
            guard let connLink = try await apiCreateUserAddress() else {
                print("Inqalaab: apiCreateUserAddress returned nil")
                return
            }
            await MainActor.run {
                ChatModel.shared.userAddress = UserContactLink(connLink)
            }
            print("Inqalaab: User address created successfully")
            UserDefaults.standard.set(true, forKey: KEY_ADDRESS_CREATED)
            await enableAutoAccept()
        } catch {
            // Address already exists in DB but wasn't loaded into model — load it now
            print("Inqalaab: Create address failed (\(error)), trying to load existing...")
            do {
                if let existingAddress = try await apiGetUserAddressAsync() {
                    await MainActor.run {
                        ChatModel.shared.userAddress = existingAddress
                    }
                    print("Inqalaab: Loaded existing user address successfully")
                    UserDefaults.standard.set(true, forKey: KEY_ADDRESS_CREATED)
                    await enableAutoAccept()
                } else {
                    print("Inqalaab: No existing address found either")
                }
            } catch {
                print("Inqalaab: Failed to load existing address: \(error)")
            }
        }
    }

    /// Enable auto-accept so contacts who scan the QR code are connected immediately
    private func enableAutoAccept() async {
        print("Inqalaab: Enabling auto-accept for user address...")
        do {
            let settings = AddressSettings(
                businessAddress: false,
                autoAccept: AutoAccept(acceptIncognito: false),
                autoReply: nil
            )
            if let updatedLink = try await apiSetUserAddressSettings(settings) {
                await MainActor.run {
                    ChatModel.shared.userAddress = updatedLink
                }
                print("Inqalaab: Auto-accept enabled successfully")
            } else {
                print("Inqalaab: apiSetUserAddressSettings returned nil (address not found)")
            }
        } catch {
            print("Inqalaab: Failed to enable auto-accept: \(error)")
        }
    }
}
