package chat.simplex.app

import android.util.Base64
import chat.simplex.common.model.*
import chat.simplex.common.model.ChatController.getUserServers
import chat.simplex.common.model.ChatController.setUserServers
import chat.simplex.common.platform.*
import chat.simplex.common.views.helpers.*
import com.google.firebase.remoteconfig.FirebaseRemoteConfig
import com.google.firebase.remoteconfig.FirebaseRemoteConfigSettings
import kotlinx.coroutines.*
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

object InqalaabServers {
    /**
     * Call this once during app startup to register the emergency wipe hooks.
     * This ensures server config is reset and reconfigured after emergency wipe.
     */
    fun init() {
        chat.simplex.common.views.safetyhub.onEmergencyWipeResetConfig = {
            val prefs = androidAppContext.getSharedPreferences(PREFS_NAME, 0)
            prefs.edit().clear().apply()
            println("ChatFort: Server config prefs cleared via emergency wipe")
        }
        chat.simplex.common.views.safetyhub.onEmergencyWipeReconfigure = {
            println("ChatFort: Triggering server reconfiguration after emergency wipe")
            configureIfNeeded()
        }
    }

    // Obfuscated fallback server addresses (Base64 encoded)
    private val FALLBACK_SMP = listOf(
        "c21wOi8vNENmV3dlaTFvT0ZBaG1mVWttcHNyU1JFTFlMQ3ZLQlBnUUlKbE9UNXo4ST1Ac21wLnN1Y2hraXRhbGFzaC5pbmZv",
        "c21wOi8vaktrS21tNjRHZjZqV2EydW5JNXQwUXVkQ29UWnh4RnA4bzI4ZkRaV1pVND1Ac21wMS5pbnFhbGFhYi5jaGF0",
        "c21wOi8vSmZkalV2TVJha3l6SDd5enVjVExveEtzWS1FZnZBMGJNVGo3a1pHM1N6cz1Ac21wMi5pbnFhbGFhYi5jaGF0",
        "c21wOi8vM1hFQ2FOT2FxbExjX2hQeXJXU213NHJ4clVHeEFMZjVxUVZxamF6LUQtWT1Ac21wMy5pbnFhbGFhYi5jaGF0",
        "c21wOi8vYnh6WEtyVUhEQlJ3RFc2RVhJR0NvNG5fdmk3eTlwTk9JbXhKMThjdGViTT1Ac21wNC5pbnFhbGFhYi5jaGF0",
        "c21wOi8vYkRoUDY5VGVGQVVkLU9tTVpwNnlUWE5jcFVJRV85aTBfaTZLb0EwUm5UVT1Ac21wNS5pbnFhbGFhYi5jaGF0",
        "c21wOi8vWEF1THpTUGE5X1FmYjRuQUxOc2dLUy1OUDFaTkNwS1ZaU0dsV3Y5eG9ZTT1Ac21wNi5pbnFhbGFhYi5jaGF0",
        "c21wOi8vb2o3N1otUThFd2hJSkRqSDRVRmtza0gwVkxUaEt6ZnY0UXkyUWpVTk45Zz1Ac21wNy5pbnFhbGFhYi5jaGF0"
    )
    private val FALLBACK_XFTP = listOf(
        "eGZ0cDovL1J6Z3pQanllbDkxWUxsaXNjVUdYQ2pSZUcxa1lWXzVfbzBwdk9mWkFfNHM9QHhmdHAuc3VjaGtpdGFsYXNoLmluZm86NTIzMw==",
        "eGZ0cDovL29Pdnk2azk5TFQ1ZHlTZUlPbXc1LUc0RkRaNW8zU1NwVndtNllteUJzWkk9QHhmdHAxLmlucWFsYWFiLmNoYXQ=",
        "eGZ0cDovL0FpazYwV2ptVkZMV09LMmRLWUVqRWJmZFVXeHV5VXBBcC1WTzNGY09FNXc9QHhmdHAyLmlucWFsYWFiLmNoYXQ6NTIzMw==",
        "eGZ0cDovL3JRRE1oT3g4d1V2N082SjN2aHQyVzNITXNVWGJxdjBIWlBRYjNDZTAyc3M9QHhmdHAzLmlucWFsYWFiLmNoYXQ6NTIzMw==",
        "eGZ0cDovL195bGlPM2FyZ2FWRWhQRzRhamF5bmN0TVdIRmVsc3ZDX0d3dFAtaDFNbmM9QHhmdHA0LmlucWFsYWFiLmNoYXQ=",
        "eGZ0cDovL3FjUTFmQWRHUEJGTmdRcTRGbU40S2xxZjFTa3k2OHcwNnRoQnhOcC01VFE9QHhmdHA1LmlucWFsYWFiLmNoYXQ=",
        "eGZ0cDovLy1kdndRU1VxMWdveFRiVi1BenJJY3ZqSjVzay02OXJ0WUszZm84OEhrTXc9QHhmdHA2LmlucWFsYWFiLmNoYXQ="
    )

