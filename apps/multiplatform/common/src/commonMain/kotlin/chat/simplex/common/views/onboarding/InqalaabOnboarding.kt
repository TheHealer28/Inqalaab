package chat.simplex.common.views.onboarding

import SectionBottomSpacer
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chat.simplex.common.model.ChatController.appPrefs
import chat.simplex.common.platform.ColumnWithScrollBarNoAppBar
import chat.simplex.common.ui.theme.*
import chat.simplex.common.views.helpers.*
import chat.simplex.res.MR
import dev.icerock.moko.resources.compose.painterResource

// Screen 1: Why Inqalaab Exists
@Composable
fun InqalaabMissionScreen() {
    ColumnWithScrollBarNoAppBar(
        Modifier.fillMaxSize().padding(horizontal = DEFAULT_PADDING)
    ) {
        Spacer(Modifier.height(40.dp))

        Icon(
            painterResource(MR.images.ic_flag_filled),
            contentDescription = null,
            modifier = Modifier.size(72.dp).align(Alignment.CenterHorizontally),
            tint = MaterialTheme.colors.primary
        )

        Spacer(Modifier.height(24.dp))

        Text(
            generalGetString(MR.strings.inq_why_exists),
            style = MaterialTheme.typography.h4.copy(fontWeight = FontWeight.Bold),
            color = MaterialTheme.colors.onBackground,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(8.dp))

        Text(
            generalGetString(MR.strings.inq_built_for_danger),
            style = MaterialTheme.typography.body1,
            color = MaterialTheme.colors.secondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(32.dp))

        ValueCard(
            painterResource(MR.images.ic_warning_filled),
            generalGetString(MR.strings.inq_shutdowns_rising),
            generalGetString(MR.strings.inq_shutdowns_desc)
        )
        Spacer(Modifier.height(12.dp))

        ValueCard(
            painterResource(MR.images.ic_shield),
            generalGetString(MR.strings.inq_surveillance),
            generalGetString(MR.strings.inq_surveillance_desc)
        )
        Spacer(Modifier.height(12.dp))

        ValueCard(
            painterResource(MR.images.ic_wifi_tethering),
            generalGetString(MR.strings.inq_offline_first),
            generalGetString(MR.strings.inq_offline_first_desc)
        )
        Spacer(Modifier.height(12.dp))

        ValueCard(
            painterResource(MR.images.ic_lock),
            generalGetString(MR.strings.inq_no_identity),
            generalGetString(MR.strings.inq_no_identity_desc)
        )

        Spacer(Modifier.weight(1f))

        OnboardingActionButton(
            modifier = Modifier.padding(bottom = 8.dp).fillMaxWidth(),
            labelId = MR.strings.setup_protection_continue,
            onboarding = OnboardingStage.Step0_5_SecurityPledgeScreen,
            onclick = null
        )

        SectionBottomSpacer()
    }
}

// Screen 2: Security Pledge / Threat Model
@Composable
fun InqalaabSecurityPledgeScreen() {
    ColumnWithScrollBarNoAppBar(
        Modifier.fillMaxSize().padding(horizontal = DEFAULT_PADDING)
    ) {
        Spacer(Modifier.height(40.dp))

        Icon(
            painterResource(MR.images.ic_shield),
            contentDescription = null,
            modifier = Modifier.size(72.dp).align(Alignment.CenterHorizontally),
            tint = SimplexGreen
        )

        Spacer(Modifier.height(24.dp))

        Text(
            generalGetString(MR.strings.inq_security_pledge),
            style = MaterialTheme.typography.h4.copy(fontWeight = FontWeight.Bold),
            color = MaterialTheme.colors.onBackground,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(8.dp))

        Text(
            generalGetString(MR.strings.inq_we_promise),
            style = MaterialTheme.typography.body1,
            color = MaterialTheme.colors.secondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(32.dp))

        PledgeItem(1, generalGetString(MR.strings.inq_zero_data), generalGetString(MR.strings.inq_zero_data_desc))
        Spacer(Modifier.height(12.dp))

        PledgeItem(2, generalGetString(MR.strings.inq_no_phone), generalGetString(MR.strings.inq_no_phone_desc))
        Spacer(Modifier.height(12.dp))

        PledgeItem(3, generalGetString(MR.strings.inq_panic_mode), generalGetString(MR.strings.inq_panic_mode_desc))
        Spacer(Modifier.height(12.dp))

        PledgeItem(4, generalGetString(MR.strings.inq_community_servers), generalGetString(MR.strings.inq_community_servers_desc))
        Spacer(Modifier.height(12.dp))

        PledgeItem(5, generalGetString(MR.strings.inq_open_source_pledge), generalGetString(MR.strings.inq_open_source_pledge_desc))

        Spacer(Modifier.weight(1f))

        OnboardingActionButton(
            modifier = Modifier.padding(bottom = 8.dp).fillMaxWidth(),
            labelId = MR.strings.setup_protection_continue,
            onboarding = OnboardingStage.Step0_2_EnableSafety,
            onclick = null
        )

        SectionBottomSpacer()
    }
}

