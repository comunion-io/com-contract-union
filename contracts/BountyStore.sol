// SPDX-License-Identifier: SimPL-2.0
pragma solidity >=0.8.x <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ownership/Secondary.sol";

contract BountyStore is Secondary {
    function transfer(address _to, uint256 _amount) public onlyPrimary returns(bool) {
        (bool isSend,) = _to.call{value: _amount}("");
        return isSend;
    }

    function transferToken(IERC20 _token, address _to, uint256 _amount) public onlyPrimary returns(bool) {
        return _token.transfer(_to, _amount);
    }
}