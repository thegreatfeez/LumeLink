# 🌟 LumeLink

> A decentralized creator subscription platform powered by Base blockchain and Chainlink VRF

[![Live Demo](https://img.shields.io/badge/demo-live-success)](https://lumlnk.netlify.app/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.30-blue)](https://soliditylang.org/)
[![Base Sepolia](https://img.shields.io/badge/Base-Sepolia-0052FF)](https://base.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 🎯 Overview

LumeLink is a next-generation Web3 subscription platform that connects creators with their audiences through blockchain technology. Built on Base (L2), it features a unique weekly spotlight system powered by Chainlink VRF for fair and transparent creator discovery.

**Live Platform:** [https://lumlnk.netlify.app/](https://lumlnk.netlify.app/)

## ✨ Key Features

### For Creators 🎨
- **Decentralized Subscriptions**: Set your own monthly subscription price (minimum 0.01 ETH)
- **90% Revenue Share**: Keep 90% of subscription fees, with 10% platform fee
- **Weekly Spotlight**: Get featured through Chainlink VRF's verifiable random selection
- **Profile Management**: IPFS-stored creator profiles with social media links
- **Direct Payments**: Instant payment settlement to your wallet

### For Subscribers 💫
- **Monthly Subscriptions**: Support your favorite creators with recurring payments
- **Discover Content**: Browse featured creators in the weekly spotlight
- **Transparent Pricing**: Clear subscription fees with no hidden costs
- **Wallet Integration**: Seamless connection via RainbowKit

### Platform Features 🔧
- **Chainlink VRF Integration**: Provably fair random selection for weekly spotlights
- **Weighted Selection Algorithm**: Creators who haven't been featured recently have higher chances
- **Treasury System**: Automated fee collection and management
- **Multi-Dashboard Interface**: Separate experiences for users, creators, and platform owners

## 🏗️ Architecture

### Smart Contracts

#### CreatorRegistry.sol
Manages creator registration and profile metadata.

```solidity
- registerCreator(string memory _profileMetadataURI)
- isCreator(address _addr) → bool
- getAllCreators() → address[]
- updateLastFeatured(address _creator)
```

#### SubscriptionManager.sol
Handles subscription payments and tracking.

```solidity
- setSubscriptionPrice(uint256 _price)
- subscribe(address _creator) payable
- isSubscribed(address _subscriber, address _creator) → bool
- getSubscriptionExpiry(address _subscriber, address _creator) → uint256
```

#### SpotlightSelector.sol
Implements Chainlink VRF v2.5 for random creator selection.

```solidity
- requestRandomWinner() → uint256
- getCurrentFeatured() → address[]
- canRequestSelection() → bool
- SELECTION_INTERVAL: 7 days
- FEATURED_SLOTS: 5
```

#### Treasury.sol
Manages platform fee collection and withdrawal.

```solidity
- receiveFee(address _creator) payable
- withdraw()
- withdrawTo(address _recipient, uint256 _amount)
- getBalance() → uint256
```

## 🚀 Getting Started

### Prerequisites

- Node.js v18 or higher
- MetaMask or compatible Web3 wallet
- Base Sepolia ETH (for testnet)

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/lumelink.git
cd lumelink
```

2. **Install frontend dependencies**
```bash
cd frontend
npm install
```

3. **Configure environment variables**
Create a `.env` file in the frontend directory:
```env
VITE_WALLETCONNECT_PROJECT_ID=your_walletconnect_project_id
VITE_PINATA_JWT=your_pinata_jwt_token
```

4. **Start the development server**
```bash
npm run dev
```

Visit `http://localhost:5173` to see the application.

## 📦 Smart Contract Deployment

### Deployed Contracts (Base Sepolia)

| Contract | Address |
|----------|---------|
| CreatorRegistry | `0x1b8a69D579877dc77174cbd56eA828D6Ded09E10` |
| Treasury | `0x0503E8e4836A718c4C25136C196ecA2A97b58d57` |
| SubscriptionManager | `0x151F2A002a2BA6a0dfF5a6Dd37015178d0c00203` |
| SpotlightSelector | `0x89E2F9e4Cce357057f99C4CB4BE3c8c016552D47` |

### Chainlink VRF Configuration

- **VRF Coordinator**: `0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE`
- **Key Hash**: `0x9e1344a1247c8a1785d0a4681a27152bffdb43666ae5bf7d14d24a5efd44bf71`
- **Subscription ID**: `6856904613366688233394896328050563800370039002518480924542370413492177404693`

### Deploy Your Own

1. **Install Foundry**
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. **Deploy contracts**
```bash
cd smartcontract
forge build
forge script script/Deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC --broadcast --verify
```

3. **Update deployment configuration**
Update `frontend/src/contracts/deployments/base-sepolia.json` with your new contract addresses.

## 🛠️ Technology Stack

### Blockchain
- **Smart Contracts**: Solidity 0.8.30
- **Development Framework**: Foundry
- **Network**: Base (L2) - Sepolia Testnet
- **Oracle**: Chainlink VRF v2.5

### Frontend
- **Framework**: React 18 + TypeScript
- **Styling**: Tailwind CSS
- **Web3 Integration**: wagmi + viem
- **Wallet Connect**: RainbowKit
- **Routing**: React Router v6
- **State Management**: TanStack Query

### Infrastructure
- **Storage**: IPFS (Pinata)
- **Hosting**: Netlify
- **RPC**: Base Sepolia RPC

## 📱 User Flows

### Creator Registration Flow
```
1. Connect wallet → 2. Click "Register Now" → 3. Fill profile form
→ 4. Metadata uploaded to IPFS → 5. Transaction signed
→ 6. Creator registered on-chain → 7. Access Creator Studio
```

### Subscription Flow
```
1. Browse creators → 2. View creator profile → 3. Click "Subscribe"
→ 4. Approve transaction (payment) → 5. Subscription active for 30 days
→ 6. 90% sent to creator, 10% to treasury
```

### Spotlight Selection Flow
```
1. Weekly timer expires → 2. Anyone calls requestRandomWinner()
→ 3. Chainlink VRF generates random number → 4. Weighted selection algorithm runs
→ 5. Top 5 creators selected → 6. Featured creators displayed
```

## 🔐 Security Features

- **ReentrancyGuard**: Protection against reentrancy attacks on Treasury
- **Access Control**: Owner-only functions for sensitive operations
- **Input Validation**: Comprehensive checks on all user inputs
- **Minimum Price Enforcement**: 0.001 ETH minimum subscription price
- **Chainlink VRF**: Tamper-proof randomness for fair selection

## 🧪 Testing

Run the smart contract test suite:

```bash
cd smartcontract
forge test
forge test -vvv # Verbose output
forge coverage # Coverage report
```

## 📊 Gas Optimization

The contracts are optimized for gas efficiency:
- Immutable variables for constant addresses
- Efficient storage patterns
- Minimal external calls
- Batched operations where possible

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **Live Platform**: [https://lumlnk.netlify.app/](https://lumlnk.netlify.app/)
- **Base Sepolia Explorer**: [https://sepolia.basescan.org/](https://sepolia.basescan.org/)
- **Chainlink VRF Docs**: [https://docs.chain.link/vrf](https://docs.chain.link/vrf)
- **Base Documentation**: [https://docs.base.org/](https://docs.base.org/)

## 👥 Team

Built with ❤️ by the LumeLink team

## 🙏 Acknowledgments

- Chainlink for VRF infrastructure
- Base team for L2 scaling solution
- OpenZeppelin for secure contract libraries
- The Ethereum community

## 📞 Support

For questions or support:
- Open an issue on GitHub
- Contact the team via [your contact method]

---

**⚠️ Disclaimer**: This is a testnet deployment. Do not use real funds on production contracts without thorough auditing.
