//
//  InqalaabServers.swift
//  Inqalaab (iOS)
//
//  Server hardcoding and configuration for ChatFort.
//  Fetches server addresses from self-hosted Cloudflare Worker at inqalaab.chat,
//  falls back to hardcoded addresses if endpoint is unreachable.
//  No third-party telemetry — see v1.5.4 release notes.
//

import Foundation
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

    // Hardcoded fallback server addresses (used when the self-hosted endpoint is unreachable)
    private let FALLBACK_SMP_SERVERS = [
        "smp://4CfWwei1oOFAhmfUkmpsrSRELYLCvKBPgQIJlOT5z8I=@smp.suchkitalash.info:5223",
        "smp://jKkKmm64Gf6jWa2unI5t0QudCoTZxxFp8o28fDZWZU4=@smp1.inqalaab.chat:5223",
        "smp://JfdjUvMRakyzH7yzucTLoxKsY-EfvA0bMTj7kZG3Szs=@smp2.inqalaab.chat:5223",
        "smp://3XECaNOaqlLc_hPyrWSmw4rxrUGxALf5qQVqjaz-D-Y=@smp3.inqalaab.chat:5223",
        "smp://bxzXKrUHDBRwDW6EXIGCo4n_vi7y9pNOImxJ18ctebM=@smp4.inqalaab.chat:5223",
        "smp://bDhP69TeFAUd-OmMZp6yTXNcpUIE_9i0_i6KoA0RnTU=@smp5.inqalaab.chat:5223",
        "smp://XAuLzSPa9_Qfb4nALNsgKS-NP1ZNCpKVZSGlWv9xoYM=@smp6.inqalaab.chat:5223",
        "smp://oj77Z-Q8EwhIJDjH4UFkskH0VLThKzfv4Qy2QjUNN9g=@smp7.inqalaab.chat:5223",
    ]
    private let FALLBACK_XFTP_SERVERS = [
        "xftp://RzgzPjyel91YLliscUGXCjReG1kYV_5_o0pvOfZA_4s=@xftp.suchkitalash.info:5233",
        "xftp://Rs0YhJBOdAE1dXruOTXIfltkta5CQax2ZRgEyXdTyog=@xftp1.inqalaab.chat:443",
        "xftp://Aik60WjmVFLWOK2dKYEjEbfdUWxuyUpAp-VO3FcOE5w=@xftp2.inqalaab.chat:5233",
        "xftp://rQDMhOx8wUv7O6J3vht2W3HMsUXbqv0HZPQb3Ce02ss=@xftp3.inqalaab.chat:5233",
        "xftp://_yliO3argaVEhPG4ajaynctMWHFelsvC_GwtP-h1Mnc=@xftp4.inqalaab.chat:443",
        "xftp://qcQ1fAdGPBFNgQq4FmN4Klqf1Sky68w06thBxNp-5TQ=@xftp5.inqalaab.chat:443",
        "xftp://-dvwQSUq1goxTbV-AzrIcvjJ5sk-69rtYK3fo88HkMw=@xftp6.inqalaab.chat:443",
    ]

    private let MANAGED_SMP_KEYS_BY_HOST = [
        "smp.suchkitalash.info": "4CfWwei1oOFAhmfUkmpsrSRELYLCvKBPgQIJlOT5z8I=",
        "smp1.inqalaab.chat": "jKkKmm64Gf6jWa2unI5t0QudCoTZxxFp8o28fDZWZU4=",
        "smp2.inqalaab.chat": "JfdjUvMRakyzH7yzucTLoxKsY-EfvA0bMTj7kZG3Szs=",
        "smp3.inqalaab.chat": "3XECaNOaqlLc_hPyrWSmw4rxrUGxALf5qQVqjaz-D-Y=",
        "smp4.inqalaab.chat": "bxzXKrUHDBRwDW6EXIGCo4n_vi7y9pNOImxJ18ctebM=",
        "smp5.inqalaab.chat": "bDhP69TeFAUd-OmMZp6yTXNcpUIE_9i0_i6KoA0RnTU=",
        "smp6.inqalaab.chat": "XAuLzSPa9_Qfb4nALNsgKS-NP1ZNCpKVZSGlWv9xoYM=",
        "smp7.inqalaab.chat": "oj77Z-Q8EwhIJDjH4UFkskH0VLThKzfv4Qy2QjUNN9g=",
    ]
    private let MANAGED_SMP_CANONICAL_URIS_BY_HOST = [
        "smp.suchkitalash.info": "smp://4CfWwei1oOFAhmfUkmpsrSRELYLCvKBPgQIJlOT5z8I=@smp.suchkitalash.info:5223",
        "smp1.inqalaab.chat": "smp://jKkKmm64Gf6jWa2unI5t0QudCoTZxxFp8o28fDZWZU4=@smp1.inqalaab.chat:5223",
        "smp2.inqalaab.chat": "smp://JfdjUvMRakyzH7yzucTLoxKsY-EfvA0bMTj7kZG3Szs=@smp2.inqalaab.chat:5223",
        "smp3.inqalaab.chat": "smp://3XECaNOaqlLc_hPyrWSmw4rxrUGxALf5qQVqjaz-D-Y=@smp3.inqalaab.chat:5223",
        "smp4.inqalaab.chat": "smp://bxzXKrUHDBRwDW6EXIGCo4n_vi7y9pNOImxJ18ctebM=@smp4.inqalaab.chat:5223",
        "smp5.inqalaab.chat": "smp://bDhP69TeFAUd-OmMZp6yTXNcpUIE_9i0_i6KoA0RnTU=@smp5.inqalaab.chat:5223",
        "smp6.inqalaab.chat": "smp://XAuLzSPa9_Qfb4nALNsgKS-NP1ZNCpKVZSGlWv9xoYM=@smp6.inqalaab.chat:5223",
        "smp7.inqalaab.chat": "smp://oj77Z-Q8EwhIJDjH4UFkskH0VLThKzfv4Qy2QjUNN9g=@smp7.inqalaab.chat:5223",
    ]
    private let MANAGED_XFTP_CANONICAL_URIS_BY_HOST = [
        "xftp.suchkitalash.info": "xftp://RzgzPjyel91YLliscUGXCjReG1kYV_5_o0pvOfZA_4s=@xftp.suchkitalash.info:5233",
        "xftp1.inqalaab.chat": "xftp://Rs0YhJBOdAE1dXruOTXIfltkta5CQax2ZRgEyXdTyog=@xftp1.inqalaab.chat:443",
        "xftp2.inqalaab.chat": "xftp://Aik60WjmVFLWOK2dKYEjEbfdUWxuyUpAp-VO3FcOE5w=@xftp2.inqalaab.chat:5233",
        "xftp3.inqalaab.chat": "xftp://rQDMhOx8wUv7O6J3vht2W3HMsUXbqv0HZPQb3Ce02ss=@xftp3.inqalaab.chat:5233",
        "xftp4.inqalaab.chat": "xftp://_yliO3argaVEhPG4ajaynctMWHFelsvC_GwtP-h1Mnc=@xftp4.inqalaab.chat:443",
        "xftp5.inqalaab.chat": "xftp://qcQ1fAdGPBFNgQq4FmN4Klqf1Sky68w06thBxNp-5TQ=@xftp5.inqalaab.chat:443",
        "xftp6.inqalaab.chat": "xftp://-dvwQSUq1goxTbV-AzrIcvjJ5sk-69rtYK3fo88HkMw=@xftp6.inqalaab.chat:443",
    ]

    private let KEY_SERVERS_CONFIGURED = "inqalaab_servers_configured_v17"
    private let KEY_CONTACTS_CLEANED = "inqalaab_contacts_cleaned"
    private let KEY_ADDRESS_CREATED = "inqalaab_address_created"
    /// Profiles added after the first one that still need their address (user IDs). The flags above are
    /// app-wide and already set by then, so each new profile is marked when it's created.
    static let KEY_ADDRESS_PENDING = "inqalaab_address_pending_users"
    @MainActor private var creatingAddressFor: Int64?

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
    private var scheduledConfigureWorkItem: DispatchWorkItem?

    private func legacyPresetContactName(_ bytes: [UInt8]) -> String {
        let decoded = bytes.map { $0 ^ legacyPresetNameMask }
        return String(decoding: decoded, as: UTF8.self)
    }

    func scheduleConfigureIfNeeded(after delay: TimeInterval = 15, reason: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let serversConfigured = UserDefaults.standard.bool(forKey: self.KEY_SERVERS_CONFIGURED)
            let contactsCleaned = UserDefaults.standard.bool(forKey: self.KEY_CONTACTS_CLEANED)
            let addressCreated = UserDefaults.standard.bool(forKey: self.KEY_ADDRESS_CREATED)

            guard !(serversConfigured && contactsCleaned && addressCreated) else {
                logger.debug("Inqalaab scheduleConfigureIfNeeded: already complete, skipping (\(reason))")
                return
            }

            guard self.scheduledConfigureWorkItem == nil else {
                logger.debug("Inqalaab scheduleConfigureIfNeeded: already scheduled, skipping (\(reason))")
                return
            }

            let workItem = DispatchWorkItem { [weak self] in
                self?.scheduledConfigureWorkItem = nil
                self?.configureIfNeeded()
            }
            self.scheduledConfigureWorkItem = workItem
            logger.debug("Inqalaab scheduleConfigureIfNeeded: scheduled in \(delay)s (\(reason))")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    func configureIfNeeded() {
        let serversConfigured = UserDefaults.standard.bool(forKey: KEY_SERVERS_CONFIGURED)
        let contactsCleaned = UserDefaults.standard.bool(forKey: KEY_CONTACTS_CLEANED)
        let addressCreated = UserDefaults.standard.bool(forKey: KEY_ADDRESS_CREATED)

        logger.debug("Inqalaab configureIfNeeded: servers=\(serversConfigured) contacts=\(contactsCleaned) address=\(addressCreated)")

        guard !isConfiguring else {
            logger.debug("Inqalaab configureIfNeeded: already configuring, skipping")
            return
        }
        isConfiguring = true

        Task {
            defer { isConfiguring = false }
            guard ChatModel.shared.chatRunning == true,
                  AppChatState.shared.value == .active else {
                logger.debug("Inqalaab configureIfNeeded: chat not running or not active, skipping")
                return
            }

            if !serversConfigured {
                logger.debug("Inqalaab configureIfNeeded: replacing servers...")
                await replaceServers()
            }

            if !contactsCleaned {
                logger.debug("Inqalaab configureIfNeeded: cleaning contacts...")
                await deletePresetContacts()
            }
            if !addressCreated {
                logger.debug("Inqalaab configureIfNeeded: creating address...")
                await createUserAddress()
            }
        }
    }

    /// Removes duplicate and non-managed servers — backend re-adds preset servers on each launch.
    /// Deduplicates by host, keeping only the canonical URI (with explicit port).
    private func cleanupStaleServers() async {
        do {
            let currentServers = try await getUserServers()
            guard !currentServers.isEmpty else { return }

            var groups = currentServers
            var needsUpdate = false

            for groupIndex in groups.indices {
                // SMP: deduplicate by host, keep only canonical URI
                var seenSmpHosts = Set<String>()
                let smpBefore = groups[groupIndex].smpServers.count
                groups[groupIndex].smpServers = groups[groupIndex].smpServers.filter { server in
                    guard let host = parseHost(from: server.server) else { return false }
                    guard MANAGED_SMP_CANONICAL_URIS_BY_HOST[host] != nil else { return false }
                    guard !seenSmpHosts.contains(host) else { return false }
                    seenSmpHosts.insert(host)
                    return true
                }
                if groups[groupIndex].smpServers.count != smpBefore { needsUpdate = true }

                // XFTP: deduplicate by host, keep only canonical URI
                var seenXftpHosts = Set<String>()
                let xftpBefore = groups[groupIndex].xftpServers.count
                groups[groupIndex].xftpServers = groups[groupIndex].xftpServers.filter { server in
                    guard let host = parseHost(from: server.server) else { return false }
                    guard MANAGED_XFTP_CANONICAL_URIS_BY_HOST[host] != nil else { return false }
                    guard !seenXftpHosts.contains(host) else { return false }
                    seenXftpHosts.insert(host)
                    return true
                }
                if groups[groupIndex].xftpServers.count != xftpBefore { needsUpdate = true }
            }

            if needsUpdate {
                logger.debug("Inqalaab cleanupStaleServers: removing \(needsUpdate ? "duplicate/non-managed" : "no") servers")
                try await setUserServers(userServers: groups)
            }
        } catch {
            logger.error("Inqalaab cleanupStaleServers error: \(error)")
        }
    }

    /// Extract host from a server URI like "smp://key@host:port"
    private func parseHost(from uri: String) -> String? {
        guard let atIndex = uri.firstIndex(of: "@") else { return nil }
        let afterAt = uri[uri.index(after: atIndex)...]
        if let colonIndex = afterAt.lastIndex(of: ":") {
            return String(afterAt[afterAt.startIndex..<colonIndex])
        }
        return String(afterAt)
    }

    // ChatFort: server config is fetched from self-hosted Cloudflare Worker on inqalaab.chat,
    // not from any third-party service.
    // Fetched without local caching so emergency server rotations are picked up promptly.
    private struct ServerConfigResponse: Decodable {
        let smp_servers: [String]
        let xftp_servers: [String]
    }

    private func fetchServerAddresses() async -> (smp: [String], xftp: [String]) {
        let url = URL(string: "https://inqalaab.chat/api/servers")!
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logger.warning("Inqalaab fetchServerAddresses: non-200 response, using fallback")
                return (
                    normalizedServerURIs(FALLBACK_SMP_SERVERS, protocol: .smp),
                    normalizedServerURIs(FALLBACK_XFTP_SERVERS, protocol: .xftp)
                )
            }

            let config = try JSONDecoder().decode(ServerConfigResponse.self, from: data)
            let smpRaw = config.smp_servers.joined(separator: ",")
            let xftpRaw = config.xftp_servers.joined(separator: ",")

            let smpServers = parseServerList(smpRaw, protocol: .smp)
            let xftpServers = parseServerList(xftpRaw, protocol: .xftp)
            let validatedSMPServers = validatedManagedSMPServers(smpServers)

            if !validatedSMPServers.isEmpty && !xftpServers.isEmpty {
                logger.debug("Inqalaab fetched \(validatedSMPServers.count) SMP and \(xftpServers.count) XFTP servers from inqalaab.chat")
                return (validatedSMPServers, xftpServers)
            }

            logger.error("Inqalaab server endpoint returned invalid lists, using fallback")
        } catch {
            logger.error("Inqalaab server endpoint fetch failed, using fallback: \(error.localizedDescription)")
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
                logger.error("Inqalaab server endpoint contains an unparsable SMP URI, using fallback")
                return []
            }

            for host in address.hostnames.map({ $0.lowercased() }) {
                guard let expectedKey = MANAGED_SMP_KEYS_BY_HOST[host] else { continue }
                guard address.keyHash == expectedKey else {
                    logger.error("Inqalaab server endpoint fingerprint mismatch for \(host), using fallback")
                    return []
                }
                matchedHosts.insert(host)
            }
        }

        if matchedHosts != Set(MANAGED_SMP_KEYS_BY_HOST.keys) {
            logger.error("Inqalaab server endpoint missing managed SMP hosts, using fallback")
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
        let primaryHost = parsedAddress.hostnames.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if serverProtocol == .smp {
            guard let primaryHost,
                  let managedURI = MANAGED_SMP_CANONICAL_URIS_BY_HOST[primaryHost],
                  let managedAddress = parseServerAddress(managedURI),
                  managedAddress.valid else { return nil }
            address = managedAddress
            canonicalURI = managedURI
        } else if serverProtocol == .xftp {
            guard let primaryHost,
                  let managedURI = MANAGED_XFTP_CANONICAL_URIS_BY_HOST[primaryHost],
                  let managedAddress = parseServerAddress(managedURI),
                  managedAddress.valid else { return nil }
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
                copy.deleted = true
                return copy
            }
            groups[groupIndex].xftpServers = groups[groupIndex].xftpServers.map { server in
                var copy = server
                copy.enabled = false
                copy.deleted = true
                return copy
            }
        }

        applyTargets(smpSpecs, protocol: .smp, to: &groups)
        applyTargets(xftpSpecs, protocol: .xftp, to: &groups)

        // Keep deleted servers in payload so backend actually removes them from DB
        // (filtering them out causes backend to leave stale entries untouched)

        return groups
    }

    func replaceManagedServersForSettings() async -> [UserOperatorServers]? {
        await replaceServers()
    }

    @discardableResult
    private func replaceServers() async -> [UserOperatorServers]? {
        do {
            let currentServers = try await getUserServers()
            guard !currentServers.isEmpty else {
                logger.error("Inqalaab replaceServers: no operator groups returned")
                return nil
            }

            // Fetch server addresses from self-hosted endpoint or fallback.
            let addresses = await fetchServerAddresses()
            let smpSpecs = addresses.smp.compactMap { managedServerSpec(for: $0, protocol: .smp) }
            let xftpSpecs = addresses.xftp.compactMap { managedServerSpec(for: $0, protocol: .xftp) }

            guard !smpSpecs.isEmpty else {
                logger.error("Inqalaab replaceServers: SMP server list is empty after parsing")
                return nil
            }
            guard !xftpSpecs.isEmpty else {
                logger.error("Inqalaab replaceServers: XFTP server list is empty after parsing")
                return nil
            }

            ensureManagedSMPPortMode()

            let modified = preparedUserServers(from: currentServers, smpSpecs: smpSpecs, xftpSpecs: xftpSpecs)
            let validationErrors = try await validateServers(userServers: modified)
            guard validationErrors.isEmpty else {
                logger.error("Inqalaab replaceServers validation failed: \(String(describing: validationErrors))")
                return nil
            }

            try await setUserServers(userServers: modified)
            let updatedServers = try await getUserServers()
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
            return updatedServers
        } catch {
            logger.error("Inqalaab replaceServers error: \(error)")
            return nil
        }
    }

    private func ensureManagedSMPPortMode() {
        var cfg = getNetCfg()
        guard cfg.smpWebPortServers != .off else { return }

        cfg.smpWebPortServers = .off
        do {
            try setNetworkConfig(cfg)
            networkSMPWebPortServersDefault.set(cfg.smpWebPortServers)
        } catch {
            logger.error("Inqalaab ensureManagedSMPPortMode error: \(error)")
        }
    }

    /// A profile's chats have loaded (start, profile switch, new profile): per-profile upkeep.
    @MainActor
    func profileChatsLoaded() {
        removePresetCards()
        createAddressIfPending()
    }

    /// A profile was added (Settings › profiles): it gets its address once its chats are loaded.
    func newProfileCreated(userId: Int64) {
        var ids = Set(UserDefaults.standard.array(forKey: Self.KEY_ADDRESS_PENDING) as? [Int] ?? [])
        ids.insert(Int(userId))
        UserDefaults.standard.set(Array(ids), forKey: Self.KEY_ADDRESS_PENDING)
    }

    /// Once per new profile, so an address the user deletes later isn't brought back.
    @MainActor
    private func createAddressIfPending() {
        let m = ChatModel.shared
        guard m.chatRunning == true, let userId = m.currentUser?.userId, creatingAddressFor == nil else { return }
        var pending = Set(UserDefaults.standard.array(forKey: Self.KEY_ADDRESS_PENDING) as? [Int] ?? [])
        guard pending.contains(Int(userId)) else { return }
        guard m.userAddress == nil else {
            pending.remove(Int(userId))
            UserDefaults.standard.set(Array(pending), forKey: Self.KEY_ADDRESS_PENDING)
            return
        }
        creatingAddressFor = userId
        Task {
            let created = await createAddressForCurrentUser()
            await MainActor.run {
                creatingAddressFor = nil
                guard created, ChatModel.shared.currentUser?.userId == userId else { return }
                var left = Set(UserDefaults.standard.array(forKey: Self.KEY_ADDRESS_PENDING) as? [Int] ?? [])
                left.remove(Int(userId))
                UserDefaults.standard.set(Array(left), forKey: Self.KEY_ADDRESS_PENDING)
            }
        }
    }

    /// The core adds SimpleX's preset contact cards to every new profile, not just the first, so the
    /// one-time cleanup below misses later profiles. Runs whenever a profile's chats are loaded and
    /// removes the cards that aren't connected contacts.
    @MainActor
    func removePresetCards() {
        guard ChatModel.shared.chatRunning == true else { return }
        let cards = ChatModel.shared.chats.compactMap { chat -> ChatInfo? in
            guard case let .direct(contact) = chat.chatInfo, !contact.ready,
                  presetContactsToDelete.contains(contact.displayName)
            else { return nil }
            return chat.chatInfo
        }
        guard !cards.isEmpty else { return }
        Task {
            for info in cards {
                do {
                    try await apiDeleteChat(type: info.chatType, id: info.apiId)
                    await MainActor.run { ChatModel.shared.removeChat(info.id) }
                } catch {
                    logger.error("Inqalaab: failed to remove a preset card: \(error)")
                }
            }
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
        if await createAddressForCurrentUser() {
            UserDefaults.standard.set(true, forKey: KEY_ADDRESS_CREATED)
        }
    }

    /// Creates the active profile's address (or loads it if it exists). True if it has one now.
    private func createAddressForCurrentUser() async -> Bool {
        if await MainActor.run(body: { ChatModel.shared.userAddress != nil }) { return true }
        do {
            guard let connLink = try await apiCreateUserAddress() else { return false }
            await MainActor.run {
                ChatModel.shared.userAddress = UserContactLink(connLink)
            }
            return true
        } catch {
            do {
                if let existingAddress = try await apiGetUserAddressAsync() {
                    await MainActor.run {
                        ChatModel.shared.userAddress = existingAddress
                    }
                    return true
                }
            } catch {
                logger.error("Inqalaab createUserAddress error: \(error)")
            }
            return false
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
