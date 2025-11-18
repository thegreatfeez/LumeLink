import { useReadContract } from "wagmi";
import { useContracts } from "./useContracts";

export function useIsCreator(creatorAddress?: `0x${string}` | undefined) {
  const contracts = useContracts();

  const { data, isLoading } = useReadContract({
    address: contracts.creatorRegistry.address,
    abi: contracts.creatorRegistry.abi,
    functionName: "isCreator",
    args: creatorAddress ? [creatorAddress] : undefined,
  });

  return {
    isCreator: data ?? false,
    isLoading,
  };
}
