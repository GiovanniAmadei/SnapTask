package com.snaptask.app.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.*
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/**
 * Icon picker screen matching iOS IconPickerView.
 * Displays icons organized by category in a grid layout.
 */
@Composable
fun IconPickerScreen(
    selectedIcon: String,
    onSelectIcon: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    data class IconCategory(
        val title: String,
        val icons: List<String>,
    )

    val categories = listOf(
        IconCategory("General", listOf(
            "circle", "check_circle", "flag", "bookmark", "label",
            "star", "auto_awesome", "workspace_premium",
        )),
        IconCategory("Time & Planning", listOf(
            "notifications", "alarm", "calendar_today", "schedule",
        )),
        IconCategory("Study & Work", listOf(
            "menu_book", "auto_stories", "school",
            "work", "business", "edit", "assignment",
            "list", "checklist", "note",
        )),
        IconCategory("Energy & Nature", listOf(
            "bolt", "local_fire_department", "water_drop", "eco", "lightbulb",
        )),
        IconCategory("Sport & Wellbeing", listOf(
            "fitness_center", "directions_run", "directions_bike", "sports",
            "favorite", "medical_services", "local_hospital", "medication",
        )),
        IconCategory("Food & Drink", listOf(
            "coffee", "restaurant", "fastfood",
        )),
        IconCategory("Home & Security", listOf(
            "home", "bed", "dark_mode", "hotel",
            "vpn_key", "lock",
        )),
        IconCategory("Travel & Places", listOf(
            "directions_car", "directions_bus", "tram", "flight", "directions_boat",
            "public", "map", "place",
        )),
        IconCategory("Shopping & Money", listOf(
            "shopping_cart", "shopping_bag", "credit_card", "payments", "receipt",
            "card_giftcard", "celebration",
        )),
        IconCategory("Creativity & Media", listOf(
            "psychology", "brush",
            "music_note", "headphones", "tv", "photo_camera",
            "sports_esports", "casino",
        )),
        IconCategory("Communication", listOf(
            "phone", "videocam",
            "chat", "forum",
            "email", "send",
        )),
        IconCategory("Weather", listOf(
            "wb_sunny", "cloud", "partly_cloudy_day",
            "grain", "ac_unit",
            "air", "umbrella",
        )),
        IconCategory("Animals", listOf(
            "pets", "bug_report", "cruelty_free", "cruelty_free", "flutter_dash", "set_meal",
        )),
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .padding(top = 8.dp),
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Choose Icon",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) { Text("Done") }
        }

        Spacer(modifier = Modifier.height(16.dp))

        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            items(categories) { category ->
                Column {
                    Text(
                        category.title,
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                        modifier = Modifier.padding(bottom = 8.dp),
                    )

                    // Icons grid (4 columns)
                    val rows = category.icons.chunked(4)
                    rows.forEach { row ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            row.forEach { iconName ->
                                val isSelected = iconName == selectedIcon
                                val containerColor = if (isSelected) {
                                    MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)
                                } else {
                                    MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                                }
                                val borderColor = if (isSelected) {
                                    MaterialTheme.colorScheme.primary
                                } else {
                                    MaterialTheme.colorScheme.outlineVariant
                                }

                                Box(
                                    modifier = Modifier
                                        .size(60.dp)
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(containerColor)
                                        .border(
                                            width = if (isSelected) 2.dp else 1.dp,
                                            color = borderColor,
                                            shape = RoundedCornerShape(12.dp),
                                        )
                                        .clickable { onSelectIcon(iconName) },
                                    contentAlignment = Alignment.Center,
                                ) {
                                    // Map icon names to Material icons
                                    val icon = mapIconName(iconName)
                                    Icon(
                                        imageVector = icon,
                                        contentDescription = iconName,
                                        tint = MaterialTheme.colorScheme.onSurface,
                                    )
                                }
                            }
                            // Fill remaining cells
                            repeat(4 - row.size) {
                                Spacer(modifier = Modifier.size(60.dp))
                            }
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                    }
                }
            }

            item { Spacer(modifier = Modifier.height(32.dp)) }
        }
    }
}

