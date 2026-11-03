package com.snaptask.app

import android.app.Activity
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.acknowledgePurchase
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import java.time.format.FormatStyle

enum class PremiumFeature(val rawValue: String) {
    unlimitedCategories("unlimited_categories"),
    taskEvaluation("task_evaluation"),
    unlimitedRewards("unlimited_rewards"),
    advancedStatistics("advanced_statistics"),
    customThemes("custom_themes");

    val localizedName: String get() = rawValue.localized
    val localizedDescription: String get() = "${rawValue}_desc".localized
}

sealed class SubscriptionStatus {
    data object NotSubscribed : SubscriptionStatus()
    data class Subscribed(val expirationDate: Date?) : SubscriptionStatus()
    data object Expired : SubscriptionStatus()
    data class InTrial(val expirationDate: Date?) : SubscriptionStatus()
    data object Pending : SubscriptionStatus()
    data class Failed(val error: String) : SubscriptionStatus()

    val isActive: Boolean get() = this is Subscribed || this is InTrial
    val isInTrial: Boolean get() = this is InTrial

    val displayStatus: String
        get() = when (this) {
            NotSubscribed -> "not_subscribed".localized
            is Subscribed -> expirationDate?.let { "subscription_expires_on".localized(it.dateStyle(FormatStyle.MEDIUM)) } ?: "lifetime_access".localized
            Expired -> "subscription_expired".localized
            is InTrial -> expirationDate?.let { "trial_expires_on".localized(it.dateStyle(FormatStyle.MEDIUM)) } ?: "not_subscribed".localized
            Pending -> "purchase_pending".localized
            is Failed -> "subscription_error".localized(error)
        }
}

/** A product of the store with what the paywall shows. */
data class StoreProduct(val id: String, val displayName: String, val displayPrice: String, val priceMicros: Long, val currency: String, val details: ProductDetails, val offerToken: String?, val hasTrial: Boolean)

/**
 * Google Play Billing in place of StoreKit. The products need the same ids in the Play Console;
 * until they exist the paywall shows "---" as prices, as iOS does without products.
 */
object SubscriptionManager {
    private const val monthlyId = "snaptask.subscription.monthly"
    private const val yearlyId = "snaptask.subscription.yearly"
    private const val lifetimeId = "snaptask.lifetime"

    const val maxCategoriesForFree = 4
    const val maxRewardsForFree = 3

    var subscriptionStatus by mutableStateOf<SubscriptionStatus>(SubscriptionStatus.NotSubscribed)
        private set
    var isLoading by mutableStateOf(false)
        private set
    var monthlyProduct by mutableStateOf<StoreProduct?>(null)
        private set
    var yearlyProduct by mutableStateOf<StoreProduct?>(null)
        private set
    var lifetimeProduct by mutableStateOf<StoreProduct?>(null)
        private set

    val isSubscribed: Boolean get() = subscriptionStatus.isActive
    fun hasAccess(feature: PremiumFeature): Boolean = subscriptionStatus.isActive

    private var client: BillingClient? = null
    private var purchaseResult: CompletableDeferred<Boolean>? = null

    private val listener = PurchasesUpdatedListener { result, purchases ->
        if (result.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            MainScope.launch {
                purchases.forEach { acknowledge(it) }
                refreshStatus()
                purchaseResult?.complete(subscriptionStatus.isActive)
            }
        } else {
            if (result.responseCode != BillingClient.BillingResponseCode.USER_CANCELED) {
                subscriptionStatus = SubscriptionStatus.Failed("purchase_failed".localized)
            }
            purchaseResult?.complete(false)
        }
    }

    fun load() {
        if (BuildConfig.UNLOCK_PRO) {
            subscriptionStatus = SubscriptionStatus.Subscribed(null)
            return
        }
        subscriptionStatus = when (Defaults.string("subscriptionStatusType")) {
            "subscribed" -> SubscriptionStatus.Subscribed(Defaults.date("subscriptionExpirationDate"))
            "inTrial" -> SubscriptionStatus.InTrial(Defaults.date("subscriptionExpirationDate"))
            "expired" -> SubscriptionStatus.Expired
            else -> SubscriptionStatus.NotSubscribed
        }
        MainScope.launch {
            if (connect()) {
                loadProducts()
                refreshStatus()
            }
        }
    }

