import CreatorRegistry from "../contracts/abis/CreatorRegistry.json";
import Treasury from "../contracts/abis/Treasury.json";
import SubscriptionManager from "../contracts/abis/SubscriptionManager.json";
import SpotlightSelector from "../contracts/abis/SpotlightSelector.json";
import deployment from "../contracts/deployments/base-sepolia.json";

export function useContracts() {
  return {
    creatorRegistry: {
      address: deployment.contracts.CreatorRegistry as `0x${string}`,
      abi: CreatorRegistry.abi,
    },
    treasury: {
      address: deployment.contracts.Treasury as `0x${string}`,
      abi: Treasury.abi,
    },
    subscriptionManager: {
      address: deployment.contracts.SubscriptionManager as `0x${string}`,
      abi: SubscriptionManager.abi,
    },
    spotlightSelector: {
      address: deployment.contracts.SpotlightSelector as `0x${string}`,
      abi: SpotlightSelector.abi,
    },

    chainId: deployment.chainId,
  };
}
