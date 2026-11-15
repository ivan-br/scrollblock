import { useCallback, useEffect, useRef, useState } from "react";
import { AppState } from "react-native";
import { network } from "./native";
import { Mode, TunnelState, unavailableState } from "./state";

export function useBlocking() {
  const [state, setState] = useState<TunnelState>(unavailableState);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const locked = useRef(false);
  const mounted = useRef(true);
  const generation = useRef(0);
  const refresh = useCallback(async () => {
    const id = ++generation.current;
    try {
      const value = await network.getState();
      if (mounted.current && generation.current === id) { setState(value); setError(null); }
    } catch (error) {
      if (mounted.current && generation.current === id) {
        setState(previous => ({ ...previous, status: "unknown" }));
        setError(error instanceof Error ? error.message : "Unable to read VPN status.");
      }
    }
  }, []);
  useEffect(() => {
    mounted.current = true;
    const unsubscribe = network.subscribe(value => { generation.current++; if (mounted.current) setState(value); });
    const appState = AppState.addEventListener("change", value => { if (value === "active") void refresh(); });
    void refresh();
    return () => { mounted.current = false; generation.current++; unsubscribe(); appState.remove(); };
  }, [refresh]);
  const change = useCallback(async (mode: Mode | "stop") => {
    if (locked.current) return;
    locked.current = true; setBusy(true); setError(null); generation.current++;
    try {
      if (mode === "stop") await network.stop(); else await network.start(mode);
      await refresh();
    } catch (error) {
      if (mounted.current) setError(error instanceof Error ? error.message : "The VPN could not be changed. Check its signing permissions.");
    } finally {
      locked.current = false; if (mounted.current) setBusy(false);
    }
  }, [refresh]);
  return { state, busy, error, refresh, change };
}
