// SPDX-License-Identifier: SimPL-2.0
pragma solidity >=0.8.x <0.9.0;

contract Base
{
    address internal  _owner;
    address payable internal  _coinbase;

    modifier isOwner() {
        assert(msg.sender == _owner);
        _;
    }

    constructor()
    {
        _owner = msg.sender;
    }

    fallback() external payable {
        revert();
    }

    receive() external payable {
        revert();
    }

    function setCoinBase(address payable cb) internal isOwner {
        _coinbase = cb;
    }

    function suicide0(address payable receiver)
    public
    isOwner {
        selfdestruct(receiver);
    }
}
