// SPDX-License-Identifier: SimPL-2.0
pragma solidity >=0.8.x <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

struct Parameters {
    address sellTokenAddress;
    address buyTokenAddress;
    uint8 buyTokenDecimals;
    bool buyTokenIsNative;
    uint256 raiseTotal;
    uint256 buyPrice;
    uint16 swapPercent;
    uint16 sellTax;
    uint256 maxBuyAmount;
    uint16 maxSellPercent;
    address teamWallet;
}

contract CrowdfundingFactory is Ownable {

    address[] private crowdfundingContracts;

    event CrowdfundingCreated(address _childContract, Parameters _paras);

    function createCrowdfundingContract(address _sellToken, address _buyToken, uint256 _raiseTotal,
        uint256 _buyPrice, uint16 _swapPercent, uint16 _sellTax,
        uint256 _maxBuyAmount, uint16 _maxSellPercent, address _teamWallet) public {

        Parameters memory paras = Parameters({sellTokenAddress: _sellToken,
        buyTokenAddress: _buyToken,
        buyTokenDecimals: 18,
        buyTokenIsNative: true,
        raiseTotal: _raiseTotal,
        buyPrice: _buyPrice,
        swapPercent: _swapPercent,
        sellTax: _sellTax,
        maxBuyAmount: _maxBuyAmount,
        maxSellPercent: _maxSellPercent,
        teamWallet: address(_teamWallet)});

        require(_sellToken != address(0), "Sell token address is zero");
        require(_buyToken != address(0), "Buy token address is zero");

        if (paras.sellTokenAddress != paras.buyTokenAddress) {
            paras.buyTokenIsNative = false;
            paras.buyTokenDecimals = ERC20(paras.buyTokenAddress).decimals();
        }

        IERC20 sellToken = IERC20(paras.sellTokenAddress);
        uint256 sellTokenDeposit = paras.raiseTotal / (10 ** paras.buyTokenDecimals) * paras.buyPrice / 100 * (10 ** ERC20(paras.sellTokenAddress).decimals());
        require(sellToken.allowance(msg.sender, address(this)) >= sellTokenDeposit, "Allowance is insuffcient");
        Crowdfunding newCrowdfunding = new Crowdfunding(msg.sender, sellTokenDeposit, paras);
        require(sellToken.transferFrom(msg.sender, address(newCrowdfunding), sellTokenDeposit), "TransferFrom error");

        crowdfundingContracts.push(address(newCrowdfunding));
        emit CrowdfundingCreated(address(newCrowdfunding), paras);
    }

    function getDeployedCrowdfundingContracts() public view returns (address[] memory) {
        return crowdfundingContracts;
    }
}

contract Crowdfunding is Ownable {
    using SafeMath for uint;
    address public factory;
    address public founder;
    uint256 public sellTokenDeposit;
    Parameters public paras;

    event Created(address factory, address founder, Parameters paras);

    constructor(address _founder, uint256 _depositTotal, Parameters memory _paras) {
        factory = msg.sender;
        founder = _founder;
        sellTokenDeposit = _depositTotal;
        paras = _paras;
        emit Created(factory, founder, paras);
    }

    function info() public view returns (uint256 _sellTokenDeposit, uint256 _sellTokenBalance) {
        return (sellTokenDeposit, IERC20(paras.sellTokenAddress).balanceOf(address(this)));
    }
}