import { Link, Stack } from "expo-router";
import { ActivityIndicator, Pressable, ScrollView, Switch, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { describeState, isRunning, isTransitioning, switchIsOn } from "../src/blocking/state";
import { useBlocking } from "../src/blocking/use-blocking";
import { colors } from "../src/theme";

export default function Home() {
  const { state, busy, error, change, refresh } = useBlocking();
  const insets = useSafeAreaInsets();
  const active = switchIsOn(state);
  const pending = busy || isTransitioning(state);
  return (
    <>
      <Stack.Screen options={{ title: "Scrollblock" }} />
      <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={{ flexGrow: 1, paddingHorizontal: 24, paddingTop: 36, paddingBottom: Math.max(insets.bottom, 24) }}>
        <View style={{ width: "100%", maxWidth: 520, alignSelf: "center", flex: 1 }}>
          <View accessible={false} style={{ width: 64, height: 64, borderRadius: 22, backgroundColor: colors.accent, flexDirection: "row", gap: 7, justifyContent: "center", alignItems: "center", marginBottom: 28 }}>
            <View style={{ width: 7, height: 25, borderRadius: 3, backgroundColor: colors.background }} />
            <View style={{ width: 7, height: 25, borderRadius: 3, backgroundColor: colors.background }} />
          </View>
          <Text style={{ color: colors.text, fontSize: 34, lineHeight: 40, fontWeight: "600", letterSpacing: -1 }}>Less scrolling.{"\n"}More living.</Text>
          <Text style={{ color: colors.muted, fontSize: 16, lineHeight: 24, marginTop: 14, marginBottom: 38 }}>Keep Instagram. Put a stop to the endless Reels feed.</Text>

          <View style={{ borderRadius: 24, borderCurve: "continuous", backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, padding: 20, gap: 20 }}>
            <View style={{ flexDirection: "row", alignItems: "center", gap: 14 }}>
              <View accessible={false} style={{ width: 48, height: 48, borderRadius: 16, backgroundColor: "#382A35", alignItems: "center", justifyContent: "center" }}>
                <View style={{ width: 27, height: 27, borderWidth: 2, borderColor: "#F2D4E6", borderRadius: 8, alignItems: "center", justifyContent: "center" }}>
                  <View style={{ width: 11, height: 11, borderWidth: 2, borderColor: "#F2D4E6", borderRadius: 6 }} />
                  <View style={{ position: "absolute", right: 3, top: 3, width: 3, height: 3, borderRadius: 2, backgroundColor: "#F2D4E6" }} />
                </View>
              </View>
              <View style={{ flex: 1, gap: 3 }}>
                <Text style={{ color: colors.muted, fontSize: 13 }}>Instagram</Text>
                <Text style={{ color: colors.text, fontSize: 21, fontWeight: "600" }}>Reels</Text>
              </View>
              <Switch accessibilityLabel="Block newly recommended Instagram Reels" accessibilityHint={state.rulesReady ? "Starts a five-minute experimental filtering session" : "Unavailable until selective blocking rules have been validated"}
                value={active} disabled={pending || !state.available || (!state.rulesReady && !active) || (isRunning(state) && state.mode === "observe")}
                onValueChange={value => void change(value ? "block" : "stop")} trackColor={{ false: "#46544B", true: colors.accent }} thumbColor={active ? colors.background : "#E5EBE6"} />
            </View>
            <View style={{ borderTopWidth: 1, borderColor: colors.line, paddingTop: 16, flexDirection: "row", alignItems: "center", gap: 9 }}>
              {pending ? <ActivityIndicator size="small" color={colors.accent} /> : <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: active ? colors.accent : colors.subtle }} />}
              <Text accessibilityLiveRegion="polite" style={{ color: colors.muted, fontSize: 13, flex: 1 }}>{describeState(state)}</Text>
            </View>
          </View>
          {!state.rulesReady && <Text style={{ color: colors.muted, fontSize: 14, lineHeight: 21, marginTop: 16 }}>This early build does not block Reels yet. A selective rule needs testing before the switch can be enabled.</Text>}
          {state.rulesReady && <Text style={{ color: colors.muted, fontSize: 14, lineHeight: 21, marginTop: 16 }}>Experimental five-minute sessions. Previously loaded Reels may still play. Verify the result in Instagram.</Text>}
          {error && <Text selectable accessibilityRole="alert" style={{ color: colors.error, fontSize: 14, lineHeight: 21, marginTop: 16 }}>{error}</Text>}
          {(isRunning(state) || state.status === "unknown") && <Pressable accessibilityRole="button" onPress={() => void change("stop")} disabled={busy} style={{ paddingVertical: 16 }}><Text style={{ color: colors.accent, fontSize: 16 }}>Stop network session</Text></Pressable>}
          {error && <Pressable accessibilityRole="button" onPress={() => void refresh()} style={{ paddingVertical: 16 }}><Text style={{ color: colors.accent }}>Refresh status</Text></Pressable>}
          <View style={{ flex: 1, minHeight: 70 }} />
          <Link href="/testing" asChild><Pressable accessibilityRole="button" style={{ minHeight: 44, justifyContent: "center" }}><Text style={{ color: colors.accent, textAlign: "center", fontSize: 15 }}>Network test & privacy</Text></Pressable></Link>
          <Text style={{ color: colors.subtle, textAlign: "center", fontSize: 12, marginTop: 8 }}>Early access · iOS 18+</Text>
        </View>
      </ScrollView>
    </>
  );
}
