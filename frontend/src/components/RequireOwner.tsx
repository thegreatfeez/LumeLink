import { useAccount } from "wagmi";
import { useIsOwner } from "../hooks/useIsOwner";

export default function RequireOwner({
  children,
}: {
  children: React.ReactNode;
}) {
  const { address } = useAccount();
  const { isOwner, isLoading } = useIsOwner(address);

  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center h-full">
        <h2 className="text-2xl font-semibold mb-4">
          Checking Owner Status...
        </h2>
      </div>
    );
  }

  if (!isOwner) {
    return (
      <div className="flex flex-col items-center justify-center h-full">
        <h2 className="text-2xl font-semibold mb-4">Access Denied</h2>
        <p className="mb-6 text-center">
          You must be the contract owner to access this feature.
        </p>
      </div>
    );
  }

  return <>{children}</>;
}
