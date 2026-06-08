/**
 * Mean Eats — Guest tracking reference (web / React Native)
 * Mirrors Services/EventTrackingService.swift + GuestIdentityService.swift
 */

import { createClient } from '@supabase/supabase-js';
import AsyncStorage from '@react-native-async-storage/async-storage'; // RN
// Web: const storage = window.localStorage;

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);

const GUEST_KEY = 'meaneats_guest_id';
const QUEUE_KEY = 'meaneats_event_queue';

async function getGuestId(storage) {
  let id = await storage.getItem(GUEST_KEY);
  if (!id) {
    id = `guest_${crypto.randomUUID()}`;
    await storage.setItem(GUEST_KEY, id);
  }
  return id;
}

export async function trackEvent(eventType, metadata = {}, storage = AsyncStorage) {
  const guestId = await getGuestId(storage);
  const { data: { user } } = await supabase.auth.getUser();

  const userId = user?.id ?? guestId;
  const userType = user ? 'auth' : 'guest';

  const row = {
    user_id: userId,
    user_type: userType,
    event_type: eventType,
    guest_id: guestId,
    metadata: { ...metadata, guest_id: guestId, platform: 'web' },
  };

  const { error } = await supabase.from('app_events').insert(row);
  if (error) {
    const queue = JSON.parse(await storage.getItem(QUEUE_KEY) ?? '[]');
    queue.push(row);
    await storage.setItem(QUEUE_KEY, JSON.stringify(queue.slice(-100)));
  }
}

export async function linkGuestToAuth(storage = AsyncStorage) {
  const guestId = await getGuestId(storage);
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;

  await trackEvent('guest_upgraded', { auth_user_id: user.id }, storage);
  await supabase.rpc('link_guest_to_auth', {
    p_guest_id: guestId,
    p_auth_id: user.id,
  });
}

// Usage:
// trackEvent('view_menu', { hall_id: 'bruceteria' });
// trackEvent('view_meal_plan');
// supabase.auth.onAuthStateChange((event) => {
//   if (event === 'SIGNED_IN') linkGuestToAuth();
// });
