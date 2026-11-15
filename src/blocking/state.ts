export type ConnectionStatus = "disconnected" | "connecting" | "connected" | "disconnecting" | "reasserting" | "unknown";
export type Mode = "observe" | "block";
export type TunnelState = { status: ConnectionStatus; mode: Mode; rulesReady: boolean; available: boolean };
export const unavailableState: TunnelState = { status: "disconnected", mode: "observe", rulesReady: false, available: false };
export const isRunning = (state: TunnelState) => ["connected", "connecting", "reasserting", "disconnecting"].includes(state.status);
export const isTransitioning = (state: TunnelState) => ["connecting", "reasserting", "disconnecting"].includes(state.status);
export const switchIsOn = (state: TunnelState) => state.mode === "block" && state.status === "connected";

export function describeState(state: TunnelState): string {
  if (!state.available) return "Requires the iPhone IPA build";
  if (state.status === "connecting") return "Starting test…";
  if (state.status === "disconnecting") return "Stopping test…";
  if (state.status === "reasserting") return "Reconnecting — blocking unavailable";
  if (state.status === "unknown") return "Connection status unavailable";
  if (state.status === "connected") return state.mode === "observe" ? "Test running · Reels are not blocked" : "Experimental filtering · verify in Instagram";
  return state.rulesReady ? "Off" : "Blocking not ready";
}
