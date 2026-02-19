package com.snaptask.app.di

import android.content.Context
import androidx.room.Room
import com.snaptask.app.SnapTaskApp
import com.snaptask.app.data.local.SnapTaskDatabase
import com.snaptask.app.data.local.SnapTaskPreferences
import com.snaptask.app.data.local.dao.*
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideApplication(@ApplicationContext context: Context): SnapTaskApp {
        return context as SnapTaskApp
    }

    // ---- Room Database ----

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): SnapTaskDatabase {
        return Room.databaseBuilder(
            context,
            SnapTaskDatabase::class.java,
            SnapTaskDatabase.DATABASE_NAME,
        ).fallbackToDestructiveMigration().build()
    }

    // ---- DAOs ----

    @Provides
    fun provideTaskDao(database: SnapTaskDatabase): TaskDao = database.taskDao()

    @Provides
    fun provideCategoryDao(database: SnapTaskDatabase): CategoryDao = database.categoryDao()

    @Provides
    fun provideRewardDao(database: SnapTaskDatabase): RewardDao = database.rewardDao()

    @Provides
    fun provideFinanceEntryDao(database: SnapTaskDatabase): FinanceEntryDao = database.financeEntryDao()

    @Provides
    fun provideJournalDao(database: SnapTaskDatabase): JournalDao = database.journalDao()

    @Provides
    fun provideTrackingSessionDao(database: SnapTaskDatabase): TrackingSessionDao =
        database.trackingSessionDao()

    // ---- Preferences ----

    @Provides
    @Singleton
    fun providePreferences(@ApplicationContext context: Context): SnapTaskPreferences {
        return SnapTaskPreferences(context)
    }
}
