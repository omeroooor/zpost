# Z-Post: Web3 Social Media Platform

Z-Post is a decentralized social media application built on Web3 principles, allowing users to create, share, and import/export posts with content ownership verification through content hashing.

## Features

- **Decentralized Content Ownership**: Posts are cryptographically signed and verified using content hashing
- **Post Import/Export**: Support for the W3-S-POST-NFT standard format for content portability
- **Media Support**: Share images and videos with automatic validation and checksum verification
- **User Authentication**: Secure login with public key cryptography
- **Social Interactions**: Follow other users and view personalized content feeds
- **Content Sorting**: Sort posts by date or reputation points
- **Search Functionality**: Find specific posts with the built-in search feature
- **Reputation System**: Posts can earn reputation points from the community

## Technical Details

- Built with Flutter for cross-platform compatibility
- Uses content hashing for data integrity verification
- Implements the W3-S-POST-NFT standard for content interoperability
- Supports media file validation and secure storage
- Backend API integration with authentication token management

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK
- An account on a Z-Post compatible server

### Installation

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Configure the API endpoint in `lib/services/post_service.dart`
4. Run the app using `flutter run`

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the terms of the MIT license.
