interface CreatorMetadata {
  name: string;
  bio: string;
  social: {
    twitter: string;
    instagram: string;
    youtube: string;
    website: string;
  };
  createdAt: string;
}

export async function uploadToIPFS(metadata: CreatorMetadata): Promise<string> {
  const JWT = import.meta.env.VITE_PINATA_JWT;

  if (!JWT) {
    throw new Error("Pinata JWT not configured");
  }

  try {
    const response = await fetch(
      "https://api.pinata.cloud/pinning/pinJSONToIPFS",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${JWT}`,
        },
        body: JSON.stringify({
          pinataContent: metadata,
          pinataMetadata: {
            name: `${metadata.name}-profile`,
          },
        }),
      }
    );

    if (!response.ok) {
      throw new Error(`Pinata upload failed: ${response.statusText}`);
    }

    const data = await response.json();
    return `ipfs://${data.IpfsHash}`;
  } catch (error) {
    console.error("IPFS upload error:", error);
    throw error;
  }
}

export async function fetchFromIPFS(ipfsUri: string): Promise<CreatorMetadata | null> {
  try {
    const ipfsHash = ipfsUri.replace("ipfs://", "");
    const gatewayUrl = `https://gateway.pinata.cloud/ipfs/${ipfsHash}`;

    const response = await fetch(gatewayUrl);
    
    if (!response.ok) {
      throw new Error(`IPFS fetch failed: ${response.statusText}`);
    }

    return await response.json();
  } catch (error) {
    console.error("IPFS fetch error:", error);
    return null;
  }
}