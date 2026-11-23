 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./VestingVault.sol";

contract UnauthorizedCaller {
    function tryRevoke(
        VestingVault vault,
        uint256 scheduleId
    ) external {
        vault.revoke(scheduleId);
    }


function tryCreateSchedule(VestingVault vault) external {
    vault.createSchedule(
        address(0x8888),
        50 ether,
        uint64(block.timestamp),
        0,
        1000,
        true
    );
}

}
