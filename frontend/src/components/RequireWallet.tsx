import { useAccount } from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";

export default function RequireWallet({
  children,
}: {
  children: React.ReactNode;
}) {
  const { isConnected } = useAccount();

  if (!isConnected) {
    return (
      <div className="flex flex-col items-center justify-center h-full">
        <h2 className="text-2xl font-semibold mb-4">Connect Your Wallet</h2>
        <p className="mb-6 text-center">
          To access this feature, please connect your cryptocurrency wallet.
        </p>
        <ConnectButton showBalance={false} />
      </div>
    );
  }

  return <>{children}</>;
}
