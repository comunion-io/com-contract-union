// SPDX-License-Identifier: SimPL-2.0
pragma solidity >=0.8.x <0.9.0;

import "../contracts/base/Base.sol";

contract Startup is Base
{
    enum Mode{
        NONE, ESG, NGO, DAO, COM
    }

    struct wallet {
        string name;
        address walletAddress;
    }

    struct Profile {
        /** startup name */
        string name;
        /** startup type */
        Mode mode;
        /** startup hash */
        string[] hashtag;
        /** startup logo src */
        string logo;
        /** startup mission */
        string mission;
        /** startup token contract */
        address tokenContract;
        /** startup compose wallet */
        wallet[] wallets;
        string overview;
        /** is validate the startup name is only */
        bool isValidate;
    }

    event created(string name, Profile startUp, address msg);

    //public name mappong to startup
    mapping(string => Profile) public startups;

    constructor() Base()
    {
        _owner = msg.sender;
    }

    // for web front,  the params looks like  ["zehui1",2,["javascript", "python"],"http://baidu.com","this is my mission", "0xF98A7F9E86DCE7298F3be4778ACd692D649c5228",[["walletname1", "0xF98A7F9E86DCE7298F3be4778ACd692D649c5228"]],"this is overview",true]
    function newStartup(Profile calldata p) public payable {
        // require(_coinbase != address(0), "the address can not be the smart contract address");
        require(bytes(p.name).length != 0, "name can not be null");
        //名称唯一
        require(!startups[p.name].isValidate, "startup name has been used");
        // require(startups[p.name].tokenContract != p.tokenContract, "token contract has been used");
        // p.isValidate = true;
        startups[p.name] = p;
        emit created(p.name, p, msg.sender);
    }
}