// Screen 3: Enable Safety Features
@Composable
fun InqalaabEnableSafetyScreen() {
    val screenProtection = remember { appPrefs.privacyProtectScreen.state }
    val localFilesEncrypted = remember { appPrefs.privacyEncryptLocalFiles.state }

    ColumnWithScrollBarNoAppBar(
        Modifier.fillMaxSize().padding(horizontal = DEFAULT_PADDING)
    ) {
        Spacer(Modifier.height(40.dp))

        Icon(
            painterResource(MR.images.ic_security),
            contentDescription = null,
            modifier = Modifier.size(72.dp).align(Alignment.CenterHorizontally),
            tint = MaterialTheme.colors.primary
        )

        Spacer(Modifier.height(24.dp))

        Text(
            generalGetString(MR.strings.inq_enable_safety),
            style = MaterialTheme.typography.h4.copy(fontWeight = FontWeight.Bold),
            color = MaterialTheme.colors.onBackground,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(8.dp))

        Text(
            generalGetString(MR.strings.inq_protect_seized),
            style = MaterialTheme.typography.body1,
            color = MaterialTheme.colors.secondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(32.dp))

        // Screen Protection toggle
        SafetyToggleCard(
            icon = painterResource(MR.images.ic_visibility_off),
            title = generalGetString(MR.strings.inq_screen_prot_onboard),
            description = generalGetString(MR.strings.inq_screen_prot_onboard_desc),
            checked = screenProtection.value,
            onCheckedChange = { appPrefs.privacyProtectScreen.set(it) }
        )
        Spacer(Modifier.height(12.dp))

        // Encrypt local files toggle
        SafetyToggleCard(
            icon = painterResource(MR.images.ic_lock),
            title = generalGetString(MR.strings.inq_encrypt_files),
            description = generalGetString(MR.strings.inq_encrypt_files_desc),
            checked = localFilesEncrypted.value,
            onCheckedChange = { appPrefs.privacyEncryptLocalFiles.set(it) }
        )
        Spacer(Modifier.height(12.dp))

        // Info card about panic mode (set up later)
        ValueCard(
            painterResource(MR.images.ic_delete_forever),
            generalGetString(MR.strings.inq_panic_decoy),
            generalGetString(MR.strings.inq_panic_decoy_desc)
        )

        Spacer(Modifier.weight(1f))

        OnboardingActionButton(
            modifier = Modifier.padding(bottom = 8.dp).fillMaxWidth(),
            labelId = MR.strings.setup_protection_continue,
            onboarding = OnboardingStage.Step0_3_NearbyExplainer,
            onclick = null
        )

        SectionBottomSpacer()
    }
}

