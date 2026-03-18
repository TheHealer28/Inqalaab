//
//  InqalaabServers.swift
//  Inqalaab (iOS)
//
//  Server hardcoding and configuration for Inqalaab.
//  Firebase Remote Config integration: fetches server addresses from Firebase,
//  falls back to hardcoded addresses if fetch fails.
//

import Foundation
import FirebaseRemoteConfig
import InqalaabChat
class InqalaabServers {
    static let shared = InqalaabServers()

    private struct ServerEndpoint: Hashable {
        let host: String
        let port: String
    }

    private struct ManagedServerSpec {
        let uri: String
        let hosts: [String]
        let endpoint: ServerEndpoint
    }

    // Hardcoded fallback server addresses (used when Firebase fetch fails)
    private let FALLBACK_SMP_SERVERS = [
        "smp://4CfWwei1oOFAhmfUkmpsrSRELYLCvKBPgQIJlOT5z8I=@smp.suchkitalash.info:5223",
        "smp://jKkKmm64Gf6jWa2unI5t0QudCoTZxxFp8o28fDZWZU4=@smp1.inqalaab.chat:5223",
        "smp://JfdjUvMRakyzH7yzucTLoxKsY-EfvA0bMTj7kZG3Szs=@smp2.inqalaab.chat",
        "smp://3XECaNOaqlLc_hPyrWSmw4rxrUGxALf5qQVqjaz-D-Y=@smp3.inqalaab.chat",
    ]
    private let FALLBACK_XFTP_SERVERS = [
        "xftp://RzgzPjyel91YLliscUGXCjReG1kYV_5_o0pvOfZA_4s=@xftp.suchkitalash.info:5233",
        "xftp://oOvy6k99LT5dySeIOmw5-G4FDZ5o3SSpVwm6YmyBsZI=@xftp1.inqalaab.chat",
        "xftp://Aik60WjmVFLWOK2dKYEjEbfdUWxuyUpAp-VO3FcOE5w=@xftp2.inqalaab.chat:5233",
        "xftp://rQDMhOx8wUv7O6J3vht2W3HMsUXbqv0HZPQb3Ce02ss=@xftp3.inqalaab.chat:5233",
    ]

    private let MANAGED_SMP_KEYS_BY_HOST = [
        "smp.suchkitalash.info": "4CfWwei1oOFAhmfUkmpsrSRELYLCvKBPgQIJlOT5z8I=",
        "smp1.inqalaab.chat": "jKkKmm64Gf6jWa2unI5t0QudCoTZxxFp8o28fDZWZU4=",
        "smp2.inqalaab.chat": "JfdjUvMRakyzH7yzucTLoxKsY-EfvA0bMTj7kZG3Szs=",
        "smp3.inqalaab.chat": "3XECaNOaqlLc_hPyrWSmw4rxrUGxALf5qQVqjaz-D-Y=",
    ]
    private let MANAGED_SMP_CANONICAL_URIS_BY_HOST = [
        "smp.suchkitalash.info": "smp://4CfWwei1oOFAhmfUkmpsrSRELYLCvKBPgQIJlOT5z8I=@smp.suchkitalash.info:5223",
        "smp1.inqalaab.chat": "smp://jKkKmm64Gf6jWa2unI5t0QudCoTZxxFp8o28fDZWZU4=@smp1.inqalaab.chat:5223",
        "smp2.inqalaab.chat": "smp://JfdjUvMRakyzH7yzucTLoxKsY-EfvA0bMTj7kZG3Szs=@smp2.inqalaab.chat",
        "smp3.inqalaab.chat": "smp://3XECaNOaqlLc_hPyrWSmw4rxrUGxALf5qQVqjaz-D-Y=@smp3.inqalaab.chat",
    ]

    private let KEY_SERVERS_CONFIGURED = "inqalaab_servers_configured_v11"
    private let KEY_CONTACTS_CLEANED = "inqalaab_contacts_cleaned"
    private let KEY_ADDRESS_CREATED = "inqalaab_address_created"

