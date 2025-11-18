import { WagmiProvider } from "wagmi";
import { RainbowKitProvider } from "@rainbow-me/rainbowkit";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import "@rainbow-me/rainbowkit/styles.css";
import { config } from "./wagmi.config";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { Layout } from "./components/Layout";
import RequireWallet from "./components/RequireWallet";
import RequireCreator from "./components/RequireCreator";
import RequireOwner from "./components/RequireOwner";
import { UserDashboard } from "./dashboards/UserDashboard";
import { CreatorDashboard } from "./dashboards/CreatorDashboard";
import { TreasuryDashboard } from "./dashboards/TreasuryDashboard";

const queryClient = new QueryClient();

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          <BrowserRouter>
            <Layout>
              <Routes>
                <Route
                  path="/"
                  element={
                    <RequireWallet>
                      <UserDashboard />
                    </RequireWallet>
                  }
                />
                <Route
                  path="/creator"
                  element={
                    <RequireWallet>
                      <RequireCreator>
                        <CreatorDashboard />
                      </RequireCreator>
                    </RequireWallet>
                  }
                />
                <Route
                  path="/treasury"
                  element={
                    <RequireWallet>
                      <RequireOwner>
                        <TreasuryDashboard />
                      </RequireOwner>
                    </RequireWallet>
                  }
                />
              </Routes>
            </Layout>
          </BrowserRouter>
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}

export default App;
