import { useReadContract } from "wagmi";
import { useContracts } from "./useContracts";

export function useIsOwner(userAddress?: `0x${string}` | undefined) {
  const contracts = useContracts();

  const { data, isLoading } = useReadContract({
    address: contracts.treasury.address,
    abi: contracts.treasury.abi,
    functionName: "owner",
  });

  const ownerAddress = data as `0x${string}` | undefined;

  const isOwner =
    ownerAddress !== undefined && userAddress !== undefined
      ? ownerAddress.toLowerCase() === userAddress.toLowerCase()
      : false;

  return {
    isOwner,
    isLoading,
  };
}