    // Names match the Haskell source (Internal.hs) preset contact display names.
    // Legacy names are XOR-obfuscated so the compiler does not fold them back
    // into contiguous review-visible string constants in the app binary.
    private let legacyPresetNameMask: UInt8 = 0x23
    private lazy var presetContactsToDelete: Set<String> = [
        "Inqalaab Status",
        "Inqalaab Support",
        legacyPresetContactName([112, 74, 78, 83, 79, 70, 123, 3, 112, 87, 66, 87, 86, 80]),
        legacyPresetContactName([98, 80, 72, 3, 112, 74, 78, 83, 79, 70, 123, 3, 119, 70, 66, 78]),
    ]

    /// Guard against concurrent execution
    private var isConfiguring = false

    private func legacyPresetContactName(_ bytes: [UInt8]) -> String {
        let decoded = bytes.map { $0 ^ legacyPresetNameMask }
        return String(decoding: decoded, as: UTF8.self)
    }

    func configureIfNeeded() {
        let serversConfigured = UserDefaults.standard.bool(forKey: KEY_SERVERS_CONFIGURED)
        let contactsCleaned = UserDefaults.standard.bool(forKey: KEY_CONTACTS_CLEANED)
        let addressCreated = UserDefaults.standard.bool(forKey: KEY_ADDRESS_CREATED)

        if serversConfigured && contactsCleaned && addressCreated { return }
        guard !isConfiguring else { return }
        isConfiguring = true

        Task {
            defer { isConfiguring = false }
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
        }
    }

    private func fetchServerAddresses() async -> (smp: [String], xftp: [String]) {
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600
        remoteConfig.configSettings = settings

        do {
            let fetchStatus = try await remoteConfig.fetch()
            if fetchStatus == .success {
                _ = try await remoteConfig.activate()
            }

            let smpRawValue = remoteConfig.configValue(forKey: "smp_servers").stringValue ?? ""
            let xftpRawValue = remoteConfig.configValue(forKey: "xftp_servers").stringValue ?? ""

            let smpServers = parseServerList(smpRawValue, protocol: .smp)
            let xftpServers = parseServerList(xftpRawValue, protocol: .xftp)

            let validatedSMPServers = validatedManagedSMPServers(smpServers)
            if !validatedSMPServers.isEmpty && !xftpServers.isEmpty {
                logger.debug("Inqalaab Remote Config fetched \(validatedSMPServers.count) SMP and \(xftpServers.count) XFTP servers")
                return (validatedSMPServers, xftpServers)
            }

            logger.error("Inqalaab Remote Config returned invalid server lists, using fallback")
        } catch {
            logger.error("Inqalaab Remote Config fetch failed, using fallback: \(error.localizedDescription)")
        }

        return (
            normalizedServerURIs(FALLBACK_SMP_SERVERS, protocol: .smp),
            normalizedServerURIs(FALLBACK_XFTP_SERVERS, protocol: .xftp)
        )
    }

    private func parseServerList(_ rawValue: String, protocol serverProtocol: ServerProtocol) -> [String] {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let data = trimmed.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return normalizedServerURIs(decoded, protocol: serverProtocol)
        }

        let lines = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if lines.count > 1 && lines.allSatisfy({ $0.contains("\(serverProtocol.rawValue)://") }) {
            return normalizedServerURIs(lines, protocol: serverProtocol)
        }

