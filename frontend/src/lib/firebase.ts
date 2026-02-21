/**
 * Firebase Cloud Messaging service for web push notifications.
 * Handles FCM initialization, token management, and message handling.
 */

import { initializeApp } from "firebase/app"
import type { FirebaseApp } from "firebase/app"
import { getMessaging, getToken, onMessage } from "firebase/messaging"
import type { Messaging, MessagePayload } from "firebase/messaging"
import { firebaseConfig, vapidKey } from "@/config/firebase"
import { registerFcmToken, unregisterFcmToken } from "@/api/notifications"
import { toast } from "@/lib/toast"

let firebaseApp: FirebaseApp | null = null
let messaging: Messaging | null = null
let currentToken: string | null = null

/**
 * Initialize Firebase app and messaging.
 */
export function initializeFirebase(): void {
  try {
    if (!firebaseApp) {
      firebaseApp = initializeApp(firebaseConfig)
    }
    
    if (!messaging && "serviceWorker" in navigator) {
      messaging = getMessaging(firebaseApp)
    }
  } catch (error) {
    console.error("Failed to initialize Firebase:", error)
  }
}

/**
 * Request notification permission and register FCM token.
 * Returns the FCM token if successful, null otherwise.
 */
export async function requestNotificationPermission(): Promise<string | null> {
  try {
    // Check if notifications are supported
    if (!("Notification" in window)) {
      console.warn("This browser does not support notifications")
      return null
    }

    // Check if service workers are supported
    if (!("serviceWorker" in navigator)) {
      console.warn("This browser does not support service workers")
      return null
    }

    // Initialize Firebase if not already done
    initializeFirebase()
    
    if (!messaging) {
      console.error("Firebase messaging not initialized")
      return null
    }

    // Request browser notification permission
    const permission = await Notification.requestPermission()
    
    if (permission !== "granted") {
      console.log("Notification permission denied")
      return null
    }

    // Get FCM token
    const token = await getToken(messaging, {
      vapidKey: vapidKey,
    })

    if (token) {
      console.log("FCM Token obtained:", token)
      currentToken = token
      
      // Register token with backend
      try {
        await registerFcmToken(token, "web")
        console.log("Token registered with backend")
      } catch (error) {
        console.error("Failed to register token with backend:", error)
      }
      
      return token
    } else {
      console.log("No token available. Request permission to generate one.")
      return null
    }
  } catch (error) {
    console.error("Error getting FCM token:", error)
    return null
  }
}

/**
 * Unregister the current FCM token.
 */
export async function unregisterCurrentToken(): Promise<void> {
  if (currentToken) {
    try {
      await unregisterFcmToken(currentToken)
      console.log("Token unregistered from backend")
      currentToken = null
    } catch (error) {
      console.error("Failed to unregister token:", error)
    }
  }
}

/**
 * Set up foreground message handler.
 * This handles messages when the app is in the foreground.
 */
export function setupForegroundMessageHandler(): void {
  if (!messaging) {
    console.error("Firebase messaging not initialized")
    return
  }

  onMessage(messaging, (payload: MessagePayload) => {
    console.log("Foreground message received:", payload)
    
    // Show toast notification
    const title = payload.notification?.title || "Notifikasi Baru"
    const body = payload.notification?.body || ""
    
    // Determine toast type based on notification_type in data
    const notificationType = payload.data?.notification_type || "INFO"
    
    switch (notificationType) {
      case "SUCCESS":
        toast.success(title, body)
        break
      case "WARNING":
        toast.warning(title, body)
        break
      case "ERROR":
        toast.error(title, body)
        break
      default:
        toast.info(title, body)
    }
    
    // You can also dispatch a custom event to update notification badge
    window.dispatchEvent(new CustomEvent("newNotification", { detail: payload }))
  })
}

/**
 * Check if notifications are enabled.
 */
export function isNotificationEnabled(): boolean {
  return "Notification" in window && Notification.permission === "granted"
}

/**
 * Get the current FCM token.
 */
export function getCurrentToken(): string | null {
  return currentToken
}
