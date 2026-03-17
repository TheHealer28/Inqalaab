//
//  InqalaabServers.swift
//  Inqalaab (iOS)
//
//  Server hardcoding and configuration for Inqalaab.
//  Firebase Remote Config integration: fetches server addresses from Firebase,
//  falls back to hardcoded addresses if fetch fails.
//

import Foundation
import InqalaabChat
import FirebaseRemoteConfig

class InqalaabServers {
    static let shared = InqalaabServers()

    // Hardcoded fallback server addresses (used when Firebase fetch fails)
    private let FALLBACK_SMP_SERVERS = [
        "smp://4CfWwei1oOFAhmfUkmpsrSRELYLCvKBPgQIJlOT5z8I=@smp.suchkitalash.info",
        "smp://jKkKmm64Gf6jWa2unI5t0QudCoTZxxFp8o28fDZWZU4=@smp1.inqalaab.chat",
        "smp://JfdjUvMRakyzH7yzucTLoxKsY-EfvA0bMTj7kZG3Szs=@smp2.inqalaab.chat",
        "smp://3XECaNOaqlLc_hPyrWSmw4rxrUGxALf5qQVqjaz-D-Y=@smp3.inqalaab.chat",
    ]
    private let FALLBACK_XFTP_SERVERS = [
        "xftp://RzgzPjyel91YLliscUGXCjReG1kYV_5_o0pvOfZA_4s=@xftp.suchkitalash.info:5233",
        "xftp://oOvy6k99LT5dySeIOmw5-G4FDZ5o3SSpVwm6YmyBsZI=@xftp1.inqalaab.chat",
        "xftp://Aik60WjmVFLWOK2dKYEjEbfdUWxuyUpAp-VO3FcOE5w=@xftp2.inqalaab.chat:5233",
        "xftp://rQDMhOx8wUv7O6J3vht2W3HMsUXbqv0HZPQb3Ce02ss=@xftp3.inqalaab.chat:5233",
    ]

    private let KEY_SERVERS_CONFIGURED = "inqalaab_servers_configured_v2"
    private let KEY_CONTACTS_CLEANED = "inqalaab_contacts_cleaned"
    private let KEY_ADDRESS_CREATED = "inqalaab_address_created"

    // Names match the binary-patched Haskell library output (space-padded to same length as originals)
    private let PRESET_CONTACTS_TO_DELETE: Set<String> = ["Inqalb Status ", "Ask Inqalb Team "]

    /// Guard against concurrent execution
    private var isConfiguring = false

    func configureIfNeeded() {
        let serversConfigured = UserDefaults.standard.bool(forKey: KEY_SERVERS_CONFIGURED)
        let contactsCleaned = UserDefaults.standard.bool(forKey: KEY_CONTACTS_CLEANED)
        let addressCreated = UserDefaults.standard.bool(forKey: KEY_ADDRESS_CREATED)

        if serversConfigured && contactsCleaned && addressCreated { return }
        guard !isConfiguring else { return }
        isConfiguring = true

        Task {
            defer { isConfiguring = false }
            do {
                guard ChatModel.shared.chatRunning == true else { return }

                if !serversConfigured {
                    await replaceServers()
                }
                if !contactsCleaned {
                    await deletePresetContacts()
                }
                if !addressCreated {
                    await createUserAddress()
                }
            } catch {
                logger.error("Inqalaab configureIfNeeded error: \(error.localizedDescription)")
            }
        }
    }

    /// Fetch server addresses from Firebase Remote Config.
    /// Returns (smpServers, xftpServers) from Firebase, or falls back to hardcoded.
    private func fetchServerAddresses() async -> (smp: [String], xftp: [String]) {
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        // First fetch: no minimum interval. Subsequent: 1 hour cache.
        settings.minimumFetchInterval = 3600
        remoteConfig.configSettings = settings

        do {
            let status = try await remoteConfig.fetch()
            if status == .success {
                try await remoteConfig.activate()

                let smpValue = remoteConfig.configValue(forKey: "smp_servers").stringValue ?? ""
                let xftpValue = remoteConfig.configValue(forKey: "xftp_servers").stringValue ?? ""

                let smpServers = smpValue.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                let xftpServers = xftpValue.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

                if !smpServers.isEmpty && !xftpServers.isEmpty {
                    logger.debug("Inqalaab: Firebase Remote Config fetched \(smpServers.count) SMP, \(xftpServers.count) XFTP servers")
                    return (smpServers, xftpServers)
                }
            }
        } catch {
            logger.debug("Inqalaab: Firebase fetch failed, using fallback servers: \(error.localizedDescription)")
        }

        return (FALLBACK_SMP_SERVERS, FALLBACK_XFTP_SERVERS)
    }

