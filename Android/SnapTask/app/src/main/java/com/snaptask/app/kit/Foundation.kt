package com.snaptask.app

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.State
import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.doubleOrNull
import java.io.File
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.temporal.ChronoUnit
import java.time.temporal.WeekFields
import java.util.Locale
import java.util.UUID

/** The Android counterpart of Swift's `Date`. */
typealias Date = Instant

/** Same shape as `JSONEncoder`/`JSONDecoder` on iOS, so an iOS backup can be read here. */
val AppJson = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
    encodeDefaults = true
    coerceInputValues = true
    isLenient = true
}

private const val REFERENCE_DATE_EPOCH = 978307200L

object DateSerializer : KSerializer<Instant> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("Date", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: Instant) {
        // Whole seconds: the iOS `.iso8601` decoder refuses fractions.
        encoder.encodeString(value.truncatedTo(ChronoUnit.SECONDS).toString())
    }

    override fun deserialize(decoder: Decoder): Instant {
        val json = decoder as? JsonDecoder ?: return Instant.parse(decoder.decodeString())
        val element = json.decodeJsonElement() as JsonPrimitive
        return parseSwiftDate(element)
    }
}

/** ISO text from a backup, or seconds since 2001 from iOS's default date encoding. */
fun parseSwiftDate(element: JsonPrimitive): Instant {
    if (element.isString) return Instant.parse(element.content)
    val seconds = element.doubleOrNull ?: 0.0
    return Instant.ofEpochMilli(((seconds + REFERENCE_DATE_EPOCH) * 1000).toLong())
}

object UUIDSerializer : KSerializer<UUID> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("UUID", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: UUID) = encoder.encodeString(value.uuidString)
    override fun deserialize(decoder: Decoder): UUID = UUID.fromString(decoder.decodeString())
}

val UUID.uuidString: String get() = toString().uppercase(Locale.ROOT)

/** `[Date: V]` as Swift writes it: a flat array alternating keys and values. */
class DateKeyedMapSerializer<V>(private val valueSerializer: KSerializer<V>) : KSerializer<Map<Instant, V>> {
    override val descriptor: SerialDescriptor = kotlinx.serialization.descriptors.buildClassSerialDescriptor("DateKeyedMap")

    override fun serialize(encoder: Encoder, value: Map<Instant, V>) {
        val json = encoder as JsonEncoder
        val items = ArrayList<JsonElement>(value.size * 2)
        for ((key, item) in value) {
            items += JsonPrimitive(key.truncatedTo(ChronoUnit.SECONDS).toString())
            items += json.json.encodeToJsonElement(valueSerializer, item)
        }
        json.encodeJsonElement(JsonArray(items))
    }

    override fun deserialize(decoder: Decoder): Map<Instant, V> {
        val json = decoder as JsonDecoder
        val result = LinkedHashMap<Instant, V>()
        when (val element = json.decodeJsonElement()) {
            is JsonArray -> {
                var index = 0
                while (index + 1 < element.size) {
                    val key = element[index] as JsonPrimitive
                    result[parseSwiftDate(key)] = json.json.decodeFromJsonElement(valueSerializer, element[index + 1])
                    index += 2
                }
            }
            is JsonObject -> for ((key, item) in element) {
                result[parseSwiftDate(JsonPrimitive(key))] = json.json.decodeFromJsonElement(valueSerializer, item)
            }
            else -> Unit
        }
        return result
    }
}

// MARK: - Calendar (same results as Calendar.current on iOS)

val zone: ZoneId get() = ZoneId.systemDefault()
fun now(): Instant = Instant.now()
fun Instant.z(): ZonedDateTime = atZone(zone)
fun LocalDate.instant(): Instant = atStartOfDay(zone).toInstant()

fun Instant.startOfDay(): Instant = z().toLocalDate().instant()
fun Instant.isSameDay(other: Instant): Boolean = z().toLocalDate() == other.z().toLocalDate()
fun Instant.isSameMonth(other: Instant): Boolean = z().let { a -> other.z().let { b -> a.year == b.year && a.monthValue == b.monthValue } }
fun Instant.isSameYear(other: Instant): Boolean = z().year == other.z().year
fun Instant.isToday(): Boolean = isSameDay(now())
fun Instant.addingDays(days: Int): Instant = z().plusDays(days.toLong()).toInstant()
fun Instant.addingWeeks(weeks: Int): Instant = z().plusWeeks(weeks.toLong()).toInstant()
fun Instant.addingMonths(months: Int): Instant = z().plusMonths(months.toLong()).toInstant()
fun Instant.addingYears(years: Int): Instant = z().plusYears(years.toLong()).toInstant()
fun Instant.addingMinutes(minutes: Int): Instant = plusSeconds(minutes * 60L)
fun Instant.addingHours(hours: Int): Instant = plusSeconds(hours * 3600L)

