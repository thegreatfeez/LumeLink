import {
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { useContracts } from "../hooks/useContracts";
import { useAccount, useConfig } from "wagmi";
import { useIsCreator } from "../hooks/useIsCreator";
import { Link } from "react-router-dom";
import { CreatorCard } from "../components/CreatorCard";
import { useState, useEffect } from "react";
import { readContract } from "@wagmi/core";
import { uploadToIPFS } from "../utils/ipfs";

export function UserDashboard() {
  const contracts = useContracts();
  const config = useConfig();
  const { address } = useAccount();
  const { isCreator } = useIsCreator(address);
  const [showRegistrationModal, setShowRegistrationModal] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [formData, setFormData] = useState({
    name: "",
    bio: "",
    twitter: "",
    instagram: "",
    youtube: "",
    website: "",
  });
 
  const { data, isLoading } = useReadContract({
    address: contracts.creatorRegistry.address,
    abi: contracts.creatorRegistry.abi,
    functionName: "getAllCreators",
  });

  const creators = data as readonly `0x${string}`[] | undefined;

  const { data: featuredData, isLoading: isFeaturedLoading } = useReadContract({
    address: contracts.spotlightSelector.address,
    abi: contracts.spotlightSelector.abi,
    functionName: "getCurrentFeatured",
  });
  const featuredCreators = featuredData as readonly `0x${string}`[] | undefined;

  const [mySubscriptions, setMySubscriptions] = useState<readonly `0x${string}`[]>([]);

  useEffect(() => {
    if (!creators || !address) {
      setMySubscriptions([]);
      return;
    }

    const checkSubscriptions = async () => {
      const subscribed: `0x${string}`[] = [];
      
      for (const creatorAddress of creators) {
        try {
          const isSubscribed = await readContract(config, {
            address: contracts.subscriptionManager.address,
            abi: contracts.subscriptionManager.abi,
            functionName: "isSubscribed",
            args: [address, creatorAddress],
          });
          
          if (isSubscribed) {
            subscribed.push(creatorAddress);
          }
        } catch (error) {
          console.error(`Error checking subscription for ${creatorAddress}:`, error);
        }
      }
      
      setMySubscriptions(subscribed);
    };

    checkSubscriptions();
  }, [creators, address, contracts.subscriptionManager, config]);

  const { writeContract, data: hash } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const handleRegisterClick = () => {
    setShowRegistrationModal(true);
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value,
    });
  };

  const handleRegister = async () => {
    if (!formData.name.trim()) {
      alert("Please enter your name");
      return;
    }

    setIsUploading(true);

    try {
      const metadata = {
        name: formData.name,
        bio: formData.bio,
        social: {
          twitter: formData.twitter,
          instagram: formData.instagram,
          youtube: formData.youtube,
          website: formData.website,
        },
        createdAt: new Date().toISOString(),
      };

      const ipfsUri = await uploadToIPFS(metadata);

      writeContract({
        address: contracts.creatorRegistry.address,
        abi: contracts.creatorRegistry.abi,
        functionName: "registerCreator",
        args: [ipfsUri],
      });
      
      setShowRegistrationModal(false);
      setFormData({
        name: "",
        bio: "",
        twitter: "",
        instagram: "",
        youtube: "",
        website: "",
      });
      setIsUploading(false);
    } catch (error) {
      setIsUploading(false);
      alert("Failed to register. Please try again.");
      console.error(error);
    }
  };

  const handleCloseModal = () => {
    setShowRegistrationModal(false);
    setFormData({
      name: "",
      bio: "",
      twitter: "",
      instagram: "",
      youtube: "",
      website: "",
    });
  };

  return (
    <div className="space-y-8">
      <section className="bg-white rounded-lg shadow-sm border border-gray-200 p-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-3">
          Discover Creators
        </h1>
        <p className="text-gray-600 text-lg">
          Support your favorite creators with monthly subscriptions. Get
          featured in the weekly spotlight powered by Chainlink VRF.
        </p>
      </section>

      {!isCreator && (
        <section className="bg-blue-50 border border-blue-200 rounded-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-xl font-semibold text-gray-900 mb-2">
                Are you a creator?
              </h2>
              <p className="text-gray-600">
                Join LumeLink, set your subscription price, and get featured in
                our weekly spotlight.
              </p>
            </div>
            <button
              onClick={handleRegisterClick}
              disabled={isConfirming}
              className="px-6 py-3 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed whitespace-nowrap"
            >
              {isConfirming ? "Check Wallet..." : "Register Now"}
            </button>
          </div>
          {isSuccess && (
            <div className="mt-4 p-4 bg-green-50 border border-green-200 rounded-lg">
              <p className="text-green-800 text-sm font-medium">
                Registration successful! Refresh to see your Creator Dashboard
                link.
              </p>
            </div>
          )}
        </section>
      )}

      {isCreator && (
        <section className="bg-green-50 border border-green-200 rounded-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-xl font-semibold text-gray-900 mb-2">
                Welcome back, Creator!
              </h2>
              <p className="text-gray-600">
                Manage your profile, subscribers, and earnings in your Creator
                Studio.
              </p>
            </div>
            <Link
              to="/creator"
              className="px-6 py-3 bg-white border border-gray-300 text-gray-900 font-medium rounded-lg hover:bg-gray-50 transition-colors whitespace-nowrap"
            >
              Open Creator Studio →
            </Link>
          </div>
        </section>
      )}

      {showRegistrationModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg p-8 max-w-lg w-full max-h-[90vh] overflow-y-auto">
            <h3 className="text-2xl font-bold text-gray-900 mb-2">
              Create Your Creator Profile
            </h3>
            <p className="text-gray-600 mb-6">
              Share your information so subscribers can discover and connect with you.
            </p>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Name *
                </label>
                <input
                  type="text"
                  name="name"
                  value={formData.name}
                  onChange={handleInputChange}
                  placeholder="Your creator name"
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Bio
                </label>
                <textarea
                  name="bio"
                  value={formData.bio}
                  onChange={handleInputChange}
                  placeholder="Tell your audience about yourself..."
                  rows={3}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Twitter/X
                </label>
                <input
                  type="text"
                  name="twitter"
                  value={formData.twitter}
                  onChange={handleInputChange}
                  placeholder="@username or profile link"
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Instagram
                </label>
                <input
                  type="text"
                  name="instagram"
                  value={formData.instagram}
                  onChange={handleInputChange}
                  placeholder="@username or profile link"
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  YouTube
                </label>
                <input
                  type="text"
                  name="youtube"
                  value={formData.youtube}
                  onChange={handleInputChange}
                  placeholder="Channel name or link"
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Website
                </label>
                <input
                  type="text"
                  name="website"
                  value={formData.website}
                  onChange={handleInputChange}
                  placeholder="https://yourwebsite.com"
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={handleCloseModal}
                disabled={isUploading}
                className="flex-1 px-6 py-3 bg-gray-200 text-gray-900 font-medium rounded-lg hover:bg-gray-300 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Cancel
              </button>
              <button
                onClick={handleRegister}
                disabled={isUploading}
                className="flex-1 px-6 py-3 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isUploading ? "Uploading..." : "Register"}
              </button>
            </div>
          </div>
        </div>
      )}

      <section>
        <div className="flex items-center justify-between mb-6">
          <div>
            <h2 className="text-2xl font-bold text-gray-900">
              Featured Creators
            </h2>
            <p className="text-sm text-gray-600 mt-1">
              This week's spotlight winners - selected by Chainlink VRF
            </p>
          </div>
        </div>

        {isFeaturedLoading && (
          <div className="flex items-center justify-center py-12">
            <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-blue-600"></div>
          </div>
        )}

        {!isFeaturedLoading &&
          (!featuredCreators || featuredCreators.length === 0) && (
            <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
              <div className="text-5xl mb-4">🌟</div>
              <h3 className="text-xl font-semibold text-gray-900 mb-2">
                No featured creators yet
              </h3>
              <p className="text-gray-600 mb-6">
                Check back later to see which creators have been spotlighted
                this week.
              </p>
            </div>
          )}

        {!isFeaturedLoading &&
          featuredCreators &&
          featuredCreators.length > 0 && (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {featuredCreators.map((creatorAddress) => (
                <CreatorCard
                  key={creatorAddress}
                  creatorAddress={creatorAddress}
                  isFeatured
                />
              ))}
            </div>
          )}
      </section>

      {address && (
        <section>
          <div className="flex items-center justify-between mb-6">
            <div>
              <h2 className="text-2xl font-bold text-gray-900">
                My Subscriptions
              </h2>
              <p className="text-sm text-gray-600 mt-1">
                Creators you're currently supporting
              </p>
            </div>
            {mySubscriptions && mySubscriptions.length > 0 && (
              <span className="text-sm text-gray-500">
                {mySubscriptions.length} subscription
                {mySubscriptions.length !== 1 ? "s" : ""}
              </span>
            )}
          </div>

          {isLoading && (
            <div className="flex items-center justify-center py-12">
              <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-blue-600"></div>
            </div>
          )}

          {!isLoading &&
            (!mySubscriptions || mySubscriptions.length === 0) && (
              <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
                <div className="text-5xl mb-4">💫</div>
                <h3 className="text-xl font-semibold text-gray-900 mb-2">
                  No subscriptions yet
                </h3>
                <p className="text-gray-600">
                  Subscribe to featured creators above to support them and get
                  exclusive access.
                </p>
              </div>
            )}

          {!isLoading && mySubscriptions && mySubscriptions.length > 0 && (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {mySubscriptions.map((creatorAddress) => (
                <CreatorCard
                  key={creatorAddress}
                  creatorAddress={creatorAddress}
                />
              ))}
            </div>
          )}
        </section>
      )}
    </div>
  );
}