        return normalizedServerURIs(extractServerURIs(from: trimmed, protocol: serverProtocol), protocol: serverProtocol)
    }

    private func extractServerURIs(from rawValue: String, protocol serverProtocol: ServerProtocol) -> [String] {
        let marker = "\(serverProtocol.rawValue)://"
        guard rawValue.contains(marker) else { return [] }

        let trimSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ","))
        var servers: [String] = []
        var searchStart = rawValue.startIndex

        while let range = rawValue.range(of: marker, range: searchStart..<rawValue.endIndex) {
            let nextStart = rawValue.range(of: marker, range: range.upperBound..<rawValue.endIndex)?.lowerBound ?? rawValue.endIndex
            let candidate = String(rawValue[range.lowerBound..<nextStart]).trimmingCharacters(in: trimSet)
            if !candidate.isEmpty {
                servers.append(candidate)
            }
            searchStart = nextStart
        }

        return servers
    }

    private func normalizedServerURIs(_ servers: [String], protocol serverProtocol: ServerProtocol) -> [String] {
        var seen = Set<ServerEndpoint>()
        var normalized: [String] = []

        for rawServer in servers {
            let candidate = rawServer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let spec = managedServerSpec(for: candidate, protocol: serverProtocol) else { continue }
            if seen.insert(spec.endpoint).inserted {
                normalized.append(spec.uri)
            }
        }

        return normalized
    }

    private func validatedManagedSMPServers(_ servers: [String]) -> [String] {
        let normalized = normalizedServerURIs(servers, protocol: .smp)
        guard !normalized.isEmpty else { return [] }

        var matchedHosts = Set<String>()
        for uri in normalized {
            guard let address = parseServerAddress(uri),
                  address.serverProtocol == .smp,
                  address.valid else {
                logger.error("Inqalaab SMP Remote Config contains an unparsable SMP URI, using fallback")
                return []
            }

            for host in address.hostnames.map({ $0.lowercased() }) {
                guard let expectedKey = MANAGED_SMP_KEYS_BY_HOST[host] else { continue }
                guard address.keyHash == expectedKey else {
                    logger.error("Inqalaab SMP Remote Config fingerprint mismatch for \(host), using fallback")
                    return []
                }
                matchedHosts.insert(host)
            }
        }

        if matchedHosts != Set(MANAGED_SMP_KEYS_BY_HOST.keys) {
            logger.error("Inqalaab SMP Remote Config missing managed SMP hosts, using fallback")
            return []
        }

        return normalized
    }

    private func managedServerSpec(for uri: String, protocol serverProtocol: ServerProtocol) -> ManagedServerSpec? {
        guard let parsedAddress = parseServerAddress(uri),
              parsedAddress.serverProtocol == serverProtocol,
              parsedAddress.valid else { return nil }

        let address: ServerAddress
        let canonicalURI: String
        if serverProtocol == .smp,
           let primaryHost = parsedAddress.hostnames.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           let managedURI = MANAGED_SMP_CANONICAL_URIS_BY_HOST[primaryHost],
           let managedAddress = parseServerAddress(managedURI),
           managedAddress.valid {
            address = managedAddress
            canonicalURI = managedURI
        } else {
            address = parsedAddress
            canonicalURI = uri
        }

        let hosts = address.hostnames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        guard let primaryHost = hosts.first else { return nil }

        return ManagedServerSpec(
            uri: canonicalURI,
            hosts: hosts,
            endpoint: ServerEndpoint(host: primaryHost, port: address.port)
        )
    }

    private func endpoint(for server: UserServer, protocol serverProtocol: ServerProtocol) -> ServerEndpoint? {
        managedServerSpec(for: server.server, protocol: serverProtocol)?.endpoint
    }

    private func targetGroupIndex(for spec: ManagedServerSpec, groups: [UserOperatorServers]) -> Int {
        if let matchingIndex = groups.firstIndex(where: { group in
            let domains = group.operator?.serverDomains.map { $0.lowercased() } ?? []
            return spec.hosts.contains { host in
                domains.contains { domain in
                    host == domain || host.hasSuffix(".\(domain)")
                }
            }
        }) {
            return matchingIndex
        }

        if let enabledIndex = groups.firstIndex(where: { $0.operator?.enabled ?? false }) {
            return enabledIndex
        }

        return groups.startIndex
    }

    private func applyTargets(
        _ specs: [ManagedServerSpec],
        protocol serverProtocol: ServerProtocol,
        to groups: inout [UserOperatorServers]
    ) {
        let keyPath: WritableKeyPath<UserOperatorServers, [UserServer]> = serverProtocol == .smp ? \.smpServers : \.xftpServers
        var existingByEndpoint: [ServerEndpoint: (groupIndex: Int, serverIndex: Int)] = [:]

        for groupIndex in groups.indices {
            for serverIndex in groups[groupIndex][keyPath: keyPath].indices {
                let server = groups[groupIndex][keyPath: keyPath][serverIndex]
                if let endpoint = endpoint(for: server, protocol: serverProtocol) {
                    existingByEndpoint[endpoint] = (groupIndex, serverIndex)
                }
            }
        }

        for spec in specs {
            if let existing = existingByEndpoint[spec.endpoint] {
                var server = groups[existing.groupIndex][keyPath: keyPath][existing.serverIndex]
                let uriChanged = server.server != spec.uri
                server.server = spec.uri
                server.preset = false
                server.enabled = true
                server.deleted = false
                if uriChanged {
                    server.tested = nil
                }
                groups[existing.groupIndex][keyPath: keyPath][existing.serverIndex] = server
            } else {
                let groupIndex = targetGroupIndex(for: spec, groups: groups)
                groups[groupIndex][keyPath: keyPath].append(
                    UserServer(
                        serverId: nil,
                        server: spec.uri,
                        preset: false,
                        tested: nil,
                        enabled: true,
                        deleted: false
                    )
                )
            }
        }
    }

    private func preparedUserServers(
        from currentServers: [UserOperatorServers],
        smpSpecs: [ManagedServerSpec],
        xftpSpecs: [ManagedServerSpec]
    ) -> [UserOperatorServers] {
        var groups = currentServers

        for groupIndex in groups.indices {
            groups[groupIndex].smpServers = groups[groupIndex].smpServers.map { server in
                var copy = server
                copy.enabled = false
                copy.deleted = false
                return copy
            }
            groups[groupIndex].xftpServers = groups[groupIndex].xftpServers.map { server in
                var copy = server
                copy.enabled = false
                copy.deleted = false
                return copy
            }
        }

        applyTargets(smpSpecs, protocol: .smp, to: &groups)
        applyTargets(xftpSpecs, protocol: .xftp, to: &groups)

        return groups
    }

    private func replaceServers() async {
        do {
            let currentServers = try await getUserServers()
            guard !currentServers.isEmpty else {
                logger.error("Inqalaab replaceServers: no operator groups returned")
                return
            }

            // Fetch server addresses (Firebase or fallback)
            let addresses = await fetchServerAddresses()
            let smpSpecs = addresses.smp.compactMap { managedServerSpec(for: $0, protocol: .smp) }
            let xftpSpecs = addresses.xftp.compactMap { managedServerSpec(for: $0, protocol: .xftp) }

            guard !smpSpecs.isEmpty else {
                logger.error("Inqalaab replaceServers: SMP server list is empty after parsing")
                return
            }
            guard !xftpSpecs.isEmpty else {
                logger.error("Inqalaab replaceServers: XFTP server list is empty after parsing")
                return
            }

            ensureManagedSMPPortMode()

            let modified = preparedUserServers(from: currentServers, smpSpecs: smpSpecs, xftpSpecs: xftpSpecs)
            let validationErrors = try await validateServers(userServers: modified)
            guard validationErrors.isEmpty else {
                logger.error("Inqalaab replaceServers validation failed: \(String(describing: validationErrors))")
                return
            }

            try await setUserServers(userServers: modified)
            do {
                try await reconnectAllServers()
            } catch {
                logger.error("Inqalaab reconnectAllServers error: \(error)")
            }
            do {
                let updatedOperators = try await getServerOperators()
                await MainActor.run {
                    ChatModel.shared.conditions = updatedOperators
                }
            } catch {
                logger.error("Inqalaab getServerOperators error: \(error)")
            }
            UserDefaults.standard.set(true, forKey: KEY_SERVERS_CONFIGURED)
        } catch {
            logger.error("Inqalaab replaceServers error: \(error)")
        }
    }

    private func ensureManagedSMPPortMode() {
        var cfg = getNetCfg()
        guard cfg.smpWebPortServers != .preset else { return }

        cfg.smpWebPortServers = .preset
        do {
            try setNetworkConfig(cfg)
            networkSMPWebPortServersDefault.set(cfg.smpWebPortServers)
        } catch {
            logger.error("Inqalaab ensureManagedSMPPortMode error: \(error)")
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

                if let name = displayName, presetContactsToDelete.contains(name) {
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
