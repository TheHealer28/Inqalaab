package chat.simplex.app

import chat.simplex.common.model.*
import chat.simplex.common.model.ChatController.getUserServers
import chat.simplex.common.model.ChatController.setUserServers
import chat.simplex.common.platform.*
import chat.simplex.common.views.helpers.*
import kotlinx.coroutines.*

object InqalaabServers {
    private const val INQALAAB_SMP = "smp://4CfWwei1oOFAhmfUkmpsrSRELYLCvKBPgQIJlOT5z8I=@smp.suchkitalash.info"
    private const val INQALAAB_XFTP = "xftp://fX3KznAU-_QoLQzaMs9w0gKFySj0nleLTb0T2ysEPJI=@xftp.suchkitalash.info"
    private const val INQALAAB_HOST = "suchkitalash.info"
    private const val PREFS_NAME = "inqalaab_prefs"
    private const val KEY_SERVERS_CONFIGURED = "servers_configured"
    private const val KEY_CONTACTS_CLEANED = "contacts_cleaned"
    private const val KEY_ADDRESS_CREATED = "address_created"

    private val PRESET_CONTACTS_TO_DELETE = setOf("SimpleX Status", "Ask SimpleX Team")

    fun configureIfNeeded() {
        val prefs = androidAppContext.getSharedPreferences(PREFS_NAME, 0)

        val serversConfigured = prefs.getBoolean(KEY_SERVERS_CONFIGURED, false)
        val contactsCleaned = prefs.getBoolean(KEY_CONTACTS_CLEANED, false)
        val addressCreated = prefs.getBoolean(KEY_ADDRESS_CREATED, false)

        if (serversConfigured && contactsCleaned && addressCreated) {
            println("Inqalaab: Already fully configured, skipping")
            return
        }

        withBGApi {
            try {
                if (chatModel.chatRunning.value != true) {
                    println("Inqalaab: Chat not running yet, will retry later")
                    return@withBGApi
                }

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

        val currentServers = getUserServers(rh)
        if (currentServers == null) {
            println("Inqalaab: getUserServers returned null")
            return
        }

        // Check if already done
        val alreadyDone = currentServers.flatMap { it.smpServers }.any {
            it.enabled && it.server.contains(INQALAAB_HOST)
        }
        if (alreadyDone) {
            println("Inqalaab: Servers already configured")
            prefs.edit().putBoolean(KEY_SERVERS_CONFIGURED, true).apply()
            return
        }

        println("Inqalaab: Found ${currentServers.size} server groups")

        // Repurpose ONE existing SMP and ONE existing XFTP record (UPDATE, not INSERT)
        var smpDone = false
        var xftpDone = false

        val modified = currentServers.map { group ->
            val newSmp = group.smpServers.map { srv ->
                if (!smpDone && srv.serverId != null) {
                    smpDone = true
                    println("Inqalaab: Repurposing SMP id=${srv.serverId}")
                    srv.copy(server = INQALAAB_SMP, preset = false, tested = null, enabled = true)
                } else {
                    srv.copy(enabled = false)
                }
            }
            val newXftp = group.xftpServers.map { srv ->
                if (!xftpDone && srv.serverId != null) {
                    xftpDone = true
                    println("Inqalaab: Repurposing XFTP id=${srv.serverId}")
                    srv.copy(server = INQALAAB_XFTP, preset = false, tested = null, enabled = true)
                } else {
                    srv.copy(enabled = false)
                }
            }
            UserOperatorServers(operator = group.operator, smpServers = newSmp, xftpServers = newXftp)
        }

        if (!smpDone || !xftpDone) {
            println("Inqalaab: ERROR - No donor servers (smp=$smpDone xftp=$xftpDone)")
            return
        }

        println("Inqalaab: Calling setUserServers...")
        val success = setUserServers(rh, modified)
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

            prefs.edit().putBoolean(KEY_SERVERS_CONFIGURED, true).apply()
            println("Inqalaab: Server replacement complete")
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
