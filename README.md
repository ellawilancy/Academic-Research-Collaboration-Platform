# Academic Research Collaboration Platform

A decentralized platform for managing academic research collaboration using Clarity smart contracts on the Stacks blockchain.

## Overview

This platform consists of five interconnected smart contracts that facilitate academic research collaboration:

1. **Researcher Verification Contract** - Validates academic credentials and institutional affiliations
2. **Research Proposal Contract** - Manages funding applications and approval processes
3. **Data Sharing Agreement Contract** - Controls access permissions for research data
4. **Peer Review Management Contract** - Handles academic paper review workflows
5. **Publication Rights Contract** - Manages research publication and citation tracking

## Features

### Researcher Verification
- Academic credential validation
- Institutional affiliation tracking
- Reputation scoring system
- Profile management

### Research Proposals
- Funding application submission
- Multi-stage approval workflow
- Budget tracking
- Milestone management

### Data Sharing
- Granular access control
- Usage tracking
- Compliance monitoring
- Audit trails

### Peer Review
- Anonymous reviewer assignment
- Review submission and tracking
- Consensus mechanisms
- Quality assurance

### Publication Rights
- Authorship management
- Citation tracking
- Copyright handling
- Revenue distribution

## Contract Architecture

Each contract operates independently without cross-contract calls, ensuring modularity and security. The contracts use native Clarity data types and functions for optimal performance.

## Getting Started

### Prerequisites
- Clarinet CLI
- Node.js and npm
- Stacks wallet for testing

### Installation

\`\`\`bash
git clone <repository-url>
cd academic-research-platform
npm install
\`\`\`

### Testing

\`\`\`bash
npm test
\`\`\`

### Deployment

\`\`\`bash
clarinet deploy
\`\`\`

## Contract Details

### Error Codes
- ERR-NOT-AUTHORIZED (u100)
- ERR-INVALID-INPUT (u101)
- ERR-NOT-FOUND (u102)
- ERR-ALREADY-EXISTS (u103)
- ERR-INSUFFICIENT-FUNDS (u104)

### Data Types
- Principal addresses for user identification
- Unsigned integers for IDs and amounts
- String ASCII for text data
- Tuples for structured data
- Maps for key-value storage

## Usage Examples

### Registering as a Researcher
\`\`\`clarity
(contract-call? .researcher-verification register-researcher
"Dr. Jane Smith"
"MIT"
"Computer Science"
"jane.smith@mit.edu")
\`\`\`

### Submitting a Research Proposal
\`\`\`clarity
(contract-call? .research-proposal submit-proposal
"AI Ethics Research"
"Investigating ethical implications of AI"
u50000)
\`\`\`

## Security Considerations

- All contracts implement proper authorization checks
- Input validation prevents malicious data
- State changes are atomic and consistent
- Access controls protect sensitive operations

## Contributing

Please read our contributing guidelines and submit pull requests for any improvements.

## License

This project is licensed under the MIT License.
