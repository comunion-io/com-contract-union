// SPDX-License-Identifier: SimPL-2.0
pragma solidity >=0.8.x <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

struct Parameters {
    address sellTokenAddress;
    address buyTokenAddress;
    uint8 sellTokenDecimals;
    uint8 buyTokenDecimals;
    bool buyTokenIsNative;
    uint256 raiseTotal;
    uint256 buyPrice;
    uint16 swapPercent;
    uint16 sellTax;
    uint256 maxBuyAmount;
    uint16 maxSellPercent;
    address teamWallet;
    uint256 startTime;
    uint256 endTime;
}

contract CrowdfundingFactory is Ownable {

    address[] private crowdfundingContracts;

    event CrowdfundingCreated(address crowdfunding, Parameters paras);

    function createCrowdfundingContract(address _sellToken, address _buyToken, uint256 _raiseTotal,
        uint256 _buyPrice, uint16 _swapPercent, uint16 _sellTax,
        uint256 _maxBuyAmount, uint16 _maxSellPercent, address _teamWallet,
        uint256 _startTime, uint256 _endTime) public {

        Parameters memory paras = Parameters({sellTokenAddress: _sellToken,
        buyTokenAddress: _buyToken,
        sellTokenDecimals: 18,
        buyTokenDecimals: 18,
        buyTokenIsNative: true,
        raiseTotal: _raiseTotal,
        buyPrice: _buyPrice,
        swapPercent: _swapPercent,
        sellTax: _sellTax,
        maxBuyAmount: _maxBuyAmount,
        maxSellPercent: _maxSellPercent,
        teamWallet: address(_teamWallet),
        startTime: _startTime,
        endTime: _endTime});

        require(_sellToken != address(0) && _buyToken != address(0), "Token address is zero");
        require(_buyPrice > 0, "Buy price is incorrect");

        IERC20 sellToken = IERC20(paras.sellTokenAddress);
        Crowdfunding newCrowdfunding = new Crowdfunding(address(this), msg.sender, paras);
        uint256 _deposit = newCrowdfunding.deposit();
        require(_deposit > 0, "Sell token deposit is zero");
        require(sellToken.balanceOf(msg.sender) >= _deposit, "Sell token balance is insufficient");
        require(sellToken.allowance(msg.sender, address(this)) >= _deposit, "Sell token allowance is insufficient");
        require(sellToken.transferFrom(msg.sender, address(newCrowdfunding), _deposit), "Sell token transferFrom failure");

        crowdfundingContracts.push(address(newCrowdfunding));
        emit CrowdfundingCreated(address(newCrowdfunding), paras);
    }

    function getDeployedCrowdfundingContracts() public view returns (address[] memory) {
        return crowdfundingContracts;
    }
}