    private func replaceServers() async {
        do {
            let currentServers = try await getUserServers()

            // Fetch server addresses (Firebase or fallback)
            let addresses = await fetchServerAddresses()

            // Check if ALL servers are already active
            let enabledSmpAddrs = Set(currentServers.flatMap { $0.smpServers }.filter { $0.enabled }.map { $0.server })
            let allSmpPresent = addresses.smp.allSatisfy { enabledSmpAddrs.contains($0) }
            let enabledXftpAddrs = Set(currentServers.flatMap { $0.xftpServers }.filter { $0.enabled }.map { $0.server })
            let allXftpPresent = addresses.xftp.allSatisfy { enabledXftpAddrs.contains($0) }
            if allSmpPresent && allXftpPresent {
                UserDefaults.standard.set(true, forKey: KEY_SERVERS_CONFIGURED)
                return
            }

            // Build Inqalaab server entries
            let inqSmp: [UserServer] = addresses.smp.map {
                UserServer(serverId: nil, server: $0, preset: false, tested: nil, enabled: true, deleted: false)
            }
            let inqXftp: [UserServer] = addresses.xftp.map {
                UserServer(serverId: nil, server: $0, preset: false, tested: nil, enabled: true, deleted: false)
            }

            // Disable every existing server in every operator group,
            // then append Inqalaab servers to the first group.
            var addedInqalaab = false
            let modified: [UserOperatorServers] = currentServers.map { group in
                let disabledSmp = group.smpServers.map { srv -> UserServer in
                    var copy = srv; copy.enabled = false; return copy
                }
                let disabledXftp = group.xftpServers.map { srv -> UserServer in
                    var copy = srv; copy.enabled = false; return copy
                }
                if !addedInqalaab {
                    addedInqalaab = true
                    return UserOperatorServers(
                        operator: group.operator_,
                        smpServers: disabledSmp + inqSmp,
                        xftpServers: disabledXftp + inqXftp
                    )
                }
                return UserOperatorServers(operator: group.operator_, smpServers: disabledSmp, xftpServers: disabledXftp)
            }

            try await setUserServers(userServers: modified)

            // Disable all operators (SimpleX, Flux, etc.)
            let conditions = ChatModel.shared.conditions
            let disabledOps = conditions.serverOperators.map { op -> ServerOperator in
                var copy = op
                copy.enabled = false
                return copy
            }
            let result = try await setServerOperators(operators: disabledOps)
            await MainActor.run {
                ChatModel.shared.conditions = result
            }

            UserDefaults.standard.set(true, forKey: KEY_SERVERS_CONFIGURED)
        } catch {
            logger.error("Inqalaab replaceServers error: \(error)")
        }
    }

    private func deletePresetContacts() async {
        for attempt in 1...3 {
            let chats = await MainActor.run { ChatModel.shared.chats }
            var deleted = 0
            var found = 0

            for chat in chats {
                let displayName: String?
                switch chat.chatInfo {
                case let .direct(contact):
                    displayName = contact.displayName
                default:
                    displayName = nil
                }

                if let name = displayName, PRESET_CONTACTS_TO_DELETE.contains(name) {
                    found += 1
                    do {
                        try await apiDeleteChat(type: chat.chatInfo.chatType, id: chat.chatInfo.apiId)
                        await MainActor.run {
                            ChatModel.shared.removeChat(chat.chatInfo.id)
                        }
                        deleted += 1
                    } catch {
                        logger.error("Inqalaab: Failed to delete \(name): \(error)")
                    }
                }
            }

            if found > 0 && found == deleted {
                UserDefaults.standard.set(true, forKey: KEY_CONTACTS_CLEANED)
                return
            } else if found > 0 {
                return
            }

            if attempt < 3 {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }

        let totalChats = await MainActor.run { ChatModel.shared.chats.count }
        if totalChats > 0 {
            UserDefaults.standard.set(true, forKey: KEY_CONTACTS_CLEANED)
        }
    }

    private func createUserAddress() async {
        if ChatModel.shared.userAddress != nil {
            UserDefaults.standard.set(true, forKey: KEY_ADDRESS_CREATED)
            await enableAutoAccept()
            return
        }

        do {
            guard let connLink = try await apiCreateUserAddress() else { return }
            await MainActor.run {
                ChatModel.shared.userAddress = UserContactLink(connLink)
            }
            UserDefaults.standard.set(true, forKey: KEY_ADDRESS_CREATED)
            await enableAutoAccept()
        } catch {
            do {
                if let existingAddress = try await apiGetUserAddressAsync() {
                    await MainActor.run {
                        ChatModel.shared.userAddress = existingAddress
                    }
                    UserDefaults.standard.set(true, forKey: KEY_ADDRESS_CREATED)
                    await enableAutoAccept()
                }
            } catch {
                logger.error("Inqalaab createUserAddress error: \(error)")
            }
        }
    }

    private func enableAutoAccept() async {
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
            }
        } catch {
            logger.error("Inqalaab enableAutoAccept error: \(error)")
        }
    }
}
