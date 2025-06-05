# 🗺️ Guideme - Local Guide NFT Badges

> **Verified tourism guides with review NFTs on Stacks blockchain** ⭐

## 🌟 Overview

Guideme is a decentralized platform that connects tourists with verified local guides through blockchain technology. Guides receive NFT badges upon registration, and tourists can leave reviews that are minted as NFTs, creating a transparent and immutable reputation system.

## ✨ Features

- 🎫 **Guide NFT Badges**: Unique NFT badges for registered guides
- ⭐ **Review NFTs**: Tourist reviews minted as collectible NFTs  
- ✅ **Verification System**: Admin verification for trusted guides
- 📊 **Rating System**: 1-5 star rating with automatic average calculation
- 🔒 **One Review Per User**: Prevents spam and manipulation
- 💰 **Registration Fee**: Anti-spam mechanism with configurable fees
- 🏃‍♂️ **Guide Management**: Activate/deactivate guide profiles

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

```bash
git clone <your-repo>
cd guideme
clarinet check
```

## 📖 Usage Guide

### For Guides 👨‍🏫

#### 1. Register as a Guide
```clarity
(contract-call? .Guideme register-as-guide 
  "John Smith" 
  "Paris, France" 
  "Historical tours, Art museums, Food experiences")
```

#### 2. Update Your Profile
```clarity
(contract-call? .Guideme update-guide-profile 
  "John Smith - Expert Guide" 
  "Paris & Versailles, France" 
  "Historical tours, Art museums, Food & wine experiences")
```

#### 3. Manage Your Status
```clarity
;; Deactivate when unavailable
(contract-call? .Guideme deactivate-guide u1)

;; Reactivate when ready
(contract-call? .Guideme reactivate-guide u1)
```

### For Tourists 🧳

#### Leave a Review
```clarity
(contract-call? .Guideme submit-review 
  u1 
  u5 
  "Amazing tour! John showed us hidden gems in Paris that we never would have found ourselves.")
```

### For Admins 👑

#### Verify Guides
```clarity
(contract-call? .Guideme verify-guide u1)
```

#### Set Registration Fee
```clarity
(contract-call? .Guideme set-registration-fee u2000000)
```

## 🔍 Query Functions

### Get Guide Information
```clarity
;; Get guide by ID
(contract-call? .Guideme get-guide u1)

;; Get guide by owner address
(contract-call? .Guideme get-guide-by-owner 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Check if guide is verified
(contract-call? .Guideme is-guide-verified u1)

;; Get guide rating stats
(contract-call? .Guideme get-guide-rating u1)
```

### Get Review Information
```clarity
;; Get review by ID
(contract-call? .Guideme get-review u1)

;; Get user's review for specific guide
(contract-call? .Guideme get-user-review-for-guide 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
  u1)
```

## 🏗️ Contract Architecture

### NFT Collections
- **Guide Badges**: Unique identity tokens for registered guides
- **Review NFTs**: Collectible tokens representing tourist reviews

### Data Structure
- **Guides Map**: Stores guide profiles, ratings, and status
- **Reviews Map**: Stores review content and metadata
- **Lookup Maps**: Efficient querying and relationship mapping

### Key Features
- **Anti-spam Protection**: Registration fees and one-review-per-user limits
- **Reputation System**: Transparent rating calculation and history
- **Flexible Management**: Guides can manage their availability status

## 🛡️ Security Features

- ✅ Owner-only admin functions
- ✅ Input validation for ratings (1-5 scale)
- ✅ Duplicate review prevention
- ✅ Active guide status checks
- ✅ Proper error handling

## 🎯 Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Guide not found |
| u102 | Already registered |
| u103 | Invalid rating (must be 1-5) |
| u104 | Already reviewed this guide |
| u105 | Guide not active |
| u106 | Insufficient payment |

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License.

---