/** Maps icon name strings to Material icons. */
@Composable
private fun mapIconName(name: String): androidx.compose.ui.graphics.vector.ImageVector {
    return when (name) {
        "circle" -> Icons.Filled.Circle
        "check_circle" -> Icons.Filled.CheckCircle
        "flag" -> Icons.Filled.Flag
        "bookmark" -> Icons.Filled.Bookmark
        "label" -> Icons.AutoMirrored.Filled.Label
        "star" -> Icons.Filled.Star
        "auto_awesome" -> Icons.Filled.AutoAwesome
        "workspace_premium" -> Icons.Filled.WorkspacePremium
        "notifications" -> Icons.Filled.Notifications
        "alarm" -> Icons.Filled.Alarm
        "calendar_today" -> Icons.Filled.CalendarToday
        "schedule" -> Icons.Filled.Schedule
        "menu_book" -> Icons.AutoMirrored.Filled.MenuBook
        "auto_stories" -> Icons.Filled.AutoStories
        "school" -> Icons.Filled.School
        "work" -> Icons.Filled.Work
        "business" -> Icons.Filled.Business
        "edit" -> Icons.Filled.Edit
        "assignment" -> Icons.AutoMirrored.Filled.Assignment
        "list" -> Icons.AutoMirrored.Filled.List
        "checklist" -> Icons.Filled.Checklist
        "note" -> Icons.AutoMirrored.Filled.Note
        "bolt" -> Icons.Filled.Bolt
        "local_fire_department" -> Icons.Filled.LocalFireDepartment
        "water_drop" -> Icons.Filled.WaterDrop
        "eco" -> Icons.Filled.Eco
        "lightbulb" -> Icons.Filled.Lightbulb
        "fitness_center" -> Icons.Filled.FitnessCenter
        "directions_run" -> Icons.AutoMirrored.Filled.DirectionsRun
        "directions_bike" -> Icons.AutoMirrored.Filled.DirectionsBike
        "sports" -> Icons.Filled.Sports
        "favorite" -> Icons.Filled.Favorite
        "medical_services" -> Icons.Filled.MedicalServices
        "local_hospital" -> Icons.Filled.LocalHospital
        "medication" -> Icons.Filled.Medication
        "coffee" -> Icons.Filled.Coffee
        "restaurant" -> Icons.Filled.Restaurant
        "fastfood" -> Icons.Filled.Fastfood
        "home" -> Icons.Filled.Home
        "bed" -> Icons.Filled.Bed
        "dark_mode" -> Icons.Filled.DarkMode
        "hotel" -> Icons.Filled.Hotel
        "vpn_key" -> Icons.Filled.VpnKey
        "lock" -> Icons.Filled.Lock
        "directions_car" -> Icons.Filled.DirectionsCar
        "directions_bus" -> Icons.Filled.DirectionsBus
        "tram" -> Icons.Filled.Tram
        "flight" -> Icons.Filled.Flight
        "directions_boat" -> Icons.Filled.DirectionsBoat
        "public" -> Icons.Filled.Public
        "map" -> Icons.Filled.Map
        "place" -> Icons.Filled.Place
        "shopping_cart" -> Icons.Filled.ShoppingCart
        "shopping_bag" -> Icons.Filled.ShoppingBag
        "credit_card" -> Icons.Filled.CreditCard
        "payments" -> Icons.Filled.Payments
        "receipt" -> Icons.Filled.Receipt
        "card_giftcard" -> Icons.Filled.CardGiftcard
        "celebration" -> Icons.Filled.Celebration
        "psychology" -> Icons.Filled.Psychology
        "brush" -> Icons.Filled.Brush
        "music_note" -> Icons.Filled.MusicNote
        "headphones" -> Icons.Filled.Headphones
        "tv" -> Icons.Filled.Tv
        "photo_camera" -> Icons.Filled.PhotoCamera
        "sports_esports" -> Icons.Filled.SportsEsports
        "casino" -> Icons.Filled.Casino
        "phone" -> Icons.Filled.Phone
        "videocam" -> Icons.Filled.Videocam
        "chat" -> Icons.AutoMirrored.Filled.Chat
        "forum" -> Icons.Filled.Forum
        "email" -> Icons.Filled.Email
        "send" -> Icons.AutoMirrored.Filled.Send
        "wb_sunny" -> Icons.Filled.WbSunny
        "cloud" -> Icons.Filled.Cloud
        "partly_cloudy_day" -> Icons.Filled.Cloud
        "grain" -> Icons.Filled.Grain
        "ac_unit" -> Icons.Filled.AcUnit
        "air" -> Icons.Filled.Air
        "umbrella" -> Icons.Filled.Umbrella
        "pets" -> Icons.Filled.Pets
        "bug_report" -> Icons.Filled.BugReport
        "cruelty_free" -> Icons.Filled.CrueltyFree
        "flutter_dash" -> Icons.Filled.FlutterDash
        "set_meal" -> Icons.Filled.SetMeal
        else -> Icons.Filled.Circle
    }
}
