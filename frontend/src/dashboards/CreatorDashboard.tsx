import {
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { useContracts } from "../hooks/useContracts";
import { useAccount } from "wagmi";
import { useState } from "react";
import { parseEther, formatEther } from "viem";

export function CreatorDashboard() {
  const contracts = useContracts();
  const { address } = useAccount();
  const [priceInput, setPriceInput] = useState<string>("0.01");

  const { data: currentPriceData } = useReadContract({
    address: contracts.subscriptionManager.address,
    abi: contracts.subscriptionManager.abi,
    functionName: "creatorPrices",
    args: address ? [address] : undefined,
  });

  const currentPrice = currentPriceData as bigint | undefined;

  const { data: earningsData } = useReadContract({
    address: contracts.treasury.address,
    abi: contracts.treasury.abi,
    functionName: "creatorFeeContributions",
    args: address ? [address] : undefined,
  });

  const earnings = earningsData as bigint | undefined;

  const { writeContract, data: hash } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const handleSetPrice = () => {
    if (!priceInput || parseFloat(priceInput) < 0.01) return;

    writeContract({
      address: contracts.subscriptionManager.address,
      abi: contracts.subscriptionManager.abi,
      functionName: "setSubscriptionPrice",
      args: [parseEther(priceInput)],
    });
  };

  return (
    <div className="space-y-8">
      <section className="bg-white rounded-lg shadow-sm border border-gray-200 p-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-3">
          Creator Studio
        </h1>
        <p className="text-gray-600 text-lg">
          Manage your subscription price, track earnings, and view your
          subscribers.
        </p>
      </section>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-medium text-gray-600">
              Subscription Price
            </h3>
            <span className="text-2xl">💰</span>
          </div>
          <p className="text-3xl font-bold text-gray-900">
            {currentPrice ? formatEther(currentPrice) : "0"} ETH
          </p>
          <p className="text-sm text-gray-500 mt-1">Monthly subscription fee</p>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-medium text-gray-600">
              Total Subscribers
            </h3>
            <span className="text-2xl">👥</span>
          </div>
          <p className="text-3xl font-bold text-gray-900">0</p>
          <p className="text-sm text-gray-500 mt-1">Active subscriptions</p>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-medium text-gray-600">
              Total Earnings
            </h3>
            <span className="text-2xl">💸</span>
          </div>
          <p className="text-3xl font-bold text-gray-900">
            {earnings ? formatEther(earnings) : "0"} ETH
          </p>
          <p className="text-sm text-gray-500 mt-1">90% of subscription fees</p>
        </div>
      </div>

      <section className="bg-white rounded-lg shadow-sm border border-gray-200 p-8">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">
          Set Subscription Price
        </h2>

        <div className="max-w-md space-y-4">
          <div>
            <label
              htmlFor="price"
              className="block text-sm font-medium text-gray-700 mb-2"
            >
              Monthly Price (ETH)
            </label>
            <input
              id="price"
              type="number"
              step="0.01"
              min="0.01"
              value={priceInput}
              onChange={(e) => setPriceInput(e.target.value)}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="0.01"
              disabled={isConfirming}
            />
            <p className="text-sm text-gray-500 mt-2">
              Minimum price: 0.01 ETH. You receive 90% of each subscription.
            </p>
          </div>

          <button
            onClick={handleSetPrice}
            disabled={
              isConfirming ||
              !priceInput ||
              parseFloat(priceInput) < 0.01
            }
            className="w-full px-6 py-3 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isConfirming ? "Confirming..." : "Set Price"}
          </button>

          {isSuccess && (
            <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
              <p className="text-green-800 text-sm font-medium">
                Price updated successfully!
              </p>
            </div>
          )}
        </div>
      </section>

      <section className="bg-white rounded-lg shadow-sm border border-gray-200 p-8">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">
          Recent Subscribers
        </h2>
        <div className="text-center py-12">
          <div className="text-5xl mb-4">📊</div>
          <h3 className="text-xl font-semibold text-gray-900 mb-2">
            Subscriber tracking coming soon
          </h3>
          <p className="text-gray-600">
            We're building detailed subscriber analytics for you.
          </p>
        </div>
      </section>
    </div>
  );
}