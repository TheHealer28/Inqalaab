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
    // Obfuscated fallback server addresses (Base64 encoded)
    private val FALLBACK_SMP = listOf(
        "c21wOi8vNENmV3dlaTFvT0ZBaG1mVWttcHNyU1JFTFlMQ3ZLQlBnUUlKbE9UNXo4ST1Ac21wLnN1Y2hraXRhbGFzaC5pbmZv",
        "c21wOi8vaktrS21tNjRHZjZqV2EydW5JNXQwUXVkQ29UWnh4RnA4bzI4ZkRaV1pVND1Ac21wMS5pbnFhbGFhYi5jaGF0",
        "c21wOi8vSmZkalV2TVJha3l6SDd5enVjVExveEtzWS1FZnZBMGJNVGo3a1pHM1N6cz1Ac21wMi5pbnFhbGFhYi5jaGF0",
        "c21wOi8vM1hFQ2FOT2FxbExjX2hQeXJXU213NHJ4clVHeEFMZjVxUVZxamF6LUQtWT1Ac21wMy5pbnFhbGFhYi5jaGF0"
    )
    private val FALLBACK_XFTP = listOf(
        "eGZ0cDovL1J6Z3pQanllbDkxWUxsaXNjVUdYQ2pSZUcxa1lWXzVfbzBwdk9mWkFfNHM9QHhmdHAuc3VjaGtpdGFsYXNoLmluZm86NTIzMw==",
        "eGZ0cDovL29Pdnk2azk5TFQ1ZHlTZUlPbXc1LUc0RkRaNW8zU1NwVndtNllteUJzWkk9QHhmdHAxLmlucWFsYWFiLmNoYXQ=",
        "eGZ0cDovL0FpazYwV2ptVkZMV09LMmRLWUVqRWJmZFVXeHV5VXBBcC1WTzNGY09FNXc9QHhmdHAyLmlucWFsYWFiLmNoYXQ6NTIzMw==",
        "eGZ0cDovL3JRRE1oT3g4d1V2N082SjN2aHQyVzNITXNVWGJxdjBIWlBRYjNDZTAyc3M9QHhmdHAzLmlucWFsYWFiLmNoYXQ6NTIzMw=="
    )

    private val INQALAAB_HOSTS = setOf("suchkitalash.info", "inqalaab.chat")
    // Bump this version whenever server addresses change to force reconfiguration
    private const val SERVER_CONFIG_VERSION = 5
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
                println("Inqalaab: Firebase fetch failed, using fallback")
                return null
            }

            val smpString = remoteConfig.getString("smp_servers")
            val xftpString = remoteConfig.getString("xftp_servers")

            if (smpString.isBlank() || xftpString.isBlank()) {
                println("Inqalaab: Firebase config empty, using fallback")
                return null
            }

            val smpList = smpString.split(",").map { it.trim() }.filter { it.startsWith("smp://") }
            val xftpList = xftpString.split(",").map { it.trim() }.filter { it.startsWith("xftp://") }

            if (smpList.isEmpty() || xftpList.isEmpty()) {
                println("Inqalaab: Firebase config invalid, using fallback")
                return null
            }

            println("Inqalaab: Got ${smpList.size} SMP and ${xftpList.size} XFTP servers from Firebase")
            Pair(smpList, xftpList)
        } catch (e: Exception) {
            println("Inqalaab: Firebase error: ${e.message}, using fallback")
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
            println("Inqalaab: Server config version changed ($savedVersion -> $SERVER_CONFIG_VERSION), reconfiguring...")
            serversConfigured = false
            prefs.edit().putBoolean(KEY_SERVERS_CONFIGURED, false).apply()
        }

        if (serversConfigured && contactsCleaned && addressCreated) {
            println("Inqalaab: Already fully configured, skipping")
            return
        }

        withBGApi {
            try {
                // Wait for chat to be running (up to 30 seconds)
                var waited = 0
                while (chatModel.chatRunning.value != true && waited < 30) {
                    println("Inqalaab: Chat not running yet, waiting... (${waited}s)")
                    delay(1000)
                    waited++
                }

                if (chatModel.chatRunning.value != true) {
                    println("Inqalaab: Chat still not running after ${waited}s, giving up")
                    return@withBGApi
                }

                println("Inqalaab: Chat is running, configuring...")
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
                println("Inqalaab: Exception: ${e.message}")
                e.printStackTrace()
            }
        }
    }

    private suspend fun replaceServers(rh: Long?, prefs: android.content.SharedPreferences) {
        println("Inqalaab: Starting server replacement...")

        // Try Firebase first, fall back to hardcoded obfuscated servers
        val (smpServers, xftpServers) = fetchServersFromFirebase()
            ?: Pair(FALLBACK_SMP.map { decode(it) }, FALLBACK_XFTP.map { decode(it) })

        val currentServers = getUserServers(rh)
        if (currentServers == null) {
            println("Inqalaab: getUserServers returned null")
            return
        }

        println("Inqalaab: Found ${currentServers.size} server groups")

        var smpIndex = 0
        var xftpIndex = 0

        val modified = currentServers.map { group ->
            // Repurpose existing SMP records
            val newSmp = group.smpServers.map { srv ->
                if (smpIndex < smpServers.size && srv.serverId != null) {
                    val serverUrl = smpServers[smpIndex]
                    smpIndex++
                    println("Inqalaab: Repurposing SMP id=${srv.serverId} -> $serverUrl")
                    srv.copy(server = serverUrl, preset = false, tested = null, enabled = true)
                } else {
                    srv.copy(enabled = false)
                }
            }
            // Repurpose existing XFTP records
            val newXftp = group.xftpServers.map { srv ->
                if (xftpIndex < xftpServers.size && srv.serverId != null) {
                    val serverUrl = xftpServers[xftpIndex]
                    xftpIndex++
                    println("Inqalaab: Repurposing XFTP id=${srv.serverId} -> $serverUrl")
                    srv.copy(server = serverUrl, preset = false, tested = null, enabled = true)
                } else {
                    srv.copy(enabled = false)
                }
            }
            UserOperatorServers(operator = group.operator, smpServers = newSmp, xftpServers = newXftp)
        }

        // Add any remaining servers that couldn't be repurposed (not enough donor records)
        val finalModified = if (smpIndex < smpServers.size || xftpIndex < xftpServers.size) {
            val firstGroup = modified.first()
            val extraSmp = smpServers.drop(smpIndex).map { url ->
                println("Inqalaab: Adding new SMP server: $url")
                UserServer(remoteHostId = rh, serverId = null, server = url, preset = false, tested = null, enabled = true, deleted = false)
            }
            val extraXftp = xftpServers.drop(xftpIndex).map { url ->
                println("Inqalaab: Adding new XFTP server: $url")
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

        if (smpIndex == 0 || xftpIndex == 0) {
            println("Inqalaab: ERROR - No donor servers (smp=$smpIndex xftp=$xftpIndex)")
            return
        }

        println("Inqalaab: Calling setUserServers...")
        val success = setUserServers(rh, finalModified)
        println("Inqalaab: setUserServers result: $success")

        if (success) {
            // Disable all operators (hides SimpleX + Flux from UI)
            val conditions = chatModel.conditions.value
            val disabledOps = conditions.serverOperators.map { it.copy(enabled = false) }
            println("Inqalaab: Disabling ${disabledOps.size} operators...")
            val result = chatController.setServerOperators(rh = rh, operators = disabledOps)
            if (result != null) {
                chatModel.conditions.value = result
                println("Inqalaab: Operators disabled")
            }

            // Verify
            val verify = getUserServers(rh)
            if (verify != null) {
                val activeSmp = verify.flatMap { it.smpServers }.filter { it.enabled }
                val activeXftp = verify.flatMap { it.xftpServers }.filter { it.enabled }
                println("Inqalaab: Servers: ${activeSmp.size} SMP, ${activeXftp.size} XFTP active")
            }

            prefs.edit()
                .putBoolean(KEY_SERVERS_CONFIGURED, true)
                .putInt(KEY_SERVER_VERSION, SERVER_CONFIG_VERSION)
                .apply()
            println("Inqalaab: Server replacement complete (version $SERVER_CONFIG_VERSION)")
        }
    }

    private suspend fun deletePresetContacts(rh: Long?, prefs: android.content.SharedPreferences) {
        println("Inqalaab: Cleaning preset contacts...")

        val chats = chatModel.chats.value
        var deleted = 0
        var found = 0

        for (chat in chats) {
            val cInfo = chat.chatInfo
            if (cInfo is ChatInfo.Direct && cInfo.displayName in PRESET_CONTACTS_TO_DELETE) {
                found++
                println("Inqalaab: Deleting contact: ${cInfo.displayName} (id=${cInfo.apiId})")
                val success = chatController.apiDeleteChat(
                    rh = chat.remoteHostId,
                    type = ChatType.Direct,
                    id = cInfo.apiId
                )
                if (success) {
                    withContext(Dispatchers.Main) {
                        chatModel.chatsContext.removeChat(chat.remoteHostId, cInfo.id)
                    }
                    println("Inqalaab: Deleted ${cInfo.displayName}")
                    deleted++
                } else {
                    println("Inqalaab: Failed to delete ${cInfo.displayName}")
                }
            }
        }

        println("Inqalaab: Found $found preset contacts, deleted $deleted")
        // Only mark done if we found and deleted them, OR if the chat list is already empty
        if (found == deleted && (found > 0 || chats.isEmpty())) {
            prefs.edit().putBoolean(KEY_CONTACTS_CLEANED, true).apply()
            println("Inqalaab: Contacts cleanup marked complete")
        } else {
            println("Inqalaab: Contacts cleanup incomplete, will retry next launch")
        }
    }

    private suspend fun createUserAddress(rh: Long?, prefs: android.content.SharedPreferences) {
        // Check if address already exists
        if (chatModel.userAddress.value != null) {
            // Ensure auto-accept is enabled on existing address
            enableAutoAccept(rh)
            println("Inqalaab: User address already exists")
            prefs.edit().putBoolean(KEY_ADDRESS_CREATED, true).apply()
            return
        }

        println("Inqalaab: Creating user address...")
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
            println("Inqalaab: User address created with auto-accept enabled")
            prefs.edit().putBoolean(KEY_ADDRESS_CREATED, true).apply()
        } else {
            println("Inqalaab: Failed to create user address")
        }
    }

    private suspend fun enableAutoAccept(rh: Long?) {
        val currentAddress = chatModel.userAddress.value ?: return
        val currentSettings = currentAddress.addressSettings
        if (currentSettings.autoAccept != null) {
            println("Inqalaab: Auto-accept already enabled")
            return
        }
        val newSettings = currentSettings.copy(autoAccept = AutoAccept(acceptIncognito = false))
        val updated = chatController.apiSetUserAddressSettings(rh, newSettings)
        if (updated != null) {
            withContext(Dispatchers.Main) {
                chatModel.userAddress.value = updated
            }
            println("Inqalaab: Auto-accept enabled successfully")
        } else {
            println("Inqalaab: Failed to enable auto-accept")
        }
    }
}
