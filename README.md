## Overview

This repository contains Foundry tests to validate the correct behavior of the proposal lifecycle with the Compound Governor.

This effort originates as the result of a [user-submitted document](https://docs.google.com/document/d/1KWtygfO02vUJ20yY8QKfBJGZMbi8FFDmlCIcoY4iEbg/edit) which states that the protocol's ownership is at risk without much effort.

The disclosure states that with 4% of the total supply of COMP tokens, a malicious actor can take over the `admin` role that corresponds to the Governor. However, this is the expected behavior of the governor, and the situation can only happen if the sum of "against" votes cannot match 4% of the total supply. As seen, there are several holders that possess more than 4%, meaning that it is highly unlikely they will ignore this voting as it goes against their interests.

### Tested cases

The behavior was tested and divided into different situations:

- `testNotReaching25kProposal`: the attacker tries to submit the proposal without having the required minimum of 25,000 COMP tokens to present and it fails.
- `testNotReaching400kProposal`: the attacker can make the proposal (> 25,000 COMP tokens) but they cannot reach the minimum required after voting to pass the proposal, failing after trying to queue it into the Timelock contract.
- `testReaching400kRejectedProposal`: the attacker gets the 4% needed to pass a proposal, but other holders participate in the voting stage overtaking and rejecting the malicious proposal.
- `test400kAttackerWithHelp`: the attacker gets the 4% needed to pass a proposal, and other holders vote in favor of passing the proposal. In this case, the proposal is passed successfully and the attacker becomes the `admin` of the Timelock contract.
- `testReaching400kPassedProposal`: this is the case mentioned in the disclosure document with no other user votes against the malicious proposal in the entire voting stage. The proposal passes when the attacker has 4% of the total supply.

## How to run it

1. Clone the repository

`git clone git@github.com:OpenZeppelin/XXX.git`

2. Export the RPC_URL env var

Because this test requires forking the Ethereum Mainnet, you will need a valid RPC Endpoint. You can get a free RPC URL from Alchemy or Infura.

`export RPC_URL=https://eth-mainnet.g.alchemy.com/v2/<Your Token>`

3. Run it

`forge test --fork-url $RPC_URL --fork-block-number 16984765`

In this case, we've fixed the block to `16984765` to preserve the balances of the accounts used for testing different scenarios.