// Screen 4: Nearby Mode Explainer
@Composable
fun InqalaabNearbyExplainerScreen() {
    ColumnWithScrollBarNoAppBar(
        Modifier.fillMaxSize().padding(horizontal = DEFAULT_PADDING)
    ) {
        Spacer(Modifier.height(40.dp))

        Icon(
            painterResource(MR.images.ic_wifi_tethering),
            contentDescription = null,
            modifier = Modifier.size(72.dp).align(Alignment.CenterHorizontally),
            tint = MaterialTheme.colors.primary
        )

        Spacer(Modifier.height(24.dp))

        Text(
            generalGetString(MR.strings.inq_nearby_mode),
            style = MaterialTheme.typography.h4.copy(fontWeight = FontWeight.Bold),
            color = MaterialTheme.colors.onBackground,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(8.dp))

        Text(
            generalGetString(MR.strings.inq_comm_without_internet),
            style = MaterialTheme.typography.body1,
            color = MaterialTheme.colors.secondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(32.dp))

        ValueCard(
            painterResource(MR.images.ic_bluetooth),
            generalGetString(MR.strings.nearby_find_people),
            generalGetString(MR.strings.inq_ble_desc)
        )
        Spacer(Modifier.height(12.dp))

        ValueCard(
            painterResource(MR.images.ic_wifi_tethering),
            generalGetString(MR.strings.inq_create_local_room),
            generalGetString(MR.strings.inq_wifi_direct_desc)
        )
        Spacer(Modifier.height(12.dp))

        ValueCard(
            painterResource(MR.images.ic_shield),
            generalGetString(MR.strings.inq_nothing_leaves),
            generalGetString(MR.strings.inq_nothing_leaves_desc)
        )
        Spacer(Modifier.height(12.dp))

        ValueCard(
            painterResource(MR.images.ic_warning),
            generalGetString(MR.strings.inq_when_internet_down),
            generalGetString(MR.strings.inq_when_internet_desc)
        )

        Spacer(Modifier.weight(1f))

        Button(
            onClick = { appPrefs.onboardingStage.set(OnboardingStage.Step2_CreateProfile) },
            modifier = Modifier.padding(bottom = 8.dp).fillMaxWidth(),
            shape = RoundedCornerShape(50),
            contentPadding = PaddingValues(horizontal = DEFAULT_PADDING * 2, vertical = 17.dp),
        ) {
            Text(generalGetString(MR.strings.inq_create_profile), color = Color.White, fontWeight = FontWeight.Medium)
        }

        SectionBottomSpacer()
    }
}

// Reusable composables

@Composable
private fun ValueCard(icon: Painter, title: String, description: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colors.onBackground.copy(alpha = 0.05f))
            .padding(16.dp),
        verticalAlignment = Alignment.Top
    ) {
        Icon(
            icon,
            contentDescription = null,
            modifier = Modifier.size(28.dp),
            tint = MaterialTheme.colors.primary
        )
        Spacer(Modifier.width(12.dp))
        Column {
            Text(
                title,
                style = MaterialTheme.typography.subtitle1.copy(fontWeight = FontWeight.SemiBold),
                color = MaterialTheme.colors.onBackground
            )
            Spacer(Modifier.height(4.dp))
            Text(
                description,
                style = MaterialTheme.typography.body2,
                color = MaterialTheme.colors.secondary,
                fontSize = 13.sp
            )
        }
    }
}

@Composable
private fun PledgeItem(number: Int, title: String, description: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colors.onBackground.copy(alpha = 0.05f))
            .padding(16.dp),
        verticalAlignment = Alignment.Top
    ) {
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(SimplexGreen),
            contentAlignment = Alignment.Center
        ) {
            Text(
                "$number",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp
            )
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(
                title,
                style = MaterialTheme.typography.subtitle1.copy(fontWeight = FontWeight.SemiBold),
                color = MaterialTheme.colors.onBackground
            )
            Spacer(Modifier.height(4.dp))
            Text(
                description,
                style = MaterialTheme.typography.body2,
                color = MaterialTheme.colors.secondary,
                fontSize = 13.sp
            )
        }
    }
}

@Composable
private fun SafetyToggleCard(
    icon: Painter,
    title: String,
    description: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colors.onBackground.copy(alpha = 0.05f))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            icon,
            contentDescription = null,
            modifier = Modifier.size(28.dp),
            tint = if (checked) SimplexGreen else MaterialTheme.colors.secondary
        )
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(
                title,
                style = MaterialTheme.typography.subtitle1.copy(fontWeight = FontWeight.SemiBold),
                color = MaterialTheme.colors.onBackground
            )
            Spacer(Modifier.height(4.dp))
            Text(
                description,
                style = MaterialTheme.typography.body2,
                color = MaterialTheme.colors.secondary,
                fontSize = 13.sp
            )
        }
        Spacer(Modifier.width(8.dp))
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(checkedThumbColor = SimplexGreen)
        )
    }
}
