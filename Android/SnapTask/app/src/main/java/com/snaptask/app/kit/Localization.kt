package com.snaptask.app

/**
 * The iOS `Localizable.strings` files are bundled as they are (assets/i18n), so all 7 languages
 * and every key match the iPhone app.
 */
object Strings {
    private val cache = HashMap<String, Map<String, String>>()

    fun table(language: String): Map<String, String> = cache.getOrPut(language) {
        val text = runCatching {
            App.context.assets.open("i18n/$language.strings").bufferedReader().use { it.readText() }
        }.getOrDefault("")
        parse(text)
    }

    fun parse(text: String): Map<String, String> {
        val result = HashMap<String, String>(4096)
        var index = 0
        val length = text.length
        fun skipBlanksAndComments() {
            while (index < length) {
                val char = text[index]
                when {
                    char.isWhitespace() || char == ';' -> index++
                    text.startsWith("//", index) -> {
                        val end = text.indexOf('\n', index)
                        index = if (end < 0) length else end + 1
                    }
                    text.startsWith("/*", index) -> {
                        val end = text.indexOf("*/", index)
                        index = if (end < 0) length else end + 2
                    }
                    else -> return
                }
            }
        }
        fun readQuoted(): String? {
            if (index >= length || text[index] != '"') return null
            index++
            val out = StringBuilder()
            while (index < length) {
                val char = text[index++]
                when (char) {
                    '"' -> return out.toString()
                    '\\' -> {
                        if (index >= length) return out.toString()
                        when (val next = text[index++]) {
                            'n' -> out.append('\n')
                            't' -> out.append('\t')
                            'r' -> out.append('\r')
                            '"' -> out.append('"')
                            '\\' -> out.append('\\')
                            'U', 'u' -> {
                                val hex = text.substring(index, minOf(index + 4, length))
                                val code = hex.toIntOrNull(16)
                                if (code != null) {
                                    out.append(code.toChar())
                                    index += 4
                                }
                            }
                            else -> out.append(next)
                        }
                    }
                    else -> out.append(char)
                }
            }
            return out.toString()
        }
        while (index < length) {
            skipBlanksAndComments()
            val key = readQuoted() ?: run { index++; null } ?: continue
            skipBlanksAndComments()
            if (index < length && text[index] == '=') index++
            skipBlanksAndComments()
            val value = readQuoted() ?: continue
            result[key] = value
        }
        return result
    }
}

/** `"key".localized` */
val String.localized: String
    get() {
        val language = LanguageManager.actualLanguageCode
        return Strings.table(language)[this]
            ?: Strings.table("en")[this]
            ?: this
    }

/** `"key".localized(a, b)`: Swift's format specifiers (`%@`, `%d`, `%lld`, `%1$@`) work as they are. */
fun String.localized(vararg arguments: Any?): String = localized.swiftFormat(*arguments)

fun String.swiftFormat(vararg arguments: Any?): String {
    val converted = replace(Regex("%(\\d+\\$)?(l{1,2}|h{1,2}|q|z|t)?([@dDiuUxXfFeEgGcCsS%])")) { match ->
        val position = match.groupValues[1]
        when (val kind = match.groupValues[3]) {
            "%" -> "%%"
            "@", "S" -> "%${position}s"
            "D", "U", "u", "i" -> "%${position}d"
            "C" -> "%${position}c"
            else -> "%$position$kind"
        }
    }
    val fixed = arguments.map { argument ->
        when (argument) {
            is Long, is Int, is Double, is Float, is String -> argument
            null -> ""
            else -> argument.toString()
        }
    }.toTypedArray()
    return runCatching { String.format(appLocale, converted, *fixed) }.getOrElse {
        // An integer given for %f or the other way around must not bring the screen down.
        val loose = converted.replace(Regex("%(\\d+\\$)?\\.?\\d*[dfFeEgGxX]"), "%$1s")
        runCatching { String.format(appLocale, loose, *arguments.map { it?.toString() ?: "" }.toTypedArray()) }.getOrDefault(this)
    }
}
