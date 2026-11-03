package com.snaptask.app

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.*
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant

/**
 * The community data (feedback, votes, app news) is the same Firestore project iOS uses.
 * It goes through the REST API: the app needs nothing else from Firebase, and only this project id
 * and the public API key from `GoogleService-Info.plist`.
 */
object Firestore {
    private const val projectId = "snaptask-50855"
    private const val apiKey = "AIzaSyBrMnUS2e7VbP0koDbx6F1LjfeS2HR69aw"
    private const val root = "projects/$projectId/databases/(default)/documents"
    private const val base = "https://firestore.googleapis.com/v1/$root"

    data class Document(val id: String, val updateTime: String?, val fields: Map<String, Any?>)

    sealed class Write {
        data class Set(val collection: String, val id: String, val fields: Map<String, Any?>) : Write()
        /** Only these fields, and only if the document hasn't changed since it was read (a transaction on iOS). */
        data class Update(val collection: String, val id: String, val fields: Map<String, Any?>, val ifUpdateTime: String? = null) : Write()
        data class Delete(val collection: String, val id: String) : Write()
    }

    suspend fun list(collection: String, limit: Int? = null): List<Document> {
        val documents = ArrayList<Document>()
        var token: String? = null
        do {
            val size = limit ?: 300
            val query = "pageSize=$size&key=$apiKey" + (token?.let { "&pageToken=${java.net.URLEncoder.encode(it, "UTF-8")}" } ?: "")
            val json = AppJson.parseToJsonElement(request("GET", "$base/$collection?$query")).jsonObject
            json["documents"]?.jsonArray?.forEach { documents += decodeDocument(it.jsonObject) }
            token = if (limit == null) json["nextPageToken"]?.jsonPrimitive?.contentOrNull else null
        } while (token != null)
        return documents
    }

    /** nil when the document doesn't exist. */
    suspend fun get(collection: String, id: String): Document? = try {
        decodeDocument(AppJson.parseToJsonElement(request("GET", "$base/$collection/$id?key=$apiKey")).jsonObject)
    } catch (error: NotFound) {
        null
    }

    suspend fun whereEqual(collection: String, field: String, value: Any?): List<Document> {
        val body = buildJsonObject {
            putJsonObject("structuredQuery") {
                putJsonArray("from") { addJsonObject { put("collectionId", collection) } }
                putJsonObject("where") {
                    putJsonObject("fieldFilter") {
                        putJsonObject("field") { put("fieldPath", field) }
                        put("op", "EQUAL")
                        put("value", encode(value))
                    }
                }
            }
        }
        val result = AppJson.parseToJsonElement(request("POST", "$base:runQuery?key=$apiKey", body.toString())).jsonArray
        return result.mapNotNull { it.jsonObject["document"]?.jsonObject }.map(::decodeDocument)
    }

    /** All or nothing, like a batch or transaction. */
    suspend fun commit(writes: List<Write>) {
        val body = buildJsonObject {
            putJsonArray("writes") {
                writes.forEach { write ->
                    addJsonObject {
                        when (write) {
                            is Write.Set -> putJsonObject("update") {
                                put("name", "$root/${write.collection}/${write.id}")
                                put("fields", encodeFields(write.fields))
                            }
                            is Write.Update -> {
                                putJsonObject("update") {
                                    put("name", "$root/${write.collection}/${write.id}")
                                    put("fields", encodeFields(write.fields))
                                }
                                putJsonObject("updateMask") {
                                    putJsonArray("fieldPaths") { write.fields.keys.forEach { add(it) } }
                                }
                                putJsonObject("currentDocument") {
                                    if (write.ifUpdateTime != null) put("updateTime", write.ifUpdateTime) else put("exists", true)
                                }
                            }
                            is Write.Delete -> put("delete", "$root/${write.collection}/${write.id}")
                        }
                    }
                }
            }
        }
        request("POST", "$base:commit?key=$apiKey", body.toString())
    }

    private class NotFound : Exception()

    private suspend fun request(method: String, url: String, body: String? = null): String = withContext(Dispatchers.IO) {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.connectTimeout = 15_000
            connection.readTimeout = 20_000
            if (body != null) {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                connection.outputStream.use { it.write(body.toByteArray()) }
            }
            val code = connection.responseCode
            if (code == 404) throw NotFound()
            if (code !in 200..299) {
                throw java.io.IOException("Firestore $code: " + (connection.errorStream?.bufferedReader()?.use { it.readText() } ?: ""))
            }
            connection.inputStream.bufferedReader().use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }

    private fun decodeDocument(json: JsonObject) = Document(
        json["name"]!!.jsonPrimitive.content.substringAfterLast('/'),
        json["updateTime"]?.jsonPrimitive?.contentOrNull,
        decodeFields(json["fields"]?.jsonObject),
    )

    private fun decodeFields(fields: JsonObject?): Map<String, Any?> =
        fields?.mapValues { decode(it.value.jsonObject) } ?: emptyMap()

    private fun decode(value: JsonObject): Any? {
        val (type, content) = value.entries.firstOrNull() ?: return null
        return when (type) {
            "stringValue" -> content.jsonPrimitive.content
            "integerValue" -> content.jsonPrimitive.content.toLongOrNull()?.toInt()
            "doubleValue" -> content.jsonPrimitive.doubleOrNull?.toInt()
            "booleanValue" -> content.jsonPrimitive.booleanOrNull
            "timestampValue" -> runCatching { Instant.parse(content.jsonPrimitive.content) }.getOrNull()
            "arrayValue" -> content.jsonObject["values"]?.jsonArray?.map { decode(it.jsonObject) } ?: emptyList<Any?>()
            "mapValue" -> decodeFields(content.jsonObject["fields"]?.jsonObject)
            else -> null
        }
    }

    private fun encodeFields(fields: Map<String, Any?>) = buildJsonObject {
        fields.forEach { (key, value) -> put(key, encode(value)) }
    }

    private fun encode(value: Any?): JsonObject = buildJsonObject {
        when (value) {
            null -> put("nullValue", JsonNull)
            is String -> put("stringValue", value)
            is Boolean -> put("booleanValue", value)
            is Int -> put("integerValue", value.toString())
            is Instant -> put("timestampValue", java.time.format.DateTimeFormatter.ISO_INSTANT.format(value))
            is List<*> -> putJsonObject("arrayValue") { putJsonArray("values") { value.forEach { add(encode(it)) } } }
            is Map<*, *> -> putJsonObject("mapValue") {
                put("fields", buildJsonObject { value.forEach { (key, item) -> put(key as String, encode(item)) } })
            }
            else -> error("Unsupported Firestore value: $value")
        }
    }
}