    private val INQALAAB_HOSTS = setOf("suchkitalash.info", "inqalaab.chat")
    // Bump this version whenever server addresses change to force reconfiguration
    private const val SERVER_CONFIG_VERSION = 6
    private const val PREFS_NAME = "inqalaab_prefs"
    private const val KEY_SERVERS_CONFIGURED = "servers_configured"
    private const val KEY_SERVER_VERSION = "server_config_version"
    private const val KEY_CONTACTS_CLEANED = "contacts_cleaned"
    private const val KEY_ADDRESS_CREATED = "address_created"

    private val PRESET_CONTACTS_TO_DELETE = setOf("SimpleX Status", "Ask SimpleX Team")

    private fun decode(encoded: String): String {
        return String(Base64.decode(encoded, Base64.NO_WRAP))
    }

    private suspend fun fetchServersFromFirebase(): Pair<List<String>, List<String>>? {
        return try {
            val remoteConfig = FirebaseRemoteConfig.getInstance()
            val configSettings = FirebaseRemoteConfigSettings.Builder()
                .setMinimumFetchIntervalInSeconds(3600) // 1 hour cache
                .build()
            remoteConfig.setConfigSettingsAsync(configSettings)

            // Fetch and activate
            val fetched = suspendCoroutine<Boolean> { cont ->
                remoteConfig.fetchAndActivate().addOnCompleteListener { task ->
                    cont.resume(task.isSuccessful)
                }
            }

            if (!fetched) {
                println("ChatFort: Firebase fetch failed, using fallback")
                return null
            }

            val smpString = remoteConfig.getString("smp_servers")
            val xftpString = remoteConfig.getString("xftp_servers")

            if (smpString.isBlank() || xftpString.isBlank()) {
                println("ChatFort: Firebase config empty, using fallback")
                return null
            }

            val smpList = smpString.split(",").map { it.trim() }.filter { it.startsWith("smp://") }
            val xftpList = xftpString.split(",").map { it.trim() }.filter { it.startsWith("xftp://") }

            if (smpList.isEmpty() || xftpList.isEmpty()) {
                println("ChatFort: Firebase config invalid, using fallback")
                return null
            }

            println("ChatFort: Got ${smpList.size} SMP and ${xftpList.size} XFTP servers from Firebase")
            Pair(smpList, xftpList)
        } catch (e: Exception) {
            println("ChatFort: Firebase error: ${e.message}, using fallback")
            null
        }
    }

