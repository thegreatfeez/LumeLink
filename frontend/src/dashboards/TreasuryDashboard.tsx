import {
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { useContracts } from "../hooks/useContracts";
import { useAccount } from "wagmi";
import { useState } from "react";
import { parseEther, formatEther, isAddress } from "viem";

export function TreasuryDashboard() {
  const contracts = useContracts();
  const { address } = useAccount();
 
  const [showWithdrawAllModal, setShowWithdrawAllModal] = useState(false);
  const [recipientAddress, setRecipientAddress] = useState<string>("");
  const [withdrawAmount, setWithdrawAmount] = useState<string>("");

  const { data: totalFeesData } = useReadContract({
    address: contracts.treasury.address,
    abi: contracts.treasury.abi,
    functionName: "totalFeesCollected",
  });

  const { data: currentBalanceData } = useReadContract({
    address: contracts.treasury.address,
    abi: contracts.treasury.abi,
    functionName: "getBalance",
  });

  const { writeContract, data: hash } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const totalFees = totalFeesData as bigint | undefined;
  const currentBalance = currentBalanceData as bigint | undefined;

  const handleWithdrawAll = () => {
    if (!address) return;

    if (!currentBalance || currentBalance === 0n) {
      console.error("No balance");
      return;
    }

    writeContract({
      address: contracts.treasury.address,
      abi: contracts.treasury.abi,
      functionName: "withdraw",
    });
  };

  const handleWithdrawTo = () => {
    if (!address || !isAddress(recipientAddress)) {
      console.error("Invalid address");
      return;
    }

    const amountNum = Number(withdrawAmount);
    if (isNaN(amountNum) || amountNum <= 0) {
      console.error("Invalid amount");
      return;
    }

    writeContract({
      address: contracts.treasury.address,
      abi: contracts.treasury.abi,
      functionName: "withdrawTo",
      args: [recipientAddress, parseEther(withdrawAmount)],
    });
  };

  const handleOpenWithdrawAllModal = () => {
    setShowWithdrawAllModal(true);
  };

  const handleCloseWithdrawAllModal = () => {
    setShowWithdrawAllModal(false);
  };

  return (
    <div className="space-y-8">
      <section className="bg-white rounded-lg shadow-sm border border-gray-200 p-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-3">
          Treasury Dashboard
        </h1>
        <p className="text-gray-600 text-lg">
          Manage platform fees and withdraw funds. Only accessible by contract owner.
        </p>
      </section>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-medium text-gray-600">
              Total Fees Collected
            </h3>
            <span className="text-2xl">💰</span>
          </div>
          <p className="text-3xl font-bold text-gray-900">
            {totalFees ? formatEther(totalFees) : "0"} ETH
          </p>
          <p className="text-sm text-gray-500 mt-1">All-time platform revenue</p>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-medium text-gray-600">
              Current Balance
            </h3>
            <span className="text-2xl">💸</span>
          </div>
          <p className="text-3xl font-bold text-gray-900">
            {currentBalance ? formatEther(currentBalance) : "0"} ETH
          </p>
          <p className="text-sm text-gray-500 mt-1">Available to withdraw</p>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-medium text-gray-600">
              Contract Address
            </h3>
            <span className="text-2xl">📝</span>
          </div>
          <p className="text-sm font-mono text-gray-900 break-all">
            {contracts.treasury.address}
          </p>
          <p className="text-sm text-gray-500 mt-1">Treasury contract</p>
        </div>
      </div>

      <section className="bg-white rounded-lg shadow-sm border border-gray-200 p-8">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">
          Withdraw All Funds
        </h2>

        <div className="bg-red-50 border border-red-200 rounded-lg p-6 mb-6">
          <div className="flex items-start">
            <span className="text-2xl mr-3">⚠️</span>
            <div>
              <h3 className="text-lg font-semibold text-red-900 mb-1">
                Withdraw All Balance
              </h3>
              <p className="text-red-800 text-sm">
                This will transfer the entire treasury balance ({currentBalance ? formatEther(currentBalance) : "0"} ETH) to your wallet address.
              </p>
            </div>
          </div>
        </div>

        <button
          onClick={handleOpenWithdrawAllModal}
          disabled={isConfirming || !currentBalance || currentBalance === 0n}
          className="px-6 py-3 bg-red-600 text-white font-medium rounded-lg hover:bg-red-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isConfirming ? "Processing..." : "Withdraw All Funds"}
        </button>
      </section>

      <section className="bg-white rounded-lg shadow-sm border border-gray-200 p-8">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">
          Custom Withdrawal
        </h2>

        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
          <div className="flex items-start">
            <span className="text-xl mr-2">⚡</span>
            <p className="text-yellow-800 text-sm">
              <strong>Advanced:</strong> Send a specific amount to any address. Use with caution.
            </p>
          </div>
        </div>

        <div className="max-w-md space-y-4">
          <div>
            <label
              htmlFor="recipient"
              className="block text-sm font-medium text-gray-700 mb-2"
            >
              Recipient Address
            </label>
            <input
              id="recipient"
              type="text"
              value={recipientAddress}
              onChange={(e) => setRecipientAddress(e.target.value)}
              placeholder="0x..."
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-transparent font-mono text-sm"
              disabled={isConfirming}
            />
          </div>

          <div>
            <label
              htmlFor="amount"
              className="block text-sm font-medium text-gray-700 mb-2"
            >
              Amount (ETH)
            </label>
            <input
              id="amount"
              type="number"
              step="0.01"
              value={withdrawAmount}
              onChange={(e) => setWithdrawAmount(e.target.value)}
              placeholder="0.00"
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-transparent"
              disabled={isConfirming}
            />
            <p className="text-sm text-gray-500 mt-2">
              Available balance: {currentBalance ? formatEther(currentBalance) : "0"} ETH
            </p>
          </div>

          <button
            onClick={handleWithdrawTo}
            disabled={isConfirming}
            className="w-full px-6 py-3 bg-red-600 text-white font-medium rounded-lg hover:bg-red-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isConfirming ? "Confirming..." : "Withdraw Custom Amount"}
          </button>

          {isSuccess && (
            <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
              <p className="text-green-800 text-sm font-medium">
                Withdrawal successful!
              </p>
            </div>
          )}
        </div>
      </section>

      {showWithdrawAllModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg p-8 max-w-md w-full">
            <h3 className="text-2xl font-bold text-gray-900 mb-4">
              Confirm Withdrawal
            </h3>
            <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
              <p className="text-red-900 font-semibold mb-2">
                You are about to withdraw:
              </p>
              <p className="text-3xl font-bold text-red-900">
                {currentBalance ? formatEther(currentBalance) : "0"} ETH
              </p>
              <p className="text-red-800 text-sm mt-2">
                This will be sent to your wallet: {address}
              </p>
            </div>
            
            <div className="flex gap-3">
              <button
                onClick={handleCloseWithdrawAllModal}
                disabled={isConfirming}
                className="flex-1 px-6 py-3 bg-gray-200 text-gray-900 font-medium rounded-lg hover:bg-gray-300 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Cancel
              </button>
              <button
                onClick={handleWithdrawAll}
                disabled={isConfirming}
                className="flex-1 px-6 py-3 bg-red-600 text-white font-medium rounded-lg hover:bg-red-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isConfirming ? "Processing..." : "Confirm Withdrawal"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}