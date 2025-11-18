import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useContracts } from '../hooks/useContracts';
import { useAccount } from 'wagmi';
import { formatEther } from 'viem';

interface CreatorCardProps {
  creatorAddress: `0x${string}`;
  isFeatured?: boolean;
}

export function CreatorCard({ creatorAddress, isFeatured }: CreatorCardProps) {
  const contracts = useContracts();
  const { address: userAddress } = useAccount();

  
  const { data: priceData } = useReadContract({
    address: contracts.subscriptionManager.address,
    abi: contracts.subscriptionManager.abi,
    functionName: 'creatorPrices',
    args: [creatorAddress],
  });

  const price = priceData as bigint | undefined;

 
  const { data: isSubscribedData } = useReadContract({
    address: contracts.subscriptionManager.address,
    abi: contracts.subscriptionManager.abi,
    functionName: 'isSubscribed',
    args: userAddress ? [userAddress, creatorAddress] : undefined,
  });

  const isSubscribed = isSubscribedData as boolean | undefined;

  const { writeContract, data: hash } = useWriteContract();
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({ hash });

  const handleSubscribe = () => {
    if (!price) return;
    
    writeContract({
      address: contracts.subscriptionManager.address,
      abi: contracts.subscriptionManager.abi,
      functionName: 'subscribe',
      args: [creatorAddress],
      value: price, 
    });
  };

  return (
    <div className={`bg-white border rounded-lg p-6 ${isFeatured ? 'border-blue-300' : 'border-gray-200'}`}>
        <h2 className="text-xl font-bold mb-4">Creator: {creatorAddress}</h2>
        <p className="mb-4">Subscription Price: {price ? `${formatEther(price)} ETH` : 'Loading...'}</p>
        <button
          onClick={handleSubscribe}
          disabled={isSubscribed || isConfirming || !price}
          className={`px-4 py-2 rounded ${isSubscribed ? 'bg-gray-400 cursor-not-allowed' : 'bg-blue-500 text-white hover:bg-blue-600'}`}
        >
          {isSubscribed ? 'Subscribed' : isConfirming ? 'Processing...' : 'Subscribe'}
        </button>
    </div>
  );
}