/** 1 = Sunday … 7 = Saturday, like `Calendar.component(.weekday)`. */
val Instant.weekday: Int get() = z().dayOfWeek.value % 7 + 1
val Instant.dayOfMonth: Int get() = z().dayOfMonth
val Instant.month: Int get() = z().monthValue
val Instant.yearNumber: Int get() = z().year
val Instant.hour: Int get() = z().hour
val Instant.minute: Int get() = z().minute
val Instant.daysInMonth: Int get() = z().toLocalDate().lengthOfMonth()
val Instant.weekOfMonth: Int get() = z().get(WeekFields.of(Locale.getDefault()).weekOfMonth())
val Instant.weekOfYear: Int get() = z().get(WeekFields.of(Locale.getDefault()).weekOfWeekBasedYear())

val firstDayOfWeek: DayOfWeek get() = WeekFields.of(Locale.getDefault()).firstDayOfWeek
/** Weekday number of the first day of the week: 1 = Sunday, 2 = Monday. */
val firstWeekdayNumber: Int get() = firstDayOfWeek.value % 7 + 1

fun Instant.startOfWeek(): Instant {
    val date = z().toLocalDate()
    val offset = ((date.dayOfWeek.value - firstDayOfWeek.value) + 7) % 7
    return date.minusDays(offset.toLong()).instant()
}
fun Instant.startOfMonth(): Instant = z().toLocalDate().withDayOfMonth(1).instant()
fun Instant.startOfYear(): Instant = z().toLocalDate().withDayOfYear(1).instant()
fun Instant.endOfMonth(): Instant = startOfMonth().addingMonths(1).addingDays(-1)
fun Instant.endOfYear(): Instant = startOfYear().addingYears(1).addingDays(-1)

fun Instant.withTime(hour: Int, minute: Int, second: Int = 0): Instant =
    z().withHour(hour).withMinute(minute).withSecond(second).withNano(0).toInstant()
fun Instant.withDayOfMonth(day: Int): Instant = z().withDayOfMonth(day).toInstant()

fun daysBetween(from: Instant, to: Instant): Long = ChronoUnit.DAYS.between(from.z().toLocalDate(), to.z().toLocalDate())
fun weeksBetween(from: Instant, to: Instant): Long = ChronoUnit.WEEKS.between(from.z().toLocalDate(), to.z().toLocalDate())
fun monthsBetween(from: Instant, to: Instant): Long = ChronoUnit.MONTHS.between(from.z().toLocalDate(), to.z().toLocalDate())
fun yearsBetween(from: Instant, to: Instant): Long = ChronoUnit.YEARS.between(from.z().toLocalDate(), to.z().toLocalDate())

val Instant.epochSeconds: Double get() = toEpochMilli() / 1000.0
fun Instant.timeIntervalSince(other: Instant): Double = (toEpochMilli() - other.toEpochMilli()) / 1000.0
/** Rounded down to the second, as iCloud stores dates. */
fun Instant.wholeSecond(): Instant = truncatedTo(ChronoUnit.SECONDS)
val distantPast: Instant = Instant.parse("0001-01-01T00:00:00Z")

/** The language picked in the app, for date texts as well as for strings. */
val appLocale: Locale get() = Locale.forLanguageTag(LanguageManager.actualLanguageCode)

fun Instant.format(pattern: String, locale: Locale = appLocale): String =
    DateTimeFormatter.ofPattern(pattern, locale).format(z())

/** `DateFormatter` with `dateStyle` only. */
fun Instant.dateStyle(style: FormatStyle): String =
    DateTimeFormatter.ofLocalizedDate(style).withLocale(appLocale).format(z())