    private suspend fun connect(): Boolean {
        val existing = client
        if (existing != null && existing.isReady) return true
        val billing = BillingClient.newBuilder(App.context)
            .setListener(listener)
            .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
            .build()
        client = billing
        val done = CompletableDeferred<Boolean>()
        billing.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                done.complete(result.responseCode == BillingClient.BillingResponseCode.OK)
            }
            override fun onBillingServiceDisconnected() {}
        })
        return done.await()
    }

    suspend fun loadProducts() {
        val billing = client ?: return
        isLoading = true
        fun products(type: String, vararg ids: String) = QueryProductDetailsParams.newBuilder().setProductList(
            ids.map { QueryProductDetailsParams.Product.newBuilder().setProductId(it).setProductType(type).build() }
        ).build()
        val subs = billing.queryProductDetails(products(BillingClient.ProductType.SUBS, monthlyId, yearlyId)).productDetailsList ?: emptyList()
        val inApp = billing.queryProductDetails(products(BillingClient.ProductType.INAPP, lifetimeId)).productDetailsList ?: emptyList()
        for (details in subs) {
            val offers = details.subscriptionOfferDetails ?: continue
            val trial = offers.firstOrNull { offer -> offer.pricingPhases.pricingPhaseList.any { it.priceAmountMicros == 0L } }
            val offer = trial ?: offers.firstOrNull() ?: continue
            val phase = offer.pricingPhases.pricingPhaseList.lastOrNull() ?: continue
            val product = StoreProduct(details.productId, details.name, phase.formattedPrice, phase.priceAmountMicros, phase.priceCurrencyCode, details, offer.offerToken, trial != null)
            if (details.productId == monthlyId) monthlyProduct = product else yearlyProduct = product
        }
        inApp.firstOrNull()?.let { details ->
            details.oneTimePurchaseOfferDetails?.let { offer ->
                lifetimeProduct = StoreProduct(details.productId, details.name, offer.formattedPrice, offer.priceAmountMicros, offer.priceCurrencyCode, details, null, false)
            }
        }
        isLoading = false
    }

    suspend fun purchase(activity: Activity, product: StoreProduct): Boolean {
        val billing = client ?: return false
        if (isLoading) return false
        isLoading = true
        val params = BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(product.details)
        product.offerToken?.let { params.setOfferToken(it) }
        val deferred = CompletableDeferred<Boolean>()
        purchaseResult = deferred
        val flow = BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(params.build())).build()
        val launched = billing.launchBillingFlow(activity, flow)
        val success = if (launched.responseCode == BillingClient.BillingResponseCode.OK) deferred.await() else false
        isLoading = false
        return success
    }

    suspend fun restorePurchases(): Boolean {
        if (isLoading) return false
        isLoading = true
        if (connect()) refreshStatus()
        isLoading = false
        return subscriptionStatus.isActive
    }

    fun manageSubscriptions() {
        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse("https://play.google.com/store/account/subscriptions?package=${App.context.packageName}"))
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { App.context.startActivity(intent) }
    }

    private suspend fun acknowledge(purchase: Purchase) {
        if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED && !purchase.isAcknowledged) {
            client?.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build())
        }
    }

    private suspend fun refreshStatus() {
        if (BuildConfig.UNLOCK_PRO) return
        val billing = client ?: return
        val inApp = billing.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build()).purchasesList
        val subs = billing.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build()).purchasesList
        (inApp + subs).forEach { acknowledge(it) }
        val lifetime = inApp.any { lifetimeId in it.products && it.purchaseState == Purchase.PurchaseState.PURCHASED }
        val active = subs.firstOrNull { it.purchaseState == Purchase.PurchaseState.PURCHASED }
        val pending = (inApp + subs).any { it.purchaseState == Purchase.PurchaseState.PENDING }
        subscriptionStatus = when {
            lifetime -> SubscriptionStatus.Subscribed(null)
            active != null -> SubscriptionStatus.Subscribed(null)
            pending -> SubscriptionStatus.Pending
            else -> SubscriptionStatus.NotSubscribed
        }
        Defaults.set("subscriptionStatusType", when (subscriptionStatus) {
            is SubscriptionStatus.Subscribed -> "subscribed"
            is SubscriptionStatus.InTrial -> "inTrial"
            else -> "notSubscribed"
        })
        // Premium ended: back to a free look.
        if (!subscriptionStatus.isActive && ThemeManager.currentTheme.isPremium) ThemeManager.setTheme(ThemeManager.defaultTheme)
    }

    private fun money(micros: Long, currency: String): String {
        val format = java.text.NumberFormat.getCurrencyInstance(appLocale)
        format.currency = java.util.Currency.getInstance(currency)
        return format.format(micros / 1_000_000.0)
    }

    val monthlyEquivalentForYearly: String
        get() = yearlyProduct?.let { money(it.priceMicros / 12, it.currency) } ?: "---"
    val yearlySavingsAmount: String
        get() {
            val monthly = monthlyProduct ?: return "---"
            val yearly = yearlyProduct ?: return "---"
            return money(monthly.priceMicros * 12 - yearly.priceMicros, yearly.currency)
        }
    val lifetimeSavingsAmount: String
        get() {
            val monthly = monthlyProduct ?: return "---"
            val lifetime = lifetimeProduct ?: return "---"
            return money(monthly.priceMicros * 24 - lifetime.priceMicros, lifetime.currency)
        }

    val trialDaysRemaining: Int get() = 0
    val hasUsedTrial: Boolean get() = Defaults.bool("hasUsedFreeTrial")
    fun markTrialAsUsed() = Defaults.set("hasUsedFreeTrial", true)
}
