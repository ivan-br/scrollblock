import { Stack } from "expo-router";
import { useEffect, useState } from "react";
import { Alert, Pressable, ScrollView, Share, Text, View } from "react-native";
import { network } from "../src/blocking/native";
import { describeState, isRunning } from "../src/blocking/state";
import { useBlocking } from "../src/blocking/use-blocking";
import { colors } from "../src/theme";

type Snapshot = { phase: string; queries: number; blocked: number; events: { host: string; phase: string; blocked: boolean; time: string }[] };
const phases = ["baseline", "reels", "stories", "messages", "feed"];

export default function Testing() {
  const { state, busy, error, change, refresh } = useBlocking();
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null);
  const [working, setWorking] = useState(false);
  const [issue, setIssue] = useState<string | null>(null);
  const connected = state.status === "connected";
  useEffect(() => { if (!connected) setSnapshot(null); }, [connected]);
  async function read(action = "read", phase = "", share = false) {
    if (working) return;
    setWorking(true); setIssue(null);
    try {
      const raw = await network.snapshot(action, phase);
      setSnapshot(JSON.parse(raw));
      if (share) await Share.share({ title: "Scrollblock network test", message: raw });
    } catch (error) { setIssue(error instanceof Error ? error.message : "Unable to read diagnostics."); }
    finally { setWorking(false); }
  }
  const button = (title: string, action: () => void, disabled = false) => (
    <Pressable key={title} accessibilityRole="button" disabled={disabled} onPress={action} style={{ paddingVertical: 14, paddingHorizontal: 18, backgroundColor: colors.surface, borderRadius: 14, opacity: disabled ? 0.45 : 1 }}>
      <Text style={{ color: colors.accent, fontSize: 16 }}>{title}</Text>
    </Pressable>
  );
  return <>
    <Stack.Screen options={{ title: "Network test" }} />
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={{ padding: 24, paddingBottom: 48, gap: 18, maxWidth: 568, width: "100%", alignSelf: "center" }}>
      <Text style={{ color: colors.text, fontSize: 25, fontWeight: "600" }}>Find out what can be separated.</Text>
      <Text style={{ color: colors.muted, fontSize: 15, lineHeight: 23 }}>This test observes DNS lookups for Instagram domains. It does not block Reels, read messages, inspect video content, or prove that a hostname is used only by Reels.</Text>
      <Text selectable style={{ color: colors.muted, fontSize: 15, lineHeight: 23 }}>For up to five minutes, Instagram-domain DNS queries are sent to Cloudflare over HTTPS. Other apps using the same domains may also be included. Your other traffic is not routed through this test. An existing VPN may conflict.</Text>
      <Text style={{ color: colors.muted, fontSize: 15, lineHeight: 23 }}>Up to 128 hostname observations stay in the extension’s memory and are cleared when the session stops. No automatic diagnostic upload. Sharing exports these observations only when you choose a destination.</Text>
      <Text accessibilityLiveRegion="polite" style={{ color: colors.accent }}>{describeState(state)}</Text>
      {button(isRunning(state) || state.status === "unknown" ? "Stop test" : "Start five-minute test", () => {
        if (isRunning(state) || state.status === "unknown") { void change("stop"); return; }
        Alert.alert("Start network test?", "Instagram-domain DNS queries will be sent to Cloudflare. Hostnames stay in memory until the session ends. Reels will not be blocked. iOS will ask to add a VPN configuration.", [
          { text: "Cancel", style: "cancel" }, { text: "Start test", onPress: () => void change("observe") },
        ]);
      }, busy || !state.available)}
      {error && <Text selectable accessibilityRole="alert" style={{ color: colors.error }}>{error}</Text>}
      {button("Refresh connection status", () => void refresh(), busy)}
      {connected && <>
        <Text style={{ color: colors.text, fontSize: 18, fontWeight: "600" }}>Label the next activity</Text>
        <Text style={{ color: colors.muted, lineHeight: 22 }}>Choose one activity, switch to Instagram and use it, then return here and refresh. Cached lookups or private DNS can produce no observations; an empty log is not proof of protection.</Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>{phases.map(phase => button(`${snapshot?.phase === phase ? "✓ " : ""}${phase}`, () => void read("read", phase), working))}</View>
        {button("Refresh observations", () => void read(), working)}
        {snapshot && <>
          <Text style={{ color: colors.text }}>{snapshot.queries} DNS queries · {snapshot.blocked} blocked</Text>
          {snapshot.events.length === 0 && <Text style={{ color: colors.muted }}>No observations yet. Use Instagram, then refresh.</Text>}
          {snapshot.events.slice(-30).reverse().map((event, index) => <View key={`${event.time}-${index}`} style={{ gap: 4, paddingVertical: 8, borderBottomWidth: 1, borderColor: colors.line }}>
            <Text selectable style={{ color: colors.text }}>{event.host}</Text>
            <Text style={{ color: colors.muted, fontSize: 12 }}>{event.phase} · {event.blocked ? "blocked" : "allowed"} · {event.time}</Text>
          </View>)}
          {button("Share observations…", () => void read("read", "", true), working)}
          {button("Clear observations", () => void read("clear"), working)}
        </>}
      </>}
      {issue && <Text selectable accessibilityRole="alert" style={{ color: colors.error }}>{issue}</Text>}
    </ScrollView>
  </>;
}