/** Skeleton-based text, like `Text(date, format: .dateTime.month().day())`. */
fun Instant.skeleton(skeleton: String): String {
    val pattern = android.text.format.DateFormat.getBestDateTimePattern(appLocale, skeleton)
    return DateTimeFormatter.ofPattern(pattern, appLocale).format(z())
}

/** Clock time following the 12/24h preference. */
fun Instant.timeText(): String = TimeFormatPreference.format(this)

// MARK: - App context and preferences (`UserDefaults`)

@SuppressLint("StaticFieldLeak")
object App {
    lateinit var context: Context
    val prefs: SharedPreferences by lazy { context.getSharedPreferences("snaptask", Context.MODE_PRIVATE) }
    val filesDir: File get() = context.filesDir
}

/** The Android `UserDefaults`, with the same keys as on iOS. */
object Defaults {
    private val prefs get() = App.prefs
    fun contains(key: String) = prefs.contains(key)
    fun bool(key: String, default: Boolean = false) = prefs.getBoolean(key, default)
    fun int(key: String, default: Int = 0) = prefs.getInt(key, default)
    fun double(key: String, default: Double = 0.0): Double =
        if (prefs.contains(key)) java.lang.Double.longBitsToDouble(prefs.getLong(key, 0)) else default
    fun string(key: String): String? = prefs.getString(key, null)
    fun date(key: String): Instant? = if (prefs.contains(key)) Instant.ofEpochMilli(prefs.getLong(key, 0)) else null
    fun set(key: String, value: Boolean) = prefs.edit().putBoolean(key, value).apply()
    fun set(key: String, value: Int) = prefs.edit().putInt(key, value).apply()
    fun set(key: String, value: Double) = prefs.edit().putLong(key, java.lang.Double.doubleToRawLongBits(value)).apply()
    fun set(key: String, value: String?) = prefs.edit().apply { if (value == null) remove(key) else putString(key, value) }.apply()
    fun set(key: String, value: Instant) = prefs.edit().putLong(key, value.toEpochMilli()).apply()
    fun remove(key: String) = prefs.edit().remove(key).apply()
}

/** JSON values kept in private files: the `UserDefaults.data(forKey:)` of the iOS app. */
object Store {
    private val dir: File get() = File(App.filesDir, "store").apply { mkdirs() }
    private fun file(key: String) = File(dir, "$key.json")

    fun readText(key: String): String? = file(key).takeIf { it.exists() }?.readText()

    fun writeText(key: String, text: String) {
        val target = file(key)
        val temp = File(dir, "$key.tmp")
        temp.writeText(text)
        if (!temp.renameTo(target)) {
            target.delete()
            temp.renameTo(target)
        }
    }

    fun remove(key: String) { file(key).delete() }

    fun <T> load(key: String, serializer: KSerializer<T>): T? = runCatching {
        readText(key)?.let { AppJson.decodeFromString(serializer, it) }
    }.getOrNull()

    fun <T> save(key: String, serializer: KSerializer<T>, value: T) {
        writeText(key, AppJson.encodeToString(serializer, value))
    }
}

// MARK: - @AppStorage

@Composable
fun appStorage(key: String, default: Boolean): MutableState<Boolean> = remember(key) {
    PrefState(mutableStateOf(Defaults.bool(key, default))) { Defaults.set(key, it) }
}

@Composable
fun appStorage(key: String, default: Int): MutableState<Int> = remember(key) {
    PrefState(mutableStateOf(Defaults.int(key, default))) { Defaults.set(key, it) }
}

@Composable
fun appStorage(key: String, default: Double): MutableState<Double> = remember(key) {
    PrefState(mutableStateOf(Defaults.double(key, default))) { Defaults.set(key, it) }
}

@Composable
fun appStorage(key: String, default: String): MutableState<String> = remember(key) {
    PrefState(mutableStateOf(Defaults.string(key) ?: default)) { Defaults.set(key, it) }
}

private class PrefState<T>(private val state: MutableState<T>, private val save: (T) -> Unit) : MutableState<T> {
    override var value: T
        get() = state.value
        set(newValue) {
            state.value = newValue
            save(newValue)
        }
    override fun component1(): T = value
    override fun component2(): (T) -> Unit = { value = it }
}

fun <T> Iterable<T>.sumOfDoubleSafe(selector: (T) -> Double): Double = fold(0.0) { total, item -> total + selector(item) }

val stringSerializer = String.serializer()
