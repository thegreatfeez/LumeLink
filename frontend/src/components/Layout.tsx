import { ConnectButton } from "@rainbow-me/rainbowkit";
import { Link, useLocation } from "react-router-dom";
import { useAccount } from "wagmi";
import { useIsCreator } from "../hooks/useIsCreator";
import { useIsOwner } from "../hooks/useIsOwner";

interface LayoutProps {
  children: React.ReactNode;
}

export function Layout({ children }: LayoutProps) {
  const location = useLocation();
  const { address } = useAccount();
  const { isCreator } = useIsCreator(address);
  const { isOwner } = useIsOwner(address);

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <Link to="/" className="flex items-center space-x-2">
              <div className="w-8 h-8 flex items-center justify-center">
                <img src="lume.svg" alt="Lume" className="w-8 h-8" />
              </div>
              <span className="text-gray-900 font-semibold text-lg ml-2">
                LumeLink
              </span>
            </Link>

            <div className="flex items-center space-x-8">
              <Link
                to="/"
                className={`text-sm font-medium transition-colors ${
                  location.pathname === "/"
                    ? "text-blue-600"
                    : "text-gray-600 hover:text-gray-900"
                }`}
              >
                Discover
              </Link>

              {isCreator && (
                <Link
                  to="/creator"
                  className={`text-sm font-medium transition-colors ${
                    location.pathname === "/creator"
                      ? "text-blue-600"
                      : "text-gray-600 hover:text-gray-900"
                  }`}
                >
                  Creator Studio
                </Link>
              )}

              {isOwner && (
                <Link
                  to="/treasury"
                  className={`text-sm font-medium transition-colors ${
                    location.pathname === "/treasury"
                      ? "text-blue-600"
                      : "text-gray-600 hover:text-gray-900"
                  }`}
                >
                  Treasury
                </Link>
              )}

              <ConnectButton />
            </div>
          </div>
        </div>
      </nav>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {children}
      </main>

      <footer className="bg-white border-t border-gray-200 mt-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <p className="text-center text-gray-500 text-sm">
            © 2024 LumeLink. Powered by Base & Chainlink VRF
          </p>
        </div>
      </footer>
    </div>
  );
}
