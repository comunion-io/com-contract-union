pragma solidity >=0.4.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Startup.sol";

contract TestStartup {
    Startup startup = Startup(DeployedAddresses.Startup());

    function testNewStartup() public {
        // uint256 returnedId = startup.adopt(8);
        // uint256 expected = 8;
        // Assert.equal(
        //     expected,
        //     returnedId,
        //     "adoption of pet id 8 should be eawal"
        // );
    }

    function testGetStartup() public {
        // address expected = address(this);
        // address adopter = startup.adopters(8);
        // Assert.equal(adopter, expected, "Owner of pet id 8 shoud be eqeal");
    }
}
