// SPDX-License-Identifier: SimPL-2.0
pragma solidity >=0.8.x <0.9.0;

import "../contracts/base/Base.sol";
import "./interfaces/IErc20.sol";

contract Bounty is Base { 
    event createdBounty(BountyAddr addr);
    BountyAddr[] private bountyAddressList;

    constructor() Base() {
        _owner = msg.sender;
    }

    function createBounty() public payable {
        BountyAddr addr = new BountyAddr(address(this));
        addr.getPool().transfer(msg.value);
        bountyAddressList.push(addr);
        emit createdBounty(addr);
    }

    function invest(string memory id, address payable oriSender, uint256 oriVal, uint256 time) public {
        // deposit info
    }
}

contract BountyAddr {
    address _bountyBase;

    receive() external payable{
        require(address(_bountyBase) != address(0), 'need init bounty');
        if (msg.value > 0) {
            // Bounty bounty = Bounty(_bountyBase);
            // bounty.invest(id, msg.sender, msg.value, block.timestamp);
        }
    }

    constructor(address bountyBase) {
        _bountyBase = bountyBase;
    }

    function stableTransfer(address payable to, uint256 amount) external payable {
        to.transfer(amount);
    }

    function approve(IERC20 token, address to, uint256 amount) external {
        require(token.approve(to, amount));
    }

    function transferFrom(IERC20 token, address to, uint256 amount) external {
        require(token.transferFrom(address(this), to, amount));
    }

    function transfer(IERC20 token, address to, uint256 amount) external {
        require(token.transfer(to, amount));
    }

    function deposit() external payable {
         // skip fallback func.
    }


    function getPool() public view virtual returns (address payable) {
         return payable(address(this));
    }
}