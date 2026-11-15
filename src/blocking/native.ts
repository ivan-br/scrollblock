import { requireOptionalNativeModule } from "expo";
import { Platform } from "react-native";
import { Mode, TunnelState, unavailableState } from "./state";

type Bridge = {
  getState(): Promise<TunnelState>;
  start(mode: Mode): Promise<TunnelState>;
  stop(): Promise<TunnelState>;
  snapshot(action: string, phase: string): Promise<string>;
  addListener(name: "onStateChange", listener: (state: TunnelState) => void): { remove(): void };
};
const bridge = Platform.OS === "ios" ? requireOptionalNativeModule<Bridge>("Scrollblock") : null;
function requireBridge(): Bridge {
  if (!bridge) throw new Error("Install the signed Scrollblock IPA on an iPhone. VPN testing is unavailable in Expo Go and the web preview.");
  return bridge;
}
export const network = {
  getState: () => bridge?.getState() ?? Promise.resolve(unavailableState),
  start: (mode: Mode) => requireBridge().start(mode),
  stop: () => requireBridge().stop(),
  snapshot: (action = "read", phase = "") => requireBridge().snapshot(action, phase),
  subscribe: (listener: (state: TunnelState) => void) => {
    const subscription = bridge?.addListener("onStateChange", listener);
    return () => subscription?.remove();
  },
};