    fun configureIfNeeded() {
        val prefs = androidAppContext.getSharedPreferences(PREFS_NAME, 0)

        val savedVersion = prefs.getInt(KEY_SERVER_VERSION, 0)
        var serversConfigured = prefs.getBoolean(KEY_SERVERS_CONFIGURED, false)
        val contactsCleaned = prefs.getBoolean(KEY_CONTACTS_CLEANED, false)
        val addressCreated = prefs.getBoolean(KEY_ADDRESS_CREATED, false)

        // Force server reconfiguration if server addresses changed
        if (serversConfigured && savedVersion < SERVER_CONFIG_VERSION) {
            println("ChatFort: Server config version changed ($savedVersion -> $SERVER_CONFIG_VERSION), reconfiguring...")
            serversConfigured = false
            prefs.edit().putBoolean(KEY_SERVERS_CONFIGURED, false).apply()
        }

        if (serversConfigured && contactsCleaned && addressCreated) {
            println("ChatFort: Already fully configured, skipping")
            return
        }

        withBGApi {
            try {
                // Wait for chat to be running (up to 30 seconds)
                var waited = 0
                while (chatModel.chatRunning.value != true && waited < 30) {
                    println("ChatFort: Chat not running yet, waiting... (${waited}s)")
                    delay(1000)
                    waited++
                }

                if (chatModel.chatRunning.value != true) {
                    println("ChatFort: Chat still not running after ${waited}s, giving up")
                    return@withBGApi
                }

                println("ChatFort: Chat is running, configuring...")
                val rh = chatModel.remoteHostId()

                // ── Part 1: Replace servers ──
                if (!serversConfigured) {
                    replaceServers(rh, prefs)
                }

                // ── Part 2: Delete preset contacts ──
                if (!contactsCleaned) {
                    deletePresetContacts(rh, prefs)
                }

                // ── Part 3: Auto-create user address ──
                if (!addressCreated) {
                    createUserAddress(rh, prefs)
                }
            } catch (e: Exception) {
                println("ChatFort: Exception: ${e.message}")
                e.printStackTrace()
            }
        }
    }

    private fun serverHost(url: String): String? {
        // Extract hostname from server URL like smp://fingerprint@hostname or xftp://fingerprint@hostname:port
        val atIndex = url.indexOf('@')
        if (atIndex < 0) return null
        val hostPart = url.substring(atIndex + 1)
        return hostPart.split(':').firstOrNull()
    }

