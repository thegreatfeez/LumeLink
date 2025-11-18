import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { baseSepolia } from "wagmi/chains";
import { http } from "viem";

export const config = getDefaultConfig({
  appName: "LumeLink",
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID,
  chains: [baseSepolia],
  transports: {
    [baseSepolia.id]: http(),
  },
});
