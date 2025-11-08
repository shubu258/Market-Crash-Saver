// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Using the Brownie package path available in this workspace
// Brownie package path for Chainlink contracts
import "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract MarketInvest is Pausable, Ownable{

    enum MarketType { MarketCrash, NaturalDisaster, StablePleg }

    struct buyMarketPolicy{
        uint256 policyId;
        address user;
        MarketType marketType,
        uint256 depositAmount;
        uint256 lastDeosited;
        bool claimActive;
        uint256 expiry;
    }
    uint256 public policyCount;
    mapping(uint256 => buyMarketPolicy) public marketPolicy;

    event marketPolicyPurchased(
        uint256 policyId,
        MarketType marketType,
        address user,
        uint256 depositAmount,
        uint256 lastDeosited,
        bool claimActive,
        uint256 expiry
    );

    event investedInPolicy(
        uint256 policyId
        address user,
        uint256 depositAmount,
        uint256 lastDeosited,
        bool claimActive,
        uint256 expiry
    );

    event claimed(uint256);

    error timePassed(uint256 lastDeposited );
    error cannotClain(bool claimActive );

    uint256 public constant MARKET_MONTHLY_SUBSCRIPTION = 1 ether;


    uint256 public constant MONTHLY_FEE = 100;
    uint256 public constant TOTAL_BPS = 10_000;

    mapping(address => bool) public claimActive;

    // Chainlink price feed
    AggregatorV3Interface public priceFeed;

    // Constructor sets the Chainlink feed and the contract owner.
    // If you want the deployer to be owner, remove the _owner param.
    constructor(address _aggregator, address _owner) {
        require(_aggregator != address(0), "aggregator zero");
        require(_owner != address(0), "owner zero");

        priceFeed = AggregatorV3Interface(_aggregator);

        // Transfer ownership to the provided owner address.
        // Use internal transfer to avoid calling the external onlyOwner-protected function.
        _transferOwnership(_owner);
    }

    function buyMarketPolicy(uint256 expiry, marketType mType) external payable {
        address user = msg.sender;
        require(msg.value == MARKET_MONTHLY_SUBSCRIPTION, "Msg.value is not equal to monthly SUBSCRIPTION");
        require(expiry > block.timestamp, "expiry must be in the future");

        uint256 fees = (msg.value * MONTHLY_FEE) / TOTAL_BPS;
        uint256 netAmount = msg.value - fees;

        (bool sentFee, ) = payable(owner()).call{value: fees}("");
        require(sentFee, "fee transfer failed");

        policyCount++;

        marketPolicy[policyCount] = buyMarketPolicy({
            marketType: marketTypeInfo,
            policyId: policyCount,
            user: user,
            depositAmount: netAmount,
            lastDeosited: block.timestamp,
            claimActive: true,
            expiry: expiry
        });

        emit marketPolicyPurchased(
            policyId,
            marketType,
            user,
            netAmount,
            block.timestamp,
            true,
            expiry
        );
    }

    function investPolicy(uint256 policyId) external payable {
        require(msg.value == MARKET_MONTHLY_SUBSCRIPTION, "money dosent align");
        require( block.timestamp >= marketPolicy[policyId].expiry);
        require(policyId > 0 && marketPolicy[policyId].user != address(0),"policy dosent exist");
        require(marketPolicy[policyId].user == msg.sender, "not policy owner");

        uint256 fees = (msg.value * MONTHLY_FEE) / TOTAL_BPS;
        uint256 netAmount = msg.value - fees;

        (bool sentFee, ) = payable(owner()).call{value: fees}("");
        require(sentFee, "fee transfer failed");

        marketPolicy[policyId].depositedAmount += netAmount;
        marketPolicy[policyId].lastDeosited = block.timestamp;

        emit investedInPolicy(
            marketPolicy[policyId].marketType,
            marketPolicy[policyId].user,
            marketPolicy[policyId].depositAmount, 
            block.timestamp, 
            marketPolicy[policyId].claimActive, 
            marketPolicy[policyId].expiry
        );
    }

}