contract Crowdfunding is Ownable {

    enum Status {
        Pending, Upcoming, Live, Ended, Cancel
    }

    IERC20 private sellToken;
    IERC20 private buyToken;
    address private factory;
    address private founder;
    uint256 private depositAmount;
    uint256 private buyTokenAmount;
    uint256 private swapPoolAmount;
    uint256 private sellTokenAmount;
    Parameters private paras;
    address payable private thisAccount;
    Status private status;

    struct PairAmount {
        uint256 buyAmount;
        uint256 sellAmount;
    }
    mapping(address => PairAmount) totals;
    mapping(address => PairAmount) amounts;

    event Created(address owner, address factory, address founder, uint256 deposit, Parameters paras);
    event Buy(address caller, uint256 buyAmount, uint256 sellAmount);
    event Sell(address caller, uint256 buyAmount, uint256 sellAmount);
    event Receive(address sender, string func);

    modifier isActive() {
        _checkActive();
        _;
    }

    modifier inTime() {
        _checkInTime();
        _;
    }

    modifier beforeStart() {
        _checkBeforeStart();
        _;
    }

    modifier canOver() {
        _checkCanOver();
        _;
    }

    constructor(address _factory, address _founder, Parameters memory _parameters) {
        factory = _factory;
        founder = _founder;
        paras = _parameters;
        status = _statusFromTime();
        sellToken = IERC20(paras.sellTokenAddress);
        paras.sellTokenDecimals = ERC20(paras.sellTokenAddress).decimals();
        if (paras.sellTokenAddress == paras.buyTokenAddress) {
            paras.buyTokenIsNative = true;
            paras.buyTokenDecimals = 18;
        } else {
            paras.buyTokenIsNative = false;
            paras.buyTokenDecimals = ERC20(paras.buyTokenAddress).decimals();
            buyToken = IERC20(paras.buyTokenAddress);
        }
        depositAmount = _calculateDeposit();
        sellTokenAmount = depositAmount;
        thisAccount = payable(address(this));
        transferOwnership(_founder);

        emit Created(owner(), factory, founder, depositAmount, paras);
    }

    function buy(uint256 _buyAmount, uint256 _sellAmount) public payable isActive inTime returns (bool) {
        require(_buyAmount != 0 && _sellAmount != 0, "Amount is zero");
        require(_checkPrice(_buyAmount, _sellAmount), "Price is mismatch");
        require(_checkMaxBuyAmount(msg.sender, _buyAmount), "Amount exceeds maximum");
        require(sellToken.balanceOf(thisAccount) >= _sellAmount, "Sell token balance is insufficient");

        uint256 _toPoolAmount = _toSwapPoolAmount(_buyAmount);
        if (paras.buyTokenIsNative) {
            require(msg.value == _buyAmount, "msg.value is not valid");
            require(msg.sender.balance >= _buyAmount, "Your balance is insufficient");
            (bool isSend,) = thisAccount.call{value: _buyAmount}("");
            require(isSend, "Transfer contract failure");
            (isSend,) = paras.teamWallet.call{value: _buyAmount-_toPoolAmount}("");
            require(isSend, "Transfer team failure");
        } else {
            require(buyToken.allowance(msg.sender, thisAccount) >= _buyAmount, "Your buy token allowance is insufficient");
            require(buyToken.balanceOf(msg.sender) >= _buyAmount, "Your buy token balance is insufficient");
            require(buyToken.transferFrom(msg.sender, thisAccount, _buyAmount), "Buy token transferFrom failure");
            require(buyToken.transfer(paras.teamWallet, _buyAmount-_toPoolAmount), "Buy token transfer team failure");
        }
        require(sellToken.transfer(msg.sender, _sellAmount), "Sell token transfer failure");

        buyTokenAmount += _buyAmount;
        sellTokenAmount -= _sellAmount;
        swapPoolAmount += _toPoolAmount;
        totals[msg.sender].buyAmount += _buyAmount;
        totals[msg.sender].sellAmount += _sellAmount;
        amounts[msg.sender].buyAmount += _buyAmount;
        amounts[msg.sender].sellAmount += _sellAmount;

        return true;
    }

    function sell(uint256 _buyAmount, uint256 _sellAmount) public payable isActive inTime returns (bool) {
        require(_buyAmount != 0 && _sellAmount != 0, "Amount is zero");
        require(_checkPrice(_buyAmount, _sellAmount), "Price is mismatch");
        require(_checkMaxSellAmount(msg.sender, _sellAmount), "Amount exceeds maximum");
        uint256 _buyAmountAfterTax = _amountAfterTax(_buyAmount);
        require(_buyBalance() >= _buyAmountAfterTax, "Balance is insufficient");

        require(sellToken.allowance(msg.sender, thisAccount) >= _sellAmount, "Your sell token allowance is insufficient");
        require(sellToken.balanceOf(msg.sender) >= _sellAmount, "Your sell token balance is insufficient");
        require(sellToken.transferFrom(msg.sender, thisAccount, _sellAmount), "Sell token transferFrom failure");
        if (paras.buyTokenIsNative) {
            require(thisAccount.balance >= _buyAmountAfterTax, "Balance is insufficient");
            (bool isSend,) = msg.sender.call{value: _buyAmountAfterTax}("");
            require(isSend, "Transfer buyer failure");
        } else {
            require(buyToken.balanceOf(thisAccount) >= _buyAmountAfterTax, "Buy token balance is insufficient");
            require(buyToken.transfer(msg.sender, _buyAmountAfterTax), "Buy token transfer buyer failure");
        }

        buyTokenAmount -= _buyAmount;
        sellTokenAmount += _sellAmount;
        swapPoolAmount -= _buyAmountAfterTax;
        amounts[msg.sender].buyAmount -= _buyAmount;
        amounts[msg.sender].sellAmount -= _sellAmount;

        return true;
    }

    receive() external payable {
        emit Receive(msg.sender, "receive");
    }

    function cancel() public onlyOwner isActive beforeStart {
        require(_refundSellToken(payable(paras.teamWallet)), "Refund sell token failure");
        status = Status.Cancel;
    }

    function remove() public onlyOwner isActive canOver {
        require(_refundBuyToken(payable(paras.teamWallet)), "Refund buy token failure");
        require(_refundSellToken(payable(paras.teamWallet)), "Refund sell token failure");
        status = Status.Ended;
    }

    function state() public view returns (uint256 _raiseTotal, uint256 _raiseAmount, uint256 _swapPoolAmount,
        uint256 _sellTokenDeposit, uint256 _sellTokenAmount,
        uint256 _myBuyTokenAmount, uint256 _mySellTokenAmount,
        uint256 _buyTokenBalance, uint256 _sellTokenBalance,
        Status _status) {
        uint256 _raiseBalance = thisAccount.balance;
        if (!paras.buyTokenIsNative) {
            _raiseBalance = buyToken.balanceOf(thisAccount);
        }
        return (paras.raiseTotal, buyTokenAmount, swapPoolAmount, depositAmount, sellTokenAmount,
        amounts[msg.sender].buyAmount, amounts[msg.sender].sellAmount, _raiseBalance,
        sellToken.balanceOf(thisAccount), status);
    }

    function account() public view returns (address _owner, address _factory, address _founder) {
        return (owner(), factory, founder);
    }

    function parameters() public view returns (Parameters memory _paras) {
        return paras;
    }

    function deposit() public view returns (uint256 _depositAmount) {
        return (depositAmount);
    }

    function maxBuyAmount() public view returns (uint256 _buyAmount, uint256 _sellAmount) {
        return _getBuyMaxAmount(msg.sender);
    }

    function maxSellAmount() public view returns (uint256 _buyAmount, uint256 _sellAmount) {
        return _getSellMaxAmount(msg.sender);
    }

    function buyTokenIsNative() public view returns (bool isNative) {
        return paras.buyTokenIsNative;
    }

    function _refundBuyToken(address payable _to) internal returns (bool) {
        bool isSend = true;
        if (paras.buyTokenIsNative) {
            if (thisAccount.balance > 0) {
                (isSend,) = _to.call{value: thisAccount.balance}("");
            }
        } else {
            if (buyToken.balanceOf(thisAccount) > 0) {
                isSend = buyToken.transfer(_to, buyToken.balanceOf(thisAccount));
            }
        }
        return isSend;
    }

    function _refundSellToken(address payable _to) internal returns (bool) {
        bool isSend = true;
        if (sellToken.balanceOf(thisAccount) > 0) {
            isSend = sellToken.transfer(_to, sellToken.balanceOf(thisAccount));
        }
        return isSend;
    }

    function _buyBalance() internal view returns (uint256) {
        if (paras.buyTokenIsNative) {
            return thisAccount.balance;
        } else {
            return buyToken.balanceOf(thisAccount);
        }
    }

    function _amountAfterTax(uint256 _amount) internal view returns (uint256) {
        return _amount - _amount * paras.sellTax / 10000;
    }

    function _toSwapPoolAmount(uint256 _amount) internal view returns (uint256) {
        return _amount * paras.swapPercent / 10000;
    }

    function _checkMaxBuyAmount(address buyer, uint256 _amount) internal view returns (bool) {
        (uint256 _buyMaxAmount,) = _getBuyMaxAmount(buyer);
        if (_amount <= _buyMaxAmount) {
            return true;
        } else {
            return false;
        }
    }

    function _checkMaxSellAmount(address seller, uint256 _amount) internal view returns (bool) {
        (,uint256 _sellMaxAmount) = _getSellMaxAmount(seller);
        if (_amount <= _sellMaxAmount) {
            return true;
        } else {
            return false;
        }
    }

    function _getBuyMaxAmount(address buyer) internal view returns (uint256, uint256) {
        uint256 _buyMaxAmount = Math.min(paras.maxBuyAmount-amounts[buyer].buyAmount, paras.raiseTotal-buyTokenAmount);
        (uint256 _remainBuyAmount,) = _swapAmount(0, sellTokenAmount);
        return _swapAmount(Math.min(_buyMaxAmount, _remainBuyAmount), 0);
    }

    function _getSellMaxAmount(address seller) internal view returns (uint256, uint256) {
        uint256 _sellMaxAmount = Math.min(totals[seller].sellAmount*paras.maxSellPercent/10000+amounts[seller].sellAmount-
            totals[seller].sellAmount, amounts[seller].sellAmount);
        (,uint256 _remainSellAmount) = _swapAmount(swapPoolAmount, 0);
        return _swapAmount(0, Math.min(_sellMaxAmount, _remainSellAmount));
    }

    function _calculateDeposit() internal view returns (uint256) {
        (,uint256 _sellAmount) = _swapAmount(paras.raiseTotal, 0);
        return _sellAmount;
    }

    function _checkPrice(uint256 _buyAmount, uint256 _sellAmount) internal view returns (bool) {
        if (_reserveDecimals(_buyAmount*_swapPrice(), paras.sellTokenDecimals, 8) == _sellAmount) {
            return true;
        }
        if (_reserveDecimals(_sellAmount/_swapPrice(), paras.buyTokenDecimals, 8) == _buyAmount) {
            return true;
        }
        return false;
    }

    function _swapAmount(uint256 _buyAmount, uint256 _sellAmount) internal view returns (uint256, uint256) {
        if (_buyAmount != 0) {
            return (_buyAmount, _buyAmount * _swapPrice());
        } else if (_sellAmount != 0) {
            return (_sellAmount / _swapPrice(), _sellAmount);
        } else {
            return (0, 0);
        }
    }

    function _swapPrice() internal view returns (uint256) {
        return paras.buyPrice / 100 * (10 ** paras.sellTokenDecimals) / (10 ** paras.buyTokenDecimals);
    }

    function _reserveDecimals(uint256 _amount, uint8 _decimals, uint8 _reserves) internal pure returns(uint256) {
        if (_decimals < _reserves) {
            return _amount;
        } else {
            return _amount / 10 ** (_decimals-_reserves) * 10 ** (_decimals-_reserves);
        }
    }

    function _checkActive() internal view virtual {
        require(status != Status.Cancel, "Crowdfunding is cancel");
    }

    function _checkInTime() internal view virtual {
        require(block.timestamp >= paras.startTime, "Crowdfunding not started");
        require(block.timestamp <= paras.endTime, "Crowdfunding has ended");
    }

    function _checkBeforeStart() internal view virtual {
        require(block.timestamp < paras.startTime, "Crowdfunding has started");
    }

    function _checkCanOver() internal view virtual {
        require(block.timestamp > paras.endTime || buyTokenAmount >= paras.raiseTotal, "Crowdfunding end condition not met");
        require(status != Status.Ended, "Crowdfunding status is ended");
    }

    function _statusFromTime() internal view returns (Status) {
        if (block.timestamp < paras.startTime) {
            return Status.Upcoming;
        } else if (block.timestamp <= paras.endTime) {
            return Status.Live;
        } else {
            return Status.Ended;
        }
    }
}