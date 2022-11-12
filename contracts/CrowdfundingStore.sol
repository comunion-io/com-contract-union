// SPDX-License-Identifier: SimPL-2.0
pragma solidity >=0.8.x <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ownership/Secondary.sol";

contract CrowdfundingStore is Secondary {
    using SafeMath for uint;

    struct PairAmount {
        uint256 buyAmount;
        uint256 sellAmount;
    }

    event Receive(address sender, string func);

    mapping(address => PairAmount) totals;
    mapping(address => PairAmount) amounts;

    receive() external payable {
        emit Receive(msg.sender, "receive");
    }

    function transfer(address _to, uint256 _amount) public onlyPrimary returns(bool) {
        (bool isSend,) = _to.call{value: _amount}("");
        return isSend;
    }

    function transferToken(IERC20 _token, address _to, uint256 _amount) public onlyPrimary returns(bool) {
        return _token.transfer(_to, _amount);
    }

    function getTotal(address _address) public view onlyPrimary returns (uint256, uint256) {
        return (totals[_address].buyAmount, totals[_address].sellAmount);
    }

    function addTotal(address _address, uint256 _buyAmount, uint256 _sellAmount) public onlyPrimary {
        totals[_address].buyAmount = totals[_address].buyAmount.add(_buyAmount);
        totals[_address].sellAmount = totals[_address].sellAmount.add(_sellAmount);
    }

    function subTotal(address _address, uint256 _buyAmount, uint256 _sellAmount) public onlyPrimary {
        totals[_address].buyAmount = totals[_address].buyAmount.sub(_buyAmount);
        totals[_address].sellAmount = totals[_address].sellAmount.sub(_sellAmount);
    }

    function getAmount(address _address) public view onlyPrimary returns (uint256, uint256) {
        return (amounts[_address].buyAmount, amounts[_address].sellAmount);
    }

    function addAmount(address _address, uint256 _buyAmount, uint256 _sellAmount) public onlyPrimary {
        amounts[_address].buyAmount = amounts[_address].buyAmount.add(_buyAmount);
        amounts[_address].sellAmount = amounts[_address].sellAmount.add(_sellAmount);
    }

    function subAmount(address _address, uint256 _buyAmount, uint256 _sellAmount) public onlyPrimary {
        amounts[_address].buyAmount = amounts[_address].buyAmount.sub(_buyAmount);
        amounts[_address].sellAmount = amounts[_address].sellAmount.sub(_sellAmount);
    }
}