// SPDX-License-Identifier: SimPL-2.0
pragma solidity >=0.8.x <0.9.0;

import "../contracts/Base.sol";

contract Startup is Base
{
    enum Mode{
        NONE, ESG, NGO, DAO, COM
    }

    struct Profile {
        string id;
        string name;
        Mode mode;
        string hashtag;
        bytes logo;
        string mission;
        string overview;
    }

    event created(string startupId, Profile startUp);

    mapping(string => Profile) roster;

    constructor() Base()
    {
        _owner = msg.sender;
    }

    function newStartup(Profile memory p) public payable {
        require(msg.value >= 1e17, "your balance must more than 0.1 eth");
        require(_coinbase != address(0), "the address can not be the smart contract address");
        require(bytes(p.id).length != 0, "id can not be null");
        roster[p.id] = p;
        _coinbase.transfer(msg.value);
        emit created(p.id, p);
    }

    function getStartup(string calldata id)
    external
    view
    returns (Profile memory p){
        return roster[id];
    }
}