    private suspend fun replaceServers(rh: Long?, prefs: android.content.SharedPreferences) {
        println("ChatFort: Starting server replacement...")

        // Try Firebase first, fall back to hardcoded obfuscated servers
        val (smpServers, xftpServers) = fetchServersFromFirebase()
            ?: Pair(FALLBACK_SMP.map { decode(it) }, FALLBACK_XFTP.map { decode(it) })

        val currentServers = getUserServers(rh)
        if (currentServers == null) {
            println("ChatFort: getUserServers returned null")
            return
        }

        println("ChatFort: Found ${currentServers.size} server groups")

        // Collect all existing server hostnames to detect duplicates
        val existingSmpHosts = currentServers.flatMap { it.smpServers }
            .filter { it.enabled && !it.deleted }
            .mapNotNull { serverHost(it.server) }
            .toMutableSet()
        val existingXftpHosts = currentServers.flatMap { it.xftpServers }
            .filter { it.enabled && !it.deleted }
            .mapNotNull { serverHost(it.server) }
            .toMutableSet()

        // Filter out servers that already exist (by hostname)
        val newSmpServers = smpServers.filter { url ->
            val host = serverHost(url)
            host != null && host !in existingSmpHosts
        }
        val newXftpServers = xftpServers.filter { url ->
            val host = serverHost(url)
            host != null && host !in existingXftpHosts
        }

        println("ChatFort: ${newSmpServers.size} new SMP, ${newXftpServers.size} new XFTP to add")

        // Check if any Inqalaab servers already exist
        val hasInqalaabServers = existingSmpHosts.any { host ->
            INQALAAB_HOSTS.any { domain -> host.endsWith(domain) }
        }

        var smpIndex = 0
        var xftpIndex = 0

        val modified = if (hasInqalaabServers) {
            // Already have Inqalaab servers — just add the new ones, don't repurpose
            println("ChatFort: Existing Inqalaab servers found, adding new servers only")
            currentServers.map { group ->
                // Disable any non-Inqalaab servers that are still enabled
                val updatedSmp = group.smpServers.map { srv ->
                    val host = serverHost(srv.server)
                    if (host != null && INQALAAB_HOSTS.any { domain -> host.endsWith(domain) }) {
                        srv.copy(enabled = true)
                    } else {
                        srv.copy(enabled = false)
                    }
                }
                val updatedXftp = group.xftpServers.map { srv ->
                    val host = serverHost(srv.server)
                    if (host != null && INQALAAB_HOSTS.any { domain -> host.endsWith(domain) }) {
                        srv.copy(enabled = true)
                    } else {
                        srv.copy(enabled = false)
                    }
                }
                UserOperatorServers(operator = group.operator, smpServers = updatedSmp, xftpServers = updatedXftp)
            }
        } else {
            // Fresh install — repurpose SimpleX/Flux donor records
            println("ChatFort: No Inqalaab servers found, repurposing donors")
            currentServers.map { group ->
                val newSmp = group.smpServers.map { srv ->
                    if (smpIndex < smpServers.size && srv.serverId != null) {
                        val serverUrl = smpServers[smpIndex]
                        smpIndex++
                        println("ChatFort: Repurposing SMP id=${srv.serverId} -> $serverUrl")
                        srv.copy(server = serverUrl, preset = false, tested = null, enabled = true)
                    } else {
                        srv.copy(enabled = false)
                    }
                }
                val newXftp = group.xftpServers.map { srv ->
                    if (xftpIndex < xftpServers.size && srv.serverId != null) {
                        val serverUrl = xftpServers[xftpIndex]
                        xftpIndex++
                        println("ChatFort: Repurposing XFTP id=${srv.serverId} -> $serverUrl")
                        srv.copy(server = serverUrl, preset = false, tested = null, enabled = true)
                    } else {
                        srv.copy(enabled = false)
                    }
                }
                UserOperatorServers(operator = group.operator, smpServers = newSmp, xftpServers = newXftp)
            }
        }

        // Add any servers that don't already exist
        val serversToAddSmp = if (hasInqalaabServers) newSmpServers else smpServers.drop(smpIndex)
        val serversToAddXftp = if (hasInqalaabServers) newXftpServers else xftpServers.drop(xftpIndex)

        val finalModified = if (serversToAddSmp.isNotEmpty() || serversToAddXftp.isNotEmpty()) {
            val firstGroup = modified.first()
            val extraSmp = serversToAddSmp.map { url ->
                println("ChatFort: Adding new SMP server: $url")
                UserServer(remoteHostId = rh, serverId = null, server = url, preset = false, tested = null, enabled = true, deleted = false)
            }
            val extraXftp = serversToAddXftp.map { url ->
                println("ChatFort: Adding new XFTP server: $url")
                UserServer(remoteHostId = rh, serverId = null, server = url, preset = false, tested = null, enabled = true, deleted = false)
            }
            val updatedFirst = firstGroup.copy(
                smpServers = firstGroup.smpServers + extraSmp,
                xftpServers = firstGroup.xftpServers + extraXftp
            )
            listOf(updatedFirst) + modified.drop(1)
        } else {
            modified
        }

        if (!hasInqalaabServers && (smpIndex == 0 || xftpIndex == 0)) {
            println("ChatFort: ERROR - No donor servers on fresh install (smp=$smpIndex xftp=$xftpIndex)")
            return
        }

        println("ChatFort: Calling setUserServers...")
        val success = setUserServers(rh, finalModified)
        println("ChatFort: setUserServers result: $success")

        if (success) {
            // Disable all operators (hides SimpleX + Flux from UI)
            val conditions = chatModel.conditions.value
            val disabledOps = conditions.serverOperators.map { it.copy(enabled = false) }
            println("ChatFort: Disabling ${disabledOps.size} operators...")
            val result = chatController.setServerOperators(rh = rh, operators = disabledOps)
            if (result != null) {
                chatModel.conditions.value = result
                println("ChatFort: Operators disabled")
            }

            // Verify
            val verify = getUserServers(rh)
            if (verify != null) {
                val activeSmp = verify.flatMap { it.smpServers }.filter { it.enabled }
                val activeXftp = verify.flatMap { it.xftpServers }.filter { it.enabled }
                println("ChatFort: Servers: ${activeSmp.size} SMP, ${activeXftp.size} XFTP active")
            }

            prefs.edit()
                .putBoolean(KEY_SERVERS_CONFIGURED, true)
                .putInt(KEY_SERVER_VERSION, SERVER_CONFIG_VERSION)
                .apply()
            println("ChatFort: Server replacement complete (version $SERVER_CONFIG_VERSION)")
        }
    }

