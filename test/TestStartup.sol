pragma solidity >=0.4.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Startup.sol";

contract TestStartup {
    Startup startup = Startup(DeployedAddresses.Startup());

    function testUserCanapd() public {
        uint256 returnedId = startup.adopt(8);

        uint256 expected = 8;

        Assert.equal(
            expected,
            returnedId,
            "adoption of pet id 8 should be eawal"
        );
    }

    function testGetAdopterAddressByPetId() public {
        address expected = address(this);
        address adopter = startup.adopters(8);
        Assert.equal(adopter, expected, "Owner of pet id 8 shoud be eqeal");
    }

    function testGetAdopters() public {
        address expected = address(this);
        address[16] memory adopters = startup.getAdopters();
        Assert.equal(adopters[8], expected, "Owner should be equeal");
    }
}
