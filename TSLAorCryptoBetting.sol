// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// import statement for chainlink price feed
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// import statement for chainlink rng
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT WHICH USES HARDCODED VALUES FOR CLARITY.
 * PLEASE DO NOT USE THIS CODE IN PRODUCTION.
 */

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */
 
contract RandomNumberConsumer is VRFConsumerBase {
    
    // variables to be used by chainlink
    bytes32 internal keyHash;
    uint256 internal fee;
    // variable for the random number that is generated
    uint256 public randomResult;
    
    /**
     * Constructor inherits VRFConsumerBase
     * 
     * Network: Rinkeby Test Net
     * Chainlink VRF Coordinator address: 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B
     * LINK token address:                0x01BE23585060835E02B77ef475b0Cc51aA1e0709
     * Key Hash: 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311
     */
    constructor() 
        VRFConsumerBase(
            0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B, // VRF Coordinator
            0x01BE23585060835E02B77ef475b0Cc51aA1e0709  // LINK Token
        )
    {
        keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
        fee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network)
    }
    
    /** 
     * Requests randomness 
     */
    function getRandomNumber() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
    }
}

/**
* Contract that calls the random number generator and sets the random number to be the gambler's funds
* The gambler can then use those funds to bet on what the price of an asset is and will recieve or lose
* funds depending on how accurate the bet was
**/
contract PriceConsumerV3 is RandomNumberConsumer {

    /**
     * Live Price Feed
    */
    AggregatorV3Interface internal priceFeed;

    /**
     * How much the player has to bet
    */
    uint public playerFunds = 0;

    /**
    * Mapping for the assets to their oracle addresses
    */
    mapping(string => address) private assetAddresses;

    /**
     * Percent of holdings that a player bets
    */
    int public percentOfHoldings;

    /**
     * Predicted Asset Price
     */
    int public predictedAssetPrice;

    /**
     * Amount Player is betting
     */
    uint public betAmount;

    /**
     * Asset player is betting on
     */
    string public asset;

    /**
     * Latest Price
     */
    int public latestPrice;

    /**
     * Percent difference between two inputted values
     */
    int public valuesPercentDifference;

    /**
     * Riskiness of players bet
    */
    string public riskiness;

    /**
     * Percent difference in Actual and Expected price
     */
    int public pricePercentDifference;
    
    /**
     *  Contructor: populates dictionary that maps assets to addresses,
     * and initilizes the price feed
     */
    constructor() {
        priceFeed = AggregatorV3Interface(address(0));
        assetAddresses["ETH"] = 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e;
        assetAddresses["BTC"] = 0xECe365B379E1dD183B20fc5f022230C044d51404;
        assetAddresses["OIL"] = 0x6292aA9a6650aE14fbf974E5029f36F95a1848Fd;
        assetAddresses["BAT"] = 0x031dB56e01f82f20803059331DC6bEe9b17F7fC9;
        assetAddresses["DAI"] = 0x2bA49Aaa16E6afD2a993473cfB70Fa8559B523cF;
        assetAddresses["LTC"] = 0x4d38a35C2D87976F334c2d2379b535F1D461D9B4;
        assetAddresses["EUR"] = 0x78F9e60608bF48a1155b4B2A5e31F32318a1d85F;
        assetAddresses["LINK"] = 0xd8bD0a1cB028a31AA859A21A3758685a95dE4623;
        assetAddresses["GBP"] = 0x7B17A813eEC55515Fb8F49F2ef51502bC54DD40F;
        assetAddresses["XRP"] = 0xc3E76f41CAbA4aB38F00c7255d4df663DA02A024;
    }

    /**
     *  Checks for a valid bet amount
     */
    modifier validBet (uint _amount) {
        require(_amount > 0 && playerFunds >= _amount, "Invalid Bet");
        _;
    }

    /**
    * Calls random number from RNG class and converts it to a num in the hundreds
    */
    function setPlayerFunds() public {
        playerFunds = randomResult/10**74;
    }

    /**
     *  Places bet
     */
    function placeBet(int _prediction, string calldata _asset, uint _betAmount) public 
    validBet(_betAmount) {
        // assign gamblers predicted price, bet, and asset
        predictedAssetPrice = _prediction;
        betAmount = _betAmount;
        asset = _asset;
        // call function to get latest asset price from chainlink
        latestPrice = getLatestPrice();
        // call function to distribute the prize based on the bet outcome
        calculatePrize();
    }

    /**
     * Returns the latest price using chainlink oracle
     */
    function getLatestPrice() private returns (int) {
        // grabs the assets addr from the dictionary and passes it to the price feed
        address assetAddr = assetAddresses[asset];
        priceFeed = AggregatorV3Interface(assetAddr);
        // info needed by chainlink
        (
            uint80 roundID, 
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        // converts price to an int
        return price/10**8;
    }

    /**
     * finds the absolute value of the truncated percent difference between 2 values
     */
    function percentDifference(int _value1, int _value2) private returns(int) {
        valuesPercentDifference = ((_value1 - _value2)*100)/(_value2);
        valuesPercentDifference = valuesPercentDifference >= 0 ? valuesPercentDifference : -valuesPercentDifference;
        return valuesPercentDifference;
    }

    /**
     * Calculates Prize
     */
    function calculatePrize() private {
        // find the percentage of their holdings that they're betting
        percentOfHoldings = 100 - percentDifference(int(betAmount), int(playerFunds));
        //find the percentage difference between their bet and actual price
        pricePercentDifference = percentDifference(latestPrice, predictedAssetPrice);

        // Insane risk Bet
        if (percentOfHoldings == 100) {
            riskiness = "Insane";
            // If bet is within 5% of actual, award 2 times their bet
            if (pricePercentDifference <= 5) {
                playerFunds += betAmount*2;
            }
            // if bet is within 5-10% off, net gain is nothing
            // If bet is over 10% off, gambler loses their bet
            else if (pricePercentDifference > 10) {
                playerFunds -= betAmount;
            }
        }
        // Large risk bet
        else if (percentOfHoldings < 100 && percentOfHoldings >= 66) {
            riskiness = "Large";
            // If bet is within 5% of actual, award 1.5 times their bet
            if (pricePercentDifference <= 5) {
                playerFunds += (betAmount*3)/2;
            }
            // if bet is within 5-10% off, net gain is nothing
            // If bet is over 10% off, gambler loses their bet
            else if (pricePercentDifference > 10) {
                playerFunds -= betAmount;
            }
        }
        // Moderate risk bet
        else if (percentOfHoldings < 66 && percentOfHoldings >= 33) {
            riskiness = "Moderate";
            // If bet is within 5% of actual, award 1.25 times their bet
            if (pricePercentDifference <= 5) {
                playerFunds += (betAmount*5)/4;
            }
            // if bet is within 5-10% off, net gain is nothing
            // If bet is over 10% off, gambler loses their bet
            else if (pricePercentDifference > 10) {
                playerFunds -= betAmount;
            }
        }
        // Low risk bet
        else {
            riskiness = "Low";
            // If bet is within 5% of actual, award 1 times their bet
            if (pricePercentDifference <= 5) {
                playerFunds += betAmount;
            }
            // if bet is within 5-10% off, net gain is nothing
            // If bet is over 10% off, gambler loses their bet
            else if (pricePercentDifference > 10) {
                playerFunds -= betAmount;
            }
        }
    }

}