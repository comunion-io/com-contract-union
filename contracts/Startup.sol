// SPDX-License-Identifier: SimPL-2.0
pragma solidity >=0.8.x <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./StartupStore.sol";

contract Startup is Ownable {
    struct Profile {
        string name;
        uint256 chainId;
        bool used;
    }

    event Created(address founder, Profile startup);

    StartupStore store;

    constructor() {
        store = new StartupStore();
    }

    function createStartup(Profile calldata p) public {
        require(bytes(p.name).length > 0, "Name can not be null");
        Profile memory pm = getStartup(p.name);
        require(!pm.used, "Duplicate name");
        pm = Profile(p.name, p.chainId, true);
        store.putStartup(pm.name, pm.chainId, msg.sender, pm.used);
        emit Created(msg.sender, pm);
    }

    function getStartup(string memory name) public view returns (Profile memory) {
        (string memory _name, uint256 _chainId, , bool _used) = store.getStartup(name);
        Profile memory p = Profile(_name, _chainId, _used);
        return p;
    }

    function getStore() external onlyOwner view returns (address) {
        return address(store);
    }

    function transferPrimary(address newPrimary) external onlyOwner {
        store.transferPrimary(newPrimary);
    }

    function transferStore(address newStore) external onlyOwner {
        store = StartupStore(newStore);
    }

    function renounceOwnership() public override onlyOwner {
    }
}