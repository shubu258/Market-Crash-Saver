// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Using the Brownie package path available in this workspace
// Brownie package path for Chainlink contracts
import "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract MarketInvest is Pausable, Ownable {
    /**
     * @title MarketInvest
     * @notice A simple insurance-like contract where users can buy policies against different market events
     *         (market crash, natural disaster, stablecoin depeg). Policies are purchased by paying a
     *         monthly subscription and may be claimed when the configured conditions are met.
     * @dev  This contract stores policy records in a mapping keyed by a numeric policy id (policyCount).
     *       All monetary transfers use the recommended call pattern (.call). Functions assume the caller
     *       provides correctly-typed inputs; the frontend should present friendly UI but the contract
     *       enforces correctness via enum checks and require statements. NatSpec here documents inputs,
     *       effects and emitted events for each public/external function.
     */
    /// @notice Enumeration of supported market event types for a policy.
    /// @dev Use these values when creating or filtering policies. Stored in each policy record as `marketType`.
    ///      The frontend should map human-friendly labels to these enum values before calling the contract.
    enum MarketType {
        MarketCrash,
        NaturalDisaster,
        StablePleg
    }

    /**
     * @dev Structure that stores a purchased market policy's data.
     * @param policyId      Unique identifier for the policy (mapping key = policyCount)
     * @param user          Address that owns the policy and may claim it
     * @param marketType    Market event type this policy covers (see MarketType)
     * @param depositAmount Net amount (in wei) deposited for the policy after fees
     * @param lastDeosited  Timestamp of the last deposit/payment for the policy (used for subscription checks)
     * @param claimActive   Flag indicating whether policy is active/claimable
     * @param expiry        Unix timestamp when the policy expires
     */
    struct buyMarketPolicy {
        uint256 policyId;
        address user;
        MarketType marketType;
        uint256 depositAmount;
        uint256 lastDeosited;
        bool claimActive;
        uint256 expiry;
    }

    /// @notice Total number of policies created. New policies increment this counter and use the new value as their id.
    uint256 public policyCount;
    /// @notice Mapping from policyId to the stored buyMarketPolicy struct.
    /// @dev Use marketPolicy[policyId].user to obtain the owner for a given policy id.
    mapping(uint256 => buyMarketPolicy) public marketPolicy;

    /// @notice Emitted when a new market policy is successfully purchased
    /// @param policyId The numeric id assigned to the newly created policy
    /// @param marketType The MarketType associated with the policy
    /// @param user The address that purchased the policy
    /// @param depositAmount Net amount stored in the policy (after fees)
    /// @param lastDeosited Timestamp when the policy was created
    /// @param claimActive Whether the policy is active
    /// @param expiry Expiration timestamp of the policy
    event marketPolicyPurchased(
        uint256 policyId,
        MarketType marketType,
        address user,
        uint256 depositAmount,
        uint256 lastDeosited,
        bool claimActive,
        uint256 expiry
    );

    /// @notice Emitted when an owner tops-up or invests additional funds into an existing policy
    /// @param policyId The id of the policy receiving the funds
    /// @param user The policy owner who invested
    /// @param depositAmount Updated depositAmount after the investment
    /// @param lastDeosited Timestamp when the top-up occurred
    /// @param claimActive Policy active flag after the investment
    /// @param expiry Policy expiry timestamp
    event investedInPolicy(
        uint256 policyId, address user, uint256 depositAmount, uint256 lastDeosited, bool claimActive, uint256 expiry
    );

    /// @notice Emitted when a claim attempt fails because the current market price did not meet the configured threshold
    /// @param marketPrice The price read from the oracle
    /// @param thresholdPrice The configured threshold that was required for a successful claim
    event priceNotReachedThreshold(uint256 marketPrice, uint256 thresholdPrice);

    /// @notice Emitted when a claim payout is issued to a policy owner
    /// @param payAmount The amount of ETH paid to the claimant
    event claimed(uint256 payAmount);

    event naturalHazardIsNotAchived(string);

    /// @notice Error thrown when an action is attempted after a time window has passed
    /// @param lastDeposited Timestamp of last deposit used in the time check
    error timePassed(uint256 lastDeposited);

    /// @notice Error thrown when a claim is attempted while claimActive is false
    /// @param claimActive The current claimActive boolean value
    error cannotClain(bool claimActive);

    /// @notice Fixed monthly subscription amount (in wei) required to purchase or top-up a policy
    uint256 public constant MARKET_MONTHLY_SUBSCRIPTION = 1 ether;
    /// @notice The duration that constitutes one subscription period (used to validate last payment freshness)
    uint256 public constant MONTH_TIME = 30 days;
    /// @notice The minimum market price threshold used in claim evaluation (example value in wei)
    uint256 public constant MIN_MARKET_CLAIM = 0.5 ether;
    /// @notice BNB token address used for price feed queries in market crash claims
    address public constant BNB_ADDRESS = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;

    /// @notice Minimum water level threshold for natural disaster claims (below this triggers payout)
    uint256 public constant MIN_WWATERFALL = 20;
    /// @notice Maximum water level threshold for natural disaster claims (above this triggers payout)
    uint256 public constant MAX_WATERFALL = 100;

    /// @notice Minimum stablecoin peg ratio (0.97 = $0.97) - below this triggers depeg claims
    uint256 public constant MIN_STABLE_COIN_PEG = 0.97;
    /// @notice USDT token address used for stablecoin depeg price feed queries
    address public constant USDT_ADDRESS = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;

    /// @notice Fee configuration: MONTHLY_FEE expressed in basis points out of TOTAL_BPS
    uint256 public constant MONTHLY_FEE = 100;
    uint256 public constant TOTAL_BPS = 10_000;

    /// @notice Quick lookup mapping to show whether a given address currently has claim rights
    /// @dev This mapping can be used to mute or disable claims for addresses if required by admin logic
    mapping(address => bool) public claimActive;

    /// @notice Aggregator interface for price data (Chainlink)
    /// @dev Use `priceFeed.latestRoundData()` to obtain the current price and timestamps
    AggregatorV3Interface public priceFeed;

    /**
     * @notice Initializes the contract with a Chainlink price feed and sets the contract owner.
     * @param _aggregator Address of the Chainlink AggregatorV3Interface to read market prices from.
     * @param _owner Address which will be set as the contract owner (receive fees and admin actions).
     * @dev The constructor validates inputs and assigns `priceFeed`. Ownership is transferred using
     *      the internal `_transferOwnership` call to avoid calling external-onlyOwner functions.
     */
    constructor(address _aggregator, address _owner) {
        require(_aggregator != address(0), "aggregator zero");
        require(_owner != address(0), "owner zero");

        priceFeed = AggregatorV3Interface(_aggregator);

        // Transfer ownership to the provided owner address.
        // Use internal transfer to avoid calling the external onlyOwner-protected function.
        _transferOwnership(_owner);
    }

    /**
     * @notice Purchase a new policy for a specified market event type.
     * @param expiry Unix timestamp when the policy should expire (must be in the future).
     * @param mType The MarketType enum value selecting which risk the policy covers.
     *
     * @dev Behavior and effects:
     *  - Caller MUST send exactly `MARKET_MONTHLY_SUBSCRIPTION` in `msg.value`.
     *  - The function computes `fees = (msg.value * MONTHLY_FEE) / TOTAL_BPS` and forwards `fees` to `owner()`.
     *  - The remaining `netAmount = msg.value - fees` is stored on the new policy record as `depositAmount`.
     *  - `policyCount` is incremented and used as the policy id; policy stored at `marketPolicy[policyCount]`.
     *  - Emits `marketPolicyPurchased(policyId, marketType, user, depositAmount, lastDeosited, claimActive, expiry)`.
     *
     * @reverts
     *  - if `msg.value != MARKET_MONTHLY_SUBSCRIPTION` (exact subscription required)
     *  - if `expiry <= block.timestamp` (expiry must be in the future)
     *  - if fee transfer to `owner()` fails
     */
    function buyMarketPolicy(uint256 expiry, marketType mType) external payable {
        address user = msg.sender;
        require(msg.value == MARKET_MONTHLY_SUBSCRIPTION, "Msg.value is not equal to monthly SUBSCRIPTION");
        require(expiry > block.timestamp, "expiry must be in the future");

        uint256 fees = (msg.value * MONTHLY_FEE) / TOTAL_BPS;
        uint256 netAmount = msg.value - fees;

        (bool sentFee,) = payable(owner()).call{value: fees}("");
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

        emit marketPolicyPurchased(policyId, marketType, user, netAmount, block.timestamp, true, expiry);
    }

    /**
     * @notice Top-up or renew an existing policy by paying the monthly subscription.
     * @param policyId The id of the policy to invest in.
     *
     * @dev Behavior and effects:
     *  - Caller MUST be the policy owner (`marketPolicy[policyId].user == msg.sender`).
     *  - Caller MUST send `MARKET_MONTHLY_SUBSCRIPTION` as `msg.value` (current deposit model).
     *  - The function deducts `fees = (msg.value * MONTHLY_FEE) / TOTAL_BPS` and forwards them to `owner()`.
     *  - `netAmount = msg.value - fees` is added to `marketPolicy[policyId].depositAmount` and `lastDeosited` is updated.
     *  - Emits `investedInPolicy(policyId, user, depositAmount, lastDeosited, claimActive, expiry)`.
     */
    function investPolicy(uint256 policyId) external payable {
        require(msg.value == MARKET_MONTHLY_SUBSCRIPTION, "money dosent align");
        require(block.timestamp <= marketPolicy[policyId].expiry, "TIMESTAMP PASSED");
        require(policyId > 0 && marketPolicy[policyId].user != address(0), "policy dosent exist");
        require(marketPolicy[policyId].user == msg.sender, "not policy owner");

        uint256 fees = (msg.value * MONTHLY_FEE) / TOTAL_BPS;
        uint256 netAmount = msg.value - fees;

        (bool sentFee,) = payable(owner()).call{value: fees}("");
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

    /**
     * @notice Attempt to claim a payout for a MarketCrash policy.
     * @param policyId The id of the policy to claim against.
     *
     * @dev Full behavior:
     *  - Validates that the policy is active (`claimActive == true`) and the caller is the policy owner.
     *  - Confirms the `marketType` is `MarketType.MarketCrash` (this function is specific to crash claims).
     *  - Ensures the most recent subscription payment (`lastDeosited`) is within `MONTH_TIME` (i.e. user paid this month).
     *  - Reads the Chainlink price from `priceFeed.latestRoundData()` and checks `updatedAt` freshness.
     *  - If the price condition (e.g. `price < MIN_MARKET_CLAIM`) is met then:
     *      - computes `payAmount` (example logic: `2 * depositAmount`), zeroes stored deposit and marks policy inactive,
     *      - transfers `payAmount` to the claimant and emits `claimed(payAmount)`.
     *  - Otherwise emits `priceNotReachedThreshold(price, MIN_MARKET_CLAIM)` and leaves policy state unchanged (or marks inactive depending on logic).
     */
    function claimMarketCrash(uint256 policyId) external {
        require(marketPolicy[policyId].claimActive == true, "Claim Not avilable");
        require(marketPolicy[policyId].user == msg.sender, "not a policy owner");
        require(marketPolicy[policyId].marketType == MarketType.MarketCrash);

        if (block.timestamp - marketPolicy[policyId].lastDeosited <= MONTH_TIME) {
            (, uint256 price,, uint256 updatedAt,) = priceFeed.latestRoundData(BNB_ADDRESS);
            require(block.timestamp - updatedAt < MONTH_TIME, "NOT A CORRECT TIME TO CLAIM");
            if (price < MIN_MARKET_CLAIM) {
                uint256 amount = marketPolicy[policyId].depositAmount;
                uint256 payAmount = 2 * amount;
            } else {
                emit priceNotReachedThreshold(price, MIN_MARKET_CLAIM);
            }

            marketPolicy[policyId].depositAmount = 0;
            marketPolicy[policyId].claimActive = false;
        } else {
            marketPolicy[policyId].claimActive = false;
        }

        (bool success,) = payable(msg.sender).call{value: payAmount}("");
        require(success, "Pay Failed");

        emit claimed(payAmount);
    }

    /**
     * @notice Claim payout for a NaturalDisaster policy based on water level conditions.
     * @param waterlevel Current water level measurement to evaluate against thresholds.
     * @param policyId The id of the NaturalDisaster policy to claim against.
     * @dev Validates policy ownership, active status, and type. Checks if waterlevel is outside
     *      the safe range (MIN_WWATERFALL to MAX_WATERFALL). If conditions are met, pays 2x
     *      the deposit amount and deactivates the policy. Emits claimed or naturalHazardIsNotAchived.
     */
    function claimNaturalClamity(uint256 waterlevel, uint256 policyId) external {
        require(marketPolicy[policyId].user == msg.sender, "Not a Policy Owner");
        require(marketPolicy[policyId].claimActive == true, "CLAIM NOT ACTIVE");
        require(marketPolicy[policyId].marketType == MarketType.NaturalDisaster);

        if (block.timestamp - marketPolicy[policyId].lastDeosited <= MONTH_TIME) {
            if (waterlevel <= MIN_WWATERFALL || waterlevel >= MAX_WATERFALL) {
                uint256 amount = marketPolicy[policyId].depositAmount;
                uint256 payAmount = 2 * amount;

                marketPolicy[policyId].depositAmount = 0;
                marketPolicy[policyId].claimActive = false;
            } else {
                emit naturalHazardIsNotAchived("Market Hazard Not Arrived");
            }
        } else {
            marketPolicy[policyId].claimActive = false;
        }

        (bool ok,) = payable(msg.sender).call{value: payAmount}("");
        require(success, "pay failed");

        emit claimed(payAmount);
    }

    /**
     * @notice Claim payout for a StablePleg policy when stablecoin depegs below threshold.
     * @param policyId The id of the StablePleg policy to claim against.
     * @dev Validates policy ownership, active status, and StablePleg type. Reads USDT price
     *      from Chainlink oracle and checks if it's below MIN_STABLE_COIN_PEG (0.97). If depegged,
     *      pays 2x deposit amount and deactivates policy. Requires recent subscription payment.
     *      Emits claimed on success or priceNotReachedThreshold if peg is maintained.
     */
    function claimStableCoinPeg(uint256 policyId) external {
        require(marketPolicy[policyId].claimActive == true, "Claim Not avilable");
        require(marketPolicy[policyId].user == msg.sender, "not a policy owner");
        require(marketPolicy[policyId].marketType == MarketType.StablePleg);

        if (block.timestamp - marketPolicy[policyId].lastDeosited <= MONTH_TIME) {
            (, uint256 price,, uint256 updatedAt,) = priceFeed.latestRoundData(USDT_ADDRESS);
            require(block.timestamp - updatedAt < MONTH_TIME, "NOT A CORRECT TIME TO CLAIM");

            if (price < MIN_STABLE_COIN_PEG) {
                uint256 amount = marketPolicy[policyId].depositAmount;
                uint256 payAmount = 2 * amount;
            } else {
                emit priceNotReachedThreshold(price, MIN_STABLE_COIN_PEG);
            }

            marketPolicy[policyId].depositAmount = 0;
            marketPolicy[policyId].claimActive = false;
        } else {
            marketPolicy[policyId].claimActive = false;
        }

        (bool success,) = payable(msg.sender).call{value: payAmount}("");
        require(success, "Pay Failed");

        emit claimed(payAmount);
    }

    /**
     * @notice Withdraw all ETH balance from the contract to the owner.
     * @dev Only the contract owner can call this function. Transfers the entire
     *      contract balance (address(this).balance) to the owner address using
     *      the safe call pattern. Useful for collecting accumulated fees and funds.
     */
    function withdraw() external onlyOwner {
        uint256 payAmount = address(this).balance;
        (bool ok,) = payable(owner()).call{value: payAmount}("");
        require(ok, "failed");
    }

    /**
     * @notice Pause the contract to stop all policy purchases and claims.
     * @dev Only the contract owner can call this function. When paused, all functions
     *      with whenNotPaused modifier will revert. Useful for emergency stops or maintenance.
     *      Emits Paused event from OpenZeppelin Pausable contract.
     */
    function pauseContract() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract to resume normal operations.
     * @dev Only the contract owner can call this function. Restores normal functionality
     *      for all policy-related operations. Should only be called after resolving any
     *      issues that caused the pause. Emits Unpaused event from OpenZeppelin Pausable.
     */
    function unpauseContract() external onlyOwner {
        _unpause();
    }
}
