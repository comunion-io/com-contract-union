// SPDX-License-Identifier: SimPL-2.0
pragma solidity >=0.8.x <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Startup is Ownable {
    struct Profile {
        string name;
        uint256 chainId;
        bool used;
    }

    event Created(address founder, Profile startup);

    mapping(string => Profile) private startups;

    function createStartup(Profile calldata p) public {
        require(bytes(p.name).length > 0, "Name can not be null");
        require(!startups[p.name].used, "Name has been used");

        Profile memory profile = Profile({name: p.name, chainId: p.chainId, used: true});
        startups[p.name] = profile;
        emit Created(msg.sender, profile);
    }

    function getStartup(string memory name) public view returns (Profile memory) {
        return startups[name];
    }
}