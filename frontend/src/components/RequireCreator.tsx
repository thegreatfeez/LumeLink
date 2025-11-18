import { useAccount } from "wagmi";
import { useIsCreator } from "../hooks/useIsCreator";

export default function RequireCreator({
  children,
}: {
  children: React.ReactNode;
}) {
  const { address } = useAccount();
  const { isCreator, isLoading } = useIsCreator(address);

  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center h-full">
        <h2 className="text-2xl font-semibold mb-4">
          Checking Creator Status...
        </h2>
      </div>
    );
  }

  if (!isCreator) {
    return (
      <div className="flex flex-col items-center justify-center h-full">
        <h2 className="text-2xl font-semibold mb-4">Access Denied</h2>
        <p className="mb-6 text-center">
          You must be a registered creator to access this feature.
        </p>
      </div>
    );
  }

  return <>{children}</>;
}