    private suspend fun deletePresetContacts(rh: Long?, prefs: android.content.SharedPreferences) {
        println("ChatFort: Cleaning preset contacts...")

        val chats = chatModel.chats.value
        var deleted = 0
        var found = 0

        for (chat in chats) {
            val cInfo = chat.chatInfo
            if (cInfo is ChatInfo.Direct && cInfo.displayName in PRESET_CONTACTS_TO_DELETE) {
                found++
                println("ChatFort: Deleting contact: ${cInfo.displayName} (id=${cInfo.apiId})")
                val success = chatController.apiDeleteChat(
                    rh = chat.remoteHostId,
                    type = ChatType.Direct,
                    id = cInfo.apiId
                )
                if (success) {
                    withContext(Dispatchers.Main) {
                        chatModel.chatsContext.removeChat(chat.remoteHostId, cInfo.id)
                    }
                    println("ChatFort: Deleted ${cInfo.displayName}")
                    deleted++
                } else {
                    println("ChatFort: Failed to delete ${cInfo.displayName}")
                }
            }
        }

        println("ChatFort: Found $found preset contacts, deleted $deleted")
        // Only mark done if we found and deleted them, OR if the chat list is already empty
        if (found == deleted && (found > 0 || chats.isEmpty())) {
            prefs.edit().putBoolean(KEY_CONTACTS_CLEANED, true).apply()
            println("ChatFort: Contacts cleanup marked complete")
        } else {
            println("ChatFort: Contacts cleanup incomplete, will retry next launch")
        }
    }

    private suspend fun createUserAddress(rh: Long?, prefs: android.content.SharedPreferences) {
        // Check if address already exists
        if (chatModel.userAddress.value != null) {
            // Ensure auto-accept is enabled on existing address
            enableAutoAccept(rh)
            println("ChatFort: User address already exists")
            prefs.edit().putBoolean(KEY_ADDRESS_CREATED, true).apply()
            return
        }

        println("ChatFort: Creating user address...")
        val connLink = chatController.apiCreateUserAddress(rh)
        if (connLink != null) {
            val autoAcceptSettings = AddressSettings(
                businessAddress = false,
                autoAccept = AutoAccept(acceptIncognito = false),
                autoReply = null
            )
            val slDataSet = connLink.connShortLink != null
            withContext(Dispatchers.Main) {
                chatModel.userAddress.value = UserContactLinkRec(
                    connLink,
                    shortLinkDataSet = slDataSet,
                    shortLinkLargeDataSet = slDataSet,
                    addressSettings = autoAcceptSettings
                )
            }
            // Enable auto-accept on the newly created address
            enableAutoAccept(rh)
            println("ChatFort: User address created with auto-accept enabled")
            prefs.edit().putBoolean(KEY_ADDRESS_CREATED, true).apply()
        } else {
            println("ChatFort: Failed to create user address")
        }
    }

    private suspend fun enableAutoAccept(rh: Long?) {
        val currentAddress = chatModel.userAddress.value ?: return
        val currentSettings = currentAddress.addressSettings
        if (currentSettings.autoAccept != null) {
            println("ChatFort: Auto-accept already enabled")
            return
        }
        val newSettings = currentSettings.copy(autoAccept = AutoAccept(acceptIncognito = false))
        val updated = chatController.apiSetUserAddressSettings(rh, newSettings)
        if (updated != null) {
            withContext(Dispatchers.Main) {
                chatModel.userAddress.value = updated
            }
            println("ChatFort: Auto-accept enabled successfully")
        } else {
            println("ChatFort: Failed to enable auto-accept")
        }
    }
}
