/**************************************************************************/
/*  GodotApp.java                                                         */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

package com.godot.game;

import org.godotengine.godot.Godot;
import org.godotengine.godot.GodotActivity;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;

import androidx.activity.EdgeToEdge;
import androidx.core.splashscreen.SplashScreen;
import androidx.annotation.NonNull;
import androidx.collection.ArraySet;

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.initialization.InitializationStatus;
import com.google.android.gms.ads.initialization.OnInitializationCompleteListener;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;

import java.util.Arrays;
import java.util.List;
import java.util.Set;

/**
 * Template activity for Godot Android builds.
 * Feel free to extend and modify this class for your custom logic.
 */
public class GodotApp extends GodotActivity {
	static {
		// .NET libraries.
		if (BuildConfig.FLAVOR.equals("mono")) {
			try {
				Log.v("GODOT", "Loading System.Security.Cryptography.Native.Android library");
				System.loadLibrary("System.Security.Cryptography.Native.Android");
			} catch (UnsatisfiedLinkError e) {
				Log.e("GODOT", "Unable to load System.Security.Cryptography.Native.Android library");
			}
		}
	}

	private final Runnable updateWindowAppearance = () -> {
		Godot godot = getGodot();
		if (godot != null) {
			godot.enableImmersiveMode(godot.isInImmersiveMode(), true);
			godot.enableEdgeToEdge(godot.isInEdgeToEdgeMode(), true);
			godot.setSystemBarsAppearance();
		}
	};

	@Override
	public void onCreate(Bundle savedInstanceState) {
		SplashScreen.installSplashScreen(this);
		EdgeToEdge.enable(this);
		super.onCreate(savedInstanceState);
	}

	@Override
	public void onResume() {
		super.onResume();
		updateWindowAppearance.run();
	}

	@Override
	public void onGodotMainLoopStarted() {
		super.onGodotMainLoopStarted();
		runOnUiThread(updateWindowAppearance);
	}

	@NonNull
	public List<GodotPlugin> getPlugins() {
		return Arrays.asList(new GodotAdMobPlugin(getGodot()));
	}

	// Custom AdMob v2 Plugin
	public static class GodotAdMobPlugin extends GodotPlugin {
		private static final String TAG = "GodotAdMob";
		private RewardedAd rewardedAd = null;
		private boolean isInitialized = false;

		public GodotAdMobPlugin(Godot godot) {
			super(godot);
		}

		@NonNull
		@Override
		public String getPluginName() {
			return "GodotAdMob";
		}

		@NonNull
		@Override
		public Set<SignalInfo> getPluginSignals() {
			Set<SignalInfo> signals = new ArraySet<>();
			signals.add(new SignalInfo("admob_initialized"));
			signals.add(new SignalInfo("rewarded_ad_loaded"));
			signals.add(new SignalInfo("rewarded_ad_failed_to_load", String.class));
			signals.add(new SignalInfo("rewarded_ad_opened"));
			signals.add(new SignalInfo("rewarded_ad_closed"));
			signals.add(new SignalInfo("rewarded_ad_failed_to_show", String.class));
			signals.add(new SignalInfo("user_earned_reward", String.class, Integer.class));
			return signals;
		}

		@UsedByGodot
		public void initialize() {
			Log.d(TAG, "Initializing Google Mobile Ads SDK");
			final Activity activity = getActivity();
			if (activity == null) {
				Log.e(TAG, "Activity is null");
				return;
			}
			activity.runOnUiThread(new Runnable() {
				@Override
				public void run() {
					MobileAds.initialize(activity, new OnInitializationCompleteListener() {
						@Override
						public void onInitializationComplete(InitializationStatus initializationStatus) {
							Log.d(TAG, "AdMob SDK initialized successfully");
							isInitialized = true;
							emitSignal("admob_initialized");
						}
					});
				}
			});
		}

		@UsedByGodot
		public void loadRewardedAd(final String adUnitId) {
			Log.d(TAG, "Loading rewarded ad with ID: " + adUnitId);
			final Activity activity = getActivity();
			if (activity == null) {
				Log.e(TAG, "Activity is null");
				emitSignal("rewarded_ad_failed_to_load", "Activity is null");
				return;
			}
			activity.runOnUiThread(new Runnable() {
				@Override
				public void run() {
					AdRequest adRequest = new AdRequest.Builder().build();
					RewardedAd.load(activity, adUnitId, adRequest, new RewardedAdLoadCallback() {
						@Override
						public void onAdLoaded(@NonNull RewardedAd ad) {
							Log.d(TAG, "Rewarded ad loaded successfully");
							rewardedAd = ad;
							setupAdCallbacks();
							emitSignal("rewarded_ad_loaded");
						}

						@Override
						public void onAdFailedToLoad(@NonNull LoadAdError loadAdError) {
							Log.e(TAG, "Rewarded ad failed to load: " + loadAdError.getMessage());
							rewardedAd = null;
							emitSignal("rewarded_ad_failed_to_load", loadAdError.getMessage());
						}
					});
				}
			});
		}

		private void setupAdCallbacks() {
			if (rewardedAd != null) {
				rewardedAd.setFullScreenContentCallback(new FullScreenContentCallback() {
					@Override
					public void onAdShowedFullScreenContent() {
						Log.d(TAG, "Ad showed full screen content");
						emitSignal("rewarded_ad_opened");
					}

					@Override
					public void onAdDismissedFullScreenContent() {
						Log.d(TAG, "Ad dismissed full screen content");
						rewardedAd = null;
						emitSignal("rewarded_ad_closed");
					}

					@Override
					public void onAdFailedToShowFullScreenContent(@NonNull AdError adError) {
						Log.e(TAG, "Ad failed to show: " + adError.getMessage());
						rewardedAd = null;
						emitSignal("rewarded_ad_failed_to_show", adError.getMessage());
					}
				});
			}
		}

		@UsedByGodot
		public void showRewardedAd() {
			Log.d(TAG, "Showing rewarded ad");
			final Activity activity = getActivity();
			if (activity == null) {
				Log.e(TAG, "Activity is null");
				emitSignal("rewarded_ad_failed_to_show", "Activity is null");
				return;
			}
			activity.runOnUiThread(new Runnable() {
				@Override
				public void run() {
					if (rewardedAd != null) {
						rewardedAd.show(activity, rewardItem -> {
							int rewardAmount = rewardItem.getAmount();
							String rewardType = rewardItem.getType();
							Log.d(TAG, "User earned reward: " + rewardType + " x" + rewardAmount);
							emitSignal("user_earned_reward", rewardType, rewardAmount);
						});
					} else {
						Log.e(TAG, "Rewarded ad is not ready");
						emitSignal("rewarded_ad_failed_to_show", "Ad not loaded");
					}
				}
			});
		}

		@UsedByGodot
		public boolean isRewardedAdReady() {
			return rewardedAd != null;
		}

		@UsedByGodot
		public boolean isInitialized() {
			return isInitialized;
		}
	}
